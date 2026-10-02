import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Local workspace preferences. Scientific inputs are stored separately.
class AppSettings {
  static const volumeUnits = ['L', 'mL', 'uL', 'nL', 'pL'];
  static const concentrationUnits = [
    'g/mL',
    'mg/mL',
    'ug/mL',
    'ng/mL',
    'pg/mL',
    'M',
    'mM',
    'uM',
    'nM',
    'pM',
  ];

  final ThemeMode themeMode;
  final double textScale;
  final String defaultVolumeUnit;
  final String defaultConcentrationUnit;
  final bool sidebarCollapsed;

  const AppSettings({
    this.themeMode = ThemeMode.system,
    this.textScale = 1,
    this.defaultVolumeUnit = 'uL',
    this.defaultConcentrationUnit = 'mg/mL',
    this.sidebarCollapsed = false,
  });

  AppSettings copyWith({
    ThemeMode? themeMode,
    double? textScale,
    String? defaultVolumeUnit,
    String? defaultConcentrationUnit,
    bool? sidebarCollapsed,
  }) => AppSettings(
    themeMode: themeMode ?? this.themeMode,
    textScale: textScale ?? this.textScale,
    defaultVolumeUnit: defaultVolumeUnit ?? this.defaultVolumeUnit,
    defaultConcentrationUnit:
        defaultConcentrationUnit ?? this.defaultConcentrationUnit,
    sidebarCollapsed: sidebarCollapsed ?? this.sidebarCollapsed,
  );

  Map<String, Object> toJson() => {
    'version': 1,
    'themeMode': themeMode.name,
    'textScale': textScale,
    'defaultVolumeUnit': defaultVolumeUnit,
    'defaultConcentrationUnit': defaultConcentrationUnit,
    'sidebarCollapsed': sidebarCollapsed,
  };

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final themeName = json['themeMode'] ?? 'system';
    final scale = json['textScale'] ?? 1;
    final volume = json['defaultVolumeUnit'] ?? 'uL';
    final concentration = json['defaultConcentrationUnit'] ?? 'mg/mL';
    final collapsed = json['sidebarCollapsed'] ?? false;
    if (json['version'] != 1 ||
        !ThemeMode.values.any((mode) => mode.name == themeName) ||
        scale is! num ||
        !scale.isFinite ||
        scale < 0.85 ||
        scale > 1.5 ||
        !volumeUnits.contains(volume) ||
        !concentrationUnits.contains(concentration) ||
        collapsed is! bool) {
      throw const FormatException('本机设置的内容或版本无效');
    }
    return AppSettings(
      themeMode: ThemeMode.values.firstWhere((mode) => mode.name == themeName),
      textScale: scale.toDouble(),
      defaultVolumeUnit: volume as String,
      defaultConcentrationUnit: concentration as String,
      sidebarCollapsed: collapsed,
    );
  }
}

abstract class AppSettingsStore {
  Future<AppSettings> load();
  Future<void> save(AppSettings settings);
}

/// Writes a complete replacement before renaming it over the prior file.
/// The notifier serializes saves so rapid menu changes cannot reorder writes.
class JsonAppSettingsStore implements AppSettingsStore {
  final Future<Directory> Function() _directoryProvider;

  JsonAppSettingsStore({Future<Directory> Function()? directoryProvider})
    : _directoryProvider = directoryProvider ?? getApplicationSupportDirectory;

  Future<File> _file() async {
    final directory = await _directoryProvider();
    await directory.create(recursive: true);
    return File(p.join(directory.path, 'workspace_settings.json'));
  }

  @override
  Future<AppSettings> load() async {
    final file = await _file();
    if (!await file.exists()) return const AppSettings();
    final decoded = jsonDecode(await file.readAsString());
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('本机设置格式无效');
    }
    return AppSettings.fromJson(decoded);
  }

  @override
  Future<void> save(AppSettings settings) async {
    // Validate at the boundary as well as in the controls.
    AppSettings.fromJson(settings.toJson());
    final destination = await _file();
    final temporary = File('${destination.path}.tmp');
    await temporary.writeAsString(jsonEncode(settings.toJson()), flush: true);
    await temporary.rename(destination.path);
  }
}

/// Main initializes these once before building the UI. Tests may override them.
final initialAppSettingsProvider = Provider<AppSettings>(
  (ref) => const AppSettings(),
);
final initialSettingsErrorProvider = Provider<String?>((ref) => null);
final appSettingsStoreProvider = Provider<AppSettingsStore>(
  (ref) => JsonAppSettingsStore(),
);
final settingsSaveErrorProvider = StateProvider<String?>(
  (ref) => ref.read(initialSettingsErrorProvider),
);
final appSettingsProvider = NotifierProvider<AppSettingsNotifier, AppSettings>(
  AppSettingsNotifier.new,
);

class AppSettingsNotifier extends Notifier<AppSettings> {
  Future<void> _pendingSave = Future.value();
  bool _disposed = false;
  int _revision = 0;

  @override
  AppSettings build() {
    _disposed = false;
    ref.onDispose(() => _disposed = true);
    return ref.read(initialAppSettingsProvider);
  }

  Future<void> _update(AppSettings next) {
    AppSettings.fromJson(next.toJson());
    state = next;
    final revision = ++_revision;
    final store = ref.read(appSettingsStoreProvider);
    _pendingSave = _pendingSave.then((_) async {
      try {
        await store.save(next);
        if (!_disposed && revision == _revision) {
          ref.read(settingsSaveErrorProvider.notifier).state = null;
        }
      } catch (_) {
        if (!_disposed && revision == _revision) {
          ref.read(settingsSaveErrorProvider.notifier).state =
              '设置已在本次会话生效，但未能保存到本机。请检查磁盘空间或目录权限后重试。';
        }
      }
    });
    return _pendingSave;
  }

  Future<void> setThemeMode(ThemeMode mode) =>
      _update(state.copyWith(themeMode: mode));
  Future<void> setTextScale(double scale) =>
      _update(state.copyWith(textScale: scale));
  Future<void> setDefaultVolumeUnit(String unit) =>
      _update(state.copyWith(defaultVolumeUnit: unit));
  Future<void> setDefaultConcentrationUnit(String unit) =>
      _update(state.copyWith(defaultConcentrationUnit: unit));
  Future<void> setSidebarCollapsed(bool collapsed) =>
      _update(state.copyWith(sidebarCollapsed: collapsed));
  Future<void> resetDefaults() => _update(const AppSettings());
}
