import 'package:dadaroo/models/takeaway_type.dart';
import 'package:dadaroo/models/rating.dart';
import 'package:dadaroo/models/delivery_stop.dart';

/// The overall lifecycle status of a delivery.
enum DeliveryStatus {
  arrivedAtRestaurant,
  orderPlaced,
  orderPreparing,
  orderCollected,
  onRoute,
  nearlyThere,
  delivered;

  String get displayName => switch (this) {
        arrivedAtRestaurant => 'Arrived at Restaurant',
        orderPlaced => 'Order Placed',
        orderPreparing => 'Order Being Prepared',
        orderCollected => 'Order Collected',
        onRoute => 'On Route',
        nearlyThere => 'Arrived!',
        delivered => 'Delivered',
      };

  String get emoji => switch (this) {
        arrivedAtRestaurant => '🏪',
        orderPlaced => '📋',
        orderPreparing => '👨‍🍳',
        orderCollected => '🛍️',
        onRoute => '🚗',
        nearlyThere => '📍',
        delivered => '✅',
      };

  String get familyMessage => switch (this) {
        arrivedAtRestaurant => 'just arrived at the restaurant!',
        orderPlaced => 'has placed the order!',
        orderPreparing => "'s order is being prepared...",
        orderCollected => 'has collected the food!',
        onRoute => 'is on the way home!',
        nearlyThere => 'has arrived!',
        delivered => 'has arrived with the food!',
      };

  /// Whether GPS tracking should be active for this status.
  bool get isTracking => this == onRoute || this == nearlyThere;

  /// Whether the delivery is still in progress (not yet delivered).
  bool get isInProgress => this != delivered;

  /// The next status in the flow, or null if delivered.
  DeliveryStatus? get next => switch (this) {
        arrivedAtRestaurant => orderPlaced,
        orderPlaced => orderPreparing,
        orderPreparing => orderCollected,
        orderCollected => onRoute,
        onRoute => nearlyThere,
        nearlyThere => delivered,
        delivered => null,
      };

  /// Progress value 0.0–1.0 through the status flow.
  double get progressValue => index / (DeliveryStatus.values.length - 1);
}

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
  final DeliveryStatus status;
  final List<DeliveryStop> stops;
  final int currentStopIndex;

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
    this.status = DeliveryStatus.arrivedAtRestaurant,
    this.stops = const [],
    this.currentStopIndex = 0,
  });

  bool get isMultiDrop => stops.length > 1;
  int get totalStops => stops.length;
  int get completedStops => stops.where((s) => s.isDelivered).length;
  double get stopsProgress =>
      stops.isEmpty ? 0.0 : completedStops / totalStops;
  DeliveryStop? get currentStop =>
      currentStopIndex < stops.length ? stops[currentStopIndex] : null;
  bool get allStopsDelivered => stops.isNotEmpty && completedStops == totalStops;

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
      'status': status.name,
      'stops': stops.map((s) => s.toMap()).toList(),
      'currentStopIndex': currentStopIndex,
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
      status: DeliveryStatus.values.firstWhere(
        (s) => s.name == map['status'],
        orElse: () => DeliveryStatus.arrivedAtRestaurant,
      ),
      stops: map['stops'] != null
          ? (map['stops'] as List)
              .map((s) => DeliveryStop.fromMap(s))
              .toList()
          : [],
      currentStopIndex: map['currentStopIndex'] ?? 0,
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
    DeliveryStatus? status,
    List<DeliveryStop>? stops,
    int? currentStopIndex,
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
      status: status ?? this.status,
      stops: stops ?? this.stops,
      currentStopIndex: currentStopIndex ?? this.currentStopIndex,
    );
  }
}
