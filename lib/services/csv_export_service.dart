import 'dart:io';
import 'package:csv/csv.dart';
import 'package:file_selector/file_selector.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'history_repository.dart';

/// Writes scan history to a real `.csv` file on disk (RFC-4180 via the `csv`
/// package) and returns the saved file path.
///
/// On desktop it opens a native save dialog; on mobile it writes to the app
/// documents directory (the caller can then offer to share it).
class CsvExportService {
  static const _columns = <String>[
    'id',
    'createdAt',
    'inputType',
    'barcodeValue',
    'barcodeFormat',
    'productName',
    'productBrand',
    'ocrText',
    'kvPairs',
  ];

  /// Serializes [records] to CSV text. Public for testability.
  String buildCsv(List<ScanRecord> records) {
    final rows = <List<String>>[_columns];
    for (final r in records) {
      rows.add([
        r.id.toString(),
        r.createdAt.toIso8601String(),
        r.inputType,
        r.barcodeValue ?? '',
        r.barcodeFormat ?? '',
        r.productName ?? '',
        r.productBrand ?? '',
        r.ocrText ?? '',
        // Flatten KV pairs into a single column: "key=value; key=value".
        r.kvPairs.map((kv) => '${kv.key}=${kv.value}').join('; '),
      ]);
    }
    return const ListToCsvConverter().convert(rows);
  }

  /// Exports [records] to a `.csv` file and returns the saved path, or null if
  /// the user cancelled the save dialog (desktop only).
  Future<String?> exportToFile(List<ScanRecord> records) async {
    final csv = buildCsv(records);
    final fileName =
        'scan_history_${DateTime.now().toIso8601String().split('T').first}.csv';

    if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
      final location = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: const [
          XTypeGroup(label: 'CSV', extensions: ['csv']),
        ],
      );
      if (location == null) return null; // user cancelled
      final file = File(location.path);
      await file.writeAsString(csv);
      return file.path;
    }

    // Mobile: write into app documents so it can be shared afterwards.
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(csv);
    return file.path;
  }
}
