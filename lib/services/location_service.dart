import 'package:geolocator/geolocator.dart';

class LocationResult {
  final bool granted;
  final double? lat;
  final double? lon;
  final String? error;

  const LocationResult({
    required this.granted,
    this.lat,
    this.lon,
    this.error,
  });
}

class LocationService {
  static Future<LocationResult> requestCurrentLocation() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return const LocationResult(
        granted: false,
        error: 'Location services are disabled',
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return const LocationResult(
        granted: false,
        error: 'Location permission denied',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      return LocationResult(
        granted: true,
        lat: position.latitude,
        lon: position.longitude,
      );
    } catch (_) {
      return const LocationResult(
        granted: false,
        error: 'Unable to fetch current location',
      );
    }
  }
}
