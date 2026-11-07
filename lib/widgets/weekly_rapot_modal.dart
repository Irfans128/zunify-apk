import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/weekly_rapot_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import 'liquid_background_widget.dart';

/// Zunify 2.0 "Replay Anda & Wrapped Studio" (BitChord `ReplayScreen` + `ReplayStories` + `ReplayPoster`)
/// Mode 0: Interactive Liquid Glass Replay Dashboard (Minutes, Daily Activity Graph, Top Songs, Top Artists)
/// Mode 1: 3-Slide Swipeable Story & Poster Studio with 4 Liquid Glass Themes & 1-Tap HD PNG Share
class WeeklyRapotModal extends StatefulWidget {
  final WeeklyRapot rapot;

  const WeeklyRapotModal({super.key, required this.rapot});

  @override
  State<WeeklyRapotModal> createState() => _WeeklyRapotModalState();
}

class _WeeklyRapotModalState extends State<WeeklyRapotModal> {
  final GlobalKey _slide1CaptureKey = GlobalKey();
  final GlobalKey _slide2CaptureKey = GlobalKey();
  final GlobalKey _slide3CaptureKey = GlobalKey();
  late final PageController _pageController;

  int _viewMode = 0; // 0 = Replay Dashboard, 1 = Story & Poster Studio
  bool _isSharing = false;
  int _currentSlide = 0; // 0 = Replay Poster, 1 = Top 5 Songs, 2 = Top Artists & Aura
  int _selectedThemeIndex = 0; // 0: Liquid Glass, 1: Saweria, 2: Rose Quartz, 3: Lavender, 4: Matcha, 5: Champagne
  bool _didInitPosterTheme = false;

  bool get _isSaweriaPoster => _selectedThemeIndex == 1;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didInitPosterTheme) {
      _didInitPosterTheme = true;
      final isSaweriaApp = context.read<ThemeProvider>().isNeoBrutalism;
      _selectedThemeIndex = isSaweriaApp ? 1 : 0;
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  GlobalKey get _activeCaptureKey {
    if (_currentSlide == 1) return _slide2CaptureKey;
    if (_currentSlide == 2) return _slide3CaptureKey;
    return _slide1CaptureKey;
  }

  Future<void> _shareActiveSlide() async {
    setState(() => _isSharing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 60));
      final boundary = _activeCaptureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.2);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/zunify_replay_slide${_currentSlide + 1}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text:
            '🎧 Replay Musik gw di Zunify (${widget.rapot.formattedListenTime} • ${widget.rapot.vibePersonaTitle})',
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  List<Color> _getGradientColors(Color dynamicAccent) {
    switch (_selectedThemeIndex) {
      case 1: // Saweria (Cream Paper Neo-Brutalism)
        return const [
          Color(0xFFFAF4E6),
          Color(0xFFF7EFE0),
          Color(0xFFF3E8D2),
        ];
      case 2: // Rose Quartz
        return const [
          Color(0xFF4A152B),
          Color(0xFF1F0C18),
          Color(0xFF09070D),
        ];
      case 3: // Lavender Dream
        return const [
          Color(0xFF2E1A47),
          Color(0xFF141126),
          Color(0xFF070710),
        ];
      case 4: // Matcha Sage
        return const [
          Color(0xFF11382B),
          Color(0xFF0B1C1A),
          Color(0xFF060B0C),
        ];
      case 5: // Champagne Gold
        return const [
          Color(0xFF422C12),
          Color(0xFF1C140C),
          Color(0xFF090807),
        ];
      default: // iOS Liquid Glass
        return [
          dynamicAccent.withOpacity(0.36),
          const Color(0xFF101524),
          const Color(0xFF070911),
        ];
    }
  }

  Color _getPrimaryAccent(Color dynamicAccent) {
    switch (_selectedThemeIndex) {
      case 1: // Saweria Mustard
        return const Color(0xFFFAAE2B);
      case 2:
        return const Color(0xFFF48FB1);
      case 3:
        return const Color(0xFFB39DDB);
      case 4:
        return const Color(0xFF66BB6A);
      case 5:
        return const Color(0xFFFFD54F);
      default:
        return dynamicAccent;
    }
  }

  Color _getSecondaryAccent(Color dynamicSecondary) {
    switch (_selectedThemeIndex) {
      case 1: // Saweria Warm Coral/Amber
        return const Color(0xFFFF7A59);
      case 2:
        return const Color(0xFFCE93D8);
      case 3:
        return const Color(0xFF90CAF9);
      case 4:
        return const Color(0xFF26A69A);
      case 5:
        return const Color(0xFFFFAB91);
      default:
        return dynamicSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final library = context.watch<LibraryProvider>();
    final player = context.watch<PlayerProvider>();
    final isBrutal = theme.isNeoBrutalism;
    final topRadius = isBrutal ? 18.0 : 32.0;
    final posterPrimaryAccent = _getPrimaryAccent(theme.accentColor);
    final posterSecondaryAccent =
        _getSecondaryAccent(theme.secondaryAccentColor);
    final primaryAccent =
        _viewMode == 0 ? theme.accentColor : posterPrimaryAccent;
    final secondaryAccent =
        _viewMode == 0 ? theme.secondaryAccentColor : posterSecondaryAccent;
    final gradientColors = _getGradientColors(theme.accentColor);
    final rapot = widget.rapot;
    final topCoverUrl = rapot.topSongs.isNotEmpty
        ? rapot.topSongs.first.song.highResArtUrl
        : null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: theme.scaffoldBgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
        border: Border(
          top: BorderSide(
            color: isBrutal
                ? theme.brutalBorderColor
                : Colors.white.withOpacity(0.14),
            width: isBrutal ? 2.8 : 1.0,
          ),
          left: isBrutal
              ? BorderSide(color: theme.brutalBorderColor, width: 2.2)
              : BorderSide.none,
          right: isBrutal
              ? BorderSide(color: theme.brutalBorderColor, width: 2.2)
              : BorderSide.none,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
        child: LiquidBackgroundWidget(
          primaryColor: primaryAccent,
          secondaryColor: secondaryAccent,
          baseColor: theme.scaffoldBgColor,
          imageUrl: topCoverUrl,
          intensity: 0.56,
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
              child: Column(
                children: [
                  // Top Drag Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.textMuted.withOpacity(0.38),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Top Header + Segmented Mode Switcher ("Statistik" | "Poster HD")
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Zunify Wrapped',
                              style: GoogleFonts.plusJakartaSans(
                                color: theme.textPrimary,
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.4,
                              ),
                            ),
                            Text(
                              'Replay Mingguan • ${rapot.weekId}',
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 11.2,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      LiquidGlassBox(
                        height: 36,
                        borderRadius: isBrutal ? 11 : 18,
                        padding: const EdgeInsets.all(3),
                        tintOpacity: 0.10,
                        rimIntensity: 0.38,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _topModePill(
                              theme: theme,
                              label: 'Statistik',
                              selected: _viewMode == 0,
                              accent: primaryAccent,
                              onTap: () => setState(() => _viewMode = 0),
                            ),
                            _topModePill(
                              theme: theme,
                              label: 'Poster HD',
                              selected: _viewMode == 1,
                              accent: primaryAccent,
                              onTap: () => setState(() => _viewMode = 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IosGlassIconButton(
                        icon: Icons.close_rounded,
                        size: 36,
                        iconSize: 18,
                        onTap: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Body: Interactive Replay Dashboard OR Story/Poster Studio
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: _viewMode == 0
                          ? _buildReplayDashboard(
                              theme: theme,
                              username: library.profile.username,
                              rapot: rapot,
                              player: player,
                              primaryAccent: primaryAccent,
                              secondaryAccent: secondaryAccent,
                            )
                          : _buildPosterStudio(
                              theme: theme,
                              username: library.profile.username,
                              rapot: rapot,
                              primaryAccent: primaryAccent,
                              secondaryAccent: secondaryAccent,
                              gradientColors: gradientColors,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _topModePill({
    required ThemeProvider theme,
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final isBrutal = theme.isNeoBrutalism;
    return IosSpringButton(
      scaleDown: 0.88,
      borderRadius: isBrutal ? 8 : 15,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isBrutal && selected ? accent : null,
          gradient: (!isBrutal && selected)
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(0.24),
                    accent.withOpacity(0.26),
                  ],
                )
              : null,
          borderRadius: BorderRadius.circular(isBrutal ? 8 : 15),
          border: Border.all(
            color: selected
                ? (isBrutal
                    ? theme.brutalBorderColor
                    : Colors.white.withOpacity(0.36))
                : Colors.transparent,
            width: isBrutal ? 1.8 : 0.9,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isBrutal
                ? (selected ? const Color(0xFF111111) : theme.textSecondary)
                : (selected ? Colors.white : Colors.white60),
            fontSize: 11.2,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  /// Interactive Replay Dashboard (Adapts to Liquid Glass & Neo-Brutalism)
  Widget _buildReplayDashboard({
    required ThemeProvider theme,
    required String username,
    required WeeklyRapot rapot,
    required PlayerProvider player,
    required Color primaryAccent,
    required Color secondaryAccent,
  }) {
    final isBrutal = theme.isNeoBrutalism;
    final accentReadable =
        theme.isLightCanvas ? theme.accentText : primaryAccent;
    final weekdayLabels = const [
      'Sen',
      'Sel',
      'Rab',
      'Kam',
      'Jum',
      'Sab',
      'Min',
    ];
    int maxDayMins = 1;
    for (final v in rapot.minutesPerWeekday.values) {
      if (v > maxDayMins) maxDayMins = v;
    }

    return ListView(
      key: const ValueKey('replay_dashboard_view'),
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. Hero Replay Summary Card
        LiquidGlassBox(
          borderRadius: 26,
          padding: const EdgeInsets.all(18),
          tintColor: primaryAccent,
          tintOpacity: 0.12,
          rimIntensity: 0.45,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isBrutal
                          ? primaryAccent
                          : primaryAccent.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(isBrutal ? 8 : 12),
                      border: Border.all(
                        color: isBrutal
                            ? theme.brutalBorderColor
                            : primaryAccent.withOpacity(0.45),
                        width: isBrutal ? 1.8 : 1.0,
                      ),
                    ),
                    child: Text(
                      'REPLAY MINGGUAN • $username',
                      style: TextStyle(
                        color: isBrutal
                            ? const Color(0xFF111111)
                            : primaryAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.graphic_eq_rounded,
                    color: accentReadable,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${rapot.totalMinutes}',
                    style: GoogleFonts.plusJakartaSans(
                      color: theme.textPrimary,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 5),
                      child: Text(
                        'menit waktu dengar (${rapot.formattedListenTime})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 3 Mini Stat Pills inside Hero Card
              Row(
                children: [
                  Expanded(
                    child: _miniStatPill(
                      theme: theme,
                      label: 'Total Putar',
                      value: '${rapot.totalTracksPlayed}x',
                      valueColor: accentReadable,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _miniStatPill(
                      theme: theme,
                      label: 'Lagu Teratas',
                      value: '${rapot.topSongs.length} Lagu',
                      valueColor:
                          theme.isLightCanvas ? theme.textPrimary : secondaryAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _miniStatPill(
                      theme: theme,
                      label: 'Artis',
                      value: '${rapot.topArtists.length} Artis',
                      valueColor: theme.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: theme.subtleFill,
                  borderRadius: BorderRadius.circular(isBrutal ? 10 : 14),
                  border: Border.all(
                    color:
                        isBrutal ? theme.brutalBorderColor : theme.dividerColor,
                    width: isBrutal ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: accentReadable,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rapot.vibePersonaTitle,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            rapot.vibePersonaSubtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 2. Daily Listening Activity Bar Chart (Senin - Minggu)
        LiquidGlassBox(
          borderRadius: 22,
          padding: const EdgeInsets.all(16),
          tintOpacity: 0.08,
          rimIntensity: 0.34,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Aktivitas Hari ke Hari',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Menit / Hari',
                    style: TextStyle(
                      color: accentReadable,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              SizedBox(
                height: 92,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(7, (idx) {
                    final dayNum = idx + 1;
                    final mins = rapot.minutesPerWeekday[dayNum] ?? 0;
                    final ratio = (mins / maxDayMins).clamp(0.10, 1.0);
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          mins > 0 ? '${mins}m' : '-',
                          style: TextStyle(
                            color: mins > 0
                                ? theme.textSecondary
                                : theme.textMuted.withOpacity(0.55),
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 22,
                          height: 52 * ratio,
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(isBrutal ? 6 : 8),
                            color: isBrutal
                                ? (mins > 0 ? primaryAccent : theme.subtleFill)
                                : null,
                            border: isBrutal
                                ? Border.all(
                                    color: theme.brutalBorderColor,
                                    width: 1.6,
                                  )
                                : null,
                            gradient: isBrutal
                                ? null
                                : LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: mins > 0
                                        ? [primaryAccent, secondaryAccent]
                                        : [
                                            Colors.white.withOpacity(0.10),
                                            Colors.white.withOpacity(0.05),
                                          ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          weekdayLabels[idx],
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // 3. Top Artists Carousel
        if (rapot.topArtists.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Artis Teratas Minggu Ini',
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(
            height: 124,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: rapot.topArtists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, idx) {
                final artist = rapot.topArtists[idx];
                return LiquidGlassBox(
                  borderRadius: 20,
                  width: 114,
                  padding: const EdgeInsets.all(10),
                  tintOpacity: idx == 0 ? 0.14 : 0.07,
                  rimIntensity: idx == 0 ? 0.44 : 0.30,
                  tintColor: idx == 0 ? primaryAccent : Colors.white,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: isBrutal
                              ? Border.all(
                                  color: theme.brutalBorderColor,
                                  width: 1.8,
                                )
                              : null,
                        ),
                        child: ClipOval(
                          child: CachedNetworkImage(
                            imageUrl: artist.sampleThumbnailUrl,
                            width: 48,
                            height: 48,
                            memCacheWidth: 140,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _fallbackThumb(48, primaryAccent),
                          ),
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        '#${idx + 1} ${artist.artistName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${artist.playCount}x • ${artist.totalMinutes} mnt',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: idx == 0 ? accentReadable : theme.textMuted,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),
        ],

        // 4. Top Songs Ranked List (without Putar Semua button)
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Lagu Paling Sering Diputar',
            style: TextStyle(
              color: theme.textPrimary,
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 8),
        if (rapot.topSongs.isEmpty)
          LiquidGlassBox(
            borderRadius: 20,
            padding: const EdgeInsets.all(20),
            child: Text(
              'Belum ada riwayat pemutaran minggu ini. Putar lagu favoritmu untuk mengisi Replay!',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textSecondary, fontSize: 12.5),
            ),
          )
        else
          ...List.generate(rapot.topSongs.length, (i) {
            final item = rapot.topSongs[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: LiquidGlassBox(
                borderRadius: 18,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 9,
                ),
                tintColor: i == 0 ? primaryAccent : Colors.white,
                tintOpacity: i == 0 ? 0.14 : 0.06,
                rimIntensity: i == 0 ? 0.44 : 0.28,
                onTap: () {
                  final songs = rapot.topSongs.map((e) => e.song).toList();
                  player.playSong(
                    songs[i],
                    customQueue: songs,
                    contextName: 'Replay Mingguan',
                  );
                },
                child: Row(
                  children: [
                    SizedBox(
                      width: 28,
                      child: Text(
                        '#${i + 1}',
                        style: TextStyle(
                          color:
                              i == 0 ? accentReadable : theme.textSecondary,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: isBrutal
                            ? Border.all(
                                color: theme.brutalBorderColor,
                                width: 1.6,
                              )
                            : null,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8.5),
                        child: CachedNetworkImage(
                          imageUrl: item.song.thumbnailUrl,
                          width: 44,
                          height: 44,
                          memCacheWidth: 132,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _fallbackThumb(44, primaryAccent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            item.song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 11.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isBrutal
                            ? primaryAccent
                            : primaryAccent.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(isBrutal ? 8 : 10),
                        border: isBrutal
                            ? Border.all(
                                color: theme.brutalBorderColor,
                                width: 1.5,
                              )
                            : null,
                      ),
                      child: Text(
                        '${item.playCount}x',
                        style: TextStyle(
                          color: isBrutal
                              ? const Color(0xFF111111)
                              : primaryAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 11.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        const SizedBox(height: 12),

        // CTA to open Poster Studio
        IosSpringButton(
          borderRadius: isBrutal ? 12 : 23,
          onTap: () => setState(() => _viewMode = 1),
          child: Container(
            width: double.infinity,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primaryAccent,
              borderRadius: BorderRadius.circular(isBrutal ? 12 : 23),
              border: isBrutal
                  ? Border.all(color: theme.brutalBorderColor, width: 2.2)
                  : null,
              boxShadow: [
                isBrutal
                    ? BoxShadow(
                        color: theme.brutalShadowColor,
                        blurRadius: 0,
                        offset: const Offset(3.5, 3.5),
                      )
                    : BoxShadow(
                        color: primaryAccent.withOpacity(0.32),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
              ],
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.auto_awesome_motion_rounded,
                  size: 18,
                  color: Color(0xFF111111),
                ),
                SizedBox(width: 8),
                Text(
                  'Buat Poster & Kartu Story Wrapped HD',
                  style: TextStyle(
                    color: Color(0xFF111111),
                    fontWeight: FontWeight.w800,
                    fontSize: 13.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniStatPill({
    required ThemeProvider theme,
    required String label,
    required String value,
    required Color valueColor,
  }) {
    final isBrutal = theme.isNeoBrutalism;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: theme.subtleFill,
        borderRadius: BorderRadius.circular(isBrutal ? 10 : 14),
        border: Border.all(
          color: isBrutal ? theme.brutalBorderColor : theme.dividerColor,
          width: isBrutal ? 1.6 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: theme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: valueColor,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  /// Zunify Wrapped 3-Slide Poster Studio
  Widget _buildPosterStudio({
    required ThemeProvider theme,
    required String username,
    required WeeklyRapot rapot,
    required Color primaryAccent,
    required Color secondaryAccent,
    required List<Color> gradientColors,
  }) {
    final isBrutal = theme.isNeoBrutalism;
    const themeLabels = [
      '💧 Liquid Glass',
      '⚡ Neo-Brutalism',
      '🌸 Rose Quartz',
      '🔮 Lavender Dream',
      '🍃 Matcha Sage',
      '✨ Champagne Gold',
    ];

    return Column(
      key: const ValueKey('poster_studio_view'),
      children: [
        // Slide selector pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.none,
          padding: EdgeInsets.only(bottom: isBrutal ? 3 : 0),
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              IosGlassPillButton(
                label: '1 • Ringkasan',
                height: 31,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                activeColor: primaryAccent,
                isActive: _currentSlide == 0,
                fontSize: 11.2,
                onTap: () => _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                ),
              ),
              const SizedBox(width: 6),
              IosGlassPillButton(
                label: '2 • Top 5 Lagu',
                height: 31,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                activeColor: primaryAccent,
                isActive: _currentSlide == 1,
                fontSize: 11.2,
                onTap: () => _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                ),
              ),
              const SizedBox(width: 6),
              IosGlassPillButton(
                label: '3 • Artis & Aura',
                height: 31,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                activeColor: primaryAccent,
                isActive: _currentSlide == 2,
                fontSize: 11.2,
                onTap: () => _pageController.animateToPage(
                  2,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: isBrutal ? 36 : 32,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: EdgeInsets.only(bottom: isBrutal ? 4 : 0, right: 4),
            physics: const BouncingScrollPhysics(),
            itemCount: themeLabels.length,
            separatorBuilder: (_, __) => const SizedBox(width: 7),
            itemBuilder: (context, idx) {
              final selected = _selectedThemeIndex == idx;
              return IosGlassPillButton(
                label: themeLabels[idx],
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 13),
                activeColor: primaryAccent,
                isActive: selected,
                fontSize: 11.2,
                onTap: () => setState(() => _selectedThemeIndex = idx),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        // 3-Slide Swipeable Story Deck
        Expanded(
          child: PageView(
            controller: _pageController,
            onPageChanged: (idx) => setState(() => _currentSlide = idx),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: RepaintBoundary(
                  key: _slide1CaptureKey,
                  child: _buildStoryContainer(
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent,
                    gradientColors: gradientColors,
                    child: _buildSlide1Content(
                      username: username,
                      rapot: rapot,
                      primaryAccent: primaryAccent,
                      secondaryAccent: secondaryAccent,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: RepaintBoundary(
                  key: _slide2CaptureKey,
                  child: _buildStoryContainer(
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent,
                    gradientColors: gradientColors,
                    child: _buildSlide2Content(
                      username: username,
                      rapot: rapot,
                      primaryAccent: primaryAccent,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: RepaintBoundary(
                  key: _slide3CaptureKey,
                  child: _buildStoryContainer(
                    primaryAccent: primaryAccent,
                    secondaryAccent: secondaryAccent,
                    gradientColors: gradientColors,
                    child: _buildSlide3Content(
                      username: username,
                      rapot: rapot,
                      primaryAccent: primaryAccent,
                      secondaryAccent: secondaryAccent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Page indicator dots
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _dot(_currentSlide == 0, primaryAccent, theme.dividerColor),
            const SizedBox(width: 6),
            _dot(_currentSlide == 1, primaryAccent, theme.dividerColor),
            const SizedBox(width: 6),
            _dot(_currentSlide == 2, primaryAccent, theme.dividerColor),
            const SizedBox(width: 10),
            Text(
              'Geser kiri/kanan untuk pindah poster',
              style: TextStyle(color: theme.textMuted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Share Active Slide Button
        IosSpringButton(
          borderRadius: isBrutal ? 12 : 23,
          onTap: _isSharing ? null : _shareActiveSlide,
          child: Container(
            width: double.infinity,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: primaryAccent,
              borderRadius: BorderRadius.circular(isBrutal ? 12 : 23),
              border: isBrutal
                  ? Border.all(color: theme.brutalBorderColor, width: 2.2)
                  : null,
              boxShadow: [
                isBrutal
                    ? BoxShadow(
                        color: theme.brutalShadowColor,
                        blurRadius: 0,
                        offset: const Offset(3.5, 3.5),
                      )
                    : BoxShadow(
                        color: primaryAccent.withOpacity(0.32),
                        blurRadius: 14,
                        offset: const Offset(0, 5),
                      ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (_isSharing)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Color(0xFF111111),
                    ),
                  )
                else
                  const Icon(
                    Icons.ios_share_rounded,
                    size: 18,
                    color: Color(0xFF111111),
                  ),
                const SizedBox(width: 8),
                Text(
                  _isSharing
                      ? 'Menyiapkan Poster HD...'
                      : 'Bagikan Poster ${_currentSlide + 1} ke IG Story / WA',
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontWeight: FontWeight.w800,
                    fontSize: 13.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _dot(bool active, Color accent, Color inactiveColor) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 18 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? accent : inactiveColor,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildStoryContainer({
    required Color primaryAccent,
    required Color secondaryAccent,
    required List<Color> gradientColors,
    required Widget child,
  }) {
    final saweria = _isSaweriaPoster;
    if (saweria) {
      return Padding(
        padding: const EdgeInsets.only(right: 4, bottom: 4),
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: gradientColors,
            ),
            border: Border.all(
              color: const Color(0xFF111111),
              width: 2.6,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0xFF111111),
                blurRadius: 0,
                offset: Offset(4.0, 4.0),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(15.4),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Positioned(
                  top: -38,
                  right: -28,
                  child: Container(
                    width: 126,
                    height: 126,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: primaryAccent.withOpacity(0.32),
                      border: Border.all(
                        color: const Color(0xFF111111).withOpacity(0.16),
                        width: 2.0,
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -44,
                  left: -30,
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: secondaryAccent.withOpacity(0.22),
                      border: Border.all(
                        color: const Color(0xFF111111).withOpacity(0.14),
                        width: 2.0,
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: Border.all(
          color: primaryAccent.withOpacity(0.45),
          width: 1.4,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: Stack(
          fit: StackFit.expand,
          children: [
            Positioned(
              top: -45,
              right: -35,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: primaryAccent.withOpacity(0.20),
                ),
              ),
            ),
            Positioned(
              bottom: -50,
              left: -35,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: secondaryAccent.withOpacity(0.16),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
              child: child,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterHeaderBadge({
    required String label,
    required String slideCounter,
    required Color primaryAccent,
  }) {
    final saweria = _isSaweriaPoster;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: saweria
              ? BoxDecoration(
                  color: primaryAccent,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF111111),
                    width: 1.8,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFF111111),
                      blurRadius: 0,
                      offset: Offset(2.0, 2.0),
                    ),
                  ],
                )
              : BoxDecoration(
                  color: primaryAccent.withOpacity(0.16),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: primaryAccent.withOpacity(0.4)),
                ),
          child: Text(
            label,
            style: TextStyle(
              color: saweria ? const Color(0xFF111111) : primaryAccent,
              fontSize: 10,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
        ),
        const Spacer(),
        Text(
          slideCounter,
          style: TextStyle(
            color: saweria ? const Color(0xFF5C5449) : Colors.white38,
            fontSize: 10,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildSlide1Content({
    required String username,
    required WeeklyRapot rapot,
    required Color primaryAccent,
    required Color secondaryAccent,
  }) {
    final saweria = _isSaweriaPoster;
    final textMain = saweria ? const Color(0xFF111111) : Colors.white;
    final textSub =
        saweria ? const Color(0xFF4B453C) : Colors.white.withOpacity(0.75);
    final topOne = rapot.topSongs.isNotEmpty ? rapot.topSongs.first : null;
    final topArtist = topOne != null ? topOne.song.artist : 'Eksplorasi Baru';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPosterHeaderBadge(
          label: 'REPLAY STUDIO • ${rapot.weekId}',
          slideCounter: '1 / 3',
          primaryAccent: primaryAccent,
        ),
        const SizedBox(height: 10),
        Text(
          'Replay Musik $username',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            color: textMain,
            fontSize: 20.5,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '${rapot.vibePersonaTitle} — ${rapot.vibePersonaSubtitle}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textSub,
            fontSize: 11.5,
            fontWeight: saweria ? FontWeight.w600 : FontWeight.w500,
            height: 1.28,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: saweria
              ? BoxDecoration(
                  color: const Color(0xFFFFFDF7),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: const Color(0xFF111111),
                    width: 2.0,
                  ),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0xFF111111),
                      blurRadius: 0,
                      offset: Offset(3.0, 3.0),
                    ),
                  ],
                )
              : BoxDecoration(
                  color: Colors.white.withOpacity(0.07),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: primaryAccent.withOpacity(0.38)),
                ),
          child: Row(
            children: [
              Container(
                decoration: saweria
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFF111111),
                          width: 1.8,
                        ),
                      )
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(saweria ? 8.2 : 12),
                  child: topOne != null
                      ? CachedNetworkImage(
                          imageUrl: topOne.song.highResArtUrl,
                          width: 60,
                          height: 60,
                          memCacheWidth: 190,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) =>
                              _fallbackThumb(60, primaryAccent),
                        )
                      : _fallbackThumb(60, primaryAccent),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: primaryAccent,
                        borderRadius: BorderRadius.circular(6),
                        border: saweria
                            ? Border.all(
                                color: const Color(0xFF111111),
                                width: 1.4,
                              )
                            : null,
                      ),
                      child: const Text(
                        '👑 #1 LAGU TERATAS',
                        style: TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      topOne?.song.title ?? 'Belum Ada Lagu Diputar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: textMain,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      topOne != null
                          ? '${topOne.song.artist} • ${topOne.playCount}x diputar'
                          : 'Putar musik favoritmu minggu ini!',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color:
                            saweria ? const Color(0xFF9A5B00) : primaryAccent,
                        fontSize: 11.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _bentoBox(
                        icon: Icons.headphones_rounded,
                        label: 'WAKTU DENGAR',
                        value: rapot.formattedListenTime,
                        color: primaryAccent,
                        tintedSaweria: true,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _bentoBox(
                        icon: Icons.bolt_rounded,
                        label: 'TOTAL PUTAR',
                        value: '${rapot.totalTracksPlayed} Lagu',
                        color: secondaryAccent,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: _bentoBox(
                        icon: Icons.mic_external_on_rounded,
                        label: 'ARTIS TERATAS',
                        value: topArtist,
                        color: saweria ? const Color(0xFF111111) : Colors.white,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _bentoBox(
                        icon: Icons.auto_graph_rounded,
                        label: 'AURA MUSIK',
                        value: rapot.vibePersonaTitle
                            .replaceAll(RegExp(r'[^\w\s]'), '')
                            .trim(),
                        color: primaryAccent,
                        tintedSaweria: true,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _buildWatermarkFooter(primaryAccent),
      ],
    );
  }

  Widget _buildSlide2Content({
    required String username,
    required WeeklyRapot rapot,
    required Color primaryAccent,
  }) {
    final saweria = _isSaweriaPoster;
    final textMain = saweria ? const Color(0xFF111111) : Colors.white;
    final textSub =
        saweria ? const Color(0xFF575046) : Colors.white.withOpacity(0.65);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPosterHeaderBadge(
          label: 'TOP CHARTS • ${rapot.weekId}',
          slideCounter: '2 / 3',
          primaryAccent: primaryAccent,
        ),
        const SizedBox(height: 10),
        Text(
          'Top 5 Lagu $username 🔥',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            color: textMain,
            fontSize: 19.5,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Lagu yang paling sering menemani harimu minggu ini',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textSub,
            fontSize: 11.2,
            fontWeight: saweria ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: rapot.topSongs.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada lagu yang diputar minggu ini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: textSub, fontSize: 12.5),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    rapot.topSongs.length.clamp(0, 5),
                    (i) {
                      final item = rapot.topSongs[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6.5,
                        ),
                        decoration: saweria
                            ? BoxDecoration(
                                color: i == 0
                                    ? const Color(0xFFFFE59D)
                                    : const Color(0xFFFFFDF7),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: const Color(0xFF111111),
                                  width: 1.8,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xFF111111),
                                    blurRadius: 0,
                                    offset: Offset(2.2, 2.2),
                                  ),
                                ],
                              )
                            : BoxDecoration(
                                color: i == 0
                                    ? primaryAccent.withOpacity(0.14)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: i == 0
                                      ? primaryAccent.withOpacity(0.45)
                                      : Colors.white.withOpacity(0.06),
                                ),
                              ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: Text(
                                '#${i + 1}',
                                style: TextStyle(
                                  color: saweria
                                      ? const Color(0xFF111111)
                                      : (i == 0
                                          ? primaryAccent
                                          : Colors.white70),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Container(
                              decoration: saweria
                                  ? BoxDecoration(
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(
                                        color: const Color(0xFF111111),
                                        width: 1.4,
                                      ),
                                    )
                                  : null,
                              child: ClipRRect(
                                borderRadius:
                                    BorderRadius.circular(saweria ? 5.6 : 8),
                                child: CachedNetworkImage(
                                  imageUrl: item.song.thumbnailUrl,
                                  width: 36,
                                  height: 36,
                                  memCacheWidth: 120,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      _fallbackThumb(36, primaryAccent),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    item.song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: textMain,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  Text(
                                    item.song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: saweria
                                          ? const Color(0xFF575046)
                                          : Colors.white60,
                                      fontSize: 10.5,
                                      fontWeight: saweria
                                          ? FontWeight.w600
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: saweria
                                  ? BoxDecoration(
                                      color: primaryAccent,
                                      borderRadius: BorderRadius.circular(7),
                                      border: Border.all(
                                        color: const Color(0xFF111111),
                                        width: 1.4,
                                      ),
                                    )
                                  : BoxDecoration(
                                      color: primaryAccent.withOpacity(0.16),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                              child: Text(
                                '${item.playCount}x',
                                style: TextStyle(
                                  color: saweria
                                      ? const Color(0xFF111111)
                                      : primaryAccent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 11,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(height: 8),
        _buildWatermarkFooter(primaryAccent),
      ],
    );
  }

  Widget _buildSlide3Content({
    required String username,
    required WeeklyRapot rapot,
    required Color primaryAccent,
    required Color secondaryAccent,
  }) {
    final saweria = _isSaweriaPoster;
    final textMain = saweria ? const Color(0xFF111111) : Colors.white;
    final textSub =
        saweria ? const Color(0xFF575046) : Colors.white.withOpacity(0.65);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPosterHeaderBadge(
          label: 'TOP ARTISTS • ${rapot.weekId}',
          slideCounter: '3 / 3',
          primaryAccent: primaryAccent,
        ),
        const SizedBox(height: 10),
        Text(
          'Artis Favorit $username 🌟',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            color: textMain,
            fontSize: 19.5,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'Musisi yang paling mendominasi telingamu minggu ini',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: textSub,
            fontSize: 11.2,
            fontWeight: saweria ? FontWeight.w600 : FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: rapot.topArtists.isEmpty
              ? Center(
                  child: Text(
                    'Belum ada statistik artis minggu ini.',
                    style: TextStyle(color: textSub, fontSize: 12.5),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: List.generate(
                    rapot.topArtists.length.clamp(0, 5),
                    (i) {
                      final artist = rapot.topArtists[i];
                      return Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: saweria
                            ? BoxDecoration(
                                color: i == 0
                                    ? const Color(0xFFFFE59D)
                                    : const Color(0xFFFFFDF7),
                                borderRadius: BorderRadius.circular(11),
                                border: Border.all(
                                  color: const Color(0xFF111111),
                                  width: 1.8,
                                ),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Color(0xFF111111),
                                    blurRadius: 0,
                                    offset: Offset(2.2, 2.2),
                                  ),
                                ],
                              )
                            : BoxDecoration(
                                color: i == 0
                                    ? primaryAccent.withOpacity(0.14)
                                    : Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(13),
                                border: Border.all(
                                  color: i == 0
                                      ? primaryAccent.withOpacity(0.45)
                                      : Colors.white.withOpacity(0.06),
                                ),
                              ),
                        child: Row(
                          children: [
                            SizedBox(
                              width: 24,
                              child: Text(
                                '#${i + 1}',
                                style: TextStyle(
                                  color: saweria
                                      ? const Color(0xFF111111)
                                      : (i == 0
                                          ? primaryAccent
                                          : Colors.white70),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Container(
                              decoration: saweria
                                  ? BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: const Color(0xFF111111),
                                        width: 1.5,
                                      ),
                                    )
                                  : null,
                              child: ClipOval(
                                child: CachedNetworkImage(
                                  imageUrl: artist.sampleThumbnailUrl,
                                  width: 36,
                                  height: 36,
                                  memCacheWidth: 120,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) =>
                                      _fallbackThumb(36, primaryAccent),
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                artist.artistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textMain,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '${artist.playCount}x • ${artist.totalMinutes} mnt',
                              style: TextStyle(
                                color: saweria
                                    ? const Color(0xFF111111)
                                    : (i == 0 ? primaryAccent : Colors.white70),
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
        ),
        const SizedBox(height: 8),
        _buildWatermarkFooter(primaryAccent),
      ],
    );
  }

  Widget _bentoBox({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool tintedSaweria = false,
  }) {
    final saweria = _isSaweriaPoster;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: saweria
          ? BoxDecoration(
              color: tintedSaweria
                  ? const Color(0xFFFFF2CC)
                  : const Color(0xFFFFFDF7),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF111111),
                width: 1.9,
              ),
              boxShadow: const [
                BoxShadow(
                  color: Color(0xFF111111),
                  blurRadius: 0,
                  offset: Offset(2.5, 2.5),
                ),
              ],
            )
          : BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
            ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: saweria ? const Color(0xFF111111) : color,
                size: 13,
              ),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: saweria ? const Color(0xFF5C5449) : Colors.white54,
                    fontSize: 9.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: saweria ? const Color(0xFF111111) : Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatermarkFooter(Color accent) {
    final saweria = _isSaweriaPoster;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              Icons.graphic_eq_rounded,
              color: saweria ? const Color(0xFF111111) : accent,
              size: 15,
            ),
            const SizedBox(width: 5),
            Text(
              'ZUNIFY 2.0',
              style: TextStyle(
                color: saweria ? const Color(0xFF111111) : Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        if (saweria)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF111111),
                width: 1.4,
              ),
            ),
            child: const Text(
              'Zunify Wrapped',
              style: TextStyle(
                color: Color(0xFF111111),
                fontSize: 9.8,
                fontWeight: FontWeight.w900,
              ),
            ),
          )
        else
          Text(
            'Zunify Wrapped',
            style: TextStyle(
              color: accent,
              fontSize: 10.5,
              fontWeight: FontWeight.w800,
            ),
          ),
      ],
    );
  }

  Widget _fallbackThumb(double size, Color accent) {
    final saweria = _isSaweriaPoster;
    return Container(
      width: size,
      height: size,
      color: saweria ? const Color(0xFFF2E8D5) : Colors.white10,
      child: Icon(
        Icons.music_note_rounded,
        color: saweria ? const Color(0xFF111111) : accent,
        size: size * 0.45,
      ),
    );
  }
}
