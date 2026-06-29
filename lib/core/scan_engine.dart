import 'dart:typed_data';

enum BarcodeFormat {
  qrCode,
  ean13,
  ean8,
  code128,
  code39,
  upcA,
  upcE,
  dataMatrix,
  pdf417,
  aztec,
  itf,
  codabar,
  unknown,
}

class BarcodeResult {
  final String value;
  final BarcodeFormat format;

  const BarcodeResult({required this.value, required this.format});
}

class ScanInput {
  final Uint8List? bytes;
  final String? filePath;
  final int? width;
  final int? height;

  const ScanInput.fromBytes({
    required Uint8List this.bytes,
    this.width,
    this.height,
  }) : filePath = null;

  const ScanInput.fromPath(String this.filePath)
      : bytes = null,
        width = null,
        height = null;
}

abstract class ScanEngine {
  Future<BarcodeResult?> scanBarcode(ScanInput input);
  Future<String> recognizeText(ScanInput input);
  bool get supportsLiveCamera;
  void dispose() {}
}
