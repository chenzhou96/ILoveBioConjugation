import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/data/calculation_input_snapshot.dart';

const _parent = SubstrateInputSnapshot(
  enabled: true,
  name: 'Label',
  mw: '500',
  mwUnit: 'Da',
  storageConc: '0010.00',
  storageUnit: 'mM',
  finalConc: '',
  finalUnit: 'uM',
  reactionRatio: '02.0',
  storageVolume: '',
  storageVolumeUnit: 'uL',
);
const _recipe = WorkingStockProvenance(
  slot: 1,
  parentInput: _parent,
  workingConcentration: '2.0',
  workingUnit: 'mM',
  dilutionFactor: 5,
  parentVolumeMl: .001,
  diluentVolumeMl: .004,
  preparationVolumeMl: .005,
  requiredVolumeMl: .002,
  newAliquotMl: .001,
  minimumVolumeMl: .001,
  diluentName: 'PBS',
);

void main() {
  CalculationInputSnapshot snapshot() => CalculationInputSnapshot(
    reactionVolume: '0100.00',
    reactionVolumeUnit: 'uL',
    ratioType: true,
    referenceSlot: 1,
    minimumPipettingVolumeUl: 2.5,
    substrates: [_parent, _parent],
    gradient: GradientInputSnapshot(
      selectedSlot: 1,
      unit: 'uM',
      points: ['0', '.20', 'draft'],
      replicates: 3,
      extraPreparationFraction: .1,
      workingStocks: [_recipe],
    ),
  );

  test(
    'v2 preserves exact request, reference, threshold and complete recipe',
    () {
      final source = snapshot();
      final restored = CalculationInputSnapshot.fromJson(
        jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>,
      );
      expect(restored.toJson(), source.toJson());
      expect(
        restored.gradient!.workingStocks.single.parentInput.storageConc,
        '0010.00',
      );
      expect(
        () => restored.gradient!.workingStocks.clear(),
        throwsUnsupportedError,
      );
    },
  );

  test('v1 gains safe defaults without changing scientific input strings', () {
    final old = {
      'version': 1,
      'reactionVolume': '0100.00',
      'reactionVolumeUnit': 'uL',
      'ratioType': true,
      'substrates': [_parent.toJson()],
    };
    final restored = CalculationInputSnapshot.fromJson(old);
    expect(restored.referenceSlot, 0);
    expect(restored.minimumPipettingVolumeUl, 1);
    expect(restored.workingStocks, isEmpty);
    expect(restored.gradient, isNull);
    expect(restored.substrates.single.toJson(), _parent.toJson());
  });

  test('corrupt reference and disabled metadata slots are rejected', () {
    final source = snapshot().toJson();
    for (final reference in [-1, 8, 1.5, '1']) {
      expect(
        () => CalculationInputSnapshot.fromJson({
          ...source,
          'referenceSlot': reference,
        }),
        throwsFormatException,
      );
    }
    expect(
      () => CalculationInputSnapshot.fromJson({
        ...source,
        'substrates': [
          _parent.toJson(),
          {..._parent.toJson(), 'enabled': false},
        ],
      }),
      throwsFormatException,
    );
    expect(
      () => CalculationInputSnapshot.fromJson({
        ...source,
        'workingStocks': [
          {..._recipe.toJson(), 'slot': 3},
        ],
      }),
      throwsFormatException,
    );
  });

  test(
    'recipe rejects nonfinite, nonpositive and nonconserving preparation values',
    () {
      for (final changed in <Map<String, Object>>[
        {'workingConcentration': '0'},
        {'workingConcentration': 'NaN'},
        {'workingConcentration': 'draft'},
        {'workingConcentration': '3'},
        {'dilutionFactor': .5},
        {'dilutionFactor': 6},
        {'parentVolumeMl': double.infinity},
        {'diluentVolumeMl': -.001},
        {'preparationVolumeMl': .006},
        {'requiredVolumeMl': .006},
        {'newAliquotMl': .003},
        {'minimumVolumeMl': 0},
        {'diluentName': ' '},
      ]) {
        expect(
          () => WorkingStockProvenance.fromJson({
            ..._recipe.toJson(),
            ...changed,
          }),
          throwsFormatException,
          reason: '$changed',
        );
      }
    },
  );

  test('duplicate same-stock serial dilution metadata is rejected', () {
    final source = snapshot().toJson();
    expect(
      () => CalculationInputSnapshot.fromJson({
        ...source,
        'workingStocks': [_recipe.toJson(), _recipe.toJson()],
      }),
      throwsFormatException,
    );
    expect(
      () => GradientInputSnapshot.fromJson({
        ...snapshot().gradient!.toJson(),
        'workingStocks': [_recipe.toJson(), _recipe.toJson()],
      }),
      throwsFormatException,
    );
  });

  test('batch metadata validates units, slots, counts and extra fraction', () {
    for (final changed in <Map<String, Object>>[
      {'selectedSlot': 0},
      {'selectedSlot': 4},
      {'proteinSlot': 1},
      {'unit': 'unknown'},
      {'replicates': 0},
      {'replicates': 1.5},
      {'extraPreparationFraction': -.1},
      {'extraPreparationFraction': double.infinity},
      {
        'points': [1, 2],
      },
      {'workingStocks': 'invalid'},
    ]) {
      expect(
        () => GradientInputSnapshot.fromJson({
          ...snapshot().gradient!.toJson(),
          ...changed,
        }),
        throwsFormatException,
        reason: '$changed',
      );
    }
  });
  test(
    'inactive ordinary recipe is archival but its slot and current stock must match',
    () {
      final source = snapshot().toJson();
      final good = {
        ...source,
        'referenceSlot': 0,
        'substrates': [
          _parent.toJson(),
          {..._parent.toJson(), 'enabled': false, 'storageConc': '2.0'},
        ],
        'workingStocks': [_recipe.toJson()],
      };
      good.remove('gradient');
      final restored = CalculationInputSnapshot.fromJson(good);
      expect(restored.workingStocks, hasLength(1));
      expect(restored.substrates[1].enabled, isFalse);
      expect(
        () => CalculationInputSnapshot.fromJson({
          ...good,
          'substrates': [
            _parent.toJson(),
            {..._parent.toJson(), 'enabled': false, 'storageConc': '3.0'},
          ],
        }),
        throwsFormatException,
      );
    },
  );
}
