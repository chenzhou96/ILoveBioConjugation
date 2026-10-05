import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/core/unit_converter.dart';
import 'package:ilovebioconjugation/core/validators.dart';

void main() {
  group('Finite number parsing', () {
    for (final text in ['', ' ', '\n\t']) {
      test('blank ${text.length} characters is absent', () {
        expect(parseFloatOrNull(text), isNull);
      });
    }
    test('decimal, sign and scientific notation', () {
      expect(parseFloatOrNull(' 1.25e-9 '), 1.25e-9);
      expect(parseFloatOrNull('-3.5'), -3.5);
      expect(parseFloatOrNull('0'), 0);
    });
    test('nonzero significands must not silently underflow to zero', () {
      for (final text in ['1e-999', '-1e-999', '2e-324', ' 0.001e-999 ']) {
        expect(() => parseFloatOrNull(text), throwsArgumentError);
      }
      for (final text in ['0e-999', '-0.000e-999', '+0.0e999']) {
        expect(parseFloatOrNull(text), 0);
      }
      expect(parseFloatOrNull('5e-324'), double.minPositive);
    });
    for (final text in [
      'NaN',
      'Infinity',
      '-Infinity',
      '1e999',
      'abc',
      '1,2',
    ]) {
      test('rejects $text', () {
        expect(() => parseFloatOrNull(text), throwsArgumentError);
      });
    }
  });

  group('Unit conversions use independently specified SI factors', () {
    const volumes = {
      'L': 1000.0,
      'mL': 1.0,
      'uL': 1e-3,
      'nL': 1e-6,
      'pL': 1e-9,
    };
    const concentrations = {
      'M': 1000.0,
      'mM': 1.0,
      'uM': 1e-3,
      'nM': 1e-6,
      'pM': 1e-9,
      'g/mL': 1000.0,
      'mg/mL': 1.0,
      'ug/mL': 1e-3,
      'ng/mL': 1e-6,
      'pg/mL': 1e-9,
    };
    for (final entry in volumes.entries) {
      test('${entry.key} to mL', () {
        expect(
          convertVolumeToMl(2.5, entry.key),
          closeTo(2.5 * entry.value, entry.value * 1e-12),
        );
        expect(
          math.pow(10, UnitConverter.volumeUnits[entry.key]!),
          entry.value,
        );
      });
    }
    for (final entry in concentrations.entries) {
      test('${entry.key} to concentration base', () {
        expect(
          convertConcentrationToBaseUnit(2.5, entry.key),
          closeTo(2.5 * entry.value, entry.value * 1e-12),
        );
      });
    }
    test('molecular weight conversion', () {
      expect(convertMwToDa(150, 'kDa'), 150000);
      expect(convertMwToDa(150000, 'Da'), 150000);
    });
    test('mass exponent table is relative to mg', () {
      expect(UnitConverter.massUnits, {
        'kg': 6,
        'g': 3,
        'mg': 0,
        'ug': -3,
        'ng': -6,
        'pg': -9,
      });
    });
    test('unit categories use exact supported units', () {
      expect(isMolarUnit('mM'), isTrue);
      expect(isMassUnit('mg/mL'), isTrue);
      for (final unit in ['', 'MM', 'mol/L', 'bogusM', 'x/y']) {
        expect(isMolarUnit(unit), isFalse);
        expect(isMassUnit(unit), isFalse);
      }
    });
  });

  group('Invalid conversions fail rather than silently preserving values', () {
    test('unsupported and case-mismatched units', () {
      expect(() => convertVolumeToMl(1, 'ml'), throwsArgumentError);
      expect(() => convertMwToDa(1, 'kg'), throwsArgumentError);
      expect(
        () => convertConcentrationToBaseUnit(1, 'mol/L'),
        throwsArgumentError,
      );
    });
    for (final value in [
      double.nan,
      double.infinity,
      double.negativeInfinity,
      -1.0,
    ]) {
      test('rejects $value in every conversion', () {
        expect(() => convertVolumeToMl(value, 'mL'), throwsArgumentError);
        expect(() => convertMwToDa(value, 'Da'), throwsArgumentError);
        expect(
          () => convertConcentrationToBaseUnit(value, 'mM'),
          throwsArgumentError,
        );
      });
    }
    test('zero is valid for dose/volume, but never for molecular weight', () {
      expect(convertVolumeToMl(0, 'mL'), 0);
      expect(convertConcentrationToBaseUnit(0, 'mM'), 0);
      expect(() => convertMwToDa(0, 'Da'), throwsArgumentError);
    });
    test('rejects finite inputs whose conversion overflows or underflows', () {
      expect(() => convertVolumeToMl(1e308, 'L'), throwsArgumentError);
      expect(
        () => convertConcentrationToBaseUnit(1e308, 'M'),
        throwsArgumentError,
      );
      expect(() => convertMwToDa(1e308, 'kDa'), throwsArgumentError);
      expect(() => convertVolumeToMl(5e-324, 'pL'), throwsArgumentError);
    });
  });
}
