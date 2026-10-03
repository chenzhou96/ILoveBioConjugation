import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/data/app_database.dart';
import 'package:ilovebioconjugation/data/calculation_history.dart';
import 'package:ilovebioconjugation/data/calculation_input_snapshot.dart';
import 'package:ilovebioconjugation/data/substrate_template.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/calculator/state.dart';
import 'package:ilovebioconjugation/ui/history/history_screen.dart';

import 'fake_database.dart';

void main() {
  late FakeDatabase database;
  late ProviderContainer container;
  late CalculatorNotifier notifier;

  setUp(() {
    database = FakeDatabase();
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    notifier = container.read(calculatorProvider.notifier);
    addTearDown(container.dispose);
  });

  CalculatorState current() => container.read(calculatorProvider);

  void prepareValidCalculation() {
    notifier.setRatioType(false);
    notifier.toggleSubstrateEnabled(1);
    notifier.setReactionVolume('100');
    notifier.setSubstrateField(0, 'storageConc', '10');
    notifier.setSubstrateField(0, 'finalConc', '1');
    notifier.calculate();
    expect(current().statusLevel, StatusLevel.success);
    expect(notifier.buildCopyText(), isNotEmpty);
  }

  void expectInvalidated() {
    expect(current().rows, isEmpty);
    expect(current().summaryRows, isEmpty);
    expect(current().metrics.totalVolume, '--');
    expect(notifier.buildCopyText(), isEmpty);
    expect(current().statusLevel, StatusLevel.info);
  }

  group('Every input change invalidates copyable results', () {
    const edits = {
      'name': 'renamed',
      'mw': '50000',
      'mwUnit': 'Da',
      'storageConc': '20',
      'storageUnit': 'nM',
      'finalConc': '2',
      'finalUnit': 'pM',
      'reactionRatio': '3',
      'storageVolume': '7',
      'storageVolumeUnit': 'pL',
    };
    for (final edit in edits.entries) {
      test('substrate ${edit.key}', () {
        prepareValidCalculation();
        notifier.setSubstrateField(0, edit.key, edit.value);
        expectInvalidated();
      });
    }
    test('reaction volume', () {
      prepareValidCalculation();
      notifier.setReactionVolume('200');
      expectInvalidated();
    });
    test('reaction volume unit', () {
      prepareValidCalculation();
      notifier.setReactionVolumeUnit('mL');
      expectInvalidated();
    });
    test('ratio type', () {
      prepareValidCalculation();
      notifier.setRatioType(true);
      expectInvalidated();
    });
    test('enabled slot', () {
      prepareValidCalculation();
      notifier.toggleSubstrateEnabled(2);
      expectInvalidated();
    });
    test('disabled slot edits', () {
      prepareValidCalculation();
      notifier.setSubstrateField(3, 'name', 'a draft');
      expectInvalidated();
    });
    test('reset', () {
      prepareValidCalculation();
      notifier.reset();
      expectInvalidated();
      expect(current().reactionVolume, '');
    });
  });

  test(
    'rejects overfill without changing the target or input concentrations',
    () {
      prepareValidCalculation();
      final savedCount = database.saveRequests.length;
      notifier.setSubstrateField(0, 'finalConc', '20');
      final before = current().substrates
          .map((s) => s.toSnapshot().toJson())
          .toList();
      notifier.calculate();
      expect(current().statusLevel, StatusLevel.error);
      expect(current().errorMessage, contains('体积'));
      expect(current().reactionVolume, '100');
      expect(current().reactionVolumeUnit, 'uL');
      expect(
        current().substrates.map((s) => s.toSnapshot().toJson()).toList(),
        before,
      );
      expect(notifier.buildCopyText(), isEmpty);
      expect(database.saveRequests.length, savedCount);
    },
  );

  test('template blanks replace stale values, including previous aliquot', () {
    prepareValidCalculation();
    notifier.setSubstrateField(0, 'mw', '123');
    notifier.setSubstrateField(0, 'storageVolume', '9');
    notifier.applyTemplate(
      0,
      const SubstrateTemplate(
        name: 'Blank stock',
        mwUnit: 'Da',
        storageUnit: 'nM',
        defaultFinalUnit: 'pM',
        createdAt: '2026-10-02',
        updatedAt: '2026-10-02',
      ),
    );
    final input = current().substrates[0];
    expect(input.enabled, isTrue);
    expect(input.name, 'Blank stock');
    expect(input.mw, '');
    expect(input.storageConc, '');
    expect(input.finalConc, '');
    expect(input.reactionRatio, '1');
    expect(input.storageVolume, '');
    expect(input.mwUnit, 'Da');
    expect(input.storageUnit, 'nM');
    expect(input.finalUnit, 'pM');
    expectInvalidated();
  });

  test(
    'new history exactly restores text, units, blank constraints and all slots',
    () async {
      notifier.toggleSubstrateEnabled(1);
      notifier.toggleSubstrateEnabled(2);
      notifier.setReactionVolume('00100.00');
      notifier.setSubstrateField(0, 'name', '  protein  ');
      notifier.setSubstrateField(0, 'storageConc', '001.2500');
      notifier.setSubstrateField(0, 'storageUnit', 'nM');
      notifier.setSubstrateField(0, 'finalConc', '.2500');
      notifier.setSubstrateField(0, 'finalUnit', 'nM');
      notifier.setSubstrateField(2, 'storageConc', '2500.000');
      notifier.setSubstrateField(2, 'storageUnit', 'pM');
      notifier.setSubstrateField(2, 'reactionRatio', '2.000');
      notifier.setSubstrateField(3, 'mw', 'unfinished draft');
      final original = current();
      notifier.calculate();
      expect(current().statusLevel, StatusLevel.success);
      final copyText = notifier.buildCopyText();
      await Future<void>.delayed(Duration.zero);
      final record = database.records.single;
      expect(record.inputSnapshot, isNotNull);
      expect(record.substrates.map((s) => s.sortOrder), [0, 2]);
      expect(current().rows.last.role, '副底物2');
      notifier.toggleSubstrateEnabled(3);
      notifier.setReactionVolume('999');
      notifier.setSubstrateField(0, 'finalConc', '777');
      notifier.restoreFromHistory(record);
      expect(current().reactionVolume, original.reactionVolume);
      expect(current().reactionVolumeUnit, original.reactionVolumeUnit);
      expect(current().ratioType, original.ratioType);
      expect(
        current().substrates.map((s) => s.toSnapshot().toJson()).toList(),
        original.substrates.map((s) => s.toSnapshot().toJson()).toList(),
      );
      expect(current().substrates[0].storageVolume, isEmpty);
      expect(current().substrates[2].finalConc, isEmpty);
      expectInvalidated();
      notifier.calculate();
      expect(current().statusLevel, StatusLevel.success);
      expect(notifier.buildCopyText(), copyText);
    },
  );

  for (final concentration in [1e-6, 1e-9, 1.234567890123456e-12]) {
    test('legacy history preserves small concentration $concentration', () {
      prepareValidCalculation();
      notifier.toggleSubstrateEnabled(2);
      notifier.toggleSubstrateEnabled(3);
      notifier.setSubstrateField(3, 'storageConc', '999');
      notifier.restoreFromHistory(
        CalculationHistory(
          createdAt: '2026-10-02T00:00:00',
          ratioType: true,
          reactionVolume: 1.234567890123456e-9,
          substrates: [
            SubstrateResult(
              sortOrder: 0,
              name: 'Trace stock',
              role: 'main',
              molecularWeight: 12345.67890123456,
              storageConcMolar: concentration,
              finalConcMolar: concentration / 10,
              storageVolume: 1.234567890123456e-10,
              reactionRatio: 1,
            ),
          ],
        ),
      );
      final main = current().substrates.first;
      expect(double.parse(main.storageConc), concentration);
      expect(double.parse(main.finalConc), concentration / 10);
      expect(double.parse(main.mw), 12345.67890123456);
      expect(double.parse(current().reactionVolume), 1.234567890123456e-9);
      expect(current().substrates.map((s) => s.enabled), [
        true,
        false,
        false,
        false,
      ]);
      expect(current().substrates[3].storageConc, isEmpty);
      expectInvalidated();
    });
  }

  test(
    'legacy mass history uses mass concentrations when both bases exist',
    () {
      notifier.restoreFromHistory(
        const CalculationHistory(
          createdAt: '2026-10-02T00:00:00',
          ratioType: false,
          substrates: [
            SubstrateResult(
              sortOrder: 0,
              name: 'Mass stock',
              role: 'main',
              storageConcMolar: 2,
              storageConcMass: 3,
              finalConcMolar: 0.2,
              finalConcMass: 0.3,
            ),
          ],
        ),
      );
      expect(current().substrates[0].storageConc, '3.0');
      expect(current().substrates[0].storageUnit, 'mg/mL');
      expect(current().substrates[0].finalConc, '0.3');
    },
  );

  test(
    'inferred target is identified and original blank remains in history',
    () {
      notifier.setRatioType(false);
      notifier.toggleSubstrateEnabled(1);
      notifier.setSubstrateField(0, 'storageConc', '10');
      notifier.setSubstrateField(0, 'finalConc', '1');
      notifier.setSubstrateField(0, 'storageVolume', '10');
      notifier.calculate();
      expect(current().statusLevel, StatusLevel.success);
      expect(current().summaryRows, contains(('反应体积来源', '根据已知条件推导')));
      expect(database.saveRequests.single.inputSnapshot!.reactionVolume, '');
    },
  );

  test(
    'save failure is visible and preserves successful, copyable results',
    () async {
      database.saveError = StateError('disk full');
      prepareValidCalculation();
      await Future<void>.delayed(Duration.zero);
      expect(current().historySaveError, contains('disk full'));
      expect(current().statusLevel, StatusLevel.success);
      expect(current().rows, isNotEmpty);
      expect(notifier.buildCopyText(), isNotEmpty);
    },
  );

  test('history refresh waits until save has actually completed', () async {
    database.saveGate = Completer<int>();
    final subscription = container.listen(historyProvider, (_, _) {});
    addTearDown(subscription.close);
    await container.read(historyProvider.future);
    expect(database.historyReads, 1);
    prepareValidCalculation();
    await Future<void>.delayed(Duration.zero);
    expect(database.historyReads, 1);
    database.saveGate!.complete(1);
    await Future<void>.delayed(Duration.zero);
    final history = await container.read(historyProvider.future);
    expect(history.length, 1);
    expect(database.historyReads, 2);
  });

  test('late save failure does not replace status after editing', () async {
    database.saveGate = Completer<int>();
    database.saveError = StateError('disk full');
    prepareValidCalculation();
    notifier.setReactionVolume('200');
    final status = current().statusMessage;
    database.saveGate!.complete(1);
    await Future<void>.delayed(Duration.zero);
    expect(current().statusMessage, status);
    expect(current().historySaveError, contains('disk full'));
    expectInvalidated();
  });

  test(
    'late save failure after reset does not pollute the fresh calculator',
    () async {
      database.saveGate = Completer<int>();
      database.saveError = StateError('disk full');
      prepareValidCalculation();
      notifier.reset();
      expect(current().reactionVolume, isEmpty);
      database.saveGate!.complete(1);
      await Future<void>.delayed(Duration.zero);
      expect(current().historySaveError, isEmpty);
    },
  );

  test(
    'older failing save cannot overwrite a newer successfully saved calculation',
    () async {
      final oldSave = Completer<int>();
      database.saveGate = oldSave;
      database.saveError = StateError('older save failed');
      prepareValidCalculation();
      database.saveGate = null;
      database.saveError = null;
      notifier.setReactionVolume('200');
      notifier.calculate();
      await Future<void>.delayed(Duration.zero);
      expect(database.records.length, 1);
      oldSave.complete(1);
      await Future<void>.delayed(Duration.zero);
      expect(current().historySaveError, isEmpty);
      expect(current().reactionVolume, '200');
      expect(current().statusLevel, StatusLevel.success);
    },
  );

  test('older successful save cannot clear a newer failure', () async {
    final oldSave = Completer<int>();
    database.saveGate = oldSave;
    prepareValidCalculation();
    database.saveGate = null;
    database.saveError = StateError('new save failed');
    notifier.setReactionVolume('200');
    notifier.calculate();
    await Future<void>.delayed(Duration.zero);
    expect(current().historySaveError, contains('new save failed'));
    oldSave.complete(1);
    await Future<void>.delayed(Duration.zero);
    expect(current().historySaveError, contains('new save failed'));
  });

  test(
    'template supports an explicit main reference ratio and defaults a missing one',
    () {
      notifier.applyTemplate(
        0,
        const SubstrateTemplate(
          name: 'Two equivalents',
          defaultReactionRatio: 2,
          createdAt: '2026-10-02',
          updatedAt: '2026-10-02',
        ),
      );
      expect(current().substrates.first.reactionRatio, '2.0');
      notifier.applyTemplate(
        1,
        const SubstrateTemplate(
          name: 'Blank secondary',
          createdAt: '2026-10-02',
          updatedAt: '2026-10-02',
        ),
      );
      expect(current().substrates[1].reactionRatio, '');
    },
  );

  test('tiny positive concentration and volume stay nonzero in copy text', () {
    notifier.toggleSubstrateEnabled(1);
    notifier.setReactionVolume('0.0001');
    notifier.setReactionVolumeUnit('pL');
    notifier.setSubstrateField(0, 'storageConc', '0.0001');
    notifier.setSubstrateField(0, 'storageUnit', 'pM');
    notifier.setSubstrateField(0, 'finalConc', '0.00001');
    notifier.setSubstrateField(0, 'finalUnit', 'pM');
    notifier.calculate();
    expect(current().statusLevel, StatusLevel.success);
    expect(current().rows.single.stock, contains('e-'));
    expect(current().rows.single.finalConc, contains('e-'));
    expect(current().rows.single.volume, contains('e-'));
    expect(current().metrics.totalVolume, contains('e-'));
  });

  test(
    'short input snapshots pad fresh disabled slots without stale fields',
    () {
      prepareValidCalculation();
      notifier.setSubstrateField(3, 'mw', 'stale');
      notifier.restoreFromHistory(
        CalculationHistory(
          createdAt: '2026-10-02',
          ratioType: false,
          inputSnapshot: CalculationInputSnapshot(
            reactionVolume: '100.0',
            reactionVolumeUnit: 'uL',
            ratioType: false,
            substrates: [current().substrates.first.toSnapshot()],
          ),
        ),
      );
      expect(current().substrates.length, 4);
      expect(current().substrates.map((s) => s.enabled), [
        true,
        false,
        false,
        false,
      ]);
      expect(current().substrates[3].mw, isEmpty);
      expectInvalidated();
    },
  );

  test('legacy restore respects sparse original slot indices', () {
    notifier.restoreFromHistory(
      const CalculationHistory(
        createdAt: '2026-10-02',
        ratioType: false,
        substrates: [
          SubstrateResult(sortOrder: 2, name: 'Second slot', role: 'secondary'),
          SubstrateResult(sortOrder: 0, name: 'Main', role: 'main'),
        ],
      ),
    );
    expect(current().substrates.map((s) => s.enabled), [
      true,
      false,
      true,
      false,
    ]);
    expect(current().substrates[2].name, 'Second slot');
  });

  test('tiny positive ratios are not copied as zero', () {
    notifier.setReactionVolume('100');
    notifier.setSubstrateField(0, 'storageConc', '10');
    notifier.setSubstrateField(0, 'storageUnit', 'nM');
    notifier.setSubstrateField(0, 'finalConc', '1');
    notifier.setSubstrateField(0, 'finalUnit', 'nM');
    notifier.setSubstrateField(1, 'storageConc', '10');
    notifier.setSubstrateField(1, 'storageUnit', 'nM');
    notifier.setSubstrateField(1, 'reactionRatio', '1e-9');
    notifier.calculate();
    expect(current().statusLevel, StatusLevel.success);
    expect(current().rows.last.ratio, '1.000e-9');
  });

  test(
    'successful save still refreshes history after calculator reset',
    () async {
      database.saveGate = Completer<int>();
      final subscription = container.listen(historyProvider, (_, _) {});
      addTearDown(subscription.close);
      await container.read(historyProvider.future);
      prepareValidCalculation();
      notifier.reset();
      expect(current().reactionVolume, isEmpty);
      database.saveGate!.complete(1);
      await Future<void>.delayed(Duration.zero);
      expect(await container.read(historyProvider.future), hasLength(1));
      expect(current().reactionVolume, isEmpty);
    },
  );

  test('late save failure after disposal is handled', () async {
    final localDatabase = FakeDatabase()
      ..saveGate = Completer<int>()
      ..saveError = StateError('closed database');
    final localContainer = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(localDatabase)],
    );
    final localNotifier = localContainer.read(calculatorProvider.notifier);
    localNotifier.setRatioType(false);
    localNotifier.toggleSubstrateEnabled(1);
    localNotifier.setReactionVolume('100');
    localNotifier.setSubstrateField(0, 'storageConc', '10');
    localNotifier.setSubstrateField(0, 'finalConc', '1');
    localNotifier.calculate();
    localContainer.dispose();
    localDatabase.saveGate!.complete(1);
    await Future<void>.delayed(Duration.zero);
  });
}
