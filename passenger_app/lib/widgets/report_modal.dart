import 'package:flutter/material.dart';
import '../models/coach.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class ReportModal extends StatefulWidget {
  final CoachModel coach;
  final String stationName;
  final VoidCallback onReportSubmitted;

  const ReportModal({
    super.key,
    required this.coach,
    this.stationName = 'Katpadi Junction',
    required this.onReportSubmitted,
  });

  static Future<void> show(
    BuildContext context, {
    required CoachModel coach,
    String stationName = 'Katpadi Junction',
    required VoidCallback onSubmitted,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReportModal(
        coach: coach,
        stationName: stationName,
        onReportSubmitted: onSubmitted,
      ),
    );
  }

  @override
  State<ReportModal> createState() => _ReportModalState();
}

class _ReportModalState extends State<ReportModal> {
  String? _selectedLevel;
  bool _isSubmitting = false;
  String? _errorMsg;

  final List<Map<String, dynamic>> _options = [
    {
      'level': 'Low',
      'label': 'LOW CROWD',
      'sub': 'Plenty of seats available, easy movement',
      'icon': Icons.sentiment_very_satisfied,
      'color': AppColors.crowdLow,
    },
    {
      'level': 'Medium',
      'label': 'MEDIUM CROWD',
      'sub': 'Seats occupied, reasonable standing space',
      'icon': Icons.sentiment_neutral,
      'color': AppColors.crowdMedium,
    },
    {
      'level': 'High',
      'label': 'HIGH CROWD',
      'sub': 'Heavily packed, difficult to board/move',
      'icon': Icons.sentiment_very_dissatisfied,
      'color': AppColors.crowdHigh,
    },
  ];

  Future<void> _submit() async {
    if (_selectedLevel == null) return;
    setState(() {
      _isSubmitting = true;
      _errorMsg = null;
    });

    try {
      await ApiService().submitCrowdReport(
        coachId: widget.coach.id,
        level: _selectedLevel!,
        stationName: widget.stationName,
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Thanks! Your report for ${widget.coach.code} was recorded.',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      widget.onReportSubmitted();
    } catch (e) {
      setState(() {
        _isSubmitting = false;
        _errorMsg = e.toString().replaceAll('Exception: ', '');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.rate_review, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Report Crowd: Coach ${widget.coach.code}',
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${widget.coach.type} • At ${widget.stationName}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const Text(
            'How crowded is this coach right now?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),

          // Options
          ..._options.map((opt) {
            final isSelected = _selectedLevel == opt['level'];
            final color = opt['color'] as Color;

            return GestureDetector(
              onTap: () => setState(() => _selectedLevel = opt['level'] as String),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected ? color.withValues(alpha: 0.08) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? color : Colors.grey.shade300,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(opt['icon'] as IconData, color: color, size: 28),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            opt['label'] as String,
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            opt['sub'] as String,
                            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                          ),
                        ],
                      ),
                    ),
                    if (isSelected)
                      Icon(Icons.check_circle, color: color, size: 22),
                  ],
                ),
              ),
            );
          }),

          if (_errorMsg != null) ...[
            const SizedBox(height: 6),
            Text(
              _errorMsg!,
              style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w500),
            ),
          ],

          const SizedBox(height: 16),

          // Submit Button
          ElevatedButton(
            onPressed: (_selectedLevel != null && !_isSubmitting) ? _submit : null,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              backgroundColor: AppColors.primary,
            ),
            child: _isSubmitting
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Submit Crowd Report', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
