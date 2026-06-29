import 'package:go_router/go_router.dart';
import '../features/capture/capture_page.dart';
import '../features/results/results_page.dart';
import '../features/history/history_page.dart';
import '../features/history/history_detail_page.dart';
import '../services/kv_parser.dart';
import '../core/scan_engine.dart';

final appRouter = GoRouter(
  initialLocation: '/capture',
  routes: [
    GoRoute(
      path: '/capture',
      builder: (context, state) => const CapturePage(),
    ),
    GoRoute(
      path: '/results',
      builder: (context, state) {
        final extra = state.extra as ResultsArgs;
        return ResultsPage(args: extra);
      },
    ),
    GoRoute(
      path: '/history',
      builder: (context, state) => const HistoryPage(),
    ),
    GoRoute(
      path: '/history/:id',
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return HistoryDetailPage(scanId: id);
      },
    ),
  ],
);

class ResultsArgs {
  final BarcodeResult? barcode;
  final String ocrText;
  final List<KeyValue> kvPairs;
  final String inputType;
  final String? imagePath;

  const ResultsArgs({
    this.barcode,
    required this.ocrText,
    required this.kvPairs,
    required this.inputType,
    this.imagePath,
  });
}
