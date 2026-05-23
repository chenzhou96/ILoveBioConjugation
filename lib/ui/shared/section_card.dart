import 'package:flutter/material.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isMain;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;
  final Color? accentColor;

  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.isMain = false,
    this.padding = const EdgeInsets.all(12),
    this.trailing,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final barColor = accentColor ?? (isMain ? AppColors.mainRed : AppColors.primary);

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(6),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: const BorderRadius.only(
                topRight: Radius.circular(3),
                bottomRight: Radius.circular(3),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isMain ? AppColors.mainRed : AppColors.text,
                          ),
                        ),
                      ),
                      ?trailing,
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...children,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
