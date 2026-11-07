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
      name: 'Liquid Crystal',
      subtitle: 'Biru safir & aurora',
      primary: Color(0xFF38BDF8),
      secondary: Color(0xFFC084FC),
    ),
    ZunifyAccentPreset(
      id: 'aurora_prism',
      name: 'Aurora Prism',
      subtitle: 'Sian & zamrud kaca',
      primary: Color(0xFF22D3EE),
      secondary: Color(0xFF34D399),
    ),
    ZunifyAccentPreset(
      id: 'brutal_amber',
      name: 'Mustard Amber',
      subtitle: 'Kuning tegas',
      primary: Color(0xFFFAAE2B),
      secondary: Color(0xFFFFD166),
    ),
    ZunifyAccentPreset(
      id: 'crimson_z',
      name: 'Crimson Glow',
      subtitle: 'Merah rubi cerah',
      primary: Color(0xFFFF4D6D),
      secondary: Color(0xFFFF8FA3),
    ),
    ZunifyAccentPreset(
      id: 'rose_quartz',
      name: 'Rose Iridescent',
      subtitle: 'Merah muda kristal',
      primary: Color(0xFFF472B6),
      secondary: Color(0xFFA78BFA),
    ),
    ZunifyAccentPreset(
      id: 'lavender',
      name: 'Violet Nebula',
      subtitle: 'Ungu elektrik',
      primary: Color(0xFFA78BFA),
      secondary: Color(0xFF38BDF8),
    ),
    ZunifyAccentPreset(
      id: 'matcha',
      name: 'Emerald Frost',
      subtitle: 'Hijau mint jernih',
      primary: Color(0xFF34D399),
      secondary: Color(0xFF60A5FA),
    ),
  ];

  /// 2 Core Visual Themes: 'liquid_glass' | 'neo_brutalism'
  String _uiThemeMode = 'liquid_glass';
  String _selectedPresetId = 'ios_liquid';
  bool _oledPureBlack = false;
  bool _dynamicAlbumColorEnabled = true;
  bool _dynamicFullAccentEnabled = true;

  // Appearance & UI Control Settings
  double _animationSpeedMultiplier = 0.88; // Snappy 90/120Hz feel
  String _playerSpacingMode = 'balanced'; // 'compact' | 'balanced' | 'spacious'
  double _blurIntensity = 0.80; // 0.40 = Ringan, 0.80 = Seimbang, 1.0 = Ultra
  String _playerCoverStyle = 'artwork'; // 'artwork' | 'vinyl'
  bool _lyricsCenterAligned = false; // false = Rata Kiri, true = Rata Tengah
  double _lyricsFontScale = 1.0; // 0.90 = Kecil, 1.0 = Normal, 1.14 = Besar

  Color? _dynamicAlbumColor;
  Color? _dynamicVibrantAccent;
  Color? _dynamicSecondaryAccent;
  final Map<Object, _CachedPalettePair> _paletteCache = {};

  String get uiThemeMode => _uiThemeMode;
  bool get isNeoBrutalism => _uiThemeMode == 'neo_brutalism';
  bool get isSaweriaTheme => isNeoBrutalism; // Compatibility alias
  bool get isLightCanvas => isNeoBrutalism && !_oledPureBlack;

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

  Duration animDuration(int baseMs) {
    final scaled = (baseMs * _animationSpeedMultiplier).round().clamp(60, 850);
    return Duration(milliseconds: scaled);
  }

  double get glassBlurSigma =>
      isNeoBrutalism ? 0.0 : (24.0 * _blurIntensity).clamp(10.0, 30.0);

  double get playerSpacingFactor {
    switch (_playerSpacingMode) {
      case 'compact':
        return 0.78;
      case 'spacious':
        return 1.24;
      default:
        return 1.0;
    }
  }

  EdgeInsets get playerHorizontalPadding {
    switch (_playerSpacingMode) {
      case 'compact':
        return const EdgeInsets.fromLTRB(18, 4, 18, 8);
      case 'spacious':
        return const EdgeInsets.fromLTRB(22, 8, 22, 12);
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

  /// High-legibility version of accentColor when used as bare text/icon on cream paper
  Color get accentText {
    final c = accentColor;
    if (!isLightCanvas) return c;
    final hsl = HSLColor.fromColor(c);
    if (hsl.lightness > 0.36) {
      return hsl
          .withSaturation((hsl.saturation + 0.12).clamp(0.55, 0.95))
          .withLightness(0.32)
          .toColor();
    }
    return c;
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

  // --- Semantic Theme Tokens ---
  Color get scaffoldBgColor {
    if (isNeoBrutalism) {
      return _oledPureBlack
          ? const Color(0xFF16171D)
          : const Color(0xFFFAF4E6); // Warm cream paper canvas
    }
    return _oledPureBlack ? const Color(0xFF000000) : const Color(0xFF060A15);
  }

  Color get cardBgColor {
    if (isLightCanvas) return const Color(0xFFFFFDF8);
    if (isNeoBrutalism) return const Color(0xFF232530);
    return _oledPureBlack ? const Color(0xFF0B0D13) : const Color(0xFF121622);
  }

  Color get sheetBgColor {
    if (isLightCanvas) return const Color(0xFFFAF4E6);
    if (isNeoBrutalism) return const Color(0xFF1D1F29);
    return _oledPureBlack ? const Color(0xFF0B0D14) : const Color(0xFF101420);
  }

  Color get textPrimary =>
      isLightCanvas ? const Color(0xFF111111) : Colors.white;

  Color get textSecondary => isLightCanvas
      ? const Color(0xFF3A3A44)
      : Colors.white.withOpacity(0.74);

  Color get textMuted => isLightCanvas
      ? const Color(0xFF6B6B76)
      : Colors.white.withOpacity(0.54);

  Color get subtleFill => isLightCanvas
      ? const Color(0xFF111111).withOpacity(0.06)
      : Colors.white.withOpacity(0.07);

  Color get dividerColor => isLightCanvas
      ? const Color(0xFF111111).withOpacity(0.14)
      : Colors.white.withOpacity(0.09);

  Color get brutalBorderColor => isLightCanvas
      ? const Color(0xFF111111)
      : Colors.white.withOpacity(0.88);

  Color get brutalShadowColor =>
      isLightCanvas ? const Color(0xFF111111) : const Color(0xFF050608);

  Future<void> loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    var rawMode = prefs.getString('ui_theme_mode_v2') ?? 'liquid_glass';
    if (rawMode == 'saweria') rawMode = 'neo_brutalism';
    _uiThemeMode = rawMode;

    var rawPreset = prefs.getString('theme_preset_id_v2') ?? 'ios_liquid';
    if (rawPreset == 'saweria_amber') rawPreset = 'brutal_amber';
    _selectedPresetId = rawPreset;

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
    final normalized = mode == 'saweria' ? 'neo_brutalism' : mode;
    _uiThemeMode = normalized;
    if (normalized == 'neo_brutalism') {
      // Ensure Neo-Brutalism defaults to authentic warm cream + punchy amber
      if (_oledPureBlack) {
        _oledPureBlack = false;
      }
      if (_selectedPresetId == 'ios_liquid') {
        _selectedPresetId = 'brutal_amber';
      }
    } else if (normalized == 'liquid_glass' &&
        _selectedPresetId == 'brutal_amber') {
      _selectedPresetId = 'ios_liquid';
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('ui_theme_mode_v2', normalized);
    await prefs.setString('theme_preset_id_v2', _selectedPresetId);
    await prefs.setBool('oled_pure_black', _oledPureBlack);
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

  Color _boostForAestheticUi(Color raw, {double hueShift = 0.0}) {
    final hsl = HSLColor.fromColor(raw);
    if (hsl.saturation < 0.11) {
      final fallback = HSLColor.fromColor(activePreset.primary);
      return fallback
          .withHue((fallback.hue + hueShift) % 360.0)
          .withSaturation(0.84)
          .withLightness(0.68)
          .toColor();
    }
    final nextHue = (hsl.hue + hueShift) % 360.0;
    final sat = hsl.saturation < 0.52
        ? (hsl.saturation + 0.36).clamp(0.66, 0.94)
        : hsl.saturation.clamp(0.66, 0.95);
    final light = hsl.lightness.clamp(0.65, 0.76);
    return hsl
        .withHue(nextHue)
        .withSaturation(sat)
        .withLightness(light)
        .toColor();
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
          palette.darkVibrantColor?.color ??
          palette.mutedColor?.color;
      if (rawPrimary != null) {
        final boostedPrimary = _boostForAestheticUi(rawPrimary);
        final sameHue = rawSecondary == null ||
            (HSLColor.fromColor(rawSecondary).hue -
                        HSLColor.fromColor(rawPrimary).hue)
                    .abs() <
                16.0;
        final boostedSecondary = _boostForAestheticUi(
          rawSecondary ?? rawPrimary,
          hueShift: sameHue ? 34.0 : 0.0,
        );
        final ambientVibrant = HSLColor.fromColor(boostedPrimary)
            .withSaturation(0.78)
            .withLightness(0.56)
            .toColor();
        final entry = _CachedPalettePair(
          ambient: ambientVibrant,
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
