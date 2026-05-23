import 'package:flutter/material.dart';
import 'package:ilovebioconjunction/theme/app_colors.dart';
import 'package:ilovebioconjunction/ui/shared/unit_dropdown.dart';

class ChemicalFieldRow extends StatefulWidget {
  final String label;
  final String value;
  final ValueChanged<String> onChanged;
  final String? unit;
  final List<String>? unitValues;
  final ValueChanged<String>? onUnitChanged;
  final double entryWidth;
  final String? hint;
  final bool readOnly;

  const ChemicalFieldRow({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
    this.unit,
    this.unitValues,
    this.onUnitChanged,
    this.entryWidth = 80,
    this.hint,
    this.readOnly = false,
  });

  @override
  State<ChemicalFieldRow> createState() => _ChemicalFieldRowState();
}

class _ChemicalFieldRowState extends State<ChemicalFieldRow> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(ChemicalFieldRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value;
      _controller.selection = TextSelection.collapsed(offset: _controller.text.length);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 70,
            child: Text(
              widget.label,
              style: const TextStyle(fontSize: 11, color: AppColors.text),
            ),
          ),
          SizedBox(
            width: widget.entryWidth,
            height: 30,
            child: TextField(
              controller: _controller,
              onChanged: widget.readOnly ? null : widget.onChanged,
              readOnly: widget.readOnly,
              style: const TextStyle(fontSize: 12),
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: const TextStyle(fontSize: 10, color: AppColors.muted),
                contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          if (widget.unit != null && widget.unitValues != null) ...[
            const SizedBox(width: 4),
            UnitDropdown(
              value: widget.unit!,
              items: widget.unitValues!,
              onChanged: widget.onUnitChanged ?? (_) {},
            ),
          ],
        ],
      ),
    );
  }
}
