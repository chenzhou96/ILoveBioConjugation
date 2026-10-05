import 'dart:async';

import 'package:ilovebioconjugation/data/app_database.dart';
import 'package:ilovebioconjugation/data/calculation_history.dart';
import 'package:ilovebioconjugation/data/calculation_input_snapshot.dart';
import 'package:ilovebioconjugation/data/substrate_template.dart';

class FakeDatabase implements AppDatabase {
  final records = <CalculationHistory>[];
  final saveRequests = <CalculationHistory>[];
  final templates = <SubstrateTemplate>[];
  Completer<int>? saveGate;
  Object? saveError;
  int historyReads = 0;

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
    CalculationInputSnapshot? inputSnapshot,
  }) async {
    final record = CalculationHistory(
      id: saveRequests.length + 1,
      createdAt: createdAt.toIso8601String(),
      ratioType: ratioType,
      reactionVolume: reactionVolume,
      reactionVolumeUnit: reactionVolumeUnit,
      totalStockVolume: totalStockVolume,
      diluentVolume: diluentVolume,
      substrates: substrates,
      inputSnapshot: inputSnapshot,
    );
    saveRequests.add(record);
    final saveGate = this.saveGate;
    final saveError = this.saveError;
    if (saveGate != null) await saveGate.future;
    if (saveError != null) throw saveError;
    records.add(record);
    return record.id!;
  }

  @override
  Future<List<CalculationHistory>> getHistory({int limit = 50}) async {
    historyReads++;
    return records.reversed.take(limit).toList();
  }

  @override
  Future<void> deleteHistory(int id) async =>
      records.removeWhere((record) => record.id == id);

  @override
  Future<void> clearHistory() async => records.clear();

  @override
  Future<int> saveTemplate(SubstrateTemplate template) async {
    templates.add(template);
    return templates.length;
  }

  @override
  Future<List<SubstrateTemplate>> getTemplates() async => templates.toList();

  @override
  Future<void> deleteTemplate(int id) async =>
      templates.removeWhere((template) => template.id == id);
}
