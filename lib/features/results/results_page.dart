import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../providers.dart';
import '../../services/kv_parser.dart';
import '../../services/product_lookup.dart';
import '../capture/capture_controller.dart';
import '../../ui/app_router.dart';
import '../../ui/theme.dart';

class ResultsPage extends ConsumerStatefulWidget {
  final ResultsArgs args;
  const ResultsPage({super.key, required this.args});

  @override
  ConsumerState<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends ConsumerState<ResultsPage> {
  late List<KeyValue> _kvPairs;
  bool _saved = false;
  bool _aiLoading = false;

  @override
  void initState() {
    super.initState();
    _kvPairs = List.from(widget.args.kvPairs);
  }

  Future<void> _lookupWithAi() async {
    final imagePath = widget.args.imagePath;
    if (imagePath == null || _aiLoading) return;
    setState(() => _aiLoading = true);
    try {
      final merged = await ref
          .read(captureControllerProvider.notifier)
          .lookupWithAi(imagePath, _kvPairs);
      if (!mounted) return;
      setState(() => _kvPairs = merged);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Updated with AI'),
        behavior: SnackBarBehavior.floating,
      ));
    } on AiLookupException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.message),
        behavior: SnackBarBehavior.floating,
        action: e.needsKey
            ? SnackBarAction(
                label: 'Settings',
                onPressed: () => context.push('/settings'),
              )
            : null,
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('AI lookup failed. Please try again.'),
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _aiLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final args = widget.args;
    final productName = _findValue('Product Name') ?? _findValue('Name');
    final brand = _findValue('Brand');
    final hasProductHeader = productName != null || brand != null ||
        args.productImageUrl != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Results'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/capture'),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              children: [
                // Product hero header
                if (hasProductHeader)
                  _ProductHero(
                    name: productName,
                    brand: brand,
                    imageUrl: args.productImageUrl,
                    barcodeValue: args.barcode?.value,
                    barcodeFormat: args.barcode?.format.name,
                  ),

                if (hasProductHeader) const SizedBox(height: 16),

                // Contextual QR actions (open link, WiFi, contact)
                _QrActions(
                  kvPairs: _kvPairs,
                  findValue: _findValue,
                ),

                // AI lookup — identify/extract more fields from the scanned image
                if (args.imagePath != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _AiLookupButton(
                      loading: _aiLoading,
                      onPressed: _lookupWithAi,
                    ),
                  ),

                // KV pair cards
                if (_kvPairs.isEmpty)
                  _EmptyResults(ocrText: args.ocrText)
                else
                  ..._kvPairs.asMap().entries.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _KvCard(
                        kv: e.value,
                        onChanged: (val) => setState(
                            () => _kvPairs[e.key] = _kvPairs[e.key].copyWith(value: val)),
                      ),
                    ),
                  ),

                // Source attribution
                if (_findValue('Source') != null) ...[
                  const SizedBox(height: 8),
                  Center(
                    child: Text(
                      'Product data sourced from ${_findValue('Source')}',
                      style: const TextStyle(
                          color: Colors.white38, fontSize: 11),
                    ),
                  ),
                ],

                const SizedBox(height: 100), // Space for sticky bar
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: _StickyActionBar(
        saved: _saved,
        onSave: _save,
        onCopy: _copyAll,
        onScanAgain: () => context.go('/capture'),
      ),
    );
  }

  Future<void> _save() async {
    final repo = ref.read(historyRepositoryProvider);
    final a = widget.args;
    await repo.save(
      inputType: a.inputType,
      barcodeValue: a.barcode?.value,
      barcodeFormat: a.barcode?.format.name,
      ocrText: a.ocrText,
      kvPairs: _kvPairs,
      productName: _findValue('Product Name') ?? _findValue('Name'),
      productBrand: _findValue('Brand'),
      imagePath: a.imagePath,
    );
    setState(() => _saved = true);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Saved to history'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _copyAll() {
    final text = _kvPairs.map((kv) => '${kv.key}: ${kv.value}').join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String? _findValue(String key) {
    try {
      return _kvPairs
          .firstWhere((kv) => kv.key.toLowerCase() == key.toLowerCase())
          .value;
    } catch (_) {
      return null;
    }
  }
}

// ─── Product hero ─────────────────────────────────────────────────────────────

class _ProductHero extends StatelessWidget {
  final String? name;
  final String? brand;
  final String? imageUrl;
  final String? barcodeValue;
  final String? barcodeFormat;

  const _ProductHero({
    this.name,
    this.brand,
    this.imageUrl,
    this.barcodeValue,
    this.barcodeFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kAccent.withAlpha(60)),
      ),
      child: Row(
        children: [
          // Product image
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: imageUrl != null
                ? Image.network(
                    imageUrl!,
                    width: 72,
                    height: 72,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _imagePlaceholder(),
                  )
                : _imagePlaceholder(),
          ),
          const SizedBox(width: 14),
          // Product info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (brand != null)
                  Text(
                    brand!,
                    style: const TextStyle(
                      color: kAccent,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.8,
                    ),
                  ),
                if (name != null)
                  Text(
                    name!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                if (barcodeValue != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '${barcodeFormat?.toUpperCase() ?? ''} · $barcodeValue',
                    style: const TextStyle(
                        color: Colors.white38,
                        fontSize: 11,
                        fontFamily: 'monospace'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder() {
    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        color: const Color(0xFF2A2A2A),
        borderRadius: BorderRadius.circular(10),
      ),
      child: const Icon(Icons.inventory_2_outlined,
          color: Colors.white24, size: 30),
    );
  }
}

// ─── QR contextual actions ────────────────────────────────────────────────────

class _QrActions extends StatelessWidget {
  final List<KeyValue> kvPairs;
  final String? Function(String key) findValue;

  const _QrActions({required this.kvPairs, required this.findValue});

  @override
  Widget build(BuildContext context) {
    final type = findValue('Type')?.toLowerCase();
    final actions = <Widget>[];

    final url = findValue('URL');
    if ((type == 'url' || url != null) && url != null) {
      actions.add(_ActionButton(
        icon: Icons.open_in_new_rounded,
        label: 'Open link',
        onPressed: () => _openUrl(context, url),
      ));
    }

    if (type == 'wifi') {
      final password = findValue('Password');
      final ssid = findValue('SSID');
      if (password != null) {
        actions.add(_ActionButton(
          icon: Icons.wifi_rounded,
          label: 'Copy password',
          onPressed: () => _copy(context, password,
              'WiFi password${ssid != null ? ' for $ssid' : ''} copied'),
        ));
      }
    }

    if (type == 'vcard') {
      actions.add(_ActionButton(
        icon: Icons.person_add_alt_rounded,
        label: 'Share contact',
        onPressed: () => _shareContact(kvPairs),
      ));
    }

    if (actions.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Wrap(spacing: 8, runSpacing: 8, children: actions),
    );
  }

  Future<void> _openUrl(BuildContext context, String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not open link'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _copy(BuildContext context, String value, String msg) async {
    await Clipboard.setData(ClipboardData(text: value));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _shareContact(List<KeyValue> pairs) async {
    final text = pairs
        .where((kv) => kv.key.toLowerCase() != 'type')
        .map((kv) => '${kv.key}: ${kv.value}')
        .join('\n');
    await Share.share(text, subject: 'Contact');
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

/// Full-width "Lookup with AI" button that identifies/extracts extra fields
/// from the scanned image. Shows a spinner while the request is in flight.
class _AiLookupButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _AiLookupButton({required this.loading, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: kAccent.withAlpha(40),
          foregroundColor: kAccent,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: kAccent),
              )
            : const Icon(Icons.auto_awesome_rounded, size: 18),
        label: Text(loading ? 'Looking up…' : 'Lookup with AI'),
      ),
    );
  }
}

// ─── KV card ──────────────────────────────────────────────────────────────────

class _KvCard extends StatelessWidget {
  final KeyValue kv;
  final ValueChanged<String> onChanged;

  const _KvCard({required this.kv, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2A2A2A)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Key chip
            Container(
              constraints: const BoxConstraints(maxWidth: 130),
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: kAccent.withAlpha(25),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: kAccent.withAlpha(60)),
              ),
              child: Text(
                kv.key,
                style: const TextStyle(
                  color: kAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 12),
            // Editable value
            Expanded(
              child: _EditableValue(value: kv.value, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Editable value ───────────────────────────────────────────────────────────

class _EditableValue extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;

  const _EditableValue({required this.value, required this.onChanged});

  @override
  State<_EditableValue> createState() => _EditableValueState();
}

class _EditableValueState extends State<_EditableValue> {
  bool _editing = false;
  late TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.value);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_editing) {
      return TextField(
        controller: _ctrl,
        autofocus: true,
        style: const TextStyle(color: Colors.white, fontSize: 14),
        onSubmitted: (v) {
          widget.onChanged(v);
          setState(() => _editing = false);
        },
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          suffixIcon: IconButton(
            icon: const Icon(Icons.check_rounded, color: kAccent, size: 18),
            onPressed: () {
              widget.onChanged(_ctrl.text);
              setState(() => _editing = false);
            },
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => setState(() => _editing = true),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.value,
              style: const TextStyle(color: Colors.white, fontSize: 14),
            ),
          ),
          const SizedBox(width: 4),
          const Icon(Icons.edit_outlined,
              size: 13, color: Colors.white30),
        ],
      ),
    );
  }
}

// ─── Empty results ────────────────────────────────────────────────────────────

class _EmptyResults extends StatelessWidget {
  final String ocrText;
  const _EmptyResults({required this.ocrText});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 56, color: Colors.white24),
          const SizedBox(height: 12),
          const Text('No structured data found',
              style: TextStyle(color: Colors.white54)),
          if (ocrText.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF1A1A1A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF2A2A2A)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Raw OCR text',
                      style: TextStyle(
                          color: kAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  SelectableText(ocrText,
                      style: const TextStyle(
                          color: Colors.white70, fontSize: 13)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Sticky action bar ────────────────────────────────────────────────────────

class _StickyActionBar extends StatelessWidget {
  final bool saved;
  final VoidCallback onSave;
  final VoidCallback onCopy;
  final VoidCallback onScanAgain;

  const _StickyActionBar({
    required this.saved,
    required this.onSave,
    required this.onCopy,
    required this.onScanAgain,
  });

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, bottom + 12),
      decoration: const BoxDecoration(
        color: Color(0xFF1A1A1A),
        border: Border(top: BorderSide(color: Color(0xFF2A2A2A))),
      ),
      child: Row(
        children: [
          // Save
          Expanded(
            child: OutlinedButton.icon(
              onPressed: saved ? null : onSave,
              icon: Icon(
                saved ? Icons.check_rounded : Icons.bookmark_add_outlined,
                size: 18,
              ),
              label: Text(saved ? 'Saved' : 'Save'),
            ),
          ),
          const SizedBox(width: 8),
          // Copy
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onCopy,
              icon: const Icon(Icons.copy_rounded, size: 18),
              label: const Text('Copy'),
            ),
          ),
          const SizedBox(width: 8),
          // Scan Again
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed: onScanAgain,
              icon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
              label: const Text('Scan Again'),
            ),
          ),
        ],
      ),
    );
  }
}
