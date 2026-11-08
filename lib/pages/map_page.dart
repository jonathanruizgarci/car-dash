import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/daynight.dart';
import '../services/fuel.dart';
import '../services/gps.dart';
import '../services/music.dart';
import '../services/nav.dart';
import '../services/obd.dart';
import '../widgets/common.dart';
import 'home_page.dart';

/// Navegador dentro de la app: mapa, búsqueda, ruta y guía por voz, con música a un lado.
class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  final _map = MapController();
  final _search = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  bool _ready = false;
  bool _follow = true;
  bool _headingUp = true;
  bool _showResults = false;

  static const _fallback = LatLng(18.9036, -98.4366); // Atlixco

  @override
  void initState() {
    super.initState();
    GpsService.I.addListener(_onMove);
    NavService.I.addListener(_onNav);
    _focus.addListener(() {
      if (_focus.hasFocus) setState(() => _showResults = true);
    });
  }

  @override
  void dispose() {
    GpsService.I.removeListener(_onMove);
    NavService.I.removeListener(_onNav);
    _debounce?.cancel();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  LatLng? get _me => NavService.I.myPos;

  void _onNav() {
    // Al calcular una ruta nueva, encuadrarla.
    final n = NavService.I;
    if (_ready && n.hasRoute && !n.navigating && !n.routing && !_follow) return;
    if (_ready && n.hasRoute && !n.navigating && !n.routing) {
      _fitRoute();
    }
  }

  void _fitRoute() {
    final n = NavService.I;
    if (!_ready || !n.hasRoute) return;
    _follow = false;
    try {
      _map.fitCamera(CameraFit.bounds(
        bounds: LatLngBounds.fromPoints(n.route),
        padding: const EdgeInsets.fromLTRB(60, 120, 60, 160),
      ));
      _map.rotate(0);
    } catch (_) {}
  }

  void _onMove() {
    if (!_ready || !_follow) return;
    final me = _me;
    if (me == null) return;
    final g = GpsService.I;
    final nav = NavService.I.navigating;
    final heading = g.last?.heading ?? 0;
    final moving = g.speedKmh > 4;
    final zoom = nav ? (g.speedKmh > 70 ? 16.0 : 17.0) : _map.camera.zoom;
    // En navegación, el auto va abajo de la pantalla: centramos un poco adelante.
    final center = nav && moving ? const Distance().offset(me, 90, heading) : me;
    final rotation = _headingUp && nav && moving ? -heading : (_headingUp && nav ? _map.camera.rotation : 0.0);
    try {
      _map.moveAndRotate(center, zoom, rotation);
    } catch (_) {}
  }

  void _recenter() {
    setState(() => _follow = true);
    final me = _me;
    if (me != null && _ready) {
      try {
        _map.moveAndRotate(me, NavService.I.navigating ? 17 : 16, 0);
      } catch (_) {}
    }
  }

  void _onSearchChanged(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () => NavService.I.search(q));
    setState(() => _showResults = true);
  }

  void _choose(Place p) {
    _focus.unfocus();
    _search.text = p.name;
    setState(() => _showResults = false);
    NavService.I.routeTo(p);
  }

  void _gasStations() {
    final f = FuelService.I;
    if (f.nearby.isEmpty) {
      f.refresh();
      toast(context, 'Buscando gasolineras cercanas… vuelve a tocar en unos segundos');
      return;
    }
    final type = 'regular';
    NavService.I.showPlaces(f.nearby
        .map((s) => Place(
              s.name,
              '${fmtDist(s.km * 1000)} · Magna \$${s.prices[type]?.toStringAsFixed(2) ?? '--'}'
              '${s.prices['premium'] != null ? ' · Premium \$${s.prices['premium']!.toStringAsFixed(2)}' : ''}',
              LatLng(s.lat, s.lon),
            ))
        .toList());
    setState(() => _showResults = true);
  }

  Future<void> _favoriteMenu(Place p) async {
    final which = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.home), title: const Text('Guardar como Casa'), onTap: () => Navigator.pop(ctx, 'home')),
            ListTile(leading: const Icon(Icons.work), title: const Text('Guardar como Trabajo'), onTap: () => Navigator.pop(ctx, 'work')),
          ],
        ),
      ),
    );
    if (which != null) {
      await NavService.I.setFavorite(which, p);
      if (mounted) toast(context, 'Guardado como ${which == 'home' ? 'Casa' : 'Trabajo'}');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: ListenableBuilder(
              listenable: Listenable.merge([NavService.I, GpsService.I, DayNight.I]),
              builder: (context, _) => _mapStack(context),
            ),
          ),
        ),
        const SizedBox(width: kGap),
        const SizedBox(width: 350, child: _SidePanel()),
      ],
    );
  }

  Widget _mapStack(BuildContext context) {
    final n = NavService.I;
    final g = GpsService.I;
    final me = _me;
    final dark = DayNight.I.dark;
    final cs = Theme.of(context).colorScheme;
    final heading = g.last?.heading ?? 0;

    final markers = <Marker>[
      for (final p in n.results)
        Marker(
          point: p.point,
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () => _choose(p),
            child: const Icon(Icons.location_on, color: Colors.deepOrange, size: 34),
          ),
        ),
      if (n.destination != null)
        Marker(
          point: n.destination!.point,
          width: 46,
          height: 46,
          child: const Icon(Icons.flag_circle, color: Colors.redAccent, size: 44),
        ),
      if (me != null)
        Marker(
          point: me,
          width: 54,
          height: 54,
          child: Transform.rotate(
            angle: heading * math.pi / 180,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 6)],
                border: Border.all(color: const Color(0xFF1A73E8), width: 3),
              ),
              child: const Icon(Icons.navigation, color: Color(0xFF1A73E8), size: 30),
            ),
          ),
        ),
    ];

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: me ?? _fallback,
            initialZoom: 15,
            maxZoom: 19,
            minZoom: 4,
            onMapReady: () {
              _ready = true;
              _onMove();
            },
            onPositionChanged: (camera, hasGesture) {
              if (hasGesture && _follow) setState(() => _follow = false);
            },
            onTap: (_, __) {
              _focus.unfocus();
              if (_showResults) setState(() => _showResults = false);
            },
            onLongPress: (_, point) {
              if (n.navigating) return;
              NavService.I.routeTo(Place('Punto en el mapa', '', point));
            },
          ),
          children: [
            TileLayer(
              urlTemplate: dark
                  ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}.png'
                  : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'mx.autopanel.autopanel',
              maxZoom: 20,
            ),
            if (n.hasRoute)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: n.route,
                    strokeWidth: 9,
                    color: const Color(0xFF1A73E8),
                    borderStrokeWidth: 3,
                    borderColor: dark ? Colors.black54 : Colors.white,
                  ),
                ],
              ),
            MarkerLayer(markers: markers),
          ],
        ),

        // Arriba: búsqueda o instrucción
        Positioned(
          left: 12,
          top: 12,
          right: 76,
          child: n.navigating ? _maneuverBanner(cs) : _searchBox(cs),
        ),

        // Botones del mapa
        Positioned(
          right: 12,
          top: 12,
          child: Column(
            children: [
              _roundBtn(Icons.add, () => _zoom(1)),
              const SizedBox(height: 8),
              _roundBtn(Icons.remove, () => _zoom(-1)),
              const SizedBox(height: 8),
              _roundBtn(_headingUp ? Icons.explore : Icons.explore_outlined, () {
                setState(() => _headingUp = !_headingUp);
                if (!_headingUp && _ready) _map.rotate(0);
                toast(context, _headingUp ? 'El mapa gira con tu dirección' : 'Norte arriba');
              }),
              const SizedBox(height: 8),
              _roundBtn(n.voice ? Icons.volume_up : Icons.volume_off, () => n.setVoice(!n.voice)),
            ],
          ),
        ),
        if (!_follow)
          Positioned(
            right: 12,
            bottom: n.navigating || n.hasRoute ? 120 : 24,
            child: FloatingActionButton.extended(
              heroTag: 'recenter',
              onPressed: _recenter,
              icon: const Icon(Icons.my_location),
              label: const Text('Centrar'),
            ),
          ),

        // Abajo: vista previa de ruta o datos de navegación
        if (n.routing)
          const Positioned(left: 12, right: 12, bottom: 12, child: Panel(child: LinearProgressIndicator())),
        if (!n.routing && n.routeError != null && !n.navigating)
          Positioned(left: 12, right: 12, bottom: 12, child: Panel(child: Text(n.routeError!))),
        if (!n.routing && n.hasRoute && !n.navigating && !n.arrived)
          Positioned(left: 12, right: 12, bottom: 12, child: _routePreview(cs)),
        if (n.navigating) Positioned(left: 12, right: 12, bottom: 12, child: _navBar(cs)),
        if (n.arrived)
          Positioned(
            left: 12,
            right: 12,
            bottom: 12,
            child: Panel(
              child: Row(
                children: [
                  const Icon(Icons.flag, color: Colors.green, size: 36),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text('Llegaste a ${n.destination?.name ?? 'tu destino'}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                  FilledButton(onPressed: n.stop, child: const Text('Listo')),
                ],
              ),
            ),
          ),

        Positioned(
          left: 8,
          bottom: 2,
          child: Text('© OpenStreetMap · © CARTO · OSRM',
              style: TextStyle(fontSize: 9, color: dark ? Colors.white54 : Colors.black45)),
        ),
      ],
    );
  }

  void _zoom(double d) {
    if (!_ready) return;
    try {
      _map.move(_map.camera.center, (_map.camera.zoom + d).clamp(4, 19).toDouble());
    } catch (_) {}
  }

  Widget _roundBtn(IconData icon, VoidCallback onTap) => Material(
        color: Theme.of(context).colorScheme.surface,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(12), child: Icon(icon, size: 26)),
        ),
      );

  Widget _searchBox(ColorScheme cs) {
    final n = NavService.I;
    final quick = <Widget>[
      if (n.home != null) _chip(Icons.home, 'Casa', () => _choose(n.home!)),
      if (n.work != null) _chip(Icons.work, 'Trabajo', () => _choose(n.work!)),
      _chip(Icons.local_gas_station, 'Gasolineras', _gasStations),
      if (n.recents.isNotEmpty)
        _chip(Icons.history, 'Recientes', () {
          n.showPlaces(n.recents);
          setState(() => _showResults = true);
        }),
    ];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 520),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            elevation: 4,
            borderRadius: BorderRadius.circular(28),
            color: cs.surface,
            child: TextField(
              controller: _search,
              focusNode: _focus,
              onChanged: _onSearchChanged,
              onSubmitted: (q) => NavService.I.search(q),
              textInputAction: TextInputAction.search,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                hintText: '¿A dónde vamos?',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty && !n.hasRoute
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _search.clear();
                          n.clearResults();
                          n.stop();
                          setState(() => _showResults = false);
                        },
                      ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: quick)),
          if (_showResults && (n.searching || n.results.isNotEmpty || n.searchError != null))
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Material(
                elevation: 4,
                borderRadius: BorderRadius.circular(18),
                color: cs.surface,
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 330),
                  child: n.searching && n.results.isEmpty
                      ? const Padding(padding: EdgeInsets.all(16), child: LinearProgressIndicator())
                      : n.results.isEmpty
                          ? Padding(padding: const EdgeInsets.all(16), child: Text(n.searchError ?? ''))
                          : ListView.separated(
                              shrinkWrap: true,
                              padding: EdgeInsets.zero,
                              itemCount: n.results.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final p = n.results[i];
                                return ListTile(
                                  leading: const Icon(Icons.place),
                                  title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(p.detail, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  trailing: IconButton(
                                    icon: const Icon(Icons.star_border),
                                    tooltip: 'Guardar',
                                    onPressed: () => _favoriteMenu(p),
                                  ),
                                  onTap: () => _choose(p),
                                );
                              },
                            ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String label, VoidCallback onTap) => Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ActionChip(
          avatar: Icon(icon, size: 18),
          label: Text(label),
          onPressed: onTap,
          elevation: 2,
        ),
      );

  Widget _routePreview(ColorScheme cs) {
    final n = NavService.I;
    return Panel(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(n.destination?.name ?? 'Destino',
                    maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  '${fmtMinutes(n.routeSeconds)} · ${fmtDist(n.routeMeters)} · llegas a las ${fmtTime(n.eta)}',
                  style: TextStyle(fontSize: 15, color: cs.primary, fontWeight: FontWeight.w600),
                ),
                Text('Sin datos de tráfico en tiempo real',
                    style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          TextButton(onPressed: n.stop, child: const Text('Cancelar')),
          const SizedBox(width: 8),
          FilledButton.icon(
            onPressed: () {
              n.start();
              setState(() => _follow = true);
              _onMove();
            },
            icon: const Icon(Icons.navigation),
            label: const Text('Iniciar', style: TextStyle(fontSize: 18)),
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16)),
          ),
        ],
      ),
    );
  }

  Widget _maneuverBanner(ColorScheme cs) {
    final n = NavService.I;
    final step = n.nextStep;
    final then = n.afterNext;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Material(
            color: const Color(0xFF0B7A55),
            borderRadius: BorderRadius.circular(18),
            elevation: 6,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
              child: Row(
                children: [
                  Icon(step?.icon ?? Icons.straight, color: Colors.white, size: 58),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(fmtDist(n.distToNext),
                            style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800, height: 1.1)),
                        Text(
                          step == null ? 'Sigue la ruta' : _capitalize(step.text),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (then != null && step != null && then.along - step.along < 400)
            Padding(
              padding: const EdgeInsets.only(top: 6, left: 8),
              child: Material(
                color: const Color(0xFF075E42),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Luego ', style: TextStyle(color: Colors.white70)),
                      Icon(then.icon, color: Colors.white, size: 22),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _navBar(ColorScheme cs) {
    final n = NavService.I;
    final g = GpsService.I;
    return Panel(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: g.speedKmh > 110 ? Colors.redAccent : cs.outline, width: 3),
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(fmt(g.speedKmh), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1)),
                const Text('km/h', style: TextStyle(fontSize: 10)),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(fmtTime(n.eta), style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: cs.primary)),
                Text('${fmtMinutes(n.remainingSeconds)} · ${fmtDist(n.remainingMeters)}',
                    style: TextStyle(fontSize: 15, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
          if (n.routing) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
          OutlinedButton.icon(
            onPressed: _fitRoute,
            icon: const Icon(Icons.alt_route),
            label: const Text('Ver ruta'),
          ),
          const SizedBox(width: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              n.stop();
              _search.clear();
            },
            icon: const Icon(Icons.close),
            label: const Text('Terminar'),
          ),
        ],
      ),
    );
  }
}

String _capitalize(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

/// Panel lateral: música, datos del auto y opciones.
class _SidePanel extends StatelessWidget {
  const _SidePanel();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([MusicService.I, ObdService.I, GpsService.I, NavService.I]),
      builder: (context, _) {
        final o = ObdService.I;
        final n = NavService.I;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Expanded(flex: 5, child: _SideMusic()),
            const SizedBox(height: kGap),
            SizedBox(
              height: 92,
              child: Row(
                children: [
                  Expanded(
                    child: StatTile(icon: Icons.local_gas_station, label: 'Autonomía', value: fmt(FuelMath.rangeKm), unit: 'km'),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: StatTile(
                      icon: Icons.thermostat,
                      label: 'Motor',
                      value: fmt(o.value('05')),
                      unit: '°C',
                      accent: (o.value('05') ?? 0) >= 108 ? Colors.redAccent : null,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: kGap),
            Expanded(
              flex: 4,
              child: Panel(
                padding: const EdgeInsets.all(8),
                child: GridView.count(
                  crossAxisCount: 3,
                  mainAxisSpacing: 6,
                  crossAxisSpacing: 6,
                  childAspectRatio: 1.15,
                  children: [
                    _opt(context, Icons.navigation, 'Waze', const Color(0xFF33CCFF), () {
                      final d = n.destination;
                      if (d != null) {
                        launchUri(context, 'waze://?ll=${d.point.latitude},${d.point.longitude}&navigate=yes', kQuickApps[0]);
                      } else {
                        launchQuickApp(context, kQuickApps[0]);
                      }
                    }),
                    _opt(context, Icons.map, 'Google Maps', const Color(0xFF34A853), () {
                      final d = n.destination;
                      if (d != null) {
                        launchUri(context, 'google.navigation:q=${d.point.latitude},${d.point.longitude}', kQuickApps[1]);
                      } else {
                        launchQuickApp(context, kQuickApps[1]);
                      }
                    }),
                    _opt(context, Icons.directions_car, 'Android Auto', const Color(0xFF4285F4),
                        () => launchQuickApp(context, kQuickApps[3])),
                    _opt(context, n.voice ? Icons.record_voice_over : Icons.voice_over_off, n.voice ? 'Voz activa' : 'Voz apagada',
                        cs.primary, () => n.setVoice(!n.voice)),
                    _opt(context, Icons.music_note, 'Spotify', const Color(0xFF1DB954), () => launchQuickApp(context, kQuickApps[2])),
                    _opt(context, Icons.chat, 'WhatsApp', const Color(0xFF25D366), () => launchQuickApp(context, kQuickApps[5])),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _opt(BuildContext context, IconData icon, String label, Color color, VoidCallback onTap) => Material(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: color, size: 28),
                  const SizedBox(height: 4),
                  Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ),
      );
}

/// Música vertical para el panel lateral.
class _SideMusic extends StatelessWidget {
  const _SideMusic();

  @override
  Widget build(BuildContext context) {
    final m = MusicService.I;
    final cs = Theme.of(context).colorScheme;
    if (!m.hasAccess) return const MusicPlayerCard(compact: true);
    return Panel(
      onTap: () => launchQuickApp(context, kQuickApps[2]),
      child: LayoutBuilder(builder: (context, c) {
        final art = math.max(0.0, math.min(c.maxWidth, c.maxHeight - 112));
        return Column(
          children: [
            Expanded(
              child: Center(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: art,
                    height: art,
                    child: m.art != null
                        ? Image.memory(m.art!, fit: BoxFit.cover, gaplessPlayback: true)
                        : Container(
                            color: const Color(0xFF1DB954),
                            child: Icon(Icons.music_note, color: Colors.white, size: art * 0.45),
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(m.active && m.title.isNotEmpty ? m.title : 'Nada sonando',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
            Text(m.active ? m.artist : 'Toca para abrir Spotify',
                maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: m.progress,
                minHeight: 4,
                color: const Color(0xFF1DB954),
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(onPressed: () => m.command('prev'), icon: const Icon(Icons.skip_previous), iconSize: 32),
                IconButton.filled(
                  onPressed: () => m.command('play'),
                  icon: Icon(m.playing ? Icons.pause : Icons.play_arrow),
                  iconSize: 34,
                ),
                IconButton(onPressed: () => m.command('next'), icon: const Icon(Icons.skip_next), iconSize: 32),
              ],
            ),
          ],
        );
      }),
    );
  }
}
