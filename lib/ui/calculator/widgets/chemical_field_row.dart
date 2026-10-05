import 'package:flutter/material.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/ui/shared/unit_dropdown.dart';

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
  final bool numeric;
  final String? semanticLabel;
  final bool compact;

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
    this.numeric = true,
    this.semanticLabel,
    this.compact = false,
  });

  @override
  State<ChemicalFieldRow> createState() => _ChemicalFieldRowState();
}

class _ChemicalFieldRowState extends State<ChemicalFieldRow> {
  late final TextEditingController _controller;
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value);
  }

  @override
  void didUpdateWidget(ChemicalFieldRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return Focus(
        canRequestFocus: false,
        skipTraversal: true,
        onFocusChange: (value) => setState(() => _focused = value),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.of(context).surface,
            border: Border.all(
              color: _focused
                  ? AppColors.of(context).primary
                  : AppColors.of(context).border,
            ),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  label: widget.semanticLabel ?? widget.label,
                  child: TextField(
                    controller: _controller,
                    onChanged: widget.readOnly ? null : widget.onChanged,
                    enabled: !widget.readOnly,
                    keyboardType: widget.numeric
                        ? const TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          )
                        : TextInputType.text,
                    textInputAction: TextInputAction.next,
                    style: const TextStyle(fontSize: 12, height: 1.3),
                    decoration: const InputDecoration(
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 9,
                      ),
                      hintText: '—',
                      hintStyle: TextStyle(fontSize: 11),
                      filled: false,
                      isDense: true,
                    ),
                  ),
                ),
              ),
              if (widget.unit != null && widget.unitValues != null)
                UnitDropdown(
                  value: widget.unit!,
                  items: widget.unitValues!,
                  enabled: !widget.readOnly,
                  compact: true,
                  attached: true,
                  semanticLabel: '${widget.semanticLabel ?? widget.label}单位',
                  onChanged: widget.onUnitChanged ?? (_) {},
                ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.label,
            style: TextStyle(fontSize: 12, color: AppColors.of(context).muted),
          ),
          SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: widget.semanticLabel ?? widget.label,
                  child: TextField(
                    controller: _controller,
                    onChanged: widget.readOnly ? null : widget.onChanged,
                    enabled: !widget.readOnly,
                    keyboardType: widget.numeric
                        ? TextInputType.numberWithOptions(
                            decimal: true,
                            signed: true,
                          )
                        : TextInputType.text,
                    textInputAction: TextInputAction.next,
                    style: TextStyle(fontSize: 13),
                    decoration: InputDecoration(hintText: widget.hint),
                  ),
                ),
              ),
              if (widget.unit != null && widget.unitValues != null) ...[
                SizedBox(width: 8),
                UnitDropdown(
                  value: widget.unit!,
                  items: widget.unitValues!,
                  enabled: !widget.readOnly,
                  semanticLabel: '${widget.semanticLabel ?? widget.label}单位',
                  onChanged: widget.onUnitChanged ?? (_) {},
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
