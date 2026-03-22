import 'dart:io';
import 'package:geolocator/geolocator.dart';

enum LocationPermissionStatus { always, whileInUse, denied, deniedForever }

class LocationService {
  LocationSettings get _locationSettings {
    if (Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
        pauseLocationUpdatesAutomatically: false,
        activityType: ActivityType.fitness,
      );
    }
    return const LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
  }

  Stream<Position> positionStream() {
    return Geolocator.getPositionStream(locationSettings: _locationSettings);
  }

  Future<LocationPermissionStatus> requestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    switch (permission) {
      case LocationPermission.always:
        return LocationPermissionStatus.always;
      case LocationPermission.whileInUse:
        return LocationPermissionStatus.whileInUse;
      case LocationPermission.deniedForever:
        return LocationPermissionStatus.deniedForever;
      default:
        return LocationPermissionStatus.denied;
    }
  }

  Future<void> openSettings() => Geolocator.openAppSettings();
}
