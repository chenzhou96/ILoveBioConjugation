import 'dart:math' as math;

/// A reagent using mM, mg/mL, Da and mL as its base units.
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
    outputTest();
  }

  double _concMass2Molar(double conc) => (conc / molecularWeight!) * 1000;
  double _concMolar2Mass(double conc) => conc * (molecularWeight! / 1000);

  void _validateValue(double? value, String label, {bool positive = false}) {
    if (value != null &&
        (!value.isFinite || (positive ? value <= 0 : value < 0))) {
      throw ArgumentError('$name 的$label必须是${positive ? '大于 0 的' : '非负'}有限数字。');
    }
  }

  void _validateValues() {
    _validateValue(storageConcMolar, '母液摩尔浓度', positive: true);
    _validateValue(storageConcMass, '母液质量浓度', positive: true);
    _validateValue(molecularWeight, '分子量', positive: true);
    _validateValue(storageConcVolume, '母液体积');
    _validateValue(finalConcMolar, '实际反应摩尔浓度');
    _validateValue(finalConcMass, '实际反应质量浓度');
    _validateValue(reactionRatio, '反应投料比', positive: true);
    if (storageConcMolar == null && storageConcMass == null) {
      throw ArgumentError('$name 缺少母液浓度。');
    }
  }

  void _checkConcentrationPair(double? molar, double? mass) {
    if (molar == null || mass == null) return;
    if (molecularWeight == null) {
      throw ArgumentError('$name 同时使用摩尔浓度和质量浓度时必须提供分子量。');
    }
    if ((molar == 0) != (mass == 0)) {
      throw ArgumentError('$name 的浓度换算结果超出可计算范围。');
    }
    final expectedMass = _concMolar2Mass(molar);
    final scale = math.max(mass.abs(), expectedMass.abs());
    if (!expectedMass.isFinite || (mass - expectedMass).abs() > 1e-9 * scale) {
      throw ArgumentError('$name 的摩尔浓度与质量浓度不一致，请检查分子量和输入。');
    }
  }

  /// Validate all fields and derive missing concentrations using molecular weight.
  ///
  /// Existing pairs must agree; direct edits cannot silently retain stale values.
  void outputTest() {
    _validateValues();
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
    _validateValues();
    _checkConcentrationPair(storageConcMolar, storageConcMass);
    _checkConcentrationPair(finalConcMolar, finalConcMass);
  }

  /// ratioType=true selects molar concentration; false selects mass concentration.
  double? getBasisConc(bool ratioType) =>
      ratioType ? storageConcMolar : storageConcMass;

  double? getBasisFinalConc(bool ratioType) =>
      ratioType ? finalConcMolar : finalConcMass;

  /// Replace the final concentration and refresh its derived counterpart.
  /// Clearing the selected basis also clears the derived concentration.
  void setBasisFinalConc(bool ratioType, double? value) {
    _validateValue(value, '实际反应浓度');
    _validateValue(molecularWeight, '分子量', positive: true);
    final converted = value == null || molecularWeight == null
        ? null
        : ratioType
        ? _concMolar2Mass(value)
        : _concMass2Molar(value);
    _validateValue(converted, '换算后的实际反应浓度');
    if (value != null && value > 0 && converted == 0) {
      throw ArgumentError('$name 的浓度换算结果超出可计算范围。');
    }
    if (ratioType) {
      finalConcMolar = value;
      finalConcMass = converted;
    } else {
      finalConcMass = value;
      finalConcMolar = converted;
    }
  }
}
