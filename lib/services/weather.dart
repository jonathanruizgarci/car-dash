import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import 'gps.dart';

class HourW {
  final DateTime time;
  final double temp;
  final int code;
  final int rain;
  const HourW(this.time, this.temp, this.code, this.rain);
}

class DayW {
  final DateTime date;
  final double max;
  final double min;
  final int code;
  final int rain;
  const DayW(this.date, this.max, this.min, this.code, this.rain);
}

/// Pronóstico de Open-Meteo (gratis, sin llave).
class WeatherService extends ChangeNotifier {
  WeatherService._();
  static final WeatherService I = WeatherService._();

  double? temp;
  double? feels;
  double? humidity;
  double? wind;
  int? code;
  List<HourW> hours = [];
  List<DayW> days = [];
  DateTime? sunrise;
  DateTime? sunset;
  DateTime? updated;
  String? error;
  bool loading = false;
  Timer? _timer;

  void start() {
    refresh();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(minutes: 20), (_) => refresh());
  }

  Future<void> refresh() async {
    if (loading) return;
    final pos = GpsService.I.last;
    final lat = pos?.latitude ?? 18.9;
    final lon = pos?.longitude ?? -98.43;
    loading = true;
    notifyListeners();
    try {
      final uri = Uri.parse('https://api.open-meteo.com/v1/forecast'
          '?latitude=${lat.toStringAsFixed(4)}&longitude=${lon.toStringAsFixed(4)}'
          '&current=temperature_2m,apparent_temperature,relative_humidity_2m,wind_speed_10m,weather_code'
          '&hourly=temperature_2m,weather_code,precipitation_probability'
          '&daily=weather_code,temperature_2m_max,temperature_2m_min,sunrise,sunset,precipitation_probability_max'
          '&timezone=auto&forecast_days=7');
      final res = await http.get(uri).timeout(const Duration(seconds: 20));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final j = jsonDecode(res.body) as Map<String, dynamic>;

      final cur = j['current'] as Map<String, dynamic>;
      temp = _d(cur['temperature_2m']);
      feels = _d(cur['apparent_temperature']);
      humidity = _d(cur['relative_humidity_2m']);
      wind = _d(cur['wind_speed_10m']);
      code = (cur['weather_code'] as num?)?.toInt();

      final h = j['hourly'] as Map<String, dynamic>;
      final hTime = (h['time'] as List).cast<String>();
      final hTemp = h['temperature_2m'] as List;
      final hCode = h['weather_code'] as List;
      final hRain = h['precipitation_probability'] as List;
      final now = DateTime.now();
      final newHours = <HourW>[];
      for (var i = 0; i < hTime.length; i++) {
        final t = DateTime.parse(hTime[i]);
        if (t.isBefore(now.subtract(const Duration(minutes: 59)))) continue;
        newHours.add(HourW(t, _d(hTemp[i]) ?? 0, (hCode[i] as num?)?.toInt() ?? 0,
            (hRain[i] as num?)?.toInt() ?? 0));
        if (newHours.length >= 24) break;
      }
      hours = newHours;

      final d = j['daily'] as Map<String, dynamic>;
      final dTime = (d['time'] as List).cast<String>();
      final dMax = d['temperature_2m_max'] as List;
      final dMin = d['temperature_2m_min'] as List;
      final dCode = d['weather_code'] as List;
      final dRain = d['precipitation_probability_max'] as List;
      final newDays = <DayW>[];
      for (var i = 0; i < dTime.length; i++) {
        newDays.add(DayW(DateTime.parse(dTime[i]), _d(dMax[i]) ?? 0, _d(dMin[i]) ?? 0,
            (dCode[i] as num?)?.toInt() ?? 0, (dRain[i] as num?)?.toInt() ?? 0));
      }
      days = newDays;
      final sr = d['sunrise'] as List;
      final ss = d['sunset'] as List;
      if (sr.isNotEmpty) sunrise = DateTime.parse(sr[0] as String);
      if (ss.isNotEmpty) sunset = DateTime.parse(ss[0] as String);
      updated = DateTime.now();
      error = null;
    } catch (e) {
      error = 'Sin datos del clima (revisa el internet)';
    }
    loading = false;
    notifyListeners();
  }

  static double? _d(Object? v) => (v as num?)?.toDouble();
}

/// Texto e ícono para los códigos WMO de Open-Meteo.
(String, IconData) weatherInfo(int? code, {bool night = false}) {
  final c = code ?? -1;
  if (c == 0) return (night ? 'Despejado' : 'Soleado', night ? Icons.nights_stay : Icons.wb_sunny);
  if (c == 1 || c == 2) return ('Parcialmente nublado', night ? Icons.nights_stay : Icons.wb_cloudy);
  if (c == 3) return ('Nublado', Icons.cloud);
  if (c == 45 || c == 48) return ('Neblina', Icons.cloud);
  if (c >= 51 && c <= 57) return ('Llovizna', Icons.grain);
  if (c >= 61 && c <= 67) return ('Lluvia', Icons.water_drop);
  if (c >= 71 && c <= 77) return ('Nieve', Icons.ac_unit);
  if (c >= 80 && c <= 82) return ('Chubascos', Icons.water_drop);
  if (c >= 85 && c <= 86) return ('Nevadas', Icons.ac_unit);
  if (c >= 95) return ('Tormenta', Icons.thunderstorm);
  return ('--', Icons.cloud_queue);
}
