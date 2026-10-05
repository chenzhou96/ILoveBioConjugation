import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/app.dart';
import 'package:ilovebioconjugation/theme/app_theme.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/settings/app_settings.dart';
import 'package:ilovebioconjugation/ui/settings/settings_screen.dart';

class _SettingsStore implements AppSettingsStore {
  AppSettings? saved;
  bool fail = false;
  @override
  Future<AppSettings> load() async => const AppSettings();
  @override
  Future<void> save(AppSettings settings) async {
    if (fail) throw Exception('disk unavailable');
    saved = settings;
  }
}

void main() {
  void size(WidgetTester tester, Size value) {
    tester.view.physicalSize = value;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  testWidgets(
    'all standard desktop settings fit without scrolling at 1366×768',
    (tester) async {
      size(tester, const Size(1366, 768));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AppTheme.light,
            home: WorkspaceShell(
              selectedIndex: 3,
              onDestinationSelected: (_) {},
              child: const SettingsScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final scrollable = tester.state<ScrollableState>(
        find
            .descendant(
              of: find.byType(SettingsScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      expect(scrollable.position.maxScrollExtent, 0);
      expect(find.text('恢复默认设置').hitTestable(), findsOneWidget);
      expect(tester.getRect(find.text('恢复默认设置')).bottom, lessThan(768));
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('desktop sidebar collapses and menu destinations work', (
    tester,
  ) async {
    size(tester, const Size(1440, 1000));
    var collapsed = false;
    var destination = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: StatefulBuilder(
          builder: (context, update) => WorkspaceShell(
            selectedIndex: destination,
            collapsed: collapsed,
            onSidebarToggle: () => update(() => collapsed = !collapsed),
            onDestinationSelected: (index) => update(() => destination = index),
            child: const SizedBox(),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('收起侧边栏'));
    await tester.pumpAndSettle();
    expect(collapsed, isTrue);
    expect(find.byTooltip('展开侧边栏'), findsOneWidget);
    await tester.tap(find.text('文件'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, '模板库'));
    await tester.pumpAndSettle();
    expect(destination, 2);
    await tester.tap(find.text('帮助'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(MenuItemButton, '使用说明'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('phone menu exposes settings and template destinations', (
    tester,
  ) async {
    size(tester, const Size(390, 844));
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
    await tester.tap(find.byTooltip('工作台菜单'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('工作台设置'));
    await tester.pumpAndSettle();
    expect(destination, 3);
    await tester.tap(find.text('模板'));
    await tester.pumpAndSettle();
    expect(destination, 2);
    expect(tester.takeException(), isNull);
  });

  Future<ProviderContainer> pumpSettings(
    WidgetTester tester,
    _SettingsStore store,
  ) async {
    size(tester, const Size(390, 1000));
    final container = ProviderContainer(
      overrides: [appSettingsStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: Consumer(
          builder: (context, ref, _) => MaterialApp(
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: ref.watch(appSettingsProvider).themeMode,
            home: const SettingsScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  testWidgets(
    'theme and default units update without overwriting active inputs',
    (tester) async {
      final store = _SettingsStore();
      final container = await pumpSettings(tester, store);
      container.read(calculatorProvider.notifier).setReactionVolume('123');
      await tester.tap(find.byKey(const ValueKey('theme-mode-setting')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('深色').last);
      await tester.pumpAndSettle();
      expect(container.read(appSettingsProvider).themeMode, ThemeMode.dark);
      expect(
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness,
        Brightness.dark,
      );
      await tester.ensureVisible(
        find.byKey(const ValueKey('default-volume-setting')),
      );
      await tester.tap(find.byKey(const ValueKey('default-volume-setting')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('mL').last);
      await tester.pumpAndSettle();
      expect(store.saved!.defaultVolumeUnit, 'mL');
      expect(container.read(calculatorProvider).reactionVolume, '123');
      expect(container.read(calculatorProvider).reactionVolumeUnit, 'uL');
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'settings save failure stays visible with effective session values',
    (tester) async {
      final store = _SettingsStore()..fail = true;
      final container = await pumpSettings(tester, store);
      await tester.tap(find.byKey(const ValueKey('theme-mode-setting')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('深色').last);
      await tester.pumpAndSettle();
      expect(container.read(appSettingsProvider).themeMode, ThemeMode.dark);
      expect(find.textContaining('未能保存到本机'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
