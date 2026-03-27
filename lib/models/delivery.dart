import 'package:dadaroo/models/takeaway_type.dart';
import 'package:dadaroo/models/rating.dart';

class GpsPoint {
  final double latitude;
  final double longitude;
  final DateTime timestamp;

  GpsPoint({
    required this.latitude,
    required this.longitude,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() => {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': timestamp.toIso8601String(),
      };

  factory GpsPoint.fromMap(Map<String, dynamic> map) => GpsPoint(
        latitude: (map['latitude'] ?? 0.0).toDouble(),
        longitude: (map['longitude'] ?? 0.0).toDouble(),
        timestamp: map['timestamp'] != null
            ? DateTime.parse(map['timestamp'])
            : DateTime.now(),
      );
}

class Delivery {
  final String id;
  final String dadName;
  final String? dadUid;
  final String? familyGroupId;
  final TakeawayType takeawayType;
  final String? customTakeawayName;
  final DateTime startTime;
  final DateTime? arrivalTime;
  final Duration estimatedDuration;
  final Rating? rating;
  final bool isActive;
  final List<GpsPoint> gpsTrail;
  final double? currentLatitude;
  final double? currentLongitude;

  Delivery({
    required this.id,
    required this.dadName,
    this.dadUid,
    this.familyGroupId,
    required this.takeawayType,
    this.customTakeawayName,
    required this.startTime,
    this.arrivalTime,
    required this.estimatedDuration,
    this.rating,
    this.isActive = false,
    this.gpsTrail = const [],
    this.currentLatitude,
    this.currentLongitude,
  });

  String get takeawayDisplayName {
    if (takeawayType == TakeawayType.custom && customTakeawayName != null) {
      return customTakeawayName!;
    }
    return takeawayType.displayName;
  }

  String get takeawayEmoji => takeawayType.emoji;

  Duration? get actualDuration {
    if (arrivalTime == null) return null;
    return arrivalTime!.difference(startTime);
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'dadName': dadName,
      'dadUid': dadUid,
      'familyGroupId': familyGroupId,
      'takeawayType': takeawayType.name,
      'customTakeawayName': customTakeawayName,
      'startTime': startTime.toIso8601String(),
      'arrivalTime': arrivalTime?.toIso8601String(),
      'estimatedDurationSeconds': estimatedDuration.inSeconds,
      'rating': rating?.toMap(),
      'isActive': isActive,
      'gpsTrail': gpsTrail.map((p) => p.toMap()).toList(),
      'currentLatitude': currentLatitude,
      'currentLongitude': currentLongitude,
    };
  }

  factory Delivery.fromMap(Map<String, dynamic> map) {
    return Delivery(
      id: map['id'] ?? '',
      dadName: map['dadName'] ?? '',
      dadUid: map['dadUid'],
      familyGroupId: map['familyGroupId'],
      takeawayType: TakeawayType.values.firstWhere(
        (t) => t.name == map['takeawayType'],
        orElse: () => TakeawayType.other,
      ),
      customTakeawayName: map['customTakeawayName'],
      startTime: map['startTime'] != null
          ? DateTime.parse(map['startTime'])
          : DateTime.now(),
      arrivalTime: map['arrivalTime'] != null
          ? DateTime.parse(map['arrivalTime'])
          : null,
      estimatedDuration:
          Duration(seconds: map['estimatedDurationSeconds'] ?? 600),
      rating:
          map['rating'] != null ? Rating.fromMap(map['rating']) : null,
      isActive: map['isActive'] ?? false,
      gpsTrail: map['gpsTrail'] != null
          ? (map['gpsTrail'] as List)
              .map((p) => GpsPoint.fromMap(p))
              .toList()
          : [],
      currentLatitude: (map['currentLatitude'] as num?)?.toDouble(),
      currentLongitude: (map['currentLongitude'] as num?)?.toDouble(),
    );
  }

  Delivery copyWith({
    String? id,
    String? dadName,
    String? dadUid,
    String? familyGroupId,
    TakeawayType? takeawayType,
    String? customTakeawayName,
    DateTime? startTime,
    DateTime? arrivalTime,
    Duration? estimatedDuration,
    Rating? rating,
    bool? isActive,
    List<GpsPoint>? gpsTrail,
    double? currentLatitude,
    double? currentLongitude,
  }) {
    return Delivery(
      id: id ?? this.id,
      dadName: dadName ?? this.dadName,
      dadUid: dadUid ?? this.dadUid,
      familyGroupId: familyGroupId ?? this.familyGroupId,
      takeawayType: takeawayType ?? this.takeawayType,
      customTakeawayName: customTakeawayName ?? this.customTakeawayName,
      startTime: startTime ?? this.startTime,
      arrivalTime: arrivalTime ?? this.arrivalTime,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      rating: rating ?? this.rating,
      isActive: isActive ?? this.isActive,
      gpsTrail: gpsTrail ?? this.gpsTrail,
      currentLatitude: currentLatitude ?? this.currentLatitude,
      currentLongitude: currentLongitude ?? this.currentLongitude,
    );
  }
}
