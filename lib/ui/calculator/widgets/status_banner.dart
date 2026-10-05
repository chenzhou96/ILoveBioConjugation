import 'package:flutter/material.dart';
import 'package:ilovebioconjugation/theme/app_colors.dart';
import 'package:ilovebioconjugation/ui/calculator/state.dart';

class StatusBanner extends StatelessWidget {
  final String message;
  final StatusLevel level;
  final String? detail;

  const StatusBanner({
    super.key,
    required this.message,
    required this.level,
    this.detail,
  });

  Color _bgColor(BuildContext context) => switch (level) {
    StatusLevel.success => AppColors.of(context).successBg,
    StatusLevel.warning => AppColors.of(context).warningBg,
    StatusLevel.error => AppColors.of(context).errorBg,
    StatusLevel.info => AppColors.of(context).infoBg,
  };

  Color _fgColor(BuildContext context) => switch (level) {
    StatusLevel.success => AppColors.of(context).successFg,
    StatusLevel.warning => AppColors.of(context).warningFg,
    StatusLevel.error => AppColors.of(context).errorFg,
    StatusLevel.info => AppColors.of(context).muted,
  };

  IconData get _icon => switch (level) {
    StatusLevel.success => Icons.check_circle_outline,
    StatusLevel.warning => Icons.warning_amber_outlined,
    StatusLevel.error => Icons.error_outline,
    StatusLevel.info => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _bgColor(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(_icon, size: 19, color: _fgColor(context)),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.5,
                    color: _fgColor(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                if (detail != null &&
                    detail!.isNotEmpty &&
                    detail != message) ...[
                  SizedBox(height: 8),
                  SelectableText(
                    detail!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: _fgColor(context),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
