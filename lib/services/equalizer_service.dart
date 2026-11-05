import 'dart:async';
import 'package:flutter/services.dart';

class EqPreset {
  final String name;
  final String subtitle;
  final List<int> bandLevelsMilliBels; // 5 bands: 60Hz, 230Hz, 910Hz, 3.6kHz, 14kHz
  final int bassBoostStrength; // 0 .. 1000
  final int virtualizerStrength; // 0 .. 1000

  const EqPreset({
    required this.name,
    this.subtitle = '',
    required this.bandLevelsMilliBels,
    required this.bassBoostStrength,
    required this.virtualizerStrength,
  });
}

/// Hardware DSP Equalizer Service for Zunify
/// Connects to Android's native `Equalizer`, `BassBoost`, and `Virtualizer`
/// via `com.fannz.zunify/equalizer` MethodChannel with non-blocking throttling.
class EqualizerService {
  static const MethodChannel _channel = MethodChannel('com.fannz.zunify/equalizer');

  static const List<String> bandLabels = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];
  static const List<String> bandSubLabels = ['Sub', 'Bass', 'Mid', 'Presence', 'Air'];

  final Map<int, Timer?> _bandTimers = {};
  Timer? _bassTimer;
  Timer? _virtTimer;

  static const List<EqPreset> presets = [
    EqPreset(
      name: 'Normal',
      subtitle: 'Suara rata & murni studio',
      bandLevelsMilliBels: [0, 0, 0, 0, 0],
      bassBoostStrength: 0,
      virtualizerStrength: 0,
    ),
    EqPreset(
      name: 'Spotify Loudness ✨',
      subtitle: 'Punchy, hangat & detail di semua volume',
      bandLevelsMilliBels: [550, 320, -80, 380, 520],
      bassBoostStrength: 420,
      virtualizerStrength: 380,
    ),
    EqPreset(
      name: 'Bass Boost Pro 🔥',
      subtitle: 'Sub-bass dalam tanpa menutupi vokal',
      bandLevelsMilliBels: [1050, 720, -100, 220, 380],
      bassBoostStrength: 880,
      virtualizerStrength: 350,
    ),
    EqPreset(
      name: 'Dolby Spatial 3D 🎧',
      subtitle: 'Panggung suara luas & imersif',
      bandLevelsMilliBels: [620, 280, 120, 540, 780],
      bassBoostStrength: 480,
      virtualizerStrength: 920,
    ),
    EqPreset(
      name: 'Vokal & Akustik 🎙️',
      subtitle: 'Vokal penyanyi & petikan gitar super jernih',
      bandLevelsMilliBels: [-180, 80, 680, 720, 340],
      bassBoostStrength: 160,
      virtualizerStrength: 450,
    ),
    EqPreset(
      name: 'Pop Modern',
      subtitle: 'Seimbang untuk Pop Indonesia & Global',
      bandLevelsMilliBels: [380, 460, 150, 480, 420],
      bassBoostStrength: 380,
      virtualizerStrength: 500,
    ),
    EqPreset(
      name: 'Rock & Band',
      subtitle: 'Gebukan drum & distorsi gitar bertenaga',
      bandLevelsMilliBels: [780, 420, -180, 520, 820],
      bassBoostStrength: 620,
      virtualizerStrength: 450,
    ),
    EqPreset(
      name: 'EDM & Jedag Jedug',
      subtitle: 'Tendangan bass maksimal & treble kristal',
      bandLevelsMilliBels: [1150, 680, -220, 420, 850],
      bassBoostStrength: 950,
      virtualizerStrength: 780,
    ),
    EqPreset(
      name: 'Lo-Fi Chill',
      subtitle: 'Hangat & lembut untuk dengar malam hari',
      bandLevelsMilliBels: [450, 520, 180, -240, -450],
      bassBoostStrength: 400,
      virtualizerStrength: 600,
    ),
  ];

  Future<void> bindAudioSession(int sessionId, {bool enabled = true}) async {
    try {
      await _channel.invokeMethod('initAudioEffects', {
        'sessionId': sessionId,
        'enabled': enabled,
      });
    } catch (_) {}
  }

  Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod('setEnabled', {'enabled': enabled});
    } catch (_) {}
  }

  Future<void> setBandLevel(int bandIndex, int levelMilliBels) async {
    _bandTimers[bandIndex]?.cancel();
    _bandTimers[bandIndex] = Timer(const Duration(milliseconds: 24), () async {
      try {
        await _channel.invokeMethod('setBandLevel', {
          'band': bandIndex,
          'level': levelMilliBels,
        });
      } catch (_) {}
    });
  }

  Future<void> setBassBoost(int strength) async {
    _bassTimer?.cancel();
    _bassTimer = Timer(const Duration(milliseconds: 24), () async {
      try {
        await _channel.invokeMethod('setBassBoost', {'strength': strength});
      } catch (_) {}
    });
  }

  Future<void> setVirtualizer(int strength) async {
    _virtTimer?.cancel();
    _virtTimer = Timer(const Duration(milliseconds: 24), () async {
      try {
        await _channel.invokeMethod('setVirtualizer', {'strength': strength});
      } catch (_) {}
    });
  }

  Future<void> applyPreset(EqPreset preset) async {
    for (int i = 0; i < preset.bandLevelsMilliBels.length; i++) {
      try {
        await _channel.invokeMethod('setBandLevel', {
          'band': i,
          'level': preset.bandLevelsMilliBels[i],
        });
      } catch (_) {}
    }
    try {
      await _channel.invokeMethod('setBassBoost', {
        'strength': preset.bassBoostStrength,
      });
      await _channel.invokeMethod('setVirtualizer', {
        'strength': preset.virtualizerStrength,
      });
    } catch (_) {}
  }
}
