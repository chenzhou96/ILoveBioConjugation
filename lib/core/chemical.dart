/// Represents a single chemical substance — port of chemical_config.Chemical.
class Chemical {
  final int unitCoefficient;
  final String name;

  double? storageConcMolar;
  double? storageConcMass;
  double? molecularWeight;
  double? storageConcVolume;
  double? finalConcMolar;
  double? finalConcMass;
  double? reactionRatio;

  Chemical({
    required this.unitCoefficient,
    this.storageConcMolar,
    this.storageConcMass,
    this.name = 'Untitled',
    this.molecularWeight,
    this.storageConcVolume,
    this.finalConcMolar,
    this.finalConcMass,
    this.reactionRatio,
  }) {
    if (storageConcMolar != null && storageConcMass != null) {
      throw ArgumentError('只能提供母液浓度(摩尔浓度或质量浓度)中的一个。');
    }
    if (storageConcMolar == null && storageConcMass == null) {
      throw ArgumentError('必须提供母液浓度(摩尔浓度或质量浓度)中的一个。');
    }
    if (finalConcMolar != null && finalConcMass != null) {
      throw ArgumentError('只能提供实际反应浓度(摩尔浓度或质量浓度)中的一个。');
    }

    if (molecularWeight != null) {
      if (storageConcMolar == null && storageConcMass != null) {
        storageConcMolar = _concMass2Molar(storageConcMass!);
      } else if (storageConcMass == null && storageConcMolar != null) {
        storageConcMass = _concMolar2Mass(storageConcMolar!);
      }

      if (finalConcMolar == null && finalConcMass != null) {
        finalConcMolar = _concMass2Molar(finalConcMass!);
      } else if (finalConcMass == null && finalConcMolar != null) {
        finalConcMass = _concMolar2Mass(finalConcMolar!);
      }
    }
  }

  double _concMass2Molar(double conc) => (conc / molecularWeight!) * 1000;
  double _concMolar2Mass(double conc) => (conc * molecularWeight!) / 1000;

  /// Re-derive missing concentration fields after calculation updates.
  void outputTest() {
    if (molecularWeight != null) {
      if (finalConcMass != null && finalConcMolar == null) {
        finalConcMolar = _concMass2Molar(finalConcMass!);
      }
      if (finalConcMolar != null && finalConcMass == null) {
        finalConcMass = _concMolar2Mass(finalConcMolar!);
      }
      if (storageConcMass != null && storageConcMolar == null) {
        storageConcMolar = _concMass2Molar(storageConcMass!);
      }
      if (storageConcMolar != null && storageConcMass == null) {
        storageConcMass = _concMolar2Mass(storageConcMolar!);
      }
    }
  }

  /// Get the basis concentration for the given ratio type.
  /// ratioType=true → molar, ratioType=false → mass.
  double? getBasisConc(bool ratioType) =>
      ratioType ? storageConcMolar : storageConcMass;

  /// Get the basis final concentration for the given ratio type.
  double? getBasisFinalConc(bool ratioType) =>
      ratioType ? finalConcMolar : finalConcMass;

  /// Set the basis final concentration for the given ratio type.
  void setBasisFinalConc(bool ratioType, double? value) {
    if (ratioType) {
      finalConcMolar = value;
    } else {
      finalConcMass = value;
    }
  }
}
