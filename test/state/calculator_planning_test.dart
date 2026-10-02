import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/core/planning.dart';
import 'package:ilovebioconjugation/data/app_database.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/calculator/state.dart';
import 'package:ilovebioconjugation/ui/settings/app_settings.dart';

import 'fake_database.dart';

class _SettingsStore implements AppSettingsStore {
  @override
  Future<AppSettings> load() async => const AppSettings();
  @override
  Future<void> save(AppSettings settings) async {}
}

void main() {
  late ProviderContainer container;
  late FakeDatabase db;
  late CalculatorNotifier notifier;
  CalculatorState state() => container.read(calculatorProvider);

  setUp(() {
    db = FakeDatabase();
    container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appSettingsStoreProvider.overrideWithValue(_SettingsStore()),
      ],
    );
    notifier = container.read(calculatorProvider.notifier);
    addTearDown(container.dispose);
  });

  void baseline({bool blankMainRatio = false, bool inferredVolume = false}) {
    notifier.setReactionVolume(inferredVolume ? '' : '100');
    notifier.setSubstrateField(0, 'name', 'Protein');
    notifier.setSubstrateField(0, 'mw', '50');
    notifier.setSubstrateField(0, 'storageUnit', 'uM');
    notifier.setSubstrateField(0, 'storageConc', '100');
    notifier.setSubstrateField(0, 'finalUnit', 'uM');
    notifier.setSubstrateField(0, 'finalConc', '10');
    if (inferredVolume) notifier.setSubstrateField(0, 'storageVolume', '10');
    notifier.setSubstrateField(0, 'reactionRatio', blankMainRatio ? '' : '1');
    notifier.setSubstrateField(1, 'name', 'Label');
    notifier.setSubstrateField(1, 'mw', '500');
    notifier.setSubstrateField(1, 'storageUnit', 'mM');
    notifier.setSubstrateField(1, 'storageConc', '10');
    notifier.setSubstrateField(1, 'reactionRatio', '2');
    notifier.calculate();
    expect(state().rawResult, isNotNull, reason: state().errorMessage);
    expect(state().rawResult!.substrateAt(1).aliquotMl, closeTo(0.0002, 1e-14));
  }

  test(
    'raw unrounded values survive rendering and edits clear all derived plans',
    () {
      baseline();
      notifier.configureGradient(
        GradientSpec(selectedSlot: 1, unit: 'eq', points: ['0', '2', '4']),
      );
      notifier.calculateGradient();
      expect(state().gradientPlan, isNotNull);
      final proposal = notifier.proposeWorkingStock(1, diluentName: 'PBS')!;
      notifier.setSubstrateField(1, 'storageUnit', 'uM');
      expect(state().rawResult, isNull);
      expect(state().gradientPlan, isNull);
      expect(state().rows, isEmpty);
      expect(notifier.buildCopyText(), isEmpty);
      expect(notifier.adoptWorkingStock(proposal), isFalse);
      expect(state().planningMessage, contains('重新生成'));
    },
  );

  test(
    'reference switch renormalizes inputs and preserves physical plan, identity and blanks',
    () {
      baseline(blankMainRatio: true);
      notifier.toggleSubstrateEnabled(2);
      notifier.setSubstrateField(2, 'name', 'TCEP');
      notifier.setSubstrateField(2, 'storageUnit', 'mM');
      notifier.setSubstrateField(2, 'storageConc', '1');
      notifier.setSubstrateField(2, 'finalUnit', 'uM');
      notifier.setSubstrateField(2, 'finalConc', '5');
      notifier.calculate();
      final before = state().rawResult!;
      expect(notifier.setReferenceSlot(1), isTrue);
      expect(state().rawResult, isNull);
      expect(state().substrates[0].reactionRatio, '0.5');
      expect(state().substrates[1].reactionRatio, '1');
      expect(state().substrates[2].reactionRatio, '');
      notifier.calculate();
      final after = state().rawResult!;
      expect(after.referenceSlot, 1);
      for (final old in before.substrates) {
        expect(
          after.substrateAt(old.slot).aliquotMl,
          closeTo(old.aliquotMl, 1e-12),
        );
        expect(after.substrateAt(old.slot).finalMolarMm, old.finalMolarMm);
      }
      expect(state().substrates[0].name, 'Protein');
      expect(state().rows.first.role, '主底物');
      expect(notifier.buildCopyText(), contains('Label = 1'));
    },
  );

  test(
    'disabled and blank derived references reject without mutating valid results',
    () {
      baseline();
      final result = state().rawResult;
      expect(notifier.setReferenceSlot(2), isFalse);
      expect(state().rawResult, same(result));
      notifier.setSubstrateField(1, 'reactionRatio', '');
      notifier.setSubstrateField(1, 'finalUnit', 'uM');
      notifier.setSubstrateField(1, 'finalConc', '20');
      notifier.calculate();
      final derived = state().rawResult;
      expect(notifier.setReferenceSlot(1), isFalse);
      expect(state().rawResult, same(derived));
      expect(state().substrates[1].reactionRatio, '');
    },
  );

  test(
    'cannot silently disable active reference and reset restores main anchor',
    () {
      baseline();
      expect(notifier.setReferenceSlot(1), isTrue);
      notifier.toggleSubstrateEnabled(1);
      expect(state().substrates[1].enabled, isTrue);
      expect(state().referenceSlot, 1);
      notifier.reset();
      expect(state().referenceSlot, 0);
      expect(state().rawResult, isNull);
    },
  );

  test(
    'working stock adoption preserves dose and blanks old aliquot, retains original stock',
    () async {
      baseline(inferredVolume: true);
      notifier.setSubstrateField(1, 'storageVolume', '.2000');
      notifier.calculate();
      final before = state().rawResult!;
      final originalInput = state().substrates[1].toSnapshot().toJson();
      final beforeHistory = db.saveRequests.length;
      final proposal = notifier.proposeWorkingStock(1, diluentName: 'PBS')!;
      expect(proposal.feasible, isTrue);
      expect(
        notifier.adoptWorkingStock(proposal),
        isTrue,
        reason: state().planningMessage,
      );
      final after = state().rawResult!;
      expect(after.totalVolumeMl, closeTo(before.totalVolumeMl, 1e-12));
      expect(
        after.substrateAt(1).finalMolarMm,
        before.substrateAt(1).finalMolarMm,
      );
      expect(after.substrateAt(1).aliquotMl, closeTo(0.001, 1e-12));
      expect(state().substrates[1].storageVolume, '');
      expect(state().workingStocks.single.parentInput.toJson(), originalInput);
      expect(state().workingStocks.single.diluentName, 'PBS');
      expect(state().workingStocks.single.newAliquotMl, closeTo(0.001, 1e-12));
      expect(db.saveRequests.length, beforeHistory + 1);
      await Future<void>.delayed(Duration.zero);
      final record = db.records.last;
      notifier.reset();
      notifier.restoreFromHistory(record);
      expect(state().rawResult, isNull);
      expect(state().workingStocks.single.parentInput.toJson(), originalInput);
      notifier.calculate();
      expect(
        state().rawResult!.substrateAt(1).aliquotMl,
        closeTo(0.001, 1e-12),
      );
    },
  );

  test('infeasible, reused, and reset proposals are rejected atomically', () {
    baseline();
    final original = notifier.captureInputs().toJson();
    final impossible = notifier.proposeWorkingStock(1, dilutionFactor: 1000)!;
    expect(impossible.feasible, isFalse);
    expect(notifier.adoptWorkingStock(impossible), isFalse);
    expect(notifier.captureInputs().toJson(), original);
    final possible = notifier.proposeWorkingStock(1, diluentName: 'PBS')!;
    expect(notifier.adoptWorkingStock(possible), isTrue);
    final adopted = notifier.captureInputs().toJson();
    expect(notifier.adoptWorkingStock(possible), isFalse);
    expect(notifier.captureInputs().toJson(), adopted);
    final another = notifier.proposeWorkingStock(
      1,
      dilutionFactor: 2,
      diluentName: 'PBS',
    )!;
    notifier.reset();
    expect(notifier.adoptWorkingStock(another), isFalse);
    expect(state().workingStocks, isEmpty);
  });

  test(
    'threshold refreshes warnings and batch without rewriting history or doses',
    () async {
      baseline();
      notifier.configureGradient(
        GradientSpec(selectedSlot: 1, unit: 'eq', points: ['0', '1', '2']),
      );
      notifier.calculateGradient();
      final before = state().rawResult!;
      final proposal = notifier.proposeWorkingStock(1, diluentName: 'PBS')!;
      final count = db.saveRequests.length;
      expect(state().rows.last.lowVolume, isTrue);
      await container
          .read(appSettingsProvider.notifier)
          .setMinimumPipettingVolumeUl(0);
      expect(state().rows.last.lowVolume, isFalse);
      expect(
        state().rawResult!.substrateAt(1).aliquotMl,
        before.substrateAt(1).aliquotMl,
      );
      expect(state().gradientPlan!.groups, hasLength(3));
      expect(db.saveRequests.length, count);
      expect(state().rawResult!.input.minimumPipettingVolumeUl, 0);
      expect(notifier.adoptWorkingStock(proposal), isFalse);
    },
  );

  test(
    'batch saves once, keeps invalid groups, and restores base inputs/settings/request',
    () async {
      baseline();
      await container
          .read(appSettingsProvider.notifier)
          .setMinimumPipettingVolumeUl(2.5);
      final before = state().substrates
          .map((s) => s.toSnapshot().toJson())
          .toList();
      final count = db.saveRequests.length;
      notifier.configureGradient(
        GradientSpec(
          selectedSlot: 1,
          unit: 'eq',
          points: ['0', '2.000', 'bad', '2000'],
          replicates: 3,
          extraPreparationFraction: .1,
        ),
      );
      notifier.calculateGradient();
      final plan = state().gradientPlan!;
      expect(plan.groups, hasLength(4));
      expect(plan.totals.validGroupCount, 2);
      expect(plan.totals.failedGroupCount, 2);
      expect(plan.totals.reactionCount, 6);
      expect(db.saveRequests.length, count + 1);
      await Future<void>.delayed(Duration.zero);
      final record = db.records.last;
      notifier.setSubstrateField(0, 'finalConc', '999');
      await container
          .read(appSettingsProvider.notifier)
          .setMinimumPipettingVolumeUl(5);
      notifier.restoreFromHistory(record);
      expect(
        state().substrates.map((s) => s.toSnapshot().toJson()).toList(),
        before,
      );
      expect(state().rawResult, isNull);
      expect(state().gradientPlan, isNull);
      expect(state().gradientSpec!.points, ['0', '2.000', 'bad', '2000']);
      expect(state().gradientSpec!.replicates, 3);
      expect(state().gradientSpec!.extraPreparationFraction, .1);
      expect(container.read(appSettingsProvider).minimumPipettingVolumeUl, 2.5);
      notifier.calculate();
      notifier.calculateGradient();
      expect(
        state().gradientPlan!.totals.totalVolumeMl,
        plan.totals.totalVolumeMl,
      );
    },
  );

  test('changing gradient draft invalidates batch only and no save occurs', () {
    baseline();
    notifier.configureGradient(
      GradientSpec(selectedSlot: 1, unit: 'eq', points: ['0', '2']),
    );
    notifier.calculateGradient();
    final baselineResult = state().rawResult;
    final count = db.saveRequests.length;
    notifier.configureGradient(
      GradientSpec(selectedSlot: 1, unit: 'eq', points: ['4']),
    );
    expect(state().gradientPlan, isNull);
    expect(state().rawResult, same(baselineResult));
    expect(db.saveRequests.length, count);
  });

  test(
    'late batch save errors cannot pollute reset or overwrite later successful calculation',
    () async {
      baseline();
      final gate = Completer<int>();
      db.saveGate = gate;
      db.saveError = StateError('old batch failure');
      notifier.configureGradient(
        GradientSpec(selectedSlot: 1, unit: 'eq', points: ['0', '2']),
      );
      notifier.calculateGradient();
      notifier.reset();
      db.saveGate = null;
      db.saveError = null;
      baseline();
      gate.complete(1);
      await Future<void>.delayed(Duration.zero);
      expect(state().historySaveError, isEmpty);
      expect(state().gradientPlan, isNull);
      expect(state().rawResult, isNotNull);
    },
  );
  test(
    'adoption requires named diluent, actual dilution, and no unsupported serial stock',
    () {
      baseline();
      final original = notifier.captureInputs().toJson();
      final unnamed = notifier.proposeWorkingStock(1)!;
      expect(notifier.adoptWorkingStock(unnamed), isFalse);
      expect(state().planningMessage, contains('稀释液'));
      final unnecessary = notifier.proposeWorkingStock(0, diluentName: 'PBS')!;
      expect(notifier.adoptWorkingStock(unnecessary), isFalse);
      expect(notifier.captureInputs().toJson(), original);
      expect(
        notifier.adoptWorkingStock(
          notifier.proposeWorkingStock(1, diluentName: 'PBS')!,
        ),
        isTrue,
      );
      final adopted = notifier.captureInputs().toJson();
      final second = notifier.proposeWorkingStock(
        1,
        dilutionFactor: 1.01,
        diluentName: 'PBS',
      )!;
      expect(notifier.adoptWorkingStock(second), isFalse);
      expect(state().planningMessage, contains('恢复原母液'));
      expect(notifier.captureInputs().toJson(), adopted);
    },
  );

  test(
    'shared batch adoption works when original baseline is outside feasible diluted range',
    () async {
      baseline();
      notifier.setSubstrateField(1, 'reactionRatio', '500');
      notifier.calculate();
      final originalInputs = notifier
          .captureInputs()
          .substrates
          .map((s) => s.toJson())
          .toList();
      final originalResult = state().rawResult!;
      notifier.configureGradient(
        GradientSpec(
          selectedSlot: 1,
          unit: 'eq',
          points: ['0', '.10', '1'],
          replicates: 2,
          extraPreparationFraction: .1,
        ),
      );
      notifier.calculateGradient();
      final originalPlan = state().gradientPlan!;
      final advice = proposeGradientWorkingStock(
        originalPlan,
        slot: 1,
        minimumVolumeMl: .001,
        diluentName: 'PBS',
      );
      expect(advice.shared!.factor, closeTo(100, 1e-9));
      final writes = db.saveRequests.length;
      expect(
        notifier.adoptGradientWorkingStock(advice),
        isTrue,
        reason: state().planningMessage,
      );
      expect(state().rawResult, same(originalResult));
      expect(
        notifier.captureInputs().substrates.map((s) => s.toJson()).toList(),
        originalInputs,
      );
      expect(
        state().gradientPlan!.groups[1].result!.substrateAt(1).aliquotMl,
        closeTo(.001, 1e-12),
      );
      expect(
        state().gradientPlan!.groups[2].result!.substrateAt(1).aliquotMl,
        closeTo(.01, 1e-12),
      );
      expect(
        state().gradientPlan!.groups[0].result!.substrateAt(1).aliquotMl,
        0,
      );
      expect(state().gradientPlan!.workingStocks, hasLength(1));
      expect(state().gradientWorkingStocks.single.diluentName, 'PBS');
      expect(db.saveRequests.length, writes + 1);
      await Future<void>.delayed(Duration.zero);
      final saved = db.records.last;
      final totals = state().gradientPlan!.totals.aliquotsMl;
      expect(saved.inputSnapshot!.gradient!.workingStocks, hasLength(1));
      notifier.reset();
      notifier.restoreFromHistory(saved);
      expect(state().rawResult, isNull);
      expect(state().gradientWorkingStocks, hasLength(1));
      notifier.calculate();
      // Dialog recreation may construct a new object with unchanged values.
      notifier.configureGradient(
        GradientSpec(
          selectedSlot: 1,
          unit: 'eq',
          points: ['0', '.10', '1'],
          replicates: 2,
          extraPreparationFraction: .1,
        ),
      );
      expect(state().gradientWorkingStocks, hasLength(1));
      notifier.calculateGradient();
      expect(state().gradientPlan!.totals.aliquotsMl, totals);
      expect(
        state().rawResult!.substrateAt(1).aliquotMl,
        originalResult.substrateAt(1).aliquotMl,
      );
    },
  );

  test(
    'batch recipe keeps preparation threshold but refreshes warnings at new threshold',
    () async {
      baseline();
      notifier.configureGradient(
        GradientSpec(selectedSlot: 1, unit: 'eq', points: ['0', '1', '2']),
      );
      notifier.calculateGradient();
      final advice = proposeGradientWorkingStock(
        state().gradientPlan!,
        slot: 1,
        minimumVolumeMl: .001,
        diluentName: 'PBS',
      );
      expect(notifier.adoptGradientWorkingStock(advice), isTrue);
      final totals = state().gradientPlan!.totals.aliquotsMl;
      final recipe = state().gradientWorkingStocks.single.toJson();
      await container
          .read(appSettingsProvider.notifier)
          .setMinimumPipettingVolumeUl(0);
      expect(state().gradientPlan, isNotNull);
      expect(
        state().gradientPlan!.groups.expand((g) => g.result!.warnings),
        isEmpty,
      );
      expect(state().gradientPlan!.totals.aliquotsMl, totals);
      expect(state().gradientWorkingStocks.single.toJson(), recipe);
      await container
          .read(appSettingsProvider.notifier)
          .setMinimumPipettingVolumeUl(20);
      expect(state().gradientPlan!.groups.last.result!.warnings, isNotEmpty);
      expect(state().gradientPlan!.totals.aliquotsMl, totals);
      expect(state().gradientWorkingStocks.single.toJson(), recipe);
    },
  );

  test(
    'old common-stock advice cannot overwrite a changed gradient or add history',
    () {
      baseline();
      notifier.configureGradient(
        GradientSpec(selectedSlot: 1, unit: 'eq', points: ['1', '2']),
      );
      notifier.calculateGradient();
      final advice = proposeGradientWorkingStock(
        state().gradientPlan!,
        slot: 1,
        minimumVolumeMl: .001,
        diluentName: 'PBS',
      );
      final writes = db.saveRequests.length;
      notifier.configureGradient(
        GradientSpec(selectedSlot: 1, unit: 'eq', points: ['4']),
      );
      expect(notifier.adoptGradientWorkingStock(advice), isFalse);
      expect(state().gradientWorkingStocks, isEmpty);
      expect(db.saveRequests.length, writes);
      notifier.calculateGradient();
      expect(state().gradientPlan!.spec.points, ['4']);
    },
  );

  test('zero reference is shown as unavailable, never one equivalent', () {
    baseline();
    notifier.toggleSubstrateEnabled(1);
    notifier.setSubstrateField(0, 'finalConc', '0');
    notifier.calculate();
    expect(state().rawResult, isNotNull);
    expect(state().rows.single.ratio, 'N/A');
    expect(notifier.buildCopyText(), contains('用量为 0，投料比不适用'));
    expect(notifier.buildCopyText(), isNot(contains('Protein = 1')));
  });
  test('reference normalization rejects invalid filled ratios atomically', () {
    baseline();
    notifier.setSubstrateField(3, 'reactionRatio', 'draft');
    final before = notifier.captureInputs().toJson();
    expect(notifier.setReferenceSlot(1), isFalse);
    expect(state().planningMessage, contains('有效数字'));
    expect(notifier.captureInputs().toJson(), before);
    notifier.setSubstrateField(3, 'reactionRatio', '');
    expect(notifier.setReferenceSlot(1), isTrue);
    expect(state().substrates[3].reactionRatio, '');
  });
  test(
    'dose edits retain original preparation and expose current stock shortage',
    () {
      baseline();
      expect(
        notifier.adoptWorkingStock(
          notifier.proposeWorkingStock(1, diluentName: 'PBS')!,
        ),
        isTrue,
      );
      final recipe = state().workingStocks.single.toJson();
      notifier.setReactionVolume('1000');
      expect(state().rawResult, isNull);
      expect(state().workingStocks.single.toJson(), recipe);
      notifier.calculate();
      expect(state().rawResult!.substrateAt(1).aliquotMl, closeTo(.01, 1e-12));
      expect(
        state().rawResult!.warnings.any(
          (warning) => warning.code == 'insufficient_working_stock',
        ),
        isTrue,
      );
      expect(state().rows.last.warning, isNotEmpty);
      expect(notifier.buildCopyText(), contains('不足'));
      expect(state().workingStocks.single.toJson(), recipe);
    },
  );

  test(
    'batch demand includes repeats and excess without enlarging original single stock preparation',
    () {
      baseline();
      expect(
        notifier.adoptWorkingStock(
          notifier.proposeWorkingStock(1, diluentName: 'PBS')!,
        ),
        isTrue,
      );
      final recipe = state().workingStocks.single.toJson();
      notifier.configureGradient(
        GradientSpec(
          selectedSlot: 1,
          unit: 'eq',
          points: ['2', '3'],
          replicates: 10,
          extraPreparationFraction: .1,
        ),
      );
      notifier.calculateGradient();
      expect(state().gradientPlan!.totals.aliquotsMl[1], closeTo(.0275, 1e-12));
      expect(
        state().gradientPlan!.warnings.any(
          (warning) => warning.code == 'insufficient_working_stock',
        ),
        isTrue,
      );
      expect(state().workingStocks.single.toJson(), recipe);
      final advice = proposeGradientWorkingStock(
        state().gradientPlan!,
        slot: 1,
        minimumVolumeMl: .002,
        diluentName: 'PBS',
      );
      expect(notifier.adoptGradientWorkingStock(advice), isFalse);
      expect(state().planningMessage, contains('基线已采用工作液'));
      expect(state().workingStocks.single.toJson(), recipe);
    },
  );
  test(
    'disabled adopted stock retains archived recipe across history restore and reenable',
    () async {
      baseline();
      expect(
        notifier.adoptWorkingStock(
          notifier.proposeWorkingStock(1, diluentName: 'PBS')!,
        ),
        isTrue,
      );
      final recipe = state().workingStocks.single.toJson();
      final stock = state().substrates[1].storageConc;
      notifier.toggleSubstrateEnabled(1);
      expect(state().workingStocks.single.toJson(), recipe);
      notifier.calculate();
      expect(state().rawResult!.substrates, hasLength(1));
      await Future<void>.delayed(Duration.zero);
      final saved = db.records.last;
      expect(saved.inputSnapshot!.workingStocks.single.toJson(), recipe);
      notifier.reset();
      notifier.restoreFromHistory(saved);
      expect(state().substrates[1].enabled, isFalse);
      expect(state().workingStocks.single.toJson(), recipe);
      notifier.toggleSubstrateEnabled(1);
      notifier.calculate();
      expect(state().workingStocks.single.toJson(), recipe);
      expect(state().substrates[1].storageConc, stock);
      expect(state().rawResult!.substrateAt(1).aliquotMl, closeTo(.001, 1e-12));
    },
  );
}
