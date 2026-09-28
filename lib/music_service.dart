import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

// ═══════════════════════════════════════════════════════════════════════
// MUSIC SERVICE — Singleton
// ═══════════════════════════════════════════════════════════════════════
class MusicService extends ChangeNotifier {
  static final MusicService _instance = MusicService._internal();
  factory MusicService() => _instance;
  MusicService._internal();

  final AudioPlayer _player = AudioPlayer();

  bool _isPlaying = false;
  bool _initialized = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  bool get isPlaying => _isPlaying;
  Duration get position => _position;
  Duration get duration => _duration;
  AudioPlayer get player => _player;

  Future<void> play({String assetPath = 'audio/bug.mp3'}) async {
    try {
      if (!_initialized) {
        await _player.setSource(AssetSource(assetPath));
        await _player.setReleaseMode(ReleaseMode.loop);
        await _player.setVolume(1.0);

        _player.onPlayerStateChanged.listen((PlayerState s) {
          _isPlaying = s == PlayerState.playing;
          notifyListeners();
        });

        _player.onPositionChanged.listen((Duration p) {
          _position = p;
          notifyListeners();
        });

        _player.onDurationChanged.listen((Duration d) {
          _duration = d;
          notifyListeners();
        });

        _initialized = true;
      }
      await _player.resume();
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      debugPrint('MusicService.play error: $e');
    }
  }

  Future<void> pause() async {
    try {
      await _player.pause();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      debugPrint('MusicService.pause error: $e');
    }
  }

  Future<void> toggle() async {
    if (_isPlaying) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
      _initialized = false;
      notifyListeners();
    } catch (e) {
      debugPrint('MusicService.stop error: $e');
    }
  }

  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      debugPrint('MusicService.seek error: $e');
    }
  }
}