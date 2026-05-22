import 'package:flutter/material.dart';
import 'package:ilovebioconjunction/data/substrate_template.dart';
import 'package:ilovebioconjunction/theme/app_colors.dart';
import 'package:ilovebioconjunction/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjunction/ui/calculator/state.dart';
import 'package:ilovebioconjunction/ui/calculator/widgets/chemical_field_row.dart';
import 'package:ilovebioconjunction/ui/shared/section_card.dart';
import 'package:ilovebioconjunction/ui/templates/template_picker_dialog.dart';

class ChemicalCard extends StatelessWidget {
  final int index;
  final SubstrateInput input;
  final bool isMain;
  final VoidCallback? onToggle;
  final void Function(String field, String value) onFieldChanged;

  const ChemicalCard({
    super.key,
    required this.index,
    required this.input,
    required this.isMain,
    this.onToggle,
    required this.onFieldChanged,
  });

  void _loadTemplate(SubstrateTemplate t) {
    if (t.molecularWeight != null) onFieldChanged('mw', t.molecularWeight.toString());
    onFieldChanged('mwUnit', t.mwUnit);
    if (t.storageConcentration != null) onFieldChanged('storageConc', t.storageConcentration.toString());
    onFieldChanged('storageUnit', t.storageUnit);
    if (t.defaultFinalConc != null) onFieldChanged('finalConc', t.defaultFinalConc.toString());
    onFieldChanged('finalUnit', t.defaultFinalUnit);
    if (t.defaultReactionRatio != null) onFieldChanged('reactionRatio', t.defaultReactionRatio.toString());
  }

  SubstrateTemplate _currentAsTemplate() {
    final mw = double.tryParse(input.mw);
    final storageConc = double.tryParse(input.storageConc);
    final finalConc = double.tryParse(input.finalConc);
    final ratio = double.tryParse(input.reactionRatio);
    final now = DateTime.now().toIso8601String();
    return SubstrateTemplate(
      name: input.name,
      molecularWeight: mw,
      mwUnit: input.mwUnit,
      storageConcentration: storageConc,
      storageUnit: input.storageUnit,
      defaultFinalConc: finalConc,
      defaultFinalUnit: input.finalUnit,
      defaultReactionRatio: ratio,
      createdAt: now,
      updatedAt: now,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: input.name.isEmpty ? (isMain ? '主底物' : '副底物${index + 1}') : input.name,
      isMain: isMain,
      padding: const EdgeInsets.all(8),
      trailing: IconButton(
        icon: const Icon(Icons.bookmark_outline, size: 14),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 24, minHeight: 24),
        tooltip: '模板',
        onPressed: () async {
          final template = await showTemplatePicker(
            context,
            currentValues: _currentAsTemplate(),
          );
          if (template != null) {
            _loadTemplate(template);
          }
        },
      ),
      children: [
        if (!isMain) ...[
          Row(
            children: [
              Text(
                input.enabled ? '状态：已启用' : '状态：未启用',
                style: TextStyle(
                  fontSize: 10,
                  color: input.enabled ? AppColors.successFg : AppColors.muted,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: onToggle,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  input.enabled ? '停用' : '启用',
                  style: const TextStyle(fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],
        ChemicalFieldRow(
          label: '名称',
          value: input.name,
          onChanged: (v) => onFieldChanged('name', v),
          entryWidth: 120,
        ),
        ChemicalFieldRow(
          label: '分子量',
          value: input.mw,
          onChanged: (v) => onFieldChanged('mw', v),
          unit: input.mwUnit,
          unitValues: CalculatorNotifier.mwUnits,
          onUnitChanged: (v) => onFieldChanged('mwUnit', v),
        ),
        ChemicalFieldRow(
          label: '母液浓度',
          value: input.storageConc,
          onChanged: (v) => onFieldChanged('storageConc', v),
          unit: input.storageUnit,
          unitValues: CalculatorNotifier.storageUnits,
          onUnitChanged: (v) => onFieldChanged('storageUnit', v),
        ),
        ChemicalFieldRow(
          label: '反应浓度',
          value: input.finalConc,
          onChanged: (v) => onFieldChanged('finalConc', v),
          unit: input.finalUnit,
          unitValues: CalculatorNotifier.storageUnits,
          onUnitChanged: (v) => onFieldChanged('finalUnit', v),
        ),
        ChemicalFieldRow(
          label: '投料比',
          value: input.reactionRatio,
          onChanged: (v) => onFieldChanged('reactionRatio', v),
          entryWidth: 100,
        ),
        ChemicalFieldRow(
          label: '母液体积',
          value: input.storageVolume,
          onChanged: (v) => onFieldChanged('storageVolume', v),
          unit: input.storageVolumeUnit,
          unitValues: CalculatorNotifier.volumeUnits,
          onUnitChanged: (v) => onFieldChanged('storageVolumeUnit', v),
        ),
        const SizedBox(height: 4),
        const Text(
          '可只填部分条件，系统会自动求解未知变量',
          style: TextStyle(fontSize: 9, color: AppColors.muted),
        ),
      ],
    );
  }
}
