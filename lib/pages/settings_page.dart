import 'package:flutter/material.dart';

import '../services/native.dart';
import '../services/obd.dart';
import '../services/settings.dart';
import '../widgets/common.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  List<BtDevice> devices = [];
  bool loadingDevices = false;

  Future<void> _loadDevices() async {
    setState(() => loadingDevices = true);
    if (!await NativeBridge.hasBtPermission()) {
      await NativeBridge.requestBtPermission();
      await Future.delayed(const Duration(seconds: 3));
    }
    final list = await NativeBridge.bondedDevices();
    if (!mounted) return;
    setState(() {
      devices = list;
      loadingDevices = false;
    });
    if (list.isEmpty) {
      toast(context, 'No hay equipos emparejados. Empareja el OBD2 en Ajustes > Bluetooth de la tableta.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: Listenable.merge([Settings.I, ObdService.I]),
      builder: (context, _) {
        final s = Settings.I;
        final o = ObdService.I;
        return ListView(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionTitle('Adaptador OBD2 (Bluetooth)'),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            o.connected ? Icons.bluetooth_connected : Icons.bluetooth,
                            color: o.connected ? Colors.green : cs.onSurfaceVariant,
                          ),
                          title: Text(s.obdName.isEmpty ? 'Ninguno elegido' : s.obdName),
                          subtitle: Text(o.message),
                          trailing: o.connected
                              ? OutlinedButton(onPressed: () => o.disconnect(), child: const Text('Desconectar'))
                              : FilledButton(
                                  onPressed: s.obdAddress.isEmpty || o.state == ObdState.connecting ? null : () => o.connect(),
                                  child: const Text('Conectar'),
                                ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Conectar automáticamente'),
                          value: s.autoConnectObd,
                          onChanged: (v) => s.update((x) => x.autoConnectObd = v),
                        ),
                        const SizedBox(height: 4),
                        OutlinedButton.icon(
                          onPressed: loadingDevices ? null : _loadDevices,
                          icon: const Icon(Icons.search),
                          label: const Text('Elegir adaptador emparejado'),
                        ),
                        for (final d in devices)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.memory),
                            title: Text(d.name),
                            subtitle: Text(d.address),
                            trailing: s.obdAddress == d.address ? const Icon(Icons.check_circle, color: Colors.green) : null,
                            onTap: () async {
                              await o.disconnect();
                              await s.update((x) {
                                x.obdAddress = d.address;
                                x.obdName = d.name;
                              });
                              await o.connect();
                            },
                          ),
                        const SizedBox(height: 8),
                        Text(
                          'Funciona con adaptadores ELM327 Bluetooth clásico (Vgate iCar2, Vgate iCar Pro Bluetooth 3.0, '
                          'Konnwei, etc.). Los modelos "BLE / 4.0" que solo funcionan con iPhone todavía no son compatibles.',
                          style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: kGap),
                Expanded(
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionTitle('Vehículo'),
                        _tile(context, Icons.directions_car, 'Nombre', s.vehicleName, () async {
                          final v = await askText(context, 'Nombre del vehículo', s.vehicleName);
                          if (v != null && v.isNotEmpty) s.update((x) => x.vehicleName = v);
                        }),
                        _tile(context, Icons.propane_tank, 'Capacidad del tanque', '${fmt(s.tankLiters)} L', () async {
                          final v = await askNumber(context, 'Capacidad del tanque', s.tankLiters, unit: 'L');
                          if (v != null && v > 0) s.update((x) => x.tankLiters = v);
                        }),
                        _tile(context, Icons.eco, 'Rendimiento', '${fmt(s.kmPerLiter, 1)} km/L', () async {
                          final v = await askNumber(context, 'Rendimiento', s.kmPerLiter, unit: 'km/L');
                          if (v != null && v > 0) s.update((x) => x.kmPerLiter = v);
                        }),
                        _tile(context, Icons.attach_money, 'Precio manual de gasolina', '\$${fmt(s.manualPrice, 2)} / L', () async {
                          final v = await askNumber(context, 'Precio por litro', s.manualPrice, unit: 'MXN');
                          if (v != null && v > 0) s.update((x) => x.manualPrice = v);
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: kGap),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SectionTitle('Pantalla'),
                        const Text('Tema'),
                        const SizedBox(height: 6),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'auto', label: Text('Automático'), icon: Icon(Icons.brightness_auto)),
                            ButtonSegment(value: 'day', label: Text('Día'), icon: Icon(Icons.light_mode)),
                            ButtonSegment(value: 'night', label: Text('Noche'), icon: Icon(Icons.dark_mode)),
                          ],
                          selected: {s.themeMode},
                          onSelectionChanged: (sel) => s.update((x) => x.themeMode = sel.first),
                        ),
                        const SizedBox(height: 6),
                        Text('Automático cambia según el amanecer y el atardecer de tu ubicación.',
                            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Mantener la pantalla encendida'),
                          value: s.keepScreenOn,
                          onChanged: (v) {
                            s.update((x) => x.keepScreenOn = v);
                            NativeBridge.keepScreenOn(v);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: kGap),
                Expanded(
                  child: Panel(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SectionTitle('Usar como pantalla de inicio'),
                        Text(
                          '1. Presiona el botón de inicio (casita) de la tableta.\n'
                          '2. Elige "AutoPanel" y luego "Siempre".\n'
                          '3. Si no pregunta: Ajustes > Aplicaciones > Apps predeterminadas > App de inicio > AutoPanel.\n\n'
                          'Para Android Auto instala "Headunit Revived" en la tableta: aparece como botón en Inicio.',
                          style: TextStyle(color: cs.onSurfaceVariant, height: 1.4),
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => NativeBridge.openUri('market://details?id=com.andrerinas.headunitrevived'),
                          icon: const Icon(Icons.download),
                          label: const Text('Instalar Headunit Revived'),
                        ),
                        const SizedBox(height: 8),
                        Text('AutoPanel v1.1', style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _tile(BuildContext context, IconData icon, String title, String value, VoidCallback onTap) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        onTap: onTap,
      );
}
