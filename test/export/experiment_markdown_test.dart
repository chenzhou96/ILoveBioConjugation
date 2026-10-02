import 'package:flutter_test/flutter_test.dart';
import 'package:ilovebioconjugation/core/planning.dart';
import 'package:ilovebioconjugation/data/calculation_input_snapshot.dart';
import 'package:ilovebioconjugation/export/experiment_markdown.dart';

SubstrateInputSnapshot reagent({
  String name = 'IgG',
  String mw = '000150.00',
  String mwUnit = 'kDa',
  String stock = '0010.000',
  String stockUnit = 'mg/mL',
  String finalConc = '1.0000',
  String finalUnit = 'mg/mL',
  String ratio = '1',
}) => SubstrateInputSnapshot(
  enabled: true,
  name: name,
  mw: mw,
  mwUnit: mwUnit,
  storageConc: stock,
  storageUnit: stockUnit,
  finalConc: finalConc,
  finalUnit: finalUnit,
  reactionRatio: ratio,
  storageVolume: '',
  storageVolumeUnit: 'uL',
);

CalculationInputSnapshot input({
  String name = 'IgG',
  List<WorkingStockProvenance> stocks = const [],
}) => CalculationInputSnapshot(
  reactionVolume: '0100.00',
  reactionVolumeUnit: 'uL',
  ratioType: true,
  substrates: [
    reagent(name: name),
    reagent(
      name: 'TCEP',
      mw: '286.65',
      mwUnit: 'Da',
      stock: '10',
      stockUnit: 'mM',
      finalConc: '',
      finalUnit: 'uM',
      ratio: '10',
    ),
  ],
  workingStocks: stocks,
);

void main() {
  test(
    'record omits all rejected metadata and preserves exact original units/text',
    () {
      final result = solveCalculation(input());
      final markdown = buildCalculationMarkdown(result);
      for (final label in ['实验标题', '日期', '方案编号', '备注', '软件版本', '计算规则版本']) {
        expect(markdown, isNot(contains(label)));
      }
      expect(markdown, contains('计划配方'));
      expect(markdown, contains('0100.00 uL'));
      expect(markdown, contains('000150.00 kDa'));
      expect(markdown, contains('0010.000 mg/mL'));
      expect(markdown, contains('1.0000 mg/mL'));
      expect(markdown, contains('未填（uM）'));
      expect(markdown, contains('未填（uL）'));
      expect(markdown, contains('投料比参照：IgG（主底物；归一为 1）'));
      expect(markdown, contains('实际取样量 | 观察'));
      final tcepResult = markdown
          .split('\n')
          .singleWhere(
            (line) =>
                line.startsWith('| 副底物1 | TCEP') &&
                line.contains('19.11 µg/mL'),
          );
      expect(tcepResult, endsWith('|  |  |'));
      expect(markdown, contains('最小移液量'));
    },
  );

  test('both concentration bases are exported from raw solver values', () {
    final markdown = buildCalculationMarkdown(solveCalculation(input()));
    expect(markdown, contains('2.8665 mg/mL'));
    expect(markdown, contains('66.66666667 µM'));
    expect(markdown, contains('19.11 µg/mL'));
    expect(markdown, contains('666.6666667 nL'));
    expect(markdown, isNot(contains('2.87 mg/mL')));
  });

  test('missing MW stays unavailable, never converted to zero', () {
    final original = CalculationInputSnapshot(
      reactionVolume: '100',
      reactionVolumeUnit: 'uL',
      ratioType: false,
      substrates: [reagent(mw: '', mwUnit: 'Da')],
    );
    final markdown = buildCalculationMarkdown(solveCalculation(original));
    expect(markdown, contains('无法换算（缺少分子量）'));
    expect(markdown, contains('10 mg/mL'));
    expect(markdown, contains('1 mg/mL'));
    expect(markdown, isNot(contains('0 mM')));
  });

  test('zero control and invalid groups remain in whole-batch export', () {
    final plan = generateGradient(
      solveCalculation(input()),
      GradientSpec(
        selectedSlot: 1,
        unit: 'eq',
        points: ['0', '5', 'broken', '10'],
        replicates: 2,
        extraPreparationFraction: 0.1,
      ),
    );
    final markdown = buildGradientMarkdown(plan);
    expect(markdown, contains('条件 1 · 0 eq'));
    expect(markdown, contains('条件 4 · 10 eq'));
    expect(markdown, contains('条件 3 · broken eq'));
    expect(markdown, contains('**不可执行**'));
    expect(markdown, contains('仅计入有效条件'));
    expect(markdown, contains('实际反应数：6'));
    expect(markdown, contains('额外配制：10%（仅汇总，单组配方不变）'));
    expect(markdown, contains('660 µL'));
    expect(markdown, contains('66 µL'));
    expect(markdown, contains('0 µL'));
    expect(markdown, isNot(contains('Infinity')));
    final short = buildGradientCopyText(plan);
    expect(short, contains('条件 4：10 eq'));
    expect(short, contains('条件 3：broken eq'));
    expect(short, contains('未计入 1 个不可执行条件'));
    expect(short, contains('投料比参照：IgG；摩尔比'));
    expect(short, contains('mg/mL'));
  });

  test('working-stock source and chosen diluent are retained in records', () {
    final original = input();
    final provenance = WorkingStockProvenance(
      slot: 1,
      parentInput: original.substrates[1],
      workingConcentration: '1',
      workingUnit: 'mM',
      dilutionFactor: 10,
      parentVolumeMl: 0.001,
      diluentVolumeMl: 0.009,
      preparationVolumeMl: 0.01,
      requiredVolumeMl: 0.00666666666667,
      newAliquotMl: 0.00666666666667,
      minimumVolumeMl: 0.001,
      diluentName: 'PBS',
    );
    final workingInput = CalculationInputSnapshot(
      reactionVolume: original.reactionVolume,
      reactionVolumeUnit: original.reactionVolumeUnit,
      ratioType: original.ratioType,
      workingStocks: [provenance],
      substrates: [
        original.substrates[0],
        reagent(
          name: 'TCEP',
          mw: '286.65',
          mwUnit: 'Da',
          stock: '1',
          stockUnit: 'mM',
          finalConc: '',
          finalUnit: 'uM',
          ratio: '10',
        ),
      ],
    );
    final markdown = buildCalculationMarkdown(solveCalculation(workingInput));
    expect(markdown, contains('已采用工作液'));
    expect(markdown, contains('10 mM | 10 | 1 mM'));
    expect(markdown, contains('1 µL | PBS | 9 µL | 10 µL'));
    expect(markdown, contains('DMSO'));
    expect(markdown, contains('兼容性'));
  });

  test('names cannot inject extra rows, links or HTML into Markdown', () {
    const name = 'A|B\n<script>[link](https://example.com)</script>`*';
    final markdown = buildCalculationMarkdown(
      solveCalculation(input(name: name)),
    );
    expect(markdown, contains('A&#124;B<br>&lt;script&gt;'));
    expect(markdown, isNot(contains('<script>')));
    expect(markdown, isNot(contains('[link]')));
    expect(markdown, isNot(contains('\n<script>')));
    expect(markdown, contains('&#96;&#42;'));
  });

  test(
    'adopted batch records identify the common working stock and recipe',
    () {
      final baseline = solveCalculation(input());
      final original = generateGradient(
        baseline,
        GradientSpec(
          selectedSlot: 1,
          unit: 'eq',
          points: ['0', '1', '2', '5'],
          replicates: 2,
          extraPreparationFraction: 0.1,
        ),
      );
      final advice = proposeGradientWorkingStock(
        original,
        slot: 1,
        minimumVolumeMl: 0.001,
        diluentName: 'PBS',
      );
      expect(advice.shared, isNotNull);
      final adopted = applyGradientWorkingStock(original, advice);
      final markdown = buildGradientMarkdown(adopted);
      expect(markdown, contains('梯度共同工作液（已采用）'));
      expect(markdown, contains('TCEP（共同工作液）'));
      expect(markdown, contains('批次需求量'));
      expect(markdown, contains('PBS'));
      expect(markdown, contains('191.1 µg/mL'));
      expect(markdown, contains('17.6 µL'));
      expect(markdown, contains('0 µL'));
      expect(buildGradientCopyText(adopted), contains('共同工作液 · TCEP'));
      expect(identical(adopted.baseline, baseline), isTrue);
      expect(baseline.input.substrates[1].storageConc, '10');
    },
  );

  test(
    'changed dose does not silently enlarge an adopted preparation record',
    () {
      final original = input();
      final recipe = WorkingStockProvenance(
        slot: 1,
        parentInput: original.substrates[1],
        workingConcentration: '1',
        workingUnit: 'mM',
        dilutionFactor: 10,
        parentVolumeMl: 0.001,
        diluentVolumeMl: 0.009,
        preparationVolumeMl: 0.01,
        requiredVolumeMl: 0.00666666666667,
        newAliquotMl: 0.00666666666667,
        minimumVolumeMl: 0.001,
        diluentName: 'PBS',
      );
      final changed = CalculationInputSnapshot(
        reactionVolume: '1000',
        reactionVolumeUnit: 'uL',
        ratioType: true,
        workingStocks: [recipe],
        substrates: [
          original.substrates[0],
          reagent(
            name: 'TCEP',
            mw: '286.65',
            mwUnit: 'Da',
            stock: '1',
            stockUnit: 'mM',
            finalConc: '',
            finalUnit: 'uM',
            ratio: '10',
          ),
        ],
      );
      final markdown = buildCalculationMarkdown(solveCalculation(changed));
      expect(markdown, contains('原采用配制量'));
      expect(markdown, contains('当前计划需求量'));
      expect(markdown, contains('原配制量不足'));
      expect(markdown, contains('原方案仅配制 10 µL'));
      expect(markdown, contains('当前计划需 66.66666667 µL'));
      expect(recipe.preparationVolumeMl, 0.01);
    },
  );

  test(
    'repeated serialization is deterministic and leaves inputs unchanged',
    () {
      final original = input();
      final json = original.toJson().toString();
      final result = solveCalculation(original);
      expect(
        buildCalculationMarkdown(result),
        buildCalculationMarkdown(result),
      );
      expect(original.toJson().toString(), json);
    },
  );

  test('formatting keeps tiny nonzero values and rejects non-finite data', () {
    expect(formatPlanVolume(1e-30), contains('e-21 pL'));
    expect(formatPlanMolar(1e-30), contains('e-21 pM'));
    expect(formatPlanMass(1e-30), contains('e-21 pg/mL'));
    expect(formatPlanNumber(0), '0');
    expect(formatPlanVolume(0), '0 µL');
    expect(() => formatPlanNumber(double.infinity), throwsArgumentError);
  });
}
