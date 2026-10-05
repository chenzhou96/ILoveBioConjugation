import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/core/planning.dart';
import 'package:ilovebioconjugation/data/calculation_input_snapshot.dart';

SubstrateInputSnapshot reagent({
  String name = 'Reagent',
  String stock = '10',
  String stockUnit = 'mM',
  String finalConc = '0.1',
  String finalUnit = 'mM',
  String mw = '1000',
  String volume = '',
  String ratio = '',
  bool enabled = true,
}) => SubstrateInputSnapshot(
  enabled: enabled,
  name: name,
  mw: mw,
  mwUnit: 'Da',
  storageConc: stock,
  storageUnit: stockUnit,
  finalConc: finalConc,
  finalUnit: finalUnit,
  reactionRatio: ratio,
  storageVolume: volume,
  storageVolumeUnit: 'mL',
);

CalculationInputSnapshot input({
  List<SubstrateInputSnapshot>? substrates,
  int reference = 0,
  bool molar = true,
  String volume = '0.1',
}) => CalculationInputSnapshot(
  reactionVolume: volume,
  reactionVolumeUnit: 'mL',
  ratioType: molar,
  referenceSlot: reference,
  substrates:
      substrates ??
      [
        reagent(name: 'Protein', stock: '1', finalConc: '0.1', mw: '50000'),
        reagent(name: 'Label', stock: '100', finalConc: '0.2', mw: '500'),
      ],
);

void main() {
  group('pure calculation and reference', () {
    test(
      'unrounded physical outputs retain raw source and dual concentration bases',
      () {
        final source = input();
        final result = solveCalculation(source);
        expect(identical(result.input, source), isTrue);
        expect(result.totalVolumeMl, 0.1);
        expect(result.substrateAt(0).aliquotMl, closeTo(0.01, 1e-15));
        expect(result.substrateAt(1).aliquotMl, closeTo(0.0002, 1e-15));
        expect(result.stockVolumeMl, closeTo(0.0102, 1e-15));
        expect(result.diluentVolumeMl, closeTo(0.0898, 1e-15));
        expect(result.substrateAt(0).finalMassMgMl, 5);
        expect(result.substrateAt(1).finalMassMgMl, 0.1);
        expect(result.substrateAt(1).ratio, 2);
        expect(
          result.warnings.where((w) => w.code == 'low_volume').single.slot,
          1,
        );
        expect(source.substrates[1].storageVolume, '');
        expect(source.substrates[1].reactionRatio, '');
        expect(() => result.substrates.clear(), throwsUnsupportedError);
        expect(() => result.warnings.clear(), throwsUnsupportedError);
      },
    );

    test('reference normalizes displayed ratios without physical changes', () {
      final a = solveCalculation(input());
      final b = solveCalculation(input(reference: 1));
      expect(b.referenceSlot, 1);
      expect(b.substrates.map((s) => s.slot).toList(), [0, 1]);
      expect(b.substrateAt(0).ratio, 0.5);
      expect(b.substrateAt(1).ratio, 1);
      for (var slot = 0; slot < 2; slot++) {
        expect(b.substrateAt(slot).aliquotMl, a.substrateAt(slot).aliquotMl);
        expect(
          b.substrateAt(slot).finalMolarMm,
          a.substrateAt(slot).finalMolarMm,
        );
      }
    });

    test('new reference can anchor ratio while original main has no ratio', () {
      final source = input(
        reference: 1,
        substrates: [
          reagent(stock: '1', finalConc: '0.1'),
          reagent(stock: '100', finalConc: '0.2', ratio: '1'),
        ],
      );
      final result = solveCalculation(source);
      expect(result.substrateAt(0).ratio, 0.5);
      expect(result.substrateAt(1).ratio, 1);
    });

    test('mass reference uses mass quantity rather than molar quantity', () {
      final result = solveCalculation(input(molar: false, reference: 1));
      expect(result.substrateAt(0).ratio, 50);
      expect(result.substrateAt(1).ratio, 1);
    });

    test('disabled slot identity survives holes', () {
      final result = solveCalculation(
        input(
          reference: 3,
          substrates: [
            reagent(finalConc: '0.1'),
            reagent(enabled: false, stock: 'nonsense'),
            reagent(enabled: false),
            reagent(finalConc: '0.3'),
          ],
        ),
      );
      expect(result.substrates.map((s) => s.slot), [0, 3]);
      expect(result.substrateAt(0).ratio, closeTo(1 / 3, 1e-15));
      expect(
        () => solveCalculation(result.input, referenceSlot: 1),
        throwsArgumentError,
      );
    });

    test(
      'omitted threshold follows persisted setting including disabled warnings',
      () {
        final original = input();
        final source = CalculationInputSnapshot(
          reactionVolume: original.reactionVolume,
          reactionVolumeUnit: original.reactionVolumeUnit,
          ratioType: original.ratioType,
          substrates: original.substrates,
          minimumPipettingVolumeUl: 0,
        );
        final result = solveCalculation(source);
        expect(result.warnings, isEmpty);
        final plan = generateGradient(
          result,
          GradientSpec(
            selectedSlot: 1,
            unit: 'mM',
            points: ['0', '0.1', '0.2'],
          ),
        );
        expect(plan.groups.every((g) => g.result!.warnings.isEmpty), isTrue);
      },
    );

    test(
      'one-ulp threshold roundoff does not rewarn after working stock adoption',
      () {
        final result = solveCalculation(
          input(
            substrates: [
              reagent(stock: '10', finalConc: '0.09999999999999999'),
            ],
          ),
          minimumVolumeMl: 0.001,
        );
        expect(result.warnings, isEmpty);
        final genuinelySmall = solveCalculation(
          input(
            substrates: [reagent(stock: '10', finalConc: '0.0999')],
          ),
          minimumVolumeMl: 0.001,
        );
        expect(
          genuinelySmall.warnings.where((w) => w.code == 'low_volume'),
          hasLength(1),
        );
      },
    );

    test('0 threshold disables low-volume warnings', () {
      final result = solveCalculation(input(), minimumVolumeMl: 0);
      expect(result.warnings, isEmpty);
    });

    test('threshold boundary is strict and zeros do not warn', () {
      final source = input(substrates: [reagent(finalConc: '0')]);
      expect(
        solveCalculation(source).warnings.where((w) => w.code == 'low_volume'),
        isEmpty,
      );
      final result = solveCalculation(
        input(
          substrates: [reagent(stock: '10', finalConc: '0.1')],
        ),
        minimumVolumeMl: 0.001,
      );
      expect(result.substrateAt(0).aliquotMl, closeTo(0.001, 1e-18));
      expect(result.warnings, isEmpty);
    });

    test('raw nan, invalid threshold and disabled reference reject', () {
      expect(() => solveCalculation(input(volume: 'NaN')), throwsArgumentError);
      expect(
        () => solveCalculation(input(), minimumVolumeMl: -1),
        throwsArgumentError,
      );
      expect(
        () => solveCalculation(input(), minimumVolumeMl: double.infinity),
        throwsArgumentError,
      );
      expect(
        () => solveCalculation(input(), referenceSlot: 9),
        throwsArgumentError,
      );
    });
  });

  group('fixed protein fixed total single-factor gradient', () {
    test('0, 0.1 and 0.2 mM preserve protein amount and exact total', () {
      final baseline = solveCalculation(input());
      final plan = generateGradient(
        baseline,
        GradientSpec(
          selectedSlot: 1,
          unit: 'mM',
          points: ['0', '0.1', '0.2'],
          replicates: 3,
        ),
      );
      expect(plan.isValid, isTrue);
      expect(plan.groups.length, 3);
      for (var i = 0; i < 3; i++) {
        final result = plan.groups[i].result!;
        expect(result.totalVolumeMl, 0.1);
        expect(result.substrateAt(0).aliquotMl, closeTo(0.01, 1e-15));
        expect(result.substrateAt(0).finalMolarMm, 0.1);
        expect(result.substrateAt(1).finalMolarMm, closeTo(i * 0.1, 1e-15));
        expect(result.substrateAt(1).aliquotMl, closeTo(i * 0.0001, 1e-15));
        expect(result.substrateAt(1).ratio, i.toDouble());
        expect(
          result.stockVolumeMl + result.diluentVolumeMl,
          closeTo(0.1, 1e-15),
        );
      }
      expect(plan.totals.reactionCount, 9);
      expect(plan.totals.aliquotsMl[0], closeTo(0.09, 1e-15));
      expect(plan.totals.aliquotsMl[1], closeTo(0.0009, 1e-15));
      expect(plan.totals.diluentMl, closeTo(0.8091, 1e-15));
      expect(plan.totals.totalVolumeMl, closeTo(0.9, 1e-15));
      expect(baseline.substrateAt(1).finalMolarMm, 0.2);
      expect(baseline.substrateAt(1).aliquotMl, closeTo(0.0002, 1e-15));
    });

    test(
      'clears old aliquot and ratio constraints instead of mutating baseline',
      () {
        final source = input(
          substrates: [
            reagent(stock: '1', finalConc: '0.1', volume: '0.01', ratio: '1'),
            reagent(
              stock: '100',
              finalConc: '0.2',
              volume: '0.0002',
              ratio: '2',
            ),
          ],
        );
        final baseline = solveCalculation(source);
        final plan = generateGradient(
          baseline,
          GradientSpec(selectedSlot: 1, unit: 'eq', points: ['0', '5', '10']),
        );
        expect(plan.isValid, isTrue);
        expect(plan.groups[1].result!.substrateAt(1).finalMolarMm, 0.5);
        expect(plan.groups[2].result!.substrateAt(1).ratio, 10);
        expect(source.substrates[1].storageVolume, '0.0002');
        expect(source.substrates[1].reactionRatio, '2');
      },
    );

    test('extra fraction only scales preparation totals', () {
      final baseline = solveCalculation(input());
      final plan = generateGradient(
        baseline,
        GradientSpec(
          selectedSlot: 1,
          unit: 'mM',
          points: ['0.1', '0.2'],
          replicates: 2,
          extraPreparationFraction: 0.1,
        ),
      );
      expect(plan.totals.reactionCount, 4);
      expect(plan.totals.preparationReactionEquivalent, 4.4);
      expect(plan.totals.totalVolumeMl, closeTo(0.44, 1e-15));
      expect(
        plan.groups[1].result!.substrateAt(1).aliquotMl,
        closeTo(0.0002, 1e-15),
      );
      expect(plan.totals.aliquotsMl[1], closeTo(0.00066, 1e-15));
    });

    test('mass eq uses current mass-ratio reference', () {
      final baseline = solveCalculation(input(molar: false));
      final plan = generateGradient(
        baseline,
        GradientSpec(selectedSlot: 1, unit: 'eq', points: ['0', '0.1', '1']),
      );
      expect(plan.groups[1].result!.substrateAt(1).finalMassMgMl, 0.5);
      expect(plan.groups[1].result!.substrateAt(1).finalMolarMm, 1);
      expect(plan.groups[1].result!.substrateAt(1).ratio, 0.1);
    });

    test('cross-basis point converts through molecular weight', () {
      final baseline = solveCalculation(input());
      final plan = generateGradient(
        baseline,
        GradientSpec(
          selectedSlot: 1,
          unit: 'ug/mL',
          points: ['0', '50', '100'],
        ),
      );
      expect(
        plan.groups[1].result!.substrateAt(1).finalMolarMm,
        closeTo(0.1, 1e-15),
      );
      expect(
        plan.groups[2].result!.substrateAt(1).finalMolarMm,
        closeTo(0.2, 1e-15),
      );
    });

    test('cross-basis target without MW blocks before generating groups', () {
      final baseline = solveCalculation(
        input(
          substrates: [
            reagent(stock: '1'),
            reagent(stock: '100', mw: ''),
          ],
        ),
      );
      expect(
        () => generateGradient(
          baseline,
          GradientSpec(selectedSlot: 1, unit: 'mg/mL', points: ['1']),
        ),
        throwsArgumentError,
      );
    });

    test(
      'reference at zero shows N/A while internal positive anchor solves',
      () {
        final baseline = solveCalculation(input(reference: 1));
        final plan = generateGradient(
          baseline,
          GradientSpec(selectedSlot: 1, unit: 'mM', points: ['0', '0.2']),
        );
        final control = plan.groups[0].result!;
        expect(control.referenceSlot, 1);
        expect(control.substrates.map((s) => s.slot), [0, 1]);
        expect(control.substrateAt(0).ratio, isNull);
        expect(control.substrateAt(1).ratio, isNull);
        expect(control.substrateAt(1).aliquotMl, 0);
        expect(
          control.warnings.where((w) => w.code == 'zero_reference'),
          hasLength(1),
        );
        expect(control.warnings.where((w) => w.code == 'low_volume'), isEmpty);
        expect(plan.groups[1].result!.substrateAt(0).ratio, 0.5);
      },
    );

    test('all-zero solvent-only control retains both slots and total', () {
      final baseline = solveCalculation(
        input(
          substrates: [
            reagent(finalConc: '0', ratio: '1'),
            reagent(finalConc: '0', ratio: '1'),
          ],
        ),
      );
      final plan = generateGradient(
        baseline,
        GradientSpec(selectedSlot: 1, unit: 'mM', points: ['0', '0.1']),
      );
      final zero = plan.groups.first.result!;
      expect(zero.stockVolumeMl, 0);
      expect(zero.diluentVolumeMl, 0.1);
      expect(zero.substrates.map((s) => s.aliquotMl), [0, 0]);
      expect(zero.substrates.every((s) => s.ratio == null), isTrue);
      expect(plan.groups[1].result!.substrateAt(0).aliquotMl, 0);
      expect(
        plan.groups[1].result!.substrateAt(1).aliquotMl,
        closeTo(0.001, 1e-15),
      );
    });

    test('failures retain indices and valid-only totals', () {
      final baseline = solveCalculation(input());
      final plan = generateGradient(
        baseline,
        GradientSpec(
          selectedSlot: 1,
          unit: 'mM',
          points: ['0', '200', 'bad', '-1', '0.2', 'Infinity'],
          replicates: 2,
        ),
      );
      expect(plan.isPartial, isTrue);
      expect(plan.isValid, isFalse);
      expect(plan.groups.map((g) => g.index), [0, 1, 2, 3, 4, 5]);
      expect(plan.groups.map((g) => g.isValid), [
        true,
        false,
        false,
        false,
        true,
        false,
      ]);
      expect(plan.groups[1].error, contains('总体积'));
      expect(plan.groups[2].pointText, 'bad');
      expect(plan.totals.validGroupsOnly, isTrue);
      expect(plan.totals.validGroupCount, 2);
      expect(plan.totals.failedGroupCount, 4);
      expect(plan.totals.reactionCount, 4);
      expect(plan.totals.aliquotsMl[1], closeTo(0.0004, 1e-15));
      expect(plan.totals.totalVolumeMl, closeTo(0.4, 1e-15));
    });

    test('duplicate points remain distinct conditions', () {
      final plan = generateGradient(
        solveCalculation(input()),
        GradientSpec(
          selectedSlot: 1,
          unit: 'eq',
          points: ['2', '2'],
          replicates: 3,
        ),
      );
      expect(plan.groups, hasLength(2));
      expect(plan.totals.reactionCount, 6);
    });

    test('protects protein and rejects self-reference eq, invalid repeats', () {
      final baseline = solveCalculation(input());
      expect(
        () => generateGradient(
          baseline,
          GradientSpec(selectedSlot: 0, unit: 'mM', points: ['0']),
        ),
        throwsArgumentError,
      );
      expect(
        () => generateGradient(
          solveCalculation(input(reference: 1)),
          GradientSpec(selectedSlot: 1, unit: 'eq', points: ['2']),
        ),
        throwsArgumentError,
      );
      expect(
        () => generateGradient(
          baseline,
          GradientSpec(
            selectedSlot: 1,
            unit: 'eq',
            points: ['1'],
            replicates: 0,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => generateGradient(
          baseline,
          GradientSpec(
            selectedSlot: 1,
            unit: 'eq',
            points: ['1'],
            extraPreparationFraction: -0.1,
          ),
        ),
        throwsArgumentError,
      );
      expect(
        () => generateGradient(
          baseline,
          GradientSpec(selectedSlot: 1, unit: 'eq', points: []),
        ),
        throwsArgumentError,
      );
    });

    test('many raw targets independently preserve analytic mass balances', () {
      final baseline = solveCalculation(input());
      final values = List.generate(120, (i) => i / 1000);
      final plan = generateGradient(
        baseline,
        GradientSpec(
          selectedSlot: 1,
          unit: 'mM',
          points: values.map((v) => v.toString()).toList(),
        ),
      );
      expect(plan.isValid, isTrue);
      for (var i = 0; i < values.length; i++) {
        final result = plan.groups[i].result!;
        final s = result.substrateAt(1);
        expect(s.aliquotMl, closeTo(values[i] * 0.1 / 100, 1e-15));
        expect(s.finalMolarMm, values[i]);
        expect(s.ratio, closeTo(values[i] / 0.1, 1e-15));
        expect(result.substrateAt(0).aliquotMl, closeTo(0.01, 1e-15));
        expect(result.diluentVolumeMl, closeTo(0.09 - s.aliquotMl, 1e-15));
      }
    });
  });

  group('working stocks and feasibility', () {
    test(
      '5-fold plan keeps amount and sizes preparation with pipettable inputs',
      () {
        final result = solveCalculation(input());
        final proposal = proposeWorkingStock(
          result,
          slot: 1,
          minimumVolumeMl: 0.001,
          replicates: 3,
          diluentName: 'user buffer',
        );
        expect(proposal.feasible, isTrue);
        expect(identical(proposal.sourceResult, result), isTrue);
        expect(proposal.factor, closeTo(5, 1e-14));
        expect(proposal.stockMolarMm, closeTo(20, 1e-14));
        expect(proposal.stockMassMgMl, closeTo(10, 1e-14));
        expect(proposal.newAliquotMl, closeTo(0.001, 1e-15));
        expect(proposal.requiredVolumeMl, closeTo(0.003, 1e-15));
        expect(proposal.parentStockMl, closeTo(0.001, 1e-15));
        expect(proposal.diluentMl, closeTo(0.004, 1e-15));
        expect(proposal.preparationVolumeMl, closeTo(0.005, 1e-15));
        expect(
          proposal.stockMolarMm! * proposal.newAliquotMl,
          closeTo(
            result.substrateAt(1).stockMolarMm! *
                result.substrateAt(1).aliquotMl,
            1e-15,
          ),
        );
        expect(proposal.diluentName, 'user buffer');
        expect(proposal.reason, contains('DMSO'));
        expect(result.substrateAt(1).stockMolarMm, 100);
      },
    );

    test(
      'small dilution factor increases preparation so diluent is pipettable',
      () {
        final result = solveCalculation(input());
        final proposal = proposeWorkingStock(
          result,
          slot: 0,
          minimumVolumeMl: 0.001,
          dilutionFactor: 1.01,
        );
        expect(proposal.feasible, isTrue);
        expect(proposal.parentStockMl, closeTo(0.1, 1e-13));
        expect(proposal.diluentMl, closeTo(0.001, 1e-15));
        expect(
          proposal.preparationVolumeMl,
          greaterThan(proposal.requiredVolumeMl),
        );
      },
    );

    test('required volume includes replicates and extra preparation', () {
      final proposal = proposeWorkingStock(
        solveCalculation(input()),
        slot: 1,
        minimumVolumeMl: 0.001,
        replicates: 20,
        extraPreparationFraction: 0.1,
      );
      expect(proposal.feasible, isTrue);
      expect(proposal.requiredVolumeMl, closeTo(0.022, 1e-15));
      expect(proposal.preparationVolumeMl, closeTo(0.022, 1e-15));
      expect(proposal.parentStockMl, closeTo(0.0044, 1e-15));
    });

    test('cannot fit increased aliquot in fixed total', () {
      final result = solveCalculation(
        input(
          substrates: [
            reagent(stock: '1', finalConc: '0.999'),
            reagent(stock: '100', finalConc: '0.1'),
          ],
        ),
      );
      final proposal = proposeWorkingStock(
        result,
        slot: 1,
        minimumVolumeMl: 0.001,
      );
      expect(proposal.feasible, isFalse);
      expect(proposal.reason, contains('剩余空间'));
    });

    test(
      'invalid factor, zero dose and disabled threshold cannot produce recipe',
      () {
        final result = solveCalculation(input());
        for (final factor in [0.0, -1.0, double.infinity, double.nan, 2.0]) {
          expect(
            proposeWorkingStock(
              result,
              slot: 1,
              minimumVolumeMl: 0.001,
              dilutionFactor: factor,
            ).feasible,
            isFalse,
          );
        }
        final control = generateGradient(
          result,
          GradientSpec(selectedSlot: 1, unit: 'mM', points: ['0']),
        ).groups.first.result!;
        expect(
          proposeWorkingStock(
            control,
            slot: 1,
            minimumVolumeMl: 0.001,
          ).feasible,
          isFalse,
        );
        expect(
          () => proposeWorkingStock(result, slot: 1, minimumVolumeMl: 0),
          throwsArgumentError,
        );
      },
    );

    test(
      'common working stock sizes whole gradient and excludes zero control',
      () {
        final plan = generateGradient(
          solveCalculation(input()),
          GradientSpec(
            selectedSlot: 1,
            unit: 'mM',
            points: ['0', '0.1', '0.2'],
            replicates: 4,
            extraPreparationFraction: 0.1,
          ),
        );
        final advice = proposeGradientWorkingStock(
          plan,
          slot: 1,
          minimumVolumeMl: 0.001,
          diluentName: 'buffer',
        );
        expect(advice.feasible, isTrue);
        expect(advice.tiers, isEmpty);
        expect(advice.shared!.factor, closeTo(10, 1e-14));
        expect(advice.shared!.requiredVolumeMl, closeTo(0.0132, 1e-15));
        expect(advice.shared!.preparationVolumeMl, closeTo(0.0132, 1e-15));
      },
    );

    test(
      'wide range gets two actually feasible tiers rather than false common advice',
      () {
        final plan = generateGradient(
          solveCalculation(input()),
          GradientSpec(
            selectedSlot: 1,
            unit: 'mM',
            points: ['0', '0.01', '0.1', '80'],
          ),
        );
        final advice = proposeGradientWorkingStock(
          plan,
          slot: 1,
          minimumVolumeMl: 0.001,
          diluentName: 'buffer',
        );
        expect(advice.feasible, isTrue);
        expect(advice.shared, isNull);
        expect(advice.tiers, hasLength(2));
        expect(advice.tiers[0].groupIndices, [1, 2]);
        expect(advice.tiers[0].proposal.factor, closeTo(100, 1e-10));
        expect(advice.tiers[1].groupIndices, [3]);
        expect(advice.tiers[1].proposal.factor, 1);
        for (final tier in advice.tiers) {
          expect(tier.proposal.feasible, isTrue);
          for (final index in tier.groupIndices) {
            final group = plan.groups[index].result!;
            final expanded =
                group.substrateAt(1).aliquotMl * tier.proposal.factor;
            expect(
              expanded + group.substrateAt(0).aliquotMl,
              lessThanOrEqualTo(group.totalVolumeMl + 1e-14),
            );
            expect(expanded, greaterThanOrEqualTo(0.001 - 1e-14));
          }
        }
      },
    );
  });

  group('explicit batch working stock adoption', () {
    test(
      'changes groups and bulk totals while retaining baseline outside gradient',
      () {
        final baseline = solveCalculation(
          input(
            substrates: [
              reagent(stock: '1', finalConc: '0.1'),
              reagent(stock: '100', finalConc: '80'),
            ],
          ),
        );
        final plan = generateGradient(
          baseline,
          GradientSpec(
            selectedSlot: 1,
            unit: 'mM',
            points: ['0', '0.1', '0.2', '200'],
            replicates: 2,
            extraPreparationFraction: 0.1,
          ),
        );
        final advice = proposeGradientWorkingStock(
          plan,
          slot: 1,
          minimumVolumeMl: 0.001,
          diluentName: 'confirmed buffer',
        );
        expect(advice.shared!.factor, closeTo(10, 1e-13));
        final adopted = applyGradientWorkingStock(plan, advice);
        expect(identical(adopted.baseline, baseline), isTrue);
        expect(baseline.substrateAt(1).stockMolarMm, 100);
        expect(baseline.substrateAt(1).finalMolarMm, 80);
        expect(baseline.substrateAt(1).aliquotMl, closeTo(0.08, 1e-14));
        expect(adopted.workingStocks, hasLength(1));
        expect(adopted.workingStocks.single.diluentName, 'confirmed buffer');
        expect(identical(adopted.groups[3], plan.groups[3]), isTrue);
        expect(adopted.isPartial, isTrue);
        for (var i = 0; i < 3; i++) {
          final before = plan.groups[i].result!;
          final after = adopted.groups[i].result!;
          expect(after.substrateAt(1).stockMolarMm, closeTo(10, 1e-13));
          expect(
            after.substrateAt(1).aliquotMl,
            closeTo(before.substrateAt(1).aliquotMl * 10, 1e-15),
          );
          expect(
            after.substrateAt(1).finalMolarMm,
            before.substrateAt(1).finalMolarMm,
          );
          expect(
            after.substrateAt(0).aliquotMl,
            before.substrateAt(0).aliquotMl,
          );
          expect(after.totalVolumeMl, before.totalVolumeMl);
          expect(after.substrateAt(1).ratio, before.substrateAt(1).ratio);
        }
        expect(adopted.totals.aliquotsMl[1], closeTo(0.0066, 1e-15));
        expect(adopted.totals.reactionCount, 6);
        expect(adopted.totals.totalVolumeMl, closeTo(0.66, 1e-15));
        expect(plan.workingStocks, isEmpty);
        expect(() => adopted.workingStocks.clear(), throwsUnsupportedError);
      },
    );

    test(
      'explicit persisted factor replay reproduces output and does not reselect factor',
      () {
        final plan = generateGradient(
          solveCalculation(input()),
          GradientSpec(selectedSlot: 1, unit: 'eq', points: ['0', '1', '2']),
        );
        final adopted = applyGradientWorkingStockFactor(
          plan,
          slot: 1,
          factor: 20,
          diluentName: 'buffer',
          minimumVolumeMl: 0.001,
        );
        expect(adopted.workingStocks.single.factor, 20);
        expect(adopted.groups[1].result!.substrateAt(1).stockMolarMm, 5);
        expect(
          adopted.groups[1].result!.substrateAt(1).aliquotMl,
          closeTo(0.002, 1e-15),
        );
        expect(
          adopted.groups[2].result!.substrateAt(1).aliquotMl,
          closeTo(0.004, 1e-15),
        );
      },
    );

    test(
      'replay retains recipe threshold while new threshold disables all warnings',
      () {
        final baseline = solveCalculation(
          input(
            substrates: [
              reagent(stock: '1', finalConc: '0.1'),
              reagent(stock: '100', finalConc: '0.2'),
              reagent(stock: '100', finalConc: '0.01'),
            ],
          ),
        );
        final plan = generateGradient(
          baseline,
          GradientSpec(
            selectedSlot: 1,
            unit: 'mM',
            points: ['0', '0.1', '0.2'],
          ),
        );
        expect(
          plan.groups.first.result!.warnings.any((w) => w.slot == 2),
          isTrue,
        );
        final adopted = applyGradientWorkingStockFactor(
          plan,
          slot: 1,
          factor: 10,
          diluentName: 'buffer',
          minimumVolumeMl: 0.001,
          warningMinimumVolumeMl: 0,
        );
        expect(adopted.groups.every((g) => g.result!.warnings.isEmpty), isTrue);
        expect(adopted.workingStocks.single.minimumVolumeMl, 0.001);
        expect(
          adopted.workingStocks.single.parentStockMl,
          greaterThanOrEqualTo(0.001),
        );
        expect(
          () => applyGradientWorkingStockFactor(
            adopted,
            slot: 1,
            factor: 2,
            diluentName: 'buffer',
            minimumVolumeMl: 0.001,
          ),
          throwsArgumentError,
        );
      },
    );

    test(
      'stale, blank diluent, tiered and infeasible advice cannot be adopted',
      () {
        final baseline = solveCalculation(input());
        final spec = GradientSpec(
          selectedSlot: 1,
          unit: 'mM',
          points: ['0.1', '0.2'],
        );
        final plan = generateGradient(baseline, spec);
        final advice = proposeGradientWorkingStock(
          plan,
          slot: 1,
          minimumVolumeMl: 0.001,
          diluentName: 'buffer',
        );
        expect(
          () => applyGradientWorkingStock(
            generateGradient(baseline, spec),
            advice,
          ),
          throwsArgumentError,
        );
        expect(
          () => applyGradientWorkingStock(
            plan,
            proposeGradientWorkingStock(plan, slot: 1, minimumVolumeMl: 0.001),
          ),
          throwsArgumentError,
        );
        final wide = generateGradient(
          baseline,
          GradientSpec(selectedSlot: 1, unit: 'mM', points: ['0.01', '80']),
        );
        final tiered = proposeGradientWorkingStock(
          wide,
          slot: 1,
          minimumVolumeMl: 0.001,
          diluentName: 'buffer',
        );
        expect(tiered.tiers, hasLength(2));
        expect(
          () => applyGradientWorkingStock(wide, tiered),
          throwsArgumentError,
        );
        expect(
          () => applyGradientWorkingStockFactor(
            plan,
            slot: 1,
            factor: 10000,
            diluentName: 'buffer',
            minimumVolumeMl: 0.001,
          ),
          throwsArgumentError,
        );
      },
    );
  });

  group('gradient point generators', () {
    test('arithmetic and geometric preserve count and zero control', () {
      expect(arithmeticGradientPoints(start: 0, step: 2, count: 4), [
        '0.0',
        '2.0',
        '4.0',
        '6.0',
      ]);
      expect(geometricGradientPoints(start: 0.1, factor: 10, count: 4), [
        '0.1',
        '1.0',
        '10.0',
        '100.0',
      ]);
      expect(arithmeticGradientPoints(start: 1, step: -0.5, count: 3), [
        '1.0',
        '0.5',
        '0.0',
      ]);
      expect(
        () => arithmeticGradientPoints(start: 0, step: 1, count: 0),
        throwsArgumentError,
      );
      expect(
        () => arithmeticGradientPoints(start: 0, step: -1, count: 2),
        throwsArgumentError,
      );
      expect(
        () => geometricGradientPoints(start: 0, factor: 2, count: 2),
        throwsArgumentError,
      );
      expect(
        () => geometricGradientPoints(start: 1e308, factor: 100, count: 2),
        throwsArgumentError,
      );
      expect(
        () => geometricGradientPoints(start: 1e-300, factor: 1e-300, count: 2),
        throwsArgumentError,
      );
    });
  });
}
