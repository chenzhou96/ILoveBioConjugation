/// Unit conversion constants — port of chemical_config.UnitConverter.
///
/// Each map stores exponents: base = value × 10^exponent.
class UnitConverter {
  UnitConverter._();

  static const Map<String, int> massUnits = {
    'g': 3,
    'kg': 6,
    'mg': 0,
    'ug': -3,
    'ng': -9,
    'pg': -12,
  };

  static const Map<String, int> volumeUnits = {
    'L': 3,
    'mL': 0,
    'uL': -3,
    'nL': -6,
    'pL': -9,
  };

  static const Map<String, int> molarUnits = {
    'mol': 6,
    'mmol': 3,
    'umol': 0,
    'nmol': -3,
    'pmol': -6,
  };

  static const Map<String, int> molecularUnits = {
    'Da': 0,
    'kDa': 3,
  };

  static const Map<String, int> molarConcUnits = {
    'M': 3,
    'mM': 0,
    'uM': -3,
    'nM': -6,
    'pM': -9,
  };

  static const Map<String, int> massConcUnits = {
    'g/mL': 3,
    'mg/mL': 0,
    'ug/mL': -3,
    'ng/mL': -6,
    'pg/mL': -9,
  };
}
