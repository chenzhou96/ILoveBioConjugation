import 'package:flutter/material.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/shared/section_card.dart';
import 'package:ilovebioconjugation/ui/shared/unit_dropdown.dart';

class ReactionSettingsCard extends StatefulWidget {
  final String volume;
  final String volumeUnit;
  final bool ratioType;
  final bool compact;
  final Widget? referenceSelector;
  final ValueChanged<String> onVolumeChanged;
  final ValueChanged<String> onVolumeUnitChanged;
  final ValueChanged<bool> onRatioTypeChanged;

  const ReactionSettingsCard({
    super.key,
    required this.volume,
    required this.volumeUnit,
    required this.ratioType,
    this.compact = false,
    this.referenceSelector,
    required this.onVolumeChanged,
    required this.onVolumeUnitChanged,
    required this.onRatioTypeChanged,
  });

  @override
  State<ReactionSettingsCard> createState() => _ReactionSettingsCardState();
}

class _ReactionSettingsCardState extends State<ReactionSettingsCard> {
  late final TextEditingController _volumeController;

  @override
  void initState() {
    super.initState();
    _volumeController = TextEditingController(text: widget.volume);
  }

  @override
  void didUpdateWidget(ReactionSettingsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.volume != _volumeController.text) {
      _volumeController.value = TextEditingValue(
        text: widget.volume,
        selection: TextSelection.collapsed(offset: widget.volume.length),
      );
    }
  }

  @override
  void dispose() {
    _volumeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return Container(
        key: const ValueKey('desktop-reaction-settings'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: AppColors.of(context).surface,
          border: Border.all(color: AppColors.of(context).border),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            const Text(
              '反应设置',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 28),
            Text(
              '反应体积',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.of(context).muted,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 106,
              child: Semantics(
                label: '目标反应体积',
                child: TextField(
                  key: const ValueKey('reaction-volume'),
                  controller: _volumeController,
                  onChanged: widget.onVolumeChanged,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  ),
                  textInputAction: TextInputAction.next,
                  style: const TextStyle(fontSize: 12, height: 1.3),
                  decoration: const InputDecoration(
                    hintText: '如：100',
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 9,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 6),
            UnitDropdown(
              semanticLabel: '目标反应体积单位',
              value: widget.volumeUnit,
              items: CalculatorNotifier.volumeUnits,
              compact: true,
              onChanged: widget.onVolumeUnitChanged,
            ),
            const SizedBox(width: 28),
            Text(
              '投料比',
              style: TextStyle(
                fontSize: 11,
                color: AppColors.of(context).muted,
              ),
            ),
            const SizedBox(width: 10),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('摩尔比')),
                ButtonSegment(value: false, label: Text('质量比')),
              ],
              showSelectedIcon: false,
              selected: {widget.ratioType},
              onSelectionChanged: (selection) =>
                  widget.onRatioTypeChanged(selection.first),
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: WidgetStatePropertyAll(Size(66, 32)),
                padding: WidgetStatePropertyAll(
                  EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
            ),
            const SizedBox(width: 20),
            if (widget.referenceSelector != null)
              Expanded(child: widget.referenceSelector!)
            else
              const Spacer(),
            Tooltip(
              message: '填写母液浓度，再填终浓度、取样体积或投料比。质量与摩尔换算需分子量。',
              child: Icon(
                Icons.help_outline,
                size: 16,
                color: AppColors.of(context).muted,
              ),
            ),
          ],
        ),
      );
    }
    return SectionCard(
      title: '反应设置',

      children: [
        if (widget.referenceSelector != null) ...[
          widget.referenceSelector!,
          const SizedBox(height: 14),
        ],
        LayoutBuilder(
          builder: (context, constraints) {
            final twoColumns = constraints.maxWidth >= 560;
            final width = twoColumns
                ? (constraints.maxWidth - 20) / 2
                : constraints.maxWidth;
            return Wrap(
              spacing: 20,
              runSpacing: 18,
              children: [
                SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '目标反应体积',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.of(context).muted,
                        ),
                      ),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Semantics(
                              label: '目标反应体积',
                              child: TextField(
                                key: ValueKey('reaction-volume'),
                                controller: _volumeController,
                                onChanged: widget.onVolumeChanged,
                                keyboardType: TextInputType.numberWithOptions(
                                  decimal: true,
                                  signed: true,
                                ),
                                textInputAction: TextInputAction.next,
                                style: TextStyle(fontSize: 13),
                                decoration: InputDecoration(hintText: '如：100'),
                              ),
                            ),
                          ),
                          SizedBox(width: 8),
                          UnitDropdown(
                            semanticLabel: '目标反应体积单位',
                            value: widget.volumeUnit,
                            items: CalculatorNotifier.volumeUnits,
                            onChanged: widget.onVolumeUnitChanged,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: width,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '投料比类型',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.of(context).muted,
                        ),
                      ),
                      SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<bool>(
                          segments: [
                            ButtonSegment(value: true, label: Text('摩尔比')),
                            ButtonSegment(value: false, label: Text('质量比')),
                          ],
                          showSelectedIcon: false,
                          selected: {widget.ratioType},
                          onSelectionChanged: (selection) =>
                              widget.onRatioTypeChanged(selection.first),
                          style: ButtonStyle(
                            minimumSize: WidgetStatePropertyAll(Size(44, 38)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
