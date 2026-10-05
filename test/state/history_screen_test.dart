import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/data/app_database.dart';
import 'package:ilovebioconjugation/data/calculation_history.dart';
import 'package:ilovebioconjugation/ui/history/history_detail_screen.dart';
import 'package:ilovebioconjugation/ui/history/history_format.dart';
import 'package:ilovebioconjugation/ui/history/history_screen.dart';

import 'fake_database.dart';

class FailingDeleteDatabase extends FakeDatabase {
  @override
  Future<void> clearHistory() async => throw StateError('database locked');
}

class GatedDeleteDatabase extends FakeDatabase {
  final gate = Completer<void>();
  @override
  Future<void> clearHistory() async {
    await gate.future;
    await super.clearHistory();
  }

  @override
  Future<void> deleteHistory(int id) async {
    await gate.future;
    await super.deleteHistory(id);
  }
}

void main() {
  const record = CalculationHistory(
    id: 1,
    createdAt: 'legacy',
    ratioType: true,
  );

  Future<void> pumpHistory(
    WidgetTester tester,
    FakeDatabase database, {
    Widget screen = const HistoryScreen(),
  }) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [appDatabaseProvider.overrideWithValue(database)],
        child: MaterialApp(home: screen),
      ),
    );
    await tester.pumpAndSettle();
  }

  test(
    'history timestamp formatting accepts short or malformed legacy dates',
    () {
      expect(formatHistoryDate(''), '未知时间');
      expect(formatHistoryDate('legacy'), 'legacy');
      expect(formatHistoryDate('2026-10-02'), '2026-10-02 00:00:00');
    },
  );

  test('history number formatting preserves tiny nonzero values', () {
    expect(formatHistoryNumber(1e-9), '1.000e-9');
    expect(formatHistoryNumber(0), '0.000');
    expect(formatHistoryNumber(12.5), '12.500');
  });

  testWidgets('history renders both bases for legacy, zero and missing MW', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1366, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    const legacy = CalculationHistory(
      id: 1,
      createdAt: 'legacy',
      ratioType: true,
      reactionVolume: 1,
      substrates: [
        SubstrateResult(
          sortOrder: 0,
          name: 'IgG',
          role: 'main',
          molecularWeight: 150000,
          mwUnit: 'kDa',
          storageConcMass: 10,
          finalConcMass: 1.123456789,
        ),
        SubstrateResult(
          sortOrder: 1,
          name: 'FITC',
          role: 'secondary',
          molecularWeight: 389.38,
          storageConcMolar: 1,
          finalConcMolar: 0,
          storageVolume: 0.001,
        ),
        SubstrateResult(
          sortOrder: 2,
          name: '未知分子量',
          role: 'secondary',
          storageConcMass: 10,
          finalConcMass: 1,
        ),
        SubstrateResult(
          sortOrder: 3,
          name: '已存双浓度',
          role: 'secondary',
          molecularWeight: 1000,
          storageConcMass: 3.123456789,
          storageConcMolar: 2.987654321,
          finalConcMass: 0.00028665,
          finalConcMolar: 0.001,
        ),
      ],
    );
    final database = FakeDatabase()..records.add(legacy);
    await pumpHistory(
      tester,
      database,
      screen: const HistoryDetailScreen(recordId: 1),
    );
    String cell(String key) =>
        tester.widget<Text>(find.byKey(ValueKey(key))).data!;
    expect(cell('history-stock-0'), '质量：10.000 mg/mL\n摩尔：66.667 µM');
    expect(cell('history-final-0'), '质量：1.123 mg/mL\n摩尔：7.490 µM');
    expect(cell('history-stock-1'), '质量：389.380 µg/mL\n摩尔：1.000 mM');
    expect(cell('history-final-1'), '质量：0.000 mg/mL\n摩尔：0.000 mM');
    expect(cell('history-stock-2'), '质量：10.000 mg/mL\n摩尔：无法换算（缺少分子量）');
    expect(cell('history-stock-3'), '质量：3.123 mg/mL\n摩尔：2.988 mM');
    expect(cell('history-final-3'), '质量：286.650 ng/mL\n摩尔：1.000 µM');
    expect(find.text('1.000 mL'), findsOneWidget);
    expect(find.text('1.000 µL'), findsOneWidget);
    expect(legacy.substrates[0].storageConcMolar, isNull);
    expect(legacy.substrates[0].finalConcMass, 1.123456789);
    expect(legacy.substrates[3].storageConcMolar, 2.987654321);
    expect(database.saveRequests, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('canceling clear leaves all history untouched', (tester) async {
    final database = FakeDatabase()..records.add(record);
    await pumpHistory(tester, database);
    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();
    expect(find.text('清空历史记录？'), findsOneWidget);
    expect(database.records, hasLength(1));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(database.records, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('confirming clear deletes history and refreshes the screen', (
    tester,
  ) async {
    final database = FakeDatabase()..records.add(record);
    await pumpHistory(tester, database);
    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认清空'));
    await tester.pumpAndSettle();
    expect(database.records, isEmpty);
    expect(find.text('暂无历史记录'), findsOneWidget);
  });

  testWidgets('deleting a record requires confirmation', (tester) async {
    final database = FakeDatabase()..records.add(record);
    await pumpHistory(tester, database);
    await tester.tap(find.byTooltip('删除记录'));
    await tester.pumpAndSettle();
    expect(database.records, hasLength(1));
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();
    expect(database.records, isEmpty);
  });

  testWidgets('failed history deletion shows a nonfatal error', (tester) async {
    final database = FailingDeleteDatabase()..records.add(record);
    await pumpHistory(tester, database);
    await tester.tap(find.text('清空'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认清空'));
    await tester.pumpAndSettle();
    expect(find.textContaining('删除失败'), findsOneWidget);
    expect(database.records, hasLength(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('detail screen renders malformed timestamp safely', (
    tester,
  ) async {
    final database = FakeDatabase()..records.add(record);
    await pumpHistory(
      tester,
      database,
      screen: const HistoryDetailScreen(recordId: 1),
    );
    expect(find.text('legacy'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final clearAll in [false, true]) {
    testWidgets(
      'history refreshes after leaving during ${clearAll ? 'clear' : 'delete'}',
      (tester) async {
        final database = GatedDeleteDatabase()..records.add(record);
        final showHistory = ValueNotifier(true);
        addTearDown(showHistory.dispose);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [appDatabaseProvider.overrideWithValue(database)],
            child: MaterialApp(
              home: ValueListenableBuilder<bool>(
                valueListenable: showHistory,
                builder: (_, history, _) => history
                    ? const HistoryScreen()
                    : const Scaffold(body: Text('Calculator destination')),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(clearAll ? find.text('清空') : find.byTooltip('删除记录'));
        await tester.pumpAndSettle();
        await tester.tap(find.text(clearAll ? '确认清空' : '确认删除'));
        await tester.pumpAndSettle();
        showHistory.value = false;
        await tester.pumpAndSettle();
        database.gate.complete();
        await tester.pumpAndSettle();
        showHistory.value = true;
        await tester.pumpAndSettle();
        expect(find.text('暂无历史记录'), findsOneWidget);
        expect(database.records, isEmpty);
        expect(tester.takeException(), isNull);
      },
    );
  }
}
