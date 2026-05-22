import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjunction/core/chemical.dart';

void main() {
  group('Chemical construction', () {
    test('creates with molar storage concentration', () {
      final chem = Chemical(
        unitCoefficient: 3,
        name: 'Test',
        storageConcMolar: 10,
      );
      expect(chem.storageConcMolar, 10);
      expect(chem.storageConcMass, isNull);
    });

    test('creates with mass storage concentration', () {
      final chem = Chemical(
        unitCoefficient: 0,
        name: 'Test',
        storageConcMass: 5,
      );
      expect(chem.storageConcMass, 5);
      expect(chem.storageConcMolar, isNull);
    });

    test('throws if both molar and mass storage conc provided', () {
      expect(
        () => Chemical(
          unitCoefficient: 0,
          storageConcMolar: 1,
          storageConcMass: 1,
        ),
        throwsArgumentError,
      );
    });

    test('throws if neither storage conc provided', () {
      expect(
        () => Chemical(unitCoefficient: 0),
        throwsArgumentError,
      );
    });

    test('throws if both final conc types provided', () {
      expect(
        () => Chemical(
          unitCoefficient: 0,
          storageConcMass: 1,
          finalConcMolar: 1,
          finalConcMass: 1,
        ),
        throwsArgumentError,
      );
    });
  });

  group('Auto-derivation with molecular weight', () {
    test('derives storage molar from mass when MW provided', () {
      final chem = Chemical(
        unitCoefficient: 0,
        name: 'Goat IgG',
        storageConcMass: 10,
        molecularWeight: 150000,
      );
      // conc_mass2molar = (10 / 150000) * 1000 = 0.06666666666666667
      expect(
        chem.storageConcMolar,
        closeTo(0.06666666666666667, 1e-15),
      );
    });

    test('derives storage mass from molar when MW provided', () {
      final chem = Chemical(
        unitCoefficient: 3,
        name: 'Test',
        storageConcMolar: 0.06666666666666667,
        molecularWeight: 150000,
      );
      // conc_molar2mass = (0.066... * 150000) / 1000 = 10.0
      expect(chem.storageConcMass, closeTo(10.0, 1e-12));
    });

    test('derives final molar from mass when MW provided', () {
      final chem = Chemical(
        unitCoefficient: 0,
        name: 'Test',
        storageConcMass: 1,
        finalConcMass: 5,
        molecularWeight: 150000,
      );
      expect(
        chem.finalConcMolar,
        closeTo(0.03333333333333333, 1e-15),
      );
    });

    test('derives final mass from molar when MW provided', () {
      final chem = Chemical(
        unitCoefficient: 3,
        name: 'Test',
        storageConcMolar: 1,
        finalConcMolar: 0.03333333333333333,
        molecularWeight: 150000,
      );
      expect(chem.finalConcMass, closeTo(5.0, 1e-12));
    });
  });

  group('outputTest', () {
    test('re-derives missing final concentrations', () {
      final chem = Chemical(
        unitCoefficient: 0,
        name: 'Test',
        storageConcMass: 10,
        molecularWeight: 150000,
        finalConcMass: 5,
      );
      chem.finalConcMolar = null;
      chem.outputTest();
      expect(
        chem.finalConcMolar,
        closeTo(0.03333333333333333, 1e-15),
      );
    });

    test('re-derives missing storage concentrations', () {
      final chem = Chemical(
        unitCoefficient: 0,
        name: 'Test',
        storageConcMass: 10,
        molecularWeight: 150000,
      );
      chem.storageConcMolar = null;
      chem.outputTest();
      expect(
        chem.storageConcMolar,
        closeTo(0.06666666666666667, 1e-15),
      );
    });
  });

  group('getBasisConc / getBasisFinalConc', () {
    test('returns molar when ratioType=true', () {
      final chem = Chemical(
        unitCoefficient: 3,
        name: 'Test',
        storageConcMolar: 10,
        finalConcMolar: 5,
      );
      expect(chem.getBasisConc(true), 10);
      expect(chem.getBasisFinalConc(true), 5);
    });

    test('returns mass when ratioType=false', () {
      final chem = Chemical(
        unitCoefficient: 0,
        name: 'Test',
        storageConcMass: 10,
        finalConcMass: 5,
      );
      expect(chem.getBasisConc(false), 10);
      expect(chem.getBasisFinalConc(false), 5);
    });
  });
}
