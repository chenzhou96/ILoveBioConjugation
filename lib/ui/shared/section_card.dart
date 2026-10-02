import 'package:flutter/material.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';

class SectionCard extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool isMain;
  final EdgeInsetsGeometry padding;
  final Widget? trailing;
  final Color? accentColor;
  final String? subtitle;

  const SectionCard({
    super.key,
    required this.title,
    required this.children,
    this.isMain = false,
    this.padding = const EdgeInsets.all(16),
    this.trailing,
    this.accentColor,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: AppColors.of(context).surface,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AppColors.of(context).border),
    ),
    padding: padding,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                  if (subtitle != null) ...[
                    SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[SizedBox(width: 8), trailing!],
          ],
        ),
        if (children.isNotEmpty) ...[SizedBox(height: 14), ...children],
      ],
    ),
  );
}
