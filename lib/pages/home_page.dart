import 'package:flutter/material.dart';

import '../services/daynight.dart';
import '../services/fuel.dart';
import '../services/gps.dart';
import '../services/music.dart';
import '../services/native.dart';
import '../services/obd.dart';
import '../services/reminders.dart';
import '../services/settings.dart';
import '../services/weather.dart';
import '../widgets/common.dart';
import '../widgets/gauge.dart';

class QuickApp {
  final String name;
  final IconData icon;
  final String pkg;
  final Color color;
  const QuickApp(this.name, this.icon, this.pkg, this.color);
}

const kQuickApps = [
  QuickApp('Waze', Icons.navigation, 'com.waze', Color(0xFF33CCFF)),
  QuickApp('Maps', Icons.map, 'com.google.android.apps.maps', Color(0xFF34A853)),
  QuickApp('Spotify', Icons.music_note, 'com.spotify.music', Color(0xFF1DB954)),
  QuickApp('Android Auto', Icons.directions_car, 'com.andrerinas.headunitrevived', Color(0xFF4285F4)),
  QuickApp('YT Music', Icons.play_circle, 'com.google.android.apps.youtube.music', Color(0xFFFF0000)),
  QuickApp('WhatsApp', Icons.chat, 'com.whatsapp', Color(0xFF25D366)),
];

Future<void> launchQuickApp(BuildContext context, QuickApp app) async {
  final ok = await NativeBridge.launchApp(app.pkg);
  if (!ok && context.mounted) {
    toast(context, '${app.name} no está instalada en esta tableta',
        action: SnackBarAction(
          label: 'Instalar',
          onPressed: () => NativeBridge.openUri('market://details?id=${app.pkg}'),
        ));
  }
}

/// Abre un enlace (ej. waze://) y si la app no está, ofrece instalarla.
Future<void> launchUri(BuildContext context, String uri, QuickApp app) async {
  final ok = await NativeBridge.openUri(uri);
  if (!ok && context.mounted) await launchQuickApp(context, app);
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Expanded(flex: 5, child: _SpeedPanel()),
        const SizedBox(width: kGap),
        const Expanded(flex: 4, child: _StatsColumn()),
        const SizedBox(width: kGap),
        Expanded(
          flex: 4,
          child: Column(
            children: const [
              Expanded(flex: 3, child: _WeatherMini()),
              SizedBox(height: kGap),
              Expanded(flex: 3, child: _MusicCard()),
              SizedBox(height: kGap),
              Expanded(flex: 4, child: _AppsGrid()),
            ],
          ),
        ),
      ],
    );
  }
}

class _SpeedPanel extends StatelessWidget {
  const _SpeedPanel();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([GpsService.I, ObdService.I]),
      builder: (context, _) {
        final gps = GpsService.I;
        final rpm = ObdService.I.value('0C');
        final cs = Theme.of(context).colorScheme;
        return Panel(
          child: Column(
            children: [
              Expanded(
                child: Gauge(
                  value: gps.speedKmh,
                  max: 200,
                  unit: 'km/h',
                  label: gps.speedFromObd ? 'OBD2' : (gps.ok ? 'GPS' : gps.status),
                  warnFrom: 120,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text('RPM', style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: rpm == null ? 0.0 : (rpm / 7000).clamp(0.0, 1.0).toDouble(),
                        minHeight: 12,
                        color: (rpm ?? 0) > 5000 ? Colors.redAccent : cs.primary,
                        backgroundColor: cs.surfaceContainerHighest,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 64,
                    child: Text(fmt(rpm), textAlign: TextAlign.right, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatsColumn extends StatelessWidget {
  const _StatsColumn();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([GpsService.I, ObdService.I, Settings.I, FuelService.I, RemindersService.I]),
      builder: (context, _) {
        final obd = ObdService.I;
        final gps = GpsService.I;
        final temp = obd.value('05');
        final batt = obd.connected ? obd.batteryV : null;
        final next = RemindersService.I.next;
        Widget row(Widget a, Widget b) => Expanded(
              child: Row(children: [Expanded(child: a), const SizedBox(width: kGap), Expanded(child: b)]),
            );
        return Column(
          children: [
            row(
              StatTile(
                icon: Icons.thermostat,
                label: 'Temp. motor',
                value: fmt(temp),
                unit: '°C',
                accent: (temp ?? 0) >= 108 ? Colors.redAccent : null,
              ),
              StatTile(
                icon: Icons.battery_charging_full,
                label: 'Batería',
                value: fmt(batt, 1),
                unit: 'V',
                accent: batt != null && (batt < 12.0 || batt > 15.0) ? Colors.orange : null,
              ),
            ),
            const SizedBox(height: kGap),
            row(
              StatTile(
                icon: Icons.local_gas_station,
                label: 'Autonomía',
                value: fmt(FuelMath.rangeKm),
                unit: 'km',
                sub: '${fmt(FuelMath.pct)} % ${FuelMath.fromObd ? '(OBD2)' : '(manual)'}',
              ),
              StatTile(
                icon: Icons.route,
                label: 'Viaje',
                value: fmt(gps.tripKm, 1),
                unit: 'km',
                sub: 'Prom. ${fmt(gps.avgKmh)} km/h',
              ),
            ),
            const SizedBox(height: kGap),
            row(
              StatTile(
                icon: Icons.warning_amber,
                label: 'Check engine',
                value: !obd.connected ? '--' : (obd.milOn ? 'ON' : 'OK'),
                accent: obd.connected ? (obd.milOn ? Colors.orange : Colors.green) : null,
                sub: obd.connected ? '${obd.dtcCount} código(s)' : obd.message,
              ),
              StatTile(
                icon: Icons.event,
                label: next?.title ?? 'Recordatorios',
                value: next == null ? '--' : '${next.daysLeft}',
                unit: next == null ? '' : 'días',
                accent: next != null && (next.daysLeft ?? 99) <= 15 ? Colors.orange : null,
                sub: next?.date == null ? 'Agrega fechas' : fmtDate(next!.date!),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _WeatherMini extends StatelessWidget {
  const _WeatherMini();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: WeatherService.I,
      builder: (context, _) {
        final w = WeatherService.I;
        final (text, icon) = weatherInfo(w.code, night: DayNight.I.isNightNow);
        final today = w.days.isNotEmpty ? w.days.first : null;
        final cs = Theme.of(context).colorScheme;
        return Panel(
          child: Row(
            children: [
              Icon(icon, size: 52, color: Colors.amber),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      child: Text('${fmt(w.temp)}°',
                          style: const TextStyle(fontSize: 38, fontWeight: FontWeight.w700, height: 1)),
                    ),
                    Text(w.error ?? text, maxLines: 1, overflow: TextOverflow.ellipsis),
                    if (today != null)
                      Text('Máx ${fmt(today.max)}° · Mín ${fmt(today.min)}° · Lluvia ${today.rain}%',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MusicCard extends StatelessWidget {
  const _MusicCard();

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: MusicService.I,
      builder: (context, _) => MusicPlayerCard(compact: true),
    );
  }
}

/// Tarjeta de música con portada, canción, progreso y controles.
class MusicPlayerCard extends StatelessWidget {
  final bool compact;
  const MusicPlayerCard({super.key, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final m = MusicService.I;
    final cs = Theme.of(context).colorScheme;
    final artSize = compact ? 64.0 : 150.0;
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(compact ? 12 : 18),
      child: SizedBox(
        width: artSize,
        height: artSize,
        child: m.art != null
            ? Image.memory(m.art!, fit: BoxFit.cover, gaplessPlayback: true)
            : Container(
                color: const Color(0xFF1DB954),
                child: Icon(Icons.music_note, color: Colors.white, size: artSize * 0.5),
              ),
      ),
    );

    if (!m.hasAccess) {
      return Panel(
        child: Row(
          children: [
            cover,
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Música', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  Text('Activa el permiso para ver la canción y controlar Spotify',
                      maxLines: 2, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                ],
              ),
            ),
            FilledButton(onPressed: () => NativeBridge.openNotifSettings(), child: const Text('Activar')),
          ],
        ),
      );
    }

    final title = m.active && m.title.isNotEmpty ? m.title : 'Nada sonando';
    final sub = m.active ? [m.artist, if (m.sourceName.isNotEmpty) m.sourceName].where((e) => e.isNotEmpty).join(' · ') : 'Toca para abrir Spotify';
    final controls = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(onPressed: () => m.command('prev'), icon: const Icon(Icons.skip_previous), iconSize: compact ? 30 : 40),
        IconButton.filled(
          onPressed: () => m.command('play'),
          icon: Icon(m.playing ? Icons.pause : Icons.play_arrow),
          iconSize: compact ? 32 : 46,
        ),
        IconButton(onPressed: () => m.command('next'), icon: const Icon(Icons.skip_next), iconSize: compact ? 30 : 40),
      ],
    );
    final progress = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: m.progress,
            minHeight: 4,
            color: const Color(0xFF1DB954),
            backgroundColor: cs.surfaceContainerHighest,
          ),
        ),
        if (!compact)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Text(fmtMs(m.positionMs), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                const Spacer(),
                Text(fmtMs(m.durationMs), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ],
            ),
          ),
      ],
    );

    return Panel(
      onTap: () => launchQuickApp(context, kQuickApps[2]),
      child: Row(
        children: [
          cover,
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: compact ? 15 : 22)),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: compact ? 12 : 15, color: cs.onSurfaceVariant)),
                SizedBox(height: compact ? 6 : 12),
                progress,
                if (!compact) ...[const SizedBox(height: 8), Center(child: controls)],
              ],
            ),
          ),
          if (compact) controls,
        ],
      ),
    );
  }
}

class _AppsGrid extends StatelessWidget {
  const _AppsGrid();

  @override
  Widget build(BuildContext context) {
    return Panel(
      padding: const EdgeInsets.all(8),
      child: LayoutBuilder(builder: (context, c) {
        const cols = 3;
        final rows = (kQuickApps.length / cols).ceil();
        final w = ((c.maxWidth - 8 * (cols - 1)) / cols).clamp(0.0, 4000.0).toDouble();
        final h = ((c.maxHeight - 8 * (rows - 1)) / rows).clamp(0.0, 4000.0).toDouble();
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final app in kQuickApps)
              SizedBox(
                width: w,
                height: h,
                child: Material(
                  color: app.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () => launchQuickApp(context, app),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(app.icon, color: app.color, size: 30),
                            const SizedBox(height: 4),
                            Text(app.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      }),
    );
  }
}
