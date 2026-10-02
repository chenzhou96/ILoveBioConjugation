import 'package:flutter/material.dart';
import 'package:ilovebioconjugation/data/substrate_template.dart';
import 'package:ilovebioconjugation/core/validators.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/calculator/state.dart';
import 'package:ilovebioconjugation/ui/calculator/widgets/chemical_field_row.dart';
import 'package:ilovebioconjugation/ui/shared/section_card.dart';
import 'package:ilovebioconjugation/ui/templates/template_picker_dialog.dart';

class ChemicalCard extends StatelessWidget {
  final int index;
  final SubstrateInput input;
  final bool isMain;
  final bool compact;
  final VoidCallback? onToggle;
  final void Function(String field, String value) onFieldChanged;
  final ValueChanged<SubstrateTemplate> onTemplateSelected;

  const ChemicalCard({
    super.key,
    required this.index,
    required this.input,
    required this.isMain,
    this.compact = false,
    this.onToggle,
    required this.onFieldChanged,
    required this.onTemplateSelected,
  });

  SubstrateTemplate _currentAsTemplate() {
    final now = DateTime.now().toIso8601String();
    return SubstrateTemplate(
      name: input.name,
      molecularWeight: _templateNumber(input.mw, '分子量'),
      mwUnit: input.mwUnit,
      storageConcentration: _templateNumber(input.storageConc, '母液浓度'),
      storageUnit: input.storageUnit,
      defaultFinalConc: _templateNumber(
        input.finalConc,
        '终浓度',
        allowZero: true,
      ),
      defaultFinalUnit: input.finalUnit,
      defaultReactionRatio: _templateNumber(input.reactionRatio, '投料比'),
      createdAt: now,
      updatedAt: now,
    );
  }

  double? _templateNumber(String raw, String label, {bool allowZero = false}) {
    double? value;
    try {
      value = parseFloatOrNull(raw);
    } on ArgumentError {
      throw ArgumentError('$label必须是有限数字');
    }
    if (value != null && (value < 0 || (!allowZero && value == 0))) {
      throw ArgumentError('$label必须${allowZero ? '大于或等于' : '大于'} 0');
    }
    return value;
  }

  @override
  Widget build(BuildContext context) {
    final role = isMain ? '主底物' : '副底物$index';
    final enabled = isMain || input.enabled;
    if (compact) return _matrixRow(context, role, enabled);
    return SectionCard(
      title: role,

      padding: EdgeInsets.all(16),
      trailing: isMain
          ? Icon(
              Icons.science_outlined,
              color: AppColors.of(context).accent,
              size: 22,
            )
          : Semantics(
              label: '$role参与计算',
              child: Switch.adaptive(
                value: enabled,
                onChanged: (_) => onToggle?.call(),
              ),
            ),
      children: enabled
          ? [
              ChemicalFieldRow(
                label: '名称',
                value: input.name,
                numeric: false,
                semanticLabel: '$role名称',
                hint: '如：抗体、连接剂',
                onChanged: (value) => onFieldChanged('name', value),
              ),
              ChemicalFieldRow(
                label: '分子量',
                value: input.mw,
                hint: '换算时填写',
                semanticLabel: '$role分子量',
                onChanged: (value) => onFieldChanged('mw', value),
                unit: input.mwUnit,
                unitValues: CalculatorNotifier.mwUnits,
                onUnitChanged: (value) => onFieldChanged('mwUnit', value),
              ),
              ChemicalFieldRow(
                label: '母液浓度',
                value: input.storageConc,
                hint: '实际配制浓度',
                semanticLabel: '$role母液浓度',
                onChanged: (value) => onFieldChanged('storageConc', value),
                unit: input.storageUnit,
                unitValues: CalculatorNotifier.storageUnits,
                onUnitChanged: (value) => onFieldChanged('storageUnit', value),
              ),
              Divider(height: 18),
              ChemicalFieldRow(
                label: '目标终浓度',
                value: input.finalConc,
                hint: '已知时填写',
                semanticLabel: '$role目标终浓度',
                onChanged: (value) => onFieldChanged('finalConc', value),
                unit: input.finalUnit,
                unitValues: CalculatorNotifier.storageUnits,
                onUnitChanged: (value) => onFieldChanged('finalUnit', value),
              ),
              ChemicalFieldRow(
                label: '投料比',
                value: input.reactionRatio,
                semanticLabel: '$role投料比',
                hint: isMain ? '参考比例，通常为 1' : '相对于主底物',
                onChanged: (value) => onFieldChanged('reactionRatio', value),
              ),
              ChemicalFieldRow(
                label: '母液取样体积',
                value: input.storageVolume,
                hint: '已知取样量时填写',
                semanticLabel: '$role母液取样体积',
                onChanged: (value) => onFieldChanged('storageVolume', value),
                unit: input.storageVolumeUnit,
                unitValues: CalculatorNotifier.volumeUnits,
                onUnitChanged: (value) =>
                    onFieldChanged('storageVolumeUnit', value),
              ),
              TextButton.icon(
                onPressed: () => _openTemplate(context),
                icon: Icon(Icons.bookmark_outline, size: 17),
                label: Text('使用 / 保存模板'),
              ),
            ]
          : [],
    );
  }

  Future<void> _openTemplate(BuildContext context) async {
    SubstrateTemplate? currentValues;
    String? warning;
    try {
      currentValues = _currentAsTemplate();
    } on ArgumentError catch (error) {
      warning = '当前参数无法保存：${error.message}。修正后可保存，也可先加载已有模板。';
    }
    final template = await showTemplatePicker(
      context,
      currentValues: currentValues,
      currentValuesWarning: warning,
    );
    if (template != null) onTemplateSelected(template);
  }

  Widget _matrixRow(BuildContext context, String role, bool enabled) {
    Widget field(
      String label,
      String value,
      String name, {
      String? unit,
      List<String>? units,
      String? unitField,
      bool numeric = true,
    }) => ChemicalFieldRow(
      compact: true,
      label: label,
      semanticLabel: '$role$label',
      value: value,
      numeric: numeric,
      unit: unit,
      unitValues: units,
      onChanged: (value) => onFieldChanged(name, value),
      onUnitChanged: unitField == null
          ? null
          : (value) => onFieldChanged(unitField, value),
    );
    final toggle = SizedBox(
      width: 26,
      child: isMain
          ? Tooltip(
              message: '投料比参考底物',
              child: Icon(
                Icons.science_outlined,
                size: 17,
                color: AppColors.of(context).accent,
              ),
            )
          : Checkbox(
              value: enabled,
              semanticLabel: '$role参与计算',
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              onChanged: (_) => onToggle?.call(),
            ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ChemicalMatrixColumns(
        cells: [
          Row(
            children: [
              toggle,
              const SizedBox(width: 5),
              SizedBox(
                width: 42,
                child: Text(
                  role,
                  style: TextStyle(
                    fontSize: 10,
                    color: AppColors.of(context).muted,
                  ),
                ),
              ),
              Expanded(
                child: enabled
                    ? field('名称', input.name, 'name', numeric: false)
                    : Padding(
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        child: Text(
                          '未启用',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.of(context).muted,
                          ),
                        ),
                      ),
              ),
            ],
          ),
          if (enabled) ...[
            field(
              '分子量',
              input.mw,
              'mw',
              unit: input.mwUnit,
              units: CalculatorNotifier.mwUnits,
              unitField: 'mwUnit',
            ),
            field(
              '母液浓度',
              input.storageConc,
              'storageConc',
              unit: input.storageUnit,
              units: CalculatorNotifier.storageUnits,
              unitField: 'storageUnit',
            ),
            field(
              '目标终浓度',
              input.finalConc,
              'finalConc',
              unit: input.finalUnit,
              units: CalculatorNotifier.storageUnits,
              unitField: 'finalUnit',
            ),
            field('投料比', input.reactionRatio, 'reactionRatio'),
            field(
              '母液取样体积',
              input.storageVolume,
              'storageVolume',
              unit: input.storageVolumeUnit,
              units: CalculatorNotifier.volumeUnits,
              unitField: 'storageVolumeUnit',
            ),
            IconButton(
              tooltip: '$role使用 / 保存模板',
              style: const ButtonStyle(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () => _openTemplate(context),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 28, minHeight: 32),
              icon: Icon(
                Icons.bookmark_outline,
                size: 17,
                color: AppColors.of(context).muted,
              ),
            ),
          ] else
            ...List.generate(6, (_) => const SizedBox.shrink()),
        ],
      ),
    );
  }
}

/// Shares the exact column alignment between the desktop labels and input rows.
class ChemicalMatrixColumns extends StatelessWidget {
  final List<Widget> cells;
  const ChemicalMatrixColumns({super.key, required this.cells});

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      for (var index = 0; index < cells.length; index++) ...[
        if (index > 0) const SizedBox(width: 10),
        if (index == 6)
          SizedBox(width: 28, child: cells[index])
        else
          Expanded(flex: [23, 17, 20, 20, 9, 18][index], child: cells[index]),
      ],
    ],
  );
}
