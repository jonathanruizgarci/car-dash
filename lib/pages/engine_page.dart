import 'package:flutter/material.dart';

import '../services/obd.dart';
import '../services/pids.dart';
import '../widgets/common.dart';
import '../widgets/gauge.dart';

class ObdConnectCard extends StatelessWidget {
  const ObdConnectCard({super.key});

  @override
  Widget build(BuildContext context) {
    final o = ObdService.I;
    final cs = Theme.of(context).colorScheme;
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Panel(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.bluetooth_searching, size: 56, color: cs.primary),
              const SizedBox(height: 12),
              const Text('Adaptador OBD2', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(o.message, textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                'Conecta el Vgate/ELM327 al puerto OBD2 (abajo del volante), enciende el auto, '
                'emparéjalo en los ajustes de Bluetooth de la tableta (PIN 1234 o 0000) y elígelo en Ajustes.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: o.state == ObdState.connecting ? null : () => o.connect(),
                icon: o.state == ObdState.connecting
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.link),
                label: Text(o.state == ObdState.connecting ? 'Conectando…' : 'Conectar'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EnginePage extends StatelessWidget {
  const EnginePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ObdService.I,
      builder: (context, _) {
        final o = ObdService.I;
        if (!o.connected) return const ObdConnectCard();
        final pids = kPids.where((p) => o.values.containsKey(p.pid)).toList();
        final temp = o.values['05'] ?? 0;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 220,
              child: Row(
                children: [
                  Expanded(child: Panel(child: Gauge(value: o.values['0C'] ?? 0, max: 7000, unit: 'rpm', label: 'x1000', warnFrom: 5500))),
                  const SizedBox(width: kGap),
                  Expanded(child: Panel(child: Gauge(value: o.values['0D'] ?? 0, max: 200, unit: 'km/h'))),
                  const SizedBox(width: kGap),
                  Expanded(child: Panel(child: Gauge(value: temp, max: 130, unit: '°C', label: 'Motor', warnFrom: 108))),
                  const SizedBox(width: kGap),
                  Expanded(
                    child: StatTile(
                      icon: Icons.battery_charging_full,
                      label: 'Batería',
                      value: fmt(o.batteryV, 1),
                      unit: 'V',
                      sub: (o.batteryV ?? 0) >= 13.3 ? 'Alternador cargando' : 'Revisa con motor encendido',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: kGap),
            Text(
              '${o.supported.length} sensores reportados por el auto · ${pids.length} leídos · ${o.protocol}  —  toca un dato para ver qué significa',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 240,
                  mainAxisExtent: 104,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: pids.length,
                itemBuilder: (context, i) {
                  final p = pids[i];
                  return StatTile(
                    icon: Icons.sensors,
                    label: p.name,
                    value: fmt(o.values[p.pid], p.decimals),
                    unit: p.unit,
                    sub: 'PID ${p.pid}',
                    onTap: () => showDialog<void>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(p.name),
                        content: Text('${p.help}\n\nValor actual: ${fmt(o.values[p.pid], p.decimals)} ${p.unit}'),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Entendido'))],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}
