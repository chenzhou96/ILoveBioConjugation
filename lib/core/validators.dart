// Input parsing and unit conversion helpers — port of main.py utility functions.

/// Parse a string to double, returning null for empty input.
double? parseFloatOrNull(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final parsed = double.tryParse(trimmed);
  if (parsed == null) {
    throw ArgumentError('必须是数字。');
  }
  return parsed;
}

/// Convert a volume from its unit to mL (base unit expected by Chemical).
double convertVolumeToMl(double volume, String unit) {
  const factors = <String, double>{
    'L': 1000,
    'mL': 1,
    'uL': 0.001,
    'nL': 0.000001,
    'pL': 0.000000001,
  };
  return volume * (factors[unit] ?? 1);
}

/// Convert molecular weight from kDa to Da.
double convertMwToDa(double mw, String unit) {
  return unit == 'kDa' ? mw * 1000 : mw;
}

/// Convert a concentration value to its base unit.
///
/// Molar concentrations → mM base.
/// Mass concentrations → mg/mL base.
double convertConcentrationToBaseUnit(double value, String unit) {
  const molarFactors = <String, double>{
    'M': 1000, 'mM': 1, 'uM': 0.001, 'nM': 0.000001, 'pM': 0.000000001,
  };
  const massFactors = <String, double>{
    'g/mL': 1000, 'mg/mL': 1, 'ug/mL': 0.001, 'ng/mL': 0.000001, 'pg/mL': 0.000000001,
  };
  if (molarFactors.containsKey(unit)) return value * molarFactors[unit]!;
  if (massFactors.containsKey(unit)) return value * massFactors[unit]!;
  return value;
}

/// Whether a concentration unit string represents a molar unit.
bool isMolarUnit(String unit) => unit.endsWith('M') && !unit.contains('/');

/// Whether a concentration unit string represents a mass concentration unit.
bool isMassUnit(String unit) => unit.contains('/');
