import 'package:flutter/material.dart';

import '../services/fuel.dart';
import '../services/gps.dart';
import '../services/settings.dart';
import '../widgets/common.dart';

class TripPage extends StatelessWidget {
  const TripPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: GpsService.I,
      builder: (context, _) {
        final g = GpsService.I;
        final kmL = g.tripKmPerL;
        final cost = g.tripFuelL * FuelMath.price;
        final tiles = [
          StatTile(icon: Icons.route, label: 'Distancia', value: fmt(g.tripKm, 1), unit: 'km'),
          StatTile(icon: Icons.timer, label: 'Tiempo en movimiento', value: fmtDuration(g.tripMovingSec)),
          StatTile(icon: Icons.schedule, label: 'Tiempo total', value: fmtDuration(g.tripTotalSec), sub: 'Desde ${fmtDate(g.tripStart)} ${fmtTime(g.tripStart)}'),
          StatTile(icon: Icons.speed, label: 'Velocidad actual', value: fmt(g.speedKmh), unit: 'km/h', sub: g.speedFromObd ? 'OBD2' : g.status),
          StatTile(icon: Icons.av_timer, label: 'Velocidad promedio', value: fmt(g.avgKmh), unit: 'km/h'),
          StatTile(icon: Icons.trending_up, label: 'Velocidad máxima', value: fmt(g.tripMaxKmh), unit: 'km/h'),
          StatTile(
            icon: Icons.local_gas_station,
            label: 'Combustible usado',
            value: fmt(g.tripFuelL, 2),
            unit: 'L',
            sub: g.tripFuelL > 0 ? 'Calculado con el sensor MAF' : 'Requiere OBD2',
          ),
          StatTile(
            icon: Icons.eco,
            label: 'Rendimiento',
            value: fmt(kmL, 1),
            unit: 'km/L',
            sub: kmL == null ? 'Se calcula tras unos km con OBD2' : 'Configurado: ${fmt(Settings.I.kmPerLiter, 1)} km/L',
          ),
          StatTile(icon: Icons.payments, label: 'Costo estimado', value: '\$${fmt(cost, 0)}', unit: 'MXN', sub: 'A \$${fmt(FuelMath.price, 2)}/L'),
        ];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              'Viaje actual',
              trailing: Wrap(
                spacing: 8,
                children: [
                  if (kmL != null)
                    OutlinedButton.icon(
                      onPressed: () {
                        Settings.I.update((s) => s.kmPerLiter = double.parse(kmL!.toStringAsFixed(1)));
                        toast(context, 'Rendimiento guardado: ${fmt(kmL, 1)} km/L');
                      },
                      icon: const Icon(Icons.save),
                      label: const Text('Usar este rendimiento'),
                    ),
                  FilledButton.icon(
                    onPressed: () => g.resetTrip(),
                    icon: const Icon(Icons.restart_alt),
                    label: const Text('Nuevo viaje'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: LayoutBuilder(builder: (context, c) {
                const cols = 3;
                const rows = 3;
                final w = ((c.maxWidth - kGap * (cols - 1)) / cols).clamp(0.0, 4000.0).toDouble();
                final h = ((c.maxHeight - kGap * (rows - 1)) / rows).clamp(0.0, 4000.0).toDouble();
                return Wrap(
                  spacing: kGap,
                  runSpacing: kGap,
                  children: [for (final t in tiles) SizedBox(width: w, height: h, child: t)],
                );
              }),
            ),
          ],
        );
      },
    );
  }
}
