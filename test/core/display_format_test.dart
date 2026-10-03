import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/core/display_format.dart';

void main() {
  test(
    'all displayed decimals use three places without losing tiny values',
    () {
      expect(displayNumber(66.6666666667), '66.667');
      expect(displayNumber(1), '1.000');
      expect(displayNumber(-0.0), '0.000');
      expect(displayNumber(1e-9), '1.000e-9');
      expect(displayNumber(1e22), '1.000e+22');
      expect(displayNumber(2.8664999999999994), '2.867');
      expect(displayNumber(-2.8665), '-2.867');
      expect(displayNumber(2.86649), '2.866');
      expect(() => displayNumber(double.nan), throwsArgumentError);
    },
  );

  test('volume promotes at 1000 and at the rounded boundary', () {
    expect(displayInputValue('1000', 'nL'), '1.000 µL');
    expect(displayInputValue('1000', 'uL'), '1.000 mL');
    expect(displayInputValue('1000', 'mL'), '1.000 L');
    expect(displayInputValue('999.9999', 'nL'), '1.000 µL');
    expect(displayInputValue('999.999', 'nL'), '999.999 nL');
    expect(displayVolume(0), '0.000 µL');
    expect(displayVolume(1e-13), '1.000e-4 pL');
  });

  test('concentrations scale before rounding and preserve zero vs missing', () {
    expect(displayMass(0.00028665), '286.650 ng/mL');
    expect(displayMolar(0.001), '1.000 µM');
    expect(displayMass(2.8665), '2.867 mg/mL');
    expect(displayMass(0), '0.000 mg/mL');
    expect(displayMolar(null), '无法换算（缺少分子量）');
    expect(displayMolar(1e-13), '1.000e-4 pM');
  });

  test('legacy history derives only missing concentration bases from Da', () {
    final fromMass = concentrationPair(mass: 10, molecularWeightDa: 150000);
    expect(fromMass.molar, closeTo(0.06666666666666667, 1e-16));
    expect(fromMass.mass, 10);
    final fromMolar = concentrationPair(molar: 0.1, molecularWeightDa: 389.38);
    expect(fromMolar.mass, closeTo(0.038938, 1e-16));
    expect(concentrationPair(mass: 10).molar, isNull);
    expect(concentrationPair(molar: 0, molecularWeightDa: 1000).mass, 0);
    expect(
      concentrationPair(mass: 1, molar: 2, molecularWeightDa: 1000).molar,
      2,
    );
  });

  test('working-stock strings convert with their original units', () {
    final stock = concentrationInputPair(
      '10',
      'mg/mL',
      molecularWeight: '150',
      mwUnit: 'kDa',
    );
    expect(displayMass(stock.mass), '10.000 mg/mL');
    expect(displayMolar(stock.molar), '66.667 µM');
    final dilute = concentrationInputPair(
      '25.644205',
      'µM',
      molecularWeight: '389.38',
    );
    expect(displayMass(dilute.mass), '9.985 µg/mL');
  });
}
