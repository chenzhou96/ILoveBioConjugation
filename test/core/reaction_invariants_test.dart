import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/core/chemical.dart';
import 'package:ilovebioconjugation/core/reaction.dart';

// Analytical cases built from conserved amounts, not from a reference solver.
// Test all supported reagent counts/bases, independent anchors and SI scales.
void main() {
  for (final molar in [false, true]) {
    for (var count = 1; count <= 4; count++) {
      for (var mode = 0; mode < 9; mode++) {
        if (count == 1 && (mode == 5 || mode == 8)) continue;
        for (final scale in [1e-9, 1e-6, 0.001, 1.0, 1000.0, 1e6]) {
          test(
            '${molar ? 'molar' : 'mass'}: $count reagents, anchor $mode, scale $scale',
            () {
              final nominalVolume = scale * 0.1;
              final stock = List.generate(count, (i) => scale * (i + 1) * 10);
              const ratios = [2.0, 3.0, 0.5, 4.0];
              final mainAmount = stock[0] * nominalVolume / 100;
              final amounts = List.generate(
                count,
                (i) => mainAmount * ratios[i] / ratios[0],
              );
              final volumes = List.generate(
                count,
                (i) => amounts[i] / stock[i],
              );
              final totalStock = volumes.fold(
                0.0,
                (sum, volume) => sum + volume,
              );
              final expectedVolume = mode == 5 || mode == 8
                  ? totalStock
                  : nominalVolume;
              final finals = List.generate(
                count,
                (i) => amounts[i] / expectedVolume,
              );
              final chemicals = List.generate(count, (i) {
                final mw = (i + 1) * 25000.0;
                // Alternate source units to exercise both MW conversion directions.
                final massInput = i.isOdd ? molar : !molar;
                final inputStock = massInput == !molar
                    ? stock[i]
                    : molar
                    ? stock[i] * mw / 1000
                    : stock[i] * 1000 / mw;
                final knownVolume = switch (mode) {
                  0 || 6 || 8 => i == 0 ? volumes[i] : null,
                  2 => i == count - 1 ? volumes[i] : null,
                  3 || 4 || 5 => volumes[i],
                  _ => null,
                };
                final basisFinal = switch (mode) {
                  1 || 4 || 6 => i == 0 ? finals[i] : null,
                  7 => finals[i],
                  _ => null,
                };
                final inputFinal = basisFinal == null
                    ? null
                    : massInput == !molar
                    ? basisFinal
                    : molar
                    ? basisFinal * mw / 1000
                    : basisFinal * 1000 / mw;
                return Chemical(
                  unitCoefficient: 0,
                  name: 'Reagent $i',
                  molecularWeight: mw,
                  storageConcMass: massInput ? inputStock : null,
                  storageConcMolar: massInput ? null : inputStock,
                  storageConcVolume: knownVolume,
                  finalConcMass: massInput ? inputFinal : null,
                  finalConcMolar: massInput ? null : inputFinal,
                  reactionRatio: i == 0 || ![3, 4, 5, 7].contains(mode)
                      ? ratios[i]
                      : null,
                );
              });
              final reaction = Reaction(
                ratioType: molar,
                substrateMain: chemicals.first,
                substratesSecondary: chemicals.skip(1).toList(),
                reactionVolume: [4, 5, 6, 8].contains(mode)
                    ? null
                    : nominalVolume,
              );
              void close(double? actual, double expected) {
                expect(actual, isNotNull);
                expect(actual!.isFinite, isTrue);
                expect(actual, closeTo(expected, expected.abs() * 1e-9));
              }

              close(reaction.reactionVolume, expectedVolume);
              close(reaction.totalStockVolume, totalStock);
              for (var i = 0; i < count; i++) {
                final chem = chemicals[i];
                close(chem.storageConcVolume, volumes[i]);
                close(chem.getBasisFinalConc(molar), finals[i]);
                close(chem.reactionRatio, ratios[i]);
                close(
                  chem.getBasisConc(molar)! * chem.storageConcVolume!,
                  amounts[i],
                );
                close(
                  chem.getBasisFinalConc(molar)! * reaction.reactionVolume!,
                  amounts[i],
                );
                close(
                  chem.finalConcMolar! * chem.molecularWeight! / 1000,
                  chem.finalConcMass!,
                );
              }
            },
          );
        }
      }
    }
  }
}
