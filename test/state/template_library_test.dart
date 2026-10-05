import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ilovebioconjugation/data/app_database.dart';
import 'package:ilovebioconjugation/data/substrate_template.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/templates/template_library_screen.dart';

import 'fake_database.dart';

class FailingTemplateDatabase extends FakeDatabase {
  @override
  Future<void> deleteTemplate(int id) async =>
      throw StateError('database locked');
}

void main() {
  const template = SubstrateTemplate(
    id: 1,
    name: 'Trace protein',
    storageConcentration: 1.25,
    storageUnit: 'nM',
    defaultFinalUnit: 'pM',
    createdAt: '2026-10-02',
    updatedAt: '2026-10-02',
  );

  Future<ProviderContainer> pumpLibrary(
    WidgetTester tester,
    FakeDatabase database, {
    double textScale = 1,
    bool dark = false,
  }) async {
    final container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    final router = GoRouter(
      initialLocation: '/templates',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) =>
              const Scaffold(body: Text('Calculator destination')),
        ),
        GoRoute(
          path: '/templates',
          builder: (_, _) => const TemplateLibraryScreen(),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          routerConfig: router,
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets('browses and filters saved templates', (tester) async {
    final database = FakeDatabase()..templates.add(template);
    await pumpLibrary(tester, database);
    expect(find.text('Trace protein'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'unmatched');
    await tester.pumpAndSettle();
    expect(find.text('Trace protein'), findsNothing);
    expect(find.text('没有匹配的模板，请尝试其他名称。'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'TRACE');
    await tester.pumpAndSettle();
    expect(find.text('Trace protein'), findsOneWidget);
  });

  testWidgets('loads chosen disabled secondary and activates that exact slot', (
    tester,
  ) async {
    final database = FakeDatabase()..templates.add(template);
    final container = await pumpLibrary(tester, database);
    final notifier = container.read(calculatorProvider.notifier);
    notifier.setSubstrateField(2, 'finalConc', 'stale');
    notifier.setSubstrateField(2, 'storageVolume', '99');
    await tester.tap(find.byKey(const ValueKey('template-target-slot')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('副底物2').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('加载到副底物2'));
    await tester.pumpAndSettle();
    expect(find.text('Calculator destination'), findsOneWidget);
    final state = container.read(calculatorProvider);
    expect(state.substrates[2].enabled, isTrue);
    expect(state.substrates[2].name, 'Trace protein');
    expect(state.substrates[2].storageConc, '1.25');
    expect(state.substrates[2].storageUnit, 'nM');
    expect(state.substrates[2].finalConc, isEmpty);
    expect(state.substrates[2].storageVolume, isEmpty);
    expect(state.substrates[0].name, '主底物');
    expect(state.rows, isEmpty);
  });

  testWidgets('requires confirmation before deleting a template', (
    tester,
  ) async {
    final database = FakeDatabase()..templates.add(template);
    await pumpLibrary(tester, database);
    await tester.tap(find.text('删除模板'));
    await tester.pumpAndSettle();
    expect(database.templates, hasLength(1));
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(database.templates, hasLength(1));
    await tester.tap(find.text('删除模板'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();
    expect(database.templates, isEmpty);
    expect(find.textContaining('暂无模板'), findsOneWidget);
  });

  testWidgets('template deletion errors are visible and nonfatal', (
    tester,
  ) async {
    final database = FailingTemplateDatabase()..templates.add(template);
    await pumpLibrary(tester, database);
    await tester.tap(find.text('删除模板'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();
    expect(find.textContaining('模板删除失败'), findsOneWidget);
    expect(database.templates, hasLength(1));
    expect(tester.takeException(), isNull);
  });
  for (final width in [320.0, 390.0]) {
    for (final textScale in [1.3, 2.0]) {
      testWidgets(
        'template library fits ${width.toInt()}px at ${textScale}x text',
        (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final database = FakeDatabase()..templates.add(template);
          await pumpLibrary(tester, database, textScale: textScale, dark: true);
          expect(tester.takeException(), isNull);
          await tester.scrollUntilVisible(
            find.text('加载到主底物'),
            150,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await tester.tap(find.text('加载到主底物'));
          await tester.pumpAndSettle();
          expect(find.text('Calculator destination'), findsOneWidget);
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
