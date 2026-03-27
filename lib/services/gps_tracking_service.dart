import 'dart:async';
import 'dart:math';
import 'package:geolocator/geolocator.dart';
import 'package:dadaroo/services/firestore_service.dart';

class GpsTrackingService {
  final FirestoreService _firestoreService;
  StreamSubscription<Position>? _positionSubscription;
  Timer? _etaTimer;

  Position? _currentPosition;
  double? _homeLatitude;
  double? _homeLongitude;
  String? _activeDeliveryId;

  Position? get currentPosition => _currentPosition;

  GpsTrackingService(this._firestoreService);

  /// Check and request location permissions.
  Future<bool> ensurePermissions() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return false;

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) return false;
    }
    if (permission == LocationPermission.deniedForever) return false;

    return true;
  }

  /// Start tracking GPS and pushing updates to Firestore.
  Future<void> startTracking({
    required String deliveryId,
    double? homeLatitude,
    double? homeLongitude,
    void Function(Position position, Duration? eta)? onUpdate,
  }) async {
    _activeDeliveryId = deliveryId;
    _homeLatitude = homeLatitude;
    _homeLongitude = homeLongitude;

    const locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 10, // meters
    );

    _positionSubscription =
        Geolocator.getPositionStream(locationSettings: locationSettings)
            .listen((position) {
      _currentPosition = position;

      // Push to Firestore
      _firestoreService.updateDeliveryLocation(
        deliveryId: deliveryId,
        latitude: position.latitude,
        longitude: position.longitude,
      );

      final eta = _calculateEta(position);
      onUpdate?.call(position, eta);
    });
  }

  /// Calculate ETA based on distance and speed.
  Duration? _calculateEta(Position position) {
    if (_homeLatitude == null || _homeLongitude == null) return null;

    final distanceMeters = Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      _homeLatitude!,
      _homeLongitude!,
    );

    // Use actual speed if available (m/s), otherwise estimate at 30 km/h
    final speedMps = position.speed > 1.0 ? position.speed : 8.33;
    final seconds = distanceMeters / speedMps;

    return Duration(seconds: seconds.round());
  }

  /// Calculate distance in meters between two points.
  static double distanceBetween(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  /// Calculate ETA from any position to home.
  static Duration calculateEtaFromPosition({
    required double latitude,
    required double longitude,
    required double homeLatitude,
    required double homeLongitude,
    double? speedMps,
  }) {
    final distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      homeLatitude,
      homeLongitude,
    );
    final speed = (speedMps != null && speedMps > 1.0) ? speedMps : 8.33;
    return Duration(seconds: (distance / speed).round());
  }

  void stopTracking() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    _etaTimer?.cancel();
    _etaTimer = null;
    _activeDeliveryId = null;
    _currentPosition = null;
  }

  void dispose() {
    stopTracking();
  }
}
