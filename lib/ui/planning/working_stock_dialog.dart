import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilovebioconjugation/core/planning.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/settings/app_settings.dart';
import 'package:ilovebioconjugation/ui/planning/planning_format.dart';

Future<void> showWorkingStockDialog(BuildContext context, int slot) =>
    showDialog<void>(
      context: context,
      builder: (_) => WorkingStockDialog(slot: slot),
    );

class WorkingStockDialog extends ConsumerStatefulWidget {
  final int slot;
  const WorkingStockDialog({super.key, required this.slot});
  @override
  ConsumerState<WorkingStockDialog> createState() => _WorkingStockDialogState();
}

class _WorkingStockDialogState extends ConsumerState<WorkingStockDialog> {
  final _diluent = TextEditingController();
  final _factor = TextEditingController();
  final _extra = TextEditingController(text: '0');
  WorkingStockProposal? _proposal;
  String? _error;
  bool _adopting = false;
  @override
  void dispose() {
    _diluent.dispose();
    _factor.dispose();
    _extra.dispose();
    super.dispose();
  }

  void _changed(String _) => setState(() {
    _proposal = null;
    _error = null;
  });
  void _preview() {
    final factor = _factor.text.trim().isEmpty
        ? null
        : double.tryParse(_factor.text.trim());
    final extra = double.tryParse(_extra.text.trim());
    if (_diluent.text.trim().isEmpty) {
      setState(() => _error = '请指定实际使用的稀释液');
      return;
    }
    if ((_factor.text.trim().isNotEmpty &&
            (factor == null || !factor.isFinite || factor < 1)) ||
        extra == null ||
        !extra.isFinite ||
        extra < 0) {
      setState(() => _error = '稀释倍数须为大于或等于 1 的有限数字；额外配制比例须大于或等于 0');
      return;
    }
    final proposal = ref
        .read(calculatorProvider.notifier)
        .proposeWorkingStock(
          widget.slot,
          dilutionFactor: factor,
          diluentName: _diluent.text.trim(),
          extraFraction: extra / 100,
        );
    setState(() {
      _proposal = proposal;
      _error = proposal == null
          ? ref.read(calculatorProvider).planningMessage
          : null;
    });
  }

  void _adopt() {
    if (_adopting || _proposal == null) return;
    setState(() => _adopting = true);
    final accepted = ref
        .read(calculatorProvider.notifier)
        .adoptWorkingStock(_proposal!);
    if (accepted) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _adopting = false;
        _error = ref.read(calculatorProvider).planningMessage;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(calculatorProvider);
    final threshold = ref.watch(appSettingsProvider).minimumPipettingVolumeUl;
    final proposal = _proposal;
    final stale =
        proposal != null && !identical(proposal.sourceResult, state.rawResult);
    final colors = AppColors.of(context);
    final name = state.substrates[widget.slot].name;
    return AlertDialog(
      title: Text('计算工作液 · $name', style: const TextStyle(fontSize: 18)),
      content: SizedBox(
        width: 590,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '最小移液量 ${planningNumber(threshold)} µL。保持本次反应的试剂用量与总体积不变，增加工作液取样量并减少补液。',
                style: const TextStyle(fontSize: 12, height: 1.6),
              ),
              const SizedBox(height: 16),
              TextField(
                key: const ValueKey('working-stock-diluent'),
                controller: _diluent,
                onChanged: _changed,
                decoration: const InputDecoration(
                  labelText: '稀释液（由你选择）',
                  hintText: '例如 PBS、反应缓冲液或 DMSO',
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  SizedBox(
                    width: 230,
                    child: TextField(
                      key: const ValueKey('working-stock-factor'),
                      controller: _factor,
                      onChanged: _changed,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '稀释倍数',
                        hintText: '留空：按最小移液量建议',
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 230,
                    child: TextField(
                      key: const ValueKey('working-stock-extra'),
                      controller: _extra,
                      onChanged: _changed,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: '额外配制',
                        suffixText: '%（仅备液）',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('working-stock-preview'),
                  onPressed: _preview,
                  icon: const Icon(Icons.calculate_outlined, size: 16),
                  label: const Text('计算配制方案'),
                ),
              ),
              if (_error != null || stale)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    stale ? '原始计算已变化，请重新计算工作液方案。' : _error!,
                    style: TextStyle(color: colors.errorFg, fontSize: 12),
                  ),
                ),
              if (proposal != null && !stale) ...[
                const SizedBox(height: 12),
                WorkingStockRecipe(proposal: proposal),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _adopting ? null : () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          key: const ValueKey('working-stock-adopt'),
          onPressed: proposal?.feasible == true && !stale && !_adopting
              ? _adopt
              : null,
          child: const Text('采用工作液并重算'),
        ),
      ],
    );
  }
}

class WorkingStockRecipe extends StatelessWidget {
  final WorkingStockProposal proposal;
  final bool batch;
  const WorkingStockRecipe({
    super.key,
    required this.proposal,
    this.batch = false,
  });
  @override
  Widget build(BuildContext context) {
    final p = proposal;
    final colors = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.feasible ? colors.surfaceSoft : colors.errorBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            p.feasible ? '可配制 · ${planningNumber(p.factor)} 倍稀释' : '方案不可行',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: p.feasible ? colors.successFg : colors.errorFg,
            ),
          ),
          if (p.reason.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(p.reason, style: const TextStyle(fontSize: 12, height: 1.5)),
          ],
          const SizedBox(height: 10),
          Text(
            '原母液：${planningConcentration(p.parentStockMolarMm)} / ${planningConcentration(p.parentStockMassMgMl, molar: false)}\n工作液：${planningConcentration(p.stockMolarMm)} / ${planningConcentration(p.stockMassMgMl, molar: false)}',
            style: const TextStyle(fontSize: 12, height: 1.7),
          ),
          const SizedBox(height: 8),
          Text(
            '配制：原母液 ${planningVolume(p.parentStockMl)} + ${p.diluentName.isEmpty ? '所选稀释液' : p.diluentName} ${planningVolume(p.diluentMl)} = ${planningVolume(p.preparationVolumeMl)}\n需求量：${planningVolume(p.requiredVolumeMl)}；${batch ? '示例条件每次' : '本组每次'}取工作液 ${planningVolume(p.newAliquotMl)}',
            style: const TextStyle(
              fontSize: 12,
              height: 1.7,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '溶剂 / DMSO 提醒：此方案会改变反应的溶剂组成。软件未获知原母液的溶剂比例，无法核定最终 DMSO 含量；采用前请确认溶解度、缓冲液兼容性与可接受的溶剂比例。',
            style: TextStyle(
              fontSize: 11,
              height: 1.6,
              color: colors.warningFg,
            ),
          ),
        ],
      ),
    );
  }
}
