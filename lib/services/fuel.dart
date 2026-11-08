import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'gps.dart';
import 'obd.dart';
import 'settings.dart';

class Station {
  final String name;
  final double lat;
  final double lon;
  final double km;
  final Map<String, double> prices;
  const Station(this.name, this.lat, this.lon, this.km, this.prices);

  Map<String, dynamic> toJson() => {'name': name, 'lat': lat, 'lon': lon, 'km': km, 'prices': prices};

  static Station fromJson(Map<String, dynamic> j) => Station(
        j['name'] as String,
        (j['lat'] as num).toDouble(),
        (j['lon'] as num).toDouble(),
        (j['km'] as num).toDouble(),
        (j['prices'] as Map).map((k, v) => MapEntry(k as String, (v as num).toDouble())),
      );
}

/// Gasolineras cercanas con precios publicados por la CRE.
class FuelService extends ChangeNotifier {
  FuelService._();
  static final FuelService I = FuelService._();

  static const _placesUrl = 'https://publicacionexterna.azurewebsites.net/publicaciones/places';
  static const _pricesUrl = 'https://publicacionexterna.azurewebsites.net/publicaciones/prices';

  List<Station> nearby = [];
  bool loading = false;
  String? error;
  DateTime? updated;

  void loadCached() {
    final raw = Settings.I.prefs.getString('cre_cache');
    if (raw == null) return;
    try {
      final j = jsonDecode(raw) as Map<String, dynamic>;
      updated = DateTime.parse(j['ts'] as String);
      nearby = (j['list'] as List).map((e) => Station.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      notifyListeners();
    } catch (_) {}
  }

  bool get stale => updated == null || DateTime.now().difference(updated!).inHours >= 12;

  Future<void> refresh() async {
    if (loading) return;
    final pos = GpsService.I.last;
    if (pos == null) {
      error = 'Esperando ubicación GPS para buscar gasolineras';
      notifyListeners();
      return;
    }
    loading = true;
    error = null;
    notifyListeners();
    try {
      final responses = await Future.wait([
        http.get(Uri.parse(_placesUrl)).timeout(const Duration(seconds: 60)),
        http.get(Uri.parse(_pricesUrl)).timeout(const Duration(seconds: 60)),
      ]);
      if (responses.any((r) => r.statusCode != 200)) throw Exception('CRE no respondió');
      final list = await compute(parseCre, <String, Object>{
        'places': utf8.decode(responses[0].bodyBytes, allowMalformed: true),
        'prices': utf8.decode(responses[1].bodyBytes, allowMalformed: true),
        'lat': pos.latitude,
        'lon': pos.longitude,
      });
      nearby = list.map(Station.fromJson).toList();
      updated = DateTime.now();
      await Settings.I.prefs.setString(
        'cre_cache',
        jsonEncode({'ts': updated!.toIso8601String(), 'list': nearby.map((s) => s.toJson()).toList()}),
      );
      if (nearby.isEmpty) error = 'No se encontraron gasolineras a menos de 15 km';
    } catch (e) {
      error = 'No se pudieron descargar los precios de la CRE. Se usa el precio manual.';
    }
    loading = false;
    notifyListeners();
  }

  /// Precio de la gasolinera más cercana que venda ese tipo.
  double? nearestPrice(String type) {
    for (final s in nearby) {
      final p = s.prices[type];
      if (p != null && p > 0) return p;
    }
    return null;
  }
}

/// Cálculos de autonomía.
class FuelMath {
  static bool get fromObd => ObdService.I.value('2F') != null;
  static double get pct => ObdService.I.value('2F') ?? Settings.I.manualFuelPct;
  static double get liters => Settings.I.tankLiters * pct / 100;
  static double get rangeKm => liters * Settings.I.kmPerLiter;
  static double get price => FuelService.I.nearestPrice(Settings.I.fuelType) ?? Settings.I.manualPrice;
  static bool get priceFromCre => FuelService.I.nearestPrice(Settings.I.fuelType) != null;
  static double get costToFill => (Settings.I.tankLiters - liters).clamp(0, 1000).toDouble() * price;
}

// ---- Se ejecuta en un isolate aparte ----

List<Map<String, dynamic>> parseCre(Map<String, Object> m) {
  final places = m['places'] as String;
  final prices = m['prices'] as String;
  final lat = m['lat'] as double;
  final lon = m['lon'] as double;

  final placeRe = RegExp(r'<place\s+place_id="(\d+)"[^>]*>(.*?)</place>', dotAll: true);
  final nameRe = RegExp(r'<name>(.*?)</name>', dotAll: true);
  final xRe = RegExp(r'<x>\s*(-?[\d.]+)\s*</x>');
  final yRe = RegExp(r'<y>\s*(-?[\d.]+)\s*</y>');
  final priceRe = RegExp(r'<gas_price\s+type="(\w+)"[^>]*>\s*([\d.]+)\s*</gas_price>');

  final near = <String, Map<String, dynamic>>{};
  for (final pm in placeRe.allMatches(places)) {
    final body = pm.group(2)!;
    final x = xRe.firstMatch(body);
    final y = yRe.firstMatch(body);
    if (x == null || y == null) continue;
    final lo = double.tryParse(x.group(1)!);
    final la = double.tryParse(y.group(1)!);
    if (lo == null || la == null) continue;
    final d = _haversine(lat, lon, la, lo);
    if (d > 15) continue;
    near[pm.group(1)!] = {
      'name': _unescape(nameRe.firstMatch(body)?.group(1) ?? 'Gasolinera'),
      'lat': la,
      'lon': lo,
      'km': d,
      'prices': <String, double>{},
    };
  }
  if (near.isEmpty) return [];
  for (final pm in placeRe.allMatches(prices)) {
    final st = near[pm.group(1)!];
    if (st == null) continue;
    final p = st['prices'] as Map<String, double>;
    for (final g in priceRe.allMatches(pm.group(2)!)) {
      final v = double.tryParse(g.group(2)!);
      if (v != null) p[g.group(1)!.toLowerCase()] = v;
    }
  }
  final list = near.values.where((s) => (s['prices'] as Map).isNotEmpty).toList()
    ..sort((a, b) => (a['km'] as double).compareTo(b['km'] as double));
  return list.take(30).toList();
}

double _haversine(double lat1, double lon1, double lat2, double lon2) {
  const r = 6371.0;
  final dLat = (lat2 - lat1) * math.pi / 180;
  final dLon = (lon2 - lon1) * math.pi / 180;
  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) * math.sin(dLon / 2) * math.sin(dLon / 2);
  return r * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
}

String _unescape(String s) => s
    .replaceAll('&amp;', '&')
    .replaceAll('&quot;', '"')
    .replaceAll('&apos;', "'")
    .replaceAll('&lt;', '<')
    .replaceAll('&gt;', '>')
    .trim();
