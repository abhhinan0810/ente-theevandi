import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import '../models/train.dart';
import '../models/coach.dart';
import '../services/api_service.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';

class StudentSimulationScreen extends StatefulWidget {
  const StudentSimulationScreen({super.key});

  @override
  State<StudentSimulationScreen> createState() => _StudentSimulationScreenState();
}

class _StudentSimulationScreenState extends State<StudentSimulationScreen> {
  List<TrainModel> _trains = [];
  TrainModel? _selectedTrain;
  List<CoachModel> _trainCoaches = [];
  bool _isLoading = true;

  // Simulation Parameters
  String _selectedStation = 'Chengannur';
  final int _selectedPlatform = 2;
  double _platformOffsetMeters = 85.0; // Distance from front of train stop marker
  bool _isBoarded = false;
  CoachModel? _estimatedCoach;
  double _confidence = 0.94;

  // Departure & 1-minute countdown
  bool _hasDeparted = false;
  Timer? _countdownTimer;
  int _secondsRemaining = 60; // 1 minute as requested
  bool _showVotePrompt = false;
  String? _selectedCrowdVote;
  bool _isSubmitting = false;
  String? _feedbackMessage;

  // Anchor Passenger Kinematics State
  List<dynamic> _anchorPassengers = [];
  Timer? _anchorRefreshTimer;
  int _anchorRefreshCountdown = 30;

  // In-train movement test
  int _inTrainCoachSeq = 3; // Initially GS2 / Coach 3

  @override
  void initState() {
    super.initState();
    _selectedStation = UserSession().currentStationNameOnly;
    _platformOffsetMeters = UserSession().distanceFromFrontMeters;
    _loadInitialData();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _anchorRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    try {
      final trains = await ApiService().getTrains();
      setState(() {
        _trains = trains;
        if (trains.isNotEmpty) {
          _selectedTrain = trains.firstWhere(
            (t) => t.number == '16302',
            orElse: () => trains.first,
          );
        }
      });
      if (_selectedTrain != null) {
        await _fetchCoachesForTrain(_selectedTrain!.id);
        _fetchAnchors(_selectedTrain!.id);
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchCoachesForTrain(int trainId) async {
    try {
      final coaches = await ApiService().getTrainCoaches(trainId);
      if (mounted) {
        setState(() {
          _trainCoaches = coaches;
          _recalculateEstimatedCoach();
        });
      }
    } catch (_) {}
  }

  Future<void> _fetchAnchors(int trainId, {bool force = false}) async {
    try {
      final res = await ApiService().getTrainAnchors(trainId, force: force);
      if (mounted) {
        setState(() {
          _anchorPassengers = (res['data']?['anchors'] as List<dynamic>?) ?? [];
          _anchorRefreshCountdown = 30;
        });
      }
    } catch (_) {}
  }

  void _startAnchorTimer() {
    _anchorRefreshTimer?.cancel();
    _anchorRefreshTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_anchorRefreshCountdown <= 1) {
        if (_selectedTrain != null) _fetchAnchors(_selectedTrain!.id, force: true);
        setState(() => _anchorRefreshCountdown = 30);
      } else {
        setState(() => _anchorRefreshCountdown--);
      }
    });
  }

  void _recalculateEstimatedCoach() {
    if (_trainCoaches.isEmpty) {
      _estimatedCoach = null;
      return;
    }

    // Standard ICF/LHB coach length is 25 meters
    const coachLength = 25.0;
    int index = (_platformOffsetMeters / coachLength).floor();
    if (index >= _trainCoaches.length) {
      index = _trainCoaches.length - 1;
    }
    if (index < 0) index = 0;

    _estimatedCoach = _trainCoaches[index];
    _inTrainCoachSeq = index + 1;

    // Compute realistic GPS confidence score (peaks when near center of coach)
    double distIntoCoach = _platformOffsetMeters % coachLength;
    double distFromCenter = (distIntoCoach - 12.5).abs();
    _confidence = max(0.68, min(0.98, 0.98 - (distFromCenter / 12.5) * 0.28));
  }

  void _boardTrain() {
    setState(() {
      _isBoarded = true;
    });
    if (_selectedTrain != null) {
      UserSession().boardTrain(
        trainId: _selectedTrain!.id,
        trainNumber: _selectedTrain!.number,
        trainName: _selectedTrain!.name,
      );
      _startAnchorTimer();
    }
  }

  void _triggerDeparture() {
    setState(() {
      _hasDeparted = true;
      _secondsRemaining = 60; // 1 minute
      _showVotePrompt = false;
    });

    if (_selectedTrain != null) {
      UserSession().setTrainDeparted();
      ApiService().simulateDeparture(_selectedTrain!.id, stationName: _selectedStation);
    }

    // Start 60-second countdown
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsRemaining <= 1) {
        t.cancel();
        setState(() {
          _secondsRemaining = 0;
          _showVotePrompt = true;
        });
      } else {
        setState(() {
          _secondsRemaining--;
        });
      }
    });
  }

  void _skipTimerAndVoteNow() {
    _countdownTimer?.cancel();
    setState(() {
      _secondsRemaining = 0;
      _showVotePrompt = true;
    });
  }

  // Simulate in-train movement between compartments
  void _moveInTrain(String direction) {
    if (_trainCoaches.isEmpty) return;
    setState(() {
      if (direction == 'FORWARD' && _inTrainCoachSeq > 1) {
        _inTrainCoachSeq--;
      } else if (direction == 'REARWARD' && _inTrainCoachSeq < _trainCoaches.length) {
        _inTrainCoachSeq++;
      }
      _estimatedCoach = _trainCoaches[_inTrainCoachSeq - 1];
      _platformOffsetMeters = (_inTrainCoachSeq - 1) * 25.0 + 12.5;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('🚶 Movement detected! Moved $direction relative to anchor passengers -> Now in ${_estimatedCoach?.code}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _submitCrowdReport(String level) async {
    if (_estimatedCoach == null) return;
    setState(() {
      _isSubmitting = true;
      _selectedCrowdVote = level;
      _feedbackMessage = null;
    });

    try {
      final res = await ApiService().submitCrowdReport(
        coachId: _estimatedCoach!.id,
        stationName: _selectedStation,
        level: level,
      );

      UserSession().recordVote(level);

      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _feedbackMessage = res['message'] ?? 'Crowd report recorded in database for ${_estimatedCoach?.code}!';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _feedbackMessage = 'Error submitting report: ${e.toString().replaceAll('Exception: ', '')}';
        });
      }
    }
  }

  void _resetSimulation() {
    _countdownTimer?.cancel();
    _anchorRefreshTimer?.cancel();
    setState(() {
      _isBoarded = false;
      _hasDeparted = false;
      _secondsRemaining = 60;
      _showVotePrompt = false;
      _selectedCrowdVote = null;
      _feedbackMessage = null;
      _platformOffsetMeters = 85.0;
      _recalculateEstimatedCoach();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Viva Demo Simulator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Reset Demo Flow',
            onPressed: _resetSimulation,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Academic Viva Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primary, width: 1.5),
                  ),
                  child: const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('🎓', style: TextStyle(fontSize: 24)),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'COLLEGE PROJECT VIVA SIMULATION CONSOLE',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF67E8F9),
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Demonstrates coordinate-based compartment division, anchor passenger kinematics (30s refresh), simultaneous departure detection, in-train movement, and 1-minute post-departure crowdsourced voting.',
                              style: TextStyle(fontSize: 11, color: Colors.white70, height: 1.4),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ── STEP 1: Train & Platform Configuration ──
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.primary,
                              child: Text('1', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            SizedBox(width: 8),
                            Text('Select Train & Station Platform', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const Divider(height: 20),

                        // Station & Platform info
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('STATION', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w700)),
                                  const SizedBox(height: 2),
                                  Text('$_selectedStation (CNGR)', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Platform $_selectedPlatform',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Train dropdown
                        const Text('TESTING TRAIN', style: TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<TrainModel>(
                              isExpanded: true,
                              value: _selectedTrain,
                              items: _trains.map((t) {
                                return DropdownMenuItem(
                                  value: t,
                                  child: Text('${t.number} - ${t.name} (${t.coachCount} coaches)', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                                );
                              }).toList(),
                              onChanged: (newTrain) {
                                if (newTrain != null) {
                                  setState(() {
                                    _selectedTrain = newTrain;
                                    _resetSimulation();
                                  });
                                  _fetchCoachesForTrain(newTrain.id);
                                  _fetchAnchors(newTrain.id);
                                }
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── STEP 2: Platform Distance & Coach Division ──
                Card(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            CircleAvatar(
                              radius: 12,
                              backgroundColor: AppColors.primary,
                              child: Text('2', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                            ),
                            SizedBox(width: 8),
                            Text('Platform Position & Coach Division', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Distance from front stop divides train into 25m coach parts. Example: 85m is in Compartment 3 (75m–100m).',
                          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                        ),
                        const SizedBox(height: 16),

                        // Slider
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Front (0m)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                            Text(
                              'Position: ${_platformOffsetMeters.round()} meters from front',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.primary),
                            ),
                            const Text('Rear (500m)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey)),
                          ],
                        ),
                        Slider(
                          value: _platformOffsetMeters,
                          min: 0,
                          max: 500,
                          divisions: 20,
                          label: '${_platformOffsetMeters.round()}m',
                          activeColor: AppColors.primary,
                          onChanged: _isBoarded
                              ? null
                              : (val) {
                                  setState(() {
                                    _platformOffsetMeters = val;
                                    _recalculateEstimatedCoach();
                                  });
                                },
                        ),

                        // Alignment Box
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _estimatedCoach?.isGeneral == true ? const Color(0xFFF0FDF4) : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _estimatedCoach?.isGeneral == true ? const Color(0xFF86EFAC) : const Color(0xFFCBD5E1),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: _estimatedCoach?.isGeneral == true ? const Color(0xFF16A34A) : const Color(0xFF475569),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Center(
                                  child: Text(
                                    _estimatedCoach?.code ?? '--',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 16),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Target Compartment: ${_estimatedCoach?.code ?? "None"}',
                                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
                                    ),
                                    Text(
                                      _estimatedCoach?.type ?? 'Unknown',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          'Boarding Probability: ${(_confidence * 100).round()}%',
                                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Color(0xFF047857)),
                                        ),
                                        if (_estimatedCoach?.isGeneral == true) ...[
                                          const SizedBox(width: 8),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                            decoration: BoxDecoration(color: const Color(0xFFDCFCE7), borderRadius: BorderRadius.circular(4)),
                                            child: const Text('GENERAL UNRESERVED', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: Color(0xFF15803D))),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Boarding Action Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _isBoarded ? null : _boardTrain,
                            icon: Icon(_isBoarded ? Icons.check_circle_rounded : Icons.login_rounded),
                            label: Text(_isBoarded ? 'Boarded into ${_estimatedCoach?.code}' : 'Step Inside & Board Train'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // ── STEP 3: Anchor Passengers & Departure Kinematics ──
                if (_isBoarded) ...[
                  Card(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Row(
                                children: [
                                  CircleAvatar(
                                    radius: 12,
                                    backgroundColor: Color(0xFF0284C7),
                                    child: Text('3', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                                  ),
                                  SizedBox(width: 8),
                                  Text('Anchor Passengers & Movement', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFE0F2FE),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text('Refreshes in ${_anchorRefreshCountdown}s', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFF0284C7))),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          const Text(
                            'Random anchor passengers are distributed from front to rear. Train departure is detected instantly when all anchor passengers move simultaneously in route direction.',
                            style: TextStyle(fontSize: 11, color: Colors.black54),
                          ),
                          const SizedBox(height: 12),

                          // Anchor Passengers List
                          if (_anchorPassengers.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: const Color(0xFFE2E8F0)),
                              ),
                              child: Column(
                                children: _anchorPassengers.map((a) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 3),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text('👤 ${a["passenger_name"]} (${a["coach_code"]})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                                        Text('${a["role"]} • ${a["speed_kmh"]} km/h', style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          const SizedBox(height: 14),

                          // In-Train Movement Simulation Buttons
                          if (_hasDeparted) ...[
                            const Text('In-Train Movement (Relative to Anchor Passengers):', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _moveInTrain('FORWARD'),
                                    icon: const Icon(Icons.arrow_upward_rounded, size: 16),
                                    label: const Text('Move Forward', style: TextStyle(fontSize: 11)),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => _moveInTrain('REARWARD'),
                                    icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                                    label: const Text('Move Rearward', style: TextStyle(fontSize: 11)),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                          ],

                          // Departure Trigger
                          if (!_hasDeparted)
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                onPressed: _triggerDeparture,
                                icon: const Icon(Icons.departure_board_rounded),
                                label: const Text('Simulate Train Departure (Anchor Simultaneous Movement)'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFE11D48),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── STEP 4: 1-Minute Post-Departure Crowd Vote Notification ──
                  if (_hasDeparted)
                    Card(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 12,
                                      backgroundColor: Color(0xFFE11D48),
                                      child: Text('4', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)),
                                    ),
                                    SizedBox(width: 8),
                                    Text('1-Minute Post-Departure Vote Prompt', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
                                  ],
                                ),
                                if (_secondsRemaining > 0)
                                  TextButton(
                                    onPressed: _skipTimerAndVoteNow,
                                    child: const Text('⚡ Skip Timer', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFE11D48))),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),

                            if (!_showVotePrompt && _secondsRemaining > 0) ...[
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF1F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: const Color(0xFFFECDD3)),
                                ),
                                child: Row(
                                  children: [
                                    const CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFE11D48)),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Notification due in $_secondsRemaining seconds...',
                                            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF9F1239)),
                                          ),
                                          const Text(
                                            'App waits 1 minute after train leaves station before prompting passenger for compartment crowd feedback.',
                                            style: TextStyle(fontSize: 11, color: Color(0xFFBE123C)),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ] else ...[
                              // Vote prompt is ready
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.amber.shade50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.amber.shade400, width: 1.5),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(Icons.notifications_active_rounded, color: Colors.amber, size: 24),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'How crowded is coach ${_estimatedCoach?.code}?',
                                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900, color: Color(0xFF78350F)),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      'Passenger aboard compartment $_inTrainCoachSeq (${_estimatedCoach?.code}). Please vote right now:',
                                      style: const TextStyle(fontSize: 11, color: Color(0xFF92400E)),
                                    ),
                                    const SizedBox(height: 16),

                                    // Three Vote Options
                                    Row(
                                      children: [
                                        Expanded(child: _buildVoteButton('Low', '🟢 Low\n(Seats free)', const Color(0xFF15803D))),
                                        const SizedBox(width: 8),
                                        Expanded(child: _buildVoteButton('Medium', '🟡 Medium\n(Standing)', const Color(0xFFD97706))),
                                        const SizedBox(width: 8),
                                        Expanded(child: _buildVoteButton('High', '🔴 High\n(Dense rush)', const Color(0xFFDC2626))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            if (_isSubmitting)
                              const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator())),

                            if (_feedbackMessage != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFECFDF5),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF10B981)),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Color(0xFF059669)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        _feedbackMessage!,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFF065F46)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 20),

                Center(
                  child: TextButton.icon(
                    onPressed: _resetSimulation,
                    icon: const Icon(Icons.replay_rounded),
                    label: const Text('Reset Demo Workflow'),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildVoteButton(String level, String label, Color color) {
    final isSelected = _selectedCrowdVote == level;
    return ElevatedButton(
      onPressed: _isSubmitting ? null : () => _submitCrowdReport(level),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? color : Colors.white,
        foregroundColor: isSelected ? Colors.white : color,
        side: BorderSide(color: color, width: 1.5),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, height: 1.3),
      ),
    );
  }
}
