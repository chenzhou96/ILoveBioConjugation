import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/app.dart';
import 'package:ilovebioconjugation/theme/app_theme.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_screen.dart';
import 'package:ilovebioconjugation/ui/calculator/state.dart';
import 'package:ilovebioconjugation/ui/calculator/widgets/chemical_card.dart';
import 'package:ilovebioconjugation/ui/calculator/widgets/chemical_field_row.dart';
import 'package:ilovebioconjugation/ui/calculator/widgets/result_data_table.dart';
import 'package:ilovebioconjugation/ui/calculator/widgets/result_metrics_row.dart';
import 'package:ilovebioconjugation/ui/calculator/widgets/status_banner.dart';

class _CompactFixtureNotifier extends CalculatorNotifier {
  @override
  CalculatorState build() => super.build().copyWith(
    reactionVolume: '100',
    substrates: List.generate(
      4,
      (index) => SubstrateInput(
        enabled: true,
        name: ['IgG', 'TCEP', 'Linker', 'Probe'][index],
        mw: index == 0 ? '150' : '500',
        mwUnit: 'kDa',
        storageConc: '10',
        storageUnit: 'mM',
        reactionRatio: '${index + 1}',
      ),
    ),
    statusMessage: '计算完成，请核对取样清单。',
    statusLevel: StatusLevel.success,
    metrics: const ResultMetrics(
      totalVolume: '100.00 uL',
      stockVolume: '20.00 uL',
      diluentVolume: '80.00 uL',
      substrateCount: '4',
    ),
    rows: List.generate(
      4,
      (index) => ResultRow(
        role: index == 0 ? '主底物' : '副底物$index',
        name: ['IgG', 'TCEP', 'Linker', 'Probe'][index],
        stock: '10.00 mM',
        stockMass: index == 0 ? '1.50 g/mL' : '5.00 g/mL',
        finalConc: '1.00 mM',
        finalConcMass: index == 0 ? '150.00 mg/mL' : '500.00 mg/mL',
        volume: '5.00 uL',
        volumePct: '5.00%',
        ratio: '${index + 1}.0000',
      ),
    ),
  );

  void showError({bool long = false}) => state = state.copyWith(
    rows: [],
    statusLevel: StatusLevel.error,
    statusMessage: '计算失败，请检查输入条件。',
    errorMessage: long
        ? List.filled(60, '请检查主底物浓度及其单位。').join()
        : '主底物母液浓度必须大于 0',
  );

  void showUnavailableConversions() => state = state.copyWith(
    rows: [
      for (var index = 0; index < state.rows.length; index++)
        ResultRow(
          role: state.rows[index].role,
          name: state.rows[index].name,
          stock: index.isEven ? state.rows[index].stock : '无法换算（缺少分子量）',
          stockMass: index.isEven ? '无法换算（缺少分子量）' : state.rows[index].stockMass,
          finalConc: index.isEven ? state.rows[index].finalConc : '无法换算（缺少分子量）',
          finalConcMass: index.isEven
              ? '无法换算（缺少分子量）'
              : state.rows[index].finalConcMass,
          volume: state.rows[index].volume,
          volumePct: state.rows[index].volumePct,
          ratio: state.rows[index].ratio,
        ),
    ],
  );

  void showSaveWarning() => state = state.copyWith(
    historySaveError: '本次计算成功，但历史记录未能保存到本机。请复制结果，检查磁盘空间后重试。',
  );
}

void main() {
  Future<ProviderContainer> pumpWorkspace(
    WidgetTester tester,
    Size size, {
    double scale = 1,
    bool populated = false,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final container = ProviderContainer(
      overrides: [
        if (populated)
          calculatorProvider.overrideWith(_CompactFixtureNotifier.new),
      ],
    );
    addTearDown(container.dispose);
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

  for (final width in [320.0, 390.0, 768.0, 1024.0, 1440.0, 1920.0]) {
    testWidgets('workspace lays out without overflow at $width pixels', (
      tester,
    ) async {
      await pumpWorkspace(tester, Size(width, 1000));
      expect(tester.takeException(), isNull);
      expect(
        find.byType(NavigationBar),
        width < 900 ? findsOneWidget : findsNothing,
      );
      expect(find.byKey(const ValueKey('calculate-button')), findsOneWidget);
      expect(
        tester
            .widget<OutlinedButton>(
              find.byKey(const ValueKey('copy-results-button')),
            )
            .onPressed,
        isNull,
      );
    });
  }

  void expectDesktopFits(WidgetTester tester, Size size) {
    final canvas = find.byKey(const ValueKey('desktop-workspace'));
    expect(canvas, findsOneWidget);
    expect(find.byKey(const ValueKey('desktop-result-table')), findsOneWidget);
    expect(find.byType(ChemicalCard), findsNWidgets(4));
    final fields = find.descendant(
      of: canvas,
      matching: find.byType(TextField),
    );
    expect(fields, findsNWidgets(25));
    for (final element in fields.evaluate()) {
      final rect = tester.getRect(find.byWidget(element.widget));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(size.width));
      expect(rect.top, greaterThanOrEqualTo(0));
      expect(rect.bottom, lessThanOrEqualTo(size.height));
    }
    final resultRect = tester.getRect(
      find.byKey(const ValueKey('desktop-result-table')),
    );
    expect(resultRect.bottom, lessThanOrEqualTo(size.height - 18));
    final table = tester.widget<Table>(
      find.byKey(const ValueKey('desktop-result-table')),
    );
    expect(
      table.children,
      hasLength(5),
    ); // Header plus all four real data rows.
    var previousBottom = resultRect.top;
    for (var index = 0; index < 4; index++) {
      expect(
        find.byKey(ValueKey('result-name-$index')).hitTestable(),
        findsOneWidget,
      );
      for (final field in ['stock', 'final']) {
        final pair = find.byKey(ValueKey('result-$field-$index'));
        final pairRect = tester.getRect(pair);
        expect(pairRect.top, greaterThanOrEqualTo(previousBottom));
        expect(pairRect.bottom, lessThanOrEqualTo(size.height - 18));
        expect(pairRect.left, greaterThanOrEqualTo(resultRect.left));
        expect(pairRect.right, lessThanOrEqualTo(resultRect.right));
        final lines = find.descendant(of: pair, matching: find.byType(Text));
        expect(lines, findsNWidgets(2));
        expect(lines.hitTestable(), findsNWidgets(2));
        final values = tester.widgetList<Text>(lines).map((line) => line.data!);
        expect(values.first, startsWith('摩尔 '));
        expect(values.last, startsWith('质量 '));
        for (final paragraph in tester.renderObjectList<RenderParagraph>(
          find.descendant(of: pair, matching: find.byType(RichText)),
        )) {
          expect(paragraph.didExceedMaxLines, isFalse);
          expect(
            paragraph.getBoxesForSelection(
              TextSelection(
                baseOffset: 0,
                extentOffset: paragraph.text.toPlainText().length,
              ),
            ),
            hasLength(1),
            reason: 'Each concentration stays on one full line',
          );
        }
      }
      previousBottom = tester
          .getRect(find.byKey(ValueKey('result-stock-$index')))
          .bottom;
    }
    for (final scrollable in tester.stateList<ScrollableState>(
      find.descendant(of: canvas, matching: find.byType(Scrollable)),
    )) {
      if (scrollable.position.axis == Axis.vertical) {
        expect(
          scrollable.position.maxScrollExtent,
          0,
          reason:
              'No desktop scrolling is needed for four reagents and four results',
        );
      }
    }
    expect(tester.takeException(), isNull);
  }

  for (final size in [const Size(1366, 768), const Size(1440, 900)]) {
    testWidgets('four reagent inputs and results fit $size without scrolling', (
      tester,
    ) async {
      await pumpWorkspace(tester, size, populated: true);
      expectDesktopFits(tester, size);
    });

    testWidgets('missing conversion labels fit all four rows at $size', (
      tester,
    ) async {
      final container = await pumpWorkspace(tester, size, populated: true);
      (container.read(calculatorProvider.notifier) as _CompactFixtureNotifier)
          .showUnavailableConversions();
      await tester.pumpAndSettle();
      expect(find.text('质量 无法换算（缺少分子量）'), findsNWidgets(4));
      expect(find.text('摩尔 无法换算（缺少分子量）'), findsNWidgets(4));
      expectDesktopFits(tester, size);
    });
  }

  testWidgets('desktop errors preserve the input matrix and show details', (
    tester,
  ) async {
    final container = await pumpWorkspace(
      tester,
      const Size(1366, 768),
      populated: true,
    );
    final before = tester.getRect(
      find.byKey(const ValueKey('desktop-input-matrix')),
    );
    (container.read(calculatorProvider.notifier) as _CompactFixtureNotifier)
        .showError();
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desktop-input-matrix')), findsOneWidget);
    expect(
      tester.getRect(find.byKey(const ValueKey('desktop-input-matrix'))),
      before,
    );
    expect(find.text('主底物母液浓度必须大于 0').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'unusually long error details scroll within results without clipping inputs',
    (tester) async {
      final container = await pumpWorkspace(
        tester,
        const Size(1366, 768),
        populated: true,
      );
      (container.read(calculatorProvider.notifier) as _CompactFixtureNotifier)
          .showError(long: true);
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('desktop-input-matrix')),
        findsOneWidget,
      );
      final view = tester.widget<SingleChildScrollView>(
        find.byKey(const ValueKey('desktop-results-scroll')),
      );
      expect(view.controller!.position.maxScrollExtent, greaterThan(0));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('history save warning keeps all desktop results visible', (
    tester,
  ) async {
    final container = await pumpWorkspace(
      tester,
      const Size(1366, 768),
      populated: true,
    );
    (container.read(calculatorProvider.notifier) as _CompactFixtureNotifier)
        .showSaveWarning();
    await tester.pumpAndSettle();
    expect(find.textContaining('历史记录未保存'), findsOneWidget);
    expectDesktopFits(tester, const Size(1366, 768));
  });

  testWidgets('long reference name does not stretch the desktop matrix', (
    tester,
  ) async {
    final container = await pumpWorkspace(
      tester,
      const Size(1366, 768),
      populated: true,
    );
    container
        .read(calculatorProvider.notifier)
        .setSubstrateField(
          0,
          'name',
          'A very long substrate reference name ' * 8,
        );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('desktop-input-matrix')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('enlarged desktop text uses accessible scrolling fallback', (
    tester,
  ) async {
    await pumpWorkspace(
      tester,
      const Size(1366, 768),
      populated: true,
      scale: 1.5,
    );
    expect(find.byKey(const ValueKey('desktop-workspace')), findsNothing);
    expect(
      tester
          .stateList<ScrollableState>(find.byType(Scrollable))
          .where((state) => state.position.axis == Axis.vertical)
          .any((state) => state.position.maxScrollExtent > 0),
      isTrue,
    );
    final last = find
        .descendant(
          of: find.byKey(const ValueKey('substrate-3')),
          matching: find.byType(TextField),
        )
        .last;
    await tester.ensureVisible(last);
    await tester.pumpAndSettle();
    expect(last.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'desktop toggles retain values and remove disabled controls from focus order',
    (tester) async {
      final container = await pumpWorkspace(
        tester,
        const Size(1366, 768),
        populated: true,
      );
      final row = find.byKey(const ValueKey('substrate-3'));
      final toggle = find.descendant(of: row, matching: find.byType(Checkbox));
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(container.read(calculatorProvider).substrates[3].enabled, isFalse);
      expect(
        find.descendant(of: row, matching: find.byType(TextField)),
        findsNothing,
      );
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(container.read(calculatorProvider).substrates[3].enabled, isTrue);
      expect(container.read(calculatorProvider).substrates[3].name, 'Probe');
      expect(
        find.descendant(of: row, matching: find.byType(TextField)),
        findsNWidgets(6),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop numeric fields and unit menus edit canonical state', (
    tester,
  ) async {
    final container = await pumpWorkspace(
      tester,
      const Size(1366, 768),
      populated: true,
    );
    final field = find.descendant(
      of: find.byKey(const ValueKey('substrate-0')),
      matching: find.byWidgetPredicate(
        (widget) => widget is ChemicalFieldRow && widget.label == '母液浓度',
      ),
    );
    final entry = find.descendant(of: field, matching: find.byType(TextField));
    await tester.enterText(entry, '25.5');
    await tester.pumpAndSettle();
    expect(
      container.read(calculatorProvider).substrates[0].storageConc,
      '25.5',
    );
    await tester.tap(
      find.descendant(of: field, matching: find.byType(DropdownButton<String>)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('µM').last);
    await tester.pumpAndSettle();
    expect(container.read(calculatorProvider).substrates[0].storageUnit, 'uM');
    expect(tester.takeException(), isNull);
  });

  testWidgets('desktop supports the largest saved text setting', (
    tester,
  ) async {
    await pumpWorkspace(tester, const Size(1440, 1100), scale: 1.5);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone supports large text', (tester) async {
    await pumpWorkspace(tester, const Size(390, 1000), scale: 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed calculation reveals actionable error on phone', (
    tester,
  ) async {
    final container = await pumpWorkspace(tester, const Size(390, 844));
    await tester.tap(find.byKey(const ValueKey('calculate-button')));
    await tester.pumpAndSettle();
    final state = container.read(calculatorProvider);
    expect(state.statusLevel, StatusLevel.error);
    expect(find.text(state.errorMessage), findsOneWidget);
    expect(find.byType(StatusBanner).hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('reset cancel preserves values and confirm clears them', (
    tester,
  ) async {
    final container = await pumpWorkspace(tester, const Size(1024, 900));
    await tester.enterText(
      find.byKey(const ValueKey('reaction-volume')),
      '100',
    );
    await tester.tap(find.byTooltip('清空当前计算'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('继续编辑'));
    await tester.pumpAndSettle();
    expect(container.read(calculatorProvider).reactionVolume, '100');
    await tester.tap(find.byTooltip('清空当前计算'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('清空并新建'));
    await tester.pumpAndSettle();
    expect(container.read(calculatorProvider).reactionVolume, isEmpty);
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('reaction-volume')))
          .controller!
          .text,
      isEmpty,
    );
  });

  testWidgets('inactive substrate fields are removed from tab order', (
    tester,
  ) async {
    await pumpWorkspace(tester, const Size(1440, 1000));
    final inactive = find.byKey(const ValueKey('substrate-2'));
    expect(tester.widget<ChemicalCard>(inactive).input.enabled, isFalse);
    expect(
      find.descendant(of: inactive, matching: find.byType(TextField)),
      findsNothing,
    );
  });

  testWidgets('enabling an inactive substrate reveals editable fields', (
    tester,
  ) async {
    final container = await pumpWorkspace(tester, const Size(390, 844));
    final card = find.byKey(const ValueKey('substrate-2'));
    final toggle = find.descendant(of: card, matching: find.byType(Switch));
    await tester.ensureVisible(toggle);
    await tester.pumpAndSettle();
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(container.read(calculatorProvider).substrates[2].enabled, isTrue);
    expect(
      find.descendant(of: card, matching: find.byType(TextField)),
      findsNWidgets(6),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('bottom navigation changes destination', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var destination = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: WorkspaceShell(
          selectedIndex: 0,
          onDestinationSelected: (index) => destination = index,
          child: const SizedBox(),
        ),
      ),
    );
    await tester.tap(find.text('历史'));
    await tester.pumpAndSettle();
    expect(destination, 1);
  });

  testWidgets('copy shortcut leaves ordinary text copy unbound', (
    tester,
  ) async {
    await pumpWorkspace(tester, const Size(1024, 900));
    final copyBindings = tester
        .widgetList<CallbackShortcuts>(find.byType(CallbackShortcuts))
        .expand((shortcuts) => shortcuts.bindings.keys)
        .whereType<SingleActivator>()
        .where((binding) => binding.trigger == LogicalKeyboardKey.keyC);
    expect(copyBindings, hasLength(1));
    expect(copyBindings.single.control, isTrue);
    expect(copyBindings.single.shift, isTrue);
  });

  testWidgets(
    'updated field values appear after restoring or loading templates',
    (tester) async {
      var value = 'before';
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return ChemicalFieldRow(
                  label: '名称',
                  value: value,
                  numeric: false,
                  onChanged: (_) {},
                );
              },
            ),
          ),
        ),
      );
      update(() => value = 'after');
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'after',
      );
    },
  );

  testWidgets('results use readable cards on narrow screens', (tester) async {
    tester.view.physicalSize = const Size(320, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const ResultMetricsRow(
                  metrics: ResultMetrics(
                    totalVolume: '100.00 uL',
                    stockVolume: '20.00 uL',
                    diluentVolume: '80.00 uL',
                    substrateCount: '2',
                  ),
                ),
                const SizedBox(height: 16),
                const ResultDataTableWidget(
                  rows: [
                    ResultRow(
                      role: '主底物',
                      name: 'IgG',
                      stock: '10.00 uM',
                      stockMass: '1.50 mg/mL',
                      finalConc: '1.00 uM',
                      finalConcMass: '150.00 ug/mL',
                      volume: '10.00 uL',
                      volumePct: '10.00%',
                      ratio: '1.0000',
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    expect(find.text('取 10.00 µL'), findsOneWidget);
    expect(find.text('摩尔 10.00 µM'), findsOneWidget);
    expect(find.text('质量 1.50 mg/mL'), findsOneWidget);
    expect(find.text('摩尔 1.00 µM'), findsOneWidget);
    expect(find.text('质量 150.00 µg/mL'), findsOneWidget);
    expect(find.byType(DataTable), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets('regular table includes both concentration bases', (
    tester,
  ) async {
    await pumpWorkspace(tester, const Size(1024, 900), populated: true);
    expect(find.byType(DataTable), findsOneWidget);
    final result = find.byType(ResultDataTableWidget);
    expect(
      find.descendant(of: result, matching: find.text('摩尔 10.00 mM')),
      findsNWidgets(4),
    );
    expect(
      find.descendant(of: result, matching: find.text('质量 1.50 g/mL')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: result, matching: find.text('摩尔 1.00 mM')),
      findsNWidgets(4),
    );
    final finalMass = find.descendant(
      of: result,
      matching: find.text('质量 500.00 mg/mL'),
    );
    expect(finalMass, findsNWidgets(3));
    await tester.ensureVisible(finalMass.last);
    await tester.pumpAndSettle();
    expect(finalMass.last.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final size in [const Size(320, 844), const Size(1024, 900)]) {
    testWidgets('paired concentrations remain accessible at 200% on $size', (
      tester,
    ) async {
      final container = await pumpWorkspace(
        tester,
        size,
        populated: true,
        scale: 2,
      );
      (container.read(calculatorProvider.notifier) as _CompactFixtureNotifier)
          .showUnavailableConversions();
      await tester.pumpAndSettle();
      expect(find.byType(DataTable), findsNothing);
      expect(find.text('质量 无法换算（缺少分子量）'), findsNWidgets(4));
      expect(find.text('摩尔 无法换算（缺少分子量）'), findsNWidgets(4));
      final lastLine = find.text('摩尔 无法换算（缺少分子量）').last;
      await tester.ensureVisible(lastLine);
      await tester.pumpAndSettle();
      expect(lastLine.hitTestable(), findsOneWidget);
      for (final paragraph in tester.renderObjectList<RenderParagraph>(
        find.descendant(
          of: find.byType(ResultDataTableWidget),
          matching: find.byType(RichText),
        ),
      )) {
        expect(paragraph.didExceedMaxLines, isFalse);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
