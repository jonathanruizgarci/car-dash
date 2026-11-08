import 'package:flutter/material.dart';

import '../services/dtc.dart';
import '../services/obd.dart';
import '../widgets/common.dart';
import 'engine_page.dart';

class DtcPage extends StatefulWidget {
  const DtcPage({super.key});

  @override
  State<DtcPage> createState() => _DtcPageState();
}

class _DtcPageState extends State<DtcPage> {
  List<String>? stored;
  List<String>? pending;
  bool busy = false;
  String? error;

  Future<void> _read() async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final r = await ObdService.I.readDtcs();
      stored = r['stored'];
      pending = r['pending'];
    } catch (e) {
      error = e.toString().replaceFirst('Exception: ', '');
    }
    if (mounted) setState(() => busy = false);
  }

  Future<void> _clear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Borrar códigos?'),
        content: const Text(
            'Se apagará la luz de check engine y se reiniciarán los monitores de emisiones. '
            'Si la falla sigue, el código volverá a aparecer. No lo hagas justo antes de la verificación.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => busy = true);
    try {
      final done = await ObdService.I.clearDtcs();
      if (mounted) toast(context, done ? 'Códigos borrados' : 'El auto no confirmó el borrado (apaga el motor y deja el switch en ON)');
      await _read();
    } catch (e) {
      if (mounted) toast(context, e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => busy = false);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ObdService.I,
      builder: (context, _) {
        final o = ObdService.I;
        if (!o.connected) return const ObdConnectCard();
        final cs = Theme.of(context).colorScheme;
        final items = <Widget>[];
        void addGroup(String title, List<String>? codes, Color color) {
          if (codes == null) return;
          items.add(SectionTitle('$title (${codes.length})'));
          if (codes.isEmpty) {
            items.add(const Padding(padding: EdgeInsets.only(bottom: 16), child: Text('Sin códigos 👍')));
          }
          for (final c in codes) {
            items.add(Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Panel(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(10)),
                      child: Text(c, style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: color)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dtcDescription(c), style: const TextStyle(fontWeight: FontWeight.w600)),
                          Text(dtcSystem(c), style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ));
          }
        }

        addGroup('Códigos guardados', stored, Colors.orange);
        addGroup('Códigos pendientes', pending, Colors.amber.shade700);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Panel(
              child: Row(
                children: [
                  Icon(Icons.warning_amber, size: 40, color: o.milOn ? Colors.orange : Colors.green),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(o.milOn ? 'Check engine ENCENDIDO' : 'Check engine apagado',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        Text('La computadora reporta ${o.dtcCount} código(s) guardado(s)',
                            style: TextStyle(color: cs.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  if (busy) const Padding(padding: EdgeInsets.all(8), child: CircularProgressIndicator()),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: busy ? null : _clear,
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Borrar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    onPressed: busy ? null : _read,
                    icon: const Icon(Icons.search),
                    label: const Text('Leer códigos'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: kGap),
            if (error != null) Text(error!, style: const TextStyle(color: Colors.redAccent)),
            Expanded(
              child: items.isEmpty
                  ? Center(
                      child: Text('Toca "Leer códigos" para revisar las fallas del auto',
                          style: TextStyle(color: cs.onSurfaceVariant)))
                  : ListView(children: items),
            ),
          ],
        );
      },
    );
  }
}
