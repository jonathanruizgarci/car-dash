import 'dart:async';

import 'package:flutter/foundation.dart';

import 'dtc.dart';
import 'native.dart';
import 'pids.dart';
import 'settings.dart';

enum ObdState { disconnected, connecting, connected, error }

/// Comunicación con un adaptador ELM327 (Vgate, etc.) por Bluetooth clásico.
class ObdService extends ChangeNotifier {
  ObdService._();
  static final ObdService I = ObdService._();

  ObdState state = ObdState.disconnected;
  String message = 'Sin adaptador';
  String protocol = '';
  final Map<String, double> values = {};
  final Map<String, DateTime> _stamps = {};
  Set<String> supported = {};
  double? batteryV;
  bool milOn = false;
  int dtcCount = 0;

  bool get connected => state == ObdState.connected;

  Future<void> _lock = Future.value();
  bool _polling = false;
  int _rot = 0;
  int _failures = 0;
  Timer? _auto;

  bool fresh(String pid, {int seconds = 15}) {
    final t = _stamps[pid];
    return connected && t != null && DateTime.now().difference(t).inSeconds < seconds;
  }

  double? value(String pid) => fresh(pid) ? values[pid] : null;

  Future<T> _locked<T>(Future<T> Function() fn) {
    final prev = _lock;
    final done = Completer<void>();
    _lock = done.future;
    return prev.then((_) => fn()).whenComplete(() => done.complete());
  }

  Future<String> _send(String cmd, {int timeout = 2000}) =>
      NativeBridge.obdSend(cmd, timeout: timeout);

  /// Reintenta conectar cada 30 s si está configurado.
  void startAuto() {
    _auto?.cancel();
    if (Settings.I.autoConnectObd && Settings.I.obdAddress.isNotEmpty) connect();
    _auto = Timer.periodic(const Duration(seconds: 30), (_) {
      final s = Settings.I;
      if (s.autoConnectObd &&
          s.obdAddress.isNotEmpty &&
          (state == ObdState.disconnected || state == ObdState.error)) {
        connect();
      }
    });
  }

  Future<void> connect() async {
    final s = Settings.I;
    if (s.obdAddress.isEmpty) {
      state = ObdState.disconnected;
      message = 'Elige tu adaptador OBD2 en Ajustes';
      notifyListeners();
      return;
    }
    if (state == ObdState.connecting || state == ObdState.connected) return;
    state = ObdState.connecting;
    message = 'Conectando a ${s.obdName}…';
    notifyListeners();
    try {
      if (!await NativeBridge.hasBtPermission()) {
        await NativeBridge.requestBtPermission();
        await Future.delayed(const Duration(seconds: 4));
      }
      await NativeBridge.obdConnect(s.obdAddress);
      message = 'Inicializando adaptador…';
      notifyListeners();
      await _locked(() async {
        await _send('ATZ', timeout: 4000);
        for (final c in ['ATE0', 'ATL0', 'ATS0', 'ATH0', 'ATSP0']) {
          await _send(c, timeout: 1500);
        }
        final r = await _send('0100', timeout: 12000);
        final bits = _parse(r, '41', '00');
        if (bits == null) {
          throw Exception(r.toUpperCase().contains('UNABLE')
              ? 'El auto no responde (¿está encendido?)'
              : 'Sin respuesta de la computadora del auto');
        }
        supported = {};
        _addSupported(bits, 0);
        var base = 0;
        var last = bits;
        while (last.length >= 4 && (last[3] & 0x01) == 1 && base < 0x60) {
          base += 0x20;
          final pid = base.toRadixString(16).toUpperCase().padLeft(2, '0');
          final more = _parse(await _send('01$pid', timeout: 3000), '41', pid);
          if (more == null) break;
          _addSupported(more, base);
          last = more;
        }
        final dp = await _send('ATDP', timeout: 1500);
        protocol = dp.replaceAll(RegExp(r'[\r\n>]'), ' ').trim();
      });
      state = ObdState.connected;
      _failures = 0;
      message = 'Conectado a ${s.obdName}';
      notifyListeners();
      unawaited(_pollLoop());
    } catch (e) {
      await NativeBridge.obdDisconnect();
      state = ObdState.error;
      message = _clean(e);
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    state = ObdState.disconnected;
    message = 'Desconectado';
    notifyListeners();
    await NativeBridge.obdDisconnect();
  }

  void _addSupported(List<int> bits, int base) {
    for (var i = 0; i < 32 && i ~/ 8 < bits.length; i++) {
      final byte = bits[i ~/ 8];
      if ((byte >> (7 - (i % 8))) & 1 == 1) {
        supported.add((base + i + 1).toRadixString(16).toUpperCase().padLeft(2, '0'));
      }
    }
  }

  Future<void> _pollLoop() async {
    if (_polling) return;
    _polling = true;
    var cycle = 0;
    while (connected) {
      try {
        await _locked(() async {
          for (final p in ['0C', '0D']) {
            if (supported.contains(p)) await _readPid(p);
          }
          final slow = kPids
              .map((d) => d.pid)
              .where((p) => supported.contains(p) && p != '0C' && p != '0D')
              .toList();
          if (slow.isNotEmpty) {
            await _readPid(slow[_rot % slow.length]);
            _rot++;
          }
          if (cycle % 8 == 0) await _readVoltage();
          if (cycle % 50 == 0) await _readStatus();
        });
        _failures = 0;
        cycle++;
        notifyListeners();
      } catch (e) {
        _failures++;
        if (_failures >= 4 && connected) {
          await NativeBridge.obdDisconnect();
          state = ObdState.error;
          message = 'Se perdió la conexión con el adaptador';
          notifyListeners();
        }
      }
      await Future.delayed(const Duration(milliseconds: 120));
    }
    _polling = false;
  }

  Future<void> _readPid(String pid) async {
    final def = kPidById[pid];
    if (def == null) return;
    final r = await _send('01$pid', timeout: 1500);
    final data = _parse(r, '41', pid);
    if (data != null && data.length >= def.bytes) {
      values[pid] = def.f(data);
      _stamps[pid] = DateTime.now();
    }
  }

  Future<void> _readVoltage() async {
    final r = await _send('ATRV', timeout: 1500);
    final m = RegExp(r'(\d+(?:\.\d+)?)\s*V', caseSensitive: false).firstMatch(r);
    if (m != null) batteryV = double.tryParse(m.group(1)!);
  }

  Future<void> _readStatus() async {
    final r = await _send('0101', timeout: 2000);
    final d = _parse(r, '41', '01');
    if (d != null && d.isNotEmpty) {
      milOn = (d[0] & 0x80) != 0;
      dtcCount = d[0] & 0x7F;
    }
  }

  /// Lee los códigos de falla guardados (modo 03) y pendientes (modo 07).
  Future<Map<String, List<String>>> readDtcs() async {
    if (!connected) throw Exception('Conecta primero el adaptador OBD2');
    return _locked(() async {
      final stored = _decodeDtcResponse(await _send('03', timeout: 6000), '43');
      final pending = _decodeDtcResponse(await _send('07', timeout: 6000), '47');
      await _readStatus();
      notifyListeners();
      return {'stored': stored, 'pending': pending};
    });
  }

  Future<bool> clearDtcs() async {
    if (!connected) throw Exception('Conecta primero el adaptador OBD2');
    return _locked(() async {
      final r = await _send('04', timeout: 6000);
      await _readStatus();
      notifyListeners();
      return r.toUpperCase().contains('44');
    });
  }

  List<String> _decodeDtcResponse(String resp, String header) {
    final codes = <String>[];
    for (var line in resp.split(RegExp(r'[\r\n]+'))) {
      line = line.replaceAll(' ', '').trim().toUpperCase();
      final colon = line.indexOf(':');
      if (colon >= 0) line = line.substring(colon + 1);
      if (!RegExp(r'^[0-9A-F]+$').hasMatch(line)) continue;
      if (!line.startsWith(header)) continue;
      var data = line.substring(header.length);
      // En CAN viene un byte con la cantidad de códigos: longitud impar en bytes.
      if ((data.length ~/ 2).isOdd) data = data.substring(2);
      for (var i = 0; i + 3 < data.length; i += 4) {
        final a = int.parse(data.substring(i, i + 2), radix: 16);
        final b = int.parse(data.substring(i + 2, i + 4), radix: 16);
        if (a == 0 && b == 0) continue;
        final code = decodeDtc(a, b);
        if (!codes.contains(code)) codes.add(code);
      }
    }
    return codes;
  }

  List<int>? _parse(String resp, String mode, String pid) {
    final want = (mode + pid).toUpperCase();
    for (var line in resp.split(RegExp(r'[\r\n]+'))) {
      line = line.replaceAll(' ', '').trim().toUpperCase();
      final colon = line.indexOf(':');
      if (colon >= 0) line = line.substring(colon + 1);
      if (line.startsWith(want) && RegExp(r'^[0-9A-F]+$').hasMatch(line)) {
        final data = line.substring(want.length);
        final out = <int>[];
        for (var i = 0; i + 1 < data.length; i += 2) {
          out.add(int.parse(data.substring(i, i + 2), radix: 16));
        }
        return out;
      }
    }
    return null;
  }

  String _clean(Object e) {
    final s = e.toString();
    return s.replaceFirst('Exception: ', '').replaceFirst(RegExp(r'^PlatformException\([^,]*, '), '').replaceAll(RegExp(r', null.*$'), '');
  }
}
