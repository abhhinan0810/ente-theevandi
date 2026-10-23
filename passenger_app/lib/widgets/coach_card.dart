import 'package:flutter/material.dart';
import '../models/coach.dart';
import '../theme/app_theme.dart';
import 'crowd_badge.dart';

class CoachCard extends StatelessWidget {
  final CoachModel coach;
  final VoidCallback onTap;

  const CoachCard({
    super.key,
    required this.coach,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isGeneral = coach.isGeneral;
    final color = AppTheme.getCrowdColor(coach.crowdLevel);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 124,
        margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isGeneral ? AppColors.primary : Colors.grey.shade300,
            width: isGeneral ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isGeneral
                  ? AppColors.primary.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.04),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Sequence badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '#${coach.sequence}',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (isGeneral)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                    decoration: BoxDecoration(
                      color: AppColors.generalBadgeBg,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'GEN',
                      style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        color: AppColors.generalBadgeText,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 6),

            // Coach Code
            Text(
              coach.code,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isGeneral ? AppColors.primary : Colors.black87,
              ),
            ),

            // Coach Type
            Text(
              coach.type,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 10),

            // Crowd status badge
            CrowdBadge(level: coach.crowdLevel, isSmall: true),
            const SizedBox(height: 6),

            // Confidence / Report Count
            Text(
              coach.reportsCount > 0
                  ? '${coach.confidence}% (${coach.reportsCount})'
                  : 'No reports',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: coach.reportsCount > 0 ? color : Colors.grey.shade500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
