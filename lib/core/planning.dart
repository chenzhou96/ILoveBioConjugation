import 'dart:math' as math;

import '../data/calculation_input_snapshot.dart';
import 'chemical.dart';
import 'reaction.dart';
import 'validators.dart';

/// All numerical planning values use mL, mM, mg/mL and Da. Display strings are
/// deliberately excluded from calculations. Every public collection is frozen.
class SolvedSubstrate {
  final int slot;
  final String name;
  final double? molecularWeightDa;
  final double? stockMolarMm;
  final double? stockMassMgMl;
  final double? finalMolarMm;
  final double? finalMassMgMl;
  final double aliquotMl;
  final double? ratio;

  const SolvedSubstrate({
    required this.slot,
    required this.name,
    required this.molecularWeightDa,
    required this.stockMolarMm,
    required this.stockMassMgMl,
    required this.finalMolarMm,
    required this.finalMassMgMl,
    required this.aliquotMl,
    required this.ratio,
  });

  double? basisFinal(bool molar) => molar ? finalMolarMm : finalMassMgMl;
  double? basisStock(bool molar) => molar ? stockMolarMm : stockMassMgMl;
}

class PlanningWarning {
  final int? slot;
  final String code;
  final String message;
  const PlanningWarning({this.slot, required this.code, required this.message});
}

class CalculationResult {
  final CalculationInputSnapshot input;
  final bool ratioType;
  final int referenceSlot;
  final List<SolvedSubstrate> substrates;
  final double totalVolumeMl;
  final double stockVolumeMl;
  final double diluentVolumeMl;
  final List<PlanningWarning> warnings;

  CalculationResult({
    required this.input,
    required this.ratioType,
    required this.referenceSlot,
    required List<SolvedSubstrate> substrates,
    required this.totalVolumeMl,
    required this.stockVolumeMl,
    required this.diluentVolumeMl,
    required List<PlanningWarning> warnings,
  }) : substrates = List.unmodifiable(substrates),
       warnings = List.unmodifiable(warnings);

  SolvedSubstrate substrateAt(int slot) => substrates.firstWhere(
    (s) => s.slot == slot,
    orElse: () => throw ArgumentError('所选试剂未启用。'),
  );
}

class GradientSpec {
  final int selectedSlot;
  final int proteinSlot;

  /// A concentration unit, or `eq` in the baseline's selected ratio basis.
  final String unit;
  final List<String> points;
  final int replicates;

  /// Extra preparation affects bulk totals only, never the single reaction.
  final double extraPreparationFraction;
  GradientSpec({
    required this.selectedSlot,
    this.proteinSlot = 0,
    required this.unit,
    required List<String> points,
    this.replicates = 1,
    this.extraPreparationFraction = 0,
  }) : points = List.unmodifiable(points);
}

class GradientGroup {
  final int index;
  final String pointText;
  final double? pointValue;
  final CalculationResult? result;
  final String? error;
  const GradientGroup({
    required this.index,
    required this.pointText,
    required this.pointValue,
    this.result,
    this.error,
  });
  bool get isValid => result != null;
}

class GradientTotals {
  final int validGroupCount;
  final int failedGroupCount;
  final int reactionCount;
  final double preparationReactionEquivalent;
  final Map<int, double> aliquotsMl;
  final double diluentMl;
  final double totalVolumeMl;
  GradientTotals({
    required this.validGroupCount,
    required this.failedGroupCount,
    required this.reactionCount,
    required this.preparationReactionEquivalent,
    required Map<int, double> aliquotsMl,
    required this.diluentMl,
    required this.totalVolumeMl,
  }) : aliquotsMl = Map.unmodifiable(aliquotsMl);
  bool get validGroupsOnly => failedGroupCount > 0;
}

class GradientPlan {
  final CalculationResult baseline;
  final GradientSpec spec;
  final List<GradientGroup> groups;
  final GradientTotals totals;
  final List<PlanningWarning> warnings;

  /// Explicitly adopted shared working stocks, in preparation/adoption order.
  final List<WorkingStockProposal> workingStocks;
  GradientPlan({
    required this.baseline,
    required this.spec,
    required List<GradientGroup> groups,
    required this.totals,
    List<WorkingStockProposal> workingStocks = const [],
    List<PlanningWarning> warnings = const [],
  }) : groups = List.unmodifiable(groups),
       workingStocks = List.unmodifiable(workingStocks),
       warnings = List.unmodifiable(warnings);
  bool get isPartial =>
      totals.failedGroupCount > 0 && totals.validGroupCount > 0;
  bool get isValid => totals.failedGroupCount == 0;
}

class WorkingStockProposal {
  /// Identity lets adapters reject stale proposals before adoption.
  final CalculationResult sourceResult;
  final int slot;
  final bool feasible;
  final String reason;
  final double factor;
  final double? parentStockMolarMm;
  final double? parentStockMassMgMl;
  final double? stockMolarMm;
  final double? stockMassMgMl;
  final double newAliquotMl;
  final double parentStockMl;
  final double diluentMl;
  final double preparationVolumeMl;
  final double requiredVolumeMl;
  final double minimumVolumeMl;
  final String diluentName;
  const WorkingStockProposal({
    required this.sourceResult,
    required this.slot,
    required this.feasible,
    required this.reason,
    required this.factor,
    required this.parentStockMolarMm,
    required this.parentStockMassMgMl,
    required this.stockMolarMm,
    required this.stockMassMgMl,
    required this.newAliquotMl,
    required this.parentStockMl,
    required this.diluentMl,
    required this.preparationVolumeMl,
    required this.requiredVolumeMl,
    required this.minimumVolumeMl,
    required this.diluentName,
  });
  bool get needsDilution => factor > 1;
}

class WorkingStockTier {
  final List<int> groupIndices;
  final WorkingStockProposal proposal;
  WorkingStockTier({required List<int> groupIndices, required this.proposal})
    : groupIndices = List.unmodifiable(groupIndices);
}

class GradientWorkingStockProposal {
  final GradientPlan sourcePlan;
  final bool feasible;
  final String reason;
  final WorkingStockProposal? shared;
  final List<WorkingStockTier> tiers;
  GradientWorkingStockProposal({
    required this.sourcePlan,
    required this.feasible,
    required this.reason,
    this.shared,
    List<WorkingStockTier> tiers = const [],
  }) : tiers = List.unmodifiable(tiers);
}

CalculationResult solveCalculation(
  CalculationInputSnapshot input, {
  double? minimumVolumeMl,
  int? referenceSlot,
}) {
  minimumVolumeMl ??= input.minimumPipettingVolumeUl / 1000;
  _validateMinimum(minimumVolumeMl);
  if (input.substrates.isEmpty || input.substrates.length > 4) {
    throw ArgumentError('需要 1 至 4 种试剂。');
  }
  final active = <int>[
    0,
    for (var i = 1; i < input.substrates.length; i++)
      if (input.substrates[i].enabled) i,
  ];
  final reference = referenceSlot ?? input.referenceSlot;
  if (!active.contains(reference)) throw ArgumentError('投料比参照试剂未启用。');
  final chemicals = <int, Chemical>{
    for (final slot in active) slot: _fromInput(input.substrates[slot], slot),
  };
  final volumeRaw = parseFloatOrNull(input.reactionVolume);
  final volume = volumeRaw == null
      ? null
      : convertVolumeToMl(volumeRaw, input.reactionVolumeUnit);
  final reaction = Reaction(
    ratioType: input.ratioType,
    substrateMain: chemicals[reference]!,
    substratesSecondary: [
      for (final slot in active)
        if (slot != reference) chemicals[slot]!,
    ],
    reactionVolume: volume,
  );
  return _result(
    input,
    input.ratioType,
    reference,
    chemicals,
    reaction.reactionVolume!,
    minimumVolumeMl,
  );
}

GradientPlan generateGradient(
  CalculationResult baseline,
  GradientSpec spec, {
  double? minimumVolumeMl,
}) {
  minimumVolumeMl ??= baseline.input.minimumPipettingVolumeUl / 1000;
  _validateMinimum(minimumVolumeMl);
  _validatePreparation(spec.replicates, spec.extraPreparationFraction);
  if (spec.points.isEmpty) throw ArgumentError('请至少输入一个梯度点。');
  if (spec.points.length > 1000) throw ArgumentError('每次最多生成 1000 个梯度条件。');
  if (spec.proteinSlot != 0) {
    throw ArgumentError('固定蛋白用量的梯度以主底物作为蛋白试剂。');
  }
  baseline.substrateAt(spec.proteinSlot);
  final selected = baseline.substrateAt(spec.selectedSlot);
  if (spec.selectedSlot == spec.proteinSlot) {
    throw ArgumentError('固定蛋白用量的梯度不能改变蛋白试剂。');
  }
  final isEq = spec.unit == 'eq';
  if (!isEq && !isMolarUnit(spec.unit) && !isMassUnit(spec.unit)) {
    throw ArgumentError('不支持的梯度单位: ${spec.unit}');
  }
  if (isEq && spec.selectedSlot == baseline.referenceSlot) {
    throw ArgumentError('eq 梯度试剂不能同时作为投料比参照。');
  }
  final referenceFinal = baseline
      .substrateAt(baseline.referenceSlot)
      .basisFinal(baseline.ratioType);
  if (isEq && (referenceFinal == null || referenceFinal <= 0)) {
    throw ArgumentError('eq 梯度需要正用量的投料比参照试剂。');
  }
  if (!isEq &&
      isMolarUnit(spec.unit) != baseline.ratioType &&
      selected.molecularWeightDa == null) {
    throw ArgumentError('跨摩尔/质量基准的梯度需要该试剂的分子量。');
  }
  final groups = <GradientGroup>[];
  for (var index = 0; index < spec.points.length; index++) {
    final text = spec.points[index];
    double? value;
    try {
      value = parseFloatOrNull(text);
      if (value == null || value < 0) throw ArgumentError('梯度点必须是非负有限数字。');
      double target;
      if (isEq) {
        target = _checkedProduct(value, referenceFinal!, 'eq 换算');
      } else {
        target = convertConcentrationToBaseUnit(value, spec.unit);
        if (isMolarUnit(spec.unit) != baseline.ratioType) {
          target = baseline.ratioType
              ? _checkedProduct(
                  target,
                  1000 / selected.molecularWeightDa!,
                  '浓度换算',
                )
              : _checkedProduct(
                  target,
                  selected.molecularWeightDa! / 1000,
                  '浓度换算',
                );
        }
      }
      final targets = <int, double>{
        for (final s in baseline.substrates)
          s.slot: s.slot == spec.selectedSlot
              ? target
              : s.basisFinal(baseline.ratioType)!,
      };
      final solved = _solveFixedTargets(baseline, targets, minimumVolumeMl);
      groups.add(
        GradientGroup(
          index: index,
          pointText: text,
          pointValue: value,
          result: solved,
        ),
      );
    } catch (error) {
      groups.add(
        GradientGroup(
          index: index,
          pointText: text,
          pointValue: value,
          error: _errorText(error),
        ),
      );
    }
  }
  final totals = _totals(baseline, spec, groups);
  return GradientPlan(
    baseline: baseline,
    spec: spec,
    groups: groups,
    totals: totals,
    warnings: _preparedStockWarnings(
      baseline.input,
      totals.aliquotsMl,
      batch: true,
    ),
  );
}

/// Arithmetic points include `start`, followed by `count - 1` additions.
List<String> arithmeticGradientPoints({
  required double start,
  required double step,
  required int count,
}) {
  _validatePointGenerator(start, count);
  if (!step.isFinite) throw ArgumentError('步长必须是有限数字。');
  return List.unmodifiable(
    List.generate(count, (i) {
      final value = start + step * i;
      if (!value.isFinite || value < 0) throw ArgumentError('生成的梯度点必须是非负有限数字。');
      return value.toString();
    }),
  );
}

/// Geometric points require positive start/factor; use manual points for zero.
List<String> geometricGradientPoints({
  required double start,
  required double factor,
  required int count,
}) {
  _validatePointGenerator(start, count);
  if (start <= 0 || !factor.isFinite || factor <= 0) {
    throw ArgumentError('等比梯度的起点和倍数必须大于 0。');
  }
  return List.unmodifiable(
    List.generate(count, (i) {
      final value = start * math.pow(factor, i);
      if (!value.isFinite || value <= 0) throw ArgumentError('生成的梯度点超出可计算范围。');
      return value.toString();
    }),
  );
}

WorkingStockProposal proposeWorkingStock(
  CalculationResult result, {
  required int slot,
  required double minimumVolumeMl,
  int replicates = 1,
  double extraPreparationFraction = 0,
  String diluentName = '',
  double? dilutionFactor,
}) {
  _validateMinimum(minimumVolumeMl);
  if (minimumVolumeMl == 0) throw ArgumentError('请先设置大于 0 的最小移液量。');
  _validatePreparation(replicates, extraPreparationFraction);
  final reagent = result.substrateAt(slot);
  final factor =
      dilutionFactor ??
      (reagent.aliquotMl > 0
          ? math.max(1.0, minimumVolumeMl / reagent.aliquotMl)
          : 1.0);
  return _workingProposal(
    result,
    slot,
    factor,
    minimumVolumeMl,
    reagent.aliquotMl * replicates * (1 + extraPreparationFraction),
    diluentName,
    [result],
  );
}

GradientWorkingStockProposal proposeGradientWorkingStock(
  GradientPlan plan, {
  required int slot,
  required double minimumVolumeMl,
  String diluentName = '',
  double? dilutionFactor,
}) {
  _validateMinimum(minimumVolumeMl);
  if (minimumVolumeMl == 0) throw ArgumentError('请先设置大于 0 的最小移液量。');
  plan.baseline.substrateAt(slot);
  final positive = plan.groups
      .where((g) => g.isValid && g.result!.substrateAt(slot).aliquotMl > 0)
      .toList();
  if (positive.isEmpty) {
    return GradientWorkingStockProposal(
      sourcePlan: plan,
      feasible: false,
      reason: '有效组中该试剂用量均为 0，无需制备工作液。',
    );
  }
  WorkingStockProposal proposal(List<GradientGroup> groups) {
    final results = groups.map((g) => g.result!).toList();
    final minimumAliquot = results
        .map((r) => r.substrateAt(slot).aliquotMl)
        .reduce(math.min);
    final factor =
        dilutionFactor ?? math.max(1.0, minimumVolumeMl / minimumAliquot);
    final requiredParent =
        results.fold(0.0, (sum, r) => sum + r.substrateAt(slot).aliquotMl) *
        plan.spec.replicates *
        (1 + plan.spec.extraPreparationFraction);
    return _workingProposal(
      results.first,
      slot,
      factor,
      minimumVolumeMl,
      requiredParent,
      diluentName,
      results,
    );
  }

  final shared = proposal(positive);
  if (shared.feasible) {
    return GradientWorkingStockProposal(
      sourcePlan: plan,
      feasible: true,
      reason: shared.needsDilution
          ? '所有正用量有效组可共用该工作液。'
          : '所有正用量有效组已达到最小移液量，无需稀释。',
      shared: shared,
    );
  }
  if (dilutionFactor != null) {
    return GradientWorkingStockProposal(
      sourcePlan: plan,
      feasible: false,
      reason: shared.reason,
    );
  }
  // Try a bounded two-tier split, with the largest possible low-volume tier.
  // Every returned tier is checked against every group's free reaction volume.
  positive.sort(
    (a, b) => a.result!
        .substrateAt(slot)
        .aliquotMl
        .compareTo(b.result!.substrateAt(slot).aliquotMl),
  );
  for (var split = positive.length - 1; split >= 1; split--) {
    final low = positive.sublist(0, split);
    final high = positive.sublist(split);
    final first = proposal(low);
    final second = proposal(high);
    if (first.feasible && second.feasible) {
      return GradientWorkingStockProposal(
        sourcePlan: plan,
        feasible: true,
        reason: '单一工作液不能覆盖该梯度；以下两档均可保持各组用量和总体积。',
        tiers: [
          WorkingStockTier(
            groupIndices: low.map((g) => g.index).toList(),
            proposal: first,
          ),
          WorkingStockTier(
            groupIndices: high.map((g) => g.index).toList(),
            proposal: second,
          ),
        ],
      );
    }
  }
  return GradientWorkingStockProposal(
    sourcePlan: plan,
    feasible: false,
    reason: '共同工作液和两档工作液均不可行：${shared.reason}',
  );
}

/// Adopt a verified common working stock for this batch only. The original
/// baseline can be outside the swept points; it remains unchanged.
GradientPlan applyGradientWorkingStock(
  GradientPlan plan,
  GradientWorkingStockProposal advice, {
  double? warningMinimumVolumeMl,
}) {
  if (!identical(plan, advice.sourcePlan)) {
    throw ArgumentError('梯度已更改，请重新生成工作液建议。');
  }
  final proposal = advice.shared;
  if (!advice.feasible || proposal == null || !proposal.feasible) {
    throw ArgumentError('仅可采用体积可行的共同工作液；两档建议需分别核对。');
  }
  if (proposal.diluentName.trim().isEmpty) {
    throw ArgumentError('请明确填写经实验确认兼容的稀释液。');
  }
  if (!proposal.needsDilution) throw ArgumentError('该方案无需稀释。');
  final warningMinimum = warningMinimumVolumeMl ?? proposal.minimumVolumeMl;
  _validateMinimum(warningMinimum);
  if (plan.workingStocks.any((stock) => stock.slot == proposal.slot) ||
      plan.baseline.input.workingStocks.any(
        (stock) => stock.slot == proposal.slot,
      )) {
    throw ArgumentError('该试剂已采用工作液；请重新生成梯度后再更换工作液。');
  }
  // Revalidate even if a caller manually assembled a proposal object.
  final checked = proposeGradientWorkingStock(
    plan,
    slot: proposal.slot,
    minimumVolumeMl: proposal.minimumVolumeMl,
    diluentName: proposal.diluentName,
    dilutionFactor: proposal.factor,
  ).shared;
  if (checked == null || !checked.feasible) {
    throw ArgumentError('共同工作液已不可行，请重新核对。');
  }
  final groups = <GradientGroup>[];
  for (final group in plan.groups) {
    if (!group.isValid) {
      groups.add(group);
      continue;
    }
    final prior = group.result!;
    final targets = <int, double>{
      for (final s in prior.substrates) s.slot: s.basisFinal(prior.ratioType)!,
    };
    final result = _solveFixedTargets(
      prior,
      targets,
      warningMinimum,
      dilutionFactors: {proposal.slot: proposal.factor},
    );
    groups.add(
      GradientGroup(
        index: group.index,
        pointText: group.pointText,
        pointValue: group.pointValue,
        result: result,
      ),
    );
  }
  final totals = _totals(plan.baseline, plan.spec, groups);
  return GradientPlan(
    baseline: plan.baseline,
    spec: plan.spec,
    groups: groups,
    totals: totals,
    workingStocks: [...plan.workingStocks, checked],
    warnings: _preparedStockWarnings(
      plan.baseline.input,
      totals.aliquotsMl,
      batch: true,
    ),
  );
}

/// Replay an explicitly adopted factor from persisted batch metadata. This
/// never chooses a new factor or silently changes the user's selected diluent.
GradientPlan applyGradientWorkingStockFactor(
  GradientPlan plan, {
  required int slot,
  required double factor,
  required String diluentName,
  double? minimumVolumeMl,
  double? warningMinimumVolumeMl,
}) {
  final minimum =
      minimumVolumeMl ?? plan.baseline.input.minimumPipettingVolumeUl / 1000;
  final advice = proposeGradientWorkingStock(
    plan,
    slot: slot,
    minimumVolumeMl: minimum,
    diluentName: diluentName,
    dilutionFactor: factor,
  );
  return applyGradientWorkingStock(
    plan,
    advice,
    warningMinimumVolumeMl: warningMinimumVolumeMl,
  );
}

Chemical _fromInput(SubstrateInputSnapshot input, int slot) {
  final mw = parseFloatOrNull(input.mw);
  final stock = parseFloatOrNull(input.storageConc);
  final finalConc = parseFloatOrNull(input.finalConc);
  final aliquot = parseFloatOrNull(input.storageVolume);
  final stockBase = stock == null
      ? null
      : convertConcentrationToBaseUnit(stock, input.storageUnit);
  final finalBase = finalConc == null
      ? null
      : convertConcentrationToBaseUnit(finalConc, input.finalUnit);
  return Chemical(
    unitCoefficient: 1,
    name: input.name.trim().isEmpty
        ? (slot == 0 ? '主底物' : '副底物$slot')
        : input.name.trim(),
    molecularWeight: mw == null ? null : convertMwToDa(mw, input.mwUnit),
    storageConcMolar: isMolarUnit(input.storageUnit) ? stockBase : null,
    storageConcMass: isMolarUnit(input.storageUnit) ? null : stockBase,
    finalConcMolar: isMolarUnit(input.finalUnit) ? finalBase : null,
    finalConcMass: isMolarUnit(input.finalUnit) ? null : finalBase,
    storageConcVolume: aliquot == null
        ? null
        : convertVolumeToMl(aliquot, input.storageVolumeUnit),
    reactionRatio: parseFloatOrNull(input.reactionRatio),
  );
}

CalculationResult _solveFixedTargets(
  CalculationResult baseline,
  Map<int, double> targets,
  double minimumVolumeMl, {
  Map<int, double> dilutionFactors = const {},
}) {
  final chemicals = <int, Chemical>{};
  for (final s in baseline.substrates) {
    final target = targets[s.slot]!;
    final factor = dilutionFactors[s.slot] ?? 1.0;
    if (!target.isFinite || target < 0) throw ArgumentError('非法目标浓度。');
    // Fresh objects contain only stock, MW and new target. Old ratios and old
    // aliquots are intentionally never copied into this single-factor solve.
    chemicals[s.slot] = Chemical(
      unitCoefficient: 1,
      name: s.name,
      molecularWeight: s.molecularWeightDa,
      storageConcMolar: baseline.ratioType ? s.stockMolarMm! / factor : null,
      storageConcMass: baseline.ratioType ? null : s.stockMassMgMl! / factor,
      finalConcMolar: baseline.ratioType ? target : null,
      finalConcMass: baseline.ratioType ? null : target,
      storageConcVolume: target == 0 ? 0 : null,
    );
  }
  final positive = chemicals.entries.where((e) => targets[e.key]! > 0).toList();
  if (positive.isNotEmpty) {
    final anchor = positive.firstWhere(
      (e) => e.key == baseline.referenceSlot,
      orElse: () => positive.first,
    );
    Reaction(
      ratioType: baseline.ratioType,
      substrateMain: anchor.value,
      substratesSecondary: [
        for (final e in positive)
          if (e.key != anchor.key) e.value,
      ],
      reactionVolume: baseline.totalVolumeMl,
    );
  }
  return _result(
    baseline.input,
    baseline.ratioType,
    baseline.referenceSlot,
    chemicals,
    baseline.totalVolumeMl,
    minimumVolumeMl,
  );
}

CalculationResult _result(
  CalculationInputSnapshot input,
  bool ratioType,
  int referenceSlot,
  Map<int, Chemical> chemicals,
  double volume,
  double minimumVolumeMl,
) {
  final reference = chemicals[referenceSlot]!.getBasisFinalConc(ratioType)!;
  final rows = <SolvedSubstrate>[];
  final warnings = <PlanningWarning>[];
  double total = 0;
  for (final entry in chemicals.entries) {
    final c = entry.value;
    final aliquot = c.storageConcVolume!;
    total += aliquot;
    final quantity = c.getBasisFinalConc(ratioType)!;
    final ratio = reference > 0 ? quantity / reference : null;
    if (ratio != null && (!ratio.isFinite || (quantity > 0 && ratio == 0))) {
      throw ArgumentError('投料比超出可计算范围。');
    }
    rows.add(
      SolvedSubstrate(
        slot: entry.key,
        name: c.name,
        molecularWeightDa: c.molecularWeight,
        stockMolarMm: c.storageConcMolar,
        stockMassMgMl: c.storageConcMass,
        finalMolarMm: c.finalConcMolar,
        finalMassMgMl: c.finalConcMass,
        aliquotMl: aliquot,
        ratio: ratio,
      ),
    );
    if (_belowMinimum(aliquot, minimumVolumeMl)) {
      warnings.add(
        PlanningWarning(
          slot: entry.key,
          code: 'low_volume',
          message: '${c.name} 的取样量低于设定的最小移液量；请核对移液器或制备工作液。',
        ),
      );
    }
  }
  if (!total.isFinite || total > volume && !_close(total, volume)) {
    throw ArgumentError('母液总体积超过目标反应体积。');
  }
  final diluent = math.max(0.0, volume - total);
  if (_belowMinimum(diluent, minimumVolumeMl)) {
    warnings.add(
      const PlanningWarning(
        code: 'low_diluent_volume',
        message: '补加溶剂体积低于设定的最小移液量，请核对操作可行性。',
      ),
    );
  }
  if (reference == 0) {
    warnings.add(
      PlanningWarning(
        slot: referenceSlot,
        code: 'zero_reference',
        message: '参照试剂用量为 0，投料比不适用。',
      ),
    );
  }
  warnings.addAll(
    _preparedStockWarnings(input, {
      for (final row in rows) row.slot: row.aliquotMl,
    }),
  );
  return CalculationResult(
    input: input,
    ratioType: ratioType,
    referenceSlot: referenceSlot,
    substrates: rows,
    totalVolumeMl: volume,
    stockVolumeMl: total,
    diluentVolumeMl: diluent,
    warnings: warnings,
  );
}

/// Retained recipes describe what was originally prepared. New doses only
/// change demand; they never silently expand a recorded preparation.
List<PlanningWarning> _preparedStockWarnings(
  CalculationInputSnapshot input,
  Map<int, double> currentNeeds, {
  bool batch = false,
}) {
  final warnings = <PlanningWarning>[];
  for (final recipe in input.workingStocks) {
    final need = currentNeeds[recipe.slot];
    // Disabled slots may retain archival provenance, but have no current use.
    if (need == null ||
        need <= recipe.preparationVolumeMl ||
        _close(need, recipe.preparationVolumeMl)) {
      continue;
    }
    final sourceName = input.substrates[recipe.slot].name.trim();
    final name = sourceName.isEmpty ? '试剂 ${recipe.slot + 1}' : sourceName;
    warnings.add(
      PlanningWarning(
        slot: recipe.slot,
        code: 'insufficient_working_stock',
        message:
            '$name 的原工作液配制量为 ${recipe.preparationVolumeMl} mL，'
            '${batch ? '当前有效组总需求（含重复和额外配制）' : '当前单次需求'}为 $need mL；'
            '原配制量不足，请另行确认补配。',
      ),
    );
  }
  return warnings;
}

GradientTotals _totals(
  CalculationResult baseline,
  GradientSpec spec,
  List<GradientGroup> groups,
) {
  final valid = groups.where((g) => g.isValid).toList();
  final multiplier = spec.replicates * (1 + spec.extraPreparationFraction);
  final amounts = <int, double>{for (final s in baseline.substrates) s.slot: 0};
  double diluent = 0;
  double total = 0;
  for (final group in valid) {
    for (final s in group.result!.substrates) {
      amounts[s.slot] =
          amounts[s.slot]! + _checkedProduct(s.aliquotMl, multiplier, '配制总量');
    }
    diluent += _checkedProduct(
      group.result!.diluentVolumeMl,
      multiplier,
      '补液总量',
    );
    total += _checkedProduct(group.result!.totalVolumeMl, multiplier, '反应总量');
  }
  if (!total.isFinite ||
      !diluent.isFinite ||
      amounts.values.any((v) => !v.isFinite)) {
    throw ArgumentError('梯度汇总超出可计算范围。');
  }
  return GradientTotals(
    validGroupCount: valid.length,
    failedGroupCount: groups.length - valid.length,
    reactionCount: valid.length * spec.replicates,
    preparationReactionEquivalent: valid.length * multiplier,
    aliquotsMl: amounts,
    diluentMl: diluent,
    totalVolumeMl: total,
  );
}

WorkingStockProposal _workingProposal(
  CalculationResult source,
  int slot,
  double factor,
  double minimum,
  double parentRequired,
  String diluentName,
  List<CalculationResult> results,
) {
  final s = source.substrateAt(slot);
  var reason = '';
  double parent = 0, diluent = 0, preparation = 0, required = 0, aliquot = 0;
  double? molar, mass;
  try {
    if (!factor.isFinite || factor < 1) {
      throw ArgumentError('稀释倍数必须是大于等于 1 的有限数字。');
    }
    if (s.aliquotMl <= 0) throw ArgumentError('试剂用量为 0，无需制备工作液。');
    aliquot = _checkedProduct(s.aliquotMl, factor, '工作液取样量');
    for (final result in results) {
      final before = result.substrateAt(slot).aliquotMl;
      final after = _checkedProduct(before, factor, '工作液取样量');
      if (after < minimum && !_close(after, minimum)) {
        throw ArgumentError('该稀释倍数仍不能达到最小移液量。');
      }
      final capacity = before + result.diluentVolumeMl;
      if (after > capacity && !_close(after, capacity)) {
        throw ArgumentError('工作液取样量超过固定总体积的剩余空间；请调整母液、阈值或总体积。');
      }
    }
    molar = s.stockMolarMm == null ? null : s.stockMolarMm! / factor;
    mass = s.stockMassMgMl == null ? null : s.stockMassMgMl! / factor;
    if (molar != null && (!molar.isFinite || molar <= 0) ||
        mass != null && (!mass.isFinite || mass <= 0)) {
      throw ArgumentError('工作液浓度超出可计算范围。');
    }
    required = _checkedProduct(parentRequired, factor, '工作液总需求');
    preparation = math.max(required, minimum * factor);
    if (factor > 1) {
      preparation = math.max(preparation, minimum * factor / (factor - 1));
    }
    parent = preparation / factor;
    diluent = preparation - parent;
    if (!preparation.isFinite ||
        !parent.isFinite ||
        !diluent.isFinite ||
        preparation <= 0 ||
        parent <= 0 ||
        (parent < minimum && !_close(parent, minimum)) ||
        (factor > 1 &&
            (diluent <= 0 || diluent < minimum && !_close(diluent, minimum)))) {
      throw ArgumentError('无法在最小移液量限制内配制该工作液。');
    }
  } catch (error) {
    reason = _errorText(error);
  }
  return WorkingStockProposal(
    sourceResult: source,
    slot: slot,
    feasible: reason.isEmpty,
    reason: reason.isEmpty
        ? (factor > 1 ? '体积可行；请自行确认稀释液兼容性。稀释会改变 DMSO 等溶剂组成。' : '已达到最小移液量，无需稀释。')
        : reason,
    factor: factor,
    parentStockMolarMm: s.stockMolarMm,
    parentStockMassMgMl: s.stockMassMgMl,
    stockMolarMm: molar,
    stockMassMgMl: mass,
    newAliquotMl: aliquot,
    parentStockMl: parent,
    diluentMl: diluent,
    preparationVolumeMl: preparation,
    requiredVolumeMl: required,
    minimumVolumeMl: minimum,
    diluentName: diluentName.trim(),
  );
}

void _validateMinimum(double value) {
  if (!value.isFinite || value < 0) throw ArgumentError('最小移液量必须是非负有限数字。');
}

void _validatePreparation(int replicates, double extra) {
  if (replicates <= 0) throw ArgumentError('重复数必须是正整数。');
  if (!extra.isFinite || extra < 0 || !(replicates * (1 + extra)).isFinite) {
    throw ArgumentError('额外配制比例必须是非负有限数字。');
  }
}

void _validatePointGenerator(double start, int count) {
  if (!start.isFinite || start < 0) throw ArgumentError('起点必须是非负有限数字。');
  if (count <= 0 || count > 1000) throw ArgumentError('梯度点数必须为 1 至 1000。');
}

double _checkedProduct(double a, double b, String name) {
  final result = a * b;
  if (!result.isFinite || a > 0 && b > 0 && result == 0) {
    throw ArgumentError('$name超出可计算范围。');
  }
  return result;
}

bool _belowMinimum(double value, double minimum) =>
    value > 0 && value < minimum && !_close(value, minimum);

bool _close(double a, double b) =>
    a == b || (a - b).abs() <= 1e-9 * math.max(a.abs(), b.abs());
String _errorText(Object error) =>
    error is ArgumentError ? error.message.toString() : error.toString();
