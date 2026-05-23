import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilovebioconjugation/data/calculation_history.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/history/history_screen.dart';

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
          final volStr = _fmtVol(record.reactionVolume);
          final stockStr = _fmtVol(record.totalStockVolume);
          final diluentStr = _fmtVol(record.diluentVolume);
          final date = record.createdAt.substring(0, 19).replaceAll('T', ' ');

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      final mwStr = _fmtMw(s.molecularWeight, s.mwUnit);
                      final storageConcStr = s.storageConcMolar != null
                          ? _fmtConc(s.storageConcMolar!, 'M')
                          : s.storageConcMass != null
                              ? _fmtConc(s.storageConcMass!, 'g')
                              : 'N/A';
                      final storageVolStr = _fmtVol(s.storageVolume);
                      final finalConcStr = s.finalConcMolar != null
                          ? _fmtConc(s.finalConcMolar!, 'M')
                          : s.finalConcMass != null
                              ? _fmtConc(s.finalConcMass!, 'g')
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
          SizedBox(width: 100, child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.muted))),
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

String _fmtVol(double? ml) {
  if (ml == null) return 'N/A';
  final v = ml.abs();
  if (v >= 1000) return '${(ml / 1000).toStringAsFixed(2)} L';
  if (v >= 1) return '${ml.toStringAsFixed(2)} mL';
  if (v >= 0.001) return '${(ml * 1000).toStringAsFixed(2)} uL';
  if (v >= 0.000001) return '${(ml * 1e6).toStringAsFixed(2)} nL';
  return '${(ml * 1e9).toStringAsFixed(2)} pL';
}

String _fmtMw(double? da, String? unit) {
  if (da == null) return 'N/A';
  if (da >= 1000) return '${(da / 1000).toStringAsFixed(2)} kDa';
  return '${da.toStringAsFixed(2)} Da';
}

String _fmtConc(double? value, String baseType) {
  if (value == null) return 'N/A';
  final v = value.abs();
  if (baseType == 'M') {
    if (v >= 1000) return '${(value / 1000).toStringAsFixed(2)} M';
    if (v >= 1) return '${value.toStringAsFixed(2)} mM';
    if (v >= 0.001) return '${(value * 1000).toStringAsFixed(2)} uM';
    if (v >= 0.000001) return '${(value * 1e6).toStringAsFixed(2)} nM';
    return '${(value * 1e9).toStringAsFixed(2)} pM';
  } else {
    if (v >= 1000) return '${(value / 1000).toStringAsFixed(2)} g/mL';
    if (v >= 1) return '${value.toStringAsFixed(2)} mg/mL';
    if (v >= 0.001) return '${(value * 1000).toStringAsFixed(2)} ug/mL';
    if (v >= 0.000001) return '${(value * 1e6).toStringAsFixed(2)} ng/mL';
    return '${(value * 1e9).toStringAsFixed(2)} pg/mL';
  }
}
