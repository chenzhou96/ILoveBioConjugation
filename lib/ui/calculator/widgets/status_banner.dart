import 'package:flutter/material.dart';
import 'package:ilovebioconjunction/theme/app_colors.dart';
import 'package:ilovebioconjunction/ui/calculator/state.dart';

class StatusBanner extends StatelessWidget {
  final String message;
  final StatusLevel level;

  const StatusBanner({
    super.key,
    required this.message,
    required this.level,
  });

  Color get _bg => switch (level) {
    StatusLevel.info => AppColors.infoBg,
    StatusLevel.success => AppColors.successBg,
    StatusLevel.warning => AppColors.warningBg,
    StatusLevel.error => const Color(0xFFFEF2F2),
  };

  Color get _fg => switch (level) {
    StatusLevel.info => AppColors.text,
    StatusLevel.success => AppColors.successFg,
    StatusLevel.warning => AppColors.warningFg,
    StatusLevel.error => AppColors.errorFg,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(message, style: TextStyle(fontSize: 12, color: _fg)),
    );
  }
}
