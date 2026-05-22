import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilovebioconjunction/data/calculation_history.dart';
import 'package:ilovebioconjunction/theme/app_colors.dart';
import 'package:ilovebioconjunction/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjunction/ui/history/history_screen.dart';

class HistoryDetailScreen extends ConsumerWidget {
  final int recordId;

  const HistoryDetailScreen({super.key, required this.recordId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('计算详情', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        actions: [
          TextButton.icon(
            onPressed: () {
              historyAsync.whenData((records) {
                final record = records.cast<CalculationHistory?>().firstWhere(
                  (r) => r?.id == recordId,
                  orElse: () => null,
                );
                if (record != null) {
                  _restoreToCalculator(ref, record);
                  context.go('/');
                }
              });
            },
            icon: const Icon(Icons.restore, size: 14),
            label: const Text('恢复计算', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
      body: historyAsync.when(
        data: (records) {
          final record = records.cast<CalculationHistory?>().firstWhere(
            (r) => r?.id == recordId,
            orElse: () => null,
          );
          if (record == null) {
            return const Center(child: Text('记录未找到', style: TextStyle(color: AppColors.muted)));
          }

          final ratioLabel = record.ratioType ? '摩尔比' : '质量比';
          final volStr = record.reactionVolume != null
              ? '${record.reactionVolume!.toStringAsFixed(4)} ${record.reactionVolumeUnit}'
              : 'N/A';
          final stockStr = record.totalStockVolume != null
              ? '${record.totalStockVolume!.toStringAsFixed(4)} mL'
              : 'N/A';
          final diluentStr = record.diluentVolume != null
              ? '${record.diluentVolume!.toStringAsFixed(4)} mL'
              : 'N/A';
          final date = record.createdAt.substring(0, 19).replaceAll('T', ' ');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Summary card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(date, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        _detailRow('投料比类型', ratioLabel),
                        _detailRow('反应体积', volStr),
                        _detailRow('母液总体积', stockStr),
                        _detailRow('补加溶剂体积', diluentStr),
                        _detailRow('底物数量', '${record.substrates.length}'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Substrate table
                const Text('底物详情', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 16,
                    dataRowMinHeight: 32,
                    headingRowHeight: 32,
                    columns: const [
                      DataColumn(label: Text('角色', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('名称', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('分子量', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('母液浓度', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('母液体积', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('终浓度', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                      DataColumn(label: Text('投料比', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600))),
                    ],
                    rows: record.substrates.map((s) {
                      final mwStr = s.molecularWeight != null
                          ? '${s.molecularWeight} ${s.mwUnit ?? "Da"}'
                          : 'N/A';
                      final storageConcStr = s.storageConcMolar != null
                          ? '${s.storageConcMolar!.toStringAsFixed(4)} mM'
                          : s.storageConcMass != null
                              ? '${s.storageConcMass!.toStringAsFixed(4)} mg/mL'
                              : 'N/A';
                      final storageVolStr = s.storageVolume != null
                          ? '${s.storageVolume!.toStringAsFixed(4)} mL'
                          : 'N/A';
                      final finalConcStr = s.finalConcMolar != null
                          ? '${s.finalConcMolar!.toStringAsFixed(4)} mM'
                          : s.finalConcMass != null
                              ? '${s.finalConcMass!.toStringAsFixed(4)} mg/mL'
                              : 'N/A';
                      final ratioStr = s.reactionRatio != null
                          ? s.reactionRatio!.toStringAsFixed(4)
                          : 'N/A';

                      return DataRow(cells: [
                        DataCell(Text(s.role == 'main' ? '主底物' : '副底物', style: const TextStyle(fontSize: 11))),
                        DataCell(Text(s.name, style: const TextStyle(fontSize: 11))),
                        DataCell(Text(mwStr, style: const TextStyle(fontSize: 11))),
                        DataCell(Text(storageConcStr, style: const TextStyle(fontSize: 11))),
                        DataCell(Text(storageVolStr, style: const TextStyle(fontSize: 11))),
                        DataCell(Text(finalConcStr, style: const TextStyle(fontSize: 11))),
                        DataCell(Text(ratioStr, style: const TextStyle(fontSize: 11))),
                      ]);
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  void _restoreToCalculator(WidgetRef ref, CalculationHistory record) {
    final notifier = ref.read(calculatorProvider.notifier);
    notifier.restoreFromHistory(record);
  }
}
