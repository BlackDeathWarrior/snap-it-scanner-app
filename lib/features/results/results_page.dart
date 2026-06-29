import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers.dart';
import '../../services/kv_parser.dart';
import '../../ui/app_router.dart';

class ResultsPage extends ConsumerStatefulWidget {
  final ResultsArgs args;
  const ResultsPage({super.key, required this.args});

  @override
  ConsumerState<ResultsPage> createState() => _ResultsPageState();
}

class _ResultsPageState extends ConsumerState<ResultsPage> {
  late List<KeyValue> _kvPairs;
  bool _saved = false;

  @override
  void initState() {
    super.initState();
    _kvPairs = List.from(widget.args.kvPairs);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Results'),
        actions: [
          if (!_saved)
            IconButton(
              icon: const Icon(Icons.save),
              tooltip: 'Save to history',
              onPressed: _save,
            ),
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy all',
            onPressed: _copyAll,
          ),
        ],
      ),
      body: _kvPairs.isEmpty
          ? _EmptyResults(ocrText: widget.args.ocrText)
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _kvPairs.length,
              separatorBuilder: (context, i) => const SizedBox(height: 8),
              itemBuilder: (context, i) => _KvCard(
                kv: _kvPairs[i],
                onChanged: (val) =>
                    setState(() => _kvPairs[i] = _kvPairs[i].copyWith(value: val)),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/capture'),
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Scan Again'),
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
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Saved to history')));
    }
  }

  void _copyAll() {
    final text = _kvPairs.map((kv) => '${kv.key}: ${kv.value}').join('\n');
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
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

class _KvCard extends StatelessWidget {
  final KeyValue kv;
  final ValueChanged<String> onChanged;

  const _KvCard({required this.kv, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 130,
              child: Text(
                kv.key,
                style: Theme.of(context)
                    .textTheme
                    .labelMedium
                    ?.copyWith(color: Theme.of(context).colorScheme.primary),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _EditableValue(value: kv.value, onChanged: onChanged),
            ),
          ],
        ),
      ),
    );
  }
}

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
        onSubmitted: (v) {
          widget.onChanged(v);
          setState(() => _editing = false);
        },
        decoration: InputDecoration(
          suffixIcon: IconButton(
            icon: const Icon(Icons.check),
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
          Expanded(child: Text(widget.value)),
          Icon(Icons.edit, size: 14, color: Theme.of(context).colorScheme.outline),
        ],
      ),
    );
  }
}

class _EmptyResults extends StatelessWidget {
  final String ocrText;
  const _EmptyResults({required this.ocrText});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off, size: 64),
            const SizedBox(height: 16),
            const Text('No structured data found.'),
            if (ocrText.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text('Raw OCR text:', style: Theme.of(context).textTheme.labelMedium),
              const SizedBox(height: 8),
              SelectableText(ocrText),
            ],
          ],
        ),
      ),
    );
  }
}
