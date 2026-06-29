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
