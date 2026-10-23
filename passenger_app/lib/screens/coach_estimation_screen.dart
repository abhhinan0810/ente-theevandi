import 'dart:math';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/user_session.dart';
import '../theme/app_theme.dart';

class CoachEstimationScreen extends StatefulWidget {
  const CoachEstimationScreen({super.key});

  @override
  State<CoachEstimationScreen> createState() => _CoachEstimationScreenState();
}

class _CoachEstimationScreenState extends State<CoachEstimationScreen> {
  String _selectedStation = 'Chengannur';
  int _selectedPlatform = 2;
  String _selectedTrainType = 'Express';

  // Front & Back coordinates of platform train stop
  double _frontLat = 9.3190;
  double _frontLng = 76.6198;
  double _backLat = 9.3147;
  double _backLng = 76.6164;

  // Passenger distance from front of train in meters
  double _distanceFromFrontMeters = 85.0; // 85m as mentioned in prompt
  bool _isEstimating = false;
  Map<String, dynamic>? _estimationResult;

  final List<String> _stationNames = [
    'Chengannur',
    'Kollam Junction',
    'Kottayam',
    'Ernakulam Town',
    'Thiruvananthapuram Central',
  ];

  final Map<String, double> _coachLengthsByModel = {
    'Express': 25.0,
    'Superfast': 25.0,
    'MEMU': 22.0,
    'Passenger': 24.0,
    'Vande Bharat': 23.5,
  };

  @override
  void initState() {
    super.initState();
    _selectedStation = UserSession().currentStationNameOnly;
    _selectedPlatform = UserSession().currentPlatform;
    _distanceFromFrontMeters = UserSession().distanceFromFrontMeters;
    _runEstimation();
  }

  Future<void> _runEstimation() async {
    setState(() {
      _isEstimating = true;
      _estimationResult = null;
    });

    try {
      final coachLen = _coachLengthsByModel[_selectedTrainType] ?? 25.0;
      final totalLen = coachLen * 20.0;
      final ratio = min(1.0, max(0.0, _distanceFromFrontMeters / totalLen));
      final pLat = _frontLat + ratio * (_backLat - _frontLat);
      final pLng = _frontLng + ratio * (_backLng - _frontLng);

      final res = await ApiService().estimateCoachPosition(
        stationName: _selectedStation,
        platformNumber: _selectedPlatform,
        lat: pLat,
        lng: pLng,
        trainId: 2,
        trainType: _selectedTrainType,
      );

      setState(() {
        _estimationResult = res;
        if (res['platform_geometry'] != null) {
          final geom = res['platform_geometry'] as Map<String, dynamic>;
          _frontLat = (geom['front_lat'] as num?)?.toDouble() ?? _frontLat;
          _frontLng = (geom['front_lng'] as num?)?.toDouble() ?? _frontLng;
          _backLat = (geom['back_lat'] as num?)?.toDouble() ?? _backLat;
          _backLng = (geom['back_lng'] as num?)?.toDouble() ?? _backLng;
        }
        _isEstimating = false;
      });
    } catch (e) {
      setState(() {
        _isEstimating = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Estimation failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final coachLen = _coachLengthsByModel[_selectedTrainType] ?? 25.0;
    const totalCoaches = 20;
    final totalTrainLength = coachLen * totalCoaches;

    // Derived Compartment index from distance from front
    final compartmentIndex = (_distanceFromFrontMeters / coachLen).floor() + 1;
    final clampedIndex = min(totalCoaches, max(1, compartmentIndex));
    final compStartM = (clampedIndex - 1) * coachLen;
    final compEndM = clampedIndex * coachLen;
    final compCenterM = (compStartM + compEndM) / 2.0;

    // High probability peak near compartment center
    final distFromCenter = (_distanceFromFrontMeters - compCenterM).abs();
    final halfLen = coachLen / 2.0;
    final probability = max(65, min(98, (98 - (distFromCenter / halfLen) * 32).round()));

    final estCoach = _estimationResult?['estimated_coach'] as String? ?? 'GS$clampedIndex';
    final coachType = _estimationResult?['coach_type'] as String? ?? (clampedIndex <= 3 ? 'General Second (Unreserved)' : 'Reserved Coach');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Coach GPS & Platform Division', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_isEstimating) const LinearProgressIndicator(color: AppColors.primary),
          // Banner explaining algorithm
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.cardBorder, width: 1.2),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.architecture_rounded, color: AppColors.primary, size: 26),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'PLATFORM COORDINATE DIVISION',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: 0.6,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Divides platform stop length into equal coach parts (e.g. 25m for Express). Measures passenger distance from front stop to determine compartment boarding probability.',
                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary, height: 1.4),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Station & Train Model Configuration Card
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
                  const Text('Platform & Train Model Configuration', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 14),

                  // Station Dropdown
                  const Text('STATION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textTertiary)),
                  const SizedBox(height: 5),
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
                        dropdownColor: AppColors.cardBg,
                        value: _selectedStation,
                        items: _stationNames.map((s) {
                          return DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)));
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedStation = val);
                            _runEstimation();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  Row(
                    children: [
                      // Platform Picker
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('PLATFORM', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textTertiary)),
                            const SizedBox(height: 5),
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
                                  dropdownColor: AppColors.cardBg,
                                  value: _selectedPlatform,
                                  items: [1, 2, 3, 4].map((p) {
                                    return DropdownMenuItem(value: p, child: Text('Platform $p', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Colors.white)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedPlatform = val);
                                      _runEstimation();
                                    }
                                  },
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Train Model Picker
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('TRAIN MODEL', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textTertiary)),
                            const SizedBox(height: 5),
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
                                  dropdownColor: AppColors.cardBg,
                                  value: _selectedTrainType,
                                  items: _coachLengthsByModel.keys.map((m) {
                                    return DropdownMenuItem(value: m, child: Text('$m (${_coachLengthsByModel[m]}m)', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Colors.white)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedTrainType = val);
                                      _runEstimation();
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

                  // Stop Coordinates Info Box
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.cardBorder),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Front: ${_frontLat.toStringAsFixed(4)}, ${_frontLng.toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w800, color: Colors.white)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
                              child: Text('${totalTrainLength.round()}m Total', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: AppColors.primary)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text('Back: ${_backLat.toStringAsFixed(4)}, ${_backLng.toStringAsFixed(4)}', style: const TextStyle(fontSize: 11, fontFamily: 'monospace', fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text('Division: $totalCoaches coaches × ${coachLen}m = ${totalTrainLength.round()}m along track', style: const TextStyle(fontSize: 11, color: AppColors.primaryLight, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // User Standing Distance Along Platform Slider
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
                  const Text('Simulate Distance from Front Coordinate', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text('Drag slider to change distance from front stop point:', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  const SizedBox(height: 14),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Front (0m)', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textTertiary)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
                        child: Text(
                          '${_distanceFromFrontMeters.round()}m from front',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w900, color: Colors.white),
                        ),
                      ),
                      Text('Rear (${totalTrainLength.round()}m)', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textTertiary)),
                    ],
                  ),

                  Slider(
                    value: _distanceFromFrontMeters,
                    min: 0,
                    max: totalTrainLength,
                    divisions: 20,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.surface,
                    label: '${_distanceFromFrontMeters.round()}m',
                    onChanged: (val) {
                      setState(() {
                        _distanceFromFrontMeters = val;
                      });
                      _runEstimation();
                    },
                  ),

                  // Probability and Compartment Result Card (Vibrant Orange & Dark UI)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.35), width: 1.2),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              estCoach,
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Compartment $clampedIndex ($estCoach)',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                              Text(
                                'Range: ${compStartM.round()}m to ${compEndM.round()}m from Engine',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryLight),
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(4)),
                                    child: Text(
                                      'Probability: $probability%',
                                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: AppColors.primaryLight),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      coachType,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Apply to session
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        UserSession().updateLocation(
                          stationFullName: '$_selectedStation (STN)',
                          platform: _selectedPlatform,
                          coach: estCoach,
                          compartmentNo: clampedIndex,
                          distMeters: _distanceFromFrontMeters,
                          type: coachType,
                          isGeneral: estCoach.startsWith('GS'),
                          probPercent: probability,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Position updated: $_selectedStation Platform $_selectedPlatform, Coach $estCoach'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      },
                      icon: const Icon(Icons.sync_rounded, color: Colors.white),
                      label: const Text('Sync Position with Homescreen Dashboard', style: TextStyle(fontWeight: FontWeight.w800, color: Colors.white)),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: AppColors.surface,
                        side: const BorderSide(color: AppColors.cardBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Visual Compartment Division Track Diagram
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
                  const Text('Platform Visual Compartment Map', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16, color: Colors.white)),
                  const SizedBox(height: 4),
                  const Text('Scroll horizontally to view all coach segments:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                  const SizedBox(height: 14),

                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: List.generate(totalCoaches, (i) {
                        final compNum = i + 1;
                        final isUserHere = compNum == clampedIndex;
                        final startM = i * coachLen;
                        final endM = (i + 1) * coachLen;
                        final code = i == 0 ? 'ENG' : (i <= 3 ? 'GS$i' : (i >= totalCoaches - 2 ? 'GS${i - 10}' : 'C$compNum'));

                        return Container(
                          width: 62,
                          margin: const EdgeInsets.only(right: 5),
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                          decoration: BoxDecoration(
                            color: isUserHere
                                ? AppColors.primary
                                : (i == 0 ? const Color(0xFF232A38) : AppColors.surface),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: isUserHere ? AppColors.primaryLight : AppColors.cardBorder,
                              width: isUserHere ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                code,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w900,
                                  color: isUserHere || i == 0 ? Colors.white : AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                '${startM.round()}-${endM.round()}m',
                                style: TextStyle(
                                  fontSize: 8,
                                  fontWeight: FontWeight.w600,
                                  color: isUserHere || i == 0 ? Colors.white70 : AppColors.textTertiary,
                                ),
                              ),
                              if (isUserHere) ...[
                                const SizedBox(height: 5),
                                const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 14),
                              ],
                            ],
                          ),
                        );
                      }),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
