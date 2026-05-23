import 'package:flutter/material.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/shared/section_card.dart';
import 'package:ilovebioconjugation/ui/shared/unit_dropdown.dart';

class ReactionSettingsCard extends StatefulWidget {
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
  State<ReactionSettingsCard> createState() => _ReactionSettingsCardState();
}

class _ReactionSettingsCardState extends State<ReactionSettingsCard> {
  late TextEditingController _volumeController;

  @override
  void initState() {
    super.initState();
    _volumeController = TextEditingController(text: widget.volume);
  }

  @override
  void didUpdateWidget(ReactionSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.volume != oldWidget.volume && widget.volume != _volumeController.text) {
      _volumeController.text = widget.volume;
      _volumeController.selection = TextSelection.collapsed(offset: _volumeController.text.length);
    }
  }

  @override
  void dispose() {
    _volumeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: '反应设置',
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('目标反应体积', style: TextStyle(fontSize: 11, color: AppColors.text)),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  height: 30,
                  child: TextField(
                    controller: _volumeController,
                    onChanged: widget.onVolumeChanged,
                    style: const TextStyle(fontSize: 12),
                    decoration: const InputDecoration(
                      hintText: '体积',
                      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                UnitDropdown(
                  value: widget.volumeUnit,
                  items: CalculatorNotifier.volumeUnits,
                  onChanged: widget.onVolumeUnitChanged,
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('投料比类型', style: TextStyle(fontSize: 11, color: AppColors.text)),
                const SizedBox(width: 8),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('摩尔比', style: TextStyle(fontSize: 11))),
                    ButtonSegment(value: false, label: Text('质量比', style: TextStyle(fontSize: 11))),
                  ],
                  selected: {widget.ratioType},
                  onSelectionChanged: (v) => widget.onRatioTypeChanged(v.first),
                  style: ButtonStyle(
                    visualDensity: VisualDensity.compact,
                    textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          '建议至少填写各底物的母液浓度，并在总体积、终浓度、母液体积、投料比中提供足够条件',
          style: TextStyle(fontSize: 10, color: AppColors.muted),
        ),
      ],
    );
  }
}
