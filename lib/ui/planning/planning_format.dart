import 'package:ilovebioconjugation/core/display_format.dart';

String planningNumber(double value) => displayNumber(value);

String planningVolume(double ml) => displayVolume(ml);

/// Scale the solved base value before display. Fixed decimals in mg/mL would
/// distort small but meaningful concentrations (e.g. 286.65 ng/mL).
String planningConcentration(double? value, {bool molar = true}) =>
    molar ? displayMolar(value) : displayMass(value);
