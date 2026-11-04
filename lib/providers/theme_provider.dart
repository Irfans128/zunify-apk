import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ZunifyAccentPreset {
  final String id;
  final String name;
  final Color primary;
  final Color secondary;

  const ZunifyAccentPreset({
    required this.id,
    required this.name,
    required this.primary,
    required this.secondary,
  });
}

class ThemeProvider extends ChangeNotifier {
  static const List<ZunifyAccentPreset> accentPresets = [
    ZunifyAccentPreset(
      id: 'emerald',
      name: 'Zunify Neon Emerald',
      primary: Color(0xFF00F5A0),
      secondary: Color(0xFF00D9F5),
    ),
    ZunifyAccentPreset(
      id: 'cyan',
      name: 'Cyberpunk Cyan',
      primary: Color(0xFF00E5FF),
      secondary: Color(0xFF3B82F6),
    ),
    ZunifyAccentPreset(
      id: 'purple',
      name: 'Electric Violet',
      primary: Color(0xFFB366FF),
      secondary: Color(0xFFEC4899),
    ),
    ZunifyAccentPreset(
      id: 'orange',
      name: 'Sunset Amber',
      primary: Color(0xFFFF7A33),
      secondary: Color(0xFFFACC15),
    ),
    ZunifyAccentPreset(
      id: 'crimson',
      name: 'Crimson Rose',
      primary: Color(0xFFFF3366),
      secondary: Color(0xFFFF80AB),
    ),
  ];

  String _selectedPresetId = 'emerald';
  bool _oledPureBlack = false;
  bool _dynamicAlbumColorEnabled = true;
  Color? _dynamicAlbumColor;
  final Map<Object, Color> _paletteCache = {};

  String get selectedPresetId => _selectedPresetId;
  bool get oledPureBlack => _oledPureBlack;
  bool get dynamicAlbumColorEnabled => _dynamicAlbumColorEnabled;

  ZunifyAccentPreset get activePreset => accentPresets.firstWhere(
        (p) => p.id == _selectedPresetId,
        orElse: () => accentPresets.first,
      );

  Color get accentColor => activePreset.primary;
  Color get secondaryAccentColor => activePreset.secondary;

  Color get playerAmbientColor =>
      (_dynamicAlbumColorEnabled && _dynamicAlbumColor != null)
          ? _dynamicAlbumColor!
          : activePreset.primary;

  Color get scaffoldBgColor =>
      _oledPureBlack ? const Color(0xFF000000) : const Color(0xFF080A10);

  Color get cardBgColor =>
      _oledPureBlack ? const Color(0xFF0C0E14) : const Color(0xFF131722);

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _selectedPresetId = prefs.getString('theme_preset_id') ?? 'emerald';
    _oledPureBlack = prefs.getBool('oled_pure_black') ?? false;
    _dynamicAlbumColorEnabled = prefs.getBool('dynamic_album_color') ?? true;
    notifyListeners();
  }

  Future<void> setAccentPreset(String presetId) async {
    _selectedPresetId = presetId;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_preset_id', presetId);
  }

  Future<void> setOledPureBlack(bool value) async {
    _oledPureBlack = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('oled_pure_black', value);
  }

  Future<void> setDynamicAlbumColorEnabled(bool value) async {
    _dynamicAlbumColorEnabled = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dynamic_album_color', value);
  }

  Future<void> updateDynamicColorFromImage(ImageProvider imageProvider) async {
    if (!_dynamicAlbumColorEnabled) return;
    final cached = _paletteCache[imageProvider];
    if (cached != null) {
      if (_dynamicAlbumColor != cached) {
        _dynamicAlbumColor = cached;
        notifyListeners();
      }
      return;
    }
    try {
      final resized = ResizeImage.resizeIfNeeded(48, 48, imageProvider);
      final palette = await PaletteGenerator.fromImageProvider(
        resized,
        size: const Size(48, 48),
        maximumColorCount: 8,
      );
      final extracted = palette.vibrantColor?.color ??
          palette.lightVibrantColor?.color ??
          palette.dominantColor?.color;
      if (extracted != null) {
        if (_paletteCache.length > 60) {
          _paletteCache.clear();
        }
        _paletteCache[imageProvider] = extracted;
        if (_dynamicAlbumColor != extracted) {
          _dynamicAlbumColor = extracted;
          notifyListeners();
        }
      }
    } catch (_) {}
  }
}
