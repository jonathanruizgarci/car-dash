import 'dart:async';

import 'package:flutter/foundation.dart';

import 'settings.dart';
import 'weather.dart';

/// Decide si usar tema de día o de noche (según amanecer/atardecer).
class DayNight extends ChangeNotifier {
  DayNight._();
  static final DayNight I = DayNight._();

  bool dark = false;
  Timer? _timer;

  void start() {
    _eval();
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _eval());
    Settings.I.addListener(_eval);
    WeatherService.I.addListener(_eval);
  }

  bool get isNightNow {
    final now = DateTime.now();
    final w = WeatherService.I;
    final sr = w.sunrise;
    final ss = w.sunset;
    final rise = DateTime(now.year, now.month, now.day, sr?.hour ?? 7, sr?.minute ?? 0);
    final down = DateTime(now.year, now.month, now.day, ss?.hour ?? 19, ss?.minute ?? 0);
    return now.isBefore(rise) || now.isAfter(down);
  }

  void _eval() {
    final mode = Settings.I.themeMode;
    final d = mode == 'night' ? true : (mode == 'day' ? false : isNightNow);
    if (d != dark) {
      dark = d;
      notifyListeners();
    }
  }
}
