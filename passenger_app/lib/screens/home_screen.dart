import 'dart:async';
import 'package:flutter/material.dart';
import '../models/train.dart';
import '../services/api_service.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';
import '../widgets/crowd_badge.dart';
import 'crowd_screen.dart';
import 'track_train_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<TrainModel> _allTrains = [];
  List<TrainModel> _filteredTrains = [];
  bool _isLoading = true;
  String? _errorMsg;

  // Route selector (Where Is My Train style)
  String _fromStation = 'Chengannur (CNGR)';
  String _toStation = 'Ernakulam Town (ERN)';

  final List<String> _stationList = [
    'Chengannur (CNGR)',
    'Kollam Junction (QLN)',
    'Kottayam (KTYM)',
    'Ernakulam Town (ERN)',
    'Tiruvalla (TRVL)',
    'Kayamkulam (KYJ)',
    'Thiruvananthapuram Central (TVC)',
    'All Stations',
  ];

  // Notification Timer for Post-Departure Crowd Vote (1 minute)
  Timer? _departureVoteTimer;
  int _secondsUntilVote = 0;
  bool _timerActive = false;

  @override
  void initState() {
    super.initState();
    _fetchTrains();
    UserSession().addListener(_onUserSessionChanged);
  }

  @override
  void dispose() {
    _departureVoteTimer?.cancel();
    UserSession().removeListener(_onUserSessionChanged);
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onUserSessionChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _fetchTrains() async {
    setState(() {
      _isLoading = true;
      _errorMsg = null;
    });

    try {
      final list = await ApiService().getTrains(search: _searchCtrl.text);
      _allTrains = list;
      _applyRouteFilter();
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() {
        _errorMsg = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  void _applyRouteFilter() {
    final search = _searchCtrl.text.toLowerCase().trim();
    final toKey = _toStation == 'All Stations' ? '' : _toStation.split('(').first.trim().toLowerCase();

    _filteredTrains = _allTrains.where((t) {
      if (search.isNotEmpty) {
        final matchesSearch = t.number.toLowerCase().contains(search) ||
            t.name.toLowerCase().contains(search) ||
            t.origin.toLowerCase().contains(search) ||
            t.destination.toLowerCase().contains(search);
        if (!matchesSearch) return false;
      }

      if (toKey.isNotEmpty) {
        final dest = t.destination.toLowerCase();
        final name = t.name.toLowerCase();
        if (toKey.contains('ernakulam')) {
          return dest.contains('ernakulam') || dest.contains('shoranur') || dest.contains('mangaluru') || dest.contains('new delhi') || name.contains('venad') || name.contains('parasuram');
        } else if (toKey.contains('kollam') || toKey.contains('thiruvananthapuram')) {
          return dest.contains('kollam') || dest.contains('thiruvananthapuram') || dest.contains('tvc') || dest.contains('kanyakumari');
        } else if (toKey.contains('kottayam')) {
          return dest.contains('kottayam') || dest.contains('ernakulam') || dest.contains('shoranur');
        }
      }
      return true;
    }).toList();
  }

  void _swapStations() {
    setState(() {
      final temp = _fromStation;
      _fromStation = _toStation;
      _toStation = temp;
      _applyRouteFilter();
    });
  }

  // --- HIDDEN DEMO / QUICK SELECTOR FEATURE ---
  void _openLocationOverrideSheet() {
    String tempStation = UserSession().currentStation;
    int tempPlatform = UserSession().currentPlatform;
    String tempCoach = UserSession().currentCoach;
    double tempDist = UserSession().distanceFromFrontMeters;

    final List<String> availableCoaches = [
      'ENG (0m)', 'GS1 (25m)', 'GS2 (50m)', 'GS3 (75m)', 'GS4 (100m)',
      'D1 (125m)', 'D2 (150m)', 'S1 (175m)', 'S2 (200m)'
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return Padding(
              padding: EdgeInsets.only(
                top: 20,
                left: 20,
                right: 20,
                bottom: MediaQuery.of(context).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.tune_rounded, color: AppColors.primary, size: 22),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Demo Location & Coach Selector',
                              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: Colors.white),
                            ),
                            Text(
                              'Set simulated station, platform, and coach for presentation',
                              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(height: 24, color: AppColors.cardBorder),

                  // Station Picker
                  const Text('CURRENT STATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      border: Border.all(color: AppColors.cardBorder),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        dropdownColor: AppColors.surface,
                        value: tempStation,
                        items: _stationList.where((s) => s != 'All Stations').map((s) {
                          return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setSheetState(() => tempStation = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Platform & Coach in row
                  Row(
                    children: [
                      // Platform Picker
                      Expanded(
                        flex: 1,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PLATFORM NO.', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                border: Border.all(color: AppColors.cardBorder),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  isExpanded: true,
                                  dropdownColor: AppColors.surface,
                                  value: tempPlatform,
                                  items: [1, 2, 3, 4].map((p) {
                                    return DropdownMenuItem(value: p, child: Text('Platform $p', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) setSheetState(() => tempPlatform = val);
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Coach Position Selector
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('COACH POSITION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14),
                              decoration: BoxDecoration(
                                color: AppColors.surface,
                                border: Border.all(color: AppColors.cardBorder),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  isExpanded: true,
                                  dropdownColor: AppColors.surface,
                                  value: availableCoaches.firstWhere((c) => c.startsWith(tempCoach), orElse: () => availableCoaches[2]),
                                  items: availableCoaches.map((c) {
                                    return DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      final code = val.split(' ').first;
                                      final distMatch = RegExp(r'\((.*?)m\)').firstMatch(val);
                                      final dist = double.tryParse(distMatch?.group(1) ?? '85.0') ?? 85.0;
                                      setSheetState(() {
                                        tempCoach = code;
                                        tempDist = dist;
                                      });
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Distance calculation preview
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.straighten_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'User is at ${tempDist.round()}m from Engine Front • Coach $tempCoach (Compartment ${(tempDist / 25).floor() + 1})',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primaryLight),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Apply button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        final compNo = (tempDist / 25).floor() + 1;
                        UserSession().updateLocation(
                          stationFullName: tempStation,
                          platform: tempPlatform,
                          coach: tempCoach,
                          compartmentNo: compNo,
                          distMeters: tempDist,
                          type: tempCoach.startsWith('GS') ? 'General Second (Unreserved)' : 'Reserved Coach',
                          isGeneral: tempCoach.startsWith('GS'),
                          probPercent: 96,
                        );

                        // Notify backend with new location coordinates
                        try {
                          await ApiService().estimateCoachPosition(
                            stationName: UserSession().currentStationNameOnly,
                            platformNumber: tempPlatform,
                            lat: 9.3178 + (tempDist / 111000.0),
                            lng: 76.6186 + (tempDist / 111000.0),
                            trainId: 2,
                          );
                        } catch (_) {}

                        if (context.mounted) Navigator.pop(ctx);
                        setState(() {
                          _fromStation = tempStation;
                          _applyRouteFilter();
                        });
                      },
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const Text('Apply Simulated Position', style: TextStyle(fontWeight: FontWeight.w800)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // --- TRAIN DEPARTURE & 1-MINUTE VOTE SIMULATION ---
  void _triggerSimulatedDeparture(TrainModel train) {
    UserSession().boardTrain(trainId: train.id, trainNumber: train.number, trainName: train.name);
    UserSession().setTrainDeparted();

    // Start 60-second countdown (1 minute)
    _departureVoteTimer?.cancel();
    setState(() {
      _secondsUntilVote = 60;
      _timerActive = true;
    });

    _departureVoteTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsUntilVote <= 1) {
        timer.cancel();
        setState(() {
          _timerActive = false;
          _secondsUntilVote = 0;
        });
        UserSession().triggerVoteNotification();
        _showCrowdVoteNotificationModal();
      } else {
        setState(() {
          _secondsUntilVote--;
        });
      }
    });

    // Notify backend
    ApiService().simulateDeparture(train.id, stationName: UserSession().currentStationNameOnly);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚀 ${train.name} departed! Vote prompt in 60s.'),
        backgroundColor: AppColors.cardBg,
        duration: const Duration(seconds: 4),
        action: SnackBarAction(
          label: 'VOTE NOW',
          textColor: AppColors.primary,
          onPressed: () {
            _departureVoteTimer?.cancel();
            setState(() => _timerActive = false);
            UserSession().triggerVoteNotification();
            _showCrowdVoteNotificationModal();
          },
        ),
      ),
    );
  }

  // Notification Popup where user submits vote directly
  void _showCrowdVoteNotificationModal() {
    final session = UserSession();
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.cardBg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.notifications_active_rounded, color: AppColors.primary, size: 28),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1-MIN POST-DEPARTURE PROMPT',
                          style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary, letterSpacing: 0.5),
                        ),
                        Text(
                          'How crowded is coach ${session.currentCoach}?',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Train departed 1 minute ago from ${session.currentStationNameOnly}. Please submit your live vote for compartment ${session.currentCoach} (Compartment ${session.currentCompartmentNumber}).',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),

              // Vote Options: Low, Medium, High
              Row(
                children: [
                  _buildVoteButton(ctx, 'Low', '🟢 Low', 'Empty / Seats Free', const Color(0xFF10B981), const Color(0xFF132A22)),
                  const SizedBox(width: 10),
                  _buildVoteButton(ctx, 'Medium', '🟡 Medium', 'Standing Room', const Color(0xFFF59E0B), const Color(0xFF2C2212)),
                  const SizedBox(width: 10),
                  _buildVoteButton(ctx, 'High', '🔴 High', 'Heavy Rush', const Color(0xFFEF4444), const Color(0xFF2E1616)),
                ],
              ),
              const SizedBox(height: 16),
              Center(
                child: TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Dismiss', style: TextStyle(color: AppColors.textTertiary)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildVoteButton(BuildContext ctx, String level, String label, String desc, Color primaryColor, Color bgColor) {
    return Expanded(
      child: InkWell(
        onTap: () async {
          Navigator.pop(ctx);
          await _submitCrowdVote(level);
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: primaryColor, width: 1.5),
          ),
          child: Column(
            children: [
              Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: primaryColor)),
              const SizedBox(height: 4),
              Text(desc, textAlign: TextAlign.center, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: primaryColor.withValues(alpha: 0.85))),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _submitCrowdVote(String level) async {
    final session = UserSession();
    try {
      int coachId = 2; // Default GS2
      final trainId = session.boardedTrainId ?? 2;
      final coaches = await ApiService().getTrainCoaches(trainId);
      final matched = coaches.firstWhere((c) => c.code == session.currentCoach, orElse: () => coaches.first);
      coachId = matched.id;

      await ApiService().submitCrowdReport(
        coachId: coachId,
        level: level,
        stationName: session.currentStationNameOnly,
      );

      session.recordVote(level);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Vote "$level" recorded for coach ${session.currentCoach}!'),
            backgroundColor: const Color(0xFF10B981),
          ),
        );
        _fetchTrains();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not record vote: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = UserSession();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(7),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.train_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Ente Theevandi',
                  style: TextStyle(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.3,
                  ),
                ),
                Text(
                  'Live Crowd & Coach Position',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: const [
          // Settings option removed from top nav bar as requested!
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _fetchTrains,
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ── TOP BANNER: "YOU'RE AT:" (Sleek Dark + Vibrant Orange Accents) ──
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder, width: 1.2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.location_on, color: AppColors.primary, size: 16),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "YOU'RE AT:",
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary,
                                letterSpacing: 0.8,
                              ),
                            ),
                          ],
                        ),
                        // Quick Demo Override Trigger
                        InkWell(
                          onTap: _openLocationOverrideSheet,
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: AppColors.cardBorder),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.tune_rounded, size: 12, color: AppColors.textSecondary),
                                SizedBox(width: 5),
                                Text('Change Demo Pos', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      session.currentStation,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.4),
                    ),
                    const SizedBox(height: 10),

                    // Platform & Coach Position details
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'Platform ${session.currentPlatform}',
                              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Coach ${session.currentCoach}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white),
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      '(${session.distanceFromFrontMeters.round()}m from front)',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Compartment ${session.currentCompartmentNumber} • ${session.coachType}',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Active Countdown banner if train departed
                    if (_timerActive) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.primary),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(
                              width: 14,
                              height: 14,
                              child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Train departed! Vote prompt in $_secondsUntilVote s...',
                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white),
                              ),
                            ),
                            TextButton(
                              onPressed: () {
                                _departureVoteTimer?.cancel();
                                setState(() => _timerActive = false);
                                _showCrowdVoteNotificationModal();
                              },
                              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(50, 24)),
                              child: const Text('VOTE NOW', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primaryLight)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),

            // ── FROM & TO DESTINATION SEARCH CARD (Matching Reference UI) ──
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder, width: 1.2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // From Station Input Block
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF10B981),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('From', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textTertiary)),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    dropdownColor: AppColors.cardBg,
                                    value: _fromStation,
                                    items: _stationList.where((s) => s != 'All Stations').map((s) {
                                      return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _fromStation = val);
                                        _applyRouteFilter();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Swap Button Divider (Matching circular white swap button from screenshot!)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Divider(color: AppColors.cardBorder),
                          InkWell(
                            onTap: _swapStations,
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: const Icon(Icons.swap_vert_rounded, size: 20, color: Colors.black),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // To Station Input Block
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('To', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.textTertiary)),
                                DropdownButtonHideUnderline(
                                  child: DropdownButton<String>(
                                    isExpanded: true,
                                    dropdownColor: AppColors.cardBg,
                                    value: _toStation,
                                    items: _stationList.map((s) {
                                      return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)));
                                    }).toList(),
                                    onChanged: (val) {
                                      if (val != null) {
                                        setState(() => _toStation = val);
                                        _applyRouteFilter();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Search box filter
                    TextField(
                      controller: _searchCtrl,
                      style: const TextStyle(color: Colors.white, fontSize: 13),
                      decoration: InputDecoration(
                        hintText: 'Search train number or name (e.g. 16302, Venad)...',
                        prefixIcon: const Icon(Icons.search, size: 20, color: AppColors.textSecondary),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18, color: AppColors.textSecondary),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  _applyRouteFilter();
                                },
                              )
                            : null,
                      ),
                      onChanged: (_) => _applyRouteFilter(),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Upcoming Trains Section Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Upcoming Trains on Platform',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3),
                    ),
                    Text(
                      'Direction: ${session.currentPlatform == 2 ? "North (Ernakulam)" : "South (Kollam)"}',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.cardBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.cardBorder),
                  ),
                  child: Text(
                    '${_filteredTrains.length} trains',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Trains List ──
            if (_isLoading)
              const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_errorMsg != null)
              _buildErrorCard()
            else if (_filteredTrains.isEmpty)
              _buildEmptyCard()
            else
              ..._filteredTrains.map((train) => _buildTrainCard(train)),
          ],
        ),
      ),
    );
  }

  Widget _buildTrainCard(TrainModel train) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top: Number & Crowd Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    train.number,
                    style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 13),
                  ),
                ),
                CrowdBadge(level: train.expectedCrowd),
              ],
            ),
            const SizedBox(height: 10),

            // Train Name
            Text(
              train.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3),
            ),
            const SizedBox(height: 6),

            // Origin -> Destination
            Row(
              children: [
                const Icon(Icons.alt_route_rounded, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${train.origin} → ${train.destination}',
                    style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.departure_board_rounded, size: 14, color: AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  'At ${UserSession().currentStationNameOnly}: Platform ${UserSession().currentPlatform} • ${train.coachCount} Compartments',
                  style: const TextStyle(fontSize: 11, color: AppColors.textTertiary, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Mini Rake Preview Strip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Row(
                children: [
                  const Text('Rake: ', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.textSecondary)),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildMiniCoachTag('ENG', false, isEngine: true),
                          _buildMiniCoachTag('GS1', true),
                          _buildMiniCoachTag('GS2', true),
                          _buildMiniCoachTag('D1', false),
                          _buildMiniCoachTag('D2', false),
                          _buildMiniCoachTag('CC1', false),
                          _buildMiniCoachTag('GS3', true),
                          _buildMiniCoachTag('GS4', true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${train.coachCount} coaches',
                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── THE TWO MAIN ACTION BUTTONS ──
            Row(
              children: [
                // 1. "Track Train" / "Check Location" -> Leads to simulated live location & path
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => TrackTrainScreen(selectedTrain: train)),
                      );
                    },
                    icon: const Icon(Icons.near_me_rounded, size: 17, color: Colors.white),
                    label: const Text('Track Train', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      side: const BorderSide(color: AppColors.cardBorder, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
                const SizedBox(width: 10),

                // 2. "View Crowd" -> Vibrant Electric Orange button matching screenshot!
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => CrowdScreen(train: train)),
                      ).then((_) => _fetchTrains());
                    },
                    icon: const Icon(Icons.grid_view_rounded, size: 17, color: Colors.white),
                    label: const Text('View Crowd', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Boarding & Departure simulation test button
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: () => _triggerSimulatedDeparture(train),
                icon: const Icon(Icons.departure_board_rounded, size: 15, color: AppColors.primaryLight),
                label: const Text('Simulate Boarding & Departure (Test 1-Min Vote)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primaryLight)),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMiniCoachTag(String code, bool isGeneral, {bool isEngine = false}) {
    Color bg = isEngine
        ? const Color(0xFF282E3D)
        : (isGeneral ? const Color(0xFF261E14) : const Color(0xFF1E2330));
    Color fg = isEngine
        ? Colors.white
        : (isGeneral ? AppColors.primaryLight : AppColors.textSecondary);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: isGeneral ? AppColors.primary.withValues(alpha: 0.3) : AppColors.cardBorder, width: 0.8),
      ),
      child: Text(
        code,
        style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }

  Widget _buildErrorCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF241414),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF5A2222)),
      ),
      child: Column(
        children: [
          const Icon(Icons.error_outline_rounded, color: Color(0xFFEF4444), size: 36),
          const SizedBox(height: 8),
          const Text('Could not load trains', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
          const SizedBox(height: 4),
          Text(_errorMsg!, textAlign: TextAlign.center, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _fetchTrains, child: const Text('Retry Connection')),
        ],
      ),
    );
  }

  Widget _buildEmptyCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: const Column(
        children: [
          Icon(Icons.train_outlined, color: AppColors.textTertiary, size: 48),
          SizedBox(height: 12),
          Text('No trains found for this route', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white)),
          SizedBox(height: 4),
          Text('Try selecting "All Stations" or clear search filter.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}
