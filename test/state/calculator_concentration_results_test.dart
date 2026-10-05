import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/data/app_database.dart';
import 'package:ilovebioconjugation/ui/calculator/calculator_notifier.dart';
import 'package:ilovebioconjugation/ui/calculator/state.dart';

import 'fake_database.dart';

void main() {
  late FakeDatabase database;
  late ProviderContainer container;
  late CalculatorNotifier notifier;

  setUp(() {
    database = FakeDatabase();
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(database)],
    );
    notifier = container.read(calculatorProvider.notifier);
    notifier.toggleSubstrateEnabled(1);
    notifier.setReactionVolume('100');
    addTearDown(container.dispose);
  });

  CalculatorState current() => container.read(calculatorProvider);

  void setMain({
    required bool molarRatio,
    required String stock,
    required String finalConc,
    required String unit,
    String mw = '50',
    String mwUnit = 'kDa',
  }) {
    notifier.setRatioType(molarRatio);
    notifier.setSubstrateField(0, 'mw', mw);
    notifier.setSubstrateField(0, 'mwUnit', mwUnit);
    notifier.setSubstrateField(0, 'storageConc', stock);
    notifier.setSubstrateField(0, 'storageUnit', unit);
    notifier.setSubstrateField(0, 'finalConc', finalConc);
    notifier.setSubstrateField(0, 'finalUnit', unit);
  }

  ResultRow calculateSingle() {
    notifier.calculate();
    expect(
      current().statusLevel,
      StatusLevel.success,
      reason: current().errorMessage,
    );
    return current().rows.single;
  }

  List<String> copyCells() {
    final resultLine = notifier.buildCopyText().split('\n').last;
    return resultLine.split(' | ').map((value) => value.trim()).toList();
  }

  const unavailable = '无法换算（缺少分子量）';

  for (final molarRatio in [true, false]) {
    final mode = molarRatio ? 'molar ratio' : 'mass ratio';

    for (final molarInput in [true, false]) {
      test(
        '$mode shows both bases from ${molarInput ? 'molar' : 'mass'} input',
        () {
          setMain(
            molarRatio: molarRatio,
            stock: molarInput ? '200' : '10',
            finalConc: molarInput ? '20' : '1',
            unit: molarInput ? 'uM' : 'mg/mL',
          );
          final row = calculateSingle();

          expect(row.stock, '200.000 uM');
          expect(row.stockMass, '10.000 mg/mL');
          expect(row.finalConc, '20.000 uM');
          expect(row.finalConcMass, '1.000 mg/mL');
          expect(row.volume, '10.000 uL');
          expect(copyCells(), [
            row.role,
            row.name,
            row.stock,
            row.stockMass,
            row.finalConc,
            row.finalConcMass,
            row.volume,
            row.volumePct,
            row.ratio,
          ]);
          final copied = notifier.buildCopyText();
          for (final header in ['母液浓度（摩尔）', '母液浓度（质量）', '终浓度（摩尔）', '终浓度（质量）']) {
            expect(copied, contains(header));
          }
          final saved = database.saveRequests.single.substrates.single;
          expect(saved.storageConcMolar, closeTo(0.2, 1e-12));
          expect(saved.storageConcMass, closeTo(10, 1e-12));
          expect(saved.finalConcMolar, closeTo(0.02, 1e-12));
          expect(saved.finalConcMass, closeTo(1, 1e-12));
        },
      );
    }

    const scales = [
      ('M', 'g/mL'),
      ('mM', 'mg/mL'),
      ('uM', 'ug/mL'),
      ('nM', 'ng/mL'),
      ('pM', 'pg/mL'),
    ];
    for (final (molarUnit, massUnit) in scales) {
      for (final molarInput in [true, false]) {
        final inputUnit = molarInput ? molarUnit : massUnit;
        test('$mode preserves paired scale for $inputUnit input', () {
          setMain(
            molarRatio: molarRatio,
            stock: '25',
            finalConc: '2.5',
            unit: inputUnit,
            mw: '1000',
            mwUnit: 'Da',
          );
          final row = calculateSingle();
          expect(row.stock, '25.000 $molarUnit');
          expect(row.stockMass, '25.000 $massUnit');
          expect(row.finalConc, '2.500 $molarUnit');
          expect(row.finalConcMass, '2.500 $massUnit');
          expect(row.volume, '10.000 uL');
        });
      }
    }

    test('$mode keeps sub-pico concentrations nonzero in both bases', () {
      setMain(
        molarRatio: molarRatio,
        stock: '0.0001',
        finalConc: '0.00001',
        unit: molarRatio ? 'pM' : 'pg/mL',
        mw: '1000',
        mwUnit: 'Da',
      );
      final row = calculateSingle();
      expect(row.stock, '1.000e-4 pM');
      expect(row.stockMass, '1.000e-4 pg/mL');
      expect(row.finalConc, '1.000e-5 pM');
      expect(row.finalConcMass, '1.000e-5 pg/mL');
      expect(notifier.buildCopyText(), contains(row.finalConcMass));
    });

    test('$mode keeps explicit zero distinct from unavailable', () {
      setMain(
        molarRatio: molarRatio,
        stock: '10',
        finalConc: '0',
        unit: 'mg/mL',
      );
      final row = calculateSingle();
      expect(row.finalConc, '0.000 mM');
      expect(row.finalConcMass, '0.000 mg/mL');
      expect(row.volume, '0.000 uL');
      expect(notifier.buildCopyText(), isNot(contains(unavailable)));
    });

    test(
      '$mode retains its known basis and explains missing molecular weight',
      () {
        setMain(
          molarRatio: molarRatio,
          stock: '10',
          finalConc: '1',
          unit: molarRatio ? 'mM' : 'mg/mL',
          mw: '',
        );
        final row = calculateSingle();
        expect(row.stock, molarRatio ? '10.000 mM' : unavailable);
        expect(row.stockMass, molarRatio ? unavailable : '10.000 mg/mL');
        expect(row.finalConc, molarRatio ? '1.000 mM' : unavailable);
        expect(row.finalConcMass, molarRatio ? unavailable : '1.000 mg/mL');
        expect(row.volume, '10.000 uL');
        expect(
          copyCells().where((value) => value == unavailable),
          hasLength(2),
        );
        expect(notifier.buildCopyText(), isNot(contains('N/A')));
      },
    );

    test('$mode derives both final concentrations from the solved aliquot', () {
      setMain(
        molarRatio: molarRatio,
        stock: '10',
        finalConc: '',
        unit: 'mg/mL',
      );
      notifier.setSubstrateField(0, 'storageVolume', '10');
      final row = calculateSingle();
      expect(row.finalConc, '20.000 uM');
      expect(row.finalConcMass, '1.000 mg/mL');
      expect(row.stock, '200.000 uM');
      expect(row.stockMass, '10.000 mg/mL');
    });

    test(
      '$mode uses freshly solved paired values for a secondary substrate',
      () {
        setMain(
          molarRatio: molarRatio,
          stock: '10',
          finalConc: '1',
          unit: 'mg/mL',
        );
        notifier.toggleSubstrateEnabled(1);
        notifier.setSubstrateField(1, 'mw', '500');
        notifier.setSubstrateField(1, 'storageConc', '20');
        notifier.setSubstrateField(1, 'storageUnit', 'mg/mL');
        notifier.setSubstrateField(1, 'reactionRatio', '2');
        notifier.calculate();
        expect(current().statusLevel, StatusLevel.success);
        final secondary = current().rows.last;
        expect(secondary.stock, '40.000 mM');
        expect(secondary.stockMass, '20.000 mg/mL');
        expect(secondary.finalConc, molarRatio ? '40.000 uM' : '4.000 mM');
        expect(
          secondary.finalConcMass,
          molarRatio ? '20.000 ug/mL' : '2.000 mg/mL',
        );
        expect(secondary.volume, molarRatio ? '100.000 nL' : '10.000 uL');
      },
    );

    test(
      '$mode invalidates both bases and refreshes after editing molecular weight',
      () {
        setMain(
          molarRatio: molarRatio,
          stock: '10',
          finalConc: '1',
          unit: 'mg/mL',
        );
        expect(calculateSingle().finalConc, '20.000 uM');
        notifier.setSubstrateField(0, 'mw', '100');
        expect(current().rows, isEmpty);
        expect(notifier.buildCopyText(), isEmpty);
        final revised = calculateSingle();
        expect(revised.stock, '100.000 uM');
        expect(revised.finalConc, '10.000 uM');
        expect(revised.stockMass, '10.000 mg/mL');
        expect(revised.finalConcMass, '1.000 mg/mL');
        expect(notifier.buildCopyText(), isNot(contains('20.000 uM')));
      },
    );
  }

  test(
    'removing molecular weight clears previously available converted concentrations',
    () {
      setMain(molarRatio: false, stock: '10', finalConc: '1', unit: 'mg/mL');
      expect(calculateSingle().finalConc, '20.000 uM');
      notifier.setSubstrateField(0, 'mw', '');
      expect(current().rows, isEmpty);
      expect(notifier.buildCopyText(), isEmpty);
      final revised = calculateSingle();
      expect(revised.stock, unavailable);
      expect(revised.finalConc, unavailable);
      expect(revised.stockMass, '10.000 mg/mL');
      expect(revised.finalConcMass, '1.000 mg/mL');
      expect(notifier.buildCopyText(), isNot(contains('20.000 uM')));
    },
  );

  test(
    'changing ratio mode cannot change the meaning of concentration fields',
    () {
      setMain(molarRatio: true, stock: '10', finalConc: '1', unit: 'mg/mL');
      final original = calculateSingle();
      notifier.setRatioType(false);
      expect(current().rows, isEmpty);
      expect(notifier.buildCopyText(), isEmpty);
      final revised = calculateSingle();
      expect(revised.stock, original.stock);
      expect(revised.stockMass, original.stockMass);
      expect(revised.finalConc, original.finalConc);
      expect(revised.finalConcMass, original.finalConcMass);
      expect(revised.volume, original.volume);
    },
  );
}
