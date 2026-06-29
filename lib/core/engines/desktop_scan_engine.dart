import 'package:flutter_zxing/flutter_zxing.dart' show zx, DecodeParams, Format;
import '../scan_engine.dart';

class DesktopScanEngine implements ScanEngine {
  @override
  bool get supportsLiveCamera => false;

  @override
  Future<BarcodeResult?> scanBarcode(ScanInput input) async {
    final path = input.filePath;
    if (path == null) return null; // bytes-only input not supported on desktop MVP

    final code = await zx.readBarcodeImagePathString(
      path,
      DecodeParams(format: Format.any, tryHarder: true, tryRotate: true),
    );
    if (!code.isValid || code.text == null) return null;

    return BarcodeResult(
      value: code.text!,
      format: _mapFormat(code.format ?? Format.none),
    );
  }

  @override
  Future<String> recognizeText(ScanInput input) async {
    // Tesseract integration requires bundling eng.traineddata — post-MVP.
    return '';
  }

  @override
  void dispose() {}

  BarcodeFormat _mapFormat(int fmt) => switch (fmt) {
        Format.qrCode => BarcodeFormat.qrCode,
        Format.ean13 => BarcodeFormat.ean13,
        Format.ean8 => BarcodeFormat.ean8,
        Format.code128 => BarcodeFormat.code128,
        Format.code39 => BarcodeFormat.code39,
        Format.upca => BarcodeFormat.upcA,
        Format.upce => BarcodeFormat.upcE,
        Format.dataMatrix => BarcodeFormat.dataMatrix,
        Format.pdf417 => BarcodeFormat.pdf417,
        Format.aztec => BarcodeFormat.aztec,
        Format.itf => BarcodeFormat.itf,
        Format.codabar => BarcodeFormat.codabar,
        _ => BarcodeFormat.unknown,
      };
}
