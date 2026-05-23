import 'package:flutter/material.dart';
import 'package:ilovebioconjunction/theme/app_colors.dart';
import 'package:ilovebioconjunction/ui/calculator/state.dart';

class StatusBanner extends StatelessWidget {
  final String message;
  final StatusLevel level;

  const StatusBanner({super.key, required this.message, required this.level});

  Color get _bgColor => switch (level) {
    StatusLevel.success => AppColors.successBg,
    StatusLevel.warning => AppColors.warningBg,
    StatusLevel.error => const Color(0xFFFEF2F2),
    StatusLevel.info => AppColors.infoBg,
  };

  Color get _fgColor => switch (level) {
    StatusLevel.success => AppColors.successFg,
    StatusLevel.warning => AppColors.warningFg,
    StatusLevel.error => AppColors.errorFg,
    StatusLevel.info => AppColors.primary,
  };

  IconData get _icon => switch (level) {
    StatusLevel.success => Icons.check_circle_outline,
    StatusLevel.warning => Icons.warning_amber_outlined,
    StatusLevel.error => Icons.error_outline,
    StatusLevel.info => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: _bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _fgColor.withAlpha(30)),
      ),
      child: Row(
        children: [
          Icon(_icon, size: 16, color: _fgColor),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(fontSize: 12, color: _fgColor, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
