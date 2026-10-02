// Optional real-font planning captures (not platform-dependent golden checks):
// flutter test test/ui/planning_screenshot_test.dart \
//   --dart-define=CAPTURE_PLANNING=true \
//   --dart-define=SCREENSHOT_DIR=/workspace/shared/lab-qa-planning
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/app.dart';
import 'package:ilovebioconjugation/data/app_database.dart';
import 'package:ilovebioconjugation/theme/app_theme.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_screen.dart';

import '../state/fake_database.dart';

void main() {
  const capture = bool.fromEnvironment('CAPTURE_PLANNING');
  const output = String.fromEnvironment(
    'SCREENSHOT_DIR',
    defaultValue: 'build/qa/planning',
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
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
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
    expect(tester.takeException(), isNull);
  }

  Finder key(String value) => find.byKey(ValueKey(value));

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    if (finder.hitTestable().evaluate().isNotEmpty) return;
    if (finder.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        finder,
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
    await tester.ensureVisible(finder);
  }

  Future<void> enter(WidgetTester tester, Finder finder, String text) async {
    await reveal(tester, finder);
    await tester.enterText(finder, text);
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await reveal(tester, finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  for (final entry in [
    ('desktop', const Size(1366, 768), 1.0, false),
    ('desktop-dark', const Size(1440, 900), 1.0, true),
    ('phone', const Size(390, 844), 1.0, false),
    ('enlarged', const Size(390, 1000), 2.0, false),
  ]) {
    testWidgets('capture ${entry.$1} planning workflows', (tester) async {
      await binding.setSurfaceSize(entry.$2);
      tester.view.physicalSize = entry.$2;
      tester.view.devicePixelRatio = 1;
      addTearDown(() => binding.setSurfaceSize(null));
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(FakeDatabase())],
      );
      addTearDown(container.dispose);
      final notifier = container.read(calculatorProvider.notifier);
      notifier.setReactionVolume('100');
      notifier.setSubstrateField(0, 'name', 'IgG');
      notifier.setSubstrateField(0, 'mw', '150');
      notifier.setSubstrateField(0, 'mwUnit', 'kDa');
      notifier.setSubstrateField(0, 'storageConc', '10');
      notifier.setSubstrateField(0, 'storageUnit', 'uM');
      notifier.setSubstrateField(0, 'finalConc', '1');
      notifier.setSubstrateField(0, 'finalUnit', 'uM');
      for (var slot = 1; slot < 4; slot++) {
        if (slot > 1) notifier.toggleSubstrateEnabled(slot);
        notifier.setSubstrateField(
          slot,
          'name',
          ['IgG', 'TCEP', 'Linker', 'Probe'][slot],
        );
        notifier.setSubstrateField(slot, 'mw', slot == 1 ? '286.65' : '500');
        notifier.setSubstrateField(slot, 'storageConc', '10');
        notifier.setSubstrateField(slot, 'storageUnit', 'mM');
        notifier.setSubstrateField(slot, 'reactionRatio', '${slot * 10}');
      }
      final boundaryKey = GlobalKey();
      final base = entry.$4 ? AppTheme.dark : AppTheme.light;
      // The boundary surrounds MaterialApp so modal routes are captured too.
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundaryKey,
          child: UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: base.copyWith(
                textTheme: base.textTheme.apply(fontFamily: 'WorkspaceCJK'),
                primaryTextTheme: base.primaryTextTheme.apply(
                  fontFamily: 'WorkspaceCJK',
                ),
              ),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: TextScaler.linear(entry.$3)),
                child: child!,
              ),
              home: WorkspaceShell(
                selectedIndex: 0,
                onDestinationSelected: (_) {},
                child: const CalculatorScreen(),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tap(tester, key('calculate-button'));
      await save(tester, boundaryKey, '${entry.$1}-planning-results');
      await tap(tester, key('low-volume-1'));
      await enter(tester, key('working-stock-diluent'), 'PBS');
      await tap(tester, key('working-stock-preview'));
      await save(tester, boundaryKey, '${entry.$1}-working-stock');
      await tap(tester, find.text('取消'));
      await tap(tester, key('gradient-planning-button'));
      await enter(
        tester,
        key('gradient-values'),
        '0, 1, 2, 4, 8, 16, 32, 64, 128',
      );
      await enter(tester, key('gradient-replicates'), '3');
      await enter(tester, key('gradient-extra'), '10');
      await tap(tester, key('gradient-generate'));
      await save(tester, boundaryKey, '${entry.$1}-gradient-plan');
      if (entry.$1.startsWith('desktop')) {
        final overview = key('gradient-overview-table');
        expect(overview, findsOneWidget);
        expect(tester.widget<DataTable>(overview).rows, hasLength(5));
        final scroll = tester
            .stateList<ScrollableState>(
              find.descendant(
                of: key('gradient-result-page-0'),
                matching: find.byType(Scrollable),
              ),
            )
            .singleWhere((state) => state.position.axis == Axis.vertical);
        expect(
          scroll.position.maxScrollExtent,
          0,
          reason: 'Five overview rows fit with real CJK typography',
        );
        for (var index = 0; index < 5; index++) {
          expect(key('gradient-group-$index').hitTestable(), findsOneWidget);
          expect(key('gradient-details-$index').hitTestable(), findsOneWidget);
        }
      }
      if (entry.$1 == 'desktop') {
        await tap(tester, key('gradient-details-1'));
        await save(tester, boundaryKey, 'desktop-gradient-detail');
        await tap(tester, find.text('关闭'));
      }
      await tap(tester, find.text('备液汇总'));
      await save(tester, boundaryKey, '${entry.$1}-gradient-preparation');
      expect(container.read(calculatorProvider).gradientPlan, isNotNull);
    }, skip: !capture);
  }
}
