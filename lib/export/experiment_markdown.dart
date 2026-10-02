import '../core/planning.dart';
import '../data/calculation_input_snapshot.dart';

/// Clipboard and .md export share this serializer. It consumes raw immutable
/// results, never the rounded strings used by the compact screen.
String buildCalculationMarkdown(CalculationResult result) {
  final out = StringBuffer('## 计划配方\n\n');
  _inputs(out, result);
  _singleResults(out, result);
  _workingStocks(
    out,
    result.input.workingStocks,
    currentRequired: {for (final s in result.substrates) s.slot: s.aliquotMl},
  );
  return '${out.toString().trimRight()}\n';
}

String buildGradientMarkdown(GradientPlan plan) {
  final out = StringBuffer('## 单因素梯度计划\n\n');
  final selected = plan.baseline.substrateAt(plan.spec.selectedSlot);
  final protein = plan.baseline.substrateAt(plan.spec.proteinSlot);
  out.writeln('- 梯度试剂：${escapeMarkdownCell(selected.name)}');
  out.writeln('- 梯度单位：${escapeMarkdownCell(plan.spec.unit)}');
  if (plan.spec.unit == 'eq') {
    out.writeln('- eq 基准：${plan.baseline.ratioType ? '摩尔当量' : '质量倍数（不是摩尔当量）'}');
  }
  out.writeln('- 输入梯度点：${plan.spec.points.map(escapeMarkdownCell).join('、')}');
  out.writeln('- 每条件重复数：${plan.spec.replicates}');
  out.writeln(
    '- 额外配制：${formatPlanNumber(plan.spec.extraPreparationFraction * 100)}%（仅汇总，单组配方不变）',
  );
  out.writeln('- 锁定：${escapeMarkdownCell(protein.name)} 的投料量、每组总体积、其余试剂终浓度');
  out.writeln(
    '- 条件状态：${plan.totals.validGroupCount} 个有效，${plan.totals.failedGroupCount} 个不可执行',
  );
  out.writeln();
  _inputs(out, plan.baseline);
  if (plan.warnings.isNotEmpty) {
    out.writeln('批量操作核对：');
    for (final warning in plan.warnings) {
      out.writeln('- ${escapeMarkdownCell(warning.message)}');
    }
    out.writeln();
  }
  out.writeln('### 固定条件\n');
  out.writeln('每组总体积：${formatPlanVolume(plan.baseline.totalVolumeMl)}\n');
  _table(
    out,
    ['试剂', '固定终浓度（摩尔）', '固定终浓度（质量）', '固定取样量'],
    [
      for (final s in plan.baseline.substrates)
        if (s.slot != plan.spec.selectedSlot)
          [
            s.name,
            formatPlanMolar(s.finalMolarMm),
            formatPlanMass(s.finalMassMgMl),
            formatPlanVolume(_batchSubstrate(plan, s.slot).aliquotMl),
          ],
    ],
  );
  for (final group in plan.groups) {
    out.writeln(
      '### 条件 ${group.index + 1} · ${escapeMarkdownCell(group.pointText)} ${escapeMarkdownCell(plan.spec.unit)}\n',
    );
    if (group.result == null) {
      out.writeln('**不可执行**：${escapeMarkdownCell(group.error ?? '未生成有效结果')}\n');
      continue;
    }
    _singleResults(out, group.result!, heading: false);
  }
  out.writeln('### 配制总量\n');
  if (plan.totals.validGroupsOnly) {
    out.writeln('**仅计入有效条件；不可执行条件未计入以下总量。**\n');
  }
  out.writeln('- 实际反应数：${plan.totals.reactionCount}');
  out.writeln(
    '- 配制量已包含每条件重复数与 ${formatPlanNumber(plan.spec.extraPreparationFraction * 100)}% 预留\n',
  );
  _table(
    out,
    ['取液来源', '母液摩尔浓度', '母液质量浓度', '总取样量（含预留）'],
    [
      for (final s in plan.baseline.substrates)
        [
          _batchSourceName(plan, s.slot),
          formatPlanMolar(_batchSubstrate(plan, s.slot).stockMolarMm),
          formatPlanMass(_batchSubstrate(plan, s.slot).stockMassMgMl),
          formatPlanVolume(plan.totals.aliquotsMl[s.slot] ?? 0),
        ],
      ['补加溶剂', '', '', formatPlanVolume(plan.totals.diluentMl)],
      ['配制总体积', '', '', formatPlanVolume(plan.totals.totalVolumeMl)],
    ],
  );
  _workingStocks(
    out,
    plan.baseline.input.workingStocks,
    currentRequired: plan.totals.aliquotsMl,
  );
  _batchWorkingStocks(out, plan);
  return '${out.toString().trimRight()}\n';
}

/// Compact plain-text batch list. It intentionally includes every condition,
/// irrespective of the UI's current page, and never hides failed groups.
String buildGradientCopyText(GradientPlan plan) {
  String plain(String value) => value.replaceAll(RegExp(r'[\r\n]+'), ' ');
  final reference = plan.baseline.substrateAt(plan.baseline.referenceSlot);
  final out = StringBuffer('梯度取样清单（计划）\n');
  out.writeln(
    '投料比参照：${plain(reference.name)}；${plan.baseline.ratioType ? '摩尔比' : '质量比'}',
  );
  out.writeln(
    '每组 ${formatPlanVolume(plan.baseline.totalVolumeMl)}；每条件 ${plan.spec.replicates} 次重复',
  );
  for (final group in plan.groups) {
    out.writeln(
      '\n条件 ${group.index + 1}：${plain(group.pointText)} ${plan.spec.unit}',
    );
    final result = group.result;
    if (result == null) {
      out.writeln('不可执行：${plain(group.error ?? '没有有效结果')}');
      continue;
    }
    for (final s in result.substrates) {
      out.writeln(
        '${plain(s.name)}：取 ${formatPlanVolume(s.aliquotMl)}；母液 ${formatPlanMolar(s.stockMolarMm)} / ${formatPlanMass(s.stockMassMgMl)}；终浓度 ${formatPlanMolar(s.finalMolarMm)} / ${formatPlanMass(s.finalMassMgMl)}；比值 ${s.ratio == null ? '不适用（参照为0）' : formatPlanNumber(s.ratio!)}',
      );
    }
    out.writeln('补加溶剂：${formatPlanVolume(result.diluentVolumeMl)}');
    for (final warning in result.warnings) {
      out.writeln('提示：${plain(warning.message)}');
    }
  }
  out.writeln(
    '\n配制汇总（${plan.totals.validGroupCount} 个有效条件，${plan.totals.reactionCount} 次反应，预留 ${formatPlanNumber(plan.spec.extraPreparationFraction * 100)}%）',
  );
  if (plan.totals.validGroupsOnly) {
    out.writeln('未计入 ${plan.totals.failedGroupCount} 个不可执行条件');
  }
  for (final s in plan.baseline.substrates) {
    out.writeln(
      '${plain(_batchSourceName(plan, s.slot))}：${formatPlanVolume(plan.totals.aliquotsMl[s.slot] ?? 0)}',
    );
  }
  out.writeln('补加溶剂：${formatPlanVolume(plan.totals.diluentMl)}');
  out.writeln('配制总体积：${formatPlanVolume(plan.totals.totalVolumeMl)}');
  for (final warning in plan.warnings) {
    out.writeln('提示：${plain(warning.message)}');
  }
  for (final stock in plan.workingStocks) {
    out.writeln(
      '共同工作液 · ${plain(plan.baseline.substrateAt(stock.slot).name)}：取原母液 ${formatPlanVolume(stock.parentStockMl)} + ${plain(stock.diluentName)} ${formatPlanVolume(stock.diluentMl)} → ${formatPlanVolume(stock.preparationVolumeMl)}；${formatPlanMolar(stock.stockMolarMm)} / ${formatPlanMass(stock.stockMassMgMl)}',
    );
    out.writeln('提示：稀释会改变 DMSO 等溶剂组成，请核对兼容性。');
  }
  return out.toString().trimRight();
}

SolvedSubstrate _batchSubstrate(GradientPlan plan, int slot) =>
    plan.groups
        .where((g) => g.isValid)
        .map((g) => g.result!.substrateAt(slot))
        .firstOrNull ??
    plan.baseline.substrateAt(slot);

String _batchSourceName(GradientPlan plan, int slot) {
  final name = plan.baseline.substrateAt(slot).name;
  return plan.workingStocks.any((s) => s.slot == slot) ? '$name（共同工作液）' : name;
}

void _batchWorkingStocks(StringBuffer out, GradientPlan plan) {
  if (plan.workingStocks.isEmpty) return;
  out.writeln('### 梯度共同工作液（已采用）\n');
  _table(
    out,
    [
      '试剂',
      '来源摩尔浓度',
      '来源质量浓度',
      '稀释倍数',
      '工作液摩尔浓度',
      '工作液质量浓度',
      '取来源母液',
      '稀释液',
      '加入稀释液',
      '配制总体积',
      '批次需求量',
    ],
    [
      for (final stock in plan.workingStocks)
        [
          plan.baseline.substrateAt(stock.slot).name,
          formatPlanMolar(stock.parentStockMolarMm),
          formatPlanMass(stock.parentStockMassMgMl),
          formatPlanNumber(stock.factor),
          formatPlanMolar(stock.stockMolarMm),
          formatPlanMass(stock.stockMassMgMl),
          formatPlanVolume(stock.parentStockMl),
          stock.diluentName,
          formatPlanVolume(stock.diluentMl),
          formatPlanVolume(stock.preparationVolumeMl),
          formatPlanVolume(stock.requiredVolumeMl),
        ],
    ],
  );
  out.writeln(
    '工作液总需求已包含重复数与额外配制；取样清单中的各组浓度和投料量保持不变。稀释会改变 DMSO 等溶剂组成，请核对所选稀释液兼容性。\n',
  );
}

void _inputs(StringBuffer out, CalculationResult result) {
  final input = result.input;
  final reference = result.substrateAt(result.referenceSlot);
  final referenceDescription = reference.aliquotMl == 0
      ? '用量为 0，投料比不适用'
      : '归一为 1';
  out.writeln('### 原始输入\n');
  out.writeln(
    '- 反应总体积：${escapeMarkdownCell(_original(input.reactionVolume, input.reactionVolumeUnit))}',
  );
  out.writeln('- 投料比类型：${result.ratioType ? '摩尔比' : '质量比'}');
  out.writeln(
    '- 投料比参照：${escapeMarkdownCell(reference.name)}（${_role(reference.slot)}；$referenceDescription）',
  );
  out.writeln(
    '- 最小移液提示阈值：${input.minimumPipettingVolumeUl == 0 ? '已关闭' : '${formatPlanNumber(input.minimumPipettingVolumeUl)} µL（实验室可配置）'}',
  );
  out.writeln();
  _table(
    out,
    ['位置', '名称', '分子量', '母液浓度', '目标终浓度', '输入投料比', '输入取样体积'],
    [
      for (var slot = 0; slot < input.substrates.length; slot++)
        if (slot == 0 || input.substrates[slot].enabled)
          [
            _role(slot),
            input.substrates[slot].name.isEmpty
                ? '未命名'
                : input.substrates[slot].name,
            _original(input.substrates[slot].mw, input.substrates[slot].mwUnit),
            _original(
              input.substrates[slot].storageConc,
              input.substrates[slot].storageUnit,
            ),
            _original(
              input.substrates[slot].finalConc,
              input.substrates[slot].finalUnit,
            ),
            input.substrates[slot].reactionRatio.isEmpty
                ? '未填'
                : input.substrates[slot].reactionRatio,
            _original(
              input.substrates[slot].storageVolume,
              input.substrates[slot].storageVolumeUnit,
            ),
          ],
    ],
  );
  out.writeln('“未填”保留原始未知项；下方为计算得到的计划用量，实际取样与观察待操作后填写。\n');
}

void _singleResults(
  StringBuffer out,
  CalculationResult result, {
  bool heading = true,
}) {
  if (heading) out.writeln('### 取样清单\n');
  out.writeln('- 计划反应总体积：${formatPlanVolume(result.totalVolumeMl)}');
  out.writeln('- 母液总体积：${formatPlanVolume(result.stockVolumeMl)}');
  out.writeln('- 补加溶剂：${formatPlanVolume(result.diluentVolumeMl)}\n');
  _table(
    out,
    [
      '位置',
      '名称',
      '母液摩尔浓度',
      '母液质量浓度',
      '终摩尔浓度',
      '终质量浓度',
      '计划取样量',
      '投料比',
      '实际取样量',
      '观察',
    ],
    [
      for (final s in result.substrates)
        [
          _role(s.slot),
          s.name,
          formatPlanMolar(s.stockMolarMm),
          formatPlanMass(s.stockMassMgMl),
          formatPlanMolar(s.finalMolarMm),
          formatPlanMass(s.finalMassMgMl),
          formatPlanVolume(s.aliquotMl),
          s.ratio == null ? '不适用（参照为 0）' : formatPlanNumber(s.ratio!),
          '',
          '',
        ],
    ],
  );
  if (result.warnings.isNotEmpty) {
    out.writeln('操作核对：');
    for (final warning in result.warnings) {
      out.writeln('- ${escapeMarkdownCell(warning.message)}');
    }
    out.writeln();
  }
}

void _workingStocks(
  StringBuffer out,
  List<WorkingStockProvenance> allStocks, {
  required Map<int, double> currentRequired,
}) {
  final stocks = allStocks
      .where((s) => currentRequired.containsKey(s.slot))
      .toList();
  if (stocks.isEmpty) return;
  out.writeln('### 已采用工作液（原配制方案）\n');
  _table(
    out,
    [
      '步骤',
      '试剂',
      '来源母液（原单位）',
      '稀释倍数',
      '工作液浓度',
      '取来源母液',
      '稀释液',
      '加入稀释液',
      '原采用配制量',
      '原采用需求量',
      '当前计划需求量',
    ],
    [
      for (var i = 0; i < stocks.length; i++)
        [
          '${i + 1}',
          stocks[i].parentInput.name,
          _original(
            stocks[i].parentInput.storageConc,
            stocks[i].parentInput.storageUnit,
          ),
          formatPlanNumber(stocks[i].dilutionFactor),
          _original(stocks[i].workingConcentration, stocks[i].workingUnit),
          formatPlanVolume(stocks[i].parentVolumeMl),
          stocks[i].diluentName,
          formatPlanVolume(stocks[i].diluentVolumeMl),
          formatPlanVolume(stocks[i].preparationVolumeMl),
          formatPlanVolume(stocks[i].requiredVolumeMl),
          formatPlanVolume(currentRequired[stocks[i].slot] ?? 0),
        ],
    ],
  );
  for (final stock in stocks) {
    final required = currentRequired[stock.slot] ?? 0;
    if (required > stock.preparationVolumeMl * (1 + 1e-9)) {
      out.writeln(
        '**原配制量不足**：${escapeMarkdownCell(stock.parentInput.name)} 当前计划需 ${formatPlanVolume(required)}，原方案仅配制 ${formatPlanVolume(stock.preparationVolumeMl)}。请重新核对备液量；软件未自动扩大原配制方案。\n',
      );
    }
  }
  out.writeln('稀释会改变 DMSO 等溶剂组成；请核对所选稀释液、缓冲体系与试剂兼容性。\n');
}

void _table(StringBuffer out, List<String> headers, List<List<String>> rows) {
  String line(List<String> cells) =>
      '| ${cells.map(escapeMarkdownCell).join(' | ')} |';
  out.writeln(line(headers));
  out.writeln('| ${List.filled(headers.length, '---').join(' | ')} |');
  for (final row in rows) {
    assert(row.length == headers.length);
    out.writeln(line(row));
  }
  out.writeln();
}

String _role(int slot) => slot == 0 ? '主底物' : '副底物$slot';
String _original(String value, String unit) =>
    value.isEmpty ? '未填（$unit）' : '$value $unit';

/// A label cannot terminate a row, inject HTML, or introduce a Markdown link.
String escapeMarkdownCell(String value) => value
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('\\', '&#92;')
    .replaceAll('|', '&#124;')
    .replaceAll('`', '&#96;')
    .replaceAll('[', '&#91;')
    .replaceAll(']', '&#93;')
    .replaceAll('*', '&#42;')
    .replaceAll('_', '&#95;')
    .replaceAll('~', '&#126;')
    .replaceAll(RegExp(r'\r\n|\r|\n'), '<br>')
    .replaceAll(RegExp(r'[\x00-\x08\x0B\x0C\x0E-\x1F\x7F]'), '');

/// Ten significant figures retain useful numeric detail without letting display
/// precision leak back into any calculation. Nonzero values never become zero.
String formatPlanNumber(double value) {
  if (!value.isFinite) throw ArgumentError('不能导出非有限数值。');
  if (value == 0) return '0';
  final text = value.toStringAsPrecision(10);
  final parts = text.split('e');
  var mantissa = parts.first;
  if (mantissa.contains('.')) {
    mantissa = mantissa
        .replaceFirst(RegExp(r'0+$'), '')
        .replaceFirst(RegExp(r'\.$'), '');
  }
  return parts.length == 1 ? mantissa : '${mantissa}e${parts.last}';
}

String formatPlanVolume(double value) => _scaled(value, [
  (1000, 'L'),
  (1, 'mL'),
  (0.001, 'µL'),
  (0.000001, 'nL'),
  (0.000000001, 'pL'),
], zeroUnit: 'µL');
String formatPlanMolar(double? value) => value == null
    ? '无法换算（缺少分子量）'
    : _scaled(value, [
        (1000, 'M'),
        (1, 'mM'),
        (0.001, 'µM'),
        (0.000001, 'nM'),
        (0.000000001, 'pM'),
      ], zeroUnit: 'mM');
String formatPlanMass(double? value) => value == null
    ? '无法换算（缺少分子量）'
    : _scaled(value, [
        (1000, 'g/mL'),
        (1, 'mg/mL'),
        (0.001, 'µg/mL'),
        (0.000001, 'ng/mL'),
        (0.000000001, 'pg/mL'),
      ], zeroUnit: 'mg/mL');
String _scaled(
  double value,
  List<(double, String)> units, {
  required String zeroUnit,
}) {
  if (value == 0) return '0 $zeroUnit';
  final unit = units.firstWhere(
    (u) => value.abs() >= u.$1,
    orElse: () => units.last,
  );
  return '${formatPlanNumber(value / unit.$1)} ${unit.$2}';
}
