import 'package:flutter/foundation.dart';
import 'package:ilovebioconjugation/export/experiment_markdown.dart';
import 'package:ilovebioconjugation/ui/planning/record_actions.dart';
import 'package:ilovebioconjugation/ui/planning/gradient_dialog.dart';
import 'package:ilovebioconjugation/ui/planning/working_stock_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/calculator/state.dart';
import 'package:ilovebioconjugation/ui/calculator/widgets/chemical_card.dart';
import 'package:ilovebioconjugation/ui/calculator/widgets/reaction_settings_card.dart';
import 'package:ilovebioconjugation/ui/calculator/widgets/result_data_table.dart';
import 'package:ilovebioconjugation/ui/calculator/widgets/result_metrics_row.dart';
import 'package:ilovebioconjugation/ui/calculator/widgets/status_banner.dart';
import 'package:ilovebioconjugation/ui/shared/section_card.dart';
import 'package:ilovebioconjugation/ui/shared/confirm_reset_dialog.dart';

class CalculatorScreen extends ConsumerStatefulWidget {
  final bool openPlanning;
  const CalculatorScreen({super.key, this.openPlanning = false});

  @override
  ConsumerState<CalculatorScreen> createState() => _CalculatorScreenState();
}

class _CalculatorScreenState extends ConsumerState<CalculatorScreen> {
  final _resultsKey = GlobalKey();
  final _resultsScroll = ScrollController();
  final _pageScroll = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.openPlanning) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showGradientDialog(context);
      });
    }
  }

  bool get _mac => defaultTargetPlatform == TargetPlatform.macOS;

  @override
  void dispose() {
    _resultsScroll.dispose();
    _pageScroll.dispose();
    super.dispose();
  }

  void _calculate() {
    FocusScope.of(context).unfocus();
    ref.read(calculatorProvider.notifier).calculate();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final resultContext = _resultsKey.currentContext;
      if (mounted && resultContext != null) {
        Scrollable.ensureVisible(
          resultContext,
          duration: Duration(milliseconds: 240),
          alignment: 0,
        );
      }
    });
  }

  Future<void> _copyResults() async {
    final text = ref.read(calculatorProvider.notifier).buildCopyText();
    if (text.isEmpty) return;
    try {
      await Clipboard.setData(ClipboardData(text: text));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('计算结果已复制'), duration: Duration(seconds: 2)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('无法访问剪贴板，请稍后重试')));
    }
  }

  Future<void> _confirmReset() async {
    final confirmed = await confirmCalculationReset(context);
    if (confirmed == true && mounted) {
      ref.read(calculatorProvider.notifier).reset();
      if (_pageScroll.hasClients) _pageScroll.jumpTo(0);
      if (_resultsScroll.hasClients) _resultsScroll.jumpTo(0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calculatorProvider);
    final notifier = ref.read(calculatorProvider.notifier);
    return CallbackShortcuts(
      // Preserve standard text editing (especially Cmd/Ctrl+C) inside fields.
      bindings: {
        SingleActivator(LogicalKeyboardKey.enter, control: !_mac, meta: _mac):
            _calculate,
        SingleActivator(
          LogicalKeyboardKey.keyC,
          control: !_mac,
          meta: _mac,
          shift: true,
        ): _copyResults,
        SingleActivator(
          LogicalKeyboardKey.keyH,
          control: !_mac,
          meta: _mac,
          shift: true,
        ): () =>
            context.go('/history'),
      },
      child: Focus(
        autofocus: true,
        child: Column(
          children: [
            _header(state),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // A bounded desktop canvas fits four active reagents at
                  // 1366×768. Enlarged text and smaller windows retain natural
                  // scrolling rather than scaling down or clipping controls.
                  final desktop =
                      constraints.maxWidth >= 1050 &&
                      constraints.maxHeight >= 610 &&
                      MediaQuery.textScalerOf(context).scale(1) <= 1.05;
                  if (desktop) return _desktopWorkspace(state, notifier);
                  return SingleChildScrollView(
                    controller: _pageScroll,
                    padding: EdgeInsets.all(
                      constraints.maxWidth < 600 ? 16 : 28,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: 900),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _inputs(state, notifier),
                            SizedBox(height: 28),
                            _results(state),
                            SizedBox(height: 16),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _resultReference(CalculatorState state) {
    final raw = state.rawResult;
    final enteredName = state.substrates[state.referenceSlot].name.trim();
    final name =
        raw?.substrateAt(state.referenceSlot).name ??
        (enteredName.isEmpty
            ? (state.referenceSlot == 0 ? '主底物' : '副底物${state.referenceSlot}')
            : enteredName);
    if (raw != null && raw.substrateAt(state.referenceSlot).ratio == null) {
      return '$name 为 0，比值不适用';
    }
    return '$name = 1';
  }

  Widget _referenceSelector(
    CalculatorState state,
    CalculatorNotifier notifier,
  ) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '基准',
        style: TextStyle(fontSize: 11, color: AppColors.of(context).muted),
      ),
      const SizedBox(width: 8),
      Flexible(
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            key: const ValueKey('ratio-reference-selector'),
            value: state.referenceSlot,
            isDense: true,
            isExpanded: true,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontSize: 12),
            items: [
              for (var i = 0; i < state.substrates.length; i++)
                if (state.substrates[i].enabled)
                  DropdownMenuItem(
                    value: i,
                    child: Text(
                      i == state.referenceSlot
                          ? _resultReference(state)
                          : '${state.substrates[i].name.isEmpty ? '底物$i' : state.substrates[i].name} = 1',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
            ],
            onChanged: (value) {
              if (value == null) return;
              final accepted = notifier.setReferenceSlot(value);
              if (!accepted && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(ref.read(calculatorProvider).planningMessage),
                  ),
                );
              }
            },
          ),
        ),
      ),
    ],
  );

  Widget _resultTable(CalculatorState state, {bool compact = false}) =>
      ResultDataTableWidget(
        rows: state.rows,
        compact: compact,
        lowVolumeRows: {
          for (var i = 0; i < state.rows.length; i++)
            if (state.rows[i].lowVolume) i,
        },
        onWorkingStock: (index) =>
            showWorkingStockDialog(context, state.rows[index].sourceSlot),
      );

  List<String> _extraWarnings(CalculatorState state) => [
    for (final warning in state.rawResult?.warnings ?? [])
      if (warning.code != 'low_volume') warning.message,
  ];

  Widget _desktopStatus(CalculatorState state) {
    final warnings = _extraWarnings(state);
    final details = [
      if (state.historySaveError.isNotEmpty) state.historySaveError,
      ...warnings,
    ];
    final text = state.statusLevel == StatusLevel.error
        ? '请检查输入'
        : state.historySaveError.isNotEmpty
        ? '计算完成 · 历史记录未保存${warnings.isEmpty ? '' : '，另有操作提醒'}（点击详情）'
        : details.isNotEmpty
        ? '⚠ ${details.first}（点击详情）'
        : state.rows.isEmpty
        ? '待计算'
        : state.statusLevel == StatusLevel.success
        ? '基准 ${_resultReference(state)} · 请核对取样量'
        : state.statusMessage;
    return Semantics(
      liveRegion: true,
      child: Tooltip(
        message: details.isEmpty ? state.statusMessage : details.join('\n'),
        child: InkWell(
          key: const ValueKey('result-warning-details'),
          onTap: details.isEmpty
              ? null
              : () => showDialog<void>(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('请核对计算提醒'),
                    content: SingleChildScrollView(
                      child: Text(
                        details.join('\n\n'),
                        style: const TextStyle(fontSize: 13, height: 1.6),
                      ),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('关闭'),
                      ),
                    ],
                  ),
                ),
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color:
                  details.isNotEmpty || state.statusLevel == StatusLevel.warning
                  ? AppColors.of(context).warningFg
                  : AppColors.of(context).muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _header(CalculatorState state) => Container(
    width: double.infinity,
    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.of(context).surface,
      border: Border(bottom: BorderSide(color: AppColors.of(context).border)),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final title = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '投料计算工作台',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                letterSpacing: -.3,
              ),
            ),
          ],
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Tooltip(
              message: '${_mac ? '⌘' : 'Ctrl'} + Enter',
              child: FilledButton.icon(
                key: ValueKey('calculate-button'),
                onPressed: _calculate,
                icon: Icon(Icons.arrow_forward, size: 17),
                label: Text('运行计算'),
              ),
            ),
            Tooltip(
              message: state.rows.isEmpty
                  ? '计算成功后可复制结果'
                  : '${_mac ? '⌘' : 'Ctrl'} + Shift + C',
              child: OutlinedButton.icon(
                key: ValueKey('copy-results-button'),
                onPressed: state.rows.isEmpty ? null : _copyResults,
                icon: Icon(Icons.copy_outlined, size: 16),
                label: Text('复制结果'),
              ),
            ),
            OutlinedButton.icon(
              key: const ValueKey('gradient-planning-button'),
              onPressed: () => showGradientDialog(context),
              icon: const Icon(Icons.stacked_line_chart, size: 16),
              label: const Text('梯度方案'),
            ),
            RecordActions(
              resultToken: state.rawResult,
              buildMarkdown: () => state.rawResult == null
                  ? ''
                  : buildCalculationMarkdown(state.rawResult!),
            ),
            IconButton(
              tooltip: '清空当前计算',
              onPressed: _confirmReset,
              icon: Icon(Icons.restart_alt, size: 21),
            ),
          ],
        );
        if (constraints.maxWidth >= 720) {
          return Row(
            children: [
              Expanded(child: title),
              SizedBox(width: 16),
              actions,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [title, SizedBox(height: 12), actions],
        );
      },
    ),
  );

  Widget _desktopWorkspace(
    CalculatorState state,
    CalculatorNotifier notifier,
  ) => Padding(
    key: const ValueKey('desktop-workspace'),
    padding: const EdgeInsets.fromLTRB(24, 18, 24, 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ReactionSettingsCard(
          compact: true,
          volume: state.reactionVolume,
          volumeUnit: state.reactionVolumeUnit,
          ratioType: state.ratioType,
          onVolumeChanged: notifier.setReactionVolume,
          onVolumeUnitChanged: notifier.setReactionVolumeUnit,
          onRatioTypeChanged: notifier.setRatioType,
          referenceSelector: _referenceSelector(state, notifier),
        ),
        const SizedBox(height: 14),
        Container(
          key: const ValueKey('desktop-input-matrix'),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          decoration: BoxDecoration(
            color: AppColors.of(context).surface,
            border: Border.all(color: AppColors.of(context).border),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  const Text(
                    '底物参数',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Tooltip(
                      message: '基准：${_resultReference(state)}',
                      child: Text(
                        '基准：${_resultReference(state)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.of(context).muted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    '未知项留空',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppColors.of(context).muted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ChemicalMatrixColumns(
                cells: [
                  for (final label in [
                    '底物 / 名称',
                    '分子量',
                    '母液浓度',
                    '目标终浓度',
                    '投料比',
                    '取样体积',
                    '',
                  ])
                    Padding(
                      padding: const EdgeInsets.only(bottom: 1),
                      child: Text(
                        label,
                        style: TextStyle(
                          fontSize: 10,
                          color: AppColors.of(context).muted,
                        ),
                      ),
                    ),
                ],
              ),
              for (var index = 0; index < state.substrates.length; index++)
                ChemicalCard(
                  key: ValueKey('substrate-$index'),
                  compact: true,
                  index: index,
                  input: state.substrates[index],
                  isMain: index == 0,
                  onToggle: index == 0
                      ? null
                      : () => notifier.toggleSubstrateEnabled(index),
                  onFieldChanged: (field, value) =>
                      notifier.setSubstrateField(index, field, value),
                  onTemplateSelected: (template) =>
                      notifier.applyTemplate(index, template),
                ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Flexible(
          fit: FlexFit.loose,
          child: SingleChildScrollView(
            controller: _resultsScroll,
            key: const ValueKey('desktop-results-scroll'),
            child: Container(
              key: _resultsKey,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.of(context).surface,
                border: Border.all(color: AppColors.of(context).border),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text(
                        '取样清单',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(child: _desktopStatus(state)),
                    ],
                  ),
                  if (state.rows.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    ResultMetricsRow(metrics: state.metrics, compact: true),
                    const SizedBox(height: 10),
                  ],
                  if (state.statusLevel == StatusLevel.error) ...[
                    const SizedBox(height: 10),
                    StatusBanner(
                      message: state.statusMessage,
                      level: state.statusLevel,
                      detail: state.errorMessage,
                    ),
                  ],
                  if (state.statusLevel != StatusLevel.error)
                    _resultTable(state, compact: true),
                ],
              ),
            ),
          ),
        ),
      ],
    ),
  );

  Widget _inputs(CalculatorState state, CalculatorNotifier notifier) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ReactionSettingsCard(
        volume: state.reactionVolume,
        volumeUnit: state.reactionVolumeUnit,
        ratioType: state.ratioType,
        onVolumeChanged: notifier.setReactionVolume,
        onVolumeUnitChanged: notifier.setReactionVolumeUnit,
        onRatioTypeChanged: notifier.setRatioType,
        referenceSelector: _referenceSelector(state, notifier),
      ),
      SizedBox(height: 18),
      Row(
        children: [
          Expanded(
            child: Text(
              '底物参数',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '${state.substrates.where((s) => s.enabled).length} 种已启用',
            style: TextStyle(fontSize: 12, color: AppColors.of(context).muted),
          ),
        ],
      ),
      SizedBox(height: 12),
      LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 560 ? 2 : 1;
          final cardWidth =
              (constraints.maxWidth - (columns - 1) * 16) / columns;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: List.generate(
              state.substrates.length,
              (index) => SizedBox(
                width: cardWidth,
                child: ChemicalCard(
                  key: ValueKey('substrate-$index'),
                  index: index,
                  input: state.substrates[index],
                  isMain: index == 0,
                  onToggle: index == 0
                      ? null
                      : () => notifier.toggleSubstrateEnabled(index),
                  onFieldChanged: (field, value) =>
                      notifier.setSubstrateField(index, field, value),
                  onTemplateSelected: (template) =>
                      notifier.applyTemplate(index, template),
                ),
              ),
            ),
          );
        },
      ),
    ],
  );

  Widget _results(CalculatorState state) => Column(
    key: _resultsKey,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        '计算结果 · 基准 ${_resultReference(state)}',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),

      SizedBox(height: 18),
      StatusBanner(
        message: state.statusMessage,
        level: state.statusLevel,
        detail: state.statusLevel == StatusLevel.error
            ? state.errorMessage
            : null,
      ),
      if (state.historySaveError.isNotEmpty) ...[
        SizedBox(height: 12),
        StatusBanner(
          message: state.historySaveError,
          level: StatusLevel.warning,
        ),
      ],
      for (final warning in _extraWarnings(state)) ...[
        const SizedBox(height: 12),
        StatusBanner(message: warning, level: StatusLevel.warning),
      ],
      SizedBox(height: 16),
      if (state.rows.isNotEmpty) ...[
        ResultMetricsRow(metrics: state.metrics),
        SizedBox(height: 16),
      ],
      SectionCard(title: '取样清单', children: [_resultTable(state)]),
      if (state.rows.isNotEmpty) ...[
        SizedBox(height: 12),
        Text(
          '结果基于所填条件；请结合实际实验要求核对。',
          style: TextStyle(fontSize: 11, color: AppColors.of(context).muted),
        ),
      ],
    ],
  );
}
