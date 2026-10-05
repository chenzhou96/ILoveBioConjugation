import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/data/calculation_input_snapshot.dart';

void main() {
  const substrate = SubstrateInputSnapshot(
    enabled: true,
    name: '  exact name  ',
    mw: '50.000',
    mwUnit: 'kDa',
    storageConc: '001.20e-9',
    storageUnit: 'pM',
    finalConc: '',
    finalUnit: 'nM',
    reactionRatio: '1.000',
    storageVolume: '.00100',
    storageVolumeUnit: 'pL',
  );

  test('JSON preserves original strings, not only their numerical values', () {
    final source = CalculationInputSnapshot(
      reactionVolume: '001e-3',
      reactionVolumeUnit: 'nL',
      ratioType: true,
      substrates: [substrate],
    );
    final restored = CalculationInputSnapshot.fromJson(
      jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>,
    );
    expect(restored.toJson(), source.toJson());
  });

  test('snapshot copies and freezes the source list', () {
    final source = [substrate];
    final snapshot = CalculationInputSnapshot(
      reactionVolume: '',
      reactionVolumeUnit: 'uL',
      ratioType: false,
      substrates: source,
    );
    source.clear();
    expect(snapshot.substrates, [substrate]);
    expect(() => snapshot.substrates.clear(), throwsUnsupportedError);
  });

  test('unknown versions and incomplete snapshots are rejected', () {
    for (final json in <Map<String, dynamic>>[
      {},
      {'version': 99},
      {
        'version': 1,
        'reactionVolume': '',
        'reactionVolumeUnit': 'uL',
        'ratioType': true,
        'substrates': [],
      },
      {
        'version': 1,
        'reactionVolume': '',
        'reactionVolumeUnit': 'uL',
        'ratioType': true,
        'substrates': [
          {'enabled': true},
        ],
      },
    ]) {
      expect(
        () => CalculationInputSnapshot.fromJson(json),
        throwsFormatException,
      );
    }
  });
  test(
    'unsupported units are rejected without rejecting raw numeric drafts',
    () {
      final source = CalculationInputSnapshot(
        reactionVolume: 'unfinished draft',
        reactionVolumeUnit: 'nL',
        ratioType: true,
        substrates: [substrate],
      ).toJson();
      expect(
        () => CalculationInputSnapshot.fromJson({
          ...source,
          'reactionVolumeUnit': 'bucket',
        }),
        throwsFormatException,
      );
      for (final field in [
        'mwUnit',
        'storageUnit',
        'finalUnit',
        'storageVolumeUnit',
      ]) {
        expect(
          () => CalculationInputSnapshot.fromJson({
            ...source,
            'substrates': [
              {...substrate.toJson(), field: 'unsupported'},
            ],
          }),
          throwsFormatException,
        );
      }
      expect(
        CalculationInputSnapshot.fromJson(source).reactionVolume,
        'unfinished draft',
      );
    },
  );
}
