import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/core/chemical.dart';
import 'package:ilovebioconjugation/core/reaction.dart';

Chemical mass({
  double? volume,
  double? finalConc,
  double? ratio,
  double stock = 10,
}) => Chemical(
  unitCoefficient: 0,
  storageConcMass: stock,
  storageConcVolume: volume,
  finalConcMass: finalConc,
  reactionRatio: ratio,
);

void main() {
  group('Single-reagent constraints', () {
    test(
      'checks fully supplied values rather than treating them as a no-op',
      () {
        expect(
          () => Reaction(
            ratioType: false,
            substrateMain: mass(volume: 2, finalConc: 6),
            reactionVolume: 4,
          ),
          throwsArgumentError,
        );
      },
    );
    test('preserves zero-dose dilution when total volume is positive', () {
      final chem = mass(finalConc: 0);
      final reaction = Reaction(
        ratioType: false,
        substrateMain: chem,
        reactionVolume: 4,
      );
      expect(chem.storageConcVolume, 0);
      expect(chem.finalConcMass, 0);
      expect(reaction.reactionVolume, 4);
    });
    test('zero dose cannot imply a zero reaction volume', () {
      expect(
        () => Reaction(
          ratioType: false,
          substrateMain: mass(volume: 0, finalConc: 1),
        ),
        throwsArgumentError,
      );
    });
    test('zero final concentration cannot consume a positive amount', () {
      expect(
        () => Reaction(
          ratioType: false,
          substrateMain: mass(volume: 1, finalConc: 0),
          reactionVolume: 4,
        ),
        throwsArgumentError,
      );
    });
    test('zero dose without total volume remains underdetermined', () {
      expect(
        () => Reaction(
          ratioType: false,
          substrateMain: mass(volume: 0, finalConc: 0),
        ),
        throwsArgumentError,
      );
    });
    test(
      'rejects overfill without altering supplied concentrations or volume',
      () {
        final chem = mass(finalConc: 20);
        expect(
          () => Reaction(
            ratioType: false,
            substrateMain: chem,
            reactionVolume: 1,
          ),
          throwsArgumentError,
        );
        expect(chem.storageConcVolume, isNull);
        expect(chem.finalConcMass, 20);
        expect(chem.reactionRatio, isNull);
      },
    );
    test('does not discard a final concentration in an unavailable basis', () {
      final chem = Chemical(
        unitCoefficient: 0,
        storageConcMass: 10,
        storageConcVolume: 1,
        finalConcMolar: 3,
      );
      expect(
        () =>
            Reaction(ratioType: false, substrateMain: chem, reactionVolume: 4),
        throwsArgumentError,
      );
      expect(chem.finalConcMolar, 3);
    });
    test(
      'supports genuinely tiny units but detects relative contradictions',
      () {
        final valid = mass(stock: 1e-9, volume: 1e-9, finalConc: 1e-10);
        final reaction = Reaction(
          ratioType: false,
          substrateMain: valid,
          reactionVolume: 1e-8,
        );
        expect(reaction.reactionVolume, 1e-8);
        expect(
          () => Reaction(
            ratioType: false,
            substrateMain: mass(stock: 1e-9, volume: 1e-9, finalConc: 2e-10),
            reactionVolume: 1e-8,
          ),
          throwsArgumentError,
        );
      },
    );
    test('rejects arithmetic overflow rather than returning infinity', () {
      expect(
        () => Reaction(
          ratioType: false,
          substrateMain: mass(stock: 1e308, volume: 2, finalConc: 1),
        ),
        throwsArgumentError,
      );
    });
    test('rejects arithmetic underflow rather than returning a false zero', () {
      expect(
        () => Reaction(
          ratioType: false,
          substrateMain: mass(stock: 1e-300, volume: 1e-300),
          reactionVolume: 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Multi-reagent completion and consistency', () {
    test('ratios without an amount/concentration anchor are insufficient', () {
      final main = mass();
      final secondary = mass(ratio: 2);
      expect(
        () => Reaction(
          ratioType: false,
          substrateMain: main,
          substrateSecondary: secondary,
          reactionVolume: 1,
        ),
        throwsArgumentError,
      );
      expect(main.storageConcVolume, isNull);
      expect(main.reactionRatio, isNull);
      expect(secondary.finalConcMass, isNull);
    });
    test('a complete main reagent cannot hide an unresolved secondary', () {
      final main = mass(volume: 1);
      final secondary = mass();
      expect(
        () => Reaction(
          ratioType: false,
          substrateMain: main,
          substrateSecondary: secondary,
          reactionVolume: 4,
        ),
        throwsArgumentError,
      );
      expect(main.finalConcMass, isNull);
    });
    test(
      'concentrations and ratios without an absolute amount remain insufficient',
      () {
        expect(
          () => Reaction(
            ratioType: false,
            substrateMain: mass(finalConc: 1),
            substrateSecondary: mass(finalConc: 2, ratio: 2),
          ),
          throwsArgumentError,
        );
      },
    );
    test('checks supplied ratios against independent stock amounts', () {
      expect(
        () => Reaction(
          ratioType: false,
          substrateMain: mass(volume: 1),
          substrateSecondary: mass(volume: 1, ratio: 2),
          reactionVolume: 4,
        ),
        throwsArgumentError,
      );
    });
    test('rejects contradictory supplied final concentrations', () {
      expect(
        () => Reaction(
          ratioType: false,
          substrateMain: mass(volume: 1, finalConc: 2),
          substrateSecondary: mass(ratio: 2),
          reactionVolume: 4,
        ),
        throwsArgumentError,
      );
    });
    test(
      'rejects multi-reagent overfill without publishing partial outputs',
      () {
        final main = mass(volume: 0.6);
        final secondary = mass(ratio: 1);
        expect(
          () => Reaction(
            ratioType: false,
            substrateMain: main,
            substrateSecondary: secondary,
            reactionVolume: 1,
          ),
          throwsArgumentError,
        );
        expect(main.finalConcMass, isNull);
        expect(secondary.storageConcVolume, isNull);
      },
    );
    test('accepts roundoff at the no-diluent boundary', () {
      final reaction = Reaction(
        ratioType: false,
        substrateMain: mass(volume: 0.1),
        substrateSecondary: mass(volume: 0.2),
        reactionVolume: 0.3,
      );
      expect(reaction.totalStockVolume, closeTo(0.3, 1e-15));
    });
    test('checks even sub-picomolar amount constraints', () {
      expect(
        () => Reaction(
          ratioType: true,
          substrateMain: Chemical(
            unitCoefficient: 0,
            storageConcMolar: 1e-15,
            storageConcVolume: 1e-15,
            reactionRatio: 1,
          ),
          substrateSecondary: Chemical(
            unitCoefficient: 0,
            storageConcMolar: 1e-15,
            storageConcVolume: 1e-15,
            reactionRatio: 2,
          ),
          reactionVolume: 1e-14,
        ),
        throwsArgumentError,
      );
    });
    test(
      'deriving a zero ratio fails consistently with input ratio validation',
      () {
        expect(
          () => Reaction(
            ratioType: false,
            substrateMain: mass(volume: 1),
            substrateSecondary: mass(volume: 0),
            reactionVolume: 4,
          ),
          throwsArgumentError,
        );
      },
    );
    test('rejects an underflowed positive stock amount', () {
      expect(
        () => Reaction(
          ratioType: false,
          substrateMain: mass(stock: 1e-300, volume: 1e-300),
          substrateSecondary: mass(ratio: 1),
          reactionVolume: 1,
        ),
        throwsArgumentError,
      );
    });
    test('rejects an underflowed secondary derived from a positive ratio', () {
      expect(
        () => Reaction(
          ratioType: false,
          substrateMain: mass(stock: 1e-200, volume: 1),
          substrateSecondary: mass(stock: 1, ratio: 1e-200),
          reactionVolume: 4,
        ),
        throwsArgumentError,
      );
    });
    test('retains a fully specified all-zero-dose mixture', () {
      final reaction = Reaction(
        ratioType: false,
        substrateMain: mass(volume: 0),
        substrateSecondary: mass(ratio: 2),
        reactionVolume: 4,
      );
      expect(reaction.totalStockVolume, 0);
      expect(reaction.substrateSecondary!.finalConcMass, 0);
    });
    test('rejects repeated mutable reagent instances', () {
      final main = mass(volume: 1);
      expect(
        () => Reaction(
          ratioType: false,
          substrateMain: main,
          substrateSecondary: main,
          reactionVolume: 4,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Domain validation', () {
    for (final invalid in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
      -1.0,
      0.0,
    ]) {
      test('rejects invalid positive-only inputs: $invalid', () {
        expect(() => mass(stock: invalid), throwsArgumentError);
        expect(() => mass(ratio: invalid), throwsArgumentError);
        expect(
          () => Chemical(
            unitCoefficient: 0,
            storageConcMass: 1,
            molecularWeight: invalid,
          ),
          throwsArgumentError,
        );
        expect(
          () => Reaction(
            ratioType: false,
            substrateMain: mass(volume: 1),
            reactionVolume: invalid,
          ),
          throwsArgumentError,
        );
      });
    }
    for (final invalid in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
      -1.0,
    ]) {
      test('rejects invalid volume/concentration: $invalid', () {
        expect(() => mass(volume: invalid), throwsArgumentError);
        expect(() => mass(finalConc: invalid), throwsArgumentError);
        expect(
          () => Chemical(
            unitCoefficient: 0,
            storageConcMass: 1,
            finalConcMolar: invalid,
          ),
          throwsArgumentError,
        );
      });
    }
    test('mutable fields are revalidated before solving', () {
      final chem = mass(volume: 1);
      chem.storageConcMass = double.nan;
      expect(
        () =>
            Reaction(ratioType: false, substrateMain: chem, reactionVolume: 4),
        throwsArgumentError,
      );
    });
  });
}
