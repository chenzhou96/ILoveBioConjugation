import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/ui/planning/planning_format.dart';

void main() {
  test('gradient concentration displays preserve dilute mass precision', () {
    // 1 µM TCEP × 286.65 g/mol = 286.65 ng/mL.
    expect(planningConcentration(0.001), '1 µM');
    expect(planningConcentration(0.00028665, molar: false), '286.65 ng/mL');
    expect(planningConcentration(0.0028665, molar: false), '2.8665 µg/mL');
    expect(planningConcentration(2.8665, molar: false), '2.8665 mg/mL');
  });
  test('concentrations scale to nano and pico without rounding to zero', () {
    expect(planningConcentration(0.000001), '1 nM');
    expect(planningConcentration(0.000000001), '1 pM');
    expect(
      planningConcentration(0.00000000028665, molar: false),
      '0.28665 pg/mL',
    );
    expect(planningConcentration(null), '无法换算（缺少分子量）');
    expect(planningConcentration(null, molar: false), '无法换算（缺少分子量）');
    expect(planningConcentration(0, molar: false), '0 mg/mL');
  });
}
