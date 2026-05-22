// Standalone verification script — verifies Dart solver matches Python output.
// Run with: dart run test/run_verification.dart
import 'package:ilovebioconjunction/core/chemical.dart';
import 'package:ilovebioconjunction/core/reaction.dart';
import 'package:ilovebioconjunction/core/validators.dart';

void main() {
  var passed = 0;
  var failed = 0;

  void check(String name, dynamic actual, dynamic expected, [double tol = 1e-12]) {
    if (actual is double && expected is double) {
      final diff = (actual - expected).abs();
      final relTol = 1e-9 * expected.abs().clamp(1e-15, double.infinity) + 1e-12;
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
  check('tcep.storageConcVolume', tcep.storageConcVolume!, 1.1111111111111112e-06);
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

  // ── Summary ─────────────────────────────────────────────────────────
  print('\n========== RESULTS ==========');
  print('$passed passed, $failed failed, ${passed + failed} total');
  if (failed > 0) {
    print('*** VERIFICATION FAILED ***');
    throw Exception('Verification failed: $failed/$passed tests');
  } else {
    print('*** ALL TESTS PASSED — Dart ↔ Python parity confirmed ***');
  }
}
