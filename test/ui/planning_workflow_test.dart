import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/app.dart';
import 'package:ilovebioconjugation/data/app_database.dart';
import 'package:ilovebioconjugation/export/markdown_export_service.dart';
import 'package:ilovebioconjugation/theme/app_theme.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_screen.dart';
import 'package:ilovebioconjugation/ui/planning/record_actions.dart';
import 'package:ilovebioconjugation/ui/settings/app_settings.dart';
import 'package:ilovebioconjugation/ui/settings/settings_screen.dart';

import '../state/fake_database.dart';

class _MemorySettingsStore implements AppSettingsStore {
  AppSettings? saved;

  @override
  Future<AppSettings> load() async => const AppSettings();

  @override
  Future<void> save(AppSettings settings) async => saved = settings;
}

void _setSize(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

/// Two well-defined molar inputs: 10 µL reference stock, 0.1 µL reagent.
/// Tests use the real solver and notifier so a dialog cannot hide stale state.
void _prepareInputs(CalculatorNotifier notifier, {bool allSlots = false}) {
  notifier.setReactionVolume('100');
  notifier.setSubstrateField(0, 'name', 'IgG');
  notifier.setSubstrateField(0, 'mw', '150');
  notifier.setSubstrateField(0, 'mwUnit', 'kDa');
  notifier.setSubstrateField(0, 'storageConc', '10');
  notifier.setSubstrateField(0, 'storageUnit', 'uM');
  notifier.setSubstrateField(0, 'finalConc', '1');
  notifier.setSubstrateField(0, 'finalUnit', 'uM');
  notifier.setSubstrateField(1, 'name', 'TCEP');
  notifier.setSubstrateField(1, 'mw', '286.65');
  notifier.setSubstrateField(1, 'storageConc', '10');
  notifier.setSubstrateField(1, 'storageUnit', 'mM');
  notifier.setSubstrateField(1, 'reactionRatio', '10');
  if (allSlots) {
    for (var slot = 2; slot < 4; slot++) {
      notifier.toggleSubstrateEnabled(slot);
      notifier.setSubstrateField(slot, 'name', slot == 2 ? 'Linker' : 'Probe');
      notifier.setSubstrateField(slot, 'mw', '500');
      notifier.setSubstrateField(slot, 'storageConc', '10');
      notifier.setSubstrateField(slot, 'storageUnit', 'mM');
      notifier.setSubstrateField(slot, 'reactionRatio', '${slot * 10}');
    }
  }
}

Future<ProviderContainer> _pumpWorkspace(
  WidgetTester tester, {
  Size size = const Size(1366, 768),
  double scale = 1,
  bool allSlots = false,
}) async {
  _setSize(tester, size);
  final container = ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(FakeDatabase()),
      appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
    ],
  );
  addTearDown(container.dispose);
  _prepareInputs(
    container.read(calculatorProvider.notifier),
    allSlots: allSlots,
  );
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
        home: WorkspaceShell(
          selectedIndex: 0,
          onDestinationSelected: (_) {},
          child: const CalculatorScreen(),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

Future<void> _reveal(WidgetTester tester, Finder target) async {
  if (target.hitTestable().evaluate().isNotEmpty) return;
  if (target.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      target,
      300,
      scrollable: find
          .byWidgetPredicate(
            (widget) =>
                widget is Scrollable &&
                widget.axisDirection == AxisDirection.down,
          )
          .hitTestable()
          .last,
      maxScrolls: 50,
    );
  }
  await tester.ensureVisible(target);
}

Future<void> _enter(WidgetTester tester, Finder target, String text) async {
  await _reveal(tester, target);
  await tester.enterText(target, text);
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, Finder target) async {
  await _reveal(tester, target);
  await tester.pumpAndSettle();
  await tester.tap(target);
  await tester.pumpAndSettle();
}

Finder _key(String value) => find.byKey(ValueKey(value));

void main() {
  testWidgets(
    'desktop gradient overview fits five complete rows and opens stable details',
    (tester) async {
      final container = await _pumpWorkspace(tester, allSlots: true);
      await _tap(tester, _key('calculate-button'));
      await _tap(tester, _key('gradient-planning-button'));
      await _enter(tester, _key('gradient-values'), '0, 1, 2, 5, 10');
      await _tap(tester, _key('gradient-generate'));
      final plan = container.read(calculatorProvider).gradientPlan!;
      final overview = _key('gradient-overview-table');
      expect(overview, findsOneWidget);
      final table = tester.widget<DataTable>(overview);
      expect(table.rows, hasLength(5));
      expect(
        (table.rows[1].cells[1].child as Text).data,
        '1 µM\n286.65 ng/mL',
        reason:
            'Small scientifically meaningful mass concentrations are not rounded away',
      );
      expect(
        table.columns,
        hasLength(8),
        reason:
            'Target, paired final concentration, four aliquots, diluent and status',
      );
      final page = _key('gradient-result-page-0');
      final vertical = tester
          .stateList<ScrollableState>(
            find.descendant(of: page, matching: find.byType(Scrollable)),
          )
          .where((state) => state.position.axis == Axis.vertical);
      expect(vertical, hasLength(1));
      expect(
        vertical.single.position.maxScrollExtent,
        0,
        reason:
            'Five overview conditions fit the standard desktop without internal vertical scrolling',
      );
      final dialogRect = tester.getRect(find.byType(Dialog));
      final tableRect = tester.getRect(overview);
      expect(tableRect.bottom, lessThan(dialogRect.bottom));
      expect(tableRect.right, lessThanOrEqualTo(dialogRect.right));
      for (var index = 0; index < 5; index++) {
        expect(_key('gradient-group-$index').hitTestable(), findsOneWidget);
        expect(_key('gradient-details-$index').hitTestable(), findsOneWidget);
        final rowRect = tester.getRect(_key('gradient-group-$index'));
        expect(rowRect.top, greaterThanOrEqualTo(tableRect.top));
        expect(rowRect.bottom, lessThanOrEqualTo(tableRect.bottom));
      }
      for (final opener in [
        _key('gradient-group-2'),
        _key('gradient-details-4'),
      ]) {
        await _tap(tester, opener);
        expect(find.text('单次反应完整明细'), findsOneWidget);
        final detail = find.byType(AlertDialog);
        final detailTable = tester.widget<DataTable>(
          find.descendant(of: detail, matching: find.byType(DataTable)),
        );
        expect(detailTable.rows, hasLength(4));
        expect(detailTable.columns, hasLength(5));
        for (final name in ['IgG', 'TCEP', 'Linker', 'Probe']) {
          expect(
            find.descendant(of: detail, matching: find.text(name)),
            findsOneWidget,
          );
        }
        expect(container.read(calculatorProvider).gradientPlan, same(plan));
        await _tap(tester, find.text('关闭'));
        expect(find.byType(AlertDialog), findsNothing);
        expect(overview, findsOneWidget);
        expect(container.read(calculatorProvider).gradientPlan, same(plan));
      }
      expect(tester.takeException(), isNull);
    },
  );

  for (final size in [const Size(1366, 768), const Size(390, 844)]) {
    testWidgets(
      'zero-reference results never claim a normalized ratio at $size',
      (tester) async {
        final container = await _pumpWorkspace(tester, size: size);
        final notifier = container.read(calculatorProvider.notifier);
        for (final slot in [0, 1]) {
          notifier.setSubstrateField(slot, 'finalConc', '0');
          notifier.setSubstrateField(slot, 'storageVolume', '0');
        }
        await tester.pumpAndSettle();
        await _tap(tester, _key('calculate-button'));
        final result = container.read(calculatorProvider).rawResult;
        expect(result, isNotNull);
        expect(result!.substrateAt(0).ratio, isNull);
        expect(result.substrateAt(1).ratio, isNull);
        expect(
          container.read(calculatorProvider).rows.map((row) => row.ratio),
          ['N/A', 'N/A'],
        );
        if (size.width > 1000) {
          expect(find.text('N/A'), findsNWidgets(2));
        } else {
          expect(
            find.byWidgetPredicate(
              (widget) =>
                  widget is Text &&
                  widget.textSpan?.toPlainText() == '投料比  N/A',
            ),
            findsNWidgets(2),
          );
        }
        expect(find.text('基准 IgG = 1 · 请核对取样量'), findsNothing);
        expect(find.text('计算结果 · 基准 IgG = 1'), findsNothing);
        if (size.width > 1000) {
          await _tap(tester, _key('result-warning-details'));
          expect(find.text('请核对计算提醒'), findsOneWidget);
          expect(find.text('参照试剂用量为 0，投料比不适用。'), findsOneWidget);
          await _tap(tester, find.text('关闭'));
        } else {
          expect(find.text('计算结果 · 基准 IgG 为 0，比值不适用'), findsOneWidget);
          expect(find.text('参照试剂用量为 0，投料比不适用。'), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'batch history restores adopted working stock through unchanged regeneration',
    (tester) async {
      _setSize(tester, const Size(1366, 900));
      final database = FakeDatabase();
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(database),
          appSettingsStoreProvider.overrideWithValue(_MemorySettingsStore()),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(calculatorProvider.notifier);
      _prepareInputs(notifier, allSlots: true);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const App()),
      );
      await tester.pumpAndSettle();
      await _tap(tester, _key('calculate-button'));
      await _tap(tester, _key('gradient-planning-button'));
      await _enter(tester, _key('gradient-values'), '0, 1, 2, bad');
      await _enter(tester, _key('gradient-replicates'), '3');
      await _enter(tester, _key('gradient-extra'), '12.34567');
      await _tap(tester, _key('gradient-generate'));
      expect(
        database.records.where(
          (record) => record.inputSnapshot?.gradient != null,
        ),
        hasLength(1),
        reason: 'A whole batch is saved as one linked history record',
      );
      await _tap(tester, find.text('备液汇总'));
      await _enter(tester, _key('gradient-stock-diluent'), 'PBS');
      await _tap(tester, _key('gradient-stock-preview'));
      await _tap(tester, _key('gradient-stock-adopt'));
      final adopted = container.read(calculatorProvider).gradientPlan!;
      expect(adopted.workingStocks, hasLength(1));
      expect(adopted.spec.extraPreparationFraction, 0.1234567);
      expect(
        container.read(calculatorProvider).gradientWorkingStocks,
        hasLength(1),
      );
      for (final group in adopted.groups.where((group) => group.isValid)) {
        expect(group.result!.substrateAt(1).stockMolarMm, closeTo(0.1, 1e-12));
      }
      expect(
        database.records.last.inputSnapshot!.gradient!.workingStocks,
        hasLength(1),
      );
      await _tap(tester, find.byTooltip('关闭梯度方案'));
      notifier.setReactionVolume('777');
      await tester.pumpAndSettle();
      await _tap(tester, find.text('历史记录'));
      await _tap(tester, find.textContaining('梯度 4 条件 × 3').first);
      expect(find.text('完整梯度条件'), findsOneWidget);
      expect(find.text('0、1、2、bad eq'), findsOneWidget);
      expect(find.text('12.3457%（只用于备液）'), findsOneWidget);
      await _tap(tester, find.text('恢复计算'));
      expect(find.text('单因素梯度方案'), findsOneWidget);
      expect(container.read(calculatorProvider).reactionVolume, '100');
      expect(container.read(calculatorProvider).gradientPlan, isNull);
      expect(
        container.read(calculatorProvider).gradientWorkingStocks,
        hasLength(1),
      );
      expect(
        tester.widget<TextField>(_key('gradient-values')).controller!.text,
        '0, 1, 2, bad',
      );
      expect(
        tester.widget<TextField>(_key('gradient-replicates')).controller!.text,
        '3',
      );
      expect(
        double.parse(
          tester.widget<TextField>(_key('gradient-extra')).controller!.text,
        ),
        closeTo(12.34567, 1e-12),
      );
      expect(_key('copy-batch-button'), findsNothing);
      await _tap(tester, find.text('计算当前条件'));
      await _tap(tester, _key('gradient-generate'));
      for (var generation = 0; generation < 2; generation++) {
        final plan = container.read(calculatorProvider).gradientPlan!;
        expect(plan.groups, hasLength(4));
        expect(plan.totals.validGroupCount, 3);
        expect(plan.totals.failedGroupCount, 1);
        expect(plan.spec.replicates, 3);
        expect(
          plan.spec.extraPreparationFraction,
          adopted.spec.extraPreparationFraction,
        );
        expect(plan.workingStocks, hasLength(1));
        expect(
          container.read(calculatorProvider).gradientWorkingStocks,
          hasLength(1),
        );
        expect(
          container
              .read(calculatorProvider)
              .rawResult!
              .substrateAt(1)
              .stockMolarMm,
          10,
          reason: 'The baseline keeps its original mother stock',
        );
        for (var index = 0; index < plan.groups.length; index++) {
          if (!plan.groups[index].isValid) continue;
          final expected = adopted.groups[index].result!;
          final actual = plan.groups[index].result!;
          expect(
            actual.substrateAt(1).stockMolarMm,
            closeTo(0.1, 1e-12),
            reason:
                'Every batch group keeps the adopted stock after restore and regenerate',
          );
          expect(
            actual.substrateAt(1).aliquotMl,
            closeTo(expected.substrateAt(1).aliquotMl, 1e-12),
          );
          expect(
            actual.diluentVolumeMl,
            closeTo(expected.diluentVolumeMl, 1e-12),
          );
        }
        if (generation == 0) {
          await _tap(tester, find.text('条件设置'));
          await _tap(tester, _key('gradient-generate'));
        }
      }
      await _tap(tester, find.byTooltip('关闭梯度方案'));
      await _tap(tester, find.text('投料计算'));
      expect(find.text('单因素梯度方案'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'common working stock recomputes every gradient group and preserves zero',
    (tester) async {
      final container = await _pumpWorkspace(tester, allSlots: true);
      await _tap(tester, _key('calculate-button'));
      await _tap(tester, _key('gradient-planning-button'));
      await _enter(tester, _key('gradient-values'), '0, 1, 2, 5');
      await _enter(tester, _key('gradient-replicates'), '3');
      await _enter(tester, _key('gradient-extra'), '10');
      await _tap(tester, _key('gradient-generate'));
      final before = container.read(calculatorProvider).gradientPlan!;
      await _tap(tester, find.text('备液汇总'));
      await _tap(tester, _key('gradient-stock-preview'));
      expect(find.text('请先指定工作液使用的稀释液'), findsOneWidget);
      await _enter(tester, _key('gradient-stock-diluent'), 'PBS');
      await _tap(tester, _key('gradient-stock-preview'));
      await _reveal(tester, _key('gradient-stock-adopt'));
      expect(_key('gradient-stock-adopt'), findsOneWidget);
      await _tap(tester, _key('gradient-stock-adopt'));
      final after = container.read(calculatorProvider).gradientPlan!;
      expect(after, isNot(same(before)));
      expect(after.groups, hasLength(4));
      expect(after.spec.replicates, 3);
      expect(after.spec.extraPreparationFraction, 0.1);
      expect(after.groups.first.result!.substrateAt(1).aliquotMl, 0);
      for (var index = 0; index < before.groups.length; index++) {
        final previous = before.groups[index].result!;
        final next = after.groups[index].result!;
        expect(next.totalVolumeMl, previous.totalVolumeMl);
        for (final slot in [0, 1, 2, 3]) {
          expect(
            next.substrateAt(slot).finalMolarMm,
            closeTo(previous.substrateAt(slot).finalMolarMm!, 1e-12),
          );
        }
        if (index > 0) {
          expect(
            next.substrateAt(1).aliquotMl,
            greaterThanOrEqualTo(0.001 - 1e-12),
          );
        }
      }
      expect(
        container.read(calculatorProvider).gradientWorkingStocks,
        hasLength(1),
      );
      expect(after.workingStocks, hasLength(1));
      expect(
        container.read(calculatorProvider).rawResult,
        same(before.baseline),
      );
      await _tap(tester, find.text('备液汇总'));
      await _tap(tester, _key('gradient-stock-preview'));
      expect(
        _key('gradient-stock-adopt'),
        findsNothing,
        reason:
            'The adopted common stock already meets the pipetting threshold',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'manual gradient retains zero, duplicate and invalid points across pages',
    (tester) async {
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
      final container = await _pumpWorkspace(tester, allSlots: true);
      await _tap(tester, _key('calculate-button'));
      final baseline = container.read(calculatorProvider).rawResult!;
      await _tap(tester, _key('gradient-planning-button'));
      await _enter(
        tester,
        _key('gradient-values'),
        '0, 1, 2, 2, 1000000, bad, 4',
      );
      await _enter(tester, _key('gradient-replicates'), '3');
      await _enter(tester, _key('gradient-extra'), '10');
      await _tap(tester, _key('gradient-zero-control'));
      await _tap(tester, _key('gradient-generate'));
      final plan = container.read(calculatorProvider).gradientPlan!;
      expect(plan.groups, hasLength(7));
      expect(plan.groups.map((group) => group.pointText), [
        '0',
        '1',
        '2',
        '2',
        '1000000',
        'bad',
        '4',
      ]);
      expect(plan.groups.first.result!.substrateAt(1).aliquotMl, 0);
      expect(
        plan.groups.first.result!.warnings.where(
          (warning) => warning.slot == 1,
        ),
        isEmpty,
      );
      expect(plan.totals.validGroupCount, 5);
      expect(plan.totals.failedGroupCount, 2);
      expect(plan.totals.reactionCount, 15);
      expect(plan.totals.totalVolumeMl, closeTo(1.65, 1e-12));
      for (final group in plan.groups.where((group) => group.isValid)) {
        expect(group.result!.totalVolumeMl, baseline.totalVolumeMl);
        for (final slot in [0, 2, 3]) {
          expect(
            group.result!.substrateAt(slot).finalMolarMm,
            baseline.substrateAt(slot).finalMolarMm,
          );
        }
      }
      await _tap(tester, _key('gradient-next-page'));
      expect(find.text('第 2 / 2 页'), findsOneWidget);
      expect(_key('gradient-group-5'), findsOneWidget);
      expect(
        tester.widget<IconButton>(_key('gradient-next-page')).onPressed,
        isNull,
      );
      await _tap(tester, _key('copy-batch-button'));
      expect(copied, hasLength(1));
      for (final point in ['1000000', 'bad']) {
        expect(copied.single, contains(point));
      }
      expect(copied.single, contains('IgG'));
      await _tap(tester, find.text('备液汇总'));
      expect(find.text('备液汇总 · 仅包含有效组'), findsOneWidget);
      expect(find.textContaining('15 次反应'), findsOneWidget);
      await _tap(tester, find.text('条件设置'));
      await _enter(tester, _key('gradient-values'), '1, 3, 5');
      expect(container.read(calculatorProvider).gradientPlan, isNull);
      expect(_key('copy-batch-button'), findsNothing);
      await _tap(tester, _key('gradient-generate'));
      expect(
        container.read(calculatorProvider).gradientPlan!.groups,
        hasLength(4),
      );
      await _tap(tester, find.byTooltip('关闭梯度方案'));
      await _tap(tester, _key('gradient-planning-button'));
      expect(
        tester.widget<TextField>(_key('gradient-values')).controller!.text,
        '0, 1, 3, 5',
      );
      expect(tester.takeException(), isNull);
    },
  );

  for (final generator in [
    ('等差生成', '0', '2', [0.0, 2.0, 4.0, 6.0]),
    ('等比生成', '1', '2', [1.0, 2.0, 4.0, 8.0]),
  ]) {
    testWidgets('${generator.$1} creates the visible points before solving', (
      tester,
    ) async {
      final container = await _pumpWorkspace(tester);
      await _tap(tester, _key('calculate-button'));
      await _tap(tester, _key('gradient-planning-button'));
      await _tap(tester, _key('gradient-generator'));
      await _tap(tester, find.text(generator.$1).last);
      await _enter(tester, _key('gradient-start'), generator.$2);
      await _enter(tester, _key('gradient-step-or-factor'), generator.$3);
      await _enter(tester, _key('gradient-count'), '4');
      await _tap(tester, _key('gradient-generate-points'));
      final points = tester
          .widget<TextField>(_key('gradient-values'))
          .controller!
          .text
          .split(',')
          .map((value) => double.parse(value.trim()));
      expect(points, generator.$4);
      await _tap(tester, _key('gradient-generate'));
      final plan = container.read(calculatorProvider).gradientPlan!;
      expect(plan.groups.map((group) => group.pointValue), generator.$4);
      expect(plan.totals.failedGroupCount, 0);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
    'gradient validates replicates, extra percentage and geometric controls',
    (tester) async {
      final container = await _pumpWorkspace(tester);
      await _tap(tester, _key('calculate-button'));
      await _tap(tester, _key('gradient-planning-button'));
      for (final invalid in ['0', '1.5', 'bad']) {
        await _enter(tester, _key('gradient-replicates'), invalid);
        await _tap(tester, _key('gradient-generate'));
        expect(container.read(calculatorProvider).gradientPlan, isNull);
        expect(find.textContaining('重复数须为正整数'), findsOneWidget);
      }
      await _enter(tester, _key('gradient-replicates'), '1');
      for (final invalid in ['-1', 'NaN', 'Infinity']) {
        await _enter(tester, _key('gradient-extra'), invalid);
        await _tap(tester, _key('gradient-generate'));
        expect(container.read(calculatorProvider).gradientPlan, isNull);
        expect(find.textContaining('额外配制比例须'), findsOneWidget);
      }
      await _enter(tester, _key('gradient-extra'), '0');
      await _tap(tester, _key('gradient-generator'));
      await _tap(tester, find.text('等比生成').last);
      await _enter(tester, _key('gradient-start'), '0');
      await _tap(tester, _key('gradient-generate-points'));
      expect(find.textContaining('等比梯度的起点和倍数必须大于 0'), findsOneWidget);
      await _enter(tester, _key('gradient-start'), '1');
      await _enter(tester, _key('gradient-count'), '1001');
      await _tap(tester, _key('gradient-generate-points'));
      expect(find.textContaining('梯度点数必须为 1 至 1000'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('concentration mode changes the selected stable slot only', (
    tester,
  ) async {
    final container = await _pumpWorkspace(tester, allSlots: true);
    await _tap(tester, _key('calculate-button'));
    final baseline = container.read(calculatorProvider).rawResult!;
    await _tap(tester, _key('gradient-planning-button'));
    await _tap(tester, _key('gradient-slot'));
    await _tap(tester, find.text('Linker').last);
    await _tap(tester, _key('gradient-mode'));
    await _tap(tester, find.text('目标终浓度').last);
    await _enter(tester, _key('gradient-values'), '0, 5, 10');
    await _tap(tester, _key('gradient-generate'));
    final plan = container.read(calculatorProvider).gradientPlan!;
    expect(plan.spec.selectedSlot, 2);
    expect(plan.spec.unit, 'uM');
    expect(
      plan.groups[1].result!.substrateAt(2).finalMolarMm,
      closeTo(0.005, 1e-12),
    );
    expect(
      plan.groups[1].result!.substrateAt(1).finalMolarMm,
      baseline.substrateAt(1).finalMolarMm,
    );
    expect(
      plan.groups[1].result!.substrateAt(0).aliquotMl,
      baseline.substrateAt(0).aliquotMl,
    );
    expect(tester.takeException(), isNull);
  });

  for (final screen in [
    (const Size(320, 844), 1.0),
    (const Size(390, 1000), 2.0),
    (const Size(1366, 768), 1.0),
    (const Size(1366, 900), 2.0),
  ]) {
    testWidgets(
      'planning dialogs remain usable at ${screen.$1}, ${screen.$2}x text',
      (tester) async {
        final container = await _pumpWorkspace(
          tester,
          size: screen.$1,
          scale: screen.$2,
          allSlots: true,
        );
        await _tap(tester, _key('calculate-button'));
        await _tap(tester, _key('low-volume-3'));
        await _enter(tester, _key('working-stock-diluent'), 'PBS');
        await _tap(tester, _key('working-stock-preview'));
        expect(
          tester.widget<FilledButton>(_key('working-stock-adopt')).onPressed,
          isNotNull,
        );
        expect(tester.takeException(), isNull);
        await _tap(tester, find.text('取消'));
        await _tap(tester, _key('gradient-planning-button'));
        for (final label in ['条件设置', '逐组结果', '备液汇总']) {
          final paragraph = tester.renderObject<RenderParagraph>(
            find.text(label),
          );
          expect(
            paragraph.didExceedMaxLines,
            isFalse,
            reason: 'Gradient tab labels remain readable with enlarged text',
          );
        }
        await _enter(tester, _key('gradient-values'), '0, 1, 2, 4, 8, 16');
        await _tap(tester, _key('gradient-generate'));
        expect(
          container.read(calculatorProvider).gradientPlan!.groups,
          hasLength(6),
        );
        expect(tester.takeException(), isNull);
        await _tap(tester, _key('gradient-next-page'));
        expect(find.text('第 2 / 2 页'), findsOneWidget);
        await _tap(tester, find.byTooltip('关闭梯度方案'));
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'threshold changes refresh warnings and zero disables warning actions',
    (tester) async {
      final container = await _pumpWorkspace(tester);
      await _tap(tester, _key('calculate-button'));
      expect(_key('low-volume-1'), findsOneWidget);
      final baseline = container.read(calculatorProvider).rawResult!;
      await container
          .read(appSettingsProvider.notifier)
          .setMinimumPipettingVolumeUl(0);
      await tester.pumpAndSettle();
      expect(_key('low-volume-1'), findsNothing);
      expect(container.read(calculatorProvider).rawResult, isNotNull);
      expect(
        container.read(calculatorProvider).rawResult!.totalVolumeMl,
        baseline.totalVolumeMl,
      );
      await container
          .read(appSettingsProvider.notifier)
          .setMinimumPipettingVolumeUl(0.2);
      await tester.pumpAndSettle();
      expect(_key('low-volume-1'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'working-stock cancel and repeat preserve dose; adopt uses fresh recipe',
    (tester) async {
      final container = await _pumpWorkspace(tester);
      await _tap(tester, _key('calculate-button'));
      final baseline = container.read(calculatorProvider).rawResult!;
      final originalInputs = container
          .read(calculatorProvider)
          .substrates
          .map((input) => input.toSnapshot().toJson())
          .toList();
      expect(baseline.substrateAt(1).aliquotMl, closeTo(0.0001, 1e-12));
      for (var repeat = 0; repeat < 2; repeat++) {
        await _tap(tester, _key('low-volume-1'));
        await _enter(tester, _key('working-stock-diluent'), 'PBS');
        await _enter(tester, _key('working-stock-factor'), '20');
        await _tap(tester, _key('working-stock-preview'));
        expect(find.textContaining('20 倍稀释'), findsOneWidget);
        await _tap(tester, find.text('取消'));
        expect(container.read(calculatorProvider).rawResult, same(baseline));
        expect(container.read(calculatorProvider).workingStocks, isEmpty);
        expect(
          container
              .read(calculatorProvider)
              .substrates
              .map((input) => input.toSnapshot().toJson())
              .toList(),
          originalInputs,
        );
      }
      await _tap(tester, _key('low-volume-1'));
      expect(
        tester.widget<TextField>(_key('working-stock-factor')).controller!.text,
        isEmpty,
      );
      await _enter(tester, _key('working-stock-diluent'), 'PBS');
      await _enter(tester, _key('working-stock-factor'), '20');
      await _enter(tester, _key('working-stock-extra'), '10');
      await _tap(tester, _key('working-stock-preview'));
      await _tap(tester, _key('working-stock-adopt'));
      expect(find.byType(AlertDialog), findsNothing);
      final state = container.read(calculatorProvider);
      final result = state.rawResult!;
      expect(result.totalVolumeMl, baseline.totalVolumeMl);
      expect(result.substrateAt(1).aliquotMl, closeTo(0.002, 1e-12));
      expect(result.substrateAt(1).stockMolarMm, closeTo(0.5, 1e-12));
      expect(
        result.substrateAt(1).finalMolarMm,
        closeTo(baseline.substrateAt(1).finalMolarMm!, 1e-12),
      );
      expect(
        result.substrateAt(0).aliquotMl,
        closeTo(baseline.substrateAt(0).aliquotMl, 1e-12),
      );
      expect(state.workingStocks, hasLength(1));
      expect(state.workingStocks.single.diluentName, 'PBS');
      expect(_key('low-volume-1'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('invalid and stale working-stock previews cannot be adopted', (
    tester,
  ) async {
    final container = await _pumpWorkspace(tester);
    await _tap(tester, _key('calculate-button'));
    await _tap(tester, _key('low-volume-1'));
    await _tap(tester, _key('working-stock-preview'));
    expect(find.text('请指定实际使用的稀释液'), findsOneWidget);
    await _enter(tester, _key('working-stock-diluent'), 'PBS');
    await _enter(tester, _key('working-stock-factor'), '-1');
    await _tap(tester, _key('working-stock-preview'));
    expect(
      tester.widget<FilledButton>(_key('working-stock-adopt')).onPressed,
      isNull,
    );
    await _enter(tester, _key('working-stock-factor'), '10000');
    await _tap(tester, _key('working-stock-preview'));
    expect(find.text('方案不可行'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(_key('working-stock-adopt')).onPressed,
      isNull,
    );
    await _enter(tester, _key('working-stock-factor'), '20');
    await _tap(tester, _key('working-stock-preview'));
    expect(
      tester.widget<FilledButton>(_key('working-stock-adopt')).onPressed,
      isNotNull,
    );
    container.read(calculatorProvider.notifier).setReactionVolume('200');
    await tester.pumpAndSettle();
    expect(find.text('原始计算已变化，请重新计算工作液方案。'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(_key('working-stock-adopt')).onPressed,
      isNull,
    );
    await _tap(tester, find.text('取消'));
    expect(container.read(calculatorProvider).workingStocks, isEmpty);
    expect(container.read(calculatorProvider).rawResult, isNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'reference selection retains slot identity and recalculates same quantities',
    (tester) async {
      final container = await _pumpWorkspace(tester, allSlots: true);
      await _tap(tester, _key('calculate-button'));
      final baseline = container.read(calculatorProvider).rawResult!;
      await _tap(tester, _key('ratio-reference-selector'));
      await _tap(tester, find.text('Linker = 1').last);
      var state = container.read(calculatorProvider);
      expect(state.referenceSlot, 2);
      expect(state.substrates[2].name, 'Linker');
      expect(state.substrates[2].reactionRatio, '1');
      expect(
        double.parse(state.substrates[0].reactionRatio),
        closeTo(0.05, 1e-12),
      );
      expect(state.rawResult, isNull);
      expect(
        tester
            .widget<PopupMenuButton<String>>(_key('record-menu-button'))
            .enabled,
        isFalse,
      );
      await _tap(tester, _key('calculate-button'));
      state = container.read(calculatorProvider);
      expect(state.rawResult!.referenceSlot, 2);
      for (final previous in baseline.substrates) {
        final current = state.rawResult!.substrateAt(previous.slot);
        expect(current.name, previous.name);
        expect(current.aliquotMl, closeTo(previous.aliquotMl, 1e-12));
        expect(current.finalMolarMm, closeTo(previous.finalMolarMm!, 1e-12));
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'record copy, canceled export and repeated export use fresh snapshot',
    (tester) async {
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
      var selectCount = 0;
      final written = <String>[];
      var markdown = '# First reaction';
      Object? token = Object();
      late StateSetter rebuild;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            markdownExportServiceProvider.overrideWithValue(
              NativeMarkdownExportService(
                supported: true,
                selectPath: (_) async =>
                    ++selectCount == 1 ? null : '/tmp/record.md',
                writeFile: (_, contents) async => written.add(contents),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return RecordActions(
                    resultToken: token,
                    buildMarkdown: () => markdown,
                  );
                },
              ),
            ),
          ),
        ),
      );
      await _tap(tester, _key('record-menu-button'));
      await _tap(tester, find.text('复制完整 Markdown'));
      expect(copied, ['# First reaction']);
      await _tap(tester, _key('record-menu-button'));
      await _tap(tester, find.text('导出 .md 文件'));
      expect(written, isEmpty);
      expect(
        tester
            .widget<PopupMenuButton<String>>(_key('record-menu-button'))
            .enabled,
        isTrue,
      );
      rebuild(() {
        markdown = '# Updated reaction';
        token = Object();
      });
      await tester.pumpAndSettle();
      for (var repeat = 0; repeat < 2; repeat++) {
        await _tap(tester, _key('record-menu-button'));
        await _tap(tester, find.text('导出 .md 文件'));
      }
      expect(written, ['# Updated reaction', '# Updated reaction']);
      expect(selectCount, 3);
      rebuild(() => token = null);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<PopupMenuButton<String>>(_key('record-menu-button'))
            .enabled,
        isFalse,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'delayed export rejects a result invalidated while file picker is open',
    (tester) async {
      final path = Completer<String?>();
      final written = <String>[];
      Object? token = Object();
      late StateSetter rebuild;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            markdownExportServiceProvider.overrideWithValue(
              NativeMarkdownExportService(
                supported: true,
                selectPath: (_) => path.future,
                writeFile: (_, contents) async => written.add(contents),
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) {
                  rebuild = setState;
                  return RecordActions(
                    resultToken: token,
                    buildMarkdown: () => '# Result',
                  );
                },
              ),
            ),
          ),
        ),
      );
      await _tap(tester, _key('record-menu-button'));
      await tester.tap(find.text('导出 .md 文件'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester
            .widget<PopupMenuButton<String>>(_key('record-menu-button'))
            .enabled,
        isFalse,
      );
      rebuild(() => token = null);
      await tester.pump();
      path.complete('/tmp/stale-record.md');
      await tester.pumpAndSettle();
      expect(written, isEmpty);
      expect(find.textContaining('计算已变化'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'invalid pipetting thresholds preserve saved setting; zero disables',
    (tester) async {
      _setSize(tester, const Size(390, 844));
      final store = _MemorySettingsStore();
      final container = ProviderContainer(
        overrides: [appSettingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AppTheme.light,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final field = _key('minimum-pipetting-setting');
      for (final invalid in ['', '-1', 'NaN', 'Infinity', 'not a number']) {
        await tester.ensureVisible(field);
        await tester.enterText(field, invalid);
        await _tap(tester, find.text('保存阈值'));
        expect(find.text('请输入大于或等于 0 的有限数字'), findsOneWidget);
        expect(container.read(appSettingsProvider).minimumPipettingVolumeUl, 1);
        expect(store.saved, isNull);
        expect(tester.takeException(), isNull);
      }
      await tester.enterText(field, '0');
      await _tap(tester, find.text('保存阈值'));
      expect(container.read(appSettingsProvider).minimumPipettingVolumeUl, 0);
      expect(store.saved!.minimumPipettingVolumeUl, 0);
      expect(find.text('请输入大于或等于 0 的有限数字'), findsNothing);
      await tester.enterText(field, '2.5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(store.saved!.minimumPipettingVolumeUl, 2.5);
      expect(tester.takeException(), isNull);
    },
  );
}
