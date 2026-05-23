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
    onFieldChanged('name', t.name);
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
    final title = input.name.isEmpty ? (isMain ? '主底物' : '副底物${index + 1}') : input.name;
    final enabled = isMain || input.enabled;

    final trailing = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(6),
          onTap: () async {
            final template = await showTemplatePicker(
              context,
              currentValues: _currentAsTemplate(),
            );
            if (template != null) {
              _loadTemplate(template);
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              border: Border.all(color: AppColors.border),
              borderRadius: BorderRadius.circular(6),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.bookmark_outline, size: 12, color: AppColors.muted),
                SizedBox(width: 2),
                Text('模板', style: TextStyle(fontSize: 10, color: AppColors.muted)),
              ],
            ),
          ),
        ),
        if (!isMain) ...[
          const SizedBox(width: 6),
          if (input.enabled)
            InkWell(
              onTap: onToggle,
              child: const Text('停用', style: TextStyle(fontSize: 9, color: AppColors.errorFg)),
            )
          else
            InkWell(
              onTap: onToggle,
              child: const Text('启用', style: TextStyle(fontSize: 9, color: AppColors.primary)),
            ),
        ],
      ],
    );

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: SectionCard(
        title: title,
        isMain: isMain,
        accentColor: isMain ? AppColors.mainRed : AppColors.secondaryBlue,
        trailing: trailing,
        padding: const EdgeInsets.all(10),
        children: [
          ChemicalFieldRow(
            label: '名称',
            value: input.name,
            onChanged: (v) => onFieldChanged('name', v),
            entryWidth: 120,
            hint: '底物名称',
            readOnly: !enabled,
          ),
          ChemicalFieldRow(
            label: '分子量',
            value: input.mw,
            onChanged: (v) => onFieldChanged('mw', v),
            unit: input.mwUnit,
            unitValues: CalculatorNotifier.mwUnits,
            onUnitChanged: (v) => onFieldChanged('mwUnit', v),
            hint: 'MW',
            readOnly: !enabled,
          ),
          ChemicalFieldRow(
            label: '母液浓度',
            value: input.storageConc,
            onChanged: (v) => onFieldChanged('storageConc', v),
            unit: input.storageUnit,
            unitValues: CalculatorNotifier.storageUnits,
            onUnitChanged: (v) => onFieldChanged('storageUnit', v),
            hint: '浓度',
            readOnly: !enabled,
          ),
          ChemicalFieldRow(
            label: '反应浓度',
            value: input.finalConc,
            onChanged: (v) => onFieldChanged('finalConc', v),
            unit: input.finalUnit,
            unitValues: CalculatorNotifier.storageUnits,
            onUnitChanged: (v) => onFieldChanged('finalUnit', v),
            hint: '终浓度',
            readOnly: !enabled,
          ),
          ChemicalFieldRow(
            label: '投料比',
            value: input.reactionRatio,
            onChanged: (v) => onFieldChanged('reactionRatio', v),
            hint: '比值',
            readOnly: !enabled,
          ),
          ChemicalFieldRow(
            label: '母液体积',
            value: input.storageVolume,
            onChanged: (v) => onFieldChanged('storageVolume', v),
            unit: input.storageVolumeUnit,
            unitValues: CalculatorNotifier.volumeUnits,
            onUnitChanged: (v) => onFieldChanged('storageVolumeUnit', v),
            hint: '体积',
            readOnly: !enabled,
          ),
        ],
      ),
    );
  }
}
