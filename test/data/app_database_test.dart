import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/data/app_database.dart';
import 'package:ilovebioconjugation/data/calculation_history.dart';
import 'package:ilovebioconjugation/data/calculation_input_snapshot.dart';
import 'package:ilovebioconjugation/data/substrate_template.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late SqfliteDatabase database;

  setUpAll(sqfliteFfiInit);
  setUp(() async {
    database = SqfliteDatabase(
      factory: databaseFactoryFfiNoIsolate,
      databasePath: inMemoryDatabasePath,
    );
    await database.init();
    addTearDown(() => database.db.close());
  });

  final snapshot = CalculationInputSnapshot(
    reactionVolume: '00100.000',
    reactionVolumeUnit: 'pL',
    ratioType: true,
    substrates: const [
      SubstrateInputSnapshot(
        enabled: true,
        name: ' trace stock ',
        mw: '',
        mwUnit: 'kDa',
        storageConc: '001.234567890123456',
        storageUnit: 'pM',
        finalConc: '1e-9',
        finalUnit: 'nM',
        reactionRatio: '1.000',
        storageVolume: '',
        storageVolumeUnit: 'nL',
      ),
      SubstrateInputSnapshot(
        enabled: false,
        name: 'draft',
        mw: 'unfinished',
        mwUnit: 'Da',
        storageConc: '',
        storageUnit: 'mg/mL',
        finalConc: '',
        finalUnit: 'mg/mL',
        reactionRatio: '',
        storageVolume: '',
        storageVolumeUnit: 'uL',
      ),
    ],
  );
  const main = SubstrateResult(
    sortOrder: 0,
    name: 'trace stock',
    role: 'main',
    molecularWeight: 123.456,
    storageConcMolar: 1.234567890123456e-9,
    finalConcMolar: 1e-12,
    storageVolume: 1e-9,
    reactionRatio: 1,
  );

  Future<int> save({CalculationInputSnapshot? inputs, String? secondaryName}) =>
      database.saveCalculation(
        createdAt: DateTime.utc(2026, 10, 2),
        ratioType: true,
        reactionVolume: 1e-7,
        totalStockVolume: 1e-9,
        diluentVolume: 9.9e-8,
        inputSnapshot: inputs,
        substrates: [
          main,
          if (secondaryName != null)
            SubstrateResult(
              sortOrder: 1,
              name: secondaryName,
              role: 'secondary',
            ),
        ],
      );

  test('new database round-trips exact inputs and numeric results', () async {
    final id = await save(inputs: snapshot);
    final records = await database.getHistory();
    expect(records.length, 1);
    final record = records.single;
    expect(record.id, id);
    expect(record.inputSnapshot!.toJson(), snapshot.toJson());
    expect(record.reactionVolume, 1e-7);
    expect(record.substrates.single.storageConcMolar, main.storageConcMolar);
    expect(record.substrates.single.finalConcMolar, main.finalConcMolar);
    expect(record.substrates.single.historyId, id);
  });

  test(
    'history loading returns newest page with correctly associated children',
    () async {
      await save(secondaryName: 'first secondary');
      final newest = await save(secondaryName: 'second secondary');
      final records = await database.getHistory(limit: 1);
      expect(records.single.id, newest);
      expect(records.single.substrates.map((s) => s.name), [
        'trace stock',
        'second secondary',
      ]);
      expect(await database.getHistory(limit: 0), isEmpty);
    },
  );

  test('failed child insert rolls back the entire calculation', () async {
    await database.db.execute('''
      CREATE TRIGGER reject_broken_substrate BEFORE INSERT ON substrate_results
      WHEN NEW.name = 'Broken'
      BEGIN SELECT RAISE(ABORT, 'simulated child insert failure'); END
    ''');
    await expectLater(
      save(inputs: snapshot, secondaryName: 'Broken'),
      throwsA(isA<DatabaseException>()),
    );
    expect(await database.getHistory(), isEmpty);
    expect(await database.db.query('substrate_results'), isEmpty);
    expect(await database.db.query('calculation_history'), isEmpty);
  });

  test(
    'deleting one record removes its children without affecting others',
    () async {
      final first = await save(secondaryName: 'first secondary');
      final second = await save(secondaryName: 'second secondary');
      await database.deleteHistory(first);
      expect((await database.getHistory()).map((record) => record.id), [
        second,
      ]);
      final children = await database.db.query('substrate_results');
      expect(children.length, 2);
      expect(children.every((row) => row['history_id'] == second), isTrue);
    },
  );

  test('clear removes history and children but retains templates', () async {
    await save(inputs: snapshot, secondaryName: 'second');
    await database.saveTemplate(
      const SubstrateTemplate(
        name: 'Keep me',
        createdAt: '2026-10-02',
        updatedAt: '2026-10-02',
      ),
    );
    await database.clearHistory();
    expect(await database.getHistory(), isEmpty);
    expect(await database.db.query('substrate_results'), isEmpty);
    expect((await database.getTemplates()).single.name, 'Keep me');
  });

  test('missing and malformed snapshots fall back to legacy results', () async {
    final id = await save();
    expect((await database.getHistory()).single.inputSnapshot, isNull);
    for (final value in [
      '{invalid',
      '[]',
      jsonEncode({'version': 99}),
      jsonEncode({...snapshot.toJson(), 'reactionVolumeUnit': 'bucket'}),
      jsonEncode({
        ...snapshot.toJson(),
        'substrates': [42],
      }),
    ]) {
      await database.db.update(
        'calculation_history',
        {'input_snapshot': value},
        where: 'id = ?',
        whereArgs: [id],
      );
      final record = (await database.getHistory()).single;
      expect(record.inputSnapshot, isNull);
      expect(record.substrates.single.name, 'trace stock');
    }
  });

  test(
    'planning batch metadata uses existing JSON column and corrupt recipes fall back safely',
    () async {
      const input = SubstrateInputSnapshot(
        enabled: true,
        name: 'Label',
        mw: '500',
        mwUnit: 'Da',
        storageConc: '10',
        storageUnit: 'mM',
        finalConc: '',
        finalUnit: 'uM',
        reactionRatio: '2',
        storageVolume: '',
        storageVolumeUnit: 'uL',
      );
      const recipe = WorkingStockProvenance(
        slot: 1,
        parentInput: input,
        workingConcentration: '2',
        workingUnit: 'mM',
        dilutionFactor: 5,
        parentVolumeMl: .001,
        diluentVolumeMl: .004,
        preparationVolumeMl: .005,
        requiredVolumeMl: .002,
        newAliquotMl: .001,
        minimumVolumeMl: .001,
        diluentName: 'PBS',
      );
      final planningInput = CalculationInputSnapshot(
        reactionVolume: '0100',
        reactionVolumeUnit: 'uL',
        ratioType: true,
        referenceSlot: 1,
        minimumPipettingVolumeUl: 2.5,
        substrates: const [input, input],
        gradient: GradientInputSnapshot(
          selectedSlot: 1,
          unit: 'uM',
          points: ['0', '.1', 'bad'],
          replicates: 3,
          extraPreparationFraction: .1,
          workingStocks: [recipe],
        ),
      );
      final id = await save(inputs: planningInput);
      final restored = (await database.getHistory()).single;
      expect(restored.inputSnapshot!.toJson(), planningInput.toJson());
      expect(await database.db.getVersion(), 2);
      final corrupted = planningInput.toJson();
      corrupted['gradient'] = {
        ...planningInput.gradient!.toJson(),
        'workingStocks': [
          {...recipe.toJson(), 'diluentVolumeMl': 100},
        ],
      };
      await database.db.update(
        'calculation_history',
        {'input_snapshot': jsonEncode(corrupted)},
        where: 'id = ?',
        whereArgs: [id],
      );
      final legacyFallback = (await database.getHistory()).single;
      expect(legacyFallback.inputSnapshot, isNull);
      expect(legacyFallback.substrates.single.name, 'trace stock');
    },
  );

  test(
    'v1 migration preserves old records and allows exact new snapshots',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'reaction-db-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final path = '${directory.path}/legacy.db';
      final legacy = await databaseFactoryFfiNoIsolate.openDatabase(
        path,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            await db.execute('''
          CREATE TABLE calculation_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT, created_at TEXT NOT NULL,
            ratio_type INTEGER NOT NULL, reaction_volume REAL,
            reaction_volume_unit TEXT DEFAULT 'mL',
            total_stock_volume REAL, diluent_volume REAL)
        ''');
            await db.execute('''
          CREATE TABLE substrate_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            history_id INTEGER NOT NULL REFERENCES calculation_history(id) ON DELETE CASCADE,
            sort_order INTEGER NOT NULL, name TEXT NOT NULL, role TEXT NOT NULL,
            molecular_weight REAL, mw_unit TEXT, storage_conc_molar REAL,
            storage_conc_mass REAL, storage_conc_unit TEXT, storage_volume REAL,
            storage_volume_unit TEXT, final_conc_molar REAL, final_conc_mass REAL,
            final_conc_unit TEXT, reaction_ratio REAL)
        ''');
            await db.execute('''
          CREATE TABLE substrate_templates (
            id INTEGER PRIMARY KEY AUTOINCREMENT, name TEXT NOT NULL UNIQUE,
            molecular_weight REAL, mw_unit TEXT DEFAULT 'Da',
            storage_concentration REAL, storage_unit TEXT DEFAULT 'mg/mL',
            default_final_conc REAL, default_final_unit TEXT DEFAULT 'mg/mL',
            default_reaction_ratio REAL, created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL)
        ''');
          },
        ),
      );
      final id = await legacy.insert('calculation_history', {
        'created_at': '2026-10-01T12:34:56',
        'ratio_type': 1,
        'reaction_volume': 1e-7,
      });
      await legacy.insert('substrate_results', {
        'history_id': id,
        'sort_order': 0,
        'name': 'Legacy',
        'role': 'main',
        'storage_conc_molar': 1.234567890123456e-9,
      });
      await legacy.insert('substrate_templates', {
        'name': 'Legacy template',
        'created_at': '2026-10-01',
        'updated_at': '2026-10-01',
      });
      await legacy.close();

      final migrated = SqfliteDatabase(
        factory: databaseFactoryFfiNoIsolate,
        databasePath: path,
      );
      await migrated.init();
      addTearDown(() => migrated.db.close());
      expect(await migrated.db.getVersion(), 2);
      final old = (await migrated.getHistory()).single;
      expect(old.inputSnapshot, isNull);
      expect(old.substrates.single.storageConcMolar, 1.234567890123456e-9);
      expect((await migrated.getTemplates()).single.name, 'Legacy template');
      await migrated.saveCalculation(
        createdAt: DateTime.utc(2026, 10, 2),
        ratioType: true,
        substrates: [main],
        inputSnapshot: snapshot,
      );
      final records = await migrated.getHistory();
      expect(records.length, 2);
      expect(records.first.inputSnapshot!.toJson(), snapshot.toJson());
      expect(records.last.id, id);
    },
  );
}
