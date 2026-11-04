import 'package:flutter/services.dart';

class EqPreset {
  final String name;
  final List<int> bandLevelsMilliBels; // 5 bands: 60Hz, 230Hz, 910Hz, 3.6kHz, 14kHz
  final int bassBoostStrength; // 0 .. 1000
  final int virtualizerStrength; // 0 .. 1000

  const EqPreset({
    required this.name,
    required this.bandLevelsMilliBels,
    required this.bassBoostStrength,
    required this.virtualizerStrength,
  });
}

/// Hardware DSP Equalizer Service for Zunify
/// Connects to Android's native `Equalizer`, `BassBoost`, and `Virtualizer`
/// via `com.fannz.zunify/equalizer` MethodChannel.
class EqualizerService {
  static const MethodChannel _channel = MethodChannel('com.fannz.zunify/equalizer');

  static const List<String> bandLabels = ['60Hz', '230Hz', '910Hz', '3.6kHz', '14kHz'];

  static const List<EqPreset> presets = [
    EqPreset(
      name: 'Normal',
      bandLevelsMilliBels: [0, 0, 0, 0, 0],
      bassBoostStrength: 0,
      virtualizerStrength: 0,
    ),
    EqPreset(
      name: 'Bass Boost 🔥',
      bandLevelsMilliBels: [950, 650, 0, 150, 300],
      bassBoostStrength: 850,
      virtualizerStrength: 350,
    ),
    EqPreset(
      name: 'Pop Aesthetic',
      bandLevelsMilliBels: [-150, 400, 650, 450, -100],
      bassBoostStrength: 350,
      virtualizerStrength: 500,
    ),
    EqPreset(
      name: 'Vocal / Lirik Jernih',
      bandLevelsMilliBels: [-300, -100, 750, 650, 200],
      bassBoostStrength: 100,
      virtualizerStrength: 450,
    ),
    EqPreset(
      name: 'Rock & Energetic',
      bandLevelsMilliBels: [750, 400, -200, 450, 800],
      bassBoostStrength: 600,
      virtualizerStrength: 400,
    ),
    EqPreset(
      name: 'Electronic / Night',
      bandLevelsMilliBels: [800, 350, -100, 350, 750],
      bassBoostStrength: 750,
      virtualizerStrength: 800,
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
    try {
      await _channel.invokeMethod('setBandLevel', {
        'band': bandIndex,
        'level': levelMilliBels,
      });
    } catch (_) {}
  }

  Future<void> setBassBoost(int strength) async {
    try {
      await _channel.invokeMethod('setBassBoost', {'strength': strength});
    } catch (_) {}
  }

  Future<void> setVirtualizer(int strength) async {
    try {
      await _channel.invokeMethod('setVirtualizer', {'strength': strength});
    } catch (_) {}
  }

  Future<void> applyPreset(EqPreset preset) async {
    for (int i = 0; i < preset.bandLevelsMilliBels.length; i++) {
      await setBandLevel(i, preset.bandLevelsMilliBels[i]);
    }
    await setBassBoost(preset.bassBoostStrength);
    await setVirtualizer(preset.virtualizerStrength);
  }
}
