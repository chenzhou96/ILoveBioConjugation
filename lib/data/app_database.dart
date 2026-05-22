import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilovebioconjunction/data/calculation_history.dart';
import 'package:ilovebioconjunction/data/substrate_template.dart';

/// Abstract database interface — swap implementations for sqflite later.
abstract class AppDatabase {
  Future<void> init();

  // History
  Future<int> saveCalculation({
    required DateTime createdAt,
    required bool ratioType,
    double? reactionVolume,
    String reactionVolumeUnit = 'mL',
    double? totalStockVolume,
    double? diluentVolume,
    required List<SubstrateResult> substrates,
  });
  Future<List<CalculationHistory>> getHistory({int limit = 50});
  Future<void> deleteHistory(int id);
  Future<void> clearHistory();

  // Templates
  Future<int> saveTemplate(SubstrateTemplate template);
  Future<List<SubstrateTemplate>> getTemplates();
  Future<void> deleteTemplate(int id);
}

/// In-memory implementation — replace with sqflite when ready.
class InMemoryDatabase implements AppDatabase {
  final List<CalculationHistory> _history = [];
  final List<SubstrateTemplate> _templates = [];
  int _nextHistoryId = 1;
  int _nextTemplateId = 1;

  @override
  Future<void> init() async {}

  @override
  Future<int> saveCalculation({
    required DateTime createdAt,
    required bool ratioType,
    double? reactionVolume,
    String reactionVolumeUnit = 'mL',
    double? totalStockVolume,
    double? diluentVolume,
    required List<SubstrateResult> substrates,
  }) async {
    final id = _nextHistoryId++;
    _history.insert(
      0,
      CalculationHistory(
        id: id,
        createdAt: createdAt.toIso8601String(),
        ratioType: ratioType,
        reactionVolume: reactionVolume,
        reactionVolumeUnit: reactionVolumeUnit,
        totalStockVolume: totalStockVolume,
        diluentVolume: diluentVolume,
        substrates: substrates,
      ),
    );
    return id;
  }

  @override
  Future<List<CalculationHistory>> getHistory({int limit = 50}) async {
    return _history.take(limit).toList();
  }

  @override
  Future<void> deleteHistory(int id) async {
    _history.removeWhere((h) => h.id == id);
  }

  @override
  Future<void> clearHistory() async {
    _history.clear();
  }

  @override
  Future<int> saveTemplate(SubstrateTemplate template) async {
    final id = _nextTemplateId++;
    _templates.add(SubstrateTemplate(
      id: id,
      name: template.name,
      molecularWeight: template.molecularWeight,
      mwUnit: template.mwUnit,
      storageConcentration: template.storageConcentration,
      storageUnit: template.storageUnit,
      defaultFinalConc: template.defaultFinalConc,
      defaultFinalUnit: template.defaultFinalUnit,
      defaultReactionRatio: template.defaultReactionRatio,
      createdAt: template.createdAt,
      updatedAt: template.updatedAt,
    ));
    return id;
  }

  @override
  Future<List<SubstrateTemplate>> getTemplates() async {
    return _templates.toList();
  }

  @override
  Future<void> deleteTemplate(int id) async {
    _templates.removeWhere((t) => t.id == id);
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) => InMemoryDatabase());
