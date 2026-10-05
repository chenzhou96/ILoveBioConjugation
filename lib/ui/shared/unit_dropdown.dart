import 'package:flutter/material.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';

/// Unit values remain canonical; labels display the scientific micro symbol.
class UnitDropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final ValueChanged<String> onChanged;
  final bool enabled;
  final String? semanticLabel;
  final bool compact;
  final bool attached;

  const UnitDropdown({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
    this.enabled = true,
    this.semanticLabel,
    this.compact = false,
    this.attached = false,
  });

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel ?? '单位',
    child: Container(
      width: compact ? (items.any((item) => item.contains('/')) ? 74 : 57) : 84,
      constraints: BoxConstraints(minHeight: compact ? 30 : 38),
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8),
      decoration: BoxDecoration(
        color: enabled
            ? AppColors.of(context).surfaceSoft
            : AppColors.of(context).sidebar,
        border: attached
            ? Border(left: BorderSide(color: AppColors.of(context).border))
            : Border.all(color: AppColors.of(context).border),
        borderRadius: attached
            ? BorderRadius.only(
                topRight: Radius.circular(5),
                bottomRight: Radius.circular(5),
              )
            : BorderRadius.circular(7),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          isExpanded: true,
          isDense: compact,
          icon: Icon(Icons.expand_more, size: compact ? 13 : 16),
          borderRadius: BorderRadius.circular(12),
          items: items
              .map(
                (unit) => DropdownMenuItem(
                  value: unit,
                  child: Text(
                    unit.replaceFirst(RegExp(r'^u'), 'µ'),
                    style: TextStyle(fontSize: compact ? 11 : 12),
                  ),
                ),
              )
              .toList(),
          onChanged: enabled
              ? (unit) {
                  if (unit != null) onChanged(unit);
                }
              : null,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontSize: compact ? 11 : 12,
            color: AppColors.of(context).text,
          ),
        ),
      ),
    ),
  );
}
