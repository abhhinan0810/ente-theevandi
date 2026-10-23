class TrainModel {
  final int id;
  final String number;
  final String name;
  final String origin;
  final String destination;
  final double lengthMeters;
  final int coachCount;
  final String expectedCrowd;

  TrainModel({
    required this.id,
    required this.number,
    required this.name,
    required this.origin,
    required this.destination,
    this.lengthMeters = 450.0,
    this.coachCount = 0,
    this.expectedCrowd = 'Medium',
  });

  factory TrainModel.fromJson(Map<String, dynamic> json) {
    return TrainModel(
      id: json['id'] as int? ?? 0,
      number: json['number'] as String? ?? '',
      name: json['name'] as String? ?? '',
      origin: json['origin'] as String? ?? '',
      destination: json['destination'] as String? ?? '',
      lengthMeters: (json['length_meters'] as num?)?.toDouble() ?? 450.0,
      coachCount: json['coach_count'] as int? ?? 0,
      expectedCrowd: json['expected_crowd'] as String? ?? 'Medium',
    );
  }
}
