import 'package:flutter/material.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/ui/calculator/state.dart';

class ResultDataTableWidget extends StatelessWidget {
  final List<ResultRow> rows;
  final bool compact;
  const ResultDataTableWidget({
    super.key,
    required this.rows,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (compact) {
      final colors = AppColors.of(context);
      if (rows.isEmpty) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 26),
          child: Center(
            child: Text(
              '填写已知条件，运行计算后生成取样清单',
              style: TextStyle(fontSize: 12, color: colors.muted),
            ),
          ),
        );
      }
      Widget cell(
        String text, {
        bool heading = false,
        bool emphasis = false,
        Key? key,
      }) => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: 10,
          vertical: heading ? 7 : 8,
        ),
        child: Tooltip(
          message: _display(text),
          child: Text(
            _display(text),
            key: key,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: heading ? 10 : 12,
              height: 1.25,
              fontWeight: emphasis ? FontWeight.w600 : FontWeight.w400,
              color: emphasis
                  ? colors.successFg
                  : heading
                  ? colors.muted
                  : colors.text,
            ),
          ),
        ),
      );
      return Table(
        key: const ValueKey('desktop-result-table'),
        columnWidths: const {
          0: FlexColumnWidth(1.4),
          1: FlexColumnWidth(1.3),
          2: FlexColumnWidth(1.3),
          3: FlexColumnWidth(),
          4: FlexColumnWidth(.8),
          5: FlexColumnWidth(.8),
        },
        defaultVerticalAlignment: TableCellVerticalAlignment.middle,
        border: TableBorder(horizontalInside: BorderSide(color: colors.border)),
        children: [
          TableRow(
            decoration: BoxDecoration(color: colors.surfaceSoft),
            children: [
              for (final label in ['底物', '母液浓度', '终浓度', '取样体积', '体积占比', '投料比'])
                cell(label, heading: true),
            ],
          ),
          for (var index = 0; index < rows.length; index++)
            TableRow(
              children: [
                cell(
                  '${rows[index].name} · ${rows[index].role}',
                  key: ValueKey('result-name-$index'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  child: _ConcentrationPair(
                    key: ValueKey('result-stock-$index'),
                    molar: rows[index].stock,
                    mass: rows[index].stockMass,
                    compact: true,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 3,
                  ),
                  child: _ConcentrationPair(
                    key: ValueKey('result-final-$index'),
                    molar: rows[index].finalConc,
                    mass: rows[index].finalConcMass,
                    compact: true,
                  ),
                ),
                cell(rows[index].volume, emphasis: true),
                cell(rows[index].volumePct),
                cell(rows[index].ratio),
              ],
            ),
        ],
      );
    }
    if (rows.isEmpty) {
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 38),
        child: Column(
          children: [
            Icon(
              Icons.science_outlined,
              size: 36,
              color: AppColors.of(context).muted,
            ),
            SizedBox(height: 18),
            Text(
              '准备好下一次反应',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
            SizedBox(height: 10),
            Text(
              '填写已知条件并运行计算\n这里会列出每种底物的取样量与补液量',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                height: 1.7,
                color: AppColors.of(context).muted,
              ),
            ),
          ],
        ),
      );
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 680 ||
            MediaQuery.textScalerOf(context).scale(1) > 1.2) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: List.generate(
              rows.length,
              (index) => Padding(
                padding: EdgeInsets.only(top: index == 0 ? 0 : 16),
                child: _AliquotCard(row: rows[index]),
              ),
            ),
          );
        }
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columnSpacing: 22,
            horizontalMargin: 12,
            headingRowHeight: 44,
            dataRowMinHeight: 52,
            dataRowMaxHeight: 72,
            border: TableBorder(
              horizontalInside: BorderSide(color: AppColors.of(context).border),
            ),
            columns: [
              DataColumn(label: Text('底物')),
              DataColumn(label: Text('母液浓度')),
              DataColumn(label: Text('终浓度')),
              DataColumn(label: Text('取样体积'), numeric: true),
              DataColumn(label: Text('体积占比'), numeric: true),
              DataColumn(label: Text('投料比'), numeric: true),
            ],
            rows: rows
                .map(
                  (row) => DataRow(
                    cells: [
                      DataCell(
                        Text(
                          '${row.name}\n${row.role}',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      DataCell(
                        _ConcentrationPair(
                          molar: row.stock,
                          mass: row.stockMass,
                        ),
                      ),
                      DataCell(
                        _ConcentrationPair(
                          molar: row.finalConc,
                          mass: row.finalConcMass,
                        ),
                      ),
                      DataCell(
                        Text(
                          _display(row.volume),
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      DataCell(Text(row.volumePct)),
                      DataCell(Text(row.ratio)),
                    ],
                  ),
                )
                .toList(),
          ),
        );
      },
    );
  }
}

String _display(String value) => value
    .replaceAll('uL', 'µL')
    .replaceAll('uM', 'µM')
    .replaceAll('ug/', 'µg/');

/// Both values come from the calculation state. Units alone are not enough to
/// identify an unavailable conversion, so each line names its basis explicitly.
class _ConcentrationPair extends StatelessWidget {
  final String molar;
  final String mass;
  final bool compact;

  const _ConcentrationPair({
    super.key,
    required this.molar,
    required this.mass,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [_line(context, '摩尔', molar), _line(context, '质量', mass)],
  );

  Widget _line(BuildContext context, String basis, String value) => Text(
    '$basis ${_display(value)}',
    style: TextStyle(
      fontSize: compact ? 11 : 12,
      height: compact ? 1.25 : 1.5,
      color: AppColors.of(context).text,
    ),
  );
}

class _AliquotCard extends StatelessWidget {
  final ResultRow row;
  const _AliquotCard({required this.row});

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.only(bottom: 16),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: AppColors.of(context).border)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.role,
          style: TextStyle(fontSize: 11, color: AppColors.of(context).muted),
        ),
        SizedBox(height: 5),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              row.name,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
            Text(
              '取 ${_display(row.volume)}',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: AppColors.of(context).successFg,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        Wrap(
          spacing: 20,
          runSpacing: 8,
          children: [
            _concentrationDetail(context, '母液浓度', row.stock, row.stockMass),
            _concentrationDetail(
              context,
              '终浓度',
              row.finalConc,
              row.finalConcMass,
            ),
            _detail(context, '体积占比', row.volumePct),
            _detail(context, '投料比', row.ratio),
          ],
        ),
      ],
    ),
  );

  Widget _concentrationDetail(
    BuildContext context,
    String label,
    String molar,
    String mass,
  ) => Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontSize: 11, color: AppColors.of(context).muted),
      ),
      const SizedBox(height: 3),
      _ConcentrationPair(molar: molar, mass: mass),
    ],
  );

  Widget _detail(BuildContext context, String label, String value) => Text.rich(
    TextSpan(
      children: [
        TextSpan(
          text: '$label  ',
          style: TextStyle(color: AppColors.of(context).muted),
        ),
        TextSpan(text: value),
      ],
    ),
    style: TextStyle(fontSize: 12),
  );
}
