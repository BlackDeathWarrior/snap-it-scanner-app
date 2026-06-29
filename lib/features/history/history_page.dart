import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../providers.dart';
import '../../services/history_repository.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(historyRepositoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Scan History')),
      body: StreamBuilder<List<ScanRecord>>(
        stream: repo.watchAll(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data ?? [];
          if (records.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.history, size: 64),
                  SizedBox(height: 16),
                  Text('No scans saved yet.'),
                ],
              ),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: records.length,
            separatorBuilder: (context, i) => const SizedBox(height: 8),
            itemBuilder: (context, i) =>
                _HistoryTile(record: records[i], repo: repo),
          );
        },
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final ScanRecord record;
  final HistoryRepository repo;

  const _HistoryTile({required this.record, required this.repo});

  @override
  Widget build(BuildContext context) {
    final title = record.productName ??
        record.barcodeValue ??
        record.kvPairs.firstOrNull?.value ??
        'Scan #${record.id}';

    final subtitle = [
      if (record.productBrand != null) record.productBrand!,
      _formatDate(record.createdAt),
    ].join(' · ');

    return Card(
      child: ListTile(
        leading: _inputIcon(record.inputType),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete',
          onPressed: () => _confirmDelete(context),
        ),
        onTap: () => context.push('/history/${record.id}'),
      ),
    );
  }

  Widget _inputIcon(String type) {
    return Icon(switch (type) {
      'camera' => Icons.camera_alt,
      'gallery' => Icons.photo_library,
      _ => Icons.folder_open,
    });
  }

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete scan?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) await repo.delete(record.id);
  }
}
