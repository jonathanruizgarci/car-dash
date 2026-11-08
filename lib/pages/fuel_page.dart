import 'package:flutter/material.dart';

import '../services/fuel.dart';
import '../services/native.dart';
import '../services/obd.dart';
import '../services/settings.dart';
import '../widgets/common.dart';

const kFuelNames = {'regular': 'Magna (regular)', 'premium': 'Premium', 'diesel': 'Diésel'};

class FuelPage extends StatefulWidget {
  const FuelPage({super.key});

  @override
  State<FuelPage> createState() => _FuelPageState();
}

class _FuelPageState extends State<FuelPage> {
  @override
  void initState() {
    super.initState();
    if (FuelService.I.stale) {
      Future.delayed(const Duration(seconds: 8), () => FuelService.I.refresh());
    }
  }

  void _navigate(Station s) async {
    final ok = await NativeBridge.openUri('waze://?ll=${s.lat},${s.lon}&navigate=yes');
    if (!ok) {
      await NativeBridge.openUri('https://www.google.com/maps/dir/?api=1&destination=${s.lat},${s.lon}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([Settings.I, FuelService.I, ObdService.I]),
      builder: (context, _) {
        final s = Settings.I;
        final f = FuelService.I;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 4,
              child: ListView(
                children: [
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Autonomía estimada', style: TextStyle(color: cs.onSurfaceVariant)),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(fmt(FuelMath.rangeKm), style: const TextStyle(fontSize: 64, fontWeight: FontWeight.w800)),
                            const SizedBox(width: 6),
                            const Text('km', style: TextStyle(fontSize: 22)),
                          ],
                        ),
                        const SizedBox(height: 6),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: (FuelMath.pct / 100).clamp(0.0, 1.0).toDouble(),
                            minHeight: 14,
                            color: FuelMath.pct < 15 ? Colors.redAccent : cs.primary,
                            backgroundColor: cs.surfaceContainerHighest,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '${fmt(FuelMath.pct)} % · ${fmt(FuelMath.liters, 1)} L de ${fmt(s.tankLiters)} L · '
                          '${fmt(s.kmPerLiter, 1)} km/L ${FuelMath.fromObd ? '· nivel del OBD2' : ''}',
                          style: TextStyle(color: cs.onSurfaceVariant),
                        ),
                        if (!FuelMath.fromObd) ...[
                          const SizedBox(height: 10),
                          const Text('Nivel del tanque (ajústalo a mano)'),
                          Slider(
                            value: s.manualFuelPct.clamp(0, 100).toDouble(),
                            min: 0,
                            max: 100,
                            divisions: 20,
                            label: '${fmt(s.manualFuelPct)} %',
                            onChanged: (v) => s.update((x) => x.manualFuelPct = v),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: kGap),
                  Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('Costo'),
                        _row('Combustible', kFuelNames[s.fuelType] ?? s.fuelType),
                        _row('Precio', '\$${fmt(FuelMath.price, 2)} / L ${FuelMath.priceFromCre ? '(CRE, más cercana)' : '(manual)'}'),
                        _row('Llenar el tanque', '\$${fmt(FuelMath.costToFill, 0)}'),
                        _row('Costo por km', '\$${fmt(FuelMath.price / (s.kmPerLiter <= 0 ? 1 : s.kmPerLiter), 2)}'),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final e in kFuelNames.entries)
                              ChoiceChip(
                                label: Text(e.value),
                                selected: s.fuelType == e.key,
                                onSelected: (_) => s.update((x) => x.fuelType = e.key),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: kGap),
            Expanded(
              flex: 5,
              child: Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionTitle(
                      'Gasolineras cercanas',
                      trailing: f.loading
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : IconButton(onPressed: () => f.refresh(), icon: const Icon(Icons.refresh)),
                    ),
                    Text(
                      f.updated == null
                          ? 'Precios oficiales de la CRE'
                          : 'Precios CRE · actualizado ${fmtDate(f.updated!)} ${fmtTime(f.updated!)} · toca una para ir con Waze',
                      style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                    ),
                    if (f.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(f.error!, style: const TextStyle(color: Colors.orange)),
                      ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: f.nearby.isEmpty
                          ? Center(
                              child: Text(f.loading ? 'Descargando precios… (puede tardar)' : 'Toca ↻ para buscar',
                                  style: TextStyle(color: cs.onSurfaceVariant)))
                          : ListView.separated(
                              itemCount: f.nearby.length,
                              separatorBuilder: (_, __) => const Divider(height: 1),
                              itemBuilder: (context, i) {
                                final st = f.nearby[i];
                                final p = st.prices[s.fuelType];
                                return ListTile(
                                  onTap: () => _navigate(st),
                                  leading: CircleAvatar(
                                    backgroundColor: cs.primaryContainer,
                                    child: Icon(Icons.local_gas_station, color: cs.onPrimaryContainer),
                                  ),
                                  title: Text(st.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: Text(
                                    '${fmt(st.km, 1)} km · '
                                    '${st.prices.entries.map((e) => '${e.key[0].toUpperCase()}${e.key.substring(1)} \$${e.value.toStringAsFixed(2)}').join('  ')}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: Text(
                                    p == null ? '--' : '\$${p.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          children: [
            Expanded(child: Text(a)),
            Text(b, style: const TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
      );
}
