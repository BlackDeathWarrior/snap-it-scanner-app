import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:barcode_scanner_app/services/product_lookup.dart';

void main() {
  group('ProductInfo.toKvMap', () {
    test('includes all populated generalized fields', () {
      const info = ProductInfo(
        barcode: '123',
        name: 'Wireless Headphones',
        brand: 'Acme',
        category: 'Electronics > Audio',
        price: '49.99 USD',
        description: 'Over-ear, noise cancelling',
        source: 'UPCitemdb',
      );

      final m = info.toKvMap();
      expect(m['Product Name'], 'Wireless Headphones');
      expect(m['Brand'], 'Acme');
      expect(m['Category'], 'Electronics > Audio');
      expect(m['Price'], '49.99 USD');
      expect(m['Description'], 'Over-ear, noise cancelling');
      expect(m['Source'], 'UPCitemdb');
    });

    test('omits null fields', () {
      const info = ProductInfo(barcode: '123', name: 'Plain');
      final m = info.toKvMap();
      expect(m.containsKey('Brand'), isFalse);
      expect(m.containsKey('Price'), isFalse);
      expect(m['Product Name'], 'Plain');
    });
  });

  group('ProductLookup.lookup (UPCitemdb)', () {
    test('maps a UPCitemdb response into ProductInfo', () async {
      final mockBody = jsonEncode({
        'code': 'OK',
        'items': [
          {
            'title': 'Levi 501 Jeans',
            'brand': 'Levi',
            'category': 'Apparel > Pants',
            'description': 'Classic straight fit',
            'images': ['https://img/1.jpg'],
            'offers': [
              {'price': 59.5, 'currency': 'USD'},
              {'price': 49.0, 'currency': 'USD'},
            ],
          }
        ],
      });

      final lookup = ProductLookup(
        client: _StubClient((req) async {
          expect(req.url.host, 'api.upcitemdb.com');
          return http.Response(mockBody, 200);
        }),
      );

      final info = await lookup.lookup('0123456789012');
      expect(info, isNotNull);
      expect(info!.name, 'Levi 501 Jeans');
      expect(info.brand, 'Levi');
      expect(info.category, 'Apparel > Pants');
      expect(info.imageUrl, 'https://img/1.jpg');
      expect(info.price, '49.00 USD'); // lowest offer
      expect(info.source, 'UPCitemdb');
    });

    test('vision disabled when no API key resolver configured', () async {
      final lookup = ProductLookup(client: _StubClient((_) async {
        return http.Response('{}', 200);
      }));
      expect(await lookup.visionEnabled, isFalse);
      // Without a key, lookupByImage now reports *why* it can't run so the UI
      // can point the user to Settings.
      expect(
        () => lookup.lookupByImage('/nope.jpg'),
        throwsA(isA<AiLookupException>()
            .having((e) => e.needsKey, 'needsKey', isTrue)),
      );
    });
  });
}

/// Minimal stub http.Client that routes every request through [handler].
class _StubClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  _StubClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final resp = await handler(request);
    return http.StreamedResponse(
      Stream.value(utf8.encode(resp.body)),
      resp.statusCode,
      headers: resp.headers,
      request: request,
    );
  }
}
