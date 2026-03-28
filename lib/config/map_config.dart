/// Google Maps configuration for Dadaroo.
///
/// To get your API key:
/// 1. Go to https://console.cloud.google.com/apis/credentials
///    (select the 'dadaroo' project)
/// 2. Enable "Maps SDK for Android" and "Maps SDK for iOS"
/// 3. Create an API key (or use an existing one)
/// 4. Paste it below
///
/// Then add it to:
/// - Android: android/app/src/main/AndroidManifest.xml
/// - iOS: ios/Runner/AppDelegate.swift
class MapConfig {
  /// Set this to your Google Maps API key.
  /// Leave empty to fall back to the mock map.
  static const String apiKey = 'AIzaSyB3-N5KwVMHmZ41RTmmppaVm80uXeR9yxo';

  static bool get hasApiKey => apiKey.isNotEmpty;

  /// Cartoony / retro styled map JSON for Google Maps.
  /// Muted roads, pastel buildings, simplified labels, fun vibe.
  static const String cartoonStyle = '''
[
  {
    "elementType": "geometry",
    "stylers": [{"color": "#f5e6d3"}]
  },
  {
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#6d4c41"}]
  },
  {
    "elementType": "labels.text.stroke",
    "stylers": [{"color": "#fff8f0"}, {"weight": 3}]
  },
  {
    "featureType": "road",
    "elementType": "geometry",
    "stylers": [{"color": "#ffffff"}]
  },
  {
    "featureType": "road",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#e0d5c8"}, {"weight": 1}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry",
    "stylers": [{"color": "#ffcc80"}]
  },
  {
    "featureType": "road.highway",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#e8a040"}, {"weight": 1.5}]
  },
  {
    "featureType": "road.arterial",
    "elementType": "geometry",
    "stylers": [{"color": "#ffe0b2"}]
  },
  {
    "featureType": "water",
    "elementType": "geometry",
    "stylers": [{"color": "#b3d9ff"}]
  },
  {
    "featureType": "water",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#4a90d9"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "geometry",
    "stylers": [{"color": "#c8e6c9"}]
  },
  {
    "featureType": "poi.park",
    "elementType": "labels.text.fill",
    "stylers": [{"color": "#4caf50"}]
  },
  {
    "featureType": "poi.business",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.medical",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.government",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.school",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "poi.sports_complex",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "transit",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "landscape.man_made",
    "elementType": "geometry",
    "stylers": [{"color": "#f0e0d0"}]
  },
  {
    "featureType": "landscape.natural",
    "elementType": "geometry",
    "stylers": [{"color": "#e8dcc8"}]
  },
  {
    "featureType": "administrative",
    "elementType": "geometry.stroke",
    "stylers": [{"color": "#d7ccc8"}, {"weight": 1}]
  },
  {
    "featureType": "administrative.neighborhood",
    "stylers": [{"visibility": "off"}]
  },
  {
    "featureType": "road",
    "elementType": "labels.icon",
    "stylers": [{"visibility": "off"}]
  }
]
''';
}
