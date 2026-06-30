import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:openfoodfacts/openfoodfacts.dart';

/// Generalized product info — works for any category, not just food.
class ProductInfo {
  final String barcode;
  final String? name;
  final String? brand;
  final String? category;
  final String? description;
  final String? quantity;
  final String? ingredients;
  final String? price;
  final String? imageUrl;
  final String? source; // which provider resolved this
  final Map<String, String> extra;

  const ProductInfo({
    required this.barcode,
    this.name,
    this.brand,
    this.category,
    this.description,
    this.quantity,
    this.ingredients,
    this.price,
    this.imageUrl,
    this.source,
    this.extra = const {},
  });

  Map<String, String> toKvMap() {
    final m = <String, String>{};
    if (name != null) m['Product Name'] = name!;
    if (brand != null) m['Brand'] = brand!;
    if (category != null) m['Category'] = category!;
    if (quantity != null) m['Quantity'] = quantity!;
    if (price != null) m['Price'] = price!;
    if (description != null) m['Description'] = description!;
    if (ingredients != null) m['Ingredients'] = ingredients!;
    m.addAll(extra);
    if (source != null) m['Source'] = source!;
    return m;
  }
}

/// Resolves the optional Anthropic API key used for the "identify from photo"
/// (Google-Lens-style) visual lookup. Returns null/empty when not configured.
typedef ApiKeyResolver = Future<String?> Function();

/// Raised by [ProductLookup.lookupByImage] so the UI can explain *why* an AI
/// lookup didn't produce data instead of failing silently.
class AiLookupException implements Exception {
  final String message;
  /// True when the user simply hasn't configured an Anthropic API key yet,
  /// so the UI can offer a shortcut to Settings.
  final bool needsKey;
  const AiLookupException(this.message, {this.needsKey = false});

  @override
  String toString() => message;
}

class ProductLookup {
  final _cache = <String, ProductInfo?>{};
  final ApiKeyResolver? _apiKeyResolver;
  final http.Client _client;

  ProductLookup({ApiKeyResolver? apiKeyResolver, http.Client? client})
      : _apiKeyResolver = apiKeyResolver,
        _client = client ?? http.Client() {
    OpenFoodAPIConfiguration.userAgent = UserAgent(
      name: 'BarcodeScannerApp',
      version: '1.0.0',
    );
  }

  /// Looks up a product by barcode across multiple free, keyless sources.
  /// Returns null when no source recognizes the code.
  /// Throws on network errors so callers can distinguish offline from not-found.
  Future<ProductInfo?> lookup(String barcode) async {
    if (_cache.containsKey(barcode)) return _cache[barcode];

    ProductInfo? info;
    Object? lastError;

    // 1. UPCitemdb trial — universal retail (electronics, clothes, general).
    try {
      info = await _lookupUpcItemDb(barcode);
    } catch (e) {
      lastError = e;
    }

    // 2. Open Food Facts — food fallback.
    if (info == null) {
      try {
        info = await _lookupOpenFoodFacts(barcode);
      } catch (e) {
        lastError = e;
      }
    }

    // If every source threw (offline) and nothing resolved, surface the error.
    if (info == null && lastError != null) throw lastError;

    _cache[barcode] = info;
    return info;
  }

  // ─── UPCitemdb (keyless trial endpoint) ─────────────────────────────────────

  Future<ProductInfo?> _lookupUpcItemDb(String barcode) async {
    final uri = Uri.parse(
        'https://api.upcitemdb.com/prod/trial/lookup?upc=$barcode');
    final resp = await _client.get(uri).timeout(const Duration(seconds: 12));

    // 404 / 429 etc. → treat as "no result here", not a hard failure.
    if (resp.statusCode != 200) return null;

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final items = json['items'] as List<dynamic>?;
    if (items == null || items.isEmpty) return null;

    final item = items.first as Map<String, dynamic>;
    final images = (item['images'] as List<dynamic>?)?.cast<String>();
    final offers = item['offers'] as List<dynamic>?;

    String? price;
    if (offers != null && offers.isNotEmpty) {
      final lowest = offers
          .map((o) => (o as Map<String, dynamic>)['price'])
          .whereType<num>()
          .fold<num?>(null, (min, p) => min == null || p < min ? p : min);
      final currency =
          (offers.first as Map<String, dynamic>)['currency'] as String? ??
              'USD';
      if (lowest != null && lowest > 0) {
        price = '${lowest.toStringAsFixed(2)} $currency';
      }
    }

    String? nonEmpty(Object? v) {
      final s = v?.toString().trim();
      return (s == null || s.isEmpty) ? null : s;
    }

    return ProductInfo(
      barcode: barcode,
      name: nonEmpty(item['title']),
      brand: nonEmpty(item['brand']),
      category: nonEmpty(item['category']),
      description: nonEmpty(item['description']),
      price: price,
      imageUrl: (images != null && images.isNotEmpty) ? images.first : null,
      source: 'UPCitemdb',
    );
  }

  // ─── Open Food Facts ────────────────────────────────────────────────────────

  Future<ProductInfo?> _lookupOpenFoodFacts(String barcode) async {
    final config = ProductQueryConfiguration(
      barcode,
      version: ProductQueryVersion.v3,
      fields: [
        ProductField.NAME,
        ProductField.BRANDS,
        ProductField.QUANTITY,
        ProductField.CATEGORIES,
        ProductField.INGREDIENTS_TEXT,
        ProductField.IMAGE_FRONT_URL,
        ProductField.NUTRIMENTS,
      ],
      language: OpenFoodFactsLanguage.ENGLISH,
      country: OpenFoodFactsCountry.USA,
    );

    final result = await OpenFoodAPIClient.getProductV3(config);

    if (result.status != ProductResultV3.statusSuccess ||
        result.product == null) {
      return null;
    }

    final p = result.product!;
    final extra = <String, String>{};
    final nutriments = p.nutriments;
    if (nutriments != null) {
      final energy = nutriments.getValue(Nutrient.energyKCal, PerSize.serving);
      if (energy != null) extra['Calories (per serving)'] = '$energy kcal';
    }

    return ProductInfo(
      barcode: barcode,
      name: p.productName,
      brand: p.brands,
      category: p.categories,
      quantity: p.quantity,
      ingredients: p.ingredientsText,
      imageUrl: p.imageFrontUrl,
      source: 'Open Food Facts',
      extra: extra,
    );
  }

  // ─── Optional Claude-vision "identify from photo" (Google-Lens style) ────────

  /// Returns true when an Anthropic API key is configured (vision enabled).
  Future<bool> get visionEnabled async {
    final key = await _apiKeyResolver?.call();
    return key != null && key.trim().isNotEmpty;
  }

  /// Identifies a product from a still image using Claude's vision model and
  /// extracts every label field it can read (name, brand, MRP, quantity, etc.).
  ///
  /// Throws [AiLookupException] with a user-facing reason on any failure
  /// (missing/invalid key, network, unreadable response) instead of returning
  /// null silently. Returns null only when the model genuinely identifies
  /// nothing in the image.
  Future<ProductInfo?> lookupByImage(String imagePath) async {
    final key = (await _apiKeyResolver?.call())?.trim();
    if (key == null || key.isEmpty) {
      throw const AiLookupException(
        'Add an Anthropic API key in Settings to use AI lookup.',
        needsKey: true,
      );
    }

    final file = File(imagePath);
    if (!await file.exists()) {
      throw const AiLookupException('Could not read the scanned image.');
    }
    final bytes = await file.readAsBytes();
    final mediaType = imagePath.toLowerCase().endsWith('.png')
        ? 'image/png'
        : 'image/jpeg';

    const prompt =
        'You are reading a product label/tag. Extract every field you can see. '
        'Respond with ONLY a strict JSON object, no markdown, no prose, using '
        'these keys: {"name": string, "brand": string, "category": string, '
        '"description": string, "mrp": string, "price": string, '
        '"quantity": string, "weight": string, "expiry": string, '
        '"batch": string, "hsn": string, '
        '"extra": object of any other label fields as string key/value pairs}. '
        'Use an empty string for any field you cannot determine, and {} for '
        'extra when there is nothing else.';

    final http.Response resp;
    try {
      resp = await _client
          .post(
            Uri.parse('https://api.anthropic.com/v1/messages'),
            headers: {
              'content-type': 'application/json',
              'x-api-key': key,
              'anthropic-version': '2023-06-01',
            },
            body: jsonEncode({
              'model': 'claude-opus-4-8',
              'max_tokens': 1024,
              'messages': [
                {
                  'role': 'user',
                  'content': [
                    {
                      'type': 'image',
                      'source': {
                        'type': 'base64',
                        'media_type': mediaType,
                        'data': base64Encode(bytes),
                      },
                    },
                    {'type': 'text', 'text': prompt},
                  ],
                },
              ],
            }),
          )
          .timeout(const Duration(seconds: 40));
    } on SocketException {
      throw const AiLookupException(
          'Network error. Check your connection and try again.');
    } on http.ClientException {
      throw const AiLookupException(
          'Network error. Check your connection and try again.');
    } catch (_) {
      throw const AiLookupException('AI lookup timed out. Please try again.');
    }

    if (resp.statusCode == 401) {
      throw const AiLookupException(
        'Invalid Anthropic API key. Update it in Settings.',
        needsKey: true,
      );
    }
    if (resp.statusCode == 429) {
      throw const AiLookupException(
          'AI service is rate-limited. Please try again shortly.');
    }
    if (resp.statusCode != 200) {
      throw AiLookupException('AI lookup failed (HTTP ${resp.statusCode}).');
    }

    final json = jsonDecode(resp.body) as Map<String, dynamic>;
    final content = json['content'] as List<dynamic>?;
    final text = content
        ?.whereType<Map<String, dynamic>>()
        .firstWhere((b) => b['type'] == 'text', orElse: () => {})['text'];
    if (text is! String) {
      throw const AiLookupException('AI returned an unexpected response.');
    }

    final parsed = _extractJson(text);
    if (parsed == null) {
      throw const AiLookupException('Could not read the AI response.');
    }

    String? field(String k) {
      final v = parsed[k]?.toString().trim();
      return (v == null || v.isEmpty) ? null : v;
    }

    // Collect the richer label fields into `extra` so toKvMap surfaces them.
    final extra = <String, String>{};
    void put(String label, String? value) {
      if (value != null) extra[label] = value;
    }

    put('MRP', field('mrp'));
    put('Weight/Volume', field('weight'));
    put('Expiry', field('expiry'));
    put('Batch/Lot', field('batch'));
    put('HSN', field('hsn'));
    final extraObj = parsed['extra'];
    if (extraObj is Map) {
      extraObj.forEach((k, v) {
        final key = k.toString().trim();
        final val = v?.toString().trim() ?? '';
        if (key.isNotEmpty && val.isNotEmpty) extra[key] = val;
      });
    }

    final name = field('name');
    final brand = field('brand');
    if (name == null && brand == null && extra.isEmpty) return null;

    return ProductInfo(
      barcode: '',
      name: name,
      brand: brand,
      category: field('category'),
      description: field('description'),
      quantity: field('quantity'),
      price: field('price'),
      source: 'Claude Vision',
      extra: extra,
    );
  }

  Map<String, dynamic>? _extractJson(String text) {
    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start == -1 || end <= start) return null;
    try {
      return jsonDecode(text.substring(start, end + 1))
          as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
