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

class _CachedPalettePair {
  final Color ambient;
  final Color vibrantAccent;
  final Color secondaryAccent;

  const _CachedPalettePair({
    required this.ambient,
    required this.vibrantAccent,
    required this.secondaryAccent,
  });
}

class ThemeProvider extends ChangeNotifier {
  static const List<ZunifyAccentPreset> accentPresets = [
    ZunifyAccentPreset(
      id: 'crimson_z',
      name: 'Zunify Crimson Z',
      primary: Color(0xFFFF2E4C),
      secondary: Color(0xFFFF6B4A),
    ),
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

  String _selectedPresetId = 'crimson_z';
  bool _oledPureBlack = false;
  bool _dynamicAlbumColorEnabled = true;
  bool _dynamicFullAccentEnabled = true;

  // Appearance & UI Control Settings (Zunify 2.0 Studio Controls)
  double _animationSpeedMultiplier = 1.0; // 0.72 = Cepat, 1.0 = Normal, 1.38 = Halus
  String _playerSpacingMode = 'balanced'; // 'compact' | 'balanced' | 'spacious'
  double _blurIntensity = 0.75; // 0.40 = Ringan, 0.75 = Seimbang, 1.0 = Ultra Glass
  String _playerCoverStyle = 'artwork'; // 'artwork' (Modern 3D Cover) | 'vinyl' (Piringan Vinyl)
  bool _lyricsCenterAligned = false; // false = Rata Kiri, true = Rata Tengah
  double _lyricsFontScale = 1.0; // 0.90 = Kompak, 1.0 = Normal, 1.14 = Besar

  Color? _dynamicAlbumColor;
  Color? _dynamicVibrantAccent;
  Color? _dynamicSecondaryAccent;
  final Map<Object, _CachedPalettePair> _paletteCache = {};

  String get selectedPresetId => _selectedPresetId;
  bool get oledPureBlack => _oledPureBlack;
  bool get dynamicAlbumColorEnabled => _dynamicAlbumColorEnabled;
  bool get dynamicFullAccentEnabled => _dynamicFullAccentEnabled;

  double get animationSpeedMultiplier => _animationSpeedMultiplier;
  String get playerSpacingMode => _playerSpacingMode;
  double get blurIntensity => _blurIntensity;
  String get playerCoverStyle => _playerCoverStyle;
  bool get lyricsCenterAligned => _lyricsCenterAligned;
  double get lyricsFontScale => _lyricsFontScale;

  /// Scales any base animation duration (ms) by the user's chosen animation speed
  Duration animDuration(int baseMs) {
    final scaled = (baseMs * _animationSpeedMultiplier).round().clamp(80, 1500);
    return Duration(milliseconds: scaled);
  }

  /// Dynamic blur sigma for Frosted Glass elements (respects power-saving vs ultra glass)
  double get glassBlurSigma => (26.0 * _blurIntensity).clamp(9.0, 32.0);

  /// Vertical spacing multiplier for NowPlayingScreen based on playerSpacingMode
  double get playerSpacingFactor {
    switch (_playerSpacingMode) {
      case 'compact':
        return 0.72;
      case 'spacious':
        return 1.32;
      default:
        return 1.0;
    }
  }

  EdgeInsets get playerHorizontalPadding {
    switch (_playerSpacingMode) {
      case 'compact':
        return const EdgeInsets.fromLTRB(16, 4, 16, 8);
      case 'spacious':
        return const EdgeInsets.fromLTRB(26, 10, 26, 14);
      default:
        return const EdgeInsets.fromLTRB(22, 6, 22, 10);
    }
  }

  ZunifyAccentPreset get activePreset => accentPresets.firstWhere(
        (p) => p.id == _selectedPresetId,
        orElse: () => accentPresets.first,
      );

  Color get accentColor =>
      (_dynamicAlbumColorEnabled &&
              _dynamicFullAccentEnabled &&
              _dynamicVibrantAccent != null)
          ? _dynamicVibrantAccent!
          : activePreset.primary;

  Color get secondaryAccentColor =>
      (_dynamicAlbumColorEnabled &&
              _dynamicFullAccentEnabled &&
              _dynamicSecondaryAccent != null)
          ? _dynamicSecondaryAccent!
          : activePreset.secondary;

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
    _selectedPresetId = prefs.getString('theme_preset_id_v2') ?? 'crimson_z';
    _oledPureBlack = prefs.getBool('oled_pure_black') ?? false;
    _dynamicAlbumColorEnabled = prefs.getBool('dynamic_album_color') ?? true;
    _dynamicFullAccentEnabled =
        prefs.getBool('dynamic_full_accent_v2') ?? true;
    _animationSpeedMultiplier =
        prefs.getDouble('anim_speed_mult_v2') ?? 1.0;
    _playerSpacingMode =
        prefs.getString('player_spacing_mode_v2') ?? 'balanced';
    _blurIntensity = prefs.getDouble('blur_intensity_v2') ?? 0.75;
    _playerCoverStyle =
        prefs.getString('player_cover_style_v2') ?? 'artwork';
    _lyricsCenterAligned =
        prefs.getBool('lyrics_center_aligned_v2') ?? false;
    _lyricsFontScale = prefs.getDouble('lyrics_font_scale_v2') ?? 1.0;
    notifyListeners();
  }

  Future<void> setAccentPreset(String presetId) async {
    _selectedPresetId = presetId;
    _dynamicFullAccentEnabled = false;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('theme_preset_id_v2', presetId);
    await prefs.setBool('dynamic_full_accent_v2', false);
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

  Future<void> setDynamicFullAccentEnabled(bool value) async {
    _dynamicFullAccentEnabled = value;
    if (value && !_dynamicAlbumColorEnabled) {
      _dynamicAlbumColorEnabled = true;
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('dynamic_full_accent_v2', value);
    if (value) {
      await prefs.setBool('dynamic_album_color', true);
    }
  }

  Future<void> setAnimationSpeedMultiplier(double value) async {
    _animationSpeedMultiplier = value.clamp(0.5, 2.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('anim_speed_mult_v2', _animationSpeedMultiplier);
  }

  Future<void> setPlayerSpacingMode(String mode) async {
    _playerSpacingMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_spacing_mode_v2', mode);
  }

  Future<void> setBlurIntensity(double value) async {
    _blurIntensity = value.clamp(0.25, 1.0);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('blur_intensity_v2', _blurIntensity);
  }

  Future<void> setPlayerCoverStyle(String style) async {
    _playerCoverStyle = style;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('player_cover_style_v2', style);
  }

  Future<void> setLyricsCenterAligned(bool value) async {
    _lyricsCenterAligned = value;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('lyrics_center_aligned_v2', value);
  }

  Future<void> setLyricsFontScale(double value) async {
    _lyricsFontScale = value.clamp(0.85, 1.25);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('lyrics_font_scale_v2', _lyricsFontScale);
  }

  /// Ensures extracted cover art accent color is bright & saturated enough for dark UI
  Color _boostForDarkUiAccent(Color raw) {
    final hsl = HSLColor.fromColor(raw);
    final sat = hsl.saturation < 0.50
        ? (hsl.saturation + 0.35).clamp(0.55, 0.95)
        : hsl.saturation.clamp(0.55, 0.96);
    final light = hsl.lightness.clamp(0.60, 0.74);
    return hsl.withSaturation(sat).withLightness(light).toColor();
  }

  Future<void> updateDynamicColorFromImage(ImageProvider imageProvider) async {
    if (!_dynamicAlbumColorEnabled) return;
    final cached = _paletteCache[imageProvider];
    if (cached != null) {
      if (_dynamicAlbumColor != cached.ambient ||
          _dynamicVibrantAccent != cached.vibrantAccent) {
        _dynamicAlbumColor = cached.ambient;
        _dynamicVibrantAccent = cached.vibrantAccent;
        _dynamicSecondaryAccent = cached.secondaryAccent;
        notifyListeners();
      }
      return;
    }
    try {
      final resized = ResizeImage.resizeIfNeeded(56, 56, imageProvider);
      final palette = await PaletteGenerator.fromImageProvider(
        resized,
        size: const Size(56, 56),
        maximumColorCount: 10,
      );
      final rawPrimary = palette.vibrantColor?.color ??
          palette.lightVibrantColor?.color ??
          palette.dominantColor?.color;
      final rawSecondary = palette.lightVibrantColor?.color ??
          palette.mutedColor?.color ??
          rawPrimary;
      if (rawPrimary != null) {
        final boostedPrimary = _boostForDarkUiAccent(rawPrimary);
        final boostedSecondary =
            _boostForDarkUiAccent(rawSecondary ?? rawPrimary);
        final entry = _CachedPalettePair(
          ambient: rawPrimary,
          vibrantAccent: boostedPrimary,
          secondaryAccent: boostedSecondary,
        );
        if (_paletteCache.length > 60) {
          _paletteCache.clear();
        }
        _paletteCache[imageProvider] = entry;
        _dynamicAlbumColor = entry.ambient;
        _dynamicVibrantAccent = entry.vibrantAccent;
        _dynamicSecondaryAccent = entry.secondaryAccent;
        notifyListeners();
      }
    } catch (_) {}
  }
}
