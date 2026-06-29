import '../core/scan_engine.dart';

class KeyValue {
  final String key;
  String value;
  final bool isEdited;

  KeyValue({required this.key, required this.value, this.isEdited = false});

  KeyValue copyWith({String? key, String? value, bool? isEdited}) => KeyValue(
        key: key ?? this.key,
        value: value ?? this.value,
        isEdited: isEdited ?? this.isEdited,
      );
}

enum QrPayloadType { url, vCard, wifi, text }

class KvParser {
  static const _priceRe = r'[$€£¥₹]\s*\d+[\.,]\d{2}|\d+[\.,]\d{2}\s*[$€£¥₹]';
  static const _weightRe =
      r'\b(\d+(?:\.\d+)?)\s*(kg|g|lb|oz|ml|l|litre|liter)\b';
  static const _expiryRe =
      r'(?:exp(?:iry|ires?)?|best\s+before|mfg|manufactured)[:\s]*([0-9A-Za-z/\-\.]+)';
  static const _dateRe =
      r'\b\d{4}[-/]\d{2}[-/]\d{2}\b|\b\d{2}[-/]\d{2}[-/]\d{4}\b';
  static const _batchRe =
      r'(?:batch|lot|lot\s*no\.?)[:\s]*([A-Z0-9\-]+)';

  List<KeyValue> parse({
    required String ocrText,
    BarcodeResult? barcode,
    Map<String, String>? productFields,
  }) {
    final pairs = <KeyValue>[];

    if (barcode != null) {
      final qrPairs = _classifyBarcode(barcode);
      pairs.addAll(qrPairs);
    }

    if (ocrText.isNotEmpty) {
      pairs.addAll(_parseOcrText(ocrText));
    }

    if (productFields != null) {
      for (final e in productFields.entries) {
        if (!_hasKey(pairs, e.key)) {
          pairs.add(KeyValue(key: e.key, value: e.value));
        }
      }
    }

    // Deduplicate by key (keep first occurrence)
    final seen = <String>{};
    return pairs.where((kv) => seen.add(kv.key.toLowerCase())).toList();
  }

  List<KeyValue> _classifyBarcode(BarcodeResult b) {
    final v = b.value;
    if (_isUrl(v)) {
      return [
        KeyValue(key: 'Type', value: 'URL'),
        KeyValue(key: 'URL', value: v),
      ];
    }
    if (v.startsWith('BEGIN:VCARD')) {
      return [KeyValue(key: 'Type', value: 'vCard'), ..._parseVCard(v)];
    }
    if (v.startsWith('WIFI:')) {
      return [KeyValue(key: 'Type', value: 'WiFi'), ..._parseWifi(v)];
    }
    if (b.format == BarcodeFormat.qrCode) {
      return [
        KeyValue(key: 'Type', value: 'QR Text'),
        KeyValue(key: 'Content', value: v),
      ];
    }
    return [
      KeyValue(key: 'Barcode', value: v),
      KeyValue(key: 'Format', value: b.format.name),
    ];
  }

  List<KeyValue> _parseOcrText(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final pairs = <KeyValue>[];

    for (final line in lines) {
      // Explicit key: value pairs
      final colonIdx = line.indexOf(':');
      final equalsIdx = line.indexOf('=');
      final splitIdx = colonIdx != -1
          ? colonIdx
          : equalsIdx != -1
              ? equalsIdx
              : -1;

      if (splitIdx > 0 && splitIdx < line.length - 1) {
        final k = line.substring(0, splitIdx).trim();
        final v = line.substring(splitIdx + 1).trim();
        if (k.isNotEmpty && v.isNotEmpty && k.length < 40) {
          pairs.add(KeyValue(key: _normalizeKey(k), value: v));
          continue;
        }
      }

      // Pattern matchers for unlabeled values
      _matchPattern(line, _priceRe, 'Price', pairs);
      _matchPattern(line, _weightRe, 'Weight/Volume', pairs,
          groupIndex: 0); // full match
      _matchPattern(line, _expiryRe, 'Expiry', pairs, groupIndex: 1);
      _matchPattern(line, _batchRe, 'Batch/Lot', pairs, groupIndex: 1);
      if (!_hasKey(pairs, 'Date')) {
        _matchPattern(line, _dateRe, 'Date', pairs);
      }
    }

    return pairs;
  }

  void _matchPattern(
    String line,
    String pattern,
    String key,
    List<KeyValue> pairs, {
    int groupIndex = 0,
  }) {
    final re = RegExp(pattern, caseSensitive: false);
    final m = re.firstMatch(line);
    if (m != null) {
      final val = groupIndex == 0 ? m.group(0)! : (m.group(groupIndex) ?? '');
      if (val.isNotEmpty && !_hasKey(pairs, key)) {
        pairs.add(KeyValue(key: key, value: val.trim()));
      }
    }
  }

  List<KeyValue> _parseVCard(String vcard) {
    final pairs = <KeyValue>[];
    for (final line in vcard.split('\n')) {
      final parts = line.split(':');
      if (parts.length < 2) continue;
      final key = parts[0].split(';').first.trim();
      final value = parts.sublist(1).join(':').trim();
      if (key == 'BEGIN' || key == 'END' || key == 'VERSION') continue;
      if (value.isNotEmpty) pairs.add(KeyValue(key: key, value: value));
    }
    return pairs;
  }

  List<KeyValue> _parseWifi(String wifi) {
    // WIFI:T:WPA;S:NetworkName;P:Password;;
    final pairs = <KeyValue>[];
    final body = wifi.substring(5);
    for (final segment in body.split(';')) {
      if (segment.length < 3) continue;
      final colonIdx = segment.indexOf(':');
      if (colonIdx < 1) continue;
      final k = segment.substring(0, colonIdx);
      final v = segment.substring(colonIdx + 1);
      final label = switch (k) {
        'S' => 'SSID',
        'P' => 'Password',
        'T' => 'Security',
        _ => k,
      };
      if (v.isNotEmpty) pairs.add(KeyValue(key: label, value: v));
    }
    return pairs;
  }

  bool _isUrl(String s) =>
      s.startsWith('http://') || s.startsWith('https://');

  bool _hasKey(List<KeyValue> pairs, String key) =>
      pairs.any((kv) => kv.key.toLowerCase() == key.toLowerCase());

  static const _keyAliases = {
    'exp': 'Expiry',
    'expiry': 'Expiry',
    'expiry date': 'Expiry',
    'expires': 'Expiry',
    'best before': 'Expiry',
    'bb': 'Expiry',
    'mfg': 'MFG Date',
    'manufactured': 'MFG Date',
    'manufacture date': 'MFG Date',
    'batch': 'Batch/Lot',
    'lot': 'Batch/Lot',
    'lot no': 'Batch/Lot',
    'lot no.': 'Batch/Lot',
    'batch no': 'Batch/Lot',
    'net weight': 'Weight/Volume',
    'net wt': 'Weight/Volume',
  };

  String _normalizeKey(String s) {
    final lower = s.toLowerCase().trim();
    if (_keyAliases.containsKey(lower)) return _keyAliases[lower]!;
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}
