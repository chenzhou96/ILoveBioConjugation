/// Input state for a single substrate card.
class SubstrateInput {
  bool enabled;
  String name;
  String mw;
  String mwUnit; // "Da" or "kDa"
  String storageConc;
  String storageUnit; // molar or mass conc unit
  String finalConc;
  String finalUnit;
  String reactionRatio;
  String storageVolume;
  String storageVolumeUnit; // volume unit

  SubstrateInput({
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
  final String stock;
  final String finalConc;
  final String volume;
  final String volumePct;
  final String ratio;

  const ResultRow({
    required this.role,
    required this.name,
    required this.stock,
    required this.finalConc,
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
  final ResultMetrics metrics;
  final List<ResultRow> rows;
  final List<(String, String)> summaryRows;

  const CalculatorState({
    this.substrates = const [],
    this.reactionVolume = '',
    this.reactionVolumeUnit = 'uL',
    this.ratioType = true,
    this.statusMessage = '请在左侧填写参数，再点击"运行计算"。',
    this.statusLevel = StatusLevel.info,
    this.errorMessage = '就绪',
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
      metrics: metrics ?? this.metrics,
      rows: rows ?? this.rows,
      summaryRows: summaryRows ?? this.summaryRows,
    );
  }
}
