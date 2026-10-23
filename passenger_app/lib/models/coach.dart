class CoachModel {
  final int id;
  final int trainId;
  final String code;
  final String type;
  final int sequence;
  final bool isGeneral;
  final double distanceFromFront;
  final double lengthMeters;
  final String crowdLevel;
  final double crowdScore;
  final int reportsCount;
  final int confidence;
  final String freshness;

  CoachModel({
    required this.id,
    required this.trainId,
    required this.code,
    required this.type,
    required this.sequence,
    required this.isGeneral,
    required this.distanceFromFront,
    required this.lengthMeters,
    required this.crowdLevel,
    required this.crowdScore,
    required this.reportsCount,
    required this.confidence,
    required this.freshness,
  });

  factory CoachModel.fromJson(Map<String, dynamic> json) {
    return CoachModel(
      id: json['id'] as int? ?? 0,
      trainId: json['train_id'] as int? ?? 0,
      code: json['code'] as String? ?? 'N/A',
      type: json['type'] as String? ?? 'General',
      sequence: json['sequence'] as int? ?? 0,
      isGeneral: json['is_general'] as bool? ?? false,
      distanceFromFront: (json['distance_from_front'] as num?)?.toDouble() ?? 0.0,
      lengthMeters: (json['length_meters'] as num?)?.toDouble() ?? 24.0,
      crowdLevel: json['level'] as String? ?? 'Unknown',
      crowdScore: (json['score'] as num?)?.toDouble() ?? 0.0,
      reportsCount: json['reports'] as int? ?? 0,
      confidence: json['confidence'] as int? ?? 0,
      freshness: json['updated'] as String? ?? 'No reports',
    );
  }
}
