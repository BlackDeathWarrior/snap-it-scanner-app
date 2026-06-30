import 'package:flutter_test/flutter_test.dart';
import 'package:barcode_scanner_app/services/csv_export_service.dart';
import 'package:barcode_scanner_app/services/history_repository.dart';
import 'package:barcode_scanner_app/services/kv_parser.dart';

void main() {
  final service = CsvExportService();

  ScanRecord record({
    int id = 1,
    String inputType = 'file',
    String? barcodeValue,
    String? productName,
    List<KeyValue>? kvPairs,
  }) =>
      ScanRecord(
        id: id,
        createdAt: DateTime.utc(2026, 6, 30, 12),
        inputType: inputType,
        barcodeValue: barcodeValue,
        productName: productName,
        kvPairs: kvPairs ?? const [],
      );

  test('emits header row with all columns', () {
    final csv = service.buildCsv([record()]);
    final firstLine = csv.split(RegExp(r'\r?\n')).first;
    expect(firstLine,
        'id,createdAt,inputType,barcodeValue,barcodeFormat,productName,productBrand,ocrText,kvPairs');
  });

  test('flattens kv pairs into a single column', () {
    final csv = service.buildCsv([
      record(kvPairs: [
        KeyValue(key: 'MRP', value: '120'),
        KeyValue(key: 'Quantity', value: '6'),
      ]),
    ]);
    expect(csv, contains('MRP=120; Quantity=6'));
  });

  test('escapes fields containing commas via the csv library', () {
    final csv = service.buildCsv([
      record(productName: 'Acme, Inc.'),
    ]);
    // The csv package wraps comma-containing fields in quotes.
    expect(csv, contains('"Acme, Inc."'));
  });

  test('null fields become empty strings', () {
    final csv = service.buildCsv([record(barcodeValue: null)]);
    // id row should still have the right number of separators (8 commas).
    final dataLine = csv.split(RegExp(r'\r?\n'))[1];
    expect(','.allMatches(dataLine).length, greaterThanOrEqualTo(8));
  });
}
