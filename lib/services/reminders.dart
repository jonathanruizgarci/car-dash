import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'settings.dart';

class Reminder {
  String id;
  String title;
  DateTime? date;
  String note;
  Reminder({required this.id, required this.title, this.date, this.note = ''});

  int? get daysLeft {
    final d = date;
    if (d == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(d.year, d.month, d.day).difference(today).inDays;
  }

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'date': date?.toIso8601String(), 'note': note};

  static Reminder fromJson(Map<String, dynamic> j) => Reminder(
        id: j['id'] as String,
        title: j['title'] as String,
        date: j['date'] == null ? null : DateTime.parse(j['date'] as String),
        note: (j['note'] as String?) ?? '',
      );
}

/// Recordatorios: verificación, tenencia, seguro, servicio…
class RemindersService extends ChangeNotifier {
  RemindersService._();
  static final RemindersService I = RemindersService._();

  List<Reminder> items = [];

  Future<void> load() async {
    final raw = Settings.I.prefs.getString('reminders');
    if (raw == null) {
      items = [
        Reminder(id: 'verif', title: 'Verificación'),
        Reminder(id: 'tenencia', title: 'Tenencia / refrendo'),
        Reminder(id: 'seguro', title: 'Seguro'),
        Reminder(id: 'servicio', title: 'Servicio (aceite y filtros)'),
      ];
      return;
    }
    try {
      items = (jsonDecode(raw) as List).map((e) => Reminder.fromJson(Map<String, dynamic>.from(e as Map))).toList();
    } catch (_) {
      items = [];
    }
  }

  List<Reminder> get sorted {
    final l = [...items];
    l.sort((a, b) => (a.daysLeft ?? 99999).compareTo(b.daysLeft ?? 99999));
    return l;
  }

  Reminder? get next {
    for (final r in sorted) {
      if (r.daysLeft != null) return r;
    }
    return null;
  }

  Future<void> upsert(Reminder r) async {
    final i = items.indexWhere((e) => e.id == r.id);
    if (i >= 0) {
      items[i] = r;
    } else {
      items.add(r);
    }
    await _save();
  }

  Future<void> remove(String id) async {
    items.removeWhere((e) => e.id == id);
    await _save();
  }

  Future<void> _save() async {
    notifyListeners();
    await Settings.I.prefs.setString('reminders', jsonEncode(items.map((e) => e.toJson()).toList()));
  }
}
