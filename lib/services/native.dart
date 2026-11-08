import 'dart:typed_data';

import 'package:flutter/services.dart';

class BtDevice {
  final String name;
  final String address;
  const BtDevice(this.name, this.address);
}

/// Puente con el código nativo de Android (MainActivity.kt).
class NativeBridge {
  static const MethodChannel _ch = MethodChannel('autopanel/native');

  static Future<bool> launchApp(String pkg) async {
    try {
      return (await _ch.invokeMethod<bool>('launchApp', {'package': pkg})) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> openUri(String uri) async {
    try {
      return (await _ch.invokeMethod<bool>('openUri', {'uri': uri})) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> mediaKey(String key) async {
    try {
      await _ch.invokeMethod('mediaKey', {'key': key});
    } catch (_) {}
  }

  static Future<bool> isMusicActive() async {
    try {
      return (await _ch.invokeMethod<bool>('isMusicActive')) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> keepScreenOn(bool on) async {
    try {
      await _ch.invokeMethod('keepScreenOn', {'on': on});
    } catch (_) {}
  }

  static Future<bool> hasBtPermission() async {
    try {
      return (await _ch.invokeMethod<bool>('hasBtPermission')) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> requestBtPermission() async {
    try {
      await _ch.invokeMethod('requestBtPermission');
    } catch (_) {}
  }

  static Future<List<BtDevice>> bondedDevices() async {
    try {
      final res = await _ch.invokeMethod<List<dynamic>>('bondedDevices');
      return (res ?? const []).map((e) {
        final m = Map<String, dynamic>.from(e as Map);
        return BtDevice(
          (m['name'] as String?) ?? 'Sin nombre',
          (m['address'] as String?) ?? '',
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  /// Lanza PlatformException si no se pudo conectar.
  static Future<bool> obdConnect(String address) async {
    final r = await _ch.invokeMethod<bool>('obdConnect', {'address': address});
    return r ?? false;
  }

  /// Envía un comando ELM327 y regresa la respuesta (sin el prompt '>').
  static Future<String> obdSend(String cmd, {int timeout = 2000}) async {
    final r = await _ch.invokeMethod<String>('obdSend', {'cmd': cmd, 'timeout': timeout});
    return r ?? '';
  }

  static Future<void> obdDisconnect() async {
    try {
      await _ch.invokeMethod('obdDisconnect');
    } catch (_) {}
  }

  static Future<bool> _bool(String m) async {
    try {
      return (await _ch.invokeMethod<bool>(m)) ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> hasNotifAccess() => _bool('hasNotifAccess');
  static Future<bool> openNotifSettings() => _bool('openNotifSettings');
  static Future<bool> canOverlay() => _bool('canOverlay');
  static Future<bool> openOverlaySettings() => _bool('openOverlaySettings');
  static Future<bool> showOverlay() => _bool('showOverlay');
  static Future<bool> hideOverlay() => _bool('hideOverlay');

  static Future<Map<String, dynamic>?> nowPlaying() async {
    try {
      final r = await _ch.invokeMethod<Map<dynamic, dynamic>>('nowPlaying');
      return r == null ? null : Map<String, dynamic>.from(r);
    } catch (_) {
      return null;
    }
  }

  static Future<Uint8List?> nowPlayingArt() async {
    try {
      return await _ch.invokeMethod<Uint8List>('nowPlayingArt');
    } catch (_) {
      return null;
    }
  }
}
