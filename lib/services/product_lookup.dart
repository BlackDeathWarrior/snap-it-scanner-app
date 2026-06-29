import 'package:openfoodfacts/openfoodfacts.dart';

class ProductInfo {
  final String barcode;
  final String? name;
  final String? brand;
  final String? quantity;
  final String? categories;
  final String? ingredients;
  final String? imageUrl;
  final Map<String, String> extra;

  const ProductInfo({
    required this.barcode,
    this.name,
    this.brand,
    this.quantity,
    this.categories,
    this.ingredients,
    this.imageUrl,
    this.extra = const {},
  });

  Map<String, String> toKvMap() {
    final m = <String, String>{};
    if (name != null) m['Product Name'] = name!;
    if (brand != null) m['Brand'] = brand!;
    if (quantity != null) m['Quantity'] = quantity!;
    if (categories != null) m['Categories'] = categories!;
    if (ingredients != null) m['Ingredients'] = ingredients!;
    m.addAll(extra);
    return m;
  }
}

class ProductLookup {
  final _cache = <String, ProductInfo?>{};

  ProductLookup() {
    OpenFoodAPIConfiguration.userAgent = UserAgent(
      name: 'BarcodeScannerApp',
      version: '1.0.0',
    );
  }

  Future<ProductInfo?> lookup(String barcode) async {
    if (_cache.containsKey(barcode)) return _cache[barcode];

    try {
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
        _cache[barcode] = null;
        return null;
      }

      final p = result.product!;
      final extra = <String, String>{};

      final nutriments = p.nutriments;
      if (nutriments != null) {
        final energy = nutriments.getValue(Nutrient.energyKCal, PerSize.serving);
        if (energy != null) extra['Calories (per serving)'] = '$energy kcal';
      }

      final info = ProductInfo(
        barcode: barcode,
        name: p.productName,
        brand: p.brands,
        quantity: p.quantity,
        categories: p.categories,
        ingredients: p.ingredientsText,
        imageUrl: p.imageFrontUrl,
        extra: extra,
      );

      _cache[barcode] = info;
      return info;
    } catch (_) {
      _cache[barcode] = null;
      return null;
    }
  }
}
