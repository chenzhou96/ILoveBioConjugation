// Input parsing and unit conversion helpers.
import 'dart:math' as math;

import 'unit_converter.dart';

/// Parse a finite number, returning null only for empty input.
double? parseFloatOrNull(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final parsed = double.tryParse(trimmed);
  if (parsed == null || !parsed.isFinite) {
    throw ArgumentError('必须是有限数字。');
  }
  // double.tryParse silently rounds a nonzero decimal below its range to
  // zero. Keep true zero controls valid, including an arbitrary exponent.
  final significand = trimmed.split(RegExp('[eE]')).first;
  if (parsed == 0 && RegExp('[1-9]').hasMatch(significand)) {
    throw ArgumentError('数值超出可计算范围，不能将非零输入当作零。');
  }
  return parsed;
}

double _convert(double value, String unit, Map<String, int> units) {
  final exponent = units[unit];
  if (exponent == null) {
    throw ArgumentError('不支持的单位: $unit');
  }
  if (!value.isFinite || value < 0) {
    throw ArgumentError('数值必须是非负有限数字。');
  }
  final converted = value * math.pow(10, exponent);
  if (!converted.isFinite || (value > 0 && converted == 0)) {
    throw ArgumentError('单位换算结果超出可计算范围。');
  }
  return converted;
}

/// Convert a volume from its unit to mL (base unit expected by Chemical).
double convertVolumeToMl(double volume, String unit) =>
    _convert(volume, unit, UnitConverter.volumeUnits);

/// Convert molecular weight to Da.
double convertMwToDa(double mw, String unit) {
  if (mw <= 0) {
    throw ArgumentError('分子量必须大于 0。');
  }
  return _convert(mw, unit, UnitConverter.molecularUnits);
}

/// Convert molar concentration to mM or mass concentration to mg/mL.
double convertConcentrationToBaseUnit(double value, String unit) {
  final units = isMolarUnit(unit)
      ? UnitConverter.molarConcUnits
      : UnitConverter.massConcUnits;
  return _convert(value, unit, units);
}

/// Whether a concentration unit is a supported molar unit.
bool isMolarUnit(String unit) => UnitConverter.molarConcUnits.containsKey(unit);

/// Whether a concentration unit is a supported mass concentration unit.
bool isMassUnit(String unit) => UnitConverter.massConcUnits.containsKey(unit);
