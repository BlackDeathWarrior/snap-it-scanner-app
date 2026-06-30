import 'dart:io';
import 'dart:math' show max;
import 'package:desktop_drop/desktop_drop.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../core/engines/mobile_scan_engine.dart';
import '../../core/scan_engine.dart';
import '../../ui/theme.dart';
import '../../ui/app_router.dart';
import 'capture_controller.dart';

class CapturePage extends ConsumerStatefulWidget {
  const CapturePage({super.key});

  @override
  ConsumerState<CapturePage> createState() => _CapturePageState();
}

class _CapturePageState extends ConsumerState<CapturePage>
    with WidgetsBindingObserver {
  MobileScannerController? _cameraController;
  bool _isDragging = false;

  // Pending confirm state
  BarcodeCapture? _pendingCapture; // live camera detected barcode
  ResultsArgs? _pendingImageArgs; // still-image processed result

  bool get _hasPending => _pendingCapture != null || _pendingImageArgs != null;

  @override
  void initState() {
    super.initState();
    if (!Platform.isWindows) {
      _cameraController = MobileScannerController();
      WidgetsBinding.instance.addObserver(this);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (!_hasPending) controller.start();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        controller.stop();
    }
  }

  @override
  void dispose() {
    if (!Platform.isWindows) {
      WidgetsBinding.instance.removeObserver(this);
    }
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
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Main camera or desktop drop zone
          _buildBody(context),

          // Viewfinder corner brackets (hidden when confirm overlay is showing)
          if (!_hasPending && !Platform.isWindows)
            const _ViewfinderOverlay(),

          // Top bar — always visible
          _TopBar(
            onHistory: () => context.push('/history'),
            onSettings: () => context.push('/settings'),
          ),

          // Bottom bar — shutter, gallery, manual entry, hint text
          if (!_hasPending && !Platform.isWindows)
            _BottomBar(
              onShutter: _capturePhoto,
              onGallery: _pickGallery,
              onManualEntry: _enterManualBarcode,
              isProcessing: isProcessing,
            ),

          // Processing spinner
          if (isProcessing)
            const ColoredBox(
              color: Colors.black54,
              child: Center(
                child: CircularProgressIndicator(color: kAccent),
              ),
            ),

          // Live camera confirm overlay
          if (_pendingCapture != null)
            _LiveConfirmOverlay(
              capture: _pendingCapture!,
              cameraSize: _cameraController?.value.size ?? Size.zero,
              isProcessing: isProcessing,
              onConfirm: _onConfirmLive,
              onCancel: _onCancelLive,
            ),

          // Still-image confirm overlay
          if (_pendingImageArgs != null)
            _ImageConfirmOverlay(
              args: _pendingImageArgs!,
              onConfirm: _onConfirmImage,
              onCancel: _onCancelImage,
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
        onPickFile: _pickGallery,
        onManualEntry: _enterManualBarcode,
      );
    }
    return MobileScanner(
      controller: _cameraController!,
      onDetect: _handleBarcode,
      fit: BoxFit.cover,
    );
  }

  void _handleBarcode(BarcodeCapture capture) {
    if (_hasPending) return; // ignore if already pending
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;
    // Do NOT stop the camera here — calling stop() inside the onDetect
    // callback crashes mobile_scanner. The _hasPending guard above already
    // prevents re-processing while the confirm overlay (which dims the live
    // preview) is shown.
    setState(() => _pendingCapture = capture);
  }

  Future<void> _handleFilePath(String path) async {
    final result =
        await ref.read(captureControllerProvider.notifier).processFile(path);
    if (result != null && mounted) {
      setState(() => _pendingImageArgs = result);
    }
  }

  Future<void> _pickGallery() async {
    final result =
        await ref.read(captureControllerProvider.notifier).pickFromGallery();
    if (result != null && mounted) {
      setState(() => _pendingImageArgs = result);
    }
  }

  Future<void> _onConfirmLive() async {
    final cap = _pendingCapture!;
    final ms = cap.barcodes.first;
    final barcode = BarcodeResult(
      value: ms.rawValue!,
      format: mapMsFormat(ms.format),
      corners: ms.corners,
    );
    final result = await ref
        .read(captureControllerProvider.notifier)
        .confirmLiveBarcode(barcode);
    if (result != null && mounted) {
      setState(() => _pendingCapture = null);
      _navigate(result);
    }
  }

  void _onCancelLive() {
    // Camera was never stopped, so nothing to restart — just clear the overlay.
    setState(() => _pendingCapture = null);
    ref.read(captureControllerProvider.notifier).reset();
  }

  void _onConfirmImage() {
    final args = _pendingImageArgs!;
    setState(() => _pendingImageArgs = null);
    _navigate(args);
  }

  void _onCancelImage() {
    setState(() => _pendingImageArgs = null);
    ref.read(captureControllerProvider.notifier).reset();
  }

  void _navigate(ResultsArgs args) {
    // Safe to stop here — we're outside the onDetect callback. Resume when the
    // results route is popped so the user returns to a live preview.
    _cameraController?.stop();
    context.push('/results', extra: args).then((_) {
      if (mounted && !_hasPending) _cameraController?.start();
    });
  }

  Future<void> _capturePhoto() async {
    final result =
        await ref.read(captureControllerProvider.notifier).captureFromCamera();
    if (result != null && mounted) {
      setState(() => _pendingImageArgs = result);
    }
  }

  Future<void> _enterManualBarcode() async {
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => const _ManualEntryDialog(),
    );
    if (code == null || code.trim().isEmpty) return;
    final result = await ref
        .read(captureControllerProvider.notifier)
        .processManualBarcode(code);
    if (result != null && mounted) _navigate(result);
  }
}

// ─── Top bar ──────────────────────────────────────────────────────────────────

class _TopBar extends StatelessWidget {
  final VoidCallback onHistory;
  final VoidCallback onSettings;
  const _TopBar({required this.onHistory, required this.onSettings});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
            top: top + 8, left: 20, right: 8, bottom: 16),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Row(
          children: [
            const Text(
              'ScanKit',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: kAccent.withAlpha(40),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kAccent.withAlpha(100)),
              ),
              child: const Text(
                'BETA',
                style: TextStyle(
                    color: kAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.bold),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.history_rounded, color: Colors.white),
              tooltip: 'History',
              onPressed: onHistory,
            ),
            IconButton(
              icon: const Icon(Icons.settings_rounded, color: Colors.white),
              tooltip: 'Settings',
              onPressed: onSettings,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Bottom bar ───────────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final VoidCallback onShutter;
  final VoidCallback onGallery;
  final VoidCallback onManualEntry;
  final bool isProcessing;
  const _BottomBar({
    required this.onShutter,
    required this.onGallery,
    required this.onManualEntry,
    required this.isProcessing,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
            bottom: bottom + 24, top: 28, left: 24, right: 24),
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            colors: [Colors.black87, Colors.transparent],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Aim at a barcode or QR code — or tap the shutter to snap a photo',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white54, fontSize: 13),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                _CircleAction(
                  icon: Icons.photo_library_outlined,
                  label: 'Gallery',
                  onPressed: isProcessing ? null : onGallery,
                ),
                _ShutterButton(
                  onPressed: isProcessing ? null : onShutter,
                  isProcessing: isProcessing,
                ),
                _CircleAction(
                  icon: Icons.keyboard_outlined,
                  label: 'Enter code',
                  onPressed: isProcessing ? null : onManualEntry,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShutterButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isProcessing;
  const _ShutterButton({required this.onPressed, required this.isProcessing});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 74,
        height: 74,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white70, width: 4),
        ),
        padding: const EdgeInsets.all(5),
        child: Container(
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white,
          ),
          child: isProcessing
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(
                      color: Colors.black54, strokeWidth: 2),
                )
              : const Icon(Icons.camera_alt_rounded,
                  color: Colors.black87, size: 28),
        ),
      ),
    );
  }
}

class _CircleAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  const _CircleAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final color = enabled ? Colors.white70 : Colors.white24;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: Icon(icon, color: color, size: 26),
          style: IconButton.styleFrom(
            backgroundColor: Colors.white.withAlpha(20),
            padding: const EdgeInsets.all(14),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(color: color, fontSize: 11)),
      ],
    );
  }
}

// ─── Manual barcode entry dialog ──────────────────────────────────────────────

class _ManualEntryDialog extends StatefulWidget {
  const _ManualEntryDialog();

  @override
  State<_ManualEntryDialog> createState() => _ManualEntryDialogState();
}

class _ManualEntryDialogState extends State<_ManualEntryDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF1A1A1A),
      title: const Text('Enter barcode',
          style: TextStyle(color: Colors.white)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.text,
        style: const TextStyle(color: Colors.white),
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(
          hintText: 'e.g. 0123456789012',
          hintStyle: TextStyle(color: Colors.white38),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel',
              style: TextStyle(color: Colors.white54)),
        ),
        FilledButton(onPressed: _submit, child: const Text('Look up')),
      ],
    );
  }
}

// ─── Viewfinder overlay ───────────────────────────────────────────────────────

class _ViewfinderOverlay extends StatelessWidget {
  const _ViewfinderOverlay();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _ViewfinderPainter());
  }
}

class _ViewfinderPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kAccent
      ..strokeWidth = 3.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    const margin = 56.0;
    const cornerLen = 28.0;
    final rect = Rect.fromLTWH(
        margin, size.height * 0.18, size.width - margin * 2,
        size.height * 0.52);

    void drawCorner(Offset corner, Offset dx, Offset dy) {
      canvas.drawLine(corner, corner + dx, paint);
      canvas.drawLine(corner, corner + dy, paint);
    }

    drawCorner(rect.topLeft, const Offset(cornerLen, 0),
        const Offset(0, cornerLen));
    drawCorner(rect.topRight, const Offset(-cornerLen, 0),
        const Offset(0, cornerLen));
    drawCorner(rect.bottomLeft, const Offset(cornerLen, 0),
        const Offset(0, -cornerLen));
    drawCorner(rect.bottomRight, const Offset(-cornerLen, 0),
        const Offset(0, -cornerLen));

    // Subtle dim outside viewfinder
    final dimPaint = Paint()..color = Colors.black.withAlpha(100);
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, rect.top), dimPaint);
    canvas.drawRect(
        Rect.fromLTWH(0, rect.bottom, size.width, size.height - rect.bottom),
        dimPaint);
    canvas.drawRect(
        Rect.fromLTWH(0, rect.top, rect.left, rect.height), dimPaint);
    canvas.drawRect(
        Rect.fromLTWH(rect.right, rect.top, size.width - rect.right,
            rect.height),
        dimPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// ─── Live camera confirm overlay ──────────────────────────────────────────────

class _LiveConfirmOverlay extends StatelessWidget {
  final BarcodeCapture capture;
  final Size cameraSize;
  final bool isProcessing;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _LiveConfirmOverlay({
    required this.capture,
    required this.cameraSize,
    required this.isProcessing,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final barcode = capture.barcodes.first;
    final corners = barcode.corners;
    final bottom = MediaQuery.of(context).padding.bottom;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Dim overlay
        ColoredBox(color: Colors.black.withAlpha(120)),

        // Bounding box
        LayoutBuilder(
          builder: (context, constraints) {
            return CustomPaint(
              painter: _BarcodeBoundsPainter(
                corners: corners,
                cameraSize: cameraSize.isEmpty ? constraints.biggest : cameraSize,
                widgetSize: constraints.biggest,
              ),
            );
          },
        ),

        // Top badge
        Positioned(
          top: MediaQuery.of(context).padding.top + 64,
          left: 24,
          right: 24,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: kAccent.withAlpha(230),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.black, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    '${barcode.format.name.toUpperCase()} detected',
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Barcode value preview
        Positioned(
          bottom: bottom + 160,
          left: 24,
          right: 24,
          child: Center(
            child: Text(
              barcode.rawValue ?? '',
              style: const TextStyle(
                  color: Colors.white70, fontSize: 13,
                  fontFamily: 'monospace'),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ),

        // Confirm / Cancel buttons
        Positioned(
          bottom: bottom + 40,
          left: 24,
          right: 24,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isProcessing ? null : onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Try Again'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: isProcessing ? null : onConfirm,
                  icon: isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.black, strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded, size: 20),
                  label: Text(isProcessing ? 'Looking up…' : 'Confirm Scan'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Still-image confirm overlay ──────────────────────────────────────────────

class _ImageConfirmOverlay extends StatelessWidget {
  final ResultsArgs args;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ImageConfirmOverlay({
    required this.args,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    final hasImage = args.imagePath != null;
    final pairCount = args.kvPairs.length;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Image preview
        if (hasImage)
          Image.file(File(args.imagePath!), fit: BoxFit.cover)
        else
          const ColoredBox(color: Colors.black87),

        // Dark gradient overlay
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Colors.black54, Colors.black87],
            ),
          ),
        ),

        // Top status badge
        Positioned(
          top: MediaQuery.of(context).padding.top + 64,
          left: 24,
          right: 24,
          child: Center(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: kAccent.withAlpha(230),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: Colors.black, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    pairCount > 0
                        ? 'Found $pairCount data field${pairCount == 1 ? '' : 's'}'
                        : 'No structured data found',
                    style: const TextStyle(
                        color: Colors.black, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            ),
          ),
        ),

        // Barcode value
        if (args.barcode != null)
          Positioned(
            bottom: bottom + 160,
            left: 24,
            right: 24,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${args.barcode!.format.name.toUpperCase()} · ${args.barcode!.value}',
                    style: const TextStyle(
                        color: Colors.white70, fontSize: 13,
                        fontFamily: 'monospace'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),

        // Confirm / Cancel buttons
        Positioned(
          bottom: bottom + 40,
          left: 24,
          right: 24,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white38),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Try Again'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: onConfirm,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  label: const Text('View Results'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Bounding box painter ─────────────────────────────────────────────────────

class _BarcodeBoundsPainter extends CustomPainter {
  final List<Offset>? corners;
  final Size cameraSize;
  final Size widgetSize;

  const _BarcodeBoundsPainter({
    required this.corners,
    required this.cameraSize,
    required this.widgetSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pts = corners;
    if (pts == null || pts.length < 4 || cameraSize.isEmpty) {
      _drawCenterFallback(canvas, size);
      return;
    }

    // Transform corners from camera-image space to widget space (BoxFit.cover).
    final scaleX = size.width / cameraSize.width;
    final scaleY = size.height / cameraSize.height;
    final scale = max(scaleX, scaleY);
    final offsetX = (size.width - cameraSize.width * scale) / 2;
    final offsetY = (size.height - cameraSize.height * scale) / 2;

    final screen = pts
        .map((c) => Offset(c.dx * scale + offsetX, c.dy * scale + offsetY))
        .toList();

    final path = Path()..moveTo(screen[0].dx, screen[0].dy);
    for (final c in screen.skip(1)) {
      path.lineTo(c.dx, c.dy);
    }
    path.close();

    // Glow
    canvas.drawPath(
      path,
      Paint()
        ..color = kAccent.withAlpha(70)
        ..strokeWidth = 14
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    // Solid outline
    canvas.drawPath(
      path,
      Paint()
        ..color = kAccent
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
  }

  void _drawCenterFallback(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height / 2),
      width: size.width * 0.65,
      height: size.height * 0.25,
    );
    final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(12));
    canvas.drawRRect(
      rrect,
      Paint()
        ..color = kAccent
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant _BarcodeBoundsPainter old) =>
      old.corners != corners;
}

// ─── Desktop drop zone ────────────────────────────────────────────────────────

class _DesktopDropZone extends StatelessWidget {
  final bool isDragging;
  final ValueChanged<bool> onDraggingChanged;
  final ValueChanged<String> onFilePath;
  final VoidCallback onPickFile;
  final VoidCallback onManualEntry;

  const _DesktopDropZone({
    required this.isDragging,
    required this.onDraggingChanged,
    required this.onFilePath,
    required this.onPickFile,
    required this.onManualEntry,
  });

  @override
  Widget build(BuildContext context) {
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
            ? kAccent.withAlpha(15)
            : const Color(0xFF0D0D0D),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(28),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDragging ? kAccent : const Color(0xFF2A2A2A),
                    width: 2,
                  ),
                  color: isDragging
                      ? kAccent.withAlpha(20)
                      : const Color(0xFF1A1A1A),
                ),
                child: Icon(
                  isDragging
                      ? Icons.download_rounded
                      : Icons.image_search_rounded,
                  size: 52,
                  color: isDragging ? kAccent : Colors.white38,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                isDragging
                    ? 'Drop image here'
                    : 'Drag & drop a product image',
                style: TextStyle(
                  color: isDragging ? kAccent : Colors.white70,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (!isDragging) ...[
                const SizedBox(height: 6),
                const Text(
                  'or pick from files',
                  style: TextStyle(color: Colors.white38, fontSize: 14),
                ),
              ],
              const SizedBox(height: 28),
              FilledButton.icon(
                onPressed: onPickFile,
                icon: const Icon(Icons.folder_open_rounded, size: 18),
                label: const Text('Browse Files'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
              const SizedBox(height: 12),
              TextButton.icon(
                onPressed: onManualEntry,
                icon: const Icon(Icons.keyboard_outlined,
                    size: 18, color: Colors.white54),
                label: const Text('Enter barcode manually',
                    style: TextStyle(color: Colors.white54)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
