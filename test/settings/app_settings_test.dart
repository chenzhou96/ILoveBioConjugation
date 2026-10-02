import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/ui/settings/app_settings.dart';

class TestSettingsStore implements AppSettingsStore {
  final writes = <AppSettings>[];
  Future<void> Function(AppSettings)? onSave;
  AppSettings saved = const AppSettings();

  @override
  Future<AppSettings> load() async => saved;

  @override
  Future<void> save(AppSettings settings) async {
    writes.add(settings);
    if (onSave != null) await onSave!(settings);
    saved = settings;
  }
}

void main() {
  test('preferences serialize without changing values', () {
    const settings = AppSettings(
      themeMode: ThemeMode.dark,
      textScale: 1.15,
      defaultVolumeUnit: 'nL',
      defaultConcentrationUnit: 'pM',
      sidebarCollapsed: true,
    );
    expect(AppSettings.fromJson(settings.toJson()).toJson(), settings.toJson());
    expect(
      AppSettings.fromJson({'version': 1}).toJson(),
      const AppSettings().toJson(),
    );
  });

  test('invalid settings fail safely before changing application state', () {
    for (final entry in <String, Object>{
      'version': 99,
      'themeMode': 'rainbow',
      'textScale': double.nan,
      'defaultVolumeUnit': 'drop',
      'defaultConcentrationUnit': 'unknown',
      'sidebarCollapsed': 'yes',
      'minimumPipettingVolumeUl': -1,
    }.entries) {
      expect(
        () => AppSettings.fromJson({
          ...const AppSettings().toJson(),
          entry.key: entry.value,
        }),
        throwsFormatException,
      );
    }
    for (final scale in [0.5, 2, double.infinity]) {
      expect(
        () => AppSettings.fromJson({
          ...const AppSettings().toJson(),
          'textScale': scale,
        }),
        throwsFormatException,
      );
    }
  });

  test(
    'pipetting threshold accepts zero and rejects nonfinite or negative values',
    () {
      expect(
        AppSettings.fromJson(
          const AppSettings(minimumPipettingVolumeUl: 0).toJson(),
        ).minimumPipettingVolumeUl,
        0,
      );
      for (final threshold in [
        -1.0,
        double.nan,
        double.infinity,
        double.negativeInfinity,
      ]) {
        expect(
          () => AppSettings.fromJson(
            const AppSettings()
                .copyWith(minimumPipettingVolumeUl: threshold)
                .toJson(),
          ),
          throwsFormatException,
        );
      }
      expect(AppSettings.fromJson({'version': 1}).minimumPipettingVolumeUl, 1);
    },
  );

  group('file persistence', () {
    late Directory directory;
    late JsonAppSettingsStore store;
    setUp(() async {
      directory = await Directory.systemTemp.createTemp('laboratory-settings-');
      store = JsonAppSettingsStore(directoryProvider: () async => directory);
    });
    tearDown(() => directory.delete(recursive: true));

    test(
      'missing file uses defaults and repeated writes replace cleanly',
      () async {
        expect((await store.load()).toJson(), const AppSettings().toJson());
        await store.save(const AppSettings(themeMode: ThemeMode.dark));
        await store.save(
          const AppSettings(defaultVolumeUnit: 'pL', sidebarCollapsed: true),
        );
        final restarted = JsonAppSettingsStore(
          directoryProvider: () async => directory,
        );
        expect(
          (await restarted.load()).toJson(),
          const AppSettings(
            defaultVolumeUnit: 'pL',
            sidebarCollapsed: true,
          ).toJson(),
        );
        expect(
          await File('${directory.path}/workspace_settings.json.tmp').exists(),
          isFalse,
        );
      },
    );

    test(
      'corrupt settings are reported without deleting the original file',
      () async {
        final file = File('${directory.path}/workspace_settings.json');
        await file.writeAsString('{interrupted');
        await expectLater(store.load(), throwsFormatException);
        expect(await file.readAsString(), '{interrupted');
      },
    );

    test('invalid settings cannot overwrite valid persisted data', () async {
      await store.save(const AppSettings(themeMode: ThemeMode.light));
      await expectLater(
        store.save(const AppSettings(textScale: -1)),
        throwsFormatException,
      );
      expect((await store.load()).themeMode, ThemeMode.light);
    });
  });

  group('preference controller', () {
    late TestSettingsStore store;
    late ProviderContainer container;
    setUp(() {
      store = TestSettingsStore();
      container = ProviderContainer(
        overrides: [appSettingsStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
    });

    test('all controls persist and reset retains no old preference', () async {
      final notifier = container.read(appSettingsProvider.notifier);
      await notifier.setThemeMode(ThemeMode.dark);
      await notifier.setTextScale(1.3);
      await notifier.setDefaultVolumeUnit('nL');
      await notifier.setDefaultConcentrationUnit('pM');
      await notifier.setSidebarCollapsed(true);
      await notifier.setMinimumPipettingVolumeUl(2.5);
      expect(store.saved.minimumPipettingVolumeUl, 2.5);
      expect(
        store.saved.toJson(),
        container.read(appSettingsProvider).toJson(),
      );
      expect(store.saved.sidebarCollapsed, isTrue);
      await notifier.resetDefaults();
      expect(store.saved.toJson(), const AppSettings().toJson());
    });

    test(
      'rapid updates serialize writes and preserve the newest state',
      () async {
        final gate = Completer<void>();
        store.onSave = (_) =>
            store.writes.length == 1 ? gate.future : Future.value();
        final notifier = container.read(appSettingsProvider.notifier);
        final first = notifier.setThemeMode(ThemeMode.dark);
        final second = notifier.setSidebarCollapsed(true);
        await Future<void>.delayed(Duration.zero);
        expect(store.writes.length, 1);
        expect(container.read(appSettingsProvider).sidebarCollapsed, isTrue);
        gate.complete();
        await Future.wait([first, second]);
        expect(store.writes.length, 2);
        expect(store.saved.themeMode, ThemeMode.dark);
        expect(store.saved.sidebarCollapsed, isTrue);
      },
    );

    test('save failure is visible and a later success clears it', () async {
      store.onSave = (_) =>
          Future.error(const FileSystemException('disk full'));
      final notifier = container.read(appSettingsProvider.notifier);
      await notifier.setThemeMode(ThemeMode.dark);
      expect(container.read(appSettingsProvider).themeMode, ThemeMode.dark);
      expect(container.read(settingsSaveErrorProvider), contains('未能保存'));
      store.onSave = null;
      await notifier.setThemeMode(ThemeMode.light);
      expect(container.read(settingsSaveErrorProvider), isNull);
    });

    test(
      'old save failure cannot overwrite a newer successful preference',
      () async {
        final gate = Completer<void>();
        store.onSave = (_) =>
            store.writes.length == 1 ? gate.future : Future.value();
        final notifier = container.read(appSettingsProvider.notifier);
        final first = notifier.setThemeMode(ThemeMode.dark);
        final second = notifier.setThemeMode(ThemeMode.light);
        await Future<void>.delayed(Duration.zero);
        gate.completeError(const FileSystemException('old failed save'));
        await Future.wait([first, second]);
        expect(store.saved.themeMode, ThemeMode.light);
        expect(container.read(settingsSaveErrorProvider), isNull);
      },
    );

    test('rejects unsupported units and text scales without mutation', () {
      final notifier = container.read(appSettingsProvider.notifier);
      expect(
        () => notifier.setDefaultVolumeUnit('bucket'),
        throwsFormatException,
      );
      expect(
        () => notifier.setTextScale(double.infinity),
        throwsFormatException,
      );
      expect(
        container.read(appSettingsProvider).toJson(),
        const AppSettings().toJson(),
      );
      expect(store.writes, isEmpty);
    });

    test('initial persisted preferences load without rewriting disk', () {
      final seeded = ProviderContainer(
        overrides: [
          appSettingsStoreProvider.overrideWithValue(store),
          initialAppSettingsProvider.overrideWithValue(
            const AppSettings(
              themeMode: ThemeMode.dark,
              sidebarCollapsed: true,
            ),
          ),
          initialSettingsErrorProvider.overrideWithValue('startup warning'),
        ],
      );
      addTearDown(seeded.dispose);
      expect(seeded.read(appSettingsProvider).themeMode, ThemeMode.dark);
      expect(seeded.read(settingsSaveErrorProvider), 'startup warning');
      expect(store.writes, isEmpty);
    });
  });
}
