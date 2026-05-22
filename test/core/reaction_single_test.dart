import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjunction/core/chemical.dart';
import 'package:ilovebioconjunction/core/reaction.dart';

void main() {
  group('Single substrate solver', () {
    test('solves for reaction volume (d) given a and b', () {
      final chem = Chemical(
        unitCoefficient: 0,
        name: 'Test',
        storageConcMass: 10,
        storageConcVolume: 2,
        finalConcMass: 5,
      );
      final rxn = Reaction(
        ratioType: false, // mass ratio
        substrateMain: chem,
      );
      // d = s * a / b = 10 * 2 / 5 = 4
      expect(rxn.reactionVolume, closeTo(4.0, 1e-12));
    });

    test('solves for storage volume (a) given d and b', () {
      final chem = Chemical(
        unitCoefficient: 0,
        name: 'Test',
        storageConcMass: 10,
        finalConcMass: 5,
      );
      final rxn = Reaction(
        ratioType: false,
        substrateMain: chem,
        reactionVolume: 4,
      );
      // a = d * b / s = 4 * 5 / 10 = 2
      expect(rxn.reactionVolume, closeTo(4.0, 1e-12));
      expect(chem.storageConcVolume, closeTo(2.0, 1e-12));
    });

    test('solves for final concentration (b) given d and a', () {
      final chem = Chemical(
        unitCoefficient: 0,
        name: 'Test',
        storageConcMass: 10,
        storageConcVolume: 2,
      );
      final rxn = Reaction(
        ratioType: false,
        substrateMain: chem,
        reactionVolume: 4,
      );
      // b = s * a / d = 10 * 2 / 4 = 5
      expect(rxn.reactionVolume, closeTo(4.0, 1e-12));
      expect(chem.finalConcMass, closeTo(5.0, 1e-12));
    });

    test('no-op when all three are known', () {
      final chem = Chemical(
        unitCoefficient: 0,
        name: 'Test',
        storageConcMass: 10,
        storageConcVolume: 2,
        finalConcMass: 5,
      );
      final rxn = Reaction(
        ratioType: false,
        substrateMain: chem,
        reactionVolume: 4,
      );
      expect(rxn.reactionVolume, closeTo(4.0, 1e-12));
      expect(chem.storageConcVolume, closeTo(2.0, 1e-12));
    });

    test('throws when only one value is known', () {
      final chem = Chemical(
        unitCoefficient: 3,
        name: 'Test',
        storageConcMolar: 5,
        storageConcVolume: 2,
      );
      expect(
        () => Reaction(ratioType: true, substrateMain: chem),
        throwsArgumentError,
      );
    });

    test('works with molar ratio type', () {
      final chem = Chemical(
        unitCoefficient: 3,
        name: 'Test',
        storageConcMolar: 100,
        storageConcVolume: 1,
        finalConcMolar: 10,
      );
      final rxn = Reaction(
        ratioType: true,
        substrateMain: chem,
      );
      // d = 100 * 1 / 10 = 10
      expect(rxn.reactionVolume, closeTo(10.0, 1e-12));
    });

    test('defaults reaction_ratio to 1.0 if null', () {
      final chem = Chemical(
        unitCoefficient: 0,
        name: 'Test',
        storageConcMass: 10,
        storageConcVolume: 2,
        finalConcMass: 5,
      );
      final rxn = Reaction(
        ratioType: false,
        substrateMain: chem,
      );
      expect(rxn.reactionVolume, closeTo(4.0, 1e-12));
      expect(chem.reactionRatio, 1.0);
    });
  });
}
