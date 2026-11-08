import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pages/dtc_page.dart';
import 'pages/engine_page.dart';
import 'pages/fuel_page.dart';
import 'pages/home_page.dart';
import 'pages/map_page.dart';
import 'pages/reminders_page.dart';
import 'pages/settings_page.dart';
import 'pages/trip_page.dart';
import 'pages/weather_page.dart';
import 'services/daynight.dart';
import 'services/fuel.dart';
import 'services/gps.dart';
import 'services/music.dart';
import 'services/nav.dart';
import 'services/native.dart';
import 'services/obd.dart';
import 'services/reminders.dart';
import 'services/settings.dart';
import 'services/weather.dart';
import 'widgets/common.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  await Settings.I.load();
  await RemindersService.I.load();
  FuelService.I.loadCached();
  NavService.I.init();
  runApp(const AutoPanelApp());

  NativeBridge.keepScreenOn(Settings.I.keepScreenOn);
  WeatherService.I.start();
  DayNight.I.start();
  unawaited(GpsService.I.start());
  ObdService.I.startAuto();
  MusicService.I.start();
}

ThemeData buildTheme(Brightness b) {
  final dark = b == Brightness.dark;
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF0EA5A4), brightness: b);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark ? const Color(0xFF0A1418) : const Color(0xFFEFF4F5),
    visualDensity: VisualDensity.standard,
  );
}

class AutoPanelApp extends StatelessWidget {
  const AutoPanelApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: DayNight.I,
      builder: (context, _) => MaterialApp(
        title: 'AutoPanel',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        themeMode: DayNight.I.dark ? ThemeMode.dark : ThemeMode.light,
        home: const Shell(),
      ),
    );
  }
}

class _Dest {
  final IconData icon;
  final String label;
  const _Dest(this.icon, this.label);
}

const _dests = [
  _Dest(Icons.dashboard, 'Inicio'),
  _Dest(Icons.navigation, 'Navegar'),
  _Dest(Icons.speed, 'Motor'),
  _Dest(Icons.route, 'Viaje'),
  _Dest(Icons.local_gas_station, 'Gasolina'),
  _Dest(Icons.wb_sunny, 'Clima'),
  _Dest(Icons.build_circle, 'Códigos'),
  _Dest(Icons.event_note, 'Pendientes'),
  _Dest(Icons.settings, 'Ajustes'),
];

class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // De regreso en AutoPanel: quitamos el reproductor flotante.
      NativeBridge.hideOverlay();
      MusicService.I.start();
      SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else if (state == AppLifecycleState.paused) {
      // Se abrió otra app (Waze, Maps, Android Auto…): mostramos la música encima.
      if (Settings.I.floatingMusic) NativeBridge.showOverlay();
      MusicService.I.stop();
    }
  }

  static const _pages = [
    HomePage(),
    MapPage(),
    EnginePage(),
    TripPage(),
    FuelPage(),
    WeatherPage(),
    DtcPage(),
    RemindersPage(),
    SettingsPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (index != 0) setState(() => index = 0);
      },
      child: Scaffold(
        body: SafeArea(
          child: Row(
            children: [
              _SideNav(index: index, onTap: (i) => setState(() => index = i)),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 0, kGap, kGap),
                  child: Column(
                    children: [
                      const _TopBar(),
                      Expanded(
                        child: IndexedStack(index: index, sizing: StackFit.expand, children: _pages),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideNav extends StatelessWidget {
  final int index;
  final ValueChanged<int> onTap;
  const _SideNav({required this.index, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      width: 92,
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          for (var i = 0; i < _dests.length; i++)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              child: Material(
                color: i == index ? cs.primaryContainer : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => onTap(i),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 9),
                    child: Column(
                      children: [
                        Icon(_dests[i].icon,
                            size: 26, color: i == index ? cs.onPrimaryContainer : cs.onSurfaceVariant),
                        const SizedBox(height: 3),
                        Text(
                          _dests[i].label,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: i == index ? FontWeight.w700 : FontWeight.w500,
                            color: i == index ? cs.onPrimaryContainer : cs.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _TopBar extends StatefulWidget {
  const _TopBar();

  @override
  State<_TopBar> createState() => _TopBarState();
}

class _TopBarState extends State<_TopBar> {
  late final Stream<DateTime> _clock =
      Stream<DateTime>.periodic(const Duration(seconds: 1), (_) => DateTime.now()).asBroadcastStream();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 52,
      child: ListenableBuilder(
        listenable: Listenable.merge([Settings.I, GpsService.I, ObdService.I, WeatherService.I]),
        builder: (context, _) {
          final o = ObdService.I;
          final g = GpsService.I;
          final w = WeatherService.I;
          final obdColor = switch (o.state) {
            ObdState.connected => Colors.green,
            ObdState.connecting => Colors.amber,
            ObdState.error => Colors.redAccent,
            ObdState.disconnected => cs.onSurfaceVariant,
          };
          return Row(
            children: [
              Icon(Icons.directions_car, color: cs.primary),
              const SizedBox(width: 8),
              Flexible(
                child: Text(Settings.I.vehicleName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              ),
              const Spacer(),
              _badge(Icons.gps_fixed, g.ok ? 'GPS' : g.status, g.ok ? Colors.green : cs.onSurfaceVariant),
              const SizedBox(width: 10),
              _badge(Icons.bluetooth, 'OBD2', obdColor),
              const SizedBox(width: 10),
              if (w.temp != null) _badge(weatherInfo(w.code, night: DayNight.I.dark).$2, '${fmt(w.temp)}°', Colors.amber),
              const SizedBox(width: 14),
              StreamBuilder<DateTime>(
                stream: _clock,
                builder: (context, snap) {
                  final t = snap.data ?? DateTime.now();
                  return Text(fmtTime(t), style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700));
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _badge(IconData icon, String text, Color color) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      );
}
