import 'package:flutter/material.dart';
import '../models/train.dart';
import '../models/coach.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';
import '../widgets/crowd_badge.dart';
import '../widgets/report_modal.dart';

class CrowdScreen extends StatefulWidget {
  final TrainModel train;

  const CrowdScreen({super.key, required this.train});

  @override
  State<CrowdScreen> createState() => _CrowdScreenState();
}

class _CrowdScreenState extends State<CrowdScreen> {
  List<CoachModel> _coaches = [];
  bool _isLoading = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _fetchCoaches();
  }

  Future<void> _fetchCoaches() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final list = await ApiService().getTrainCoaches(widget.train.id);
      setState(() {
        _coaches = list;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Color _getCoachBlockColor(CoachModel coach) {
    if (!coach.isGeneral) {
      // Reserved coach block color
      return const Color(0xFF374151); // Sleek graphite
    }
    switch (coach.crowdLevel.toLowerCase()) {
      case 'low':
        return const Color(0xFF15803D); // Deep green
      case 'medium':
        return const Color(0xFFD97706); // Warm amber
      case 'high':
        return const Color(0xFFDC2626); // Strong crimson red
      default:
        return const Color(0xFF6B7280); // Neutral grey
    }
  }

  void _openReportModal(CoachModel coach) {
    ReportModal.show(
      context,
      coach: coach,
      stationName: 'Chengannur',
      onSubmitted: _fetchCoaches,
    );
  }

  @override
  Widget build(BuildContext context) {
    final generalCoaches = _coaches.where((c) => c.isGeneral).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.train.number} Compartments'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _fetchCoaches,
            tooltip: 'Refresh crowd status',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchCoaches,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // ── Train Info Header Card ──
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            '${widget.train.number} ${widget.train.name}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                          ),
                        ),
                        CrowdBadge(level: widget.train.expectedCrowd),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.train.origin} → ${widget.train.destination}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                    ),
                    const Divider(height: 20),
                    const Row(
                      children: [
                        Icon(Icons.touch_app_rounded, size: 16, color: AppColors.primary),
                        SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Tap any General Compartment (GS) to vote or report crowd level.',
                            style: TextStyle(fontSize: 12, color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // ── VISUAL COMPARTMENT ARRANGEMENT (BLOCKS ONE AFTER ANOTHER) ──
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Compartment Arrangement',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                Text(
                  '${_coaches.length} Compartments',
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Color indicates crowd level: Green (Low) • Amber (Medium) • Red (High)',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 12),

            // Visual Horizontal Train Blocks Track
            Container(
              height: 140,
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        // LOCOMOTIVE ENGINE BLOCK
                        Container(
                          width: 85,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0xFF475569), width: 1.5),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.train_rounded, color: Colors.white70, size: 32),
                              SizedBox(height: 4),
                              Text('LOCOMOTIVE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Colors.white70, letterSpacing: 0.5)),
                              Text('WAP-7', style: TextStyle(fontSize: 9, color: Colors.grey)),
                            ],
                          ),
                        ),

                        // COMPARTMENT BLOCKS
                        ..._coaches.map((c) => _buildCompartmentBlock(c)),

                        // TAIL GUARD BLOCK
                        Container(
                          width: 65,
                          margin: const EdgeInsets.only(left: 4),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: const Center(
                            child: Text(
                              'TAIL',
                              style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black45),
                            ),
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),

            // ── UNRESERVED GENERAL COMPARTMENTS DETAIL LIST ──
            const Text(
              'General Unreserved Compartments',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              'Primary focus of crowd monitoring. Tap any card below to submit a live report.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 10),

            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
            else if (_errorMsg != null)
              Card(
                color: Colors.red.shade50,
                child: Padding(padding: const EdgeInsets.all(16), child: Text('Error: $_errorMsg', style: const TextStyle(color: Colors.red))),
              )
            else
              ...generalCoaches.map((coach) => _buildGeneralCoachCard(coach)),

            const SizedBox(height: 16),

            // ── ALL OTHER COMPARTMENTS (RESERVED) ──
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                title: const Text(
                  'View Reserved Compartments (2S, CC, SL)',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.primary),
                ),
                children: _coaches.where((c) => !c.isGeneral).map((c) {
                  return Card(
                    margin: const EdgeInsets.only(bottom: 6),
                    color: Colors.grey.shade50,
                    child: ListTile(
                      leading: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(c.code, style: const TextStyle(fontWeight: FontWeight.w800)),
                      ),
                      title: Text(c.type, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                      subtitle: Text('Sequence #${c.sequence} • Reserved Berth System', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Visual Block Component (Arranged horizontally)
  Widget _buildCompartmentBlock(CoachModel coach) {
    final isGeneral = coach.isGeneral;
    final blockColor = _getCoachBlockColor(coach);

    return InkWell(
      onTap: isGeneral ? () => _openReportModal(coach) : null,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 115,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: blockColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isGeneral ? Colors.white.withValues(alpha: 0.3) : Colors.transparent,
            width: isGeneral ? 2 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: blockColor.withValues(alpha: 0.35),
              blurRadius: 6,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Compartment Name on Top
            Column(
              children: [
                Text(
                  coach.code,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  coach.type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 9,
                    color: Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // Middle: Crowd Level Text
            if (isGeneral) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  coach.crowdLevel.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              Text(
                coach.reportsCount > 0 ? '${coach.reportsCount} votes' : 'Tap to vote',
                style: TextStyle(
                  fontSize: 9,
                  color: Colors.white.withValues(alpha: 0.8),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ] else ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'RESERVED',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w800,
                    color: Colors.white70,
                  ),
                ),
              ),
              const Text(
                'Charted',
                style: TextStyle(fontSize: 9, color: Colors.white60),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Detail Card for each general coach
  Widget _buildGeneralCoachCard(CoachModel coach) {
    final blockColor = _getCoachBlockColor(coach);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        onTap: () => _openReportModal(coach),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              // Colored Box
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: blockColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    coach.code,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(width: 14),

              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Compartment ${coach.code} (${coach.type})',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${coach.reportsCount} passenger reports • ${coach.freshness}',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Score: ${coach.crowdScore.toStringAsFixed(1)} / 3.0 • Confidence: ${coach.confidence}%',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary),
                    ),
                  ],
                ),
              ),

              // Button to report
              ElevatedButton(
                onPressed: () => _openReportModal(coach),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                ),
                child: const Text('Vote'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
