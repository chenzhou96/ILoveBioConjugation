import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/data/app_database.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/settings/app_settings.dart';

import 'fake_database.dart';

class MemorySettingsStore implements AppSettingsStore {
  AppSettings settings = const AppSettings();
  @override
  Future<AppSettings> load() async => settings;
  @override
  Future<void> save(AppSettings next) async => settings = next;
}

void main() {
  test('new calculations use saved defaults for every blank unit', () {
    final container = ProviderContainer(
      overrides: [
        initialAppSettingsProvider.overrideWithValue(
          const AppSettings(
            defaultVolumeUnit: 'pL',
            defaultConcentrationUnit: 'nM',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final state = container.read(calculatorProvider);
    expect(state.reactionVolumeUnit, 'pL');
    expect(state.substrates.every((s) => s.storageVolumeUnit == 'pL'), isTrue);
    expect(state.substrates.every((s) => s.storageUnit == 'nM'), isTrue);
    expect(state.substrates.every((s) => s.finalUnit == 'nM'), isTrue);
  });

  test(
    'preference changes preserve active inputs/results and apply on reset',
    () async {
      final container = ProviderContainer(
        overrides: [
          appSettingsStoreProvider.overrideWithValue(MemorySettingsStore()),
          appDatabaseProvider.overrideWithValue(FakeDatabase()),
        ],
      );
      addTearDown(container.dispose);
      final calculator = container.read(calculatorProvider.notifier);
      calculator.setRatioType(false);
      calculator.toggleSubstrateEnabled(1);
      calculator.setReactionVolume('100');
      calculator.setSubstrateField(0, 'storageConc', '10');
      calculator.setSubstrateField(0, 'finalConc', '1');
      calculator.calculate();
      final before = container.read(calculatorProvider);
      final copy = calculator.buildCopyText();
      final settings = container.read(appSettingsProvider.notifier);
      await settings.setDefaultVolumeUnit('mL');
      await settings.setDefaultConcentrationUnit('pM');
      expect(container.read(calculatorProvider), same(before));
      expect(calculator.buildCopyText(), copy);
      calculator.reset();
      final reset = container.read(calculatorProvider);
      expect(reset.reactionVolume, isEmpty);
      expect(reset.reactionVolumeUnit, 'mL');
      expect(
        reset.substrates.every((s) => s.storageVolumeUnit == 'mL'),
        isTrue,
      );
      expect(reset.substrates.every((s) => s.storageUnit == 'pM'), isTrue);
      expect(reset.substrates.every((s) => s.finalUnit == 'pM'), isTrue);
    },
  );
}
