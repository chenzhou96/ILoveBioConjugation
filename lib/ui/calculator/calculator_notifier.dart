import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ilovebioconjunction/core/chemical.dart';
import 'package:ilovebioconjunction/core/reaction.dart';
import 'package:ilovebioconjunction/core/validators.dart';
import 'package:ilovebioconjunction/data/calculation_history.dart';
import 'package:ilovebioconjunction/data/app_database.dart';
import 'package:ilovebioconjunction/ui/calculator/state.dart';
import 'package:ilovebioconjunction/ui/history/history_screen.dart';

/// Provider for the calculator state.
final calculatorProvider =
    NotifierProvider<CalculatorNotifier, CalculatorState>(
  CalculatorNotifier.new,
);

class CalculatorNotifier extends Notifier<CalculatorState> {
  static const maxSecondaries = 3;
  static const storageUnits = [
    'g/mL', 'mg/mL', 'ug/mL', 'ng/mL', 'pg/mL',
    'M', 'mM', 'uM', 'nM', 'pM',
  ];
  static const volumeUnits = ['L', 'mL', 'uL', 'nL', 'pL'];
  static const mwUnits = ['Da', 'kDa'];

  @override
  CalculatorState build() {
    final substrates = <SubstrateInput>[
      SubstrateInput(
        enabled: true,
        name: '主底物',
        storageUnit: 'mg/mL',
        finalUnit: 'mg/mL',
        reactionRatio: '1',
        mwUnit: 'kDa',
      ),
      for (var i = 1; i <= maxSecondaries; i++)
        SubstrateInput(
          enabled: i == 1,
          name: '副底物$i',
          storageUnit: 'mg/mL',
          finalUnit: 'mg/mL',
          mwUnit: 'Da',
        ),
    ];
    return CalculatorState(substrates: substrates);
  }

  // ── field setters ────────────────────────────────────────────────────

  void setReactionVolume(String value) {
    state = state.copyWith(reactionVolume: value);
  }

  void setReactionVolumeUnit(String unit) {
    state = state.copyWith(reactionVolumeUnit: unit);
  }

  void setRatioType(bool molar) {
    state = state.copyWith(ratioType: molar);
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
    state = state.copyWith(substrates: substrates);
  }

  void toggleSubstrateEnabled(int index) {
    final substrates = state.substrates.toList();
    substrates[index] = substrates[index].copyWith(
      enabled: !substrates[index].enabled,
    );
    state = state.copyWith(substrates: substrates);
  }

  // ── calculation ──────────────────────────────────────────────────────

  void calculate() {
    try {
      state = state.copyWith(errorMessage: '就绪');

      final reactionVolumeRaw = parseFloatOrNull(state.reactionVolume);
      final reactionVolume = reactionVolumeRaw != null
          ? convertVolumeToMl(reactionVolumeRaw, state.reactionVolumeUnit)
          : null;

      final main = _buildChemical(state.substrates[0], '主底物');
      final secondaries = <Chemical>[];
      for (var i = 1; i < state.substrates.length; i++) {
        if (state.substrates[i].enabled) {
          secondaries.add(_buildChemical(state.substrates[i], '副底物$i'));
        }
      }

      final rxn = Reaction(
        ratioType: state.ratioType,
        substrateMain: main,
        substratesSecondary: secondaries,
        reactionVolume: reactionVolume,
      );

      final totalStock = rxn.totalStockVolume;
      final warningLines = <String>[];

      if (rxn.reactionVolume != null && totalStock > rxn.reactionVolume!) {
        warningLines.add(
          '母液总体积超过目标反应体积，系统已自动把反应总体积修正为各母液体积之和。',
        );
        rxn.reactionVolume = totalStock;
        for (final chem in rxn.allSubstrates) {
          if (rxn.ratioType &&
              chem.storageConcMolar != null &&
              chem.storageConcVolume != null) {
            chem.finalConcMolar =
                chem.storageConcMolar! * chem.storageConcVolume! / rxn.reactionVolume!;
          }
          if (!rxn.ratioType &&
              chem.storageConcMass != null &&
              chem.storageConcVolume != null) {
            chem.finalConcMass =
                chem.storageConcMass! * chem.storageConcVolume! / rxn.reactionVolume!;
          }
          chem.outputTest();
        }
      }

      double? diluentVolume;
      if (rxn.reactionVolume != null) {
        diluentVolume = (rxn.reactionVolume! - rxn.totalStockVolume)
            .clamp(0, double.infinity);
      }

      // Build result rows
      final rows = <ResultRow>[];
      for (var idx = 0; idx < rxn.allSubstrates.length; idx++) {
        final chem = rxn.allSubstrates[idx];
        final role = idx == 0 ? '主底物' : '副底物$idx';
        final stockText = rxn.ratioType
            ? _formatWithUnit(chem.storageConcMolar, 'molar_conc')
            : _formatWithUnit(chem.storageConcMass, 'mass_conc');
        final finalText = rxn.ratioType
            ? _formatWithUnit(chem.finalConcMolar, 'molar_conc')
            : _formatWithUnit(chem.finalConcMass, 'mass_conc');
        final volumeText =
            _formatWithUnit(chem.storageConcVolume, 'volume');
        final volumePct = _formatPercent(
          chem.storageConcVolume,
          rxn.reactionVolume,
        );
        final ratioText = chem.reactionRatio != null
            ? chem.reactionRatio!.toStringAsFixed(4)
            : 'N/A';
        rows.add(ResultRow(
          role: role,
          name: chem.name,
          stock: stockText,
          finalConc: finalText,
          volume: volumeText,
          volumePct: volumePct,
          ratio: ratioText,
        ));
      }

      final summaryRows = <(String, String)>[
        (
          '反应体积',
          _formatWithUnit(rxn.reactionVolume, 'volume'),
        ),
        ('投料比类型', rxn.ratioType ? '摩尔比' : '质量比'),
        ('已启用副底物', '${rxn.secondarySubstrates.length}'),
        ('母液总体积', _formatWithUnit(rxn.totalStockVolume, 'volume')),
        (
          '补加溶剂体积',
          _formatWithUnit(diluentVolume, 'volume'),
        ),
      ];
      if (warningLines.isNotEmpty) {
        summaryRows.add(('系统提示', warningLines.join('；')));
      }

      final metrics = ResultMetrics(
        totalVolume:
            _formatWithUnit(rxn.reactionVolume, 'volume'),
        stockVolume:
            _formatWithUnit(rxn.totalStockVolume, 'volume'),
        diluentVolume:
            _formatWithUnit(diluentVolume, 'volume'),
        substrateCount: '${rxn.allSubstrates.length}',
      );

      state = state.copyWith(
        rows: rows,
        summaryRows: summaryRows,
        metrics: metrics,
        statusMessage: warningLines.isNotEmpty
            ? warningLines[0]
            : '计算完成。右侧表格已更新。',
        statusLevel:
            warningLines.isNotEmpty ? StatusLevel.warning : StatusLevel.success,
      );

      // Save to history (fire-and-forget)
      _saveHistory(rxn);
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

  void _saveHistory(Reaction rxn) {
    final db = ref.read(appDatabaseProvider);
    final substrateResults = <SubstrateResult>[];
    for (var i = 0; i < rxn.allSubstrates.length; i++) {
      final chem = rxn.allSubstrates[i];
      substrateResults.add(SubstrateResult(
        sortOrder: i,
        name: chem.name,
        role: i == 0 ? 'main' : 'secondary',
        molecularWeight: chem.molecularWeight,
        storageConcMolar: chem.storageConcMolar,
        storageConcMass: chem.storageConcMass,
        storageVolume: chem.storageConcVolume,
        finalConcMolar: chem.finalConcMolar,
        finalConcMass: chem.finalConcMass,
        reactionRatio: chem.reactionRatio,
      ));
    }
    db.saveCalculation(
      createdAt: DateTime.now(),
      ratioType: rxn.ratioType,
      reactionVolume: rxn.reactionVolume,
      reactionVolumeUnit: 'mL',
      totalStockVolume: rxn.totalStockVolume,
      diluentVolume: (rxn.reactionVolume ?? 0) - rxn.totalStockVolume > 0
          ? (rxn.reactionVolume! - rxn.totalStockVolume)
          : 0,
      substrates: substrateResults,
    );
    ref.invalidate(historyProvider);
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
      const headers = ['类别', '名称', '母液浓度', '终浓度', '取样体积', '母液体积占比', '投料比'];
      buf.writeln('底物结果');
      buf.writeln('=' * 28);

      final widths = List.filled(headers.length, 0);
      for (var i = 0; i < headers.length; i++) {
        widths[i] = headers[i].length;
        for (final row in state.rows) {
          final vals = [
            row.role, row.name, row.stock, row.finalConc,
            row.volume, row.volumePct, row.ratio,
          ];
          if (vals[i].length > widths[i]) widths[i] = vals[i].length;
        }
      }

      buf.writeln(headers
          .asMap()
          .entries
          .map((e) => e.value.padRight(widths[e.key]))
          .join(' | '));
      buf.writeln(List.filled(
          headers.map((h) => h.padRight(widths[headers.indexOf(h)])).join(' | ').length,
          '-'));

      for (final row in state.rows) {
        final vals = [
          row.role, row.name, row.stock, row.finalConc,
          row.volume, row.volumePct, row.ratio,
        ];
        buf.writeln(vals
            .asMap()
            .entries
            .map((e) => e.value.padRight(widths[e.key]))
            .join(' | '));
      }
    }
    return buf.toString().trim();
  }

  // ── restore ──────────────────────────────────────────────────────────

  void restoreFromHistory(CalculationHistory record) {
    final substrates = state.substrates.toList();

    // Set reaction settings
    final vol = record.reactionVolume;
    final volUnit = record.reactionVolumeUnit;

    // Build substrate list from history
    final historySubs = record.substrates;
    for (var i = 0; i < substrates.length && i < historySubs.length; i++) {
      final hs = historySubs[i];
      final old = substrates[i];

      // Convert molecular weight from Da to appropriate display unit
      String mwText = '';
      String mwUnit = 'Da';
      if (hs.molecularWeight != null) {
        if (hs.molecularWeight! >= 1000) {
          mwText = (hs.molecularWeight! / 1000).toStringAsFixed(4);
          mwUnit = 'kDa';
        } else {
          mwText = hs.molecularWeight!.toStringAsFixed(2);
          mwUnit = 'Da';
        }
      }

      // Restore storage concentration (saved in mM or mg/mL base)
      String storageConcText = '';
      String storageUnit = old.storageUnit;
      if (hs.storageConcMolar != null) {
        storageConcText = hs.storageConcMolar!.toStringAsFixed(4);
        storageUnit = 'mM';
      } else if (hs.storageConcMass != null) {
        storageConcText = hs.storageConcMass!.toStringAsFixed(4);
        storageUnit = 'mg/mL';
      }

      // Restore final concentration
      String finalConcText = '';
      String finalUnit = old.finalUnit;
      if (hs.finalConcMolar != null) {
        finalConcText = hs.finalConcMolar!.toStringAsFixed(4);
        finalUnit = 'mM';
      } else if (hs.finalConcMass != null) {
        finalConcText = hs.finalConcMass!.toStringAsFixed(4);
        finalUnit = 'mg/mL';
      }

      // Restore storage volume (saved in mL, display in uL)
      String storageVolText = '';
      String storageVolUnit = 'uL';
      if (hs.storageVolume != null) {
        final volUl = hs.storageVolume! * 1000; // mL → uL
        storageVolText = volUl.toStringAsFixed(4);
        storageVolUnit = 'uL';
      }

      // Restore reaction ratio
      String ratioText = '';
      if (hs.reactionRatio != null) {
        ratioText = hs.reactionRatio!.toStringAsFixed(4);
      }

      substrates[i] = old.copyWith(
        enabled: true,
        name: hs.name,
        mw: mwText,
        mwUnit: mwUnit,
        storageConc: storageConcText,
        storageUnit: storageUnit,
        finalConc: finalConcText,
        finalUnit: finalUnit,
        reactionRatio: ratioText,
        storageVolume: storageVolText,
        storageVolumeUnit: storageVolUnit,
      );
    }

    state = state.copyWith(
      reactionVolume: vol != null ? vol.toStringAsFixed(4) : '',
      reactionVolumeUnit: volUnit,
      ratioType: record.ratioType,
      substrates: substrates,
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

  String _formatWithUnit(double? value, String unitType) {
    if (value == null) return 'N/A';
    final absV = value.abs();
    switch (unitType) {
      case 'volume':
        if (absV >= 1000) return '${(value / 1000).toStringAsFixed(2)} L';
        if (absV >= 1) return '${value.toStringAsFixed(2)} mL';
        if (absV >= 0.001) return '${(value * 1000).toStringAsFixed(2)} uL';
        if (absV >= 0.000001) return '${(value * 1000000).toStringAsFixed(2)} nL';
        return '${(value * 1000000000).toStringAsFixed(2)} pL';
      case 'mass_conc':
        if (absV >= 1000) return '${(value / 1000).toStringAsFixed(2)} g/mL';
        if (absV >= 1) return '${value.toStringAsFixed(2)} mg/mL';
        if (absV >= 0.001) return '${(value * 1000).toStringAsFixed(2)} ug/mL';
        if (absV >= 0.000001) return '${(value * 1000000).toStringAsFixed(2)} ng/mL';
        return '${(value * 1000000000).toStringAsFixed(2)} pg/mL';
      case 'molar_conc':
        if (absV >= 1000) return '${(value / 1000).toStringAsFixed(2)} M';
        if (absV >= 1) return '${value.toStringAsFixed(2)} mM';
        if (absV >= 0.001) return '${(value * 1000).toStringAsFixed(2)} uM';
        if (absV >= 0.000001) return '${(value * 1000000).toStringAsFixed(2)} nM';
        return '${(value * 1000000000).toStringAsFixed(2)} pM';
      case 'mw':
        return absV >= 1000
            ? '${(value / 1000).toStringAsFixed(2)} kDa'
            : '${value.toStringAsFixed(2)} Da';
      default:
        return value.toStringAsFixed(4);
    }
  }

  String _formatPercent(double? numerator, double? denominator) {
    if (numerator == null ||
        denominator == null ||
        denominator <= 0) {
      return 'N/A';
    }
    return '${(numerator / denominator * 100).toStringAsFixed(2)}%';
  }
}
