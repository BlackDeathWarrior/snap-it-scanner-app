import 'dart:ui' show Offset, Size;
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart'
    as mlkit_bc;
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
    if (input.filePath == null) return null;

    final scanner = mlkit_bc.BarcodeScanner(
      formats: [mlkit_bc.BarcodeFormat.all],
    );
    try {
      final inputImage = mlkit.InputImage.fromFilePath(input.filePath!);
      final barcodes = await scanner.processImage(inputImage);
      if (barcodes.isEmpty) return null;

      final b = barcodes.first;
      return BarcodeResult(
        value: b.rawValue ?? '',
        format: _mapMlkitFormat(b.format),
        corners: b.cornerPoints.isEmpty
            ? null
            : b.cornerPoints
                .map((p) => Offset(p.x.toDouble(), p.y.toDouble()))
                .toList(),
      );
    } finally {
      await scanner.close();
    }
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

  BarcodeFormat _mapMlkitFormat(mlkit_bc.BarcodeFormat fmt) =>
      switch (fmt) {
        mlkit_bc.BarcodeFormat.qrCode => BarcodeFormat.qrCode,
        mlkit_bc.BarcodeFormat.ean13 => BarcodeFormat.ean13,
        mlkit_bc.BarcodeFormat.ean8 => BarcodeFormat.ean8,
        mlkit_bc.BarcodeFormat.code128 => BarcodeFormat.code128,
        mlkit_bc.BarcodeFormat.code39 => BarcodeFormat.code39,
        mlkit_bc.BarcodeFormat.upca => BarcodeFormat.upcA,
        mlkit_bc.BarcodeFormat.upce => BarcodeFormat.upcE,
        mlkit_bc.BarcodeFormat.dataMatrix => BarcodeFormat.dataMatrix,
        mlkit_bc.BarcodeFormat.pdf417 => BarcodeFormat.pdf417,
        mlkit_bc.BarcodeFormat.aztec => BarcodeFormat.aztec,
        mlkit_bc.BarcodeFormat.itf => BarcodeFormat.itf,
        mlkit_bc.BarcodeFormat.codabar => BarcodeFormat.codabar,
        _ => BarcodeFormat.unknown,
      };
}

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
