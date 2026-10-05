import 'package:ilovebioconjugation/core/unit_converter.dart';
import 'package:ilovebioconjugation/core/validators.dart';

/// Original text, units, and enabled slots, independent of computed results.
///
/// Keeping inputs separate prevents a history restore from rounding tiny values
/// or turning values inferred by the solver into new user-supplied constraints.
class CalculationInputSnapshot {
  final String reactionVolume;
  final String reactionVolumeUnit;
  final bool ratioType;
  final List<SubstrateInputSnapshot> substrates;
  final int referenceSlot;
  final double minimumPipettingVolumeUl;
  final List<WorkingStockProvenance> workingStocks;
  final GradientInputSnapshot? gradient;

  CalculationInputSnapshot({
    required this.reactionVolume,
    required this.reactionVolumeUnit,
    required this.ratioType,
    required List<SubstrateInputSnapshot> substrates,
    this.referenceSlot = 0,
    this.minimumPipettingVolumeUl = 1,
    List<WorkingStockProvenance> workingStocks = const [],
    this.gradient,
  }) : substrates = List.unmodifiable(substrates),
       workingStocks = List.unmodifiable(workingStocks);

  Map<String, Object> toJson() => {
    'version': 2,
    'reactionVolume': reactionVolume,
    'reactionVolumeUnit': reactionVolumeUnit,
    'ratioType': ratioType,
    'substrates': substrates.map((s) => s.toJson()).toList(),
    'referenceSlot': referenceSlot,
    'minimumPipettingVolumeUl': minimumPipettingVolumeUl,
    'workingStocks': workingStocks.map((s) => s.toJson()).toList(),
    if (gradient != null) 'gradient': gradient!.toJson(),
  };

  factory CalculationInputSnapshot.fromJson(Map<String, dynamic> json) {
    final substrates = json['substrates'];
    if (![1, 2].contains(json['version']) ||
        json['reactionVolume'] is! String ||
        json['reactionVolumeUnit'] is! String ||
        !UnitConverter.volumeUnits.containsKey(json['reactionVolumeUnit']) ||
        json['ratioType'] is! bool ||
        substrates is! List ||
        substrates.isEmpty ||
        substrates.length > 4) {
      throw const FormatException('Invalid calculation input snapshot');
    }
    final reference = json['referenceSlot'] ?? 0;
    final threshold = json['minimumPipettingVolumeUl'] ?? 1;
    final recipes = json['workingStocks'] ?? <dynamic>[];
    final gradient = json['gradient'];
    if (reference is! int ||
        reference < 0 ||
        reference >= substrates.length ||
        threshold is! num ||
        !threshold.isFinite ||
        threshold < 0 ||
        recipes is! List ||
        (gradient != null && gradient is! Map<String, dynamic>)) {
      throw const FormatException('Invalid planning input snapshot');
    }
    final decodedSubstrates = substrates.map((value) {
      if (value is! Map<String, dynamic>) {
        throw const FormatException('Invalid substrate input snapshot');
      }
      return SubstrateInputSnapshot.fromJson(value);
    }).toList();
    final decodedRecipes = recipes.map((recipe) {
      if (recipe is! Map<String, dynamic>) {
        throw const FormatException('Invalid working stock provenance');
      }
      return WorkingStockProvenance.fromJson(recipe);
    }).toList();
    final decodedGradient = gradient == null
        ? null
        : GradientInputSnapshot.fromJson(gradient as Map<String, dynamic>);
    bool enabledSlot(int slot) =>
        slot >= 0 &&
        slot < decodedSubstrates.length &&
        decodedSubstrates[slot].enabled;
    if (!decodedSubstrates.first.enabled ||
        !enabledSlot(reference) ||
        decodedRecipes.any(
          (r) =>
              r.slot < 0 ||
              r.slot >= decodedSubstrates.length ||
              !_sameStockConcentration(decodedSubstrates[r.slot], r),
        ) ||
        decodedRecipes.map((r) => r.slot).toSet().length !=
            decodedRecipes.length ||
        (decodedGradient != null &&
            (!enabledSlot(decodedGradient.selectedSlot) ||
                decodedGradient.workingStocks.any(
                  (batch) =>
                      decodedRecipes.any((single) => single.slot == batch.slot),
                ) ||
                decodedGradient.workingStocks.any(
                  (r) => !enabledSlot(r.slot),
                )))) {
      throw const FormatException(
        'Planning metadata refers to a disabled or missing substrate',
      );
    }
    return CalculationInputSnapshot(
      referenceSlot: reference,
      minimumPipettingVolumeUl: threshold.toDouble(),
      workingStocks: decodedRecipes,
      gradient: decodedGradient,
      reactionVolume: json['reactionVolume'] as String,
      reactionVolumeUnit: json['reactionVolumeUnit'] as String,
      ratioType: json['ratioType'] as bool,
      substrates: decodedSubstrates,
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

/// Exact prior stock input and the preparation explicitly adopted by the user.
class WorkingStockProvenance {
  final int slot;
  final SubstrateInputSnapshot parentInput;
  final String workingConcentration;
  final String workingUnit;
  final double dilutionFactor;
  final double parentVolumeMl;
  final double diluentVolumeMl;
  final double preparationVolumeMl;
  final double requiredVolumeMl;
  final double newAliquotMl;
  final double minimumVolumeMl;
  final String diluentName;

  const WorkingStockProvenance({
    required this.slot,
    required this.parentInput,
    required this.workingConcentration,
    required this.workingUnit,
    required this.dilutionFactor,
    required this.parentVolumeMl,
    required this.diluentVolumeMl,
    required this.preparationVolumeMl,
    required this.requiredVolumeMl,
    required this.newAliquotMl,
    required this.minimumVolumeMl,
    this.diluentName = '',
  });

  Map<String, Object> toJson() => {
    'slot': slot,
    'parentInput': parentInput.toJson(),
    'workingConcentration': workingConcentration,
    'workingUnit': workingUnit,
    'dilutionFactor': dilutionFactor,
    'parentVolumeMl': parentVolumeMl,
    'diluentVolumeMl': diluentVolumeMl,
    'preparationVolumeMl': preparationVolumeMl,
    'requiredVolumeMl': requiredVolumeMl,
    'newAliquotMl': newAliquotMl,
    'minimumVolumeMl': minimumVolumeMl,
    'diluentName': diluentName,
  };

  factory WorkingStockProvenance.fromJson(Map<String, dynamic> json) {
    const positive = [
      'dilutionFactor',
      'parentVolumeMl',
      'preparationVolumeMl',
      'requiredVolumeMl',
      'newAliquotMl',
      'minimumVolumeMl',
    ];
    if (json['slot'] is! int ||
        json['slot'] < 0 ||
        json['slot'] > 3 ||
        json['parentInput'] is! Map<String, dynamic> ||
        json['workingConcentration'] is! String ||
        !_isConcentrationUnit(json['workingUnit']) ||
        json['diluentName'] is! String ||
        positive.any(
          (key) =>
              json[key] is! num ||
              !(json[key] as num).isFinite ||
              json[key] <= 0,
        ) ||
        json['diluentVolumeMl'] is! num ||
        !(json['diluentVolumeMl'] as num).isFinite ||
        json['diluentVolumeMl'] < 0) {
      throw const FormatException('Invalid working stock provenance');
    }
    final working = double.tryParse(json['workingConcentration'] as String);
    final parent = (json['parentVolumeMl'] as num).toDouble();
    final diluent = (json['diluentVolumeMl'] as num).toDouble();
    final prepared = (json['preparationVolumeMl'] as num).toDouble();
    final required = (json['requiredVolumeMl'] as num).toDouble();
    final aliquot = (json['newAliquotMl'] as num).toDouble();
    final factor = (json['dilutionFactor'] as num).toDouble();
    bool close(double a, double b) =>
        a.isFinite &&
        b.isFinite &&
        (a == b ||
            (a - b).abs() <= 1e-9 * (a.abs() > b.abs() ? a.abs() : b.abs()));
    if (working == null ||
        !working.isFinite ||
        working <= 0 ||
        factor < 1 ||
        !close(parent + diluent, prepared) ||
        !close(parent * factor, prepared) ||
        (required > prepared && !close(required, prepared)) ||
        (aliquot > required && !close(aliquot, required)) ||
        (factor > 1 && (json['diluentName'] as String).trim().isEmpty)) {
      throw const FormatException(
        'Working stock recipe fails concentration or volume conservation',
      );
    }
    final parentInput = SubstrateInputSnapshot.fromJson(
      json['parentInput'] as Map<String, dynamic>,
    );
    final parentConcentration = double.tryParse(parentInput.storageConc);
    if (!parentInput.enabled ||
        parentConcentration == null ||
        !parentConcentration.isFinite ||
        parentConcentration <= 0) {
      throw const FormatException(
        'Working stock parent concentration is invalid',
      );
    }
    var parentBase = convertConcentrationToBaseUnit(
      parentConcentration,
      parentInput.storageUnit,
    );
    final workingBase = convertConcentrationToBaseUnit(
      working,
      json['workingUnit'] as String,
    );
    if (isMolarUnit(parentInput.storageUnit) !=
        isMolarUnit(json['workingUnit'] as String)) {
      final mw = double.tryParse(parentInput.mw);
      if (mw == null || !mw.isFinite || mw <= 0) {
        throw const FormatException(
          'Working stock conversion requires molecular weight',
        );
      }
      final mwDa = convertMwToDa(mw, parentInput.mwUnit);
      parentBase = isMolarUnit(parentInput.storageUnit)
          ? parentBase * mwDa / 1000
          : parentBase * 1000 / mwDa;
    }
    if (!parentBase.isFinite ||
        parentBase <= 0 ||
        !workingBase.isFinite ||
        workingBase <= 0 ||
        !close(workingBase * factor, parentBase)) {
      throw const FormatException(
        'Working stock concentration does not match its dilution factor',
      );
    }
    return WorkingStockProvenance(
      slot: json['slot'] as int,
      parentInput: parentInput,
      workingConcentration: json['workingConcentration'] as String,
      workingUnit: json['workingUnit'] as String,
      dilutionFactor: (json['dilutionFactor'] as num).toDouble(),
      parentVolumeMl: (json['parentVolumeMl'] as num).toDouble(),
      diluentVolumeMl: (json['diluentVolumeMl'] as num).toDouble(),
      preparationVolumeMl: (json['preparationVolumeMl'] as num).toDouble(),
      requiredVolumeMl: (json['requiredVolumeMl'] as num).toDouble(),
      newAliquotMl: (json['newAliquotMl'] as num).toDouble(),
      minimumVolumeMl: (json['minimumVolumeMl'] as num).toDouble(),
      diluentName: json['diluentName'] as String,
    );
  }
}

/// Serializable batch request. Points stay textual, including invalid drafts.
class GradientInputSnapshot {
  final int selectedSlot;
  final int proteinSlot;
  final String unit;
  final List<String> points;
  final int replicates;
  final double extraPreparationFraction;
  final List<WorkingStockProvenance> workingStocks;

  GradientInputSnapshot({
    required this.selectedSlot,
    this.proteinSlot = 0,
    required this.unit,
    required List<String> points,
    this.replicates = 1,
    this.extraPreparationFraction = 0,
    List<WorkingStockProvenance> workingStocks = const [],
  }) : points = List.unmodifiable(points),
       workingStocks = List.unmodifiable(workingStocks);

  Map<String, Object> toJson() => {
    'selectedSlot': selectedSlot,
    'proteinSlot': proteinSlot,
    'unit': unit,
    'points': points,
    'replicates': replicates,
    'extraPreparationFraction': extraPreparationFraction,
    'workingStocks': workingStocks.map((recipe) => recipe.toJson()).toList(),
  };

  factory GradientInputSnapshot.fromJson(Map<String, dynamic> json) {
    final extra = json['extraPreparationFraction'] ?? 0;
    final recipes = json['workingStocks'] ?? <dynamic>[];
    if (json['selectedSlot'] is! int ||
        json['selectedSlot'] < 1 ||
        json['selectedSlot'] > 3 ||
        json['proteinSlot'] != 0 ||
        (json['unit'] != 'eq' && !_isConcentrationUnit(json['unit'])) ||
        json['points'] is! List ||
        (json['points'] as List).any((point) => point is! String) ||
        json['replicates'] is! int ||
        json['replicates'] < 1 ||
        extra is! num ||
        !extra.isFinite ||
        extra < 0 ||
        recipes is! List) {
      throw const FormatException('Invalid gradient request');
    }
    final decodedRecipes = recipes.map((recipe) {
      if (recipe is! Map<String, dynamic>) {
        throw const FormatException('Invalid batch working stock provenance');
      }
      return WorkingStockProvenance.fromJson(recipe);
    }).toList();
    if (decodedRecipes.map((recipe) => recipe.slot).toSet().length !=
        decodedRecipes.length) {
      throw const FormatException(
        'Multiple dilution steps for one batch stock are not supported',
      );
    }
    return GradientInputSnapshot(
      selectedSlot: json['selectedSlot'] as int,
      proteinSlot: 0,
      unit: json['unit'] as String,
      points: (json['points'] as List).cast<String>(),
      replicates: json['replicates'] as int,
      extraPreparationFraction: extra.toDouble(),
      workingStocks: decodedRecipes,
    );
  }
}

bool _sameStockConcentration(
  SubstrateInputSnapshot input,
  WorkingStockProvenance recipe,
) {
  final concentration = double.tryParse(input.storageConc);
  final working = double.tryParse(recipe.workingConcentration);
  if (concentration == null ||
      !concentration.isFinite ||
      concentration <= 0 ||
      working == null ||
      !working.isFinite ||
      working <= 0) {
    return false;
  }
  var currentBase = convertConcentrationToBaseUnit(
    concentration,
    input.storageUnit,
  );
  final workingBase = convertConcentrationToBaseUnit(
    working,
    recipe.workingUnit,
  );
  if (isMolarUnit(input.storageUnit) != isMolarUnit(recipe.workingUnit)) {
    final mw = double.tryParse(input.mw);
    if (mw == null || !mw.isFinite || mw <= 0) return false;
    final mwDa = convertMwToDa(mw, input.mwUnit);
    currentBase = isMolarUnit(input.storageUnit)
        ? currentBase * mwDa / 1000
        : currentBase * 1000 / mwDa;
  }
  return currentBase.isFinite &&
      workingBase.isFinite &&
      currentBase > 0 &&
      workingBase > 0 &&
      (currentBase == workingBase ||
          (currentBase - workingBase).abs() <=
              1e-9 *
                  (currentBase.abs() > workingBase.abs()
                      ? currentBase.abs()
                      : workingBase.abs()));
}
