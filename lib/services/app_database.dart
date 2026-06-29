import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

part 'app_database.g.dart';

class ScanHistoryTable extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdAt => dateTime()();
  TextColumn get inputType => text()(); // 'camera' | 'gallery' | 'file'
  TextColumn get barcodeValue => text().nullable()();
  TextColumn get barcodeFormat => text().nullable()();
  TextColumn get ocrText => text().nullable()();
  TextColumn get kvPairsJson => text()(); // JSON-encoded List<{key,value}>
  TextColumn get productName => text().nullable()();
  TextColumn get productBrand => text().nullable()();
  TextColumn get imagePath => text().nullable()();
}

@DriftDatabase(tables: [ScanHistoryTable])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    if (Platform.isWindows || Platform.isLinux) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'barcode_scanner.db'));
    return NativeDatabase.createInBackground(file);
  });
}
