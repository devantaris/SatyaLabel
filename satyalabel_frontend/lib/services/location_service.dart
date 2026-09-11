/// GPS location for scan evidence (best-effort, never blocks a scan).
library;

import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Returns the current position, or null when permission is denied,
  /// location services are off, or acquisition times out.
  static Future<({double latitude, double longitude})?> currentPosition() async {
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }
      if (!await Geolocator.isLocationServiceEnabled()) {
        return null;
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );
      return (latitude: position.latitude, longitude: position.longitude);
    } catch (_) {
      return null; // best-effort — scanning works without geo
    }
  }
}
