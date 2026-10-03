import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/core/planning.dart';
import 'package:ilovebioconjugation/data/app_database.dart';
import 'package:ilovebioconjugation/data/calculation_input_snapshot.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/history/history_detail_screen.dart';
import 'package:ilovebioconjugation/ui/planning/record_actions.dart';

import '../fixtures/gradient_history.dart';
import 'fake_database.dart';

void main() {
  test(
    'saved single working stock restores all doses, zero and bulk totals',
    () {
      final input = gradientHistoryInput();
      final original = input.toJson().toString();
      final plan = restoreGradientPlan(
        CalculationInputSnapshot.fromJson(input.toJson()),
      );
      expect(plan.groups, hasLength(4));
      expect(plan.groups.first.result!.substrateAt(1).aliquotMl, 0);
      for (var i = 0; i < 4; i++) {
        final result = plan.groups[i].result!;
        final eq = double.parse(input.gradient!.points[i]);
        expect(result.substrateAt(0).aliquotMl, closeTo(0.05, 1e-15));
        expect(result.substrateAt(1).stockMassMgMl, 1);
        expect(
          result.substrateAt(1).aliquotMl,
          closeTo(0.1 * eq * 1 / 150000 * 389.38, 1e-15),
        );
        expect(
          result.substrateAt(2).aliquotMl,
          closeTo(0.002222222222222222, 1e-15),
        );
        expect(result.totalVolumeMl, 0.1);
      }
      expect(plan.totals.totalVolumeMl, closeTo(0.48, 1e-15));
      expect(plan.totals.aliquotsMl[1], closeTo(0.01401768, 1e-15));
      expect(plan.warnings.single.code, 'insufficient_working_stock');
      expect(input.toJson().toString(), original);
    },
  );

  test('saved common stock replays its factor, never the baseline stock', () {
    final source = gradientHistoryInput(
      singleStock: false,
      points: ['0', '1', '2', '5'],
      replicates: 2,
      extra: 0.1,
    );
    final original = restoreGradientPlan(source);
    final shared = proposeGradientWorkingStock(
      original,
      slot: 1,
      minimumVolumeMl: 0.001,
      dilutionFactor: 100,
      diluentName: 'PBS',
    ).shared!;
    final stock = WorkingStockProvenance(
      slot: 1,
      parentInput: source.substrates[1],
      workingConcentration: '0.1',
      workingUnit: 'mg/mL',
      dilutionFactor: 100,
      parentVolumeMl: shared.parentStockMl,
      diluentVolumeMl: shared.diluentMl,
      preparationVolumeMl: shared.preparationVolumeMl,
      requiredVolumeMl: shared.requiredVolumeMl,
      newAliquotMl: shared.newAliquotMl,
      minimumVolumeMl: shared.minimumVolumeMl,
      diluentName: 'PBS',
    );
    final saved = gradientHistoryInput(
      singleStock: false,
      points: ['0', '1', '2', '5'],
      replicates: 2,
      extra: 0.1,
      batchStocks: [stock],
    );
    final plan = restoreGradientPlan(
      CalculationInputSnapshot.fromJson(saved.toJson()),
    );
    expect(plan.baseline.substrateAt(1).stockMassMgMl, 10);
    expect(plan.workingStocks.single.factor, 100);
    for (var i = 0; i < 4; i++) {
      final result = plan.groups[i].result!;
      expect(result.substrateAt(1).stockMassMgMl, closeTo(0.1, 1e-15));
      expect(
        result.substrateAt(1).aliquotMl,
        closeTo(
          original.groups[i].result!.substrateAt(1).aliquotMl * 100,
          1e-15,
        ),
      );
    }
  });

  for (final size in [const Size(1366, 900), const Size(390, 844)]) {
    testWidgets(
      'history directly views all pages and copies all conditions at $size',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final input = gradientHistoryInput(
          points: ['0', '10', '10', '15', '20', 'bad', '1000000'],
          replicates: 2,
          extra: 0.1,
        );
        final before = input.toJson().toString();
        final database = FakeDatabase()
          ..records.add(gradientHistoryRecord(input));
        final container = ProviderContainer(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
        );
        addTearDown(container.dispose);
        final calculatorBefore = container.read(calculatorProvider);
        final copied = <String>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async {
            if (call.method == 'Clipboard.setData') {
              copied.add((call.arguments as Map)['text'] as String);
            }
            return null;
          },
        );
        addTearDown(
          () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          ),
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: HistoryDetailScreen(recordId: 1)),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('完整梯度投料方案'), findsOneWidget);
        expect(find.text('7 个条件 × 2 次重复 · 2 组不可行'), findsOneWidget);
        if (size.width > 1000) {
          final table = tester.widget<DataTable>(
            find.byKey(const ValueKey('history-gradient-overview-table')),
          );
          expect(table.rows, hasLength(5));
          expect((table.rows[0].cells[3].child as Text).data, '0.000 µL');
          expect((table.rows[1].cells[3].child as Text).data, '2.596 µL');
          expect((table.rows[2].cells[3].child as Text).data, '2.596 µL');
          expect(
            tester
                .widget<Text>(
                  find.byKey(const ValueKey('gradient-stock-mass-1')),
                )
                .data,
            '1.000 mg/mL',
          );
          await tester.ensureVisible(
            find.byKey(const ValueKey('gradient-details-1')),
          );
          await tester.tap(find.byKey(const ValueKey('gradient-details-1')));
          await tester.pumpAndSettle();
          expect(find.text('单次反应完整明细'), findsOneWidget);
          expect(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.text('66.667 µM\n25.959 µg/mL'),
            ),
            findsOneWidget,
          );
          await tester.tap(find.text('关闭'));
          await tester.pumpAndSettle();
        }
        final next = find.byKey(const ValueKey('history-gradient-next-page'));
        await tester.ensureVisible(next);
        await tester.tap(next);
        await tester.pumpAndSettle();
        expect(find.text('第 2 / 2 页'), findsOneWidget);
        expect(find.byKey(const ValueKey('gradient-group-5')), findsOneWidget);
        expect(find.byKey(const ValueKey('gradient-group-6')), findsOneWidget);
        final copy = find.byKey(const ValueKey('history-gradient-copy'));
        await tester.ensureVisible(copy);
        await tester.tap(copy);
        await tester.pumpAndSettle();
        expect(copied.single, contains('条件 1：0.000 eq'));
        expect(copied.single, contains('条件 3：10.000 eq'));
        expect(copied.single, contains('条件 6：bad eq'));
        expect(copied.single, contains('条件 7：1000000.000 eq'));
        expect(copied.single, contains('未计入 2 个不可执行条件'));
        final actions = tester.widget<RecordActions>(
          find.byType(RecordActions),
        );
        final markdown = actions.buildMarkdown();
        expect(markdown, contains('### 条件 7'));
        expect(markdown, contains('25.959 µg/mL'));
        expect(markdown, contains('配制总体积'));
        expect(
          tester
              .widget<Text>(
                find.byKey(const ValueKey('history-gradient-total-0')),
              )
              .data,
          '550.000 µL',
        );
        expect(database.saveRequests, isEmpty);
        expect(database.records, hasLength(1));
        expect(input.toJson().toString(), before);
        expect(container.read(calculatorProvider), same(calculatorBefore));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'unreconstructable history reports an error and keeps saved inputs',
    (tester) async {
      final valid = gradientHistoryInput();
      final broken = CalculationInputSnapshot(
        reactionVolume: 'broken',
        reactionVolumeUnit: valid.reactionVolumeUnit,
        ratioType: true,
        substrates: valid.substrates,
        gradient: valid.gradient,
      );
      final database = FakeDatabase()
        ..records.add(gradientHistoryRecord(broken));
      await tester.pumpWidget(
        ProviderScope(
          overrides: [appDatabaseProvider.overrideWithValue(database)],
          child: const MaterialApp(home: HistoryDetailScreen(recordId: 1)),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('history-gradient-error')),
        findsOneWidget,
      );
      expect(find.text('完整梯度条件'), findsOneWidget);
      expect(
        find.text('0.000 eq、10.000 eq、15.000 eq、20.000 eq'),
        findsOneWidget,
      );
      expect(database.saveRequests, isEmpty);
      expect(tester.takeException(), isNull);
    },
  );
}
