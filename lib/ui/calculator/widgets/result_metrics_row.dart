import 'package:flutter/material.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/ui/calculator/state.dart';

class ResultMetricsRow extends StatelessWidget {
  final ResultMetrics metrics;

  const ResultMetricsRow({super.key, required this.metrics});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _MetricCard(
          icon: Icons.science_outlined,
          label: '最终反应体积',
          value: metrics.totalVolume,
          color: AppColors.primary,
        ),
        const SizedBox(width: 8),
        _MetricCard(
          icon: Icons.inventory_2_outlined,
          label: '母液总体积',
          value: metrics.stockVolume,
          color: AppColors.secondaryBlue,
        ),
        const SizedBox(width: 8),
        _MetricCard(
          icon: Icons.water_drop_outlined,
          label: '补加溶剂体积',
          value: metrics.diluentVolume,
          color: AppColors.success,
        ),
        const SizedBox(width: 8),
        _MetricCard(
          icon: Icons.biotech_outlined,
          label: '启用底物数量',
          value: metrics.substrateCount,
          color: AppColors.accent,
        ),
      ],
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MetricCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(height: 6),
            Text(
              value,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: color),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.muted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
