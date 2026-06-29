import 'dart:io';
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/engines/mobile_scan_engine.dart';
import '../../core/scan_engine.dart';
import 'capture_controller.dart';

class CapturePage extends ConsumerStatefulWidget {
  const CapturePage({super.key});

  @override
  ConsumerState<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends ConsumerState<CapturePage> {
  MobileScannerController? _cameraController;
  bool _isDragging = false;

  @override
  void initState() {
    super.initState();
    if (!Platform.isWindows) {
      _cameraController = MobileScannerController();
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(captureControllerProvider);
    final isProcessing = state.status == CaptureStatus.processing;

    ref.listen<CaptureState>(captureControllerProvider, (_, next) {
      if (next.status == CaptureStatus.error && next.errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(next.errorMessage!),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ));
        ref.read(captureControllerProvider.notifier).reset();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode & Label Scanner'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'History',
            onPressed: () => context.push('/history'),
          ),
        ],
      ),
      body: Stack(
        children: [
          _buildBody(context),
          if (isProcessing)
            const ColoredBox(
              color: Colors.black38,
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (Platform.isWindows) {
      return _DesktopDropZone(
        isDragging: _isDragging,
        onDraggingChanged: (v) => setState(() => _isDragging = v),
        onFilePath: _handleFilePath,
        onPickGallery: _pickGallery,
      );
    }
    return _MobileCameraView(
      controller: _cameraController!,
      onBarcodeDetected: _handleBarcode,
      onPickGallery: _pickGallery,
    );
  }

  void _handleBarcode(BarcodeCapture capture) {
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    _cameraController?.stop();
    final result = ref.read(captureControllerProvider.notifier).barcodeScanned(
          BarcodeResult(
            value: barcode!.rawValue!,
            format: mapMsFormat(barcode.format),
          ),
        );
    _navigate(result);
  }

  Future<void> _handleFilePath(String path) async {
    final result =
        await ref.read(captureControllerProvider.notifier).processFile(path);
    if (result != null && mounted) _navigate(result);
  }

  Future<void> _pickGallery() async {
    final result =
        await ref.read(captureControllerProvider.notifier).pickFromGallery();
    if (result != null && mounted) _navigate(result);
  }

  void _navigate(dynamic args) {
    context.push('/results', extra: args);
    ref.read(captureControllerProvider.notifier).reset();
    _cameraController?.start();
  }
}

class _MobileCameraView extends StatelessWidget {
  final MobileScannerController controller;
  final void Function(BarcodeCapture) onBarcodeDetected;
  final VoidCallback onPickGallery;

  const _MobileCameraView({
    required this.controller,
    required this.onBarcodeDetected,
    required this.onPickGallery,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: MobileScanner(
            controller: controller,
            onDetect: onBarcodeDetected,
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: onPickGallery,
                  icon: const Icon(Icons.photo_library),
                  label: const Text('Pick from Gallery'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DesktopDropZone extends StatelessWidget {
  final bool isDragging;
  final ValueChanged<bool> onDraggingChanged;
  final ValueChanged<String> onFilePath;
  final VoidCallback onPickGallery;

  const _DesktopDropZone({
    required this.isDragging,
    required this.onDraggingChanged,
    required this.onFilePath,
    required this.onPickGallery,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DropTarget(
      onDragEntered: (_) => onDraggingChanged(true),
      onDragExited: (_) => onDraggingChanged(false),
      onDragDone: (detail) {
        onDraggingChanged(false);
        final file = detail.files.firstOrNull;
        if (file != null) onFilePath(file.path);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        color: isDragging
            ? cs.primaryContainer.withValues(alpha: 0.3)
            : cs.surface,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDragging ? Icons.download : Icons.image_search,
                size: 80,
                color: isDragging ? cs.primary : cs.outline,
              ),
              const SizedBox(height: 16),
              Text(
                isDragging
                    ? 'Drop image here'
                    : 'Drag & drop a product image\nor pick from files',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onPickGallery,
                icon: const Icon(Icons.folder_open),
                label: const Text('Browse Files'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
