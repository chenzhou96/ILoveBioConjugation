import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/core/planning.dart';
import 'package:ilovebioconjugation/data/calculation_input_snapshot.dart';

SubstrateInputSnapshot _reagent(
  String name,
  String stock,
  String target, {
  bool enabled = true,
}) => SubstrateInputSnapshot(
  enabled: enabled,
  name: name,
  mw: '1000',
  mwUnit: 'Da',
  storageConc: stock,
  storageUnit: 'mM',
  finalConc: target,
  finalUnit: 'mM',
  reactionRatio: '',
  storageVolume: '',
  storageVolumeUnit: 'mL',
);

WorkingStockProvenance _recipe() => WorkingStockProvenance(
  slot: 1,
  parentInput: _reagent('Label', '100', '0.2'),
  workingConcentration: '20',
  workingUnit: 'mM',
  dilutionFactor: 5,
  parentVolumeMl: 0.001,
  diluentVolumeMl: 0.004,
  preparationVolumeMl: 0.005,
  requiredVolumeMl: 0.001,
  newAliquotMl: 0.001,
  minimumVolumeMl: 0.001,
  diluentName: 'buffer',
);

CalculationInputSnapshot _snapshot({
  String volume = '0.1',
  String labelTarget = '0.2',
  bool labelEnabled = true,
  bool third = false,
  WorkingStockProvenance? recipe,
}) => CalculationInputSnapshot(
  reactionVolume: volume,
  reactionVolumeUnit: 'mL',
  ratioType: true,
  substrates: [
    _reagent('Protein', '1', '0.1'),
    _reagent('Label', '20', labelTarget, enabled: labelEnabled),
    if (third) _reagent('Other reagent', '100', '0.1'),
  ],
  workingStocks: [recipe ?? _recipe()],
);

Iterable<PlanningWarning> _shortage(List<PlanningWarning> warnings) =>
    warnings.where((w) => w.code == 'insufficient_working_stock');

void main() {
  test(
    'larger reaction preserves recorded preparation and warns current demand',
    () {
      final recipe = _recipe();
      final before = recipe.toJson();
      expect(
        _shortage(solveCalculation(_snapshot(recipe: recipe)).warnings),
        isEmpty,
      );
      final result = solveCalculation(
        _snapshot(volume: '1', recipe: recipe),
        minimumVolumeMl: 0,
      );
      expect(result.substrateAt(1).aliquotMl, closeTo(0.01, 1e-15));
      expect(result.totalVolumeMl, 1);
      final warning = _shortage(result.warnings).single;
      expect(warning.slot, 1);
      expect(warning.message, contains('5.000 µL'));
      expect(warning.message, contains('10.000 µL'));
      expect(warning.message, contains('单次需求'));
      expect(recipe.toJson(), before);
      expect(identical(result.input.workingStocks.single, recipe), isTrue);
    },
  );

  test(
    'gradient compares original preparation with repetitions plus extra only for valid groups',
    () {
      final baseline = solveCalculation(_snapshot());
      final plan = generateGradient(
        baseline,
        GradientSpec(
          selectedSlot: 1,
          unit: 'mM',
          points: ['0', '0.1', '0.2', '100'],
          replicates: 4,
          extraPreparationFraction: 0.1,
        ),
      );
      expect(plan.isPartial, isTrue);
      expect(plan.totals.aliquotsMl[1], closeTo(0.0066, 1e-15));
      expect(plan.totals.validGroupCount, 3);
      expect(_shortage(plan.warnings), hasLength(1));
      expect(_shortage(plan.warnings).single.message, contains('有效组总需求'));
      expect(_shortage(plan.warnings).single.message, contains('重复和额外配制'));
      for (final group in plan.groups.where((g) => g.isValid)) {
        expect(_shortage(group.result!.warnings), isEmpty);
      }
      expect(
        plan.baseline.input.workingStocks.single.preparationVolumeMl,
        0.005,
      );
      expect(() => plan.warnings.clear(), throwsUnsupportedError);
    },
  );

  test(
    'disabled archival recipe is ignored by single and gradient warnings',
    () {
      final baseline = solveCalculation(
        _snapshot(labelEnabled: false, third: true),
      );
      expect(_shortage(baseline.warnings), isEmpty);
      final plan = generateGradient(
        baseline,
        GradientSpec(
          selectedSlot: 2,
          unit: 'mM',
          points: ['0.1', '0.2'],
          replicates: 1000,
        ),
      );
      expect(plan.totals.aliquotsMl.containsKey(1), isFalse);
      expect(_shortage(plan.warnings), isEmpty);
      expect(baseline.input.workingStocks, hasLength(1));
    },
  );

  test(
    'warning tolerance ignores roundoff but catches a real preparation shortage',
    () {
      expect(
        _shortage(
          solveCalculation(
            _snapshot(labelTarget: '1.0000000000000002'),
          ).warnings,
        ),
        isEmpty,
      );
      expect(
        _shortage(solveCalculation(_snapshot(labelTarget: '1.01')).warnings),
        hasLength(1),
      );
    },
  );

  test(
    'batch adoption of another slot retains original-stock bulk shortage',
    () {
      final baseline = solveCalculation(_snapshot(third: true));
      final plan = generateGradient(
        baseline,
        GradientSpec(
          selectedSlot: 2,
          unit: 'mM',
          points: ['0.1', '0.2', '0.3'],
          replicates: 4,
        ),
      );
      final advice = proposeGradientWorkingStock(
        plan,
        slot: 2,
        minimumVolumeMl: 0.001,
        diluentName: 'buffer',
      );
      final adopted = applyGradientWorkingStock(plan, advice);
      expect(adopted.workingStocks.single.slot, 2);
      expect(_shortage(adopted.warnings).single.slot, 1);
      expect(adopted.totals.aliquotsMl[1], closeTo(0.012, 1e-15));
      expect(
        adopted.baseline.input.workingStocks.single.preparationVolumeMl,
        0.005,
      );
      expect(_shortage(adopted.warnings).any((w) => w.slot == 2), isFalse);
    },
  );

  test(
    'cross-mode serial dilution and unsupported protein identity are rejected',
    () {
      final baseline = solveCalculation(_snapshot());
      final plan = generateGradient(
        baseline,
        GradientSpec(selectedSlot: 1, unit: 'mM', points: ['0.01', '0.02']),
      );
      final advice = proposeGradientWorkingStock(
        plan,
        slot: 1,
        minimumVolumeMl: 0.001,
        diluentName: 'buffer',
      );
      expect(advice.feasible, isTrue);
      expect(
        () => applyGradientWorkingStock(plan, advice),
        throwsArgumentError,
      );
      expect(
        () => generateGradient(
          baseline,
          GradientSpec(
            selectedSlot: 0,
            proteinSlot: 1,
            unit: 'mM',
            points: ['0.1'],
          ),
        ),
        throwsArgumentError,
      );
    },
  );
}
