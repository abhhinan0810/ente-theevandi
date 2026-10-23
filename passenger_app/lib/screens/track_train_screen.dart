import 'dart:async';
import 'package:flutter/material.dart';
import '../models/train.dart';
import '../services/api_service.dart';
import '../theme/app_theme.dart';

class TrackTrainScreen extends StatefulWidget {
  final TrainModel? selectedTrain;

  const TrackTrainScreen({super.key, this.selectedTrain});

  @override
  State<TrackTrainScreen> createState() => _TrackTrainScreenState();
}

class _TrackTrainScreenState extends State<TrackTrainScreen> {
  List<TrainModel> _allTrains = [];
  TrainModel? _activeTrain;
  Map<String, dynamic>? _telemetry;
  bool _isLoading = true;
  String? _errorMsg;
  Timer? _autoRefreshTimer;

  final List<String> _demoWaypoints = [
    'Thiruvananthapuram Central (TVC)',
    'Kollam Junction (QLN)',
    'Kayamkulam Junction (KYJ)',
    'Mavelikara (MVLK)',
    'Chengannur (CNGR)',
    'Tiruvalla (TRVL)',
    'Changanassery (CGY)',
    'Kottayam (KTYM)',
    'Piravom Road (PVRD)',
    'Ernakulam Town (ERN)',
    'Aluva (AWY)',
    'Thrissur (TCR)',
    'Shoranur Junction (SRR)',
  ];

  @override
  void initState() {
    super.initState();
    _initTrainsAndTelemetry();
    // Auto refresh every 4 seconds to track simulated train movement
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (_activeTrain != null) _fetchTelemetry(_activeTrain!.id);
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initTrainsAndTelemetry() async {
    try {
      if (widget.selectedTrain != null) {
        _activeTrain = widget.selectedTrain;
      } else {
        final trains = await ApiService().getTrains();
        _allTrains = trains;
        if (trains.isNotEmpty) _activeTrain = trains.first;
      }
      if (_activeTrain != null) {
        await _fetchTelemetry(_activeTrain!.id);
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      setState(() {
        _errorMsg = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchTelemetry(int trainId) async {
    try {
      final res = await ApiService().getTrainPosition(trainId);
      if (mounted) {
        setState(() {
          _telemetry = res['location'] as Map<String, dynamic>?;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMsg = 'Could not fetch train position';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentStation = _telemetry?['current_station'] as String? ?? 'Chengannur (CNGR)';
    final nextStation = _telemetry?['next_station'] as String? ?? 'Tiruvalla (TRVL)';
    final speed = (_telemetry?['speed_kmh'] as num?)?.toDouble() ?? 68.0;
    final status = _telemetry?['status'] as String? ?? 'IN_TRANSIT';
    final lat = (_telemetry?['latitude'] as num?)?.toDouble() ?? 9.3178;
    final lng = (_telemetry?['longitude'] as num?)?.toDouble() ?? 76.6186;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Live Train Tracker', style: TextStyle(fontWeight: FontWeight.w900)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Simulated Notice Card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF1E1812),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFF4A341A)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.satellite_alt_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'SIMULATED LIVE TRAIN TELEMETRY',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Coordinates and speed are continuously updated by the simulator console in real time.',
                        style: TextStyle(fontSize: 11, color: Colors.grey.shade400, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Train Selection Card (if multiple)
          if (_allTrains.isNotEmpty)
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.cardBorder),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<TrainModel>(
                    isExpanded: true,
                    dropdownColor: AppColors.cardBg,
                    value: _activeTrain,
                    items: _allTrains.map((t) {
                      return DropdownMenuItem(
                        value: t,
                        child: Text('${t.number} - ${t.name}', style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 13)),
                      );
                    }).toList(),
                    onChanged: (newTrain) {
                      if (newTrain != null) {
                        setState(() {
                          _activeTrain = newTrain;
                          _isLoading = true;
                        });
                        _fetchTelemetry(newTrain.id);
                      }
                    },
                  ),
                ),
              ),
            ),
          if (_errorMsg != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFF241414),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF5A2222)),
              ),
              child: Text('Note: $_errorMsg', style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12, fontWeight: FontWeight.w600)),
            ),
          ],
          const SizedBox(height: 14),

          // Telemetry Gauge Card
          if (_isLoading)
            const Center(child: Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator(color: AppColors.primary)))
          else
            Container(
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.cardBorder, width: 1.2),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _activeTrain != null ? '${_activeTrain!.number} ${_activeTrain!.name}' : 'Express Train',
                                style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'Status: $status',
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.primary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.speed_rounded, size: 16, color: Colors.white),
                              const SizedBox(width: 5),
                              Text(
                                '${speed.round()} km/h',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w900, color: Colors.white),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 28, color: AppColors.cardBorder),

                    // Station Progress Row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('CURRENT STATION', style: TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text(currentStation, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_rounded, color: AppColors.primary, size: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Text('NEXT STOP', style: TextStyle(fontSize: 10, color: AppColors.textTertiary, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 3),
                              Text(nextStation, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Colors.white)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.cardBorder),
                      ),
                      child: Center(
                        child: Text(
                          'Simulated GPS: ${lat.toStringAsFixed(4)}, ${lng.toStringAsFixed(4)}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontFamily: 'monospace'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),

          // Route Waypoint Timeline (Where Is My Train style)
          const Text(
            'Route Corridor Stops',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.3),
          ),
          const SizedBox(height: 12),

          Container(
            decoration: BoxDecoration(
              color: AppColors.cardBg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.cardBorder, width: 1.2),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
              child: Column(
                children: _demoWaypoints.map((wp) {
                  final isCurrent = wp.toLowerCase().contains(currentStation.toLowerCase()) || currentStation.toLowerCase().contains(wp.toLowerCase());
                  final isNext = wp.toLowerCase().contains(nextStation.toLowerCase()) || nextStation.toLowerCase().contains(wp.toLowerCase());

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 7),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCurrent
                                ? AppColors.primary
                                : (isNext ? AppColors.primary.withValues(alpha: 0.4) : AppColors.surface),
                            border: Border.all(
                              color: isCurrent || isNext ? AppColors.primary : AppColors.cardBorder,
                              width: 1.5,
                            ),
                          ),
                          child: Icon(
                            isCurrent ? Icons.train_rounded : Icons.circle,
                            size: isCurrent ? 14 : 8,
                            color: isCurrent ? Colors.white : (isNext ? AppColors.primary : AppColors.textTertiary),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            wp,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: isCurrent ? FontWeight.w900 : (isNext ? FontWeight.w700 : FontWeight.w500),
                              color: isCurrent ? Colors.white : (isNext ? AppColors.primaryLight : AppColors.textSecondary),
                            ),
                          ),
                        ),
                        if (isCurrent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text('HERE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: Colors.white)),
                          )
                        else if (isNext)
                          const Text('NEXT', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.primary)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
