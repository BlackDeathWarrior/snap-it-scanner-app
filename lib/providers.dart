import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/scan_engine.dart';
import 'core/engines/mobile_scan_engine.dart';
import 'core/engines/desktop_scan_engine.dart';
import 'services/kv_parser.dart';
import 'services/product_lookup.dart';
import 'services/app_database.dart';
import 'services/history_repository.dart';
import 'services/app_settings.dart';

final scanEngineProvider = Provider<ScanEngine>((ref) {
  final engine =
      Platform.isWindows ? DesktopScanEngine() : MobileScanEngine();
  ref.onDispose(engine.dispose);
  return engine;
});

final kvParserProvider = Provider<KvParser>((ref) => KvParser());

final appSettingsProvider = Provider<AppSettings>((ref) => AppSettings());

final productLookupProvider = Provider<ProductLookup>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return ProductLookup(apiKeyResolver: settings.getAnthropicKey);
});

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return HistoryRepository(db);
});
