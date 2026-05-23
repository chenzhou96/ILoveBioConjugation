import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilovebioconjunction/data/app_database.dart';
import 'package:ilovebioconjunction/data/calculation_history.dart';
import 'package:ilovebioconjunction/theme/app_colors.dart';

final historyProvider = FutureProvider<List<CalculationHistory>>((ref) async {
  final db = ref.read(appDatabaseProvider);
  return db.getHistory();
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('历史记录', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: () async {
              await ref.read(appDatabaseProvider).clearHistory();
              ref.invalidate(historyProvider);
            },
            icon: const Icon(Icons.delete_sweep, size: 16),
            label: const Text('清空', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: historyAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return const Center(
              child: Text('暂无历史记录', style: TextStyle(color: AppColors.muted)),
            );
          }
          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              final ratioLabel = record.ratioType ? '摩尔比' : '质量比';
              final vol = _formatVolumeSmart(record.reactionVolume, record.reactionVolumeUnit);
              final date = record.createdAt.substring(0, 19).replaceAll('T', ' ');
              final names = record.substrates.map((s) => s.name).join('、');

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  title: Text(
                    '$date — $ratioLabel — $vol',
                    style: const TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    names,
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete, size: 18),
                    onPressed: () async {
                      if (record.id != null) {
                        await ref.read(appDatabaseProvider).deleteHistory(record.id!);
                        ref.invalidate(historyProvider);
                      }
                    },
                  ),
                  onTap: () {
                    if (record.id != null) {
                      context.go('/history/${record.id}');
                    }
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }
}

String _formatVolumeSmart(double? volMl, String unit) {
  if (volMl == null) return 'N/A';
  final absV = volMl.abs();
  if (absV >= 1000) return '${(volMl / 1000).toStringAsFixed(2)} L';
  if (absV >= 1) return '${volMl.toStringAsFixed(2)} mL';
  if (absV >= 0.001) return '${(volMl * 1000).toStringAsFixed(2)} uL';
  if (absV >= 0.000001) return '${(volMl * 1000000).toStringAsFixed(2)} nL';
  return '${(volMl * 1000000000).toStringAsFixed(2)} pL';
}
