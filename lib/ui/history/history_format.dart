import 'package:ilovebioconjugation/core/display_format.dart';

/// Handles imported/legacy timestamps without assuming a fixed string length.
String formatHistoryDate(String value) {
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return value.isEmpty ? '未知时间' : value;
  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-'
      '${two(local.day)} ${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

/// Never display a nonzero historical value as a rounded zero.
String formatHistoryNumber(double value) {
  return displayNumber(value);
}

String formatHistoryConcentrations({
  double? molar,
  double? mass,
  double? molecularWeightDa,
}) {
  final pair = concentrationPair(
    molar: molar,
    mass: mass,
    molecularWeightDa: molecularWeightDa,
  );
  return '质量：${displayMass(pair.mass)}\n摩尔：${displayMolar(pair.molar)}';
}
