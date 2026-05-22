import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilovebioconjunction/data/app_database.dart';
import 'package:ilovebioconjunction/data/substrate_template.dart';

final templateListProvider = FutureProvider<List<SubstrateTemplate>>((ref) async {
  final db = ref.read(appDatabaseProvider);
  return db.getTemplates();
});

class TemplateNotifier extends Notifier<List<SubstrateTemplate>?> {
  @override
  List<SubstrateTemplate>? build() => null;

  Future<void> saveTemplate({
    required String name,
    double? molecularWeight,
    String mwUnit = 'Da',
    double? storageConcentration,
    String storageUnit = 'mg/mL',
    double? defaultFinalConc,
    String defaultFinalUnit = 'mg/mL',
    double? defaultReactionRatio,
  }) async {
    final db = ref.read(appDatabaseProvider);
    final now = DateTime.now().toIso8601String();
    await db.saveTemplate(SubstrateTemplate(
      name: name,
      molecularWeight: molecularWeight,
      mwUnit: mwUnit,
      storageConcentration: storageConcentration,
      storageUnit: storageUnit,
      defaultFinalConc: defaultFinalConc,
      defaultFinalUnit: defaultFinalUnit,
      defaultReactionRatio: defaultReactionRatio,
      createdAt: now,
      updatedAt: now,
    ));
    ref.invalidate(templateListProvider);
  }

  Future<void> deleteTemplate(int id) async {
    final db = ref.read(appDatabaseProvider);
    await db.deleteTemplate(id);
    ref.invalidate(templateListProvider);
  }
}

final templateNotifierProvider =
    NotifierProvider<TemplateNotifier, List<SubstrateTemplate>?>(
  TemplateNotifier.new,
);
