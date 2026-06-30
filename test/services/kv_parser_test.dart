import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_scanner_app/services/kv_parser.dart';
import 'package:barcode_scanner_app/core/scan_engine.dart';

void main() {
  late KvParser parser;

  setUp(() => parser = KvParser());

  group('explicit key:value pairs', () {
    test('splits colon-separated pairs', () {
      final result = parser.parse(ocrText: 'Weight: 200g\nBrand: Acme');
      expect(_val(result, 'Weight'), '200g');
      expect(_val(result, 'Brand'), 'Acme');
    });

    test('splits equals-separated pairs', () {
      final result = parser.parse(ocrText: 'Price=\$4.99');
      expect(_val(result, 'Price'), '\$4.99');
    });
  });

  group('pattern matchers', () {
    test('detects price with dollar sign', () {
      final result = parser.parse(ocrText: 'Special offer \$3.99 today');
      expect(_val(result, 'Price'), isNotNull);
      expect(_val(result, 'Price'), contains('3.99'));
    });

    test('detects weight in grams', () {
      final result = parser.parse(ocrText: 'Net weight 250g');
      expect(_val(result, 'Weight/Volume'), contains('250'));
    });

    test('detects expiry via EXP keyword', () {
      final result = parser.parse(ocrText: 'EXP: 2025-12-31');
      expect(_val(result, 'Expiry'), isNotNull);
    });

    test('detects batch/lot number', () {
      final result = parser.parse(ocrText: 'Batch: LOT-ABC123');
      expect(_val(result, 'Batch/Lot'), contains('LOT-ABC123'));
    });

    test('detects unlabeled MRP and keeps it out of Price', () {
      final result = parser.parse(ocrText: 'M.R.P. ₹120.00 incl. of all taxes');
      expect(_val(result, 'MRP'), contains('120'));
      // MRP runs before Price, so it should not also register as Price.
      expect(_val(result, 'Price'), isNull);
    });

    test('detects MRP with /- suffix', () {
      final result = parser.parse(ocrText: 'MRP 120/-');
      expect(_val(result, 'MRP'), contains('120'));
    });

    test('detects quantity label', () {
      final result = parser.parse(ocrText: 'Qty 6 N');
      expect(_val(result, 'Quantity'), contains('6'));
    });

    test('Net Qty does not double-register as Weight/Volume', () {
      final result = parser.parse(ocrText: 'Net Qty 500 g');
      expect(_val(result, 'Quantity'), contains('500'));
      expect(_val(result, 'Weight/Volume'), isNull);
    });

    test('detects HSN code', () {
      final result = parser.parse(ocrText: 'HSN Code 04050020');
      expect(_val(result, 'HSN'), '04050020');
    });

    test('detects serial number', () {
      final result = parser.parse(ocrText: 'Serial No. ABC12345');
      expect(_val(result, 'Serial'), contains('ABC12345'));
    });

    test('detects IMEI as Serial', () {
      final result = parser.parse(ocrText: 'IMEI 358240051111110');
      expect(_val(result, 'Serial'), contains('358240051111110'));
    });
  });

  group('key normalization', () {
    test('explicit mrp label normalizes to MRP', () {
      final result = parser.parse(ocrText: 'mrp: 99.00');
      expect(_val(result, 'MRP'), '99.00');
    });

    test('explicit qty label normalizes to Quantity', () {
      final result = parser.parse(ocrText: 'Qty: 12');
      expect(_val(result, 'Quantity'), '12');
    });
  });

  group('barcode classification', () {
    test('URL QR code', () {
      final result = parser.parse(
        ocrText: '',
        barcode: const BarcodeResult(
            value: 'https://example.com', format: BarcodeFormat.qrCode),
      );
      expect(_val(result, 'Type'), 'URL');
      expect(_val(result, 'URL'), 'https://example.com');
    });

    test('plain barcode', () {
      final result = parser.parse(
        ocrText: '',
        barcode: const BarcodeResult(
            value: '4006381333931', format: BarcodeFormat.ean13),
      );
      expect(_val(result, 'Barcode'), '4006381333931');
      expect(_val(result, 'Format'), 'ean13');
    });

    test('WiFi QR code', () {
      final result = parser.parse(
        ocrText: '',
        barcode: const BarcodeResult(
            value: 'WIFI:T:WPA;S:MyNetwork;P:secret;;',
            format: BarcodeFormat.qrCode),
      );
      expect(_val(result, 'SSID'), 'MyNetwork');
      expect(_val(result, 'Password'), 'secret');
    });
  });

  group('product fields merge', () {
    test('merges product fields without duplicating', () {
      final result = parser.parse(
        ocrText: 'Brand: Acme',
        productFields: {'Brand': 'Override', 'Product Name': 'Widget'},
      );
      // OCR Brand wins (first), product Brand is not duplicated
      expect(_val(result, 'Brand'), 'Acme');
      expect(_val(result, 'Product Name'), 'Widget');
    });

    test('existing values win over AI fields in lookupWithAi merge order', () {
      // Mirrors CaptureController.lookupWithAi: existing values are seeded,
      // AI fields are spread first so existing (seed) keys dominate the map.
      const existing = {'MRP': '120', 'Brand': 'Acme'};
      const aiFields = {'MRP': '999', 'HSN': '1905'};
      final merged = parser.parse(
        ocrText: '',
        productFields: {...aiFields, ...existing},
      );
      // Existing MRP wins; AI does not overwrite it.
      expect(_val(merged, 'MRP'), '120');
      // AI-only field is still added.
      expect(_val(merged, 'HSN'), '1905');
    });
  });

  group('deduplication', () {
    test('does not duplicate keys', () {
      final result = parser.parse(ocrText: 'Price: \$1.00\nPrice: \$2.00');
      final prices = result.where((kv) => kv.key == 'Price').toList();
      expect(prices.length, 1);
    });
  });
}

String? _val(List<KeyValue> pairs, String key) {
  try {
    return pairs.firstWhere((kv) => kv.key == key).value;
  } catch (_) {
    return null;
  }
}
