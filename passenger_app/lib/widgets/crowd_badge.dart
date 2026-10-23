import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class CrowdBadge extends StatelessWidget {
  final String level;
  final bool isSmall;

  const CrowdBadge({
    super.key,
    required this.level,
    this.isSmall = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.getCrowdColor(level);
    final text = level.toUpperCase();

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmall ? 8 : 12,
        vertical: isSmall ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4), width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isSmall ? 6 : 8,
            height: isSmall ? 6 : 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: isSmall ? 11 : 12,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
