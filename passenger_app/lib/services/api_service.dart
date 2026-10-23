import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/train.dart';
import '../models/coach.dart';

class ApiService {
  // Singleton instance
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // Configurable base URL: Defaults to local LAN IP or Android emulator address
  // Can be updated at runtime via Settings screen without rebuilding the app!
  String baseUrl = 'http://172.24.176.133:5000/api';

  void updateBaseUrl(String newUrl) {
    var sanitized = newUrl.trim();
    if (sanitized.endsWith('/')) {
      sanitized = sanitized.substring(0, sanitized.length - 1);
    }
    baseUrl = sanitized;
  }

  // Health check
  Future<bool> checkHealth() async {
    try {
      final res = await http.get(Uri.parse('$baseUrl/health')).timeout(const Duration(seconds: 4));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  // --- User Authentication ---
  Future<Map<String, dynamic>> login({required String name, required String phoneOrEmail}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'name': name.trim(),
        'phone_or_email': phoneOrEmail.trim(),
      }),
    ).timeout(const Duration(seconds: 6));

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode != 200) {
      throw Exception(data['message'] ?? 'Authentication failed');
    }
    return data;
  }

  // Fetch trains with optional search, origin, destination filters
  Future<List<TrainModel>> getTrains({String? search, String? from, String? to}) async {
    String endpoint = '$baseUrl/trains';
    List<String> queryParams = [];
    if (search != null && search.trim().isNotEmpty) {
      queryParams.add('search=${Uri.encodeComponent(search.trim())}');
    }
    if (from != null && from.trim().isNotEmpty) {
      queryParams.add('from=${Uri.encodeComponent(from.trim())}');
    }
    if (to != null && to.trim().isNotEmpty) {
      queryParams.add('to=${Uri.encodeComponent(to.trim())}');
    }
    if (queryParams.isNotEmpty) {
      endpoint += '?${queryParams.join('&')}';
    }

    final res = await http.get(Uri.parse(endpoint)).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) {
      throw Exception('Server error (${res.statusCode}): Failed to load trains');
    }
    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => TrainModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Fetch coaches and aggregated crowd for a train
  Future<List<CoachModel>> getTrainCoaches(int trainId, {bool generalOnly = false}) async {
    final endpoint = '$baseUrl/trains/$trainId/coaches?general_only=$generalOnly';
    final res = await http.get(Uri.parse(endpoint)).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) {
      throw Exception('Server error (${res.statusCode}): Failed to load coach formation');
    }
    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => CoachModel.fromJson(e as Map<String, dynamic>)).toList();
  }

  // Submit crowdsourced crowd report
  Future<Map<String, dynamic>> submitCrowdReport({
    required int coachId,
    required String level,
    String stationName = 'Chengannur',
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/crowd-reports'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'coach_id': coachId,
        'level': level,
        'station_name': stationName,
        'source': 'USER',
      }),
    ).timeout(const Duration(seconds: 6));

    if (res.statusCode != 201 && res.statusCode != 200) {
      final body = jsonDecode(res.body);
      throw Exception(body['message'] ?? 'Failed to submit report');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // Fetch train GPS position & telemetry
  Future<Map<String, dynamic>> getTrainPosition(int trainId) async {
    final res = await http.get(Uri.parse('$baseUrl/train-positions/$trainId')).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) {
      throw Exception('Failed to load train position');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // Estimate nearest coach based on platform front/back stop coordinates & user distance
  Future<Map<String, dynamic>> estimateCoachPosition({
    required String stationName,
    required int platformNumber,
    required double lat,
    required double lng,
    int? trainId,
    String? trainType,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/location/estimate-coach'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'station_name': stationName,
        'platform_number': platformNumber,
        'latitude': lat,
        'longitude': lng,
        'train_id': ?trainId,
        'train_type': ?trainType,
      }),
    ).timeout(const Duration(seconds: 6));

    if (res.statusCode != 200) {
      throw Exception('Failed to estimate coach position');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // Fetch all stations
  Future<List<Map<String, dynamic>>> getStations() async {
    final res = await http.get(Uri.parse('$baseUrl/stations')).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) {
      throw Exception('Failed to load stations');
    }
    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  // Fetch station stopping geometry
  Future<List<Map<String, dynamic>>> getStationStops(String stationName, {int? platform, String? trainType}) async {
    String endpoint = '$baseUrl/stations/$stationName/stops';
    List<String> queryParams = [];
    if (platform != null) queryParams.add('platform=$platform');
    if (trainType != null) queryParams.add('train_type=$trainType');
    if (queryParams.isNotEmpty) endpoint += '?${queryParams.join('&')}';

    final res = await http.get(Uri.parse(endpoint)).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) {
      throw Exception('Failed to load station stop coordinates');
    }
    final List<dynamic> data = jsonDecode(res.body);
    return data.map((e) => e as Map<String, dynamic>).toList();
  }

  // Fetch anchor passengers (refreshed every 30s)
  Future<Map<String, dynamic>> getTrainAnchors(int trainId, {bool force = false}) async {
    final endpoint = '$baseUrl/tracking/anchors/$trainId?force=$force';
    final res = await http.get(Uri.parse(endpoint)).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) {
      throw Exception('Failed to load anchor passengers');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // Trigger train departure
  Future<Map<String, dynamic>> simulateDeparture(int trainId, {String stationName = 'Chengannur', double speed = 45.0}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/tracking/simulate-departure'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'train_id': trainId,
        'station_name': stationName,
        'speed_kmh': speed,
      }),
    ).timeout(const Duration(seconds: 6));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // Check train departure status & vote notification countdown
  Future<Map<String, dynamic>> getDepartureStatus(int trainId) async {
    final res = await http.get(Uri.parse('$baseUrl/tracking/departure-status/$trainId')).timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) {
      throw Exception('Failed to check departure status');
    }
    return jsonDecode(res.body) as Map<String, dynamic>;
  }

  // Direct simulated train to user's station
  Future<Map<String, dynamic>> directTrain(int trainId, {String stationName = 'Chengannur'}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/simulation/direct-train'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'train_id': trainId,
        'station_name': stationName,
        'at_platform': true,
      }),
    ).timeout(const Duration(seconds: 6));
    return jsonDecode(res.body) as Map<String, dynamic>;
  }
}
