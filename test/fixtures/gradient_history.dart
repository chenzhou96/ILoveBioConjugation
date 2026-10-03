import 'package:ilovebioconjugation/data/calculation_history.dart';
import 'package:ilovebioconjugation/data/calculation_input_snapshot.dart';

CalculationInputSnapshot gradientHistoryInput({
  List<String> points = const ['0', '10', '15', '20'],
  int replicates = 1,
  double extra = 0.2,
  bool singleStock = true,
  List<WorkingStockProvenance> batchStocks = const [],
}) {
  SubstrateInputSnapshot reagent(
    String name,
    String mw,
    String stock,
    String unit,
    String finalConc,
    String ratio, {
    String finalUnit = 'mg/mL',
  }) => SubstrateInputSnapshot(
    enabled: true,
    name: name,
    mw: mw,
    mwUnit: 'Da',
    storageConc: stock,
    storageUnit: unit,
    finalConc: finalConc,
    finalUnit: finalUnit,
    reactionRatio: ratio,
    storageVolume: '',
    storageVolumeUnit: 'uL',
  );
  final parent = reagent('FITC', '389.38', '10', 'mg/mL', '', '10');
  return CalculationInputSnapshot(
    reactionVolume: '100',
    reactionVolumeUnit: 'uL',
    ratioType: true,
    minimumPipettingVolumeUl: 1,
    substrates: [
      reagent('IgG', '150000', '2', 'mg/mL', '1', '1'),
      reagent('FITC', '389.38', singleStock ? '1' : '10', 'mg/mL', '', '10'),
      reagent('乙醇胺', '61.08', '300', 'mM', '', '1000', finalUnit: 'mM'),
    ],
    workingStocks: singleStock
        ? [
            WorkingStockProvenance(
              slot: 1,
              parentInput: parent,
              workingConcentration: '1',
              workingUnit: 'mg/mL',
              dilutionFactor: 10,
              parentVolumeMl: 0.001,
              diluentVolumeMl: 0.009,
              preparationVolumeMl: 0.01,
              requiredVolumeMl: 0.002595866666666667,
              newAliquotMl: 0.002595866666666667,
              minimumVolumeMl: 0.001,
              diluentName: 'PBS',
            ),
          ]
        : [],
    gradient: GradientInputSnapshot(
      selectedSlot: 1,
      unit: 'eq',
      points: points,
      replicates: replicates,
      extraPreparationFraction: extra,
      workingStocks: batchStocks,
    ),
  );
}

CalculationHistory gradientHistoryRecord(CalculationInputSnapshot snapshot) =>
    CalculationHistory(
      id: 1,
      createdAt: '2026-10-03T08:48:15',
      ratioType: true,
      reactionVolume: 0.1,
      inputSnapshot: snapshot,
    );
