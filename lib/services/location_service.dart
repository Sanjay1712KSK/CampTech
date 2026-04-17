import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

class LocationResult {
  final bool granted;
  final double? lat;
  final double? lon;
  final String? city;
  final String? error;

  const LocationResult({
    required this.granted,
    this.lat,
    this.lon,
    this.city,
    this.error,
  });
}

class LocationService {
  static Future<bool> hasGrantedLocationPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) {
      return false;
    }

    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Future<String?> _reverseGeocode(double lat, double lon) async {
    try {
      final placemarks = await placemarkFromCoordinates(lat, lon);
      final first = placemarks.isNotEmpty ? placemarks.first : null;
      final locality = first?.locality?.trim();
      final subAdministrativeArea = first?.subAdministrativeArea?.trim();
      if (locality != null && locality.isNotEmpty) return locality;
      if (subAdministrativeArea != null && subAdministrativeArea.isNotEmpty) {
        return subAdministrativeArea;
      }
    } catch (_) {
      // Fall back to coarse coordinate mapping below.
    }

    if (lat >= 12.8 && lat <= 13.3 && lon >= 80.1 && lon <= 80.4) {
      return 'Chennai';
    }
    if (lat >= 12.8 && lat <= 13.2 && lon >= 77.4 && lon <= 77.8) {
      return 'Bengaluru';
    }
    if (lat >= 18.4 && lat <= 18.7 && lon >= 73.7 && lon <= 74.0) {
      return 'Pune';
    }
    return null;
  }

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
        city: await _reverseGeocode(position.latitude, position.longitude),
      );
    } catch (_) {
      return const LocationResult(
        granted: false,
        error: 'Unable to fetch current location',
      );
    }
  }
}
