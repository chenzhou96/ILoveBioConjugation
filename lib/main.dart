import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilovebioconjugation/app.dart';
import 'package:ilovebioconjugation/data/app_database.dart';
import 'package:ilovebioconjugation/ui/settings/app_settings.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = SqfliteDatabase();
  await db.init();
  final settingsStore = JsonAppSettingsStore();
  var settings = const AppSettings();
  String? settingsError;
  try {
    settings = await settingsStore.load();
  } catch (_) {
    settingsError = '无法读取本机设置，已使用默认值。可在设置中重新保存；计算历史不受影响。';
  }
  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        appSettingsStoreProvider.overrideWithValue(settingsStore),
        initialAppSettingsProvider.overrideWithValue(settings),
        initialSettingsErrorProvider.overrideWithValue(settingsError),
      ],
      child: const App(),
    ),
  );
}
