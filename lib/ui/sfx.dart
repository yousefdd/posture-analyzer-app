import 'package:audioplayers/audioplayers.dart';

import '../analysis/analyzer.dart';

/// The warning beeps (the desktop app's frequencies), a countdown tick and a chime.
class Sfx {
  static bool enabled = true;
  static final _players = <AudioPlayer>[];
  static int _next = 0;

  static void beep(Beep b) => play(b.name);

  static void play(String name) {
    if (!enabled) return;
    try {
      if (_players.isEmpty) {
        for (var i = 0; i < 3; i++) {
          _players.add(AudioPlayer()..setReleaseMode(ReleaseMode.stop));
        }
      }
      final p = _players[_next++ % _players.length];
      p.stop().then((_) => p.play(AssetSource('sfx/$name.wav'))).catchError((_) {});
    } catch (_) {}
  }
}
