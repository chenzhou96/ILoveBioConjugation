import 'package:flutter/material.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/ui/calculator/state.dart';

class ResultMetricsRow extends StatelessWidget {
  final ResultMetrics metrics;
  final bool compact;
  const ResultMetricsRow({
    super.key,
    required this.metrics,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columns = compact || constraints.maxWidth >= 700
          ? 4
          : (constraints.maxWidth >= 280 ? 2 : 1);
      final width = (constraints.maxWidth - (columns - 1) * 12) / columns;
      final entries = [
        ('最终反应体积', metrics.totalVolume, Icons.science_outlined),
        ('母液总体积', metrics.stockVolume, Icons.inventory_2_outlined),
        ('补加溶剂体积', metrics.diluentVolume, Icons.water_drop_outlined),
        ('参与反应底物', metrics.substrateCount, Icons.biotech_outlined),
      ];
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: List.generate(entries.length, (index) {
          final (label, value, icon) = entries[index];
          return Container(
            width: width,
            padding: EdgeInsets.all(compact ? 8 : 14),
            decoration: BoxDecoration(
              color: index == 2
                  ? AppColors.of(context).successBg
                  : AppColors.of(context).surface,
              border: Border.all(color: AppColors.of(context).border),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!compact)
                  Icon(
                    icon,
                    size: 19,
                    color: index == 2
                        ? AppColors.of(context).successFg
                        : AppColors.of(context).muted,
                  ),
                if (!compact) SizedBox(height: 10),
                Text(
                  value.replaceAll('uL', 'µL'),
                  style: TextStyle(
                    fontSize: compact ? 16 : 19,
                    height: 1.2,
                    fontWeight: FontWeight.w600,
                    color: index == 2
                        ? AppColors.of(context).successFg
                        : AppColors.of(context).text,
                  ),
                ),
                SizedBox(height: compact ? 3 : 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: compact ? 10 : 11,
                    color: AppColors.of(context).muted,
                  ),
                ),
              ],
            ),
          );
        }),
      );
    },
  );
}
