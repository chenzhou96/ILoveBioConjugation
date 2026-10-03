import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:ilovebioconjugation/core/planning.dart';
import 'package:ilovebioconjugation/data/calculation_input_snapshot.dart';
import 'package:ilovebioconjugation/export/experiment_markdown.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/ui/planning/gradient_dialog.dart';
import 'package:ilovebioconjugation/ui/planning/gradient_overview_table.dart';
import 'package:ilovebioconjugation/ui/planning/planning_format.dart';
import 'package:ilovebioconjugation/ui/planning/record_actions.dart';

class HistoryGradientPlan extends StatefulWidget {
  final CalculationInputSnapshot snapshot;
  const HistoryGradientPlan({super.key, required this.snapshot});

  @override
  State<HistoryGradientPlan> createState() => _HistoryGradientPlanState();
}

class _HistoryGradientPlanState extends State<HistoryGradientPlan> {
  static const _pageSize = 5;
  GradientPlan? _plan;
  String? _error;
  int _page = 0;

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void didUpdateWidget(HistoryGradientPlan oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(widget.snapshot, oldWidget.snapshot)) _restore();
  }

  void _restore() {
    _page = 0;
    _plan = null;
    _error = null;
    try {
      _plan = restoreGradientPlan(widget.snapshot);
    } catch (error) {
      _error = error.toString().replaceFirst('Invalid argument(s): ', '');
    }
  }

  void _details(GradientGroup group) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('单次反应完整明细', style: TextStyle(fontSize: 17)),
      content: SizedBox(
        width: 950,
        child: SingleChildScrollView(
          child: GradientGroupCard(group: group, unit: _plan!.spec.unit),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('关闭'),
        ),
      ],
    ),
  );

  Future<void> _copy(GradientPlan plan) async {
    var message = '完整梯度投料清单已复制';
    try {
      await Clipboard.setData(ClipboardData(text: buildGradientCopyText(plan)));
    } catch (_) {
      message = '无法访问剪贴板，请稍后重试';
    }
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final plan = _plan;
    if (plan == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            '此记录的梯度方案无法完整还原：$_error。保存的输入仍可查看和恢复。',
            key: const ValueKey('history-gradient-error'),
            style: TextStyle(color: colors.errorFg, height: 1.6),
          ),
        ),
      );
    }
    final pages = (plan.groups.length / _pageSize).ceil();
    final groups = plan.groups.skip(_page * _pageSize).take(_pageSize).toList();
    return Card(
      key: const ValueKey('history-gradient-plan'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '完整梯度投料方案',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              '${plan.groups.length} 个条件 × ${plan.spec.replicates} 次重复 · ${plan.totals.failedGroupCount} 组不可行',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              '依据保存条件展示 · 每组总体积 ${planningVolume(plan.baseline.totalVolumeMl)} · 下列为单次反应用量',
              style: TextStyle(fontSize: 11, color: colors.muted, height: 1.6),
            ),
            for (final warning in plan.warnings)
              Text(
                warning.message,
                style: TextStyle(
                  fontSize: 12,
                  color: colors.warningFg,
                  height: 1.6,
                ),
              ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) =>
                  constraints.maxWidth >= 850 &&
                      MediaQuery.textScalerOf(context).scale(1) <= 1.2
                  ? GradientOverviewTable(
                      tableKey: const ValueKey(
                        'history-gradient-overview-table',
                      ),
                      plan: plan,
                      groups: groups,
                      width: constraints.maxWidth,
                      onOpenGroup: _details,
                    )
                  : Column(
                      children: [
                        for (final group in groups)
                          GradientGroupCard(group: group, unit: plan.spec.unit),
                      ],
                    ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  key: const ValueKey('history-gradient-previous-page'),
                  tooltip: '上一页',
                  onPressed: _page > 0 ? () => setState(() => _page--) : null,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  '第 ${_page + 1} / $pages 页',
                  style: const TextStyle(fontSize: 12),
                ),
                IconButton(
                  key: const ValueKey('history-gradient-next-page'),
                  tooltip: '下一页',
                  onPressed: _page + 1 < pages
                      ? () => setState(() => _page++)
                      : null,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('history-gradient-copy'),
                  onPressed: () => _copy(plan),
                  icon: const Icon(Icons.copy_outlined, size: 16),
                  label: const Text('复制整批清单'),
                ),
                RecordActions(
                  resultToken: plan,
                  buildMarkdown: () => buildGradientMarkdown(plan),
                  suggestedName: 'gradient-history.md',
                  label: '整批实验记录',
                ),
                Text(
                  '复制 / 导出包含全部 ${plan.groups.length} 组',
                  style: TextStyle(fontSize: 11, color: colors.muted),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              plan.totals.validGroupsOnly ? '备液汇总 · 仅包含有效组' : '备液汇总 · 全部有效组',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: plan.totals.validGroupsOnly
                    ? colors.errorFg
                    : colors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${plan.totals.validGroupCount} 个有效条件 × ${plan.spec.replicates} 次 = ${plan.totals.reactionCount} 次反应；额外配制 ${planningNumber(plan.spec.extraPreparationFraction * 100)}%',
              style: const TextStyle(fontSize: 12, height: 1.6),
            ),
            for (final reagent in plan.baseline.substrates)
              _total(context, plan, reagent),
            _totalRow('补加溶剂', planningVolume(plan.totals.diluentMl)),
            _totalRow('配制总体积', planningVolume(plan.totals.totalVolumeMl)),
          ],
        ),
      ),
    );
  }

  Widget _total(
    BuildContext context,
    GradientPlan plan,
    SolvedSubstrate reagent,
  ) {
    final actual =
        plan.groups
            .where((group) => group.isValid)
            .map((group) => group.result!.substrateAt(reagent.slot))
            .firstOrNull ??
        reagent;
    final shared = plan.workingStocks.any(
      (stock) => stock.slot == reagent.slot,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _totalRow(
            '${reagent.name}${shared ? '（共同工作液）' : ''}',
            planningVolume(plan.totals.aliquotsMl[reagent.slot] ?? 0),
            valueKey: ValueKey('history-gradient-total-${reagent.slot}'),
          ),
          Text(
            '实际母液：${planningConcentration(actual.stockMassMgMl, molar: false)} / ${planningConcentration(actual.stockMolarMm)}',
            style: TextStyle(
              fontSize: 11,
              height: 1.5,
              color: AppColors.of(context).errorFg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {Key? valueKey}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        const SizedBox(width: 12),
        Text(
          value,
          key: valueKey,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}
