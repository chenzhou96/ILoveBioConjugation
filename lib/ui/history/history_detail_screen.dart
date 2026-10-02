import 'package:flutter/material.dart';
import 'package:ilovebioconjugation/ui/planning/planning_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilovebioconjugation/data/calculation_history.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/history/history_screen.dart';
import 'package:ilovebioconjugation/ui/history/history_format.dart';

class HistoryDetailScreen extends ConsumerWidget {
  final int recordId;

  const HistoryDetailScreen({super.key, required this.recordId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(historyProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '计算详情',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
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
                  context.go(
                    record.inputSnapshot?.gradient == null
                        ? '/'
                        : '/?planning=gradient',
                  );
                }
              });
            },
            icon: Icon(Icons.restore, size: 14),
            label: Text('恢复计算', style: TextStyle(fontSize: 12)),
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
            return Center(
              child: Text(
                '记录未找到',
                style: TextStyle(color: AppColors.of(context).muted),
              ),
            );
          }

          final ratioLabel = record.ratioType ? '摩尔比' : '质量比';
          final volStr = _fmtVol(record.reactionVolume);
          final stockStr = _fmtVol(record.totalStockVolume);
          final diluentStr = _fmtVol(record.diluentVolume);
          final date = formatHistoryDate(record.createdAt);
          final snapshot = record.inputSnapshot;
          final gradient = snapshot?.gradient;
          final referenceSlot = snapshot?.referenceSlot ?? 0;
          final referenceRatio = record.substrates
              .where((s) => s.sortOrder == referenceSlot)
              .firstOrNull
              ?.reactionRatio;
          final reference =
              record.substrates
                  .where((s) => s.sortOrder == referenceSlot)
                  .firstOrNull
                  ?.name ??
              '主底物';

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
                        Text(
                          date,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _detailRow(context, '投料比类型', ratioLabel),
                        _detailRow(
                          context,
                          '比值基准',
                          referenceRatio == null
                              ? '$reference（比值不适用）'
                              : referenceRatio == 1
                              ? '$reference = 1'
                              : '$reference = ${formatHistoryNumber(referenceRatio, 4)}（历史原值）',
                        ),
                        _detailRow(context, '反应体积', volStr),
                        _detailRow(context, '母液总体积', stockStr),
                        _detailRow(context, '补加溶剂体积', diluentStr),
                        _detailRow(
                          context,
                          '底物数量',
                          '${record.substrates.length}',
                        ),
                      ],
                    ),
                  ),
                ),
                if (gradient != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            '完整梯度条件',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          _detailRow(
                            context,
                            '改变试剂',
                            snapshot!.substrates[gradient.selectedSlot].name,
                          ),
                          _detailRow(
                            context,
                            '梯度点',
                            '${gradient.points.join('、')} ${gradient.unit.replaceFirst('u', 'µ')}',
                          ),
                          _detailRow(
                            context,
                            '每条件重复',
                            '${gradient.replicates} 次',
                          ),
                          _detailRow(
                            context,
                            '额外配制',
                            '${planningNumber(gradient.extraPreparationFraction * 100)}%（只用于备液）',
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '固定蛋白 / 主底物用量、总体积与其他试剂终浓度。恢复计算后在梯度面板重新生成整批，不会展开成互不关联的单组输入。',
                            style: TextStyle(fontSize: 12, height: 1.6),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
                if (snapshot != null)
                  for (final recipe in [
                    ...snapshot.workingStocks,
                    ...?snapshot.gradient?.workingStocks,
                  ]) ...[
                    const SizedBox(height: 12),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              '工作液配制 · ${recipe.parentInput.name}',
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '原母液 ${recipe.parentInput.storageConc} ${recipe.parentInput.storageUnit} → 工作液 ${recipe.workingConcentration} ${recipe.workingUnit}',
                              style: const TextStyle(fontSize: 12, height: 1.6),
                            ),
                            Text(
                              '原母液 ${planningVolume(recipe.parentVolumeMl)} + ${recipe.diluentName} ${planningVolume(recipe.diluentVolumeMl)} = ${planningVolume(recipe.preparationVolumeMl)}',
                              style: const TextStyle(fontSize: 12, height: 1.6),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                const SizedBox(height: 12),
                Text(
                  gradient == null ? '底物详情' : '基线详情（恢复后重新生成整批）',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columnSpacing: 16,
                    dataRowMinHeight: 32,
                    headingRowHeight: 32,
                    columns: const [
                      DataColumn(
                        label: Text(
                          '角色',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          '名称',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          '分子量',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          '母液浓度',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          '母液体积',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          '终浓度',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          '投料比',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
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
                          ? formatHistoryNumber(s.reactionRatio!, 4)
                          : 'N/A';

                      return DataRow(
                        cells: [
                          DataCell(
                            Text(
                              s.role == 'main' ? '主底物' : '副底物${s.sortOrder}',
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          DataCell(
                            Text(s.name, style: TextStyle(fontSize: 11)),
                          ),
                          DataCell(Text(mwStr, style: TextStyle(fontSize: 11))),
                          DataCell(
                            Text(
                              storageConcStr,
                              style: TextStyle(fontSize: 11),
                            ),
                          ),
                          DataCell(
                            Text(storageVolStr, style: TextStyle(fontSize: 11)),
                          ),
                          DataCell(
                            Text(finalConcStr, style: TextStyle(fontSize: 11)),
                          ),
                          DataCell(
                            Text(ratioStr, style: TextStyle(fontSize: 11)),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('加载失败: $e')),
      ),
    );
  }

  Widget _detailRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.of(context).muted,
              ),
            ),
          ),
          Expanded(child: Text(value, style: TextStyle(fontSize: 12))),
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
  if (v >= 1000) return '${formatHistoryNumber(ml / 1000, 2)} L';
  if (v >= 1) return '${formatHistoryNumber(ml, 2)} mL';
  if (v >= 0.001) return '${formatHistoryNumber(ml * 1000, 2)} uL';
  if (v >= 0.000001) return '${formatHistoryNumber(ml * 1e6, 2)} nL';
  return '${formatHistoryNumber(ml * 1e9, 2)} pL';
}

String _fmtMw(double? da, String? unit) {
  if (da == null) return 'N/A';
  if (da >= 1000) return '${formatHistoryNumber(da / 1000, 2)} kDa';
  return '${formatHistoryNumber(da, 2)} Da';
}

String _fmtConc(double? value, String baseType) {
  if (value == null) return 'N/A';
  final v = value.abs();
  if (baseType == 'M') {
    if (v >= 1000) return '${formatHistoryNumber(value / 1000, 2)} M';
    if (v >= 1) return '${formatHistoryNumber(value, 2)} mM';
    if (v >= 0.001) return '${formatHistoryNumber(value * 1000, 2)} uM';
    if (v >= 0.000001) return '${formatHistoryNumber(value * 1e6, 2)} nM';
    return '${formatHistoryNumber(value * 1e9, 2)} pM';
  } else {
    if (v >= 1000) return '${formatHistoryNumber(value / 1000, 2)} g/mL';
    if (v >= 1) return '${formatHistoryNumber(value, 2)} mg/mL';
    if (v >= 0.001) return '${formatHistoryNumber(value * 1000, 2)} ug/mL';
    if (v >= 0.000001) return '${formatHistoryNumber(value * 1e6, 2)} ng/mL';
    return '${formatHistoryNumber(value * 1e9, 2)} pg/mL';
  }
}
