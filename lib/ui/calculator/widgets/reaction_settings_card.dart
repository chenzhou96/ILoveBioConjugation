import 'package:flutter/material.dart';
import 'package:ilovebioconjunction/theme/app_colors.dart';
import 'package:ilovebioconjunction/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjunction/ui/shared/section_card.dart';
import 'package:ilovebioconjunction/ui/shared/unit_dropdown.dart';

class ReactionSettingsCard extends StatelessWidget {
  final String volume;
  final String volumeUnit;
  final bool ratioType;
  final ValueChanged<String> onVolumeChanged;
  final ValueChanged<String> onVolumeUnitChanged;
  final ValueChanged<bool> onRatioTypeChanged;

  const ReactionSettingsCard({
    super.key,
    required this.volume,
    required this.volumeUnit,
    required this.ratioType,
    required this.onVolumeChanged,
    required this.onVolumeUnitChanged,
    required this.onRatioTypeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '反应设置',
      children: [
        Row(
          children: [
            const Text('目标反应体积', style: TextStyle(fontSize: 11, color: AppColors.text)),
            const SizedBox(width: 8),
            SizedBox(
              width: 80,
              height: 28,
              child: TextField(
                controller: TextEditingController(text: volume),
                onChanged: onVolumeChanged,
                style: const TextStyle(fontSize: 12),
                decoration: const InputDecoration(
                  contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 4),
            UnitDropdown(
              value: volumeUnit,
              items: CalculatorNotifier.volumeUnits,
              onChanged: onVolumeUnitChanged,
            ),
            const SizedBox(width: 16),
            const Text('投料比类型', style: TextStyle(fontSize: 11, color: AppColors.text)),
            const SizedBox(width: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('摩尔比', style: TextStyle(fontSize: 11))),
                ButtonSegment(value: false, label: Text('质量比', style: TextStyle(fontSize: 11))),
              ],
              selected: {ratioType},
              onSelectionChanged: (v) => onRatioTypeChanged(v.first),
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Divider(),
        const Text(
          '建议至少填写各底物的母液浓度，并在总体积、终浓度、母液体积、投料比中提供足够条件',
          style: TextStyle(fontSize: 10, color: AppColors.muted),
        ),
      ],
    );
  }
}
