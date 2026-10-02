import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilovebioconjugation/core/planning.dart';
import 'package:ilovebioconjugation/export/experiment_markdown.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/settings/app_settings.dart';
import 'package:ilovebioconjugation/ui/planning/planning_format.dart';
import 'package:ilovebioconjugation/ui/planning/record_actions.dart';
import 'package:ilovebioconjugation/ui/planning/working_stock_dialog.dart';

Future<void> showGradientDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const GradientDialog());

class GradientDialog extends ConsumerStatefulWidget {
  const GradientDialog({super.key});
  @override
  ConsumerState<GradientDialog> createState() => _GradientDialogState();
}

class _GradientDialogState extends ConsumerState<GradientDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final TextEditingController _values;
  late final TextEditingController _replicates;
  late final TextEditingController _extra;
  late final double _initialExtraFraction;
  final _start = TextEditingController(text: '1');
  final _step = TextEditingController(text: '1');
  final _count = TextEditingController(text: '5');
  final _diluent = TextEditingController();
  late int _slot;
  late String _unit;
  String _generator = 'manual';
  bool _includeZero = false;
  String? _error;
  int _page = 0;
  GradientWorkingStockProposal? _stockAdvice;
  static const _pageSize = 5;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
    final state = ref.read(calculatorProvider);
    final spec = state.gradientSpec;
    _slot =
        spec?.selectedSlot ?? state.substrates.indexWhere((s) => s.enabled, 1);
    _unit = spec?.unit ?? 'eq';
    _values = TextEditingController(
      text: spec?.points.join(', ') ?? '1, 2, 5, 10',
    );
    _replicates = TextEditingController(text: '${spec?.replicates ?? 1}');
    _initialExtraFraction = spec?.extraPreparationFraction ?? 0;
    _extra = TextEditingController(
      text: (_initialExtraFraction * 100).toString(),
    );
  }

  @override
  void dispose() {
    _tabs.dispose();
    for (final controller in [
      _values,
      _replicates,
      _extra,
      _start,
      _step,
      _count,
      _diluent,
    ]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _changed([String? _]) {
    ref.read(calculatorProvider.notifier).configureGradient(null);
    setState(() {
      _error = null;
      _page = 0;
      _stockAdvice = null;
    });
  }

  void _generatePoints() {
    try {
      final start = double.tryParse(_start.text.trim());
      final step = double.tryParse(_step.text.trim());
      final count = int.tryParse(_count.text.trim());
      if (start == null || step == null || count == null) {
        throw ArgumentError('起点、步长 / 倍数和整数点数不能为空');
      }
      final points = _generator == 'arithmetic'
          ? arithmeticGradientPoints(start: start, step: step, count: count)
          : geometricGradientPoints(start: start, factor: step, count: count);
      _values.text = points.join(', ');
      _changed();
    } catch (error) {
      setState(() => _error = '$error');
    }
  }

  void _generate() {
    final replicates = int.tryParse(_replicates.text.trim());
    final extra = double.tryParse(_extra.text.trim());
    if (replicates == null ||
        replicates <= 0 ||
        extra == null ||
        !extra.isFinite ||
        extra < 0) {
      setState(() => _error = '重复数须为正整数；额外配制比例须为大于或等于 0 的有限数字');
      return;
    }
    final extraFraction = extra == _initialExtraFraction * 100
        ? _initialExtraFraction
        : extra / 100;
    final points = _values.text
        .split(RegExp(r'[,，;；\s]+'))
        .where((v) => v.isNotEmpty)
        .toList();
    if (_includeZero && !points.any((p) => double.tryParse(p) == 0)) {
      points.insert(0, '0');
    }
    if (points.isEmpty || _slot < 1) {
      setState(() => _error = '请选择已启用的非蛋白试剂，并填写梯度点');
      return;
    }
    final notifier = ref.read(calculatorProvider.notifier);
    final existing = ref.read(calculatorProvider).gradientSpec;
    final unchanged =
        existing != null &&
        existing.selectedSlot == _slot &&
        existing.unit == _unit &&
        existing.replicates == replicates &&
        existing.extraPreparationFraction == extraFraction &&
        existing.points.length == points.length &&
        Iterable<int>.generate(points.length).every(
          (i) =>
              existing.points[i] == points[i] ||
              (double.tryParse(existing.points[i]) != null &&
                  double.tryParse(existing.points[i]) ==
                      double.tryParse(points[i])),
        );
    // A restored batch may contain explicitly adopted shared stocks. Preserve
    // those recipes when merely regenerating its unchanged saved conditions.
    if (!unchanged) {
      notifier.configureGradient(
        GradientSpec(
          selectedSlot: _slot,
          unit: _unit,
          points: points,
          replicates: replicates,
          extraPreparationFraction: extraFraction,
        ),
      );
    }
    notifier.calculateGradient();
    final state = ref.read(calculatorProvider);
    setState(() {
      _error = state.gradientPlan == null ? state.planningMessage : null;
      _page = 0;
      _stockAdvice = null;
    });
    if (state.gradientPlan != null) _tabs.animateTo(1);
  }

  Future<void> _copyBatch(GradientPlan plan) async {
    try {
      await Clipboard.setData(ClipboardData(text: buildGradientCopyText(plan)));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('整批取样清单已复制（包含所有组）')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('无法访问剪贴板，请稍后重试')));
      }
    }
  }

  void _previewStock(GradientPlan plan) {
    if (_diluent.text.trim().isEmpty) {
      setState(() => _error = '请先指定工作液使用的稀释液');
      return;
    }
    try {
      final proposal = proposeGradientWorkingStock(
        plan,
        slot: plan.spec.selectedSlot,
        minimumVolumeMl:
            ref.read(appSettingsProvider).minimumPipettingVolumeUl / 1000,
        diluentName: _diluent.text.trim(),
      );
      setState(() {
        _stockAdvice = proposal;
        _error = null;
      });
    } catch (error) {
      setState(() => _error = '$error');
    }
  }

  void _adoptStock() {
    final proposal = _stockAdvice;
    if (proposal == null) return;
    final accepted = ref
        .read(calculatorProvider.notifier)
        .adoptGradientWorkingStock(proposal);
    setState(() {
      _error = accepted ? null : ref.read(calculatorProvider).planningMessage;
      if (accepted) {
        _stockAdvice = null;
        _page = 0;
      }
    });
    if (accepted) _tabs.animateTo(1);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calculatorProvider);
    final baseline = state.rawResult;
    final plan = state.gradientPlan;
    final colors = AppColors.of(context);
    final size = MediaQuery.sizeOf(context);
    final slots = [
      for (var i = 1; i < state.substrates.length; i++)
        if (state.substrates[i].enabled) i,
    ];
    final selectedSlot = slots.contains(_slot) ? _slot : null;
    return Dialog(
      insetPadding: EdgeInsets.all(size.width < 600 ? 8 : 24),
      child: SizedBox(
        width: 1100,
        height: math.min(720, size.height - (size.width < 600 ? 32 : 64)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      '单因素梯度方案',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '关闭梯度方案',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, size: 20),
                  ),
                ],
              ),
            ),
            TabBar(
              isScrollable:
                  size.width < 600 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.2,
              tabAlignment:
                  size.width < 600 ||
                      MediaQuery.textScalerOf(context).scale(1) > 1.2
                  ? TabAlignment.start
                  : TabAlignment.fill,
              controller: _tabs,
              labelStyle: const TextStyle(fontSize: 12),
              tabs: const [
                Tab(text: '条件设置'),
                Tab(text: '逐组结果'),
                Tab(text: '备液汇总'),
              ],
            ),
            if (_error != null)
              Container(
                padding: const EdgeInsets.all(10),
                color: colors.errorBg,
                child: Text(
                  _error!,
                  style: TextStyle(fontSize: 12, color: colors.errorFg),
                ),
              ),
            if (state.historySaveError.isNotEmpty)
              Padding(
                padding: const EdgeInsets.all(10),
                child: Text(
                  state.historySaveError,
                  style: TextStyle(fontSize: 11, color: colors.warningFg),
                ),
              ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: [
                  ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Text(
                        '固定主底物 / 蛋白用量、每组反应总体积与其他试剂终浓度，只改变所选试剂。',
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.6,
                          color: colors.muted,
                        ),
                      ),
                      if (baseline == null) ...[
                        const SizedBox(height: 12),
                        const Text(
                          '先运行当前条件，获得可核对的固定值。恢复的梯度条件已保留，计算后可重新生成。',
                          style: TextStyle(fontSize: 12),
                        ),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: OutlinedButton(
                            onPressed: () => ref
                                .read(calculatorProvider.notifier)
                                .calculate(),
                            child: const Text('计算当前条件'),
                          ),
                        ),
                        if (state.errorMessage != '就绪')
                          Text(
                            state.errorMessage,
                            style: TextStyle(
                              fontSize: 12,
                              color: colors.errorFg,
                            ),
                          ),
                      ],
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          _fieldBox(
                            '改变的试剂（非蛋白）',
                            DropdownButton<int>(
                              key: const ValueKey('gradient-slot'),
                              value: selectedSlot,
                              isExpanded: true,
                              isDense: true,
                              hint: const Text('请启用副底物'),
                              items: [
                                for (final slot in slots)
                                  DropdownMenuItem(
                                    value: slot,
                                    child: Text(state.substrates[slot].name),
                                  ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  _slot = v;
                                  _changed();
                                }
                              },
                            ),
                          ),
                          _fieldBox(
                            '梯度方式',
                            DropdownButton<String>(
                              key: const ValueKey('gradient-mode'),
                              value: _unit == 'eq' ? 'eq' : 'concentration',
                              isExpanded: true,
                              isDense: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'eq',
                                  child: Text('相对参照的 eq'),
                                ),
                                DropdownMenuItem(
                                  value: 'concentration',
                                  child: Text('目标终浓度'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  _unit = v == 'eq' ? 'eq' : 'uM';
                                  _changed();
                                }
                              },
                            ),
                          ),
                          if (_unit != 'eq')
                            _fieldBox(
                              '浓度单位',
                              DropdownButton<String>(
                                key: const ValueKey('gradient-unit'),
                                value: _unit,
                                isExpanded: true,
                                isDense: true,
                                items: [
                                  for (final u
                                      in CalculatorNotifier.storageUnits)
                                    DropdownMenuItem(
                                      value: u,
                                      child: Text(u.replaceFirst('u', 'µ')),
                                    ),
                                ],
                                onChanged: (v) {
                                  if (v != null) {
                                    _unit = v;
                                    _changed();
                                  }
                                },
                              ),
                            ),
                          _fieldBox(
                            '点列输入',
                            DropdownButton<String>(
                              key: const ValueKey('gradient-generator'),
                              value: _generator,
                              isExpanded: true,
                              isDense: true,
                              items: const [
                                DropdownMenuItem(
                                  value: 'manual',
                                  child: Text('手动列表'),
                                ),
                                DropdownMenuItem(
                                  value: 'arithmetic',
                                  child: Text('等差生成'),
                                ),
                                DropdownMenuItem(
                                  value: 'geometric',
                                  child: Text('等比生成'),
                                ),
                              ],
                              onChanged: (v) {
                                if (v != null) {
                                  setState(() {
                                    _generator = v;
                                    _error = null;
                                  });
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                      if (_generator != 'manual') ...[
                        const SizedBox(height: 14),
                        Wrap(
                          spacing: 12,
                          runSpacing: 12,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            _numberField('起点', _start, 'gradient-start'),
                            _numberField(
                              _generator == 'arithmetic' ? '步长' : '倍数',
                              _step,
                              'gradient-step-or-factor',
                            ),
                            _numberField('条件点数', _count, 'gradient-count'),
                            OutlinedButton(
                              key: const ValueKey('gradient-generate-points'),
                              onPressed: _generatePoints,
                              child: const Text('生成点列'),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 14),
                      TextField(
                        key: const ValueKey('gradient-values'),
                        controller: _values,
                        maxLines: 2,
                        onChanged: _changed,
                        decoration: InputDecoration(
                          labelText: '梯度点（$_unit）',
                          hintText: '逗号、空格或换行分隔；0 表示对照，重复值会保留',
                        ),
                      ),
                      CheckboxListTile(
                        key: const ValueKey('gradient-zero-control'),
                        value: _includeZero,
                        onChanged: (v) {
                          _includeZero = v ?? false;
                          _changed();
                        },
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: const Text(
                          '额外加入 0 对照（已有 0 时不重复添加）',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      Wrap(
                        spacing: 14,
                        runSpacing: 14,
                        children: [
                          _numberField(
                            '每个条件重复数',
                            _replicates,
                            'gradient-replicates',
                          ),
                          _numberField(
                            '额外配制 %（仅总备液量）',
                            _extra,
                            'gradient-extra',
                            width: 240,
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (baseline != null)
                        _lockedSummary(baseline, selectedSlot),
                      const SizedBox(height: 14),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton.icon(
                          key: const ValueKey('gradient-generate'),
                          onPressed: baseline == null || selectedSlot == null
                              ? null
                              : _generate,
                          icon: const Icon(Icons.stacked_line_chart, size: 17),
                          label: const Text('按以上固定条件生成梯度'),
                        ),
                      ),
                    ],
                  ),
                  plan == null ? _empty() : _results(plan),
                  plan == null ? _empty() : _preparation(plan),
                ],
              ),
            ),
            if (plan != null)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      key: const ValueKey('copy-batch-button'),
                      onPressed: () => _copyBatch(plan),
                      icon: const Icon(Icons.copy_outlined, size: 16),
                      label: const Text('复制整批清单'),
                    ),
                    RecordActions(
                      resultToken: plan,
                      buildMarkdown: () => buildGradientMarkdown(plan),
                      suggestedName: 'gradient-record.md',
                      label: '整批实验记录',
                    ),
                    Text(
                      '复制 / 导出包含全部 ${plan.groups.length} 组',
                      style: TextStyle(fontSize: 11, color: colors.muted),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _empty() => const Center(
    child: Padding(
      padding: EdgeInsets.all(24),
      child: Text(
        '请先在条件设置中核对固定值并生成方案',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13),
      ),
    ),
  );
  Widget _fieldBox(String label, Widget child) => SizedBox(
    width: 225,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11)),
        const SizedBox(height: 7),
        Container(
          padding: const EdgeInsets.all(11),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.of(context).border),
            borderRadius: BorderRadius.circular(7),
          ),
          child: DropdownButtonHideUnderline(child: child),
        ),
      ],
    ),
  );
  Widget _numberField(
    String label,
    TextEditingController controller,
    String key, {
    double width = 185,
  }) => SizedBox(
    width: width,
    child: TextField(
      key: ValueKey(key),
      controller: controller,
      onChanged: _changed,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(labelText: label),
    ),
  );
  Widget _lockedSummary(CalculationResult baseline, int? selected) {
    final protein = baseline.substrateAt(0);
    final reference = baseline.substrateAt(baseline.referenceSlot);
    return Container(
      key: const ValueKey('gradient-locked-summary'),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.of(context).surfaceSoft,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '生成前核对 · 以下条件锁定',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 7),
          Text(
            '每组总体积 ${planningVolume(baseline.totalVolumeMl)}；参照 ${reference.name} = 1（${baseline.ratioType ? '摩尔' : '质量'}比）',
            style: const TextStyle(fontSize: 12, height: 1.6),
          ),
          Text(
            '固定 ${protein.name}：每组取 ${planningVolume(protein.aliquotMl)}${protein.finalMassMgMl == null ? '' : ' / ${planningNumber(protein.finalMassMgMl! * baseline.totalVolumeMl * 1000)} µg'}',
            style: const TextStyle(fontSize: 12, height: 1.6),
          ),
          for (final reagent in baseline.substrates)
            if (reagent.slot != selected)
              Text(
                '${reagent.name} 终浓度：${planningConcentration(reagent.finalMolarMm)} / ${planningConcentration(reagent.finalMassMgMl, molar: false)}',
                style: const TextStyle(fontSize: 11, height: 1.6),
              ),
          const SizedBox(height: 5),
          Text(
            '各组重新求取取样量和补液量；原始投料比不会约束其他试剂。额外配制比例仅用于整批备液。',
            style: TextStyle(
              fontSize: 11,
              height: 1.6,
              color: AppColors.of(context).muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _results(GradientPlan plan) {
    final pages = (plan.groups.length / _pageSize).ceil();
    final page = _page.clamp(0, math.max(0, pages - 1)).toInt();
    final groups = plan.groups.skip(page * _pageSize).take(_pageSize);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${plan.groups.length} 个条件 × ${plan.spec.replicates} 次重复 · ${plan.totals.failedGroupCount} 组不可行',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                '每组总体积 ${planningVolume(plan.baseline.totalVolumeMl)} · 基准 ${plan.baseline.substrateAt(plan.baseline.referenceSlot).name} = 1 · 下列为单次反应用量',
                style: const TextStyle(fontSize: 11, height: 1.6),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView(
            key: ValueKey('gradient-result-page-$page'),
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            children: [
              for (final warning in plan.warnings)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    warning.message,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.6,
                      color: AppColors.of(context).warningFg,
                    ),
                  ),
                ),
              LayoutBuilder(
                builder: (context, constraints) =>
                    constraints.maxWidth >= 850 &&
                        MediaQuery.textScalerOf(context).scale(1) <= 1.2
                    ? _overview(plan, groups.toList(), constraints.maxWidth)
                    : Column(
                        children: [
                          for (final group in groups)
                            GradientGroupCard(
                              group: group,
                              unit: plan.spec.unit,
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              key: const ValueKey('gradient-previous-page'),
              tooltip: '上一页',
              onPressed: page > 0 ? () => setState(() => _page--) : null,
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              '第 ${page + 1} / $pages 页',
              style: const TextStyle(fontSize: 12),
            ),
            IconButton(
              key: const ValueKey('gradient-next-page'),
              tooltip: '下一页',
              onPressed: page + 1 < pages
                  ? () => setState(() => _page++)
                  : null,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
      ],
    );
  }

  void _showGroupDetails(GradientGroup group, String unit) => showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('单次反应完整明细', style: TextStyle(fontSize: 17)),
      content: SizedBox(
        width: 950,
        child: SingleChildScrollView(
          child: GradientGroupCard(group: group, unit: unit),
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

  Widget _overview(
    GradientPlan plan,
    List<GradientGroup> groups,
    double width,
  ) {
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
              key: const ValueKey('gradient-overview-table'),
              showCheckboxColumn: false,
              horizontalMargin: 8,
              columnSpacing: 14,
              headingRowHeight: 44,
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
                  DataColumn(
                    label: Tooltip(
                      message: '${reagent.name} 每次取样量',
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 100),
                        child: Text(
                          '${reagent.name}\n取样量',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                const DataColumn(label: Text('补加溶剂')),
                const DataColumn(label: Text('状态 / 明细')),
              ],
              rows: [
                for (final group in groups)
                  DataRow(
                    onSelectChanged: (_) =>
                        _showGroupDetails(group, plan.spec.unit),
                    color: group.isValid
                        ? null
                        : WidgetStatePropertyAll(colors.errorBg),
                    cells: [
                      DataCell(
                        Text(
                          '条件 ${group.index + 1}\n${group.pointText} ${plan.spec.unit}${group.pointValue == 0 ? ' · 对照' : ''}',
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
                                onPressed: () =>
                                    _showGroupDetails(group, plan.spec.unit),
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

  Widget _preparation(GradientPlan plan) {
    final colors = AppColors.of(context);
    final advice = _stockAdvice;
    final adviceCurrent = advice != null && identical(advice.sourcePlan, plan);
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          plan.totals.validGroupsOnly ? '备液汇总 · 仅包含有效组' : '备液汇总 · 全部有效组',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: plan.totals.validGroupsOnly ? colors.errorFg : colors.text,
          ),
        ),
        for (final warning in plan.warnings)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(
              warning.message,
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: colors.warningFg,
              ),
            ),
          ),
        const SizedBox(height: 10),
        Text(
          '${plan.totals.validGroupCount} 个有效条件 × ${plan.spec.replicates} 次 = ${plan.totals.reactionCount} 次反应；额外配制 ${planningNumber(plan.spec.extraPreparationFraction * 100)}%',
          style: const TextStyle(fontSize: 12, height: 1.6),
        ),
        if (plan.totals.validGroupsOnly)
          Text(
            '${plan.totals.failedGroupCount} 个不可行条件已保留在逐组结果中，未计入下列备液量。',
            style: TextStyle(fontSize: 12, height: 1.6, color: colors.errorFg),
          ),
        const SizedBox(height: 12),
        for (final reagent in plan.baseline.substrates)
          _totalLine(
            '${reagent.name}${plan.workingStocks.any((p) => p.slot == reagent.slot) ? '（已采用工作液）' : ''}',
            planningVolume(plan.totals.aliquotsMl[reagent.slot] ?? 0),
          ),
        _totalLine('反应补加溶剂', planningVolume(plan.totals.diluentMl)),
        _totalLine('总配制体积', planningVolume(plan.totals.totalVolumeMl)),
        for (final adopted in plan.workingStocks) ...[
          const SizedBox(height: 16),
          Text(
            '已采用共同工作液 · ${plan.baseline.substrateAt(adopted.slot).name}',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          WorkingStockRecipe(proposal: adopted, batch: true),
        ],
        const SizedBox(height: 20),
        const Text(
          '梯度共用工作液',
          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          '优先检查所选试剂的所有正用量有效组能否共用一份工作液；范围过大时给出两档配制建议。0 对照保持零用量。',
          style: TextStyle(fontSize: 12, height: 1.6, color: colors.muted),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('gradient-stock-diluent'),
          controller: _diluent,
          onChanged: (_) => setState(() => _stockAdvice = null),
          decoration: const InputDecoration(
            labelText: '由你选择工作液稀释液',
            hintText: '例如 PBS、反应缓冲液或 DMSO',
          ),
        ),
        const SizedBox(height: 10),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(
            key: const ValueKey('gradient-stock-preview'),
            onPressed:
                plan.workingStocks.any((p) => p.slot == plan.spec.selectedSlot)
                ? null
                : () => _previewStock(plan),
            child: const Text('检查共用工作液'),
          ),
        ),
        if (plan.workingStocks.any((p) => p.slot == plan.spec.selectedSlot))
          const Text(
            '该试剂已采用共同工作液。若需更换，请回到条件设置重新生成梯度。',
            style: TextStyle(fontSize: 12, height: 1.6),
          ),
        if (adviceCurrent) ...[
          const SizedBox(height: 10),
          Text(
            advice.reason,
            style: TextStyle(
              fontSize: 12,
              height: 1.6,
              color: advice.feasible ? colors.text : colors.errorFg,
            ),
          ),
          if (advice.shared != null) ...[
            const SizedBox(height: 10),
            WorkingStockRecipe(proposal: advice.shared!, batch: true),
            if (advice.shared!.needsDilution && advice.shared!.feasible)
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton(
                  key: const ValueKey('gradient-stock-adopt'),
                  onPressed: _adoptStock,
                  child: const Text('采用共同工作液并重算整批'),
                ),
              ),
          ],
          for (var i = 0; i < advice.tiers.length; i++) ...[
            const SizedBox(height: 14),
            Text(
              '第 ${i + 1} 档建议 · 条件 ${advice.tiers[i].groupIndices.map((v) => v + 1).join('、')}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            WorkingStockRecipe(proposal: advice.tiers[i].proposal, batch: true),
          ],
          if (advice.tiers.isNotEmpty)
            Text(
              '两档方案为配制建议，尚未替换当前整批取样清单；执行前请按条件分档核对各组工作液取样量与补液量。',
              style: TextStyle(
                fontSize: 12,
                height: 1.6,
                color: colors.warningFg,
              ),
            ),
        ],
      ],
    );
  }

  Widget _totalLine(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12))),
        Text(
          value,
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ],
    ),
  );
}

class GradientGroupCard extends StatelessWidget {
  final GradientGroup group;
  final String unit;
  const GradientGroupCard({super.key, required this.group, required this.unit});
  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final result = group.result;
    return Container(
      key: ValueKey('gradient-group-${group.index}'),
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: group.isValid ? colors.surfaceSoft : colors.errorBg,
        border: Border.all(
          color: group.isValid ? colors.border : colors.errorFg,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '条件 ${group.index + 1} · ${group.pointText} ${unit.replaceFirst('u', 'µ')}${group.pointValue == 0 ? ' · 0 对照' : ''}${group.isValid ? '' : ' · 不可行'}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: group.isValid ? colors.text : colors.errorFg,
            ),
          ),
          if (result == null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                group.error ?? '条件无法计算',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.6,
                  color: colors.errorFg,
                ),
              ),
            )
          else ...[
            const SizedBox(height: 8),
            LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: DataTable(
                    columnSpacing: 22,
                    headingRowHeight: MediaQuery.textScalerOf(
                      context,
                    ).scale(30),
                    headingTextStyle: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: colors.text,
                    ),
                    dataRowMinHeight: MediaQuery.textScalerOf(
                      context,
                    ).scale(38),
                    dataRowMaxHeight: MediaQuery.textScalerOf(
                      context,
                    ).scale(38),
                    horizontalMargin: 0,
                    columns: const [
                      DataColumn(label: Text('试剂')),
                      DataColumn(label: Text('每次取样')),
                      DataColumn(label: Text('母液浓度（摩尔 / 质量）')),
                      DataColumn(label: Text('终浓度（摩尔 / 质量）')),
                      DataColumn(label: Text('投料比')),
                    ],
                    rows: [
                      for (final s in result.substrates)
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                s.name,
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${planningVolume(s.aliquotMl)}${result.warnings.any((w) => w.slot == s.slot && w.code == 'low_volume') ? ' ⚠' : ''}',
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${planningConcentration(s.stockMolarMm)}\n${planningConcentration(s.stockMassMgMl, molar: false)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                '${planningConcentration(s.finalMolarMm)}\n${planningConcentration(s.finalMassMgMl, molar: false)}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                s.ratio == null
                                    ? '不适用（基准为 0）'
                                    : planningNumber(s.ratio!),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
            Text(
              '补加溶剂 ${planningVolume(result.diluentVolumeMl)} · 总体积 ${planningVolume(result.totalVolumeMl)}',
              style: const TextStyle(fontSize: 11, height: 1.7),
            ),
            for (final warning in result.warnings)
              Text(
                warning.message,
                style: TextStyle(
                  fontSize: 10,
                  height: 1.6,
                  color: colors.warningFg,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
