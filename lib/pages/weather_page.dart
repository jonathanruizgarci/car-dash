import 'package:flutter/material.dart';

import '../services/weather.dart';
import '../widgets/common.dart';

class WeatherPage extends StatelessWidget {
  const WeatherPage({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: WeatherService.I,
      builder: (context, _) {
        final w = WeatherService.I;
        final (text, icon) = weatherInfo(w.code);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 4,
              child: Panel(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, size: 96, color: Colors.amber),
                    FittedBox(
                      child: Text('${fmt(w.temp)}°', style: const TextStyle(fontSize: 88, fontWeight: FontWeight.w800)),
                    ),
                    Text(w.error ?? text, style: const TextStyle(fontSize: 20)),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 18,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        _chip(Icons.thermostat, 'Sensación ${fmt(w.feels)}°'),
                        _chip(Icons.water_drop, 'Humedad ${fmt(w.humidity)}%'),
                        _chip(Icons.air, 'Viento ${fmt(w.wind)} km/h'),
                        if (w.sunrise != null) _chip(Icons.wb_twilight, 'Amanecer ${fmtTime(w.sunrise!)}'),
                        if (w.sunset != null) _chip(Icons.nights_stay, 'Atardecer ${fmtTime(w.sunset!)}'),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: w.loading ? null : () => w.refresh(),
                      icon: const Icon(Icons.refresh),
                      label: Text(w.updated == null ? 'Actualizar' : 'Actualizado ${fmtTime(w.updated!)}'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: kGap),
            Expanded(
              flex: 6,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 150,
                    child: Panel(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: w.hours.length,
                        itemBuilder: (context, i) {
                          final h = w.hours[i];
                          final (_, hIcon) = weatherInfo(h.code, night: h.time.hour < 7 || h.time.hour >= 19);
                          return SizedBox(
                            width: 74,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                Text(i == 0 ? 'Ahora' : '${two(h.time.hour)}:00',
                                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                                Icon(hIcon, color: Colors.amber),
                                Text('${fmt(h.temp)}°', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                                Text('${h.rain}%', style: TextStyle(fontSize: 11, color: Colors.lightBlue.shade300)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: kGap),
                  Expanded(
                    child: Panel(
                      child: ListView.separated(
                        itemCount: w.days.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final d = w.days[i];
                          final (dText, dIcon) = weatherInfo(d.code);
                          return ListTile(
                            leading: Icon(dIcon, color: Colors.amber),
                            title: Text(i == 0 ? 'Hoy' : '${kDias[d.date.weekday - 1]} ${d.date.day}'),
                            subtitle: Text('$dText · lluvia ${d.rain}%'),
                            trailing: Text('${fmt(d.max)}° / ${fmt(d.min)}°',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _chip(IconData i, String t) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(i, size: 18), const SizedBox(width: 4), Text(t)],
      );
}
