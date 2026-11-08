import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'obd.dart';
import 'settings.dart';
import 'weather.dart';

/// Ubicación, velocidad por GPS y estadísticas del viaje.
class GpsService extends ChangeNotifier {
  GpsService._();
  static final GpsService I = GpsService._();

  Position? last;
  double gpsKmh = 0;
  bool ok = false;
  String status = 'Buscando GPS…';

  // Viaje
  double tripKm = 0;
  int tripMovingSec = 0;
  DateTime tripStart = DateTime.now();
  double tripMaxKmh = 0;
  double tripFuelL = 0;

  StreamSubscription<Position>? _sub;
  Timer? _tick;
  Timer? _save;
  bool _hadFix = false;

  /// Velocidad mostrada: OBD si está disponible, si no GPS.
  double get speedKmh => ObdService.I.value('0D') ?? gpsKmh;
  bool get speedFromObd => ObdService.I.value('0D') != null;

  double get avgKmh => tripMovingSec > 0 ? tripKm / (tripMovingSec / 3600) : 0;
  int get tripTotalSec => DateTime.now().difference(tripStart).inSeconds;
  double? get tripKmPerL => tripFuelL > 0.3 ? tripKm / tripFuelL : null;

  Future<void> start() async {
    _loadTrip();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
    _save = Timer.periodic(const Duration(seconds: 30), (_) => _saveTrip());
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        status = 'GPS apagado';
        notifyListeners();
      }
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) {
        status = 'Sin permiso de ubicación';
        notifyListeners();
        return;
      }
      _sub = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.bestForNavigation,
          distanceFilter: 0,
        ),
      ).listen(_onPos, onError: (Object e) {
        ok = false;
        status = 'Error de GPS';
        notifyListeners();
      });
    } catch (e) {
      status = 'Error de GPS';
      notifyListeners();
    }
  }

  void _onPos(Position p) {
    final prev = last;
    last = p;
    ok = true;
    status = 'GPS ±${p.accuracy.toStringAsFixed(0)} m';
    final s = p.speed.isFinite && p.speed > 0 ? p.speed * 3.6 : 0.0;
    gpsKmh = s < 2 ? 0.0 : s;
    if (prev != null && p.accuracy < 35 && speedKmh > 2) {
      final d = Geolocator.distanceBetween(prev.latitude, prev.longitude, p.latitude, p.longitude);
      if (d < 500) tripKm += d / 1000;
    }
    if (!_hadFix) {
      _hadFix = true;
      WeatherService.I.refresh();
    }
    notifyListeners();
  }

  void _onTick() {
    final v = speedKmh;
    if (v > 2) tripMovingSec++;
    if (v > tripMaxKmh) tripMaxKmh = v;
    final obd = ObdService.I;
    final lph = obd.value('5E');
    final maf = obd.value('10');
    if (lph != null) {
      tripFuelL += lph / 3600;
    } else if (maf != null) {
      // gasolina: relación estequiométrica 14.7 y densidad ~745 g/L
      tripFuelL += maf / 14.7 / 745;
    }
    notifyListeners();
  }

  void resetTrip() {
    tripKm = 0;
    tripMovingSec = 0;
    tripStart = DateTime.now();
    tripMaxKmh = 0;
    tripFuelL = 0;
    _saveTrip();
    notifyListeners();
  }

  void _loadTrip() {
    final raw = Settings.I.prefs.getString('trip');
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      tripKm = (j['km'] as num).toDouble();
      tripMovingSec = (j['moving'] as num).toInt();
      tripStart = DateTime.parse(j['start'] as String);
      tripMaxKmh = (j['max'] as num).toDouble();
      tripFuelL = (j['fuel'] as num).toDouble();
    } catch (_) {}
  }

  void _saveTrip() {
    Settings.I.prefs.setString(
      'trip',
      jsonEncode({
        'km': tripKm,
        'moving': tripMovingSec,
        'start': tripStart.toIso8601String(),
        'max': tripMaxKmh,
        'fuel': tripFuelL,
      }),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    _tick?.cancel();
    _save?.cancel();
    super.dispose();
  }
}
