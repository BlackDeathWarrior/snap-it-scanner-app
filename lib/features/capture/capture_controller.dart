import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/scan_engine.dart';
import '../../services/kv_parser.dart';
import '../../services/product_lookup.dart';
import '../../providers.dart';
import '../../ui/app_router.dart';

enum CaptureStatus { idle, processing, done, error }

class CaptureState {
  final CaptureStatus status;
  final String? errorMessage;

  const CaptureState({this.status = CaptureStatus.idle, this.errorMessage});

  CaptureState copyWith({CaptureStatus? status, String? errorMessage}) =>
      CaptureState(
        status: status ?? this.status,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

class CaptureController extends Notifier<CaptureState> {
  @override
  CaptureState build() => const CaptureState();

  Future<ResultsArgs?> processFile(String filePath) async {
    state = state.copyWith(status: CaptureStatus.processing);
    try {
      return await _run(ScanInput.fromPath(filePath), filePath, 'file');
    } catch (e) {
      state = state.copyWith(
          status: CaptureStatus.error, errorMessage: _friendlyError(e));
      return null;
    }
  }

  Future<ResultsArgs?> pickFromGallery() => _pickImage(ImageSource.gallery, 'gallery');

  /// Opens the device camera so the user can deliberately snap a photo
  /// (manual shutter), then runs the full barcode + OCR + lookup pipeline.
  Future<ResultsArgs?> captureFromCamera() => _pickImage(ImageSource.camera, 'camera');

  Future<ResultsArgs?> _pickImage(ImageSource source, String inputType) async {
    final picker = ImagePicker();
    try {
      final xfile = await picker.pickImage(source: source);
      if (xfile == null) return null;
      state = state.copyWith(status: CaptureStatus.processing);
      return await _run(ScanInput.fromPath(xfile.path), xfile.path, inputType);
    } on PlatformException catch (e) {
      state = state.copyWith(
          status: CaptureStatus.error, errorMessage: _friendlyError(e));
      return null;
    } catch (e) {
      state = state.copyWith(
          status: CaptureStatus.error, errorMessage: _friendlyError(e));
      return null;
    }
  }

  /// Runs the lookup pipeline for a hand-typed barcode (no image).
  Future<ResultsArgs?> processManualBarcode(String code) async {
    final trimmed = code.trim();
    if (trimmed.isEmpty) return null;
    final barcode =
        BarcodeResult(value: trimmed, format: BarcodeFormat.unknown);
    return confirmLiveBarcode(barcode);
  }

  /// Called when live camera detects a barcode. Does a full product lookup
  /// before returning so results are complete (not just barcode + format).
  Future<ResultsArgs?> confirmLiveBarcode(BarcodeResult barcode) async {
    state = state.copyWith(status: CaptureStatus.processing);
    try {
      final parser = ref.read(kvParserProvider);
      final lookup = ref.read(productLookupProvider);

      ProductInfo? product;
      String? lookupNote;
      try {
        product = await lookup.lookup(barcode.value);
        if (product == null) lookupNote = 'No product match found';
      } catch (e) {
        final msg = e.toString();
        lookupNote = (msg.contains('SocketException') ||
                msg.contains('network') ||
                msg.contains('timeout'))
            ? 'Offline — no product data'
            : 'Product lookup unavailable';
      }

      final kvPairs = parser.parse(
        ocrText: '',
        barcode: barcode,
        productFields: product?.toKvMap(),
      );

      if (lookupNote != null &&
          !kvPairs.any((kv) => kv.key.toLowerCase() == 'product lookup')) {
        kvPairs.add(KeyValue(key: 'Product Lookup', value: lookupNote));
      }

      state = state.copyWith(status: CaptureStatus.done);
      return ResultsArgs(
        barcode: barcode,
        ocrText: '',
        kvPairs: kvPairs,
        inputType: 'camera',
        productImageUrl: product?.imageUrl,
      );
    } catch (e) {
      state = state.copyWith(
          status: CaptureStatus.error, errorMessage: _friendlyError(e));
      return null;
    }
  }

  static String _friendlyError(Object e) {
    if (e is PlatformException) {
      if (e.code == 'photo_access_denied' ||
          e.code == 'camera_access_denied' ||
          e.code == 'access_denied') {
        return 'Permission denied. Please allow access in Settings.';
      }
      return e.message ?? e.code;
    }
    final msg = e.toString();
    if (msg.contains('SocketException') || msg.contains('NetworkException')) {
      return 'Network error. Check your connection and try again.';
    }
    if (msg.contains('FileSystemException') || msg.contains('No such file')) {
      return 'Could not read the file. Please try again.';
    }
    return 'Something went wrong. Please try again.';
  }

  Future<ResultsArgs> _run(
      ScanInput input, String filePath, String inputType) async {
    final engine = ref.read(scanEngineProvider);
    final parser = ref.read(kvParserProvider);
    final lookup = ref.read(productLookupProvider);

    final barcode = await engine.scanBarcode(input);
    final ocrText = await engine.recognizeText(input);

    ProductInfo? product;
    String? lookupNote;
    if (barcode != null) {
      try {
        product = await lookup.lookup(barcode.value);
        if (product == null) lookupNote = 'No product match found';
      } catch (e) {
        final msg = e.toString();
        lookupNote = (msg.contains('SocketException') ||
                msg.contains('network') ||
                msg.contains('timeout'))
            ? 'Offline — no product data'
            : 'Product lookup unavailable';
      }
    }

    // Google-Lens-style visual fallback: when no barcode resolved a product
    // and a real image is available, ask Claude vision to identify it.
    // Skipped entirely when no Anthropic key is configured.
    if (product == null && input.filePath != null) {
      try {
        if (await lookup.visionEnabled) {
          final visual = await lookup.lookupByImage(input.filePath!);
          if (visual != null) {
            product = visual;
            lookupNote = null;
          }
        }
      } on AiLookupException catch (e) {
        // Surface the reason (e.g. invalid key, offline) rather than hiding it.
        lookupNote = e.message;
      } catch (_) {
        // Other vision errors are best-effort; keep the prior note.
      }
    }

    final kvPairs = parser.parse(
      ocrText: ocrText,
      barcode: barcode,
      productFields: product?.toKvMap(),
    );

    if (lookupNote != null &&
        !kvPairs.any((kv) => kv.key.toLowerCase() == 'product lookup')) {
      kvPairs.add(KeyValue(key: 'Product Lookup', value: lookupNote));
    }

    state = state.copyWith(status: CaptureStatus.done);

    return ResultsArgs(
      barcode: barcode,
      ocrText: ocrText,
      kvPairs: kvPairs,
      inputType: inputType,
      imagePath: filePath,
      productImageUrl: product?.imageUrl,
    );
  }

  /// Runs the Claude-vision "Lookup with AI" on demand for an already-scanned
  /// image and merges any newly-found fields into [existing].
  ///
  /// Throws [AiLookupException] (no key / invalid key / network) so the caller
  /// can show the user exactly why nothing was added.
  Future<List<KeyValue>> lookupWithAi(
      String imagePath, List<KeyValue> existing) async {
    final lookup = ref.read(productLookupProvider);
    final parser = ref.read(kvParserProvider);

    final product = await lookup.lookupByImage(imagePath);
    if (product == null) return existing;

    // Merge: existing pairs win; AI fields only fill gaps. We re-run the parser
    // with the existing values seeded as productFields plus the AI fields so the
    // dedup logic in KvParser handles ordering consistently.
    final seed = <String, String>{
      for (final kv in existing) kv.key: kv.value,
    };
    final merged = parser.parse(
      ocrText: '',
      productFields: {...product.toKvMap(), ...seed},
    );
    return merged;
  }

  void reset() => state = const CaptureState();
}

final captureControllerProvider =
    NotifierProvider<CaptureController, CaptureState>(CaptureController.new);
