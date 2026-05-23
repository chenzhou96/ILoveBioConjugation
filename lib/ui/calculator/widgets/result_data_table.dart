import 'package:flutter/material.dart';
import 'package:ilovebioconjunction/theme/app_colors.dart';
import 'package:ilovebioconjunction/ui/calculator/state.dart';

class ResultDataTableWidget extends StatelessWidget {
  final List<ResultRow> rows;

  const ResultDataTableWidget({super.key, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('点击"运行计算"查看结果', style: TextStyle(fontSize: 12, color: AppColors.muted)),
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columnSpacing: 14,
        dataRowMinHeight: 34,
        headingRowHeight: 34,
        border: TableBorder(
          horizontalInside: BorderSide(color: AppColors.border.withAlpha(80)),
        ),
        columns: const [
          DataColumn(label: _ColHeader('角色')),
          DataColumn(label: _ColHeader('名称')),
          DataColumn(label: _ColHeader('母液浓度')),
          DataColumn(label: _ColHeader('终浓度')),
          DataColumn(label: _ColHeader('取样体积')),
          DataColumn(label: _ColHeader('体积占比')),
          DataColumn(label: _ColHeader('投料比')),
        ],
        rows: rows.map((r) => DataRow(cells: [
          DataCell(_CellText(r.role, bold: true)),
          DataCell(_CellText(r.name)),
          DataCell(_CellText(r.stock)),
          DataCell(_CellText(r.finalConc)),
          DataCell(_CellText(r.volume)),
          DataCell(_CellText(r.volumePct)),
          DataCell(_CellText(r.ratio)),
        ])).toList(),
      ),
    );
  }
}

class _ColHeader extends StatelessWidget {
  final String text;
  const _ColHeader(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.text));
  }
}

class _CellText extends StatelessWidget {
  final String text;
  final bool bold;
  const _CellText(this.text, {this.bold = false});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        fontSize: 11,
        fontWeight: bold ? FontWeight.w600 : FontWeight.normal,
        color: AppColors.text,
      ),
    );
  }
}
