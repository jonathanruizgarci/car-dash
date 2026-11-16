import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import 'native.dart';

/// Lo que está sonando (Spotify, YouTube Music, etc.) y sus controles.
class MusicService extends ChangeNotifier {
  MusicService._();
  static final MusicService I = MusicService._();

  bool hasAccess = false;
  bool canOverlay = false;
  bool active = false;
  String title = '';
  String artist = '';
  String album = '';
  String source = '';
  bool playing = false;
  int positionMs = 0;
  int durationMs = 0;
  Uint8List? art;
  String queue = '';
  List<MediaAction> customActions = [];

  String _artKey = '';
  Timer? _timer;
  bool _busy = false;

  double get progress => durationMs > 0 ? (positionMs / durationMs).clamp(0.0, 1.0).toDouble() : 0.0;

  String get sourceName => switch (source) {
        'com.spotify.music' => 'Spotify',
        'com.google.android.apps.youtube.music' => 'YouTube Music',
        'com.google.android.youtube' => 'YouTube',
        'com.amazon.mp3' => 'Amazon Music',
        'deezer.android.app' => 'Deezer',
        '' => '',
        _ => 'Música',
      };

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => refresh());
    refresh();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> refresh() async {
    if (_busy) return;
    _busy = true;
    try {
      hasAccess = await NativeBridge.hasNotifAccess();
      canOverlay = await NativeBridge.canOverlay();
      final m = hasAccess ? await NativeBridge.nowPlaying() : null;
      if (m == null) {
        active = false;
        playing = false;
      } else {
        active = true;
        title = (m['title'] as String?) ?? '';
        artist = (m['artist'] as String?) ?? '';
        album = (m['album'] as String?) ?? '';
        source = (m['package'] as String?) ?? '';
        playing = (m['playing'] as bool?) ?? false;
        positionMs = (m['position'] as num?)?.toInt() ?? 0;
        durationMs = (m['duration'] as num?)?.toInt() ?? 0;
        queue = (m['queue'] as String?) ?? '';
        customActions = ((m['custom'] as List?) ?? const [])
            .map((e) => Map<String, dynamic>.from(e as Map))
            .map((e) => MediaAction((e['id'] as String?) ?? '', (e['name'] as String?) ?? ''))
            .where((a) => a.id.isNotEmpty)
            .toList();
        final key = '$title|$artist|$album';
        if (key != _artKey) {
          _artKey = key;
          art = await NativeBridge.nowPlayingArt();
        }
      }
      notifyListeners();
    } finally {
      _busy = false;
    }
  }

  Future<void> seek(int ms) async {
    positionMs = ms;
    notifyListeners();
    await NativeBridge.mediaSeek(ms);
  }

  Future<void> command(String key) async {
    await NativeBridge.mediaKey(key);
    await Future.delayed(const Duration(milliseconds: 350));
    await refresh();
  }
}

class MediaAction {
  final String id;
  final String name;
  const MediaAction(this.id, this.name);
}

extension MusicExtras on MusicService {
  /// Busca una acción de la app de música (Spotify) por palabras clave en su id o nombre.
  MediaAction? findAction(List<String> keys) {
    for (final a in customActions) {
      final t = '${a.id} ${a.name}'.toLowerCase();
      if (keys.any(t.contains)) return a;
    }
    return null;
  }

  Future<void> custom(MediaAction a) async {
    await NativeBridge.mediaCustom(a.id);
    await Future.delayed(const Duration(milliseconds: 350));
    await refresh();
  }
}

String fmtMs(int ms) {
  final s = ms ~/ 1000;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}
