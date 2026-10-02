import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/core/chemical.dart';
import 'package:ilovebioconjugation/core/reaction.dart';

// An independent analytic oracle: choose concentrations and aliquots first,
// calculate amounts = concentration * volume, then hide different inputs.
// The expected values do not call the solver or the legacy Python port.
void expectRelative(double? actual, double expected, String label) {
  expect(actual, isNotNull, reason: label);
  expect(actual!.isFinite, isTrue, reason: label);
  expect(
    (actual - expected).abs() / expected.abs(),
    lessThan(1e-8),
    reason: '$label: $actual != $expected',
  );
}

Chemical reagent({
  required bool molar,
  required String name,
  required double stock,
  double? volume,
  double? finalConc,
  double? ratio,
}) => Chemical(
  unitCoefficient: molar ? 3 : 0,
  name: name,
  storageConcMolar: molar ? stock : null,
  storageConcMass: molar ? null : stock,
  storageConcVolume: volume,
  finalConcMolar: molar ? finalConc : null,
  finalConcMass: molar ? null : finalConc,
  reactionRatio: ratio,
);

void main() {
  for (final molar in [false, true]) {
    test('analytic single-reagent oracle (${molar ? 'molar' : 'mass'})', () {
      final random = math.Random(20819);
      for (var sample = 0; sample < 150; sample++) {
        final stock = math.pow(10, random.nextDouble() * 12 - 9).toDouble();
        final total = math.pow(10, random.nextDouble() * 12 - 9).toDouble();
        final aliquot = total * (0.01 + random.nextDouble() * 0.85);
        final target = stock * aliquot / total;
        for (var hidden = 0; hidden < 3; hidden++) {
          final chemical = reagent(
            molar: molar,
            name: 'single',
            stock: stock,
            volume: hidden == 0 ? null : aliquot,
            finalConc: hidden == 1 ? null : target,
          );
          final reaction = Reaction(
            ratioType: molar,
            substrateMain: chemical,
            reactionVolume: hidden == 2 ? null : total,
          );
          final label = 'sample $sample hidden $hidden';
          expectRelative(reaction.reactionVolume, total, '$label total');
          expectRelative(chemical.storageConcVolume, aliquot, '$label aliquot');
          expectRelative(
            chemical.getBasisFinalConc(molar),
            target,
            '$label final',
          );
        }
      }
    });

    test('analytic 2–4 reagent oracle (${molar ? 'molar' : 'mass'})', () {
      final random = math.Random(60217);
      for (var sample = 0; sample < 150; sample++) {
        final count = 2 + sample % 3;
        final total = math.pow(10, random.nextDouble() * 12 - 9).toDouble();
        final stocks = List.generate(
          count,
          (_) => math.pow(10, random.nextDouble() * 12 - 9).toDouble(),
        );
        final volumes = List.generate(
          count,
          (_) => total * (0.02 + random.nextDouble() * 0.15),
        );
        final amounts = List.generate(count, (i) => stocks[i] * volumes[i]);
        final finals = List.generate(count, (i) => amounts[i] / total);
        final ratios = List.generate(count, (i) => amounts[i] / amounts[0]);
        for (var mode = 0; mode < 4; mode++) {
          final chemicals = List.generate(
            count,
            (i) => reagent(
              molar: molar,
              name: 'reagent $i',
              stock: stocks[i],
              // Modes: all aliquots; all final concentrations; main anchor +
              // ratios; secondary anchor + ratios (backward propagation).
              volume:
                  mode == 0 ||
                      (mode == 2 && i == 0) ||
                      (mode == 3 && i == count - 1)
                  ? volumes[i]
                  : null,
              finalConc: mode == 1 ? finals[i] : null,
              ratio: mode >= 2 ? ratios[i] : null,
            ),
          );
          final reaction = Reaction(
            ratioType: molar,
            substrateMain: chemicals[0],
            substratesSecondary: chemicals.skip(1).toList(),
            reactionVolume: total,
          );
          final label = 'sample $sample mode $mode';
          expectRelative(reaction.reactionVolume, total, '$label total');
          expectRelative(
            reaction.totalStockVolume,
            volumes.reduce((a, b) => a + b),
            '$label stock sum',
          );
          expect(reaction.totalStockVolume, lessThan(total));
          for (var i = 0; i < count; i++) {
            expectRelative(
              chemicals[i].storageConcVolume,
              volumes[i],
              '$label reagent $i volume',
            );
            expectRelative(
              chemicals[i].getBasisFinalConc(molar),
              finals[i],
              '$label reagent $i final',
            );
            expectRelative(
              chemicals[i].reactionRatio,
              ratios[i],
              '$label reagent $i ratio',
            );
          }
        }
      }
    });
  }
}
