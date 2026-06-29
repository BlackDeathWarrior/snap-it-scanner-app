import 'dart:convert';
import 'package:drift/drift.dart';
import 'app_database.dart';
import 'kv_parser.dart';

class ScanRecord {
  final int id;
  final DateTime createdAt;
  final String inputType;
  final String? barcodeValue;
  final String? barcodeFormat;
  final String? ocrText;
  final List<KeyValue> kvPairs;
  final String? productName;
  final String? productBrand;
  final String? imagePath;

  const ScanRecord({
    required this.id,
    required this.createdAt,
    required this.inputType,
    this.barcodeValue,
    this.barcodeFormat,
    this.ocrText,
    required this.kvPairs,
    this.productName,
    this.productBrand,
    this.imagePath,
  });
}

class HistoryRepository {
  final AppDatabase _db;

  HistoryRepository(this._db);

  Stream<List<ScanRecord>> watchAll() {
    return (_db.select(_db.scanHistoryTable)
          ..orderBy([(t) => OrderingTerm.desc(t.createdAt)]))
        .watch()
        .map((rows) => rows.map(_fromRow).toList());
  }

  Future<ScanRecord?> getById(int id) async {
    final row = await (_db.select(_db.scanHistoryTable)
          ..where((t) => t.id.equals(id)))
        .getSingleOrNull();
    return row == null ? null : _fromRow(row);
  }

  Future<int> save({
    required String inputType,
    String? barcodeValue,
    String? barcodeFormat,
    String? ocrText,
    required List<KeyValue> kvPairs,
    String? productName,
    String? productBrand,
    String? imagePath,
  }) {
    final kvJson = jsonEncode(
      kvPairs.map((kv) => {'key': kv.key, 'value': kv.value}).toList(),
    );
    return _db.into(_db.scanHistoryTable).insert(
          ScanHistoryTableCompanion.insert(
            createdAt: DateTime.now(),
            inputType: inputType,
            barcodeValue: Value(barcodeValue),
            barcodeFormat: Value(barcodeFormat),
            ocrText: Value(ocrText),
            kvPairsJson: kvJson,
            productName: Value(productName),
            productBrand: Value(productBrand),
            imagePath: Value(imagePath),
          ),
        );
  }

  Future<void> delete(int id) async {
    await (_db.delete(_db.scanHistoryTable)
          ..where((t) => t.id.equals(id)))
        .go();
  }

  ScanRecord _fromRow(ScanHistoryTableData row) {
    final rawList = jsonDecode(row.kvPairsJson) as List<dynamic>;
    final kvPairs = rawList
        .map((e) => KeyValue(
              key: e['key'] as String,
              value: e['value'] as String,
            ))
        .toList();
    return ScanRecord(
      id: row.id,
      createdAt: row.createdAt,
      inputType: row.inputType,
      barcodeValue: row.barcodeValue,
      barcodeFormat: row.barcodeFormat,
      ocrText: row.ocrText,
      kvPairs: kvPairs,
      productName: row.productName,
      productBrand: row.productBrand,
      imagePath: row.imagePath,
    );
  }
}
