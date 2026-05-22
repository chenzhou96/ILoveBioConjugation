import 'package:flutter/material.dart';
import 'package:ilovebioconjunction/theme/app_colors.dart';
import 'package:ilovebioconjunction/ui/calculator/state.dart';

class ResultMetricsRow extends StatelessWidget {
  final ResultMetrics metrics;

  const ResultMetricsRow({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetricCard(title: '最终反应体积', value: metrics.totalVolume),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _MetricCard(title: '母液总体积', value: metrics.stockVolume),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _MetricCard(title: '补加溶剂体积', value: metrics.diluentVolume),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: _MetricCard(title: '启用底物数量', value: metrics.substrateCount),
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;

  const _MetricCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppColors.metricBg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
