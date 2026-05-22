import 'package:flutter/material.dart';
import 'package:ilovebioconjunction/theme/app_colors.dart';
import 'package:ilovebioconjunction/ui/calculator/state.dart';

class ResultDataTableWidget extends StatelessWidget {
  final List<ResultRow> rows;

  const ResultDataTableWidget({super.key, required this.rows});

  static const _headers = ['类别', '名称', '母液浓度', '终浓度', '取样体积', '母液体积占比', '投料比'];

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Text(
          '点击"运行计算"查看结果',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 12,
        headingRowHeight: 32,
        dataRowMinHeight: 28,
        dataRowMaxHeight: 28,
        headingTextStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: AppColors.text,
        ),
        dataTextStyle: const TextStyle(fontSize: 11, color: AppColors.text),
        columns: _headers.map((h) => DataColumn(label: Text(h))).toList(),
        rows: rows.map((r) {
          final values = [
            r.role, r.name, r.stock, r.finalConc,
            r.volume, r.volumePct, r.ratio,
          ];
          return DataRow(
            cells: values
                .map((v) => DataCell(Text(v)))
                .toList(),
          );
        }).toList(),
      ),
    );
  }
}
