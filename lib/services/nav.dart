import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import 'gps.dart';
import 'native.dart';
import 'settings.dart';

const _ua = {'User-Agent': 'AutoPanel/1.2 (tablero personal para auto)'};

class Place {
  final String name;
  final String detail;
  final LatLng point;
  const Place(this.name, this.detail, this.point);

  Map<String, dynamic> toJson() => {'n': name, 'd': detail, 'la': point.latitude, 'lo': point.longitude};

  static Place fromJson(Map<String, dynamic> j) => Place(
        j['n'] as String,
        (j['d'] as String?) ?? '',
        LatLng((j['la'] as num).toDouble(), (j['lo'] as num).toDouble()),
      );
}

class NavStep {
  final String text;
  final IconData icon;
  final LatLng at;
  final String type;
  double along = 0; // metros desde el inicio de la ruta
  bool farSpoken = false;
  bool nearSpoken = false;
  NavStep(this.text, this.icon, this.at, this.type);
}

String fmtDist(double m) {
  if (m < 1000) {
    final r = m < 100 ? (m / 10).round() * 10 : (m / 50).round() * 50;
    return '${r < 10 ? 10 : r} m';
  }
  return '${(m / 1000).toStringAsFixed(m < 10000 ? 1 : 0)} km';
}

String fmtMinutes(double sec) {
  final min = (sec / 60).round();
  if (min < 60) return '$min min';
  return '${min ~/ 60} h ${min % 60} min';
}

/// Buscador, rutas y guía vuelta por vuelta.
class NavService extends ChangeNotifier {
  NavService._();
  static final NavService I = NavService._();

  // Búsqueda
  List<Place> results = [];
  bool searching = false;
  String? searchError;
  int _searchSeq = 0;

  // Ruta
  Place? destination;
  List<LatLng> route = [];
  List<double> _cum = [];
  List<NavStep> steps = [];
  double routeMeters = 0;
  double routeSeconds = 0;
  bool routing = false;
  String? routeError;

  // Navegación
  bool navigating = false;
  bool arrived = false;
  bool voice = true;
  int stepIndex = 0;
  double along = 0;
  double distToNext = 0;
  int _offCount = 0;
  DateTime _lastReroute = DateTime.fromMillisecondsSinceEpoch(0);

  // Favoritos
  Place? home;
  Place? work;
  List<Place> recents = [];

  double get remainingMeters => math.max(0.0, routeMeters - along);
  double get remainingSeconds => routeMeters > 0 ? routeSeconds * remainingMeters / routeMeters : 0;
  DateTime get eta => DateTime.now().add(Duration(seconds: remainingSeconds.round()));
  NavStep? get nextStep => stepIndex + 1 < steps.length ? steps[stepIndex + 1] : null;
  NavStep? get afterNext => stepIndex + 2 < steps.length ? steps[stepIndex + 2] : null;
  bool get hasRoute => route.length > 1;

  void init() {
    final p = Settings.I.prefs;
    Place? read(String k) {
      final raw = p.getString(k);
      if (raw == null) return null;
      try {
        return Place.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {
        return null;
      }
    }

    home = read('nav_home');
    work = read('nav_work');
    voice = p.getBool('nav_voice') ?? true;
    try {
      final raw = p.getString('nav_recents');
      if (raw != null) {
        recents = (jsonDecode(raw) as List).map((e) => Place.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      }
    } catch (_) {}
    GpsService.I.addListener(_onGps);
  }

  LatLng? get myPos {
    final p = GpsService.I.last;
    return p == null ? null : LatLng(p.latitude, p.longitude);
  }

  // ---------------- Favoritos ----------------

  Future<void> setFavorite(String which, Place p) async {
    if (which == 'home') {
      home = Place('Casa', p.detail.isEmpty ? p.name : p.detail, p.point);
    } else {
      work = Place('Trabajo', p.detail.isEmpty ? p.name : p.detail, p.point);
    }
    await Settings.I.prefs.setString('nav_$which', jsonEncode((which == 'home' ? home : work)!.toJson()));
    notifyListeners();
  }

  Future<void> setVoice(bool v) async {
    voice = v;
    await Settings.I.prefs.setBool('nav_voice', v);
    notifyListeners();
  }

  void _addRecent(Place p) {
    recents.removeWhere((r) => r.name == p.name && _m(r.point, p.point) < 50);
    recents.insert(0, p);
    if (recents.length > 10) recents = recents.sublist(0, 10);
    Settings.I.prefs.setString('nav_recents', jsonEncode(recents.map((e) => e.toJson()).toList()));
  }

  // ---------------- Búsqueda ----------------

  void clearResults() {
    results = [];
    searchError = null;
    notifyListeners();
  }

  void showPlaces(List<Place> list) {
    results = list;
    searchError = list.isEmpty ? 'Sin resultados' : null;
    notifyListeners();
  }

  Future<void> search(String q) async {
    q = q.trim();
    final seq = ++_searchSeq;
    if (q.length < 3) {
      clearResults();
      return;
    }
    searching = true;
    searchError = null;
    notifyListeners();
    List<Place> found = [];
    try {
      found = await _photon(q);
    } catch (_) {
      try {
        found = await _nominatim(q);
      } catch (_) {
        if (seq == _searchSeq) searchError = 'Sin internet para buscar';
      }
    }
    if (seq != _searchSeq) return; // llegó una búsqueda más nueva
    results = found;
    if (found.isEmpty && searchError == null) searchError = 'Sin resultados para "$q"';
    searching = false;
    notifyListeners();
  }

  Future<List<Place>> _photon(String q) async {
    final me = myPos;
    var url = 'https://photon.komoot.io/api/?q=${Uri.encodeQueryComponent(q)}&limit=10';
    if (me != null) url += '&lat=${me.latitude}&lon=${me.longitude}&location_bias_scale=0.4';
    final res = await http.get(Uri.parse(url), headers: _ua).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('photon ${res.statusCode}');
    final j = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final out = <Place>[];
    for (final f in (j['features'] as List)) {
      final m = f as Map<String, dynamic>;
      final props = Map<String, dynamic>.from(m['properties'] as Map);
      final coords = (m['geometry'] as Map)['coordinates'] as List;
      final pt = LatLng((coords[1] as num).toDouble(), (coords[0] as num).toDouble());
      final street = [props['street'], props['housenumber']].whereType<String>().join(' ');
      final name = (props['name'] as String?) ?? (street.isNotEmpty ? street : 'Ubicación');
      final parts = <String>[
        if (street.isNotEmpty && street != name) street,
        ...[props['district'], props['locality'], props['city'], props['state']].whereType<String>(),
      ];
      out.add(Place(name, _withDistance(parts.toSet().join(', '), pt), pt));
    }
    return out;
  }

  Future<List<Place>> _nominatim(String q) async {
    final url = 'https://nominatim.openstreetmap.org/search?format=jsonv2&limit=8&countrycodes=mx'
        '&accept-language=es&q=${Uri.encodeQueryComponent(q)}';
    final res = await http.get(Uri.parse(url), headers: _ua).timeout(const Duration(seconds: 10));
    if (res.statusCode != 200) throw Exception('nominatim ${res.statusCode}');
    final list = jsonDecode(utf8.decode(res.bodyBytes)) as List;
    return list.map((e) {
      final m = e as Map<String, dynamic>;
      final pt = LatLng(double.parse(m['lat'] as String), double.parse(m['lon'] as String));
      final full = (m['display_name'] as String?) ?? '';
      final name = (m['name'] as String?)?.isNotEmpty == true ? m['name'] as String : full.split(',').first;
      return Place(name, _withDistance(full, pt), pt);
    }).toList();
  }

  String _withDistance(String detail, LatLng pt) {
    final me = myPos;
    if (me == null) return detail;
    final d = _m(me, pt);
    return detail.isEmpty ? fmtDist(d) : '${fmtDist(d)} · $detail';
  }

  // ---------------- Ruta ----------------

  Future<void> routeTo(Place p, {bool keepNavigating = false, LatLng? from}) async {
    final start = from ?? myPos;
    if (start == null) {
      routeError = 'Esperando señal de GPS…';
      notifyListeners();
      return;
    }
    destination = p;
    routing = true;
    routeError = null;
    results = [];
    notifyListeners();
    try {
      final url = 'https://router.project-osrm.org/route/v1/driving/'
          '${start.longitude},${start.latitude};${p.point.longitude},${p.point.latitude}'
          '?overview=full&geometries=geojson&steps=true';
      final res = await http.get(Uri.parse(url), headers: _ua).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
      final j = jsonDecode(res.body) as Map<String, dynamic>;
      final routes = j['routes'] as List?;
      if (routes == null || routes.isEmpty) throw Exception('Sin ruta');
      final r = routes.first as Map<String, dynamic>;
      routeMeters = (r['distance'] as num).toDouble();
      routeSeconds = (r['duration'] as num).toDouble();
      route = ((r['geometry'] as Map)['coordinates'] as List)
          .map((c) => LatLng(((c as List)[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();
      _cum = [0];
      for (var i = 1; i < route.length; i++) {
        _cum.add(_cum[i - 1] + _m(route[i - 1], route[i]));
      }
      steps = [];
      final legs = r['legs'] as List;
      for (final leg in legs) {
        for (final s in ((leg as Map)['steps'] as List)) {
          final m = s as Map<String, dynamic>;
          final man = m['maneuver'] as Map<String, dynamic>;
          final loc = man['location'] as List;
          final type = (man['type'] as String?) ?? 'turn';
          final mod = man['modifier'] as String?;
          final exit = (man['exit'] as num?)?.toInt();
          final name = ((m['name'] as String?) ?? '').trim();
          final step = NavStep(
            _instruction(type, mod, name, exit),
            _icon(type, mod),
            LatLng((loc[1] as num).toDouble(), (loc[0] as num).toDouble()),
            type,
          );
          step.along = _alongOf(step.at);
          steps.add(step);
        }
      }
      along = 0;
      stepIndex = 0;
      _offCount = 0;
      arrived = false;
      distToNext = steps.length > 1 ? steps[1].along : routeMeters;
      if (!keepNavigating) _addRecent(p);
    } catch (e) {
      routeError = 'No se pudo calcular la ruta (revisa el internet)';
      if (!keepNavigating) route = [];
    }
    routing = false;
    notifyListeners();
    if (keepNavigating && hasRoute) _update();
  }

  void start() {
    if (!hasRoute) return;
    navigating = true;
    arrived = false;
    notifyListeners();
    final n = nextStep;
    _say(n == null
        ? 'Iniciando ruta'
        : 'Iniciando ruta. ${fmtMinutes(remainingSeconds)}, ${fmtDist(remainingMeters)}. En ${fmtDist(distToNext)}, ${n.text}');
    _update();
  }

  void stop() {
    navigating = false;
    arrived = false;
    route = [];
    steps = [];
    destination = null;
    routeError = null;
    notifyListeners();
  }

  // ---------------- Seguimiento ----------------

  void _onGps() {
    if (navigating) _update();
  }

  void _update() {
    final me = myPos;
    if (me == null || !hasRoute) return;
    final proj = _project(me);
    final off = proj.$2;
    if (off > 55) {
      _offCount++;
      if (_offCount >= 3 && DateTime.now().difference(_lastReroute).inSeconds > 12 && destination != null && !routing) {
        _lastReroute = DateTime.now();
        _say('Recalculando');
        routeTo(destination!, keepNavigating: true);
      }
    } else {
      _offCount = 0;
      // Nunca retroceder mucho sobre la ruta.
      if (proj.$1 > along - 30) along = proj.$1;
    }

    while (stepIndex + 1 < steps.length && along >= steps[stepIndex + 1].along - 12) {
      stepIndex++;
    }
    final n = nextStep;
    distToNext = n == null ? remainingMeters : math.max(0.0, n.along - along);

    if (remainingMeters < 30 || (n == null && remainingMeters < 60)) {
      if (!arrived) {
        arrived = true;
        navigating = false;
        _say('Has llegado a tu destino');
      }
    } else if (n != null) {
      final speed = GpsService.I.speedKmh / 3.6;
      final nearAt = (speed * 7).clamp(40, 130).toDouble();
      final farAt = (speed * 25).clamp(250, 800).toDouble();
      if (!n.farSpoken && distToNext <= farAt && distToNext > nearAt + 60) {
        n.farSpoken = true;
        _say('En ${fmtDist(distToNext)}, ${n.text}');
      } else if (!n.nearSpoken && distToNext <= nearAt) {
        n.nearSpoken = true;
        n.farSpoken = true;
        final after = afterNext;
        _say(after != null && after.along - n.along < 120 ? '${_cap(n.text)}, y luego ${after.text}' : _cap(n.text));
      }
    }
    notifyListeners();
  }

  /// Regresa (metros recorridos sobre la ruta, distancia a la ruta).
  (double, double) _project(LatLng p) {
    final lat0 = p.latitude * math.pi / 180;
    final kx = 111320 * math.cos(lat0);
    const ky = 110540.0;
    var best = double.infinity;
    var bestAlong = along;
    // Busca cerca de donde íbamos para no saltar a otra parte de la ruta.
    final startIdx = math.max(0, _segIndexFor(along) - 20);
    final endIdx = math.min(route.length - 1, startIdx + 400);
    for (var i = startIdx; i < endIdx; i++) {
      final ax = (route[i].longitude - p.longitude) * kx;
      final ay = (route[i].latitude - p.latitude) * ky;
      final bx = (route[i + 1].longitude - p.longitude) * kx;
      final by = (route[i + 1].latitude - p.latitude) * ky;
      final dx = bx - ax;
      final dy = by - ay;
      final len2 = dx * dx + dy * dy;
      var t = len2 == 0 ? 0.0 : -(ax * dx + ay * dy) / len2;
      t = t.clamp(0.0, 1.0).toDouble();
      final px = ax + t * dx;
      final py = ay + t * dy;
      final d = math.sqrt(px * px + py * py);
      if (d < best) {
        best = d;
        bestAlong = _cum[i] + t * (_cum[i + 1] - _cum[i]);
      }
    }
    return (bestAlong, best);
  }

  int _segIndexFor(double meters) {
    var lo = 0;
    var hi = _cum.length - 1;
    while (lo < hi) {
      final mid = (lo + hi) ~/ 2;
      if (_cum[mid] < meters) {
        lo = mid + 1;
      } else {
        hi = mid;
      }
    }
    return math.max(0, lo - 1);
  }

  double _alongOf(LatLng p) {
    var best = double.infinity;
    var bestIdx = 0;
    for (var i = 0; i < route.length; i++) {
      final d = _m(route[i], p);
      if (d < best) {
        best = d;
        bestIdx = i;
      }
    }
    return _cum.isEmpty ? 0 : _cum[bestIdx];
  }

  void _say(String text) {
    if (voice) NativeBridge.speak(text);
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

String _dir(String? mod) => switch (mod) {
      'left' => 'gira a la izquierda',
      'right' => 'gira a la derecha',
      'slight left' => 'mantente ligeramente a la izquierda',
      'slight right' => 'mantente ligeramente a la derecha',
      'sharp left' => 'gira cerrado a la izquierda',
      'sharp right' => 'gira cerrado a la derecha',
      'uturn' => 'da vuelta en U',
      'straight' => 'sigue derecho',
      _ => 'continúa',
    };

String _side(String? mod) => (mod ?? '').contains('left') ? 'a la izquierda' : 'a la derecha';

String _instruction(String type, String? mod, String name, int? exit) {
  final en = name.isEmpty ? '' : ' en $name';
  final hacia = name.isEmpty ? '' : ' hacia $name';
  switch (type) {
    case 'depart':
      return name.isEmpty ? 'sal hacia tu destino' : 'sal por $name';
    case 'arrive':
      return 'llegarás a tu destino';
    case 'roundabout':
    case 'rotary':
    case 'roundabout turn':
      return 'en la glorieta toma la ${exit ?? 1}ª salida$hacia';
    case 'exit roundabout':
    case 'exit rotary':
      return 'sal de la glorieta$hacia';
    case 'fork':
      return 'mantente ${_side(mod)}$hacia';
    case 'on ramp':
      return 'toma la rampa ${_side(mod)}$hacia';
    case 'off ramp':
      return 'toma la salida ${_side(mod)}$hacia';
    case 'merge':
      return 'incorpórate$hacia';
    case 'new name':
    case 'continue':
      if (mod == null || mod == 'straight') return name.isEmpty ? 'continúa derecho' : 'continúa por $name';
      return '${_dir(mod)}$en';
    default:
      return '${_dir(mod)}$en';
  }
}

IconData _icon(String type, String? mod) {
  if (type == 'arrive') return Icons.flag;
  if (type == 'depart') return Icons.navigation;
  if (type == 'roundabout' || type == 'rotary' || type == 'roundabout turn') return Icons.roundabout_right;
  if (type == 'merge') return Icons.merge;
  if (type == 'fork') return (mod ?? '').contains('left') ? Icons.fork_left : Icons.fork_right;
  if (type == 'on ramp' || type == 'off ramp') return (mod ?? '').contains('left') ? Icons.ramp_left : Icons.ramp_right;
  return switch (mod) {
    'left' => Icons.turn_left,
    'right' => Icons.turn_right,
    'slight left' => Icons.turn_slight_left,
    'slight right' => Icons.turn_slight_right,
    'sharp left' => Icons.turn_sharp_left,
    'sharp right' => Icons.turn_sharp_right,
    'uturn' => Icons.u_turn_left,
    _ => Icons.straight,
  };
}

double _m(LatLng a, LatLng b) => const Distance().as(LengthUnit.Meter, a, b).toDouble();
