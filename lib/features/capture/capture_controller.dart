import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/scan_engine.dart';
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
          status: CaptureStatus.error, errorMessage: e.toString());
      return null;
    }
  }

  Future<ResultsArgs?> pickFromGallery() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(source: ImageSource.gallery);
    if (xfile == null) return null;

    state = state.copyWith(status: CaptureStatus.processing);
    try {
      return await _run(ScanInput.fromPath(xfile.path), xfile.path, 'gallery');
    } catch (e) {
      state = state.copyWith(
          status: CaptureStatus.error, errorMessage: e.toString());
      return null;
    }
  }

  ResultsArgs barcodeScanned(BarcodeResult barcode) {
    final kvPairs = ref.read(kvParserProvider).parse(
          ocrText: '',
          barcode: barcode,
        );
    return ResultsArgs(
      barcode: barcode,
      ocrText: '',
      kvPairs: kvPairs,
      inputType: 'camera',
    );
  }

  Future<ResultsArgs> _run(
      ScanInput input, String filePath, String inputType) async {
    final engine = ref.read(scanEngineProvider);
    final parser = ref.read(kvParserProvider);
    final lookup = ref.read(productLookupProvider);

    final barcode = await engine.scanBarcode(input);
    final ocrText = await engine.recognizeText(input);

    ProductInfo? product;
    if (barcode != null) {
      product = await lookup.lookup(barcode.value);
    }

    final kvPairs = parser.parse(
      ocrText: ocrText,
      barcode: barcode,
      productFields: product?.toKvMap(),
    );

    state = state.copyWith(status: CaptureStatus.done);

    return ResultsArgs(
      barcode: barcode,
      ocrText: ocrText,
      kvPairs: kvPairs,
      inputType: inputType,
      imagePath: filePath,
    );
  }

  void reset() => state = const CaptureState();
}

final captureControllerProvider =
    NotifierProvider<CaptureController, CaptureState>(CaptureController.new);
