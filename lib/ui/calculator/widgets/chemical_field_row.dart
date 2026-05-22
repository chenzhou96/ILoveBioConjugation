import 'package:flutter/material.dart';
import 'package:ilovebioconjunction/theme/app_colors.dart';
import 'package:ilovebioconjunction/ui/shared/unit_dropdown.dart';

/// A single row in a ChemicalCard: label + text field + optional unit dropdown.
class ChemicalFieldRow extends StatelessWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? unit;
  final List<String>? unitValues;
  final ValueChanged<String>? onUnitChanged;
  final double entryWidth;

  const ChemicalFieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.unit,
    this.unitValues,
    this.onUnitChanged,
    this.entryWidth = 80,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: AppColors.text),
            ),
          ),
          SizedBox(
            width: entryWidth,
            height: 28,
            child: TextField(
              controller: TextEditingController(text: value),
              onChanged: onChanged,
              style: const TextStyle(fontSize: 12),
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          if (unit != null && unitValues != null) ...[
            const SizedBox(width: 4),
            UnitDropdown(
              value: unit!,
              items: unitValues!,
              onChanged: onUnitChanged ?? (_) {},
            ),
          ],
        ],
      ),
    );
  }
}
