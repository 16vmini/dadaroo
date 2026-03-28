import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:dadaroo/config/map_config.dart';
import 'package:dadaroo/services/mock_gps_service.dart' as mock;
import 'package:dadaroo/theme/app_theme.dart';

/// Live Google Maps widget with cartoony styling.
/// Shows Dad's car moving along the route with custom markers.
class LiveMapWidget extends StatefulWidget {
  final mock.LatLng? dadLocation;
  final mock.LatLng homeLocation;
  final double progress;
  final mock.LatLng? restaurantLocation;

  const LiveMapWidget({
    super.key,
    required this.dadLocation,
    required this.homeLocation,
    required this.progress,
    this.restaurantLocation,
  });

  @override
  State<LiveMapWidget> createState() => _LiveMapWidgetState();
}

class _LiveMapWidgetState extends State<LiveMapWidget> {
  GoogleMapController? _controller;
  BitmapDescriptor? _dadMarkerIcon;
  BitmapDescriptor? _homeMarkerIcon;
  BitmapDescriptor? _restaurantMarkerIcon;

  @override
  void initState() {
    super.initState();
    _createMarkerIcons();
  }

  Future<void> _createMarkerIcons() async {
    // Use default markers with custom hues for now.
    // TODO: Replace with custom PNG markers (cartoon car, house, restaurant)
    _dadMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueOrange,
    );
    _homeMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueGreen,
    );
    _restaurantMarkerIcon = BitmapDescriptor.defaultMarkerWithHue(
      BitmapDescriptor.hueRed,
    );
    if (mounted) setState(() {});
  }

  @override
  void didUpdateWidget(LiveMapWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Animate camera to follow dad
    if (widget.dadLocation != null && _controller != null) {
      _controller!.animateCamera(
        CameraUpdate.newLatLng(
          LatLng(
            widget.dadLocation!.latitude,
            widget.dadLocation!.longitude,
          ),
        ),
      );
    }
  }

  LatLng _toGoogleLatLng(mock.LatLng loc) =>
      LatLng(loc.latitude, loc.longitude);

  Set<Marker> _buildMarkers() {
    final markers = <Marker>{};

    // Home marker
    markers.add(Marker(
      markerId: const MarkerId('home'),
      position: _toGoogleLatLng(widget.homeLocation),
      icon: _homeMarkerIcon ?? BitmapDescriptor.defaultMarker,
      infoWindow: const InfoWindow(title: '🏠 Home', snippet: 'Dinner time!'),
    ));

    // Restaurant marker
    if (widget.restaurantLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('restaurant'),
        position: _toGoogleLatLng(widget.restaurantLocation!),
        icon: _restaurantMarkerIcon ?? BitmapDescriptor.defaultMarker,
        infoWindow:
            const InfoWindow(title: '🍔 Takeaway', snippet: 'Getting food!'),
      ));
    }

    // Dad marker (the star of the show!)
    if (widget.dadLocation != null) {
      markers.add(Marker(
        markerId: const MarkerId('dad'),
        position: _toGoogleLatLng(widget.dadLocation!),
        icon: _dadMarkerIcon ?? BitmapDescriptor.defaultMarker,
        infoWindow: const InfoWindow(title: '🚗 Dad', snippet: 'On the way!'),
        zIndex: 10, // Always on top
      ));
    }

    return markers;
  }

  Set<Polyline> _buildRoute() {
    if (widget.restaurantLocation == null || widget.dadLocation == null) {
      return {};
    }

    // Simple straight-line route (could be replaced with Directions API)
    final points = [
      _toGoogleLatLng(widget.restaurantLocation!),
      if (widget.dadLocation != null) _toGoogleLatLng(widget.dadLocation!),
      _toGoogleLatLng(widget.homeLocation),
    ];

    return {
      // Travelled portion (solid orange)
      Polyline(
        polylineId: const PolylineId('travelled'),
        points: [
          _toGoogleLatLng(widget.restaurantLocation!),
          if (widget.dadLocation != null) _toGoogleLatLng(widget.dadLocation!),
        ],
        color: AppTheme.primaryOrange,
        width: 5,
      ),
      // Remaining portion (dashed effect via lighter color)
      Polyline(
        polylineId: const PolylineId('remaining'),
        points: [
          if (widget.dadLocation != null) _toGoogleLatLng(widget.dadLocation!),
          _toGoogleLatLng(widget.homeLocation),
        ],
        color: AppTheme.primaryOrange.withValues(alpha: 0.35),
        width: 4,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    };
  }

  LatLngBounds _calculateBounds() {
    double minLat = widget.homeLocation.latitude;
    double maxLat = widget.homeLocation.latitude;
    double minLng = widget.homeLocation.longitude;
    double maxLng = widget.homeLocation.longitude;

    void expand(double lat, double lng) {
      if (lat < minLat) minLat = lat;
      if (lat > maxLat) maxLat = lat;
      if (lng < minLng) minLng = lng;
      if (lng > maxLng) maxLng = lng;
    }

    if (widget.dadLocation != null) {
      expand(widget.dadLocation!.latitude, widget.dadLocation!.longitude);
    }
    if (widget.restaurantLocation != null) {
      expand(
          widget.restaurantLocation!.latitude, widget.restaurantLocation!.longitude);
    }

    // Add padding
    const pad = 0.005;
    return LatLngBounds(
      southwest: LatLng(minLat - pad, minLng - pad),
      northeast: LatLng(maxLat + pad, maxLng + pad),
    );
  }

  @override
  Widget build(BuildContext context) {
    final initialPos = widget.dadLocation ?? widget.homeLocation;

    return Container(
      height: 300,
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.warmBrown.withValues(alpha: 0.3),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          children: [
            GoogleMap(
              initialCameraPosition: CameraPosition(
                target: LatLng(initialPos.latitude, initialPos.longitude),
                zoom: 14,
              ),
              markers: _buildMarkers(),
              polylines: _buildRoute(),
              style: MapConfig.cartoonStyle,
              onMapCreated: (controller) {
                _controller = controller;
                // Fit bounds to show full route
                Future.delayed(const Duration(milliseconds: 500), () {
                  if (_controller != null) {
                    _controller!.animateCamera(
                      CameraUpdate.newLatLngBounds(_calculateBounds(), 50),
                    );
                  }
                });
              },
              myLocationEnabled: false,
              myLocationButtonEnabled: false,
              zoomControlsEnabled: false,
              mapToolbarEnabled: false,
              compassEnabled: false,
              rotateGesturesEnabled: false,
              tiltGesturesEnabled: false,
            ),
            // Progress overlay at bottom
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Text('🍔', style: TextStyle(fontSize: 18)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: widget.progress,
                          backgroundColor: AppTheme.lightOrange,
                          valueColor:
                              AlwaysStoppedAnimation(AppTheme.primaryOrange),
                          minHeight: 8,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('🏠', style: TextStyle(fontSize: 18)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
}
