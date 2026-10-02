import 'package:ilovebioconjugation/core/unit_converter.dart';

/// Original text, units, and enabled slots, independent of computed results.
///
/// Keeping inputs separate prevents a history restore from rounding tiny values
/// or turning values inferred by the solver into new user-supplied constraints.
class CalculationInputSnapshot {
  final String reactionVolume;
  final String reactionVolumeUnit;
  final bool ratioType;
  final List<SubstrateInputSnapshot> substrates;

  CalculationInputSnapshot({
    required this.reactionVolume,
    required this.reactionVolumeUnit,
    required this.ratioType,
    required List<SubstrateInputSnapshot> substrates,
  }) : substrates = List.unmodifiable(substrates);

  Map<String, Object> toJson() => {
    'version': 1,
    'reactionVolume': reactionVolume,
    'reactionVolumeUnit': reactionVolumeUnit,
    'ratioType': ratioType,
    'substrates': substrates.map((s) => s.toJson()).toList(),
  };

  factory CalculationInputSnapshot.fromJson(Map<String, dynamic> json) {
    final substrates = json['substrates'];
    if (json['version'] != 1 ||
        json['reactionVolume'] is! String ||
        json['reactionVolumeUnit'] is! String ||
        !UnitConverter.volumeUnits.containsKey(json['reactionVolumeUnit']) ||
        json['ratioType'] is! bool ||
        substrates is! List ||
        substrates.isEmpty ||
        substrates.length > 4) {
      throw const FormatException('Invalid calculation input snapshot');
    }
    return CalculationInputSnapshot(
      reactionVolume: json['reactionVolume'] as String,
      reactionVolumeUnit: json['reactionVolumeUnit'] as String,
      ratioType: json['ratioType'] as bool,
      substrates: substrates.map((value) {
        if (value is! Map<String, dynamic>) {
          throw const FormatException('Invalid substrate input snapshot');
        }
        return SubstrateInputSnapshot.fromJson(value);
      }).toList(),
    );
  }
}

class SubstrateInputSnapshot {
  final bool enabled;
  final String name;
  final String mw;
  final String mwUnit;
  final String storageConc;
  final String storageUnit;
  final String finalConc;
  final String finalUnit;
  final String reactionRatio;
  final String storageVolume;
  final String storageVolumeUnit;

  const SubstrateInputSnapshot({
    required this.enabled,
    required this.name,
    required this.mw,
    required this.mwUnit,
    required this.storageConc,
    required this.storageUnit,
    required this.finalConc,
    required this.finalUnit,
    required this.reactionRatio,
    required this.storageVolume,
    required this.storageVolumeUnit,
  });

  Map<String, Object> toJson() => {
    'enabled': enabled,
    'name': name,
    'mw': mw,
    'mwUnit': mwUnit,
    'storageConc': storageConc,
    'storageUnit': storageUnit,
    'finalConc': finalConc,
    'finalUnit': finalUnit,
    'reactionRatio': reactionRatio,
    'storageVolume': storageVolume,
    'storageVolumeUnit': storageVolumeUnit,
  };

  factory SubstrateInputSnapshot.fromJson(Map<String, dynamic> json) {
    const textKeys = [
      'name',
      'mw',
      'mwUnit',
      'storageConc',
      'storageUnit',
      'finalConc',
      'finalUnit',
      'reactionRatio',
      'storageVolume',
      'storageVolumeUnit',
    ];
    if (json['enabled'] is! bool ||
        textKeys.any((key) => json[key] is! String) ||
        !UnitConverter.molecularUnits.containsKey(json['mwUnit']) ||
        !UnitConverter.volumeUnits.containsKey(json['storageVolumeUnit']) ||
        !_isConcentrationUnit(json['storageUnit']) ||
        !_isConcentrationUnit(json['finalUnit'])) {
      throw const FormatException('Invalid substrate input snapshot');
    }
    return SubstrateInputSnapshot(
      enabled: json['enabled'] as bool,
      name: json['name'] as String,
      mw: json['mw'] as String,
      mwUnit: json['mwUnit'] as String,
      storageConc: json['storageConc'] as String,
      storageUnit: json['storageUnit'] as String,
      finalConc: json['finalConc'] as String,
      finalUnit: json['finalUnit'] as String,
      reactionRatio: json['reactionRatio'] as String,
      storageVolume: json['storageVolume'] as String,
      storageVolumeUnit: json['storageVolumeUnit'] as String,
    );
  }
}

bool _isConcentrationUnit(Object? unit) =>
    UnitConverter.molarConcUnits.containsKey(unit) ||
    UnitConverter.massConcUnits.containsKey(unit);
