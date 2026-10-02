import 'package:ilovebioconjugation/data/calculation_input_snapshot.dart';

/// Input state for a single substrate card.
class SubstrateInput {
  final bool enabled;
  final String name;
  final String mw;
  final String mwUnit; // "Da" or "kDa"
  final String storageConc;
  final String storageUnit; // molar or mass conc unit
  final String finalConc;
  final String finalUnit;
  final String reactionRatio;
  final String storageVolume;
  final String storageVolumeUnit; // volume unit

  const SubstrateInput({
    this.enabled = false,
    this.name = '',
    this.mw = '',
    this.mwUnit = 'Da',
    this.storageConc = '',
    this.storageUnit = 'mg/mL',
    this.finalConc = '',
    this.finalUnit = 'mg/mL',
    this.reactionRatio = '',
    this.storageVolume = '',
    this.storageVolumeUnit = 'uL',
  });

  SubstrateInputSnapshot toSnapshot() => SubstrateInputSnapshot(
    enabled: enabled,
    name: name,
    mw: mw,
    mwUnit: mwUnit,
    storageConc: storageConc,
    storageUnit: storageUnit,
    finalConc: finalConc,
    finalUnit: finalUnit,
    reactionRatio: reactionRatio,
    storageVolume: storageVolume,
    storageVolumeUnit: storageVolumeUnit,
  );

  factory SubstrateInput.fromSnapshot(SubstrateInputSnapshot snapshot) =>
      SubstrateInput(
        enabled: snapshot.enabled,
        name: snapshot.name,
        mw: snapshot.mw,
        mwUnit: snapshot.mwUnit,
        storageConc: snapshot.storageConc,
        storageUnit: snapshot.storageUnit,
        finalConc: snapshot.finalConc,
        finalUnit: snapshot.finalUnit,
        reactionRatio: snapshot.reactionRatio,
        storageVolume: snapshot.storageVolume,
        storageVolumeUnit: snapshot.storageVolumeUnit,
      );

  SubstrateInput copyWith({
    bool? enabled,
    String? name,
    String? mw,
    String? mwUnit,
    String? storageConc,
    String? storageUnit,
    String? finalConc,
    String? finalUnit,
    String? reactionRatio,
    String? storageVolume,
    String? storageVolumeUnit,
  }) {
    return SubstrateInput(
      enabled: enabled ?? this.enabled,
      name: name ?? this.name,
      mw: mw ?? this.mw,
      mwUnit: mwUnit ?? this.mwUnit,
      storageConc: storageConc ?? this.storageConc,
      storageUnit: storageUnit ?? this.storageUnit,
      finalConc: finalConc ?? this.finalConc,
      finalUnit: finalUnit ?? this.finalUnit,
      reactionRatio: reactionRatio ?? this.reactionRatio,
      storageVolume: storageVolume ?? this.storageVolume,
      storageVolumeUnit: storageVolumeUnit ?? this.storageVolumeUnit,
    );
  }
}

/// A single row in the result table.
class ResultRow {
  final String role;
  final String name;

  /// Formatted molar concentrations, independent of the selected ratio basis.
  final String stock;
  final String finalConc;

  /// Formatted mass concentrations, or an explicit conversion-unavailable label.
  final String stockMass;
  final String finalConcMass;
  final String volume;
  final String volumePct;
  final String ratio;

  const ResultRow({
    required this.role,
    required this.name,
    required this.stock,
    required this.finalConc,
    required this.stockMass,
    required this.finalConcMass,
    required this.volume,
    required this.volumePct,
    required this.ratio,
  });
}

/// Metric values displayed in the result panel.
class ResultMetrics {
  final String totalVolume;
  final String stockVolume;
  final String diluentVolume;
  final String substrateCount;

  const ResultMetrics({
    this.totalVolume = '--',
    this.stockVolume = '--',
    this.diluentVolume = '--',
    this.substrateCount = '--',
  });
}

/// Status levels for the status banner.
enum StatusLevel { info, success, warning, error }

/// The complete state of the calculator.
class CalculatorState {
  final List<SubstrateInput> substrates;
  final String reactionVolume;
  final String reactionVolumeUnit;
  final bool ratioType; // true=molar, false=mass
  final String statusMessage;
  final StatusLevel statusLevel;
  final String errorMessage;
  final String historySaveError;
  final ResultMetrics metrics;
  final List<ResultRow> rows;
  final List<(String, String)> summaryRows;

  const CalculatorState({
    this.substrates = const [],
    this.reactionVolume = '',
    this.reactionVolumeUnit = 'uL',
    this.ratioType = true,
    this.statusMessage = '填写已知条件，再点击“运行计算”。',
    this.statusLevel = StatusLevel.info,
    this.errorMessage = '就绪',
    this.historySaveError = '',
    this.metrics = const ResultMetrics(),
    this.rows = const [],
    this.summaryRows = const [],
  });

  CalculatorState copyWith({
    List<SubstrateInput>? substrates,
    String? reactionVolume,
    String? reactionVolumeUnit,
    bool? ratioType,
    String? statusMessage,
    StatusLevel? statusLevel,
    String? errorMessage,
    String? historySaveError,
    ResultMetrics? metrics,
    List<ResultRow>? rows,
    List<(String, String)>? summaryRows,
  }) {
    return CalculatorState(
      substrates: substrates ?? this.substrates,
      reactionVolume: reactionVolume ?? this.reactionVolume,
      reactionVolumeUnit: reactionVolumeUnit ?? this.reactionVolumeUnit,
      ratioType: ratioType ?? this.ratioType,
      statusMessage: statusMessage ?? this.statusMessage,
      statusLevel: statusLevel ?? this.statusLevel,
      errorMessage: errorMessage ?? this.errorMessage,
      historySaveError: historySaveError ?? this.historySaveError,
      metrics: metrics ?? this.metrics,
      rows: rows ?? this.rows,
      summaryRows: summaryRows ?? this.summaryRows,
    );
  }
}
