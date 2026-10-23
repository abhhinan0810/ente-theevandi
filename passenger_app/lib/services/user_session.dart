import 'package:flutter/foundation.dart';

class UserSession with ChangeNotifier {
  static final UserSession _instance = UserSession._internal();
  factory UserSession() => _instance;
  UserSession._internal();

  // User Authentication State
  int? userId;
  String? userName;
  String? userContact;
  bool isLoggedIn = false;

  // Selected / Simulated Station and Platform State
  String currentStation = 'Chengannur (CNGR)';
  String currentStationCode = 'CNGR';
  String currentStationNameOnly = 'Chengannur';
  int currentPlatform = 2;

  // Coach Positioning State
  String currentCoach = 'GS2';
  int currentCompartmentNumber = 3;
  double distanceFromFrontMeters = 85.0; // 85m from engine -> within compartment 3 (75m-100m)
  String coachType = 'General Second (Unreserved)';
  bool isGeneralCoach = true;
  int probabilityPercent = 94;

  // Boarding & Departure State
  bool hasBoarded = false;
  int? boardedTrainId;
  String? boardedTrainNumber;
  String? boardedTrainName;
  bool isTrainDeparted = false;
  DateTime? departureTime;
  bool showVoteNotification = false;
  String? submittedVote;

  void setUser({required int id, required String name, required String contact}) {
    userId = id;
    userName = name;
    userContact = contact;
    isLoggedIn = true;
    notifyListeners();
  }

  void logout() {
    userId = null;
    userName = null;
    userContact = null;
    isLoggedIn = false;
    notifyListeners();
  }

  void updateLocation({
    required String stationFullName,
    required int platform,
    required String coach,
    required int compartmentNo,
    required double distMeters,
    String? type,
    bool? isGeneral,
    int? probPercent,
  }) {
    currentStation = stationFullName;
    // Extract code e.g. "Chengannur (CNGR)" -> "CNGR"
    final match = RegExp(r'\((.*?)\)').firstMatch(stationFullName);
    currentStationCode = match?.group(1) ?? 'CNGR';
    currentStationNameOnly = stationFullName.split('(').first.trim();
    currentPlatform = platform;
    currentCoach = coach;
    currentCompartmentNumber = compartmentNo;
    distanceFromFrontMeters = distMeters;
    if (type != null) coachType = type;
    if (isGeneral != null) isGeneralCoach = isGeneral;
    if (probPercent != null) probabilityPercent = probPercent;
    notifyListeners();
  }

  void boardTrain({required int trainId, required String trainNumber, required String trainName}) {
    hasBoarded = true;
    boardedTrainId = trainId;
    boardedTrainNumber = trainNumber;
    boardedTrainName = trainName;
    isTrainDeparted = false;
    showVoteNotification = false;
    submittedVote = null;
    notifyListeners();
  }

  void setTrainDeparted() {
    isTrainDeparted = true;
    departureTime = DateTime.now();
    notifyListeners();
  }

  void triggerVoteNotification() {
    showVoteNotification = true;
    notifyListeners();
  }

  void recordVote(String vote) {
    submittedVote = vote;
    showVoteNotification = false;
    notifyListeners();
  }

  void resetJourney() {
    hasBoarded = false;
    boardedTrainId = null;
    boardedTrainNumber = null;
    boardedTrainName = null;
    isTrainDeparted = false;
    departureTime = null;
    showVoteNotification = false;
    submittedVote = null;
    notifyListeners();
  }
}
