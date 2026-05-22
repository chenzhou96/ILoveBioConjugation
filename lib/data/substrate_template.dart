/// A saved substrate template for quick loading into calculator cards.
class SubstrateTemplate {
  final int? id;
  final String name;
  final double? molecularWeight;
  final String mwUnit;
  final double? storageConcentration;
  final String storageUnit;
  final double? defaultFinalConc;
  final String defaultFinalUnit;
  final double? defaultReactionRatio;
  final String createdAt;
  final String updatedAt;

  const SubstrateTemplate({
    this.id,
    required this.name,
    this.molecularWeight,
    this.mwUnit = 'Da',
    this.storageConcentration,
    this.storageUnit = 'mg/mL',
    this.defaultFinalConc,
    this.defaultFinalUnit = 'mg/mL',
    this.defaultReactionRatio,
    required this.createdAt,
    required this.updatedAt,
  });
}
