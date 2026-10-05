import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilovebioconjugation/data/calculation_history.dart';
import 'package:ilovebioconjugation/data/calculation_input_snapshot.dart';
import 'package:ilovebioconjugation/data/substrate_template.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

abstract class AppDatabase {
  Future<void> init();
  Future<int> saveCalculation({
    required DateTime createdAt,
    required bool ratioType,
    double? reactionVolume,
    String reactionVolumeUnit = 'mL',
    double? totalStockVolume,
    double? diluentVolume,
    required List<SubstrateResult> substrates,
    CalculationInputSnapshot? inputSnapshot,
  });
  Future<List<CalculationHistory>> getHistory({int limit = 50});
  Future<void> deleteHistory(int id);
  Future<void> clearHistory();
  Future<int> saveTemplate(SubstrateTemplate template);
  Future<List<SubstrateTemplate>> getTemplates();
  Future<void> deleteTemplate(int id);
}

class SqfliteDatabase implements AppDatabase {
  Database? _db;
  final DatabaseFactory? factory;
  final String? databasePath;

  /// Optional overrides allow isolated databases without platform directories.
  SqfliteDatabase({this.factory, this.databasePath});

  @override
  Future<void> init() async {
    if (factory == null &&
        !kIsWeb &&
        (Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    }
    final dbPath =
        databasePath ??
        p.join(
          (await getApplicationSupportDirectory()).path,
          'ilovereaction.db',
        );
    _db = await (factory ?? databaseFactory).openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 2,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onUpgrade: (db, oldVersion, newVersion) async {
          if (oldVersion < 2) {
            await db.execute(
              'ALTER TABLE calculation_history ADD COLUMN input_snapshot TEXT',
            );
            await db.execute(
              'CREATE INDEX IF NOT EXISTS substrate_history_index '
              'ON substrate_results(history_id, sort_order)',
            );
          }
        },
        onCreate: (db, version) async {
          await db.execute('''
          CREATE TABLE calculation_history (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at TEXT NOT NULL,
            ratio_type INTEGER NOT NULL,
            reaction_volume REAL,
            reaction_volume_unit TEXT DEFAULT 'mL',
            total_stock_volume REAL,
            diluent_volume REAL,
            input_snapshot TEXT
          )
        ''');
          await db.execute('''
          CREATE TABLE substrate_results (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            history_id INTEGER NOT NULL REFERENCES calculation_history(id) ON DELETE CASCADE,
            sort_order INTEGER NOT NULL,
            name TEXT NOT NULL,
            role TEXT NOT NULL,
            molecular_weight REAL,
            mw_unit TEXT,
            storage_conc_molar REAL,
            storage_conc_mass REAL,
            storage_conc_unit TEXT,
            storage_volume REAL,
            storage_volume_unit TEXT,
            final_conc_molar REAL,
            final_conc_mass REAL,
            final_conc_unit TEXT,
            reaction_ratio REAL
          )
        ''');
          await db.execute('''
          CREATE TABLE substrate_templates (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL UNIQUE,
            molecular_weight REAL,
            mw_unit TEXT DEFAULT 'Da',
            storage_concentration REAL,
            storage_unit TEXT DEFAULT 'mg/mL',
            default_final_conc REAL,
            default_final_unit TEXT DEFAULT 'mg/mL',
            default_reaction_ratio REAL,
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');
          await db.execute(
            'CREATE INDEX substrate_history_index '
            'ON substrate_results(history_id, sort_order)',
          );
        },
      ),
    );
  }

  Database get db {
    if (_db == null) {
      throw StateError('Database not initialized. Call init() first.');
    }
    return _db!;
  }

  @override
  Future<int> saveCalculation({
    required DateTime createdAt,
    required bool ratioType,
    double? reactionVolume,
    String reactionVolumeUnit = 'mL',
    double? totalStockVolume,
    double? diluentVolume,
    required List<SubstrateResult> substrates,
    CalculationInputSnapshot? inputSnapshot,
  }) async {
    return db.transaction((txn) async {
      final historyId = await txn.insert('calculation_history', {
        'created_at': createdAt.toIso8601String(),
        'ratio_type': ratioType ? 1 : 0,
        'reaction_volume': reactionVolume,
        'reaction_volume_unit': reactionVolumeUnit,
        'total_stock_volume': totalStockVolume,
        'diluent_volume': diluentVolume,
        'input_snapshot': inputSnapshot == null
            ? null
            : jsonEncode(inputSnapshot.toJson()),
      });
      for (final sub in substrates) {
        await txn.insert('substrate_results', {
          'history_id': historyId,
          'sort_order': sub.sortOrder,
          'name': sub.name,
          'role': sub.role,
          'molecular_weight': sub.molecularWeight,
          'mw_unit': sub.mwUnit,
          'storage_conc_molar': sub.storageConcMolar,
          'storage_conc_mass': sub.storageConcMass,
          'storage_conc_unit': sub.storageConcUnit,
          'storage_volume': sub.storageVolume,
          'storage_volume_unit': sub.storageVolumeUnit,
          'final_conc_molar': sub.finalConcMolar,
          'final_conc_mass': sub.finalConcMass,
          'final_conc_unit': sub.finalConcUnit,
          'reaction_ratio': sub.reactionRatio,
        });
      }
      return historyId;
    });
  }

  @override
  Future<List<CalculationHistory>> getHistory({int limit = 50}) async {
    if (limit <= 0) return [];
    return db.transaction((txn) async {
      final rows = await txn.query(
        'calculation_history',
        orderBy: 'id DESC',
        limit: limit,
      );
      if (rows.isEmpty) return <CalculationHistory>[];
      // Fetch the page's children together rather than one query per record.
      final allSubRows = await txn.query(
        'substrate_results',
        where:
            'history_id IN '
            '(SELECT id FROM calculation_history ORDER BY id DESC LIMIT ?)',
        whereArgs: [limit],
        orderBy: 'history_id, sort_order',
      );
      final byHistory = <int, List<Map<String, Object?>>>{};
      for (final row in allSubRows) {
        byHistory.putIfAbsent(row['history_id'] as int, () => []).add(row);
      }
      final result = <CalculationHistory>[];
      for (final row in rows) {
        final subRows = byHistory[row['id']] ?? <Map<String, Object?>>[];
        result.add(
          CalculationHistory(
            id: row['id'] as int,
            createdAt: row['created_at'] as String,
            ratioType: (row['ratio_type'] as int) == 1,
            reactionVolume: (row['reaction_volume'] as num?)?.toDouble(),
            reactionVolumeUnit: row['reaction_volume_unit'] as String? ?? 'mL',
            totalStockVolume: (row['total_stock_volume'] as num?)?.toDouble(),
            diluentVolume: (row['diluent_volume'] as num?)?.toDouble(),
            inputSnapshot: _readSnapshot(row['input_snapshot'] as String?),
            substrates: subRows
                .map(
                  (s) => SubstrateResult(
                    id: s['id'] as int,
                    historyId: s['history_id'] as int,
                    sortOrder: s['sort_order'] as int,
                    name: s['name'] as String,
                    role: s['role'] as String,
                    molecularWeight: (s['molecular_weight'] as num?)
                        ?.toDouble(),
                    mwUnit: s['mw_unit'] as String?,
                    storageConcMolar: (s['storage_conc_molar'] as num?)
                        ?.toDouble(),
                    storageConcMass: (s['storage_conc_mass'] as num?)
                        ?.toDouble(),
                    storageConcUnit: s['storage_conc_unit'] as String?,
                    storageVolume: (s['storage_volume'] as num?)?.toDouble(),
                    storageVolumeUnit: s['storage_volume_unit'] as String?,
                    finalConcMolar: (s['final_conc_molar'] as num?)?.toDouble(),
                    finalConcMass: (s['final_conc_mass'] as num?)?.toDouble(),
                    finalConcUnit: s['final_conc_unit'] as String?,
                    reactionRatio: (s['reaction_ratio'] as num?)?.toDouble(),
                  ),
                )
                .toList(),
          ),
        );
      }
      return result;
    });
  }

  CalculationInputSnapshot? _readSnapshot(String? encoded) {
    if (encoded == null) return null;
    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map<String, dynamic>) return null;
      return CalculationInputSnapshot.fromJson(decoded);
    } on FormatException {
      // Old or corrupt snapshots must not make the result history unreadable.
      return null;
    } on ArgumentError {
      // Scientific unit validation can reject finite text whose conversion
      // overflows or underflows. Preserve the stored result's legacy fallback.
      return null;
    }
  }

  @override
  Future<void> deleteHistory(int id) async {
    await db.transaction((txn) async {
      await txn.delete(
        'substrate_results',
        where: 'history_id = ?',
        whereArgs: [id],
      );
      await txn.delete('calculation_history', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<void> clearHistory() async {
    await db.transaction((txn) async {
      await txn.delete('substrate_results');
      await txn.delete('calculation_history');
    });
  }

  @override
  Future<int> saveTemplate(SubstrateTemplate template) async {
    return db.insert('substrate_templates', {
      'name': template.name,
      'molecular_weight': template.molecularWeight,
      'mw_unit': template.mwUnit,
      'storage_concentration': template.storageConcentration,
      'storage_unit': template.storageUnit,
      'default_final_conc': template.defaultFinalConc,
      'default_final_unit': template.defaultFinalUnit,
      'default_reaction_ratio': template.defaultReactionRatio,
      'created_at': template.createdAt,
      'updated_at': template.updatedAt,
    });
  }

  @override
  Future<List<SubstrateTemplate>> getTemplates() async {
    final rows = await db.query('substrate_templates', orderBy: 'id DESC');
    return rows
        .map(
          (r) => SubstrateTemplate(
            id: r['id'] as int,
            name: r['name'] as String,
            molecularWeight: (r['molecular_weight'] as num?)?.toDouble(),
            mwUnit: r['mw_unit'] as String? ?? 'Da',
            storageConcentration: (r['storage_concentration'] as num?)
                ?.toDouble(),
            storageUnit: r['storage_unit'] as String? ?? 'mg/mL',
            defaultFinalConc: (r['default_final_conc'] as num?)?.toDouble(),
            defaultFinalUnit: r['default_final_unit'] as String? ?? 'mg/mL',
            defaultReactionRatio: (r['default_reaction_ratio'] as num?)
                ?.toDouble(),
            createdAt: r['created_at'] as String,
            updatedAt: r['updated_at'] as String,
          ),
        )
        .toList();
  }

  @override
  Future<void> deleteTemplate(int id) async {
    await db.delete('substrate_templates', where: 'id = ?', whereArgs: [id]);
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  throw UnimplementedError('Override appDatabaseProvider in main.dart');
});
