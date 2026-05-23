import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjunction/core/chemical.dart';
import 'package:ilovebioconjunction/core/reaction.dart';

void main() {
  group('Multi-substrate solver — Python parity', () {
    test('Goat IgG + TCEP reference case matches Python output', () {
      // Exact same inputs as test_data.py / Python reference calculation
      final main = Chemical(
        unitCoefficient: 0,
        name: 'Goat IgG',
        storageConcMass: 10, // 10 mg/mL
        molecularWeight: 150000, // 150 kDa → 150000 Da
        finalConcMass: 5, // 5 mg/mL
        reactionRatio: 1,
      );

      final tcep = Chemical(
        unitCoefficient: 3,
        name: 'TCEP',
        storageConcMolar: 6000, // 6 M → 6000 mM
        reactionRatio: 10,
      );

      final rxn = Reaction(
        ratioType: true, // molar ratio
        substrateMain: main,
        substratesSecondary: [tcep],
        reactionVolume: 0.02, // 20 uL → 0.02 mL
      );

      // Verify reaction volume
      expect(rxn.reactionVolume, closeTo(0.02, 1e-15));

      // Verify total stock volume
      expect(rxn.totalStockVolume, closeTo(0.010001111111111112, 1e-12));

      // Main substrate (Goat IgG)
      expect(main.storageConcMolar, closeTo(0.06666666666666667, 1e-12));
      expect(main.storageConcMass, closeTo(10.0, 1e-12));
      expect(main.finalConcMolar, closeTo(0.03333333333333333, 1e-12));
      expect(main.finalConcMass, closeTo(5.0, 1e-12));
      expect(main.storageConcVolume, closeTo(0.01, 1e-12));
      expect(main.reactionRatio, closeTo(1.0, 1e-12));

      // Secondary (TCEP)
      expect(tcep.storageConcMolar, closeTo(6000.0, 1e-12));
      expect(tcep.finalConcMolar, closeTo(0.3333333333333333, 1e-12));
      expect(tcep.storageConcVolume, closeTo(1.1111111111111112e-06, 1e-12));
      expect(tcep.reactionRatio, closeTo(10.0, 1e-12));
    });
  });

  group('Multi-substrate solver — edge cases', () {
    test('solves with two secondary substrates', () {
      final main = Chemical(
        unitCoefficient: 0,
        name: 'Main',
        storageConcMass: 10,
        molecularWeight: 100000,
        reactionRatio: 1,
        storageConcVolume: 2,
      );

      final sec1 = Chemical(
        unitCoefficient: 0,
        name: 'Secondary1',
        storageConcMass: 5,
        reactionRatio: 2,
      );

      final sec2 = Chemical(
        unitCoefficient: 3,
        name: 'Secondary2',
        storageConcMolar: 100,
        reactionRatio: 0.5,
      );

      final rxn = Reaction(
        ratioType: false, // mass ratio
        substrateMain: main,
        substratesSecondary: [sec1, sec2],
        reactionVolume: 5,
      );

      // All substrates should have resolved volumes
      for (final chem in rxn.allSubstrates) {
        expect(chem.storageConcVolume, isNotNull);
        expect(chem.storageConcVolume! > 0, isTrue);
        expect(chem.reactionRatio, isNotNull);
      }
    });

    test('solves from final concentrations instead of volumes', () {
      final main = Chemical(
        unitCoefficient: 3,
        name: 'Main',
        storageConcMolar: 50,
        finalConcMolar: 10,
        reactionRatio: 1,
      );

      final sec = Chemical(
        unitCoefficient: 3,
        name: 'Secondary',
        storageConcMolar: 200,
        finalConcMolar: 20,
        reactionRatio: 2,
      );

      final rxn = Reaction(
        ratioType: true,
        substrateMain: main,
        substratesSecondary: [sec],
        reactionVolume: 10,
      );

      // Main: a = d * b / s = 10 * 10 / 50 = 2
      expect(main.storageConcVolume, closeTo(2.0, 1e-12));

      // All substrates should have resolved volumes
      for (final chem in rxn.allSubstrates) {
        expect(chem.storageConcVolume, isNotNull);
        expect(chem.storageConcVolume! > 0, isTrue);
        expect(chem.reactionRatio, isNotNull);
      }
    });

    test('throws on too many secondaries', () {
      Chemical makeChem(String name) =>
          Chemical(unitCoefficient: 0, name: name, storageConcMass: 1);

      expect(
        () => Reaction(
          ratioType: false,
          substrateMain: makeChem('Main'),
          substratesSecondary: [
            makeChem('S1'),
            makeChem('S2'),
            makeChem('S3'),
            makeChem('S4'), // 4th → exceeds max
          ],
          reactionVolume: 1,
        ),
        throwsArgumentError,
      );
    });

    test('throws on insufficient data', () {
      final main = Chemical(
        unitCoefficient: 0,
        name: 'Main',
        storageConcMass: 10,
      );
      // No reaction volume, no storage volumes, no ratios → can't solve
      expect(
        () => Reaction(ratioType: false, substrateMain: main),
        throwsArgumentError,
      );
    });

    test('auto-derives secondary ratios from known volumes', () {
      final main = Chemical(
        unitCoefficient: 0,
        name: 'Main',
        storageConcMass: 10,
        storageConcVolume: 2,
        reactionRatio: 1,
      );

      final sec = Chemical(
        unitCoefficient: 0,
        name: 'Secondary',
        storageConcMass: 5,
        storageConcVolume: 0.5,
      );

      final rxn = Reaction(
        ratioType: false,
        substrateMain: main,
        substratesSecondary: [sec],
        reactionVolume: 10,
      );

      expect(rxn.reactionVolume, closeTo(10.0, 1e-12));
      // Secondary ratio should be derived from the volume/concentration relationship
      expect(sec.reactionRatio, isNotNull);
      expect(sec.reactionRatio! > 0, isTrue);
    });
  });

  group('Multi-substrate — mass ratio mode', () {
    test('works correctly in mass ratio mode', () {
      final main = Chemical(
        unitCoefficient: 0,
        name: 'Main',
        storageConcMass: 20,
        storageConcVolume: 1,
        reactionRatio: 1,
      );

      final sec = Chemical(
        unitCoefficient: 0,
        name: 'Secondary',
        storageConcMass: 10,
        reactionRatio: 0.5, // half the mass ratio of main
      );

      final rxn = Reaction(
        ratioType: false, // mass ratio
        substrateMain: main,
        substratesSecondary: [sec],
        reactionVolume: 5,
      );

      // Both substrates should have valid results
      for (final chem in rxn.allSubstrates) {
        expect(chem.storageConcVolume, isNotNull);
        expect(chem.storageConcVolume! > 0, isTrue);
      }

      // Total stock should not exceed reaction volume
      expect(rxn.totalStockVolume <= 5.0, isTrue);
    });
  });
}
