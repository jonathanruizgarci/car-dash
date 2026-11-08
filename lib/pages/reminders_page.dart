import 'package:flutter/material.dart';

import '../services/reminders.dart';
import '../widgets/common.dart';

class RemindersPage extends StatelessWidget {
  const RemindersPage({super.key});

  Future<void> _edit(BuildContext context, Reminder? existing) async {
    final r = existing == null
        ? Reminder(id: DateTime.now().millisecondsSinceEpoch.toString(), title: '')
        : Reminder(id: existing.id, title: existing.title, date: existing.date, note: existing.note);
    final title = TextEditingController(text: r.title);
    final note = TextEditingController(text: r.note);
    DateTime? date = r.date;
    final save = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text(existing == null ? 'Nuevo recordatorio' : 'Editar recordatorio'),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Nombre')),
                const SizedBox(height: 8),
                TextField(controller: note, decoration: const InputDecoration(labelText: 'Nota (opcional)')),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Text(date == null ? 'Sin fecha' : 'Fecha: ${fmtDate(date!)}')),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_month),
                      label: const Text('Elegir fecha'),
                      onPressed: () async {
                        final now = DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: date ?? now,
                          firstDate: DateTime(now.year - 2),
                          lastDate: DateTime(now.year + 10),
                        );
                        if (picked != null) setD(() => date = picked);
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            if (existing != null)
              TextButton(
                onPressed: () {
                  RemindersService.I.remove(existing.id);
                  Navigator.pop(ctx, false);
                },
                child: const Text('Eliminar', style: TextStyle(color: Colors.redAccent)),
              ),
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (save != true) return;
    r.title = title.text.trim().isEmpty ? 'Recordatorio' : title.text.trim();
    r.note = note.text.trim();
    r.date = date;
    await RemindersService.I.upsert(r);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: RemindersService.I,
      builder: (context, _) {
        final list = RemindersService.I.sorted;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              'Recordatorios del vehículo',
              trailing: FilledButton.icon(
                onPressed: () => _edit(context, null),
                icon: const Icon(Icons.add),
                label: const Text('Agregar'),
              ),
            ),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 360,
                  mainAxisExtent: 140,
                  crossAxisSpacing: kGap,
                  mainAxisSpacing: kGap,
                ),
                itemCount: list.length,
                itemBuilder: (context, i) {
                  final r = list[i];
                  final days = r.daysLeft;
                  final color = days == null
                      ? cs.onSurfaceVariant
                      : days < 0
                          ? Colors.redAccent
                          : days <= 15
                              ? Colors.orange
                              : Colors.green;
                  final status = days == null
                      ? 'Toca para poner fecha'
                      : days < 0
                          ? 'Vencido hace ${-days} días'
                          : days == 0
                              ? '¡Es hoy!'
                              : 'Faltan $days días';
                  return Panel(
                    onTap: () => _edit(context, r),
                    child: Row(
                      children: [
                        Icon(Icons.event_note, size: 40, color: color),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                              Text(status, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
                              if (r.date != null) Text(fmtDate(r.date!), style: TextStyle(color: cs.onSurfaceVariant)),
                              if (r.note.isNotEmpty)
                                Text(r.note,
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
              ),
            ),
          ],
        );
      },
    );
  }
}
