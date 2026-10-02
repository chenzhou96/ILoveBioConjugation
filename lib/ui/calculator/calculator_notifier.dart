import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilovebioconjugation/core/planning.dart';
import 'package:ilovebioconjugation/core/planning.dart' as planning;
import 'package:ilovebioconjugation/core/validators.dart';
import 'package:ilovebioconjugation/data/calculation_history.dart';
import 'package:ilovebioconjugation/data/calculation_input_snapshot.dart';
import 'package:ilovebioconjugation/data/substrate_template.dart';
import 'package:ilovebioconjugation/data/app_database.dart';
import 'package:ilovebioconjugation/ui/calculator/state.dart';
import 'package:ilovebioconjugation/ui/history/history_screen.dart';
import 'package:ilovebioconjugation/ui/settings/app_settings.dart';

/// Provider for the calculator state.
final calculatorProvider =
    NotifierProvider<CalculatorNotifier, CalculatorState>(
      CalculatorNotifier.new,
    );

class CalculatorNotifier extends Notifier<CalculatorState> {
  static const maxSecondaries = 3;
  static const storageUnits = [
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
  static const volumeUnits = ['L', 'mL', 'uL', 'nL', 'pL'];
  static const mwUnits = ['Da', 'kDa'];

  bool _disposed = false;
  int _lifecycle = 0;
  int _calculationGeneration = 0;
  final Map<WorkingStockProposal, (CalculationResult, int)> _proposalSources =
      {};

  @override
  CalculatorState build() {
    _disposed = false;
    _lifecycle++;
    ref.onDispose(() => _disposed = true);
    _proposalSources.clear();
    ref.listen<double>(
      appSettingsProvider.select(
        (settings) => settings.minimumPipettingVolumeUl,
      ),
      (previous, next) {
        if (previous != next && !_disposed) _refreshThreshold();
      },
    );
    return CalculatorState(
      substrates: _defaultSubstrates(),
      reactionVolumeUnit: ref.read(appSettingsProvider).defaultVolumeUnit,
    );
  }

  List<SubstrateInput> _defaultSubstrates({bool enableFirstSecondary = true}) {
    final settings = ref.read(appSettingsProvider);
    final substrates = <SubstrateInput>[
      SubstrateInput(
        enabled: true,
        name: '主底物',
        storageUnit: settings.defaultConcentrationUnit,
        finalUnit: settings.defaultConcentrationUnit,
        reactionRatio: '1',
        mwUnit: 'kDa',
        storageVolumeUnit: settings.defaultVolumeUnit,
      ),
      for (var i = 1; i <= maxSecondaries; i++)
        SubstrateInput(
          enabled: enableFirstSecondary && i == 1,
          name: '副底物$i',
          storageUnit: settings.defaultConcentrationUnit,
          finalUnit: settings.defaultConcentrationUnit,
          mwUnit: 'Da',
          storageVolumeUnit: settings.defaultVolumeUnit,
        ),
    ];
    return substrates;
  }

  // ── field setters ────────────────────────────────────────────────────

  void setReactionVolume(String value) {
    _replaceInputs(state.copyWith(reactionVolume: value));
  }

  void setReactionVolumeUnit(String unit) {
    _replaceInputs(state.copyWith(reactionVolumeUnit: unit));
  }

  void setRatioType(bool molar) {
    _replaceInputs(state.copyWith(ratioType: molar));
  }

  void setSubstrateField(int index, String field, String value) {
    final substrates = state.substrates.toList();
    final old = substrates[index];
    substrates[index] = switch (field) {
      'name' => old.copyWith(name: value),
      'mw' => old.copyWith(mw: value),
      'mwUnit' => old.copyWith(mwUnit: value),
      'storageConc' => old.copyWith(storageConc: value),
      'storageUnit' => old.copyWith(storageUnit: value),
      'finalConc' => old.copyWith(finalConc: value),
      'finalUnit' => old.copyWith(finalUnit: value),
      'reactionRatio' => old.copyWith(reactionRatio: value),
      'storageVolume' => old.copyWith(storageVolume: value),
      'storageVolumeUnit' => old.copyWith(storageVolumeUnit: value),
      _ => old,
    };
    final editedStock = const [
      'name',
      'mw',
      'mwUnit',
      'storageConc',
      'storageUnit',
    ].contains(field);
    _replaceInputs(
      state.copyWith(
        substrates: substrates,
        workingStocks: editedStock
            ? state.workingStocks
                  .where((recipe) => recipe.slot != index)
                  .toList()
            : state.workingStocks,
      ),
    );
  }

  void toggleSubstrateEnabled(int index) {
    if (index == 0 || index == state.referenceSlot) {
      state = state.copyWith(planningMessage: '请先切换投料比参照，再停用该底物。');
      return;
    }
    final substrates = state.substrates.toList();
    substrates[index] = substrates[index].copyWith(
      enabled: !substrates[index].enabled,
    );
    _replaceInputs(state.copyWith(substrates: substrates));
  }

  /// Apply a complete template, clearing fields the template does not supply.
  void applyTemplate(int index, SubstrateTemplate template) {
    final substrates = state.substrates.toList();
    substrates[index] = SubstrateInput(
      enabled: substrates[index].enabled,
      name: template.name,
      mw: template.molecularWeight?.toString() ?? '',
      mwUnit: template.mwUnit,
      storageConc: template.storageConcentration?.toString() ?? '',
      storageUnit: template.storageUnit,
      finalConc: template.defaultFinalConc?.toString() ?? '',
      finalUnit: template.defaultFinalUnit,
      reactionRatio:
          template.defaultReactionRatio?.toString() ??
          (index == state.referenceSlot ? '1' : ''),
      // A template describes a stock, not a previous reaction's aliquot.
      storageVolume: '',
      storageVolumeUnit: ref.read(appSettingsProvider).defaultVolumeUnit,
    );
    _replaceInputs(
      state.copyWith(
        substrates: substrates,
        workingStocks: state.workingStocks
            .where((recipe) => recipe.slot != index)
            .toList(),
      ),
    );
  }

  void _replaceInputs(
    CalculatorState next, {
    String message = '参数已更改，请重新运行计算。',
    bool preserveGradientStocks = false,
  }) {
    _proposalSources.clear();
    state = next.copyWith(
      clearRawResult: true,
      clearGradientPlan: true,
      gradientWorkingStocks: preserveGradientStocks
          ? next.gradientWorkingStocks
          : const [],
      planningMessage: '',
      rows: const [],
      summaryRows: const [],
      metrics: const ResultMetrics(),
      errorMessage: '就绪',
      statusMessage: message,
      statusLevel: StatusLevel.info,
    );
  }

  CalculationInputSnapshot captureInputs() => _captureInputs();

  CalculationInputSnapshot _captureInputs({
    CalculatorState? source,
    bool includeGradient = true,
  }) {
    final input = source ?? state;
    final gradient = includeGradient ? input.gradientSpec : null;
    return CalculationInputSnapshot(
      reactionVolume: input.reactionVolume,
      reactionVolumeUnit: input.reactionVolumeUnit,
      ratioType: input.ratioType,
      referenceSlot: input.referenceSlot,
      minimumPipettingVolumeUl: ref
          .read(appSettingsProvider)
          .minimumPipettingVolumeUl,
      workingStocks: input.workingStocks,
      gradient: gradient == null
          ? null
          : GradientInputSnapshot(
              selectedSlot: gradient.selectedSlot,
              proteinSlot: gradient.proteinSlot,
              unit: gradient.unit,
              points: gradient.points,
              replicates: gradient.replicates,
              extraPreparationFraction: gradient.extraPreparationFraction,
              workingStocks: input.gradientWorkingStocks,
            ),
      substrates: input.substrates.map((s) => s.toSnapshot()).toList(),
    );
  }

  double get _minimumVolumeMl =>
      ref.read(appSettingsProvider).minimumPipettingVolumeUl / 1000;

  // ── calculation ──────────────────────────────────────────────────────

  void calculate() {
    final generation = ++_calculationGeneration;
    _proposalSources.clear();
    try {
      final inputSnapshot = _captureInputs(includeGradient: false);
      final result = solveCalculation(
        inputSnapshot,
        minimumVolumeMl: _minimumVolumeMl,
      );
      state = _withResult(
        state.copyWith(
          historySaveError: '',
          clearGradientPlan: true,
          planningMessage: '',
        ),
        result,
      );
      unawaited(_saveHistory(result, inputSnapshot, generation));
    } catch (e) {
      state = state.copyWith(
        errorMessage: '计算错误: $e',
        metrics: const ResultMetrics(),
        rows: [],
        summaryRows: [],
        clearRawResult: true,
        clearGradientPlan: true,
        statusMessage: '计算失败，请检查输入条件。',
        statusLevel: StatusLevel.error,
      );
    }
  }

  CalculatorState _withResult(
    CalculatorState source,
    CalculationResult result,
  ) {
    final rows = <ResultRow>[];
    final minimum = _minimumVolumeMl;
    for (final chem in result.substrates) {
      final low = result.warnings.any(
        (warning) => warning.slot == chem.slot && warning.code == 'low_volume',
      );
      rows.add(
        ResultRow(
          sourceSlot: chem.slot,
          role: chem.slot == 0 ? '主底物' : '副底物${chem.slot}',
          name: chem.name,
          stock: _formatConcentration(
            chem.stockMolarMm,
            'molar_conc',
            chem.molecularWeightDa,
          ),
          finalConc: _formatConcentration(
            chem.finalMolarMm,
            'molar_conc',
            chem.molecularWeightDa,
          ),
          stockMass: _formatConcentration(
            chem.stockMassMgMl,
            'mass_conc',
            chem.molecularWeightDa,
          ),
          finalConcMass: _formatConcentration(
            chem.finalMassMgMl,
            'mass_conc',
            chem.molecularWeightDa,
          ),
          volume: _formatWithUnit(chem.aliquotMl, 'volume'),
          volumePct: _formatPercent(chem.aliquotMl, result.totalVolumeMl),
          ratio: chem.ratio == null ? 'N/A' : _formatNumber(chem.ratio!, 4),
          lowVolume: low,
          warning: [
            if (low)
              '取样体积低于本实验室最小可靠移液量 ${_formatWithUnit(minimum, 'volume')}，建议先配工作液。',
            ...result.warnings
                .where(
                  (warning) =>
                      warning.slot == chem.slot && warning.code != 'low_volume',
                )
                .map((warning) => warning.message),
          ].join(' '),
        ),
      );
    }
    final reference = result.substrates.firstWhere(
      (s) => s.slot == result.referenceSlot,
    );
    return source.copyWith(
      rawResult: result,
      rows: rows,
      errorMessage: '就绪',
      metrics: ResultMetrics(
        totalVolume: _formatWithUnit(result.totalVolumeMl, 'volume'),
        stockVolume: _formatWithUnit(result.stockVolumeMl, 'volume'),
        diluentVolume: _formatWithUnit(result.diluentVolumeMl, 'volume'),
        substrateCount: '${result.substrates.length}',
      ),
      summaryRows: [
        ('反应体积', _formatWithUnit(result.totalVolumeMl, 'volume')),
        (
          '反应体积来源',
          result.input.reactionVolume.trim().isEmpty ? '根据已知条件推导' : '用户指定',
        ),
        ('投料比类型', result.ratioType ? '摩尔比' : '质量比'),
        (
          '投料比参照',
          reference.ratio == null
              ? '${reference.name}（用量为 0，投料比不适用）'
              : '${reference.name} = 1',
        ),
        ('已启用副底物', '${result.substrates.length - 1}'),
        ('母液总体积', _formatWithUnit(result.stockVolumeMl, 'volume')),
        ('补加溶剂体积', _formatWithUnit(result.diluentVolumeMl, 'volume')),
        for (final warning in result.warnings) ('操作提醒', warning.message),
      ],
      statusMessage: rows.any((row) => row.lowVolume)
          ? '计算完成；存在低于可靠移液量的取样，请查看工作液建议。'
          : result.warnings.isNotEmpty
          ? '计算完成；请核对结果中的操作可行性提示。'
          : '计算完成，请核对取样清单。',
      statusLevel: StatusLevel.success,
    );
  }

  void _refreshThreshold() {
    _proposalSources.clear();
    if (state.rawResult == null) return;
    try {
      final result = solveCalculation(
        _captureInputs(includeGradient: false),
        minimumVolumeMl: _minimumVolumeMl,
      );
      final hadGradient = state.gradientPlan != null;
      state = _withResult(state, result);
      if (hadGradient && state.gradientSpec != null) {
        state = state.copyWith(
          gradientPlan: _generateCurrentGradient(result, state.gradientSpec!),
        );
      }
    } catch (_) {
      _replaceInputs(state);
    }
  }

  /// Change the global ratio reference without changing substrate identity.
  /// Only explicit positive inputs may become a new reference; blank inferred
  /// ratios remain blank and therefore cannot silently become new constraints.
  bool setReferenceSlot(int slot) {
    if (slot == state.referenceSlot) return true;
    if (slot < 0 ||
        slot >= state.substrates.length ||
        !state.substrates[slot].enabled) {
      state = state.copyWith(planningMessage: '请选择已启用的投料比参照。');
      return false;
    }
    final current = state.rawResult;
    if (current != null &&
        (current.substrateAt(slot).basisFinal(current.ratioType) ?? 0) <= 0) {
      state = state.copyWith(planningMessage: '用量为 0 的试剂不能作为投料比参照。');
      return false;
    }
    final denominator = double.tryParse(
      state.substrates[slot].reactionRatio.trim(),
    );
    if (denominator == null || !denominator.isFinite || denominator <= 0) {
      state = state.copyWith(
        planningMessage: '新参照需要明确填写大于 0 的投料比；推导值不会自动填入输入。',
      );
      return false;
    }
    final inputs = state.substrates.toList();
    for (var i = 0; i < inputs.length; i++) {
      final text = inputs[i].reactionRatio.trim();
      final ratio = text.isEmpty && i == state.referenceSlot
          ? 1.0
          : double.tryParse(text);
      if (ratio == null) {
        if (text.isEmpty) continue;
        state = state.copyWith(planningMessage: '已填写的投料比不是有效数字，请先修正后再切换参照。');
        return false;
      }
      final normalized = ratio / denominator;
      if (!ratio.isFinite ||
          ratio <= 0 ||
          !normalized.isFinite ||
          normalized <= 0) {
        state = state.copyWith(planningMessage: '投料比无法归一化，请检查已填写的比例。');
        return false;
      }
      inputs[i] = inputs[i].copyWith(
        reactionRatio: i == slot ? '1' : normalized.toString(),
      );
    }
    _replaceInputs(state.copyWith(substrates: inputs, referenceSlot: slot));
    return true;
  }

  WorkingStockProposal? proposeWorkingStock(
    int slot, {
    double? dilutionFactor,
    String diluentName = '',
    double extraFraction = 0,
  }) {
    final result = state.rawResult;
    if (result == null) {
      state = state.copyWith(planningMessage: '请先运行计算，才能生成工作液建议。');
      return null;
    }
    try {
      final proposal = planning.proposeWorkingStock(
        result,
        slot: slot,
        minimumVolumeMl: _minimumVolumeMl,
        dilutionFactor: dilutionFactor,
        diluentName: diluentName,
        extraPreparationFraction: extraFraction,
      );
      _proposalSources[proposal] = (result, slot);
      state = state.copyWith(planningMessage: '');
      return proposal;
    } catch (error) {
      state = state.copyWith(planningMessage: '无法生成工作液建议：$error');
      return null;
    }
  }

  bool adoptWorkingStock(WorkingStockProposal proposal) {
    final origin = _proposalSources[proposal];
    if (origin == null || !identical(origin.$1, state.rawResult)) {
      state = state.copyWith(planningMessage: '输入或设置已更改，请重新生成工作液建议。');
      return false;
    }
    return _adoptWorkingStock(proposal, origin.$1, origin.$2);
  }

  /// Adopt only the batch's shared stock. Baseline input and calculation stay
  /// unchanged, including when that baseline lies outside the gradient range.
  bool adoptGradientWorkingStock(GradientWorkingStockProposal proposal) {
    final original = state.gradientPlan;
    if (!identical(proposal.sourcePlan, original) || original == null) {
      state = state.copyWith(planningMessage: '梯度条件已更改，请重新生成共同工作液建议。');
      return false;
    }
    final shared = proposal.shared;
    if (!proposal.feasible ||
        shared == null ||
        !shared.feasible ||
        !shared.needsDilution) {
      state = state.copyWith(
        planningMessage: shared != null && !shared.needsDilution
            ? '现有母液已满足最小移液量，无需采用新的工作液。'
            : '只有可行的共同工作液可以一次采用；两档建议请分别配制。',
      );
      return false;
    }
    if (state.workingStocks.any((recipe) => recipe.slot == shared.slot)) {
      state = state.copyWith(
        planningMessage: '该试剂的基线已采用工作液，请先恢复原母液或历史输入，再重新配制。',
      );
      return false;
    }
    try {
      final replacement = applyGradientWorkingStock(original, proposal);
      final slot = shared.slot;
      var parent = state.substrates[slot];
      for (final prior in state.gradientWorkingStocks.where(
        (s) => s.slot == slot,
      )) {
        parent = parent.copyWith(
          storageConc: prior.workingConcentration,
          storageUnit: prior.workingUnit,
        );
      }
      final stock = isMolarUnit(parent.storageUnit)
          ? shared.stockMolarMm
          : shared.stockMassMgMl;
      if (stock == null) throw StateError('工作液浓度无法换算。');
      final provenance = WorkingStockProvenance(
        slot: slot,
        parentInput: parent.toSnapshot(),
        workingConcentration:
            (stock / convertConcentrationToBaseUnit(1, parent.storageUnit))
                .toString(),
        workingUnit: parent.storageUnit,
        dilutionFactor: shared.factor,
        parentVolumeMl: shared.parentStockMl,
        diluentVolumeMl: shared.diluentMl,
        preparationVolumeMl: shared.preparationVolumeMl,
        requiredVolumeMl: shared.requiredVolumeMl,
        newAliquotMl: shared.newAliquotMl,
        minimumVolumeMl: shared.minimumVolumeMl,
        diluentName: shared.diluentName,
      );
      state = state.copyWith(
        gradientPlan: replacement,
        gradientWorkingStocks: [...state.gradientWorkingStocks, provenance],
        planningMessage: '已为梯度采用共同工作液，基线输入保持不变。',
        historySaveError: '',
      );
      unawaited(
        _saveHistory(
          original.baseline,
          _captureInputs(),
          ++_calculationGeneration,
        ),
      );
      return true;
    } catch (error) {
      state = state.copyWith(planningMessage: '未采用共同工作液：$error');
      return false;
    }
  }

  bool _adoptWorkingStock(
    WorkingStockProposal proposal,
    CalculationResult baseline,
    int slot,
  ) {
    if (state.workingStocks.any((recipe) => recipe.slot == slot)) {
      state = state.copyWith(planningMessage: '该试剂已采用工作液，请先恢复原母液或历史输入，再重新配制。');
      return false;
    }
    if (!proposal.needsDilution || proposal.diluentName.trim().isEmpty) {
      state = state.copyWith(
        planningMessage: !proposal.needsDilution
            ? '现有母液已满足最小移液量，无需采用新的工作液。'
            : '请明确填写经实验确认兼容的稀释液。',
      );
      return false;
    }
    if (!proposal.feasible) {
      state = state.copyWith(planningMessage: proposal.reason);
      return false;
    }
    try {
      final before = state.substrates[slot];
      final solved = baseline.substrates.firstWhere((s) => s.slot == slot);
      final stock = isMolarUnit(before.storageUnit)
          ? proposal.stockMolarMm
          : proposal.stockMassMgMl;
      if (stock == null || stock <= 0 || !stock.isFinite) {
        throw ArgumentError('工作液浓度不能换算到当前母液单位。');
      }
      final concentration =
          (stock / convertConcentrationToBaseUnit(1, before.storageUnit))
              .toString();
      var finalUnit = before.finalUnit;
      var finalValue = isMolarUnit(finalUnit)
          ? solved.finalMolarMm
          : solved.finalMassMgMl;
      if (finalValue == null) {
        finalUnit = baseline.ratioType ? 'mM' : 'mg/mL';
        finalValue = baseline.ratioType
            ? solved.finalMolarMm
            : solved.finalMassMgMl;
      }
      if (finalValue == null) throw ArgumentError('缺少可保留的反应终浓度。');
      final inputs = state.substrates.toList();
      inputs[slot] = before.copyWith(
        storageConc: concentration,
        storageVolume: '',
        finalConc: before.finalConc.trim().isEmpty
            ? (finalValue / convertConcentrationToBaseUnit(1, finalUnit))
                  .toString()
            : before.finalConc,
        finalUnit: finalUnit,
      );
      final provenance = WorkingStockProvenance(
        slot: slot,
        parentInput: before.toSnapshot(),
        workingConcentration: concentration,
        workingUnit: before.storageUnit,
        dilutionFactor: proposal.factor,
        parentVolumeMl: proposal.parentStockMl,
        diluentVolumeMl: proposal.diluentMl,
        preparationVolumeMl: proposal.preparationVolumeMl,
        requiredVolumeMl: proposal.requiredVolumeMl,
        newAliquotMl: solved.aliquotMl * proposal.factor,
        minimumVolumeMl: proposal.minimumVolumeMl,
        diluentName: proposal.diluentName,
      );
      final candidate = state.copyWith(
        substrates: inputs,
        reactionVolume: state.reactionVolume.trim().isEmpty
            ? (baseline.totalVolumeMl /
                      convertVolumeToMl(1, state.reactionVolumeUnit))
                  .toString()
            : state.reactionVolume,
        workingStocks: [...state.workingStocks, provenance],
      );
      final result = solveCalculation(
        _captureInputs(source: candidate, includeGradient: false),
        minimumVolumeMl: _minimumVolumeMl,
      );
      if (!_samePhysicalDose(baseline, result)) {
        throw StateError('采用后不能保持原定反应总体积和各底物用量。');
      }
      _proposalSources.clear();
      state = _withResult(
        candidate.copyWith(
          clearGradientPlan: true,
          gradientWorkingStocks: const [],
          planningMessage: '已采用工作液；原母液和配制方法已保留。',
          historySaveError: '',
        ),
        result,
      );
      unawaited(_saveHistory(result, result.input, ++_calculationGeneration));
      return true;
    } catch (error) {
      state = state.copyWith(planningMessage: '未采用工作液：$error');
      return false;
    }
  }

  bool _samePhysicalDose(CalculationResult before, CalculationResult after) {
    bool close(double a, double b) =>
        a == b ||
        (a - b).abs() <= 1e-9 * (a.abs() > b.abs() ? a.abs() : b.abs());
    if (!close(before.totalVolumeMl, after.totalVolumeMl)) return false;
    for (final prior in before.substrates) {
      final next = after.substrates.firstWhere((s) => s.slot == prior.slot);
      final a = before.ratioType ? prior.finalMolarMm : prior.finalMassMgMl;
      final b = before.ratioType ? next.finalMolarMm : next.finalMassMgMl;
      if (a == null || b == null || !close(a, b)) return false;
    }
    return true;
  }

  void configureGradient(GradientSpec? spec) {
    if (_sameGradientSpec(state.gradientSpec, spec)) return;
    state = state.copyWith(
      gradientSpec: spec,
      clearGradientSpec: spec == null,
      gradientWorkingStocks: const [],
      clearGradientPlan: true,
      planningMessage: '',
    );
  }

  bool _sameGradientSpec(GradientSpec? a, GradientSpec? b) {
    if (identical(a, b)) return true;
    if (a == null ||
        b == null ||
        a.selectedSlot != b.selectedSlot ||
        a.proteinSlot != b.proteinSlot ||
        a.unit != b.unit ||
        a.replicates != b.replicates ||
        a.extraPreparationFraction != b.extraPreparationFraction ||
        a.points.length != b.points.length) {
      return false;
    }
    for (var i = 0; i < a.points.length; i++) {
      if (a.points[i] != b.points[i]) return false;
    }
    return true;
  }

  GradientPlan _generateCurrentGradient(
    CalculationResult baseline,
    GradientSpec spec,
  ) {
    var plan = generateGradient(
      baseline,
      spec,
      minimumVolumeMl: _minimumVolumeMl,
    );
    for (final stock in state.gradientWorkingStocks) {
      plan = applyGradientWorkingStockFactor(
        plan,
        slot: stock.slot,
        factor: stock.dilutionFactor,
        diluentName: stock.diluentName,
        minimumVolumeMl: stock.minimumVolumeMl,
        warningMinimumVolumeMl: _minimumVolumeMl,
      );
    }
    return plan;
  }

  void calculateGradient() {
    final baseline = state.rawResult;
    final spec = state.gradientSpec;
    if (baseline == null || spec == null) {
      state = state.copyWith(
        planningMessage: '请先计算有效基线并填写梯度条件。',
        clearGradientPlan: true,
      );
      return;
    }
    try {
      final plan = _generateCurrentGradient(baseline, spec);
      state = state.copyWith(
        gradientPlan: plan,
        planningMessage: '',
        historySaveError: '',
      );
      // Exactly one history write for the batch; no per-group calculation writes.
      unawaited(
        _saveHistory(baseline, _captureInputs(), ++_calculationGeneration),
      );
    } catch (error) {
      state = state.copyWith(
        clearGradientPlan: true,
        planningMessage: '梯度计算失败：$error',
      );
    }
  }

  Future<void> _saveHistory(
    CalculationResult result,
    CalculationInputSnapshot inputSnapshot,
    int generation,
  ) async {
    final lifecycle = _lifecycle;
    try {
      final db = ref.read(appDatabaseProvider);
      final substrateResults = [
        for (final chem in result.substrates)
          SubstrateResult(
            sortOrder: chem.slot,
            name: chem.name,
            role: chem.slot == 0 ? 'main' : 'secondary',
            molecularWeight: chem.molecularWeightDa,
            storageConcMolar: chem.stockMolarMm,
            storageConcMass: chem.stockMassMgMl,
            storageVolume: chem.aliquotMl,
            finalConcMolar: chem.finalMolarMm,
            finalConcMass: chem.finalMassMgMl,
            reactionRatio: chem.ratio,
          ),
      ];
      await db.saveCalculation(
        createdAt: DateTime.now(),
        ratioType: result.ratioType,
        reactionVolume: result.totalVolumeMl,
        reactionVolumeUnit: 'mL',
        totalStockVolume: result.stockVolumeMl,
        diluentVolume: result.diluentVolumeMl,
        substrates: substrateResults,
        inputSnapshot: inputSnapshot,
      );
      if (!_disposed) {
        // A reset may rebuild this notifier while a save is pending. The
        // saved record still belongs in history, even though input status is new.
        ref.invalidate(historyProvider);
      }
    } catch (error) {
      if (!_disposed &&
          lifecycle == _lifecycle &&
          generation == _calculationGeneration) {
        state = state.copyWith(
          historySaveError: state.rows.isEmpty
              ? '上次计算未保存到历史记录：$error。请重新计算后重试保存。'
              : '历史记录保存失败：$error。计算结果仍可使用，请重试计算以保存。',
        );
      }
    }
  }

  // ── copy result ──────────────────────────────────────────────────────

  String buildCopyText() {
    final buf = StringBuffer();
    if (state.summaryRows.isNotEmpty) {
      buf.writeln('反应汇总');
      buf.writeln('=' * 28);
      for (final (key, value) in state.summaryRows) {
        buf.writeln('$key: $value');
      }
      buf.writeln();
    }

    if (state.rows.isNotEmpty) {
      const headers = [
        '类别',
        '名称',
        '母液浓度（摩尔）',
        '母液浓度（质量）',
        '终浓度（摩尔）',
        '终浓度（质量）',
        '取样体积',
        '母液体积占比',
        '投料比',
      ];
      buf.writeln('底物结果');
      buf.writeln('=' * 28);

      final widths = List.filled(headers.length, 0);
      for (var i = 0; i < headers.length; i++) {
        widths[i] = headers[i].length;
        for (final row in state.rows) {
          final vals = [
            row.role,
            row.name,
            row.stock,
            row.stockMass,
            row.finalConc,
            row.finalConcMass,
            row.volume,
            row.volumePct,
            row.ratio,
          ];
          if (vals[i].length > widths[i]) widths[i] = vals[i].length;
        }
      }

      buf.writeln(
        headers
            .asMap()
            .entries
            .map((e) => e.value.padRight(widths[e.key]))
            .join(' | '),
      );
      buf.writeln(
        List.filled(
          headers
              .map((h) => h.padRight(widths[headers.indexOf(h)]))
              .join(' | ')
              .length,
          '-',
        ),
      );

      for (final row in state.rows) {
        final vals = [
          row.role,
          row.name,
          row.stock,
          row.stockMass,
          row.finalConc,
          row.finalConcMass,
          row.volume,
          row.volumePct,
          row.ratio,
        ];
        buf.writeln(
          vals
              .asMap()
              .entries
              .map((e) => e.value.padRight(widths[e.key]))
              .join(' | '),
        );
      }
    }
    return buf.toString().trim();
  }

  // ── restore ──────────────────────────────────────────────────────────

  void restoreFromHistory(CalculationHistory record) {
    final snapshot = record.inputSnapshot;
    if (snapshot != null) {
      unawaited(
        ref
            .read(appSettingsProvider.notifier)
            .setMinimumPipettingVolumeUl(snapshot.minimumPipettingVolumeUl),
      );
      final gradient = snapshot.gradient;
      _replaceInputs(
        state.copyWith(
          reactionVolume: snapshot.reactionVolume,
          reactionVolumeUnit: snapshot.reactionVolumeUnit,
          ratioType: snapshot.ratioType,
          referenceSlot: snapshot.referenceSlot,
          workingStocks: snapshot.workingStocks,
          gradientWorkingStocks: snapshot.gradient?.workingStocks ?? [],
          gradientSpec: gradient == null
              ? null
              : GradientSpec(
                  selectedSlot: gradient.selectedSlot,
                  proteinSlot: gradient.proteinSlot,
                  unit: gradient.unit,
                  points: gradient.points,
                  replicates: gradient.replicates,
                  extraPreparationFraction: gradient.extraPreparationFraction,
                ),
          clearGradientSpec: gradient == null,
          substrates: [
            ...snapshot.substrates.map(SubstrateInput.fromSnapshot),
            ..._defaultSubstrates(
              enableFirstSecondary: false,
            ).skip(snapshot.substrates.length),
          ],
        ),
        message: '已恢复原始输入，请重新运行计算。',
        preserveGradientStocks: true,
      );
      return;
    }

    // Legacy records contain computed base-unit values, not original input.
    // Use round-trippable strings and fresh disabled slots, never rounded text
    // or values left over from the calculation currently on screen.
    final substrates = _defaultSubstrates(enableFirstSecondary: false);
    final historySubs = record.substrates.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final hs in historySubs) {
      final i = hs.sortOrder;
      if (i < 0 || i >= substrates.length) continue;
      final useMolar = record.ratioType
          ? hs.storageConcMolar != null
          : hs.storageConcMass == null;
      final useFinalMolar = record.ratioType
          ? hs.finalConcMolar != null
          : hs.finalConcMass == null;
      substrates[i] = SubstrateInput(
        enabled: true,
        name: hs.name,
        mw: hs.molecularWeight?.toString() ?? '',
        mwUnit: 'Da',
        storageConc:
            (useMolar ? hs.storageConcMolar : hs.storageConcMass)?.toString() ??
            '',
        storageUnit: useMolar ? 'mM' : 'mg/mL',
        finalConc:
            (useFinalMolar ? hs.finalConcMolar : hs.finalConcMass)
                ?.toString() ??
            '',
        finalUnit: useFinalMolar ? 'mM' : 'mg/mL',
        reactionRatio: hs.reactionRatio?.toString() ?? '',
        storageVolume: hs.storageVolume?.toString() ?? '',
        storageVolumeUnit: 'mL',
      );
    }

    _replaceInputs(
      state.copyWith(
        reactionVolume: record.reactionVolume?.toString() ?? '',
        reactionVolumeUnit: record.reactionVolumeUnit,
        ratioType: record.ratioType,
        referenceSlot: 0,
        workingStocks: [],
        clearGradientSpec: true,
        substrates: substrates,
      ),
      message: '已恢复历史结果中的数值，请核对参数并重新计算。',
    );
  }

  // ── reset ────────────────────────────────────────────────────────────

  void reset() {
    ref.invalidateSelf();
  }

  // ── helpers ──────────────────────────────────────────────────────────

  String _formatConcentration(
    double? value,
    String unitType,
    double? molecularWeight,
  ) {
    if (value == null && molecularWeight == null) {
      return '无法换算（缺少分子量）';
    }
    return _formatWithUnit(value, unitType);
  }

  String _formatWithUnit(double? value, String unitType) {
    if (value == null) return 'N/A';
    final absV = value.abs();
    switch (unitType) {
      case 'volume':
        if (absV >= 1000) return '${_formatNumber(value / 1000, 2)} L';
        if (absV >= 1) return '${_formatNumber(value, 2)} mL';
        if (absV >= 0.001) return '${_formatNumber(value * 1000, 2)} uL';
        if (absV >= 0.000001) return '${_formatNumber(value * 1000000, 2)} nL';
        return '${_formatNumber(value * 1000000000, 2)} pL';
      case 'mass_conc':
        if (absV >= 1000) return '${_formatNumber(value / 1000, 2)} g/mL';
        if (absV >= 1) return '${_formatNumber(value, 2)} mg/mL';
        if (absV >= 0.001) return '${_formatNumber(value * 1000, 2)} ug/mL';
        if (absV >= 0.000001) {
          return '${_formatNumber(value * 1000000, 2)} ng/mL';
        }
        return '${_formatNumber(value * 1000000000, 2)} pg/mL';
      case 'molar_conc':
        if (absV >= 1000) return '${_formatNumber(value / 1000, 2)} M';
        if (absV >= 1) return '${_formatNumber(value, 2)} mM';
        if (absV >= 0.001) return '${_formatNumber(value * 1000, 2)} uM';
        if (absV >= 0.000001) return '${_formatNumber(value * 1000000, 2)} nM';
        return '${_formatNumber(value * 1000000000, 2)} pM';
      case 'mw':
        return absV >= 1000
            ? '${_formatNumber(value / 1000, 2)} kDa'
            : '${_formatNumber(value, 2)} Da';
      default:
        return _formatNumber(value, 4);
    }
  }

  String _formatNumber(double value, int decimalPlaces) {
    final fixed = value.toStringAsFixed(decimalPlaces);
    return value != 0 && double.tryParse(fixed) == 0
        ? value.toStringAsExponential(decimalPlaces)
        : fixed;
  }

  String _formatPercent(double? numerator, double? denominator) {
    if (numerator == null || denominator == null || denominator <= 0) {
      return 'N/A';
    }
    return '${_formatNumber(numerator / denominator * 100, 2)}%';
  }
}
