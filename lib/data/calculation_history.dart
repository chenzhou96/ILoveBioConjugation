/// Data class for a saved calculation record.
class CalculationHistory {
  final int? id;
  final String createdAt;
  final bool ratioType; // true=molar, false=mass
  final double? reactionVolume;
  final String reactionVolumeUnit;
  final double? totalStockVolume;
  final double? diluentVolume;
  final List<SubstrateResult> substrates;

  const CalculationHistory({
    this.id,
    required this.createdAt,
    required this.ratioType,
    this.reactionVolume,
    this.reactionVolumeUnit = 'mL',
    this.totalStockVolume,
    this.diluentVolume,
    this.substrates = const [],
  });
}

/// A single substrate row within a calculation history record.
class SubstrateResult {
  final int? id;
  final int? historyId;
  final int sortOrder; // 0=main, 1..3=secondary
  final String name;
  final String role; // 'main' or 'secondary'
  final double? molecularWeight;
  final String? mwUnit;
  final double? storageConcMolar;
  final double? storageConcMass;
  final double? storageVolume;
  final String? storageConcUnit;
  final String? storageVolumeUnit;
  final double? finalConcMolar;
  final double? finalConcMass;
  final String? finalConcUnit;
  final double? reactionRatio;

  const SubstrateResult({
    this.id,
    this.historyId,
    required this.sortOrder,
    required this.name,
    required this.role,
    this.molecularWeight,
    this.mwUnit,
    this.storageConcMolar,
    this.storageConcMass,
    this.storageVolume,
    this.storageConcUnit,
    this.storageVolumeUnit,
    this.finalConcMolar,
    this.finalConcMass,
    this.finalConcUnit,
    this.reactionRatio,
  });
}
