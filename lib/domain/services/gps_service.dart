/// GPS service — current location, speed, heading, ETA and arrival detection
/// (FR-005, FR-006). Uses geolocator. GPS sharing starts only after explicit
/// user confirmation (BR-005).
import 'dart:async';

import 'package:geolocator/geolocator.dart';

import 'package:pokatuha/core/errors/app_error.dart';
import 'package:pokatuha/core/utils/geo_utils.dart';

class GpsSample {
  GpsSample({
    required this.lat,
    required this.lng,
    required this.speed,
    required this.heading,
    required this.accuracy,
    required this.timestamp,
  });

  final double lat;
  final double lng;
  final double speed; // m/s
  final double heading; // degrees
  final double accuracy; // meters
  final int timestamp; // UTC ms
}

class GpsService {
  Stream<GpsSample>? _positionStream;
  bool _sharingEnabled = false;

  bool get isSharing => _sharingEnabled;

  /// Verify / request permissions (Permissions.md — location requested only
  /// when required, never background automatically).
  Future<bool> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) {
      throw const PermissionError(
          'Location permission permanently denied. Enable it in settings.');
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  /// Current location once.
  Future<GpsSample> current() async {
    if (!await ensurePermission()) {
      throw const PermissionError('Location permission required');
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
    return _toSample(position);
  }

  /// Begin sharing GPS (BR-005 — only after explicit Start Ride).
  Stream<GpsSample> startSharing() {
    if (_positionStream != null) return _positionStream!;
    _sharingEnabled = true;
    const settings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );
    _positionStream =
        Geolocator.getPositionStream(locationSettings: settings).map(_toSample);
    return _positionStream!;
  }

  void stopSharing() {
    _sharingEnabled = false;
    _positionStream = null;
  }

  /// Evaluate arrival stage relative to a meeting point (FR-006).
  ({ArrivalStage? stage, double distanceMeters, int etaMinutes})
      evaluateArrival({
    required GpsSample sample,
    required double meetingLat,
    required double meetingLng,
    double near = 500.0,
    double close = 200.0,
    double arrived = 50.0,
  }) {
    final distance = GeoUtils.distanceMeters(
      lat1: sample.lat,
      lng1: sample.lng,
      lat2: meetingLat,
      lng2: meetingLng,
    );
    final stage = GeoUtils.arrivalStage(
      distance,
      near: near,
      close: close,
      arrived: arrived,
    );
    final eta = GeoUtils.etaMinutes(distance, sample.speed);
    return (stage: stage, distanceMeters: distance, etaMinutes: eta);
  }

  GpsSample _toSample(Position p) {
    return GpsSample(
      lat: p.latitude,
      lng: p.longitude,
      speed: p.speed < 0 ? 0 : p.speed,
      heading: p.heading < 0 ? 0 : p.heading,
      accuracy: p.accuracy,
      timestamp: p.timestamp.millisecondsSinceEpoch,
    );
  }
}
