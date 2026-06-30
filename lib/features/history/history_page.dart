import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../providers.dart';
import '../../services/csv_export_service.dart';
import '../../services/history_repository.dart';
import '../../ui/theme.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<ScanRecord> _filter(List<ScanRecord> records) {
    if (_query.isEmpty) return records;
    final q = _query.toLowerCase();
    return records.where((r) {
      final haystack = [
        r.productName,
        r.productBrand,
        r.barcodeValue,
        r.barcodeFormat,
        r.inputType,
        ...r.kvPairs.map((kv) => '${kv.key} ${kv.value}'),
      ].whereType<String>().join(' ').toLowerCase();
      return haystack.contains(q);
    }).toList();
  }

  Future<void> _export(List<ScanRecord> records) async {
    if (records.isEmpty) return;
    try {
      final path = await CsvExportService().exportToFile(records);
      if (!mounted || path == null) return; // null = user cancelled save dialog
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Saved CSV to $path'),
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'Share',
          onPressed: () => Share.shareXFiles([XFile(path)],
              subject: 'ScanKit history export'),
        ),
      ));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Could not export CSV. Please try again.'),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.watch(historyRepositoryProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan History'),
        actions: [
          StreamBuilder<List<ScanRecord>>(
            stream: repo.watchAll(),
            builder: (context, snapshot) {
              final visible = _filter(snapshot.data ?? []);
              return IconButton(
                icon: const Icon(Icons.ios_share_rounded),
                tooltip: 'Export CSV',
                onPressed: visible.isEmpty ? null : () => _export(visible),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: Colors.white),
              onChanged: (v) => setState(() => _query = v.trim()),
              decoration: InputDecoration(
                hintText: 'Search scans…',
                hintStyle: const TextStyle(color: Colors.white38),
                prefixIcon:
                    const Icon(Icons.search_rounded, color: Colors.white54),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close_rounded,
                            color: Colors.white54),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _query = '');
                        },
                      ),
                filled: true,
                fillColor: const Color(0xFF1A1A1A),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: StreamBuilder<List<ScanRecord>>(
              stream: repo.watchAll(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator(color: kAccent));
                }
                final records = _filter(snapshot.data ?? []);
                if (records.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.history_rounded,
                            size: 64, color: Colors.white24),
                        const SizedBox(height: 16),
                        Text(
                          _query.isEmpty
                              ? 'No scans saved yet.'
                              : 'No scans match “$_query”.',
                          style: const TextStyle(color: Colors.white54),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) =>
                      _HistoryTile(record: records[i], repo: repo),
                );
              },
            ),
          ),
        ],
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

    return Dismissible(
      key: Key('scan-${record.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color: Colors.red.shade900,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: Colors.white, size: 22),
      ),
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) => repo.delete(record.id),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF2A2A2A)),
        ),
        child: ListTile(
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: kAccent.withAlpha(20),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: kAccent.withAlpha(50)),
            ),
            child: Icon(_inputIcon(record.inputType),
                color: kAccent, size: 20),
          ),
          title: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14),
          ),
          subtitle: Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right_rounded,
              color: Colors.white30, size: 20),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
          onTap: () => context.push('/history/${record.id}'),
        ),
      ),
    );
  }

  IconData _inputIcon(String type) => switch (type) {
        'camera' => Icons.camera_alt_rounded,
        'gallery' => Icons.photo_library_rounded,
        _ => Icons.folder_open_rounded,
      };

  String _formatDate(DateTime dt) {
    return '${dt.year}-${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}  '
        '${dt.hour.toString().padLeft(2, '0')}:'
        '${dt.minute.toString().padLeft(2, '0')}';
  }

  Future<bool?> _confirmDelete(BuildContext context) => showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Delete scan?',
              style: TextStyle(color: Colors.white)),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel',
                    style: TextStyle(color: Colors.white54))),
            TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Delete',
                    style: TextStyle(color: Colors.redAccent))),
          ],
        ),
      );
}
