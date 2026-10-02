import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilovebioconjugation/core/chemical.dart';
import 'package:ilovebioconjugation/core/reaction.dart';
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

  @override
  CalculatorState build() {
    _disposed = false;
    _lifecycle++;
    ref.onDispose(() => _disposed = true);
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
    _replaceInputs(state.copyWith(substrates: substrates));
  }

  void toggleSubstrateEnabled(int index) {
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
          template.defaultReactionRatio?.toString() ?? (index == 0 ? '1' : ''),
      // A template describes a stock, not a previous reaction's aliquot.
      storageVolume: '',
      storageVolumeUnit: ref.read(appSettingsProvider).defaultVolumeUnit,
    );
    _replaceInputs(state.copyWith(substrates: substrates));
  }

  void _replaceInputs(
    CalculatorState next, {
    String message = '参数已更改，请重新运行计算。',
  }) {
    state = next.copyWith(
      rows: const [],
      summaryRows: const [],
      metrics: const ResultMetrics(),
      errorMessage: '就绪',
      statusMessage: message,
      statusLevel: StatusLevel.info,
    );
  }

  CalculationInputSnapshot _captureInputs() => CalculationInputSnapshot(
    reactionVolume: state.reactionVolume,
    reactionVolumeUnit: state.reactionVolumeUnit,
    ratioType: state.ratioType,
    substrates: state.substrates.map((s) => s.toSnapshot()).toList(),
  );

  // ── calculation ──────────────────────────────────────────────────────

  void calculate() {
    final generation = ++_calculationGeneration;
    try {
      final inputSnapshot = _captureInputs();
      state = state.copyWith(errorMessage: '就绪', historySaveError: '');

      final reactionVolumeRaw = parseFloatOrNull(state.reactionVolume);
      final reactionVolume = reactionVolumeRaw != null
          ? convertVolumeToMl(reactionVolumeRaw, state.reactionVolumeUnit)
          : null;

      final main = _buildChemical(state.substrates[0], '主底物');
      final activeSlots = [
        0,
        for (var i = 1; i < state.substrates.length; i++)
          if (state.substrates[i].enabled) i,
      ];
      final secondaries = [
        for (final i in activeSlots.skip(1))
          _buildChemical(state.substrates[i], '副底物$i'),
      ];

      final rxn = Reaction(
        ratioType: state.ratioType,
        substrateMain: main,
        substratesSecondary: secondaries,
        reactionVolume: reactionVolume,
      );

      double? diluentVolume;
      if (rxn.reactionVolume != null) {
        diluentVolume = (rxn.reactionVolume! - rxn.totalStockVolume).clamp(
          0,
          double.infinity,
        );
      }

      // Build result rows
      final rows = <ResultRow>[];
      for (var idx = 0; idx < rxn.allSubstrates.length; idx++) {
        final chem = rxn.allSubstrates[idx];
        final role = idx == 0 ? '主底物' : '副底物${activeSlots[idx]}';
        // The solver has already refreshed both bases. Display these values
        // directly so the ratio basis never changes a column's meaning.
        final volumeText = _formatWithUnit(chem.storageConcVolume, 'volume');
        final volumePct = _formatPercent(
          chem.storageConcVolume,
          rxn.reactionVolume,
        );
        final ratioText = chem.reactionRatio != null
            ? _formatNumber(chem.reactionRatio!, 4)
            : 'N/A';
        rows.add(
          ResultRow(
            role: role,
            name: chem.name,
            stock: _formatConcentration(
              chem.storageConcMolar,
              'molar_conc',
              chem.molecularWeight,
            ),
            finalConc: _formatConcentration(
              chem.finalConcMolar,
              'molar_conc',
              chem.molecularWeight,
            ),
            stockMass: _formatConcentration(
              chem.storageConcMass,
              'mass_conc',
              chem.molecularWeight,
            ),
            finalConcMass: _formatConcentration(
              chem.finalConcMass,
              'mass_conc',
              chem.molecularWeight,
            ),
            volume: volumeText,
            volumePct: volumePct,
            ratio: ratioText,
          ),
        );
      }

      final summaryRows = <(String, String)>[
        ('反应体积', _formatWithUnit(rxn.reactionVolume, 'volume')),
        ('反应体积来源', reactionVolumeRaw == null ? '根据已知条件推导' : '用户指定'),
        ('投料比类型', rxn.ratioType ? '摩尔比' : '质量比'),
        ('已启用副底物', '${rxn.secondarySubstrates.length}'),
        ('母液总体积', _formatWithUnit(rxn.totalStockVolume, 'volume')),
        ('补加溶剂体积', _formatWithUnit(diluentVolume, 'volume')),
      ];
      final metrics = ResultMetrics(
        totalVolume: _formatWithUnit(rxn.reactionVolume, 'volume'),
        stockVolume: _formatWithUnit(rxn.totalStockVolume, 'volume'),
        diluentVolume: _formatWithUnit(diluentVolume, 'volume'),
        substrateCount: '${rxn.allSubstrates.length}',
      );

      state = state.copyWith(
        rows: rows,
        summaryRows: summaryRows,
        metrics: metrics,
        statusMessage: '计算完成，请核对取样清单。',
        statusLevel: StatusLevel.success,
      );

      // Persistence failures are reported separately from valid results.
      unawaited(_saveHistory(rxn, inputSnapshot, generation));
    } catch (e) {
      state = state.copyWith(
        errorMessage: '计算错误: $e',
        metrics: const ResultMetrics(),
        rows: [],
        summaryRows: [],
        statusMessage: '计算失败，请检查输入条件。',
        statusLevel: StatusLevel.error,
      );
    }
  }

  Future<void> _saveHistory(
    Reaction rxn,
    CalculationInputSnapshot inputSnapshot,
    int generation,
  ) async {
    final lifecycle = _lifecycle;
    try {
      final db = ref.read(appDatabaseProvider);
      final substrateResults = <SubstrateResult>[];
      final activeSlots = [
        0,
        for (var i = 1; i < inputSnapshot.substrates.length; i++)
          if (inputSnapshot.substrates[i].enabled) i,
      ];
      for (var i = 0; i < rxn.allSubstrates.length; i++) {
        final chem = rxn.allSubstrates[i];
        substrateResults.add(
          SubstrateResult(
            sortOrder: activeSlots[i],
            name: chem.name,
            role: i == 0 ? 'main' : 'secondary',
            molecularWeight: chem.molecularWeight,
            storageConcMolar: chem.storageConcMolar,
            storageConcMass: chem.storageConcMass,
            storageVolume: chem.storageConcVolume,
            finalConcMolar: chem.finalConcMolar,
            finalConcMass: chem.finalConcMass,
            reactionRatio: chem.reactionRatio,
          ),
        );
      }
      await db.saveCalculation(
        createdAt: DateTime.now(),
        ratioType: rxn.ratioType,
        reactionVolume: rxn.reactionVolume,
        reactionVolumeUnit: 'mL',
        totalStockVolume: rxn.totalStockVolume,
        diluentVolume: (rxn.reactionVolume ?? 0) - rxn.totalStockVolume > 0
            ? (rxn.reactionVolume! - rxn.totalStockVolume)
            : 0,
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
      _replaceInputs(
        state.copyWith(
          reactionVolume: snapshot.reactionVolume,
          reactionVolumeUnit: snapshot.reactionVolumeUnit,
          ratioType: snapshot.ratioType,
          substrates: [
            ...snapshot.substrates.map(SubstrateInput.fromSnapshot),
            ..._defaultSubstrates(
              enableFirstSecondary: false,
            ).skip(snapshot.substrates.length),
          ],
        ),
        message: '已恢复原始输入，请重新运行计算。',
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

  Chemical _buildChemical(SubstrateInput input, String fieldPrefix) {
    final name = input.name.trim().isEmpty ? fieldPrefix : input.name.trim();
    final mwRaw = parseFloatOrNull(input.mw);
    final mw = mwRaw != null ? convertMwToDa(mwRaw, input.mwUnit) : null;

    final storageRaw = parseFloatOrNull(input.storageConc);
    final finalRaw = parseFloatOrNull(input.finalConc);
    final ratio = parseFloatOrNull(input.reactionRatio);
    final volumeRaw = parseFloatOrNull(input.storageVolume);

    final storageUnit = input.storageUnit;
    final finalUnit = input.finalUnit;
    final volumeUnit = input.storageVolumeUnit;

    double? storageMolar;
    double? storageMass;
    if (storageRaw != null) {
      final converted = convertConcentrationToBaseUnit(storageRaw, storageUnit);
      if (isMolarUnit(storageUnit)) {
        storageMolar = converted;
      } else {
        storageMass = converted;
      }
    }

    double? finalMolar;
    double? finalMass;
    if (finalRaw != null) {
      final converted = convertConcentrationToBaseUnit(finalRaw, finalUnit);
      if (isMolarUnit(finalUnit)) {
        finalMolar = converted;
      } else {
        finalMass = converted;
      }
    }

    final storageVolume = volumeRaw != null
        ? convertVolumeToMl(volumeRaw, volumeUnit)
        : null;

    return Chemical(
      unitCoefficient: _getUnitCoefficient(storageUnit),
      storageConcMolar: storageMolar,
      storageConcMass: storageMass,
      name: name,
      molecularWeight: mw,
      storageConcVolume: storageVolume,
      finalConcMolar: finalMolar,
      finalConcMass: finalMass,
      reactionRatio: ratio,
    );
  }

  int _getUnitCoefficient(String unit) {
    const mass = {'g/mL': 3, 'mg/mL': 0, 'ug/mL': -3, 'ng/mL': -6, 'pg/mL': -9};
    const molar = {'M': 6, 'mM': 3, 'uM': 0, 'nM': -3, 'pM': -6};
    return mass[unit] ?? molar[unit] ?? 0;
  }

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
