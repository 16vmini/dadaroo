import 'package:flutter/material.dart';
import 'package:dadaroo/config/map_config.dart';
import 'package:dadaroo/services/mock_gps_service.dart';
import 'package:dadaroo/widgets/live_map_widget.dart';
import 'package:dadaroo/widgets/map_widget.dart';

/// Smart map widget that uses Google Maps when an API key is configured,
/// and falls back to the mock cartoon map otherwise.
class DadarooMap extends StatelessWidget {
  final LatLng? dadLocation;
  final LatLng homeLocation;
  final double progress;
  final LatLng? restaurantLocation;

  const DadarooMap({
    super.key,
    required this.dadLocation,
    required this.homeLocation,
    required this.progress,
    this.restaurantLocation,
  });

  @override
  Widget build(BuildContext context) {
    if (MapConfig.hasApiKey) {
      return LiveMapWidget(
        dadLocation: dadLocation,
        homeLocation: homeLocation,
        progress: progress,
        restaurantLocation: restaurantLocation,
      );
    }

    // Fallback to mock map
    return MockMapWidget(
      dadLocation: dadLocation,
      homeLocation: homeLocation,
      progress: progress,
    );
  }
}
