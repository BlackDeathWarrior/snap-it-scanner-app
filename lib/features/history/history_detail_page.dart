import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers.dart';
import '../../services/history_repository.dart';

class HistoryDetailPage extends ConsumerWidget {
  final int scanId;
  const HistoryDetailPage({super.key, required this.scanId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(historyRepositoryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Detail'),
        actions: [
          IconButton(
            icon: const Icon(Icons.copy),
            tooltip: 'Copy all',
            onPressed: () => _copyAll(context, repo),
          ),
        ],
      ),
      body: FutureBuilder<ScanRecord?>(
        future: repo.getById(scanId),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final record = snapshot.data;
          if (record == null) {
            return const Center(child: Text('Scan not found.'));
          }
          return _DetailBody(record: record);
        },
      ),
    );
  }

  Future<void> _copyAll(BuildContext context, HistoryRepository repo) async {
    final record = await repo.getById(scanId);
    if (record == null) return;
    final text =
        record.kvPairs.map((kv) => '${kv.key}: ${kv.value}').join('\n');
    await Clipboard.setData(ClipboardData(text: text));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Copied to clipboard')));
    }
  }
}

class _DetailBody extends StatelessWidget {
  final ScanRecord record;
  const _DetailBody({required this.record});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _metaRow('Date', _fmt(record.createdAt)),
        _metaRow('Source', record.inputType),
        if (record.barcodeValue != null) ...[
          _metaRow('Barcode', record.barcodeValue!),
          if (record.barcodeFormat != null)
            _metaRow('Format', record.barcodeFormat!),
        ],
        const Divider(height: 32),
        ...record.kvPairs.map(
          (kv) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 140,
                  child: Text(
                    kv.key,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ),
                Expanded(child: SelectableText(kv.value)),
              ],
            ),
          ),
        ),
        if (record.ocrText != null && record.ocrText!.isNotEmpty) ...[
          const Divider(height: 32),
          Text('Raw OCR Text',
              style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 8),
          SelectableText(record.ocrText!),
        ],
      ],
    );
  }

  Widget _metaRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              child: Text(label,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Expanded(child: Text(value)),
          ],
        ),
      );

  String _fmt(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
      '${dt.day.toString().padLeft(2, '0')} '
      '${dt.hour.toString().padLeft(2, '0')}:'
      '${dt.minute.toString().padLeft(2, '0')}';
}
