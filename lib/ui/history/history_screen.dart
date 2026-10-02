import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilovebioconjugation/data/app_database.dart';
import 'package:ilovebioconjugation/data/calculation_history.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/ui/history/history_format.dart';

final historyProvider = FutureProvider<List<CalculationHistory>>((ref) async {
  final db = ref.read(appDatabaseProvider);
  return db.getHistory();
});

class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  Future<void> _deleteHistory(
    BuildContext context,
    WidgetRef ref, {
    int? recordId,
  }) async {
    final clearAll = recordId == null;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(clearAll ? '清空历史记录？' : '删除这条历史记录？'),
        content: Text(
          clearAll
              ? '此操作会永久删除所有计算历史，无法撤销。已保存的底物模板不受影响。'
              : '此操作会永久删除这条计算历史，无法撤销。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(clearAll ? '确认清空' : '确认删除'),
          ),
        ],
      ),
    );
    if (approved != true || !context.mounted) return;
    // Refresh shared data even if the user leaves this screen while deletion
    // is pending. The widget's mounted state controls only local UI feedback.
    final container = ProviderScope.containerOf(context, listen: false);
    try {
      final database = container.read(appDatabaseProvider);
      if (clearAll) {
        await database.clearHistory();
      } else {
        await database.deleteHistory(recordId);
      }
      container.invalidate(historyProvider);
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('删除失败，请重试：$error')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '历史记录',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton.icon(
            onPressed: () => _deleteHistory(context, ref),
            icon: Icon(Icons.delete_sweep, size: 16),
            label: Text('清空', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: historyAsync.when(
        data: (records) {
          if (records.isEmpty) {
            return Center(
              child: Text(
                '暂无历史记录',
                style: TextStyle(color: AppColors.of(context).muted),
              ),
            );
          }
          return ListView.builder(
            itemCount: records.length,
            itemBuilder: (context, index) {
              final record = records[index];
              final ratioLabel = record.ratioType ? '摩尔比' : '质量比';
              final vol = _formatVolumeSmart(
                record.reactionVolume,
                record.reactionVolumeUnit,
              );
              final date = formatHistoryDate(record.createdAt);
              final names = record.substrates.map((s) => s.name).join('、');
              final snapshot = record.inputSnapshot;
              final gradient = snapshot?.gradient;
              final referenceSlot = snapshot?.referenceSlot ?? 0;
              final referenceRatio = record.substrates
                  .where((s) => s.sortOrder == referenceSlot)
                  .firstOrNull
                  ?.reactionRatio;
              final referenceSuffix = referenceRatio == null
                  ? '比值不适用'
                  : referenceRatio == 1
                  ? '= 1'
                  : '= ${formatHistoryNumber(referenceRatio, 4)}（历史原值）';
              final reference =
                  record.substrates
                      .where((s) => s.sortOrder == referenceSlot)
                      .firstOrNull
                      ?.name ??
                  '主底物';
              final badge = gradient == null
                  ? ''
                  : '梯度 ${gradient.points.length} 条件 × ${gradient.replicates} · ';

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: ListTile(
                  title: Text(
                    '$badge$date · $ratioLabel · $vol',
                    style: TextStyle(fontSize: 13),
                  ),
                  subtitle: Text(
                    '$names · 基准 $reference $referenceSuffix',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.of(context).muted,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete, size: 18),
                    tooltip: '删除记录',
                    onPressed: record.id == null
                        ? null
                        : () =>
                              _deleteHistory(context, ref, recordId: record.id),
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
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }
}

String _formatVolumeSmart(double? volMl, String unit) {
  if (volMl == null) return 'N/A';
  final absV = volMl.abs();
  if (absV >= 1000) return '${formatHistoryNumber(volMl / 1000, 2)} L';
  if (absV >= 1) return '${formatHistoryNumber(volMl, 2)} mL';
  if (absV >= 0.001) return '${formatHistoryNumber(volMl * 1000, 2)} uL';
  if (absV >= 0.000001) return '${formatHistoryNumber(volMl * 1000000, 2)} nL';
  return '${formatHistoryNumber(volMl * 1000000000, 2)} pL';
}
