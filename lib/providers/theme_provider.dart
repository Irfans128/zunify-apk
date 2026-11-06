import 'package:flutter/material.dart';
import 'package:palette_generator/palette_generator.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ZunifyAccentPreset {
  final String id;
  final String name;
  final String subtitle;
  final Color primary;
  final Color secondary;

  const ZunifyAccentPreset({
    required this.id,
    required this.name,
    required this.subtitle,
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
      id: 'ios_liquid',
      name: 'Liquid Pearl',
      subtitle: 'Biru kristal',
      primary: Color(0xFF60A5FA),
      secondary: Color(0xFFC084FC),
    ),
    ZunifyAccentPreset(
      id: 'saweria_amber',
      name: 'Saweria Gold',
      subtitle: 'Kuning khas Saweria',
      primary: Color(0xFFFAAE2B),
      secondary: Color(0xFFFFD166),
    ),
    ZunifyAccentPreset(
      id: 'crimson_z',
      name: 'Crimson Red',
      subtitle: 'Merah tegas',
      primary: Color(0xFFFF3358),
      secondary: Color(0xFFFF758F),
    ),
    ZunifyAccentPreset(
      id: 'rose_quartz',
      name: 'Rose Pink',
      subtitle: 'Pink lembut',
      primary: Color(0xFFF472B6),
      secondary: Color(0xFFFB7185),
    ),
    ZunifyAccentPreset(
      id: 'lavender',
      name: 'Lavender',
      subtitle: 'Ungu pastel',
      primary: Color(0xFFA78BFA),
      secondary: Color(0xFFF472B6),
    ),
    ZunifyAccentPreset(
      id: 'matcha',
      name: 'Matcha Mint',
      subtitle: 'Hijau segar',
      primary: Color(0xFF34D399),
      secondary: Color(0xFF6EE7B7),
    ),
  ];

  /// 2 Core Visual Themes: 'liquid_glass' | 'saweria'
  String _uiThemeMode = 'liquid_glass';
  String _selectedPresetId = 'ios_liquid';
  bool _oledPureBlack = false;
  bool _dynamicAlbumColorEnabled = true;
  bool _dynamicFullAccentEnabled = true;

  // Appearance & UI Control Settings
  double _animationSpeedMultiplier = 0.88; // Tuned for snappy 90/120fps feel
  String _playerSpacingMode = 'balanced'; // 'compact' | 'balanced' | 'spacious'
  double _blurIntensity = 0.80; // 0.40 = Ringan, 0.80 = Seimbang, 1.0 = Ultra
  String _playerCoverStyle = 'artwork'; // 'artwork' | 'vinyl'
  bool _lyricsCenterAligned = false; // false = Rata Kiri, true = Rata Tengah
  double _lyricsFontScale = 1.0; // 0.90 = Kompak, 1.0 = Normal, 1.14 = Besar

  Color? _dynamicAlbumColor;
  Color? _dynamicVibrantAccent;
  Color? _dynamicSecondaryAccent;
  final Map<Object, _CachedPalettePair> _paletteCache = {};

  String get uiThemeMode => _uiThemeMode;
  bool get isSaweriaTheme => _uiThemeMode == 'saweria';
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
    final scaled = (baseMs * _animationSpeedMultiplier).round().clamp(65, 900);
    return Duration(milliseconds: scaled);
  }

  /// Dynamic blur sigma for floating Liquid Glass bars
  double get glassBlurSigma =>
      isSaweriaTheme ? 0.0 : (24.0 * _blurIntensity).clamp(10.0, 30.0);

  /// Vertical spacing multiplier for NowPlayingScreen based on playerSpacingMode
  double get playerSpacingFactor {
    switch (_playerSpacingMode) {
      case 'compact':
        return 0.75;
      case 'spacious':
        return 1.28;
      default:
        return 1.0;
    }
  }

  EdgeInsets get playerHorizontalPadding {
    switch (_playerSpacingMode) {
      case 'compact':
        return const EdgeInsets.fromLTRB(18, 4, 18, 8);
      case 'spacious':
        return const EdgeInsets.fromLTRB(24, 8, 24, 12);
      default:
        return const EdgeInsets.fromLTRB(20, 6, 20, 10);
    }
  }

  ZunifyAccentPreset get activePreset => accentPresets.firstWhere(
        (p) => p.id == _selectedPresetId,
        orElse: () => accentPresets.first,
      );

  Color get accentColor {
    if (_dynamicAlbumColorEnabled &&
        _dynamicFullAccentEnabled &&
        _dynamicVibrantAccent != null) {
      return _dynamicVibrantAccent!;
    }
    return activePreset.primary;
  }

  Color get secondaryAccentColor {
    if (_dynamicAlbumColorEnabled &&
        _dynamicFullAccentEnabled &&
        _dynamicSecondaryAccent != null) {
      return _dynamicSecondaryAccent!;
    }
    return activePreset.secondary;
  }

  Color get playerAmbientColor =>
      (_dynamicAlbumColorEnabled && _dynamicAlbumColor != null)
          ? _dynamicAlbumColor!
          : activePreset.primary;

  Color get scaffoldBgColor {
    if (_oledPureBlack) return const Color(0xFF000000);
    return isSaweriaTheme ? const Color(0xFF111217) : const Color(0xFF07090F);
  }

  Color get cardBgColor {
    if (_oledPureBlack) return const Color(0xFF0B0D13);
    return isSaweriaTheme ? const Color(0xFF1B1D26) : const Color(0xFF121622);
  }

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _uiThemeMode = prefs.getString('ui_theme_mode_v2') ?? 'liquid_glass';
    _selectedPresetId = prefs.getString('theme_preset_id_v2') ?? 'ios_liquid';
    _oledPureBlack = prefs.getBool('oled_pure_black') ?? false;
    _dynamicAlbumColorEnabled = prefs.getBool('dynamic_album_color') ?? true;
    _dynamicFullAccentEnabled =
        prefs.getBool('dynamic_full_accent_v2') ?? true;
    _animationSpeedMultiplier =
        prefs.getDouble('anim_speed_mult_v2') ?? 0.88;
    _playerSpacingMode =
        prefs.getString('player_spacing_mode_v2') ?? 'balanced';
    _blurIntensity = prefs.getDouble('blur_intensity_v2') ?? 0.80;
    _playerCoverStyle =
        prefs.getString('player_cover_style_v2') ?? 'artwork';
    _lyricsCenterAligned =
        prefs.getBool('lyrics_center_aligned_v2') ?? false;
    _lyricsFontScale = prefs.getDouble('lyrics_font_scale_v2') ?? 1.0;
    notifyListeners();
  }

  Future<void> setUiThemeMode(String mode) async {
    _uiThemeMode = mode;
    if (mode == 'saweria' && _selectedPresetId == 'ios_liquid') {
      _selectedPresetId = 'saweria_amber';
    } else if (mode == 'liquid_glass' && _selectedPresetId == 'saweria_amber') {
      _selectedPresetId = 'ios_liquid';
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ui_theme_mode_v2', mode);
    await prefs.setString('theme_preset_id_v2', _selectedPresetId);
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

  Color _boostForAestheticDarkUi(Color raw) {
    final hsl = HSLColor.fromColor(raw);
    final sat = hsl.saturation < 0.45
        ? (hsl.saturation + 0.32).clamp(0.52, 0.88)
        : hsl.saturation.clamp(0.52, 0.90);
    final light = hsl.lightness.clamp(0.64, 0.76);
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
        final boostedPrimary = _boostForAestheticDarkUi(rawPrimary);
        final boostedSecondary =
            _boostForAestheticDarkUi(rawSecondary ?? rawPrimary);
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
