// Optional local screenshots (not platform-dependent golden assertions):
// flutter test test/ui/workspace_screenshot_test.dart \
//   --dart-define=CAPTURE_WORKSPACE=true
// PNG files are written to build/qa by default. Override with
// --dart-define=SCREENSHOT_DIR=/absolute/path when running outside this workspace.
import 'dart:io';
import 'dart:ui' as ui;

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
import 'package:ilovebioconjugation/ui/settings/app_settings.dart';
import 'package:ilovebioconjugation/ui/settings/settings_screen.dart';

class _ScreenshotNotifier extends CalculatorNotifier {
  @override
  CalculatorState build() => super.build().copyWith(
    reactionVolume: '100',
    substrates: [
      SubstrateInput(
        enabled: true,
        name: 'IgG',
        mw: '150',
        mwUnit: 'kDa',
        storageConc: '10',
        storageUnit: 'mg/mL',
        finalConc: '1',
        finalUnit: 'mg/mL',
        reactionRatio: '1',
      ),
      SubstrateInput(
        enabled: true,
        name: 'TCEP',
        mw: '286.65',
        storageConc: '10',
        storageUnit: 'mM',
        reactionRatio: '10',
      ),
      SubstrateInput(
        enabled: true,
        name: 'Linker',
        mw: '500',
        storageConc: '20',
        storageUnit: 'mM',
        reactionRatio: '5',
      ),
      SubstrateInput(
        enabled: true,
        name: 'Probe',
        mw: '750',
        storageConc: '5',
        storageUnit: 'mM',
        reactionRatio: '2',
      ),
    ],
    statusMessage: '计算完成，请核对下方取样清单。',
    statusLevel: StatusLevel.success,
    metrics: const ResultMetrics(
      totalVolume: '100.00 uL',
      stockVolume: '11.10 uL',
      diluentVolume: '88.90 uL',
      substrateCount: '4',
    ),
    rows: const [
      ResultRow(
        role: '主底物',
        name: 'IgG',
        stock: '66.67 uM',
        stockMass: '10.00 mg/mL',
        finalConc: '6.67 uM',
        finalConcMass: '1.00 mg/mL',
        volume: '10.00 uL',
        volumePct: '10.00%',
        ratio: '1.0000',
      ),
      ResultRow(
        role: '副底物1',
        name: 'TCEP',
        stock: '10.00 mM',
        stockMass: '2.87 mg/mL',
        finalConc: '66.67 uM',
        finalConcMass: '19.11 ug/mL',
        volume: '666.67 nL',
        volumePct: '0.67%',
        ratio: '10.0000',
      ),
      ResultRow(
        role: '副底物2',
        name: 'Linker',
        stock: '20.00 mM',
        stockMass: '10.00 mg/mL',
        finalConc: '33.33 uM',
        finalConcMass: '16.67 ug/mL',
        volume: '166.67 nL',
        volumePct: '0.17%',
        ratio: '5.0000',
      ),
      ResultRow(
        role: '副底物3',
        name: 'Probe',
        stock: '5.00 mM',
        stockMass: '3.75 mg/mL',
        finalConc: '13.33 uM',
        finalConcMass: '10.00 ug/mL',
        volume: '266.67 nL',
        volumePct: '0.27%',
        ratio: '2.0000',
      ),
    ],
  );

  // Keep this deterministic presentation fixture independent of storage.
  @override
  void calculate() {}
}

// A valid all-molar experiment can be solved without molecular weights. The
// paired mass lines must explain that they cannot be converted, never show zero.
class _MissingMwScreenshotNotifier extends _ScreenshotNotifier {
  @override
  CalculatorState build() {
    final baseline = super.build();
    return baseline.copyWith(
      substrates: [
        for (var index = 0; index < baseline.substrates.length; index++)
          baseline.substrates[index].copyWith(
            mw: '',
            storageConc: index == 0 ? '66.6667' : null,
            storageUnit: index == 0 ? 'uM' : null,
            finalConc: index == 0 ? '6.66667' : null,
            finalUnit: 'uM',
          ),
      ],
      rows: [
        for (final row in baseline.rows)
          ResultRow(
            role: row.role,
            name: row.name,
            stock: row.stock,
            stockMass: '无法换算（缺少分子量）',
            finalConc: row.finalConc,
            finalConcMass: '无法换算（缺少分子量）',
            volume: row.volume,
            volumePct: row.volumePct,
            ratio: row.ratio,
          ),
      ],
    );
  }
}

void main() {
  const capture = bool.fromEnvironment('CAPTURE_WORKSPACE');
  const output = String.fromEnvironment(
    'SCREENSHOT_DIR',
    defaultValue: 'build/qa',
  );
  const fontPath = String.fromEnvironment(
    'SCREENSHOT_FONT',
    defaultValue: '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc',
  );
  final binding = TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    if (!capture) return;
    final bytes = await File(fontPath).readAsBytes();
    for (final family in ['WorkspaceCJK', 'Roboto', 'Ahem']) {
      final loader = FontLoader(family)
        ..addFont(Future.value(ByteData.sublistView(bytes)));
      await loader.load();
    }
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });

  Future<void> save(WidgetTester tester, GlobalKey key, String name) async {
    await tester.pumpAndSettle();
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final directory = Directory(output);
      await directory.create(recursive: true);
      await File(
        '${directory.path}/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  for (final entry in [
    ('desktop', const Size(1366, 768), false, false, false),
    ('desktop-collapsed', const Size(1366, 768), false, true, false),
    ('desktop-dark', const Size(1366, 768), true, false, false),
    ('settings', const Size(1440, 900), false, false, true),
    ('desktop-1440', const Size(1440, 900), false, false, false),
    ('desktop-missing-mw', const Size(1366, 768), false, false, false),
    ('desktop-missing-mw-1440', const Size(1440, 900), false, false, false),
    ('phone', const Size(390, 844), false, false, false),
  ]) {
    testWidgets('capture ${entry.$1} workspace', (tester) async {
      await binding.setSurfaceSize(entry.$2);
      tester.view.physicalSize = entry.$2;
      tester.view.devicePixelRatio = 1;
      addTearDown(() => binding.setSurfaceSize(null));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      final base = entry.$3 ? AppTheme.dark : AppTheme.light;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            calculatorProvider.overrideWith(
              entry.$1.contains('missing-mw')
                  ? _MissingMwScreenshotNotifier.new
                  : _ScreenshotNotifier.new,
            ),
            initialAppSettingsProvider.overrideWithValue(
              AppSettings(
                themeMode: entry.$3 ? ThemeMode.dark : ThemeMode.light,
                sidebarCollapsed: entry.$4,
              ),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: base.copyWith(
              textTheme: base.textTheme.apply(fontFamily: 'WorkspaceCJK'),
              primaryTextTheme: base.primaryTextTheme.apply(
                fontFamily: 'WorkspaceCJK',
              ),
            ),
            home: RepaintBoundary(
              key: key,
              child: WorkspaceShell(
                selectedIndex: entry.$5 ? 3 : 0,
                collapsed: entry.$4,
                onSidebarToggle: () {},
                onNewCalculation: () {},
                onDestinationSelected: (_) {},
                child: entry.$5
                    ? const SettingsScreen()
                    : const CalculatorScreen(),
              ),
            ),
          ),
        ),
      );
      await save(tester, key, '${entry.$1}-workspace');
      expect(tester.takeException(), isNull);
      if (entry.$1.startsWith('desktop')) {
        // Verify the real CJK-font capture as well as the regular widget tests.
        final canvas = find.byKey(const ValueKey('desktop-workspace'));
        expect(canvas, findsOneWidget);
        final result = find.byKey(const ValueKey('desktop-result-table'));
        expect(
          tester.getRect(result).bottom,
          lessThanOrEqualTo(entry.$2.height - 18),
        );
        expect(tester.widget<Table>(result).children, hasLength(5));
        for (var index = 0; index < 4; index++) {
          expect(
            find.byKey(ValueKey('result-name-$index')).hitTestable(),
            findsOneWidget,
          );
          for (final field in ['stock', 'final']) {
            final pair = find.byKey(ValueKey('result-$field-$index'));
            final pairRect = tester.getRect(pair);
            expect(pairRect.bottom, lessThanOrEqualTo(entry.$2.height - 18));
            final lines = find.descendant(
              of: pair,
              matching: find.byType(Text),
            );
            expect(lines.hitTestable(), findsNWidgets(2));
            for (final paragraph in tester.renderObjectList<RenderParagraph>(
              find.descendant(of: pair, matching: find.byType(RichText)),
            )) {
              expect(paragraph.didExceedMaxLines, isFalse);
              final boxes = paragraph.getBoxesForSelection(
                TextSelection(
                  baseOffset: 0,
                  extentOffset: paragraph.text.toPlainText().length,
                ),
              );
              expect(boxes.map((box) => box.top).toSet(), hasLength(1));
              final origin = paragraph.localToGlobal(Offset.zero);
              for (final box in boxes) {
                expect(
                  origin.dx + box.left,
                  greaterThanOrEqualTo(pairRect.left),
                );
                expect(
                  origin.dx + box.right,
                  lessThanOrEqualTo(pairRect.right),
                );
              }
            }
          }
        }
        if (entry.$1.contains('missing-mw')) {
          expect(find.text('质量 无法换算（缺少分子量）'), findsNWidgets(8));
        }
        for (final scrollable in tester.stateList<ScrollableState>(
          find.descendant(of: canvas, matching: find.byType(Scrollable)),
        )) {
          if (scrollable.position.axis == Axis.vertical) {
            expect(scrollable.position.maxScrollExtent, 0);
          }
        }
      }
      if (entry.$1 == 'phone') {
        await tester.tap(find.byKey(const ValueKey('calculate-button')));
        await save(tester, key, 'phone-results');
        expect(tester.takeException(), isNull);
      }
    }, skip: !capture);
  }
}
