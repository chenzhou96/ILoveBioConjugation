import 'package:flutter/material.dart';
import 'package:ilovebioconjugation/core/planning.dart';
import 'package:ilovebioconjugation/core/display_format.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'planning_format.dart';

/// Shared read-only overview for the current calculation and saved batches.
class GradientOverviewTable extends StatelessWidget {
  final GradientPlan plan;
  final List<GradientGroup> groups;
  final double width;
  final ValueChanged<GradientGroup> onOpenGroup;
  final Key tableKey;
  const GradientOverviewTable({
    super.key,
    required this.plan,
    required this.groups,
    required this.width,
    required this.onOpenGroup,
    this.tableKey = const ValueKey('gradient-overview-table'),
  });

  Widget _stockHeader(BuildContext context, SolvedSubstrate reagent) {
    // A batch may adopt a shared dilution without changing its baseline.
    // Advice that has only been previewed must never replace these labels.
    final working = plan.workingStocks
        .where((stock) => stock.slot == reagent.slot)
        .lastOrNull;
    final actual =
        plan.groups
            .where((group) => group.isValid)
            .map((group) => group.result!.substrateAt(reagent.slot))
            .firstOrNull ??
        reagent;
    final mass = planningConcentration(
      working?.stockMassMgMl ?? actual.stockMassMgMl,
      molar: false,
    );
    final molar = planningConcentration(
      working?.stockMolarMm ?? actual.stockMolarMm,
    );
    final red = TextStyle(
      fontSize: 10,
      height: 1.25,
      fontWeight: FontWeight.w700,
      color: AppColors.of(context).errorFg,
    );
    return Tooltip(
      message: '${reagent.name}\n实际母液质量浓度：$mass\n实际母液摩尔浓度：$molar\n每次取样量',
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 170),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(reagent.name, maxLines: 2, overflow: TextOverflow.ellipsis),
            Text('实际母液', style: red),
            Text(
              mass,
              key: ValueKey('gradient-stock-mass-${reagent.slot}'),
              style: red,
            ),
            Text(
              molar,
              key: ValueKey('gradient-stock-molar-${reagent.slot}'),
              style: red,
            ),
            const Text('取样量'),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          '点击条件查看所有试剂的母液 / 终浓度双单位、比值与操作提醒',
          style: TextStyle(fontSize: 10, color: colors.muted),
        ),
        const SizedBox(height: 7),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: width),
            child: DataTable(
              key: tableKey,
              showCheckboxColumn: false,
              horizontalMargin: 8,
              columnSpacing: 14,
              headingRowHeight: MediaQuery.textScalerOf(context).scale(86),
              dataRowMinHeight: 58,
              dataRowMaxHeight: 58,
              headingTextStyle: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: colors.muted,
              ),
              border: TableBorder(
                horizontalInside: BorderSide(color: colors.border),
              ),
              columns: [
                const DataColumn(label: Text('条件 / 目标')),
                const DataColumn(label: Text('变化试剂终浓度\n摩尔 / 质量')),
                for (final reagent in plan.baseline.substrates)
                  DataColumn(label: _stockHeader(context, reagent)),
                const DataColumn(label: Text('补加溶剂')),
                const DataColumn(label: Text('状态 / 明细')),
              ],
              rows: [
                for (final group in groups)
                  DataRow(
                    onSelectChanged: (_) => onOpenGroup(group),
                    color: group.isValid
                        ? null
                        : WidgetStatePropertyAll(colors.errorBg),
                    cells: [
                      DataCell(
                        Text(
                          '条件 ${group.index + 1}\n${displayInputValue(group.pointText, plan.spec.unit)}${group.pointValue == 0 ? ' · 对照' : ''}',
                          key: ValueKey('gradient-group-${group.index}'),
                          style: TextStyle(
                            fontSize: 11,
                            height: 1.6,
                            color: group.isValid ? colors.text : colors.errorFg,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          group.result == null
                              ? '—'
                              : '${planningConcentration(group.result!.substrateAt(plan.spec.selectedSlot).finalMolarMm)}\n${planningConcentration(group.result!.substrateAt(plan.spec.selectedSlot).finalMassMgMl, molar: false)}',
                          style: const TextStyle(fontSize: 10, height: 1.5),
                        ),
                      ),
                      for (final reagent in plan.baseline.substrates)
                        DataCell(
                          Text(
                            group.result == null
                                ? '—'
                                : planningVolume(
                                    group.result!
                                        .substrateAt(reagent.slot)
                                        .aliquotMl,
                                  ),
                            style: TextStyle(
                              fontSize: 11,
                              color:
                                  group.result?.warnings.any(
                                        (w) => w.slot == reagent.slot,
                                      ) ==
                                      true
                                  ? colors.warningFg
                                  : colors.text,
                            ),
                          ),
                        ),
                      DataCell(
                        Text(
                          group.result == null
                              ? '—'
                              : planningVolume(group.result!.diluentVolumeMl),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                      DataCell(
                        SizedBox(
                          width: 126,
                          child: Row(
                            children: [
                              Expanded(
                                child: Tooltip(
                                  message:
                                      group.error ??
                                      group.result?.warnings
                                          .map((w) => w.message)
                                          .join('\n') ??
                                      '',
                                  child: Text(
                                    group.isValid
                                        ? (group.result!.warnings.isEmpty
                                              ? '可行'
                                              : '${group.result!.warnings.length} 项提醒')
                                        : '不可行：${group.error}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 10,
                                      height: 1.5,
                                      color: !group.isValid
                                          ? colors.errorFg
                                          : group.result!.warnings.isNotEmpty
                                          ? colors.warningFg
                                          : colors.successFg,
                                    ),
                                  ),
                                ),
                              ),
                              IconButton(
                                key: ValueKey(
                                  'gradient-details-${group.index}',
                                ),
                                tooltip: '查看条件 ${group.index + 1} 完整明细',
                                onPressed: () => onOpenGroup(group),
                                constraints: const BoxConstraints(
                                  minWidth: 26,
                                  minHeight: 30,
                                ),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.open_in_new, size: 14),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
