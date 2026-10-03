import 'dart:math' as math;

import 'unit_converter.dart';

/// Presentation only: never feed rounded strings back into a calculation.
String displayNumber(double value) {
  if (!value.isFinite) throw ArgumentError('不能显示非有限数值。');
  if (value == 0) return '0.000';
  if (value.abs() >= 1e21) return value.toStringAsExponential(3);
  final scaled = value * 1000;
  final whole = scaled.abs().floorToDouble();
  // Unit conversion can put a decimal midpoint a few binary bits below .5.
  final atMidpoint =
      (scaled.abs() - whole - 0.5).abs() <=
      math.min(1e-9, scaled.abs() * 2e-15);
  final rounded =
      (atMidpoint ? (whole + 1) * value.sign : scaled.roundToDouble()) / 1000;
  return rounded == 0
      ? value.toStringAsExponential(3)
      : rounded.toStringAsFixed(3);
}

String displayVolume(double ml, {bool asciiMicro = false}) => _scaled(ml, [
  (1000, 'L'),
  (1, 'mL'),
  (0.001, asciiMicro ? 'uL' : 'µL'),
  (0.000001, 'nL'),
  (0.000000001, 'pL'),
], zeroUnit: asciiMicro ? 'uL' : 'µL');

String displayMolar(double? mm, {bool asciiMicro = false}) => mm == null
    ? '无法换算（缺少分子量）'
    : _scaled(mm, [
        (1000, 'M'),
        (1, 'mM'),
        (0.001, asciiMicro ? 'uM' : 'µM'),
        (0.000001, 'nM'),
        (0.000000001, 'pM'),
      ], zeroUnit: 'mM');

String displayMass(double? mgMl, {bool asciiMicro = false}) => mgMl == null
    ? '无法换算（缺少分子量）'
    : _scaled(mgMl, [
        (1000, 'g/mL'),
        (1, 'mg/mL'),
        (0.001, asciiMicro ? 'ug/mL' : 'µg/mL'),
        (0.000001, 'ng/mL'),
        (0.000000001, 'pg/mL'),
      ], zeroUnit: 'mg/mL');

String displayMolecularWeight(double da) =>
    _scaled(da, [(1000, 'kDa'), (1, 'Da')], zeroUnit: 'Da');

String _scaled(
  double value,
  List<(double, String)> units, {
  required String zeroUnit,
}) {
  if (!value.isFinite) throw ArgumentError('不能显示非有限数值。');
  if (value == 0) return '0.000 $zeroUnit';
  var index = units.indexWhere((unit) => value.abs() >= unit.$1);
  if (index < 0) index = units.length - 1;
  // Rounding 999.9999 nL must show 1.000 µL, never 1000.000 nL.
  while (index > 0 &&
      double.parse(displayNumber(value.abs() / units[index].$1)) >=
          (units[index - 1].$1 / units[index].$1).roundToDouble()) {
    index--;
  }
  final (factor, unit) = units[index];
  return '${displayNumber(value / factor)} $unit';
}

/// Format a numeric input for reading/export without altering the saved input.
String displayInputNumber(String text) {
  final value = double.tryParse(text);
  return value == null || !value.isFinite ? text : displayNumber(value);
}

String displayInputValue(String text, String unit) {
  final value = double.tryParse(text);
  if (value == null || !value.isFinite) return '$text $unit';
  final normalized = unit.replaceAll('µ', 'u');
  double base(int exponent) => value * math.pow(10, exponent);
  if (UnitConverter.volumeUnits.containsKey(normalized)) {
    return displayVolume(base(UnitConverter.volumeUnits[normalized]!));
  }
  if (UnitConverter.molarConcUnits.containsKey(normalized)) {
    return displayMolar(base(UnitConverter.molarConcUnits[normalized]!));
  }
  if (UnitConverter.massConcUnits.containsKey(normalized)) {
    return displayMass(base(UnitConverter.massConcUnits[normalized]!));
  }
  if (UnitConverter.molecularUnits.containsKey(normalized)) {
    return displayMolecularWeight(
      base(UnitConverter.molecularUnits[normalized]!),
    );
  }
  return '${displayNumber(value)} $unit';
}

/// Fill only a missing basis in legacy records; existing stored values win.
({double? molar, double? mass}) concentrationPair({
  double? molar,
  double? mass,
  double? molecularWeightDa,
}) {
  if (molecularWeightDa != null &&
      molecularWeightDa.isFinite &&
      molecularWeightDa > 0) {
    if (molar == null && mass != null) {
      final converted = mass / molecularWeightDa * 1000;
      if (converted.isFinite && (converted != 0 || mass == 0)) {
        molar = converted;
      }
    }
    if (mass == null && molar != null) {
      final converted = molar * (molecularWeightDa / 1000);
      if (converted.isFinite && (converted != 0 || molar == 0)) {
        mass = converted;
      }
    }
  }
  return (molar: molar, mass: mass);
}

({double? molar, double? mass}) concentrationInputPair(
  String text,
  String unit, {
  String molecularWeight = '',
  String mwUnit = 'Da',
}) {
  final value = double.tryParse(text);
  final mw = double.tryParse(molecularWeight);
  final normalized = unit.replaceAll('µ', 'u');
  final isMolar = UnitConverter.molarConcUnits.containsKey(normalized);
  final exponent = isMolar
      ? UnitConverter.molarConcUnits[normalized]
      : UnitConverter.massConcUnits[normalized];
  if (value == null || !value.isFinite || exponent == null) {
    return (molar: null, mass: null);
  }
  final base = value * math.pow(10, exponent);
  if (!base.isFinite) return (molar: null, mass: null);
  return concentrationPair(
    molar: isMolar ? base : null,
    mass: isMolar ? null : base,
    molecularWeightDa: mw == null
        ? null
        : mw * math.pow(10, UnitConverter.molecularUnits[mwUnit] ?? 0),
  );
}
