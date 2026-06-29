import 'dart:ui' show Size;
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'
    as mlkit;
import 'package:mobile_scanner/mobile_scanner.dart' as ms;
import '../scan_engine.dart';

class MobileScanEngine implements ScanEngine {
  final _textRecognizer = mlkit.TextRecognizer(
    script: mlkit.TextRecognitionScript.latin,
  );

  @override
  bool get supportsLiveCamera => true;

  @override
  Future<BarcodeResult?> scanBarcode(ScanInput input) async {
    // Live camera scanning is handled by the MobileScanner widget directly.
    // This method handles still-image barcode decode for gallery/file paths.
    if (input.filePath == null) return null;
    final analyzer = ms.MobileScannerController();
    // flutter_mobile_scanner doesn't expose a static decode API cleanly;
    // for still images on mobile we fall back to null and rely on live camera.
    // Gallery barcode decode is a stretch goal on mobile.
    analyzer.dispose();
    return null;
  }

  @override
  Future<String> recognizeText(ScanInput input) async {
    final mlkitImage = input.filePath != null
        ? mlkit.InputImage.fromFilePath(input.filePath!)
        : mlkit.InputImage.fromBytes(
            bytes: input.bytes!,
            metadata: mlkit.InputImageMetadata(
              size: input.width != null && input.height != null
                  ? Size(input.width!.toDouble(), input.height!.toDouble())
                  : const Size(640, 480),
              rotation: mlkit.InputImageRotation.rotation0deg,
              format: mlkit.InputImageFormat.nv21,
              bytesPerRow: input.width ?? 640,
            ),
          );
    final result = await _textRecognizer.processImage(mlkitImage);
    return result.text;
  }

  @override
  void dispose() {
    _textRecognizer.close();
  }
}

// Convenience: map mobile_scanner BarcodeFormat → our BarcodeFormat
BarcodeFormat mapMsFormat(ms.BarcodeFormat fmt) {
  return switch (fmt) {
    ms.BarcodeFormat.qrCode => BarcodeFormat.qrCode,
    ms.BarcodeFormat.ean13 => BarcodeFormat.ean13,
    ms.BarcodeFormat.ean8 => BarcodeFormat.ean8,
    ms.BarcodeFormat.code128 => BarcodeFormat.code128,
    ms.BarcodeFormat.code39 => BarcodeFormat.code39,
    ms.BarcodeFormat.upcA => BarcodeFormat.upcA,
    ms.BarcodeFormat.upcE => BarcodeFormat.upcE,
    ms.BarcodeFormat.dataMatrix => BarcodeFormat.dataMatrix,
    ms.BarcodeFormat.pdf417 => BarcodeFormat.pdf417,
    ms.BarcodeFormat.aztec => BarcodeFormat.aztec,
    ms.BarcodeFormat.itf14 => BarcodeFormat.itf,
    ms.BarcodeFormat.codabar => BarcodeFormat.codabar,
    _ => BarcodeFormat.unknown,
  };
}
