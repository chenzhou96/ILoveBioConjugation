// Standalone CLI verification intentionally writes diagnostics to stdout.
// ignore_for_file: avoid_print

// Standalone reference and independent regression verification.
// Run with: dart run test/run_verification.dart
import 'dart:math' as math;

import 'package:ilovebioconjugation/core/chemical.dart';
import 'package:ilovebioconjugation/core/reaction.dart';
import 'package:ilovebioconjugation/core/validators.dart';
import 'package:ilovebioconjugation/core/unit_converter.dart';

void main() {
  var passed = 0;
  var failed = 0;

  void check(
    String name,
    dynamic actual,
    dynamic expected, [
    double tol = 1e-12,
  ]) {
    if (actual is double && expected is double) {
      final diff = (actual - expected).abs();
      final relTol = 1e-9 * expected.abs() + tol;
      if (diff <= relTol) {
        passed++;
      } else {
        failed++;
        print('FAIL $name: actual=$actual expected=$expected diff=$diff');
      }
    } else if (actual == expected) {
      passed++;
    } else {
      failed++;
      print('FAIL $name: actual=$actual expected=$expected');
    }
  }

  print('=== Reference Case: Goat IgG + TCEP (Python parity) ===');

  final main = Chemical(
    unitCoefficient: 0,
    name: 'Goat IgG',
    storageConcMass: 10,
    molecularWeight: 150000,
    finalConcMass: 5,
    reactionRatio: 1,
  );

  final tcep = Chemical(
    unitCoefficient: 3,
    name: 'TCEP',
    storageConcMolar: 6000,
    reactionRatio: 10,
  );

  final rxn = Reaction(
    ratioType: true,
    substrateMain: main,
    substratesSecondary: [tcep],
    reactionVolume: 0.02,
  );

  check('reaction_volume', rxn.reactionVolume!, 0.02);
  check('total_stock', rxn.totalStockVolume, 0.010001111111111112);
  check('main.storageConcMolar', main.storageConcMolar!, 0.06666666666666667);
  check('main.storageConcMass', main.storageConcMass!, 10.0);
  check('main.finalConcMolar', main.finalConcMolar!, 0.03333333333333333);
  check('main.finalConcMass', main.finalConcMass!, 5.0);
  check('main.storageConcVolume', main.storageConcVolume!, 0.01);
  check('main.reactionRatio', main.reactionRatio!, 1.0);
  check('tcep.storageConcMolar', tcep.storageConcMolar!, 6000.0);
  check('tcep.finalConcMolar', tcep.finalConcMolar!, 0.3333333333333333);
  check(
    'tcep.storageConcVolume',
    tcep.storageConcVolume!,
    1.1111111111111112e-06,
  );
  check('tcep.reactionRatio', tcep.reactionRatio!, 10.0);

  // ── Single substrate tests ──────────────────────────────────────────
  print('\n=== Single Substrate Tests ===');

  // Case 1: solve for d
  final s1 = Chemical(
    unitCoefficient: 0,
    name: 'S1',
    storageConcMass: 10,
    storageConcVolume: 2,
    finalConcMass: 5,
  );
  Reaction(ratioType: false, substrateMain: s1);
  check('single_solve_d', s1.finalConcMass!, 5.0, 1e-12);
  // d = s*a/b = 10*2/5 = 4

  // Case 2: solve for a
  final s2 = Chemical(
    unitCoefficient: 0,
    name: 'S2',
    storageConcMass: 10,
    finalConcMass: 5,
  );
  Reaction(ratioType: false, substrateMain: s2, reactionVolume: 4);
  check('single_solve_a', s2.storageConcVolume!, 2.0, 1e-12);

  // Case 3: solve for b
  final s3 = Chemical(
    unitCoefficient: 0,
    name: 'S3',
    storageConcMass: 10,
    storageConcVolume: 2,
  );
  Reaction(ratioType: false, substrateMain: s3, reactionVolume: 4);
  check('single_solve_b', s3.finalConcMass!, 5.0, 1e-12);

  // ── Unit conversion tests ───────────────────────────────────────────
  print('\n=== Unit Conversion Tests ===');

  check('volume_L_to_mL', convertVolumeToMl(1, 'L'), 1000.0);
  check('volume_uL_to_mL', convertVolumeToMl(1, 'uL'), 0.001);
  check('volume_mL_to_mL', convertVolumeToMl(1, 'mL'), 1.0);

  check('mw_kDa_to_Da', convertMwToDa(150, 'kDa'), 150000.0);
  check('mw_Da_unchanged', convertMwToDa(150000, 'Da'), 150000.0);

  check('conc_M_to_mM', convertConcentrationToBaseUnit(1, 'M'), 1000.0);
  check('conc_mM_unchanged', convertConcentrationToBaseUnit(1, 'mM'), 1.0);
  check('conc_mg_unchanged', convertConcentrationToBaseUnit(1, 'mg/mL'), 1.0);

  check('parseFloat_valid', parseFloatOrNull('3.14'), 3.14);
  check('parseFloat_empty', parseFloatOrNull(''), null);
  check('parseFloat_whitespace', parseFloatOrNull('  '), null);

  try {
    parseFloatOrNull('abc');
    failed++;
    print('FAIL parseFloat_invalid: should have thrown');
  } catch (_) {
    passed++;
  }

  void rejects(String name, void Function() action) {
    try {
      action();
      failed++;
      print('FAIL $name: expected ArgumentError');
    } on ArgumentError {
      passed++;
    } catch (error) {
      failed++;
      print('FAIL $name: unexpected error $error');
    }
  }

  print('\n=== Invalid-input and constraint regressions ===');
  for (final text in ['NaN', 'Infinity', '-Infinity', '1e999']) {
    rejects('parse_$text', () => parseFloatOrNull(text));
  }
  rejects('unknown_volume_unit', () => convertVolumeToMl(1, 'ml'));
  rejects(
    'unknown_concentration_unit',
    () => convertConcentrationToBaseUnit(1, 'xM'),
  );
  rejects('unknown_mw_unit', () => convertMwToDa(1, 'g'));
  rejects('zero_mw', () => convertMwToDa(0, 'Da'));
  rejects('conversion_overflow', () => convertVolumeToMl(1e308, 'L'));
  rejects(
    'single_contradiction',
    () => Reaction(
      ratioType: false,
      substrateMain: Chemical(
        unitCoefficient: 0,
        storageConcMass: 10,
        storageConcVolume: 2,
        finalConcMass: 6,
      ),
      reactionVolume: 4,
    ),
  );
  rejects(
    'multi_unresolved',
    () => Reaction(
      ratioType: false,
      substrateMain: Chemical(unitCoefficient: 0, storageConcMass: 10),
      substrateSecondary: Chemical(
        unitCoefficient: 0,
        storageConcMass: 10,
        reactionRatio: 2,
      ),
      reactionVolume: 4,
    ),
  );
  rejects(
    'overfill',
    () => Reaction(
      ratioType: false,
      substrateMain: Chemical(
        unitCoefficient: 0,
        storageConcMass: 10,
        finalConcMass: 20,
      ),
      reactionVolume: 4,
    ),
  );
  rejects(
    'ignored_opposite_basis',
    () => Reaction(
      ratioType: false,
      substrateMain: Chemical(
        unitCoefficient: 0,
        storageConcMass: 10,
        storageConcVolume: 1,
        finalConcMolar: 2,
      ),
      reactionVolume: 4,
    ),
  );
  rejects(
    'tiny_ratio_contradiction',
    () => Reaction(
      ratioType: true,
      substrateMain: Chemical(
        unitCoefficient: 0,
        storageConcMolar: 1e-15,
        storageConcVolume: 1e-15,
      ),
      substrateSecondary: Chemical(
        unitCoefficient: 0,
        storageConcMolar: 1e-15,
        storageConcVolume: 1e-15,
        reactionRatio: 2,
      ),
      reactionVolume: 1e-14,
    ),
  );
  rejects(
    'multi_positive_product_underflow',
    () => Reaction(
      ratioType: false,
      substrateMain: Chemical(
        unitCoefficient: 0,
        storageConcMass: 1e-300,
        storageConcVolume: 1e-300,
      ),
      substrateSecondary: Chemical(
        unitCoefficient: 0,
        storageConcMass: 1,
        reactionRatio: 1,
      ),
      reactionVolume: 1,
    ),
  );
  rejects(
    'multi_positive_ratio_underflow',
    () => Reaction(
      ratioType: false,
      substrateMain: Chemical(
        unitCoefficient: 0,
        storageConcMass: 1e-200,
        storageConcVolume: 1,
      ),
      substrateSecondary: Chemical(
        unitCoefficient: 0,
        storageConcMass: 1,
        reactionRatio: 1e-200,
      ),
      reactionVolume: 4,
    ),
  );
  check('ng_to_mg_exponent', UnitConverter.massUnits['ng'], -6);
  check('pg_to_mg_exponent', UnitConverter.massUnits['pg'], -9);
  final refresh = Chemical(
    unitCoefficient: 0,
    storageConcMass: 10,
    molecularWeight: 150000,
    finalConcMass: 5,
  );
  refresh.setBasisFinalConc(true, 0.01);
  check('refreshed_mass_basis', refresh.finalConcMass, 1.5);
  refresh.setBasisFinalConc(false, null);
  check('cleared_molar_basis', refresh.finalConcMolar, null);

  print('\n=== 400 seeded independent analytical mixtures ===');
  final random = math.Random(20261002);
  for (var trial = 0; trial < 400; trial++) {
    final molar = trial.isEven;
    final count = 1 + trial % 4;
    final volume = math.pow(10, -9 + random.nextInt(16)).toDouble();
    final stock = List.generate(
      count,
      (_) => math.pow(10, -9 + random.nextInt(16)).toDouble(),
    );
    // Specify physical stock volumes first, so no expected result is produced
    // by a second implementation of the iterative solver.
    final stockVolumes = List.generate(
      count,
      (_) => volume * (0.01 + random.nextDouble() * 0.1),
    );
    final amounts = List.generate(count, (i) => stock[i] * stockVolumes[i]);
    final ratios = List.generate(count, (i) => amounts[i] / amounts[0]);
    final expectedFinals = List.generate(count, (i) => amounts[i] / volume);
    final chemicals = List.generate(
      count,
      (i) => Chemical(
        unitCoefficient: 0,
        storageConcMolar: molar ? stock[i] : null,
        storageConcMass: molar ? null : stock[i],
        storageConcVolume: i == count - 1 ? stockVolumes[i] : null,
        reactionRatio: ratios[i],
      ),
    );
    final reaction = Reaction(
      ratioType: molar,
      substrateMain: chemicals.first,
      substratesSecondary: chemicals.skip(1).toList(),
      reactionVolume: volume,
    );
    check('trial_$trial.total_volume', reaction.reactionVolume, volume, 0);
    for (var i = 0; i < count; i++) {
      check(
        'trial_$trial.reagent_$i.volume',
        chemicals[i].storageConcVolume,
        stockVolumes[i],
        0,
      );
      check(
        'trial_$trial.reagent_$i.final',
        chemicals[i].getBasisFinalConc(molar),
        expectedFinals[i],
        0,
      );
      check(
        'trial_$trial.reagent_$i.amount',
        chemicals[i].getBasisFinalConc(molar)! * reaction.reactionVolume!,
        amounts[i],
        0,
      );
    }
  }

  // ── Summary ─────────────────────────────────────────────────────────
  print('\n========== RESULTS ==========');
  print('$passed passed, $failed failed, ${passed + failed} total');
  if (failed > 0) {
    print('*** VERIFICATION FAILED ***');
    throw Exception('Verification failed: $failed/${passed + failed} tests');
  } else {
    print('*** ALL REFERENCE AND INDEPENDENT CHECKS PASSED ***');
  }
}
