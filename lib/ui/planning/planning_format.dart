import 'package:ilovebioconjugation/export/experiment_markdown.dart'
    show formatPlanMolar, formatPlanMass;

String planningNumber(double value) {
  if (value == 0) return '0';
  if (value.abs() < 0.0001 || value.abs() >= 1000000) {
    return value.toStringAsExponential(4);
  }
  return value.toStringAsFixed(4).replaceFirst(RegExp(r'\.?0+$'), '');
}

String planningVolume(double ml) => '${planningNumber(ml * 1000)} µL';

/// Scale the solved base value before display. Fixed decimals in mg/mL would
/// distort small but meaningful concentrations (e.g. 286.65 ng/mL).
String planningConcentration(double? value, {bool molar = true}) =>
    molar ? formatPlanMolar(value) : formatPlanMass(value);
