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
  int _selectedThemeIndex = 0; // 0: Liquid Glass, 1: Crimson Z, 2: Midnight Violet, 3: Cyber Emerald

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
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
      case 1: // Crimson Z
        return const [
          Color(0xFF4C0519),
          Color(0xFF180812),
          Color(0xFF07060B),
        ];
      case 2: // Midnight Violet
        return const [
          Color(0xFF2E1065),
          Color(0xFF0F172A),
          Color(0xFF060812),
        ];
      case 3: // Cyber Emerald
        return const [
          Color(0xFF064E3B),
          Color(0xFF09191F),
          Color(0xFF050A0E),
        ];
      default: // Dynamic Liquid Glass
        return [
          dynamicAccent.withOpacity(0.38),
          const Color(0xFF0E1424),
          const Color(0xFF060810),
        ];
    }
  }

  Color _getPrimaryAccent(Color dynamicAccent) {
    switch (_selectedThemeIndex) {
      case 1:
        return const Color(0xFFFF2E4C);
      case 2:
        return const Color(0xFFA855F7);
      case 3:
        return const Color(0xFF00F5A0);
      default:
        return dynamicAccent;
    }
  }

  Color _getSecondaryAccent(Color dynamicSecondary) {
    switch (_selectedThemeIndex) {
      case 1:
        return const Color(0xFFFF7A33);
      case 2:
        return const Color(0xFF38BDF8);
      case 3:
        return const Color(0xFF00D9F5);
      default:
        return dynamicSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final library = context.watch<LibraryProvider>();
    final player = context.watch<PlayerProvider>();
    final primaryAccent = _getPrimaryAccent(theme.accentColor);
    final secondaryAccent = _getSecondaryAccent(theme.secondaryAccentColor);
    final gradientColors = _getGradientColors(theme.accentColor);
    final rapot = widget.rapot;
    final topCoverUrl = rapot.topSongs.isNotEmpty
        ? rapot.topSongs.first.song.highResArtUrl
        : null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: const Color(0xFF070A12),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        border: Border.all(color: Colors.white.withOpacity(0.12)),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        child: LiquidBackgroundWidget(
          primaryColor: primaryAccent,
          secondaryColor: secondaryAccent,
          baseColor: const Color(0xFF070A12),
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
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // BitChord Frosted Top Header + Segmented Mode Switcher ("Replay Anda" | "Story & Poster")
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Replay Anda',
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 19,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.4,
                              ),
                            ),
                            Text(
                              'Statistik & Kartu Musik • ${rapot.weekId}',
                              style: const TextStyle(
                                color: Colors.white54,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      LiquidGlassBox(
                        borderRadius: 20,
                        padding: const EdgeInsets.all(3),
                        tintOpacity: 0.10,
                        rimIntensity: 0.40,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _topModePill(
                              label: 'Statistik',
                              selected: _viewMode == 0,
                              accent: primaryAccent,
                              onTap: () => setState(() => _viewMode = 0),
                            ),
                            _topModePill(
                              label: 'Poster HD',
                              selected: _viewMode == 1,
                              accent: primaryAccent,
                              onTap: () => setState(() => _viewMode = 1),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      LiquidGlassBox(
                        borderRadius: 18,
                        width: 34,
                        height: 34,
                        tintOpacity: 0.08,
                        rimIntensity: 0.34,
                        onTap: () => Navigator.pop(context),
                        child: const Icon(
                          Icons.close_rounded,
                          color: Colors.white70,
                          size: 18,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Body: Either Interactive BitChord Replay Dashboard OR Story/Poster Studio
                  Expanded(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 240),
                      child: _viewMode == 0
                          ? _buildReplayDashboard(
                              username: library.profile.username,
                              rapot: rapot,
                              player: player,
                              primaryAccent: primaryAccent,
                              secondaryAccent: secondaryAccent,
                            )
                          : _buildPosterStudio(
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
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5.5),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.black : Colors.white70,
            fontSize: 11.2,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  /// BitChord `ReplayScreen` Interactive Dashboard
  Widget _buildReplayDashboard({
    required String username,
    required WeeklyRapot rapot,
    required PlayerProvider player,
    required Color primaryAccent,
    required Color secondaryAccent,
  }) {
    final weekdayLabels = const ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];
    int maxDayMins = 1;
    for (final v in rapot.minutesPerWeekday.values) {
      if (v > maxDayMins) maxDayMins = v;
    }

    return ListView(
      key: const ValueKey('replay_dashboard_view'),
      physics: const BouncingScrollPhysics(),
      children: [
        // 1. Hero Liquid Glass Replay Summary Card
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
                      color: primaryAccent.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: primaryAccent.withOpacity(0.45)),
                    ),
                    child: Text(
                      'REPLAY MINGGUAN • $username',
                      style: TextStyle(
                        color: primaryAccent,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.7,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.graphic_eq_rounded,
                    color: primaryAccent,
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
                      color: Colors.white,
                      fontSize: 42,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                      letterSpacing: -1.2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 5),
                    child: Text(
                      'menit waktu dengar (${rapot.formattedListenTime})',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.76),
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
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
                      label: 'Total Putar',
                      value: '${rapot.totalTracksPlayed}x',
                      accent: primaryAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _miniStatPill(
                      label: 'Lagu Teratas',
                      value: '${rapot.topSongs.length} Lagu',
                      accent: secondaryAccent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _miniStatPill(
                      label: 'Artis',
                      value: '${rapot.topArtists.length} Artis',
                      accent: Colors.white,
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
                  color: Colors.black.withOpacity(0.26),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.auto_awesome_rounded,
                      color: primaryAccent,
                      size: 18,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rapot.vibePersonaTitle,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            rapot.vibePersonaSubtitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
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
                  const Text(
                    'Aktivitas Hari ke Hari',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'Menit / Hari',
                    style: TextStyle(
                      color: primaryAccent,
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
                    final ratio = (mins / maxDayMins).clamp(0.08, 1.0);
                    return Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          mins > 0 ? '${mins}m' : '-',
                          style: TextStyle(
                            color: mins > 0 ? Colors.white70 : Colors.white24,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          width: 22,
                          height: 52 * ratio,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            gradient: LinearGradient(
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
                          style: const TextStyle(
                            color: Colors.white54,
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
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              'Artis Teratas Minggu Ini',
              style: TextStyle(
                color: Colors.white,
                fontSize: 15.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          SizedBox(
            height: 122,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              itemCount: rapot.topArtists.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, idx) {
                final artist = rapot.topArtists[idx];
                return LiquidGlassBox(
                  borderRadius: 20,
                  width: 112,
                  padding: const EdgeInsets.all(10),
                  tintOpacity: idx == 0 ? 0.14 : 0.07,
                  rimIntensity: idx == 0 ? 0.44 : 0.30,
                  tintColor: idx == 0 ? primaryAccent : Colors.white,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipOval(
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
                      const SizedBox(height: 7),
                      Text(
                        '#${idx + 1} ${artist.artistName}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        '${artist.playCount}x • ${artist.totalMinutes} mnt',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: idx == 0 ? primaryAccent : Colors.white54,
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

        // 4. Top Songs Ranked List
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Padding(
              padding: EdgeInsets.only(left: 4),
              child: Text(
                'Lagu Paling Sering Diputar',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            if (rapot.topSongs.isNotEmpty)
              GestureDetector(
                onTap: () {
                  final songs = rapot.topSongs.map((e) => e.song).toList();
                  player.playSong(
                    songs.first,
                    customQueue: songs,
                    contextName: 'Replay Mingguan',
                  );
                  Navigator.pop(context);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4.5,
                  ),
                  decoration: BoxDecoration(
                    color: primaryAccent.withOpacity(0.18),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.play_arrow_rounded,
                        color: primaryAccent,
                        size: 15,
                      ),
                      const SizedBox(width: 3),
                      Text(
                        'Putar Semua',
                        style: TextStyle(
                          color: primaryAccent,
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (rapot.topSongs.isEmpty)
          LiquidGlassBox(
            borderRadius: 20,
            padding: const EdgeInsets.all(20),
            child: const Text(
              'Belum ada riwayat pemutaran minggu ini. Putar lagu favoritmu untuk mengisi Replay Anda!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white60, fontSize: 12.5),
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
                          color: i == 0 ? primaryAccent : Colors.white70,
                          fontWeight: FontWeight.w900,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                          Text(
                            item.song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white60,
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
                        color: primaryAccent.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '${item.playCount}x',
                        style: TextStyle(
                          color: primaryAccent,
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
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            onPressed: () => setState(() => _viewMode = 1),
            icon: const Icon(Icons.auto_awesome_motion_rounded, size: 19),
            label: const Text(
              'Buat Poster & Kartu Story Replay HD',
              style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _miniStatPill({
    required String label,
    required String value,
    required Color accent,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white54,
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
              color: accent,
              fontSize: 13.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  /// BitChord `ReplayStories` + `ReplayPoster` 3-Slide Studio
  Widget _buildPosterStudio({
    required String username,
    required WeeklyRapot rapot,
    required Color primaryAccent,
    required Color secondaryAccent,
    required List<Color> gradientColors,
  }) {
    const themeLabels = [
      '✨ Liquid Glass',
      '🔥 Crimson Z',
      '🌌 Violet',
      '💎 Emerald',
    ];

    return Column(
      key: const ValueKey('poster_studio_view'),
      children: [
        // Slide selector pills + Theme selector pills
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _slideTabButton(
                label: '1 • Ringkasan',
                active: _currentSlide == 0,
                accent: primaryAccent,
                onTap: () => _pageController.animateToPage(
                  0,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                ),
              ),
              const SizedBox(width: 6),
              _slideTabButton(
                label: '2 • Top 5 Lagu',
                active: _currentSlide == 1,
                accent: primaryAccent,
                onTap: () => _pageController.animateToPage(
                  1,
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                ),
              ),
              const SizedBox(width: 6),
              _slideTabButton(
                label: '3 • Artis & Aura',
                active: _currentSlide == 2,
                accent: primaryAccent,
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
          height: 30,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: themeLabels.length,
            itemBuilder: (context, idx) {
              final selected = _selectedThemeIndex == idx;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: GestureDetector(
                  onTap: () => setState(() => _selectedThemeIndex = idx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? primaryAccent
                          : Colors.white.withOpacity(0.07),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selected ? primaryAccent : Colors.white12,
                      ),
                    ),
                    child: Text(
                      themeLabels[idx],
                      style: TextStyle(
                        color: selected ? Colors.black : Colors.white70,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
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
            _dot(_currentSlide == 0, primaryAccent),
            const SizedBox(width: 6),
            _dot(_currentSlide == 1, primaryAccent),
            const SizedBox(width: 6),
            _dot(_currentSlide == 2, primaryAccent),
            const SizedBox(width: 10),
            const Text(
              'Geser kiri/kanan untuk pindah poster',
              style: TextStyle(color: Colors.white38, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Share Active Slide Button
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryAccent,
              foregroundColor: Colors.black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            onPressed: _isSharing ? null : _shareActiveSlide,
            icon: _isSharing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.black,
                    ),
                  )
                : const Icon(Icons.ios_share_rounded, size: 19),
            label: Text(
              _isSharing
                  ? 'Menyiapkan Poster HD...'
                  : 'Bagikan Poster ${_currentSlide + 1} ke Story / IG / WA',
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 13.5,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _slideTabButton({
    required String label,
    required bool active,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color:
              active ? accent.withOpacity(0.20) : Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? accent : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? accent : Colors.white60,
            fontSize: 11,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }

  Widget _dot(bool active, Color accent) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: active ? 18 : 6,
      height: 6,
      decoration: BoxDecoration(
        color: active ? accent : Colors.white24,
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

  Widget _buildSlide1Content({
    required String username,
    required WeeklyRapot rapot,
    required Color primaryAccent,
    required Color secondaryAccent,
  }) {
    final topOne = rapot.topSongs.isNotEmpty ? rapot.topSongs.first : null;
    final topArtist = topOne != null ? topOne.song.artist : 'Eksplorasi Baru';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primaryAccent.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: primaryAccent.withOpacity(0.4)),
              ),
              child: Text(
                'REPLAY STUDIO • ${rapot.weekId}',
                style: TextStyle(
                  color: primaryAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ),
            const Spacer(),
            const Text(
              '1 / 3',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Replay Musik $username',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
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
            color: Colors.white.withOpacity(0.75),
            fontSize: 11.5,
            height: 1.28,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.07),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: primaryAccent.withOpacity(0.38)),
          ),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: topOne != null
                    ? CachedNetworkImage(
                        imageUrl: topOne.song.highResArtUrl,
                        width: 62,
                        height: 62,
                        memCacheWidth: 190,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _fallbackThumb(62, primaryAccent),
                      )
                    : _fallbackThumb(62, primaryAccent),
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
                      ),
                      child: const Text(
                        '👑 #1 LAGU TERATAS',
                        style: TextStyle(
                          color: Colors.black,
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
                      style: const TextStyle(
                        color: Colors.white,
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
                        color: primaryAccent,
                        fontSize: 11.2,
                        fontWeight: FontWeight.w600,
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
                        color: Colors.white,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primaryAccent.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: primaryAccent.withOpacity(0.4)),
              ),
              child: Text(
                'TOP CHARTS • ${rapot.weekId}',
                style: TextStyle(
                  color: primaryAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ),
            const Spacer(),
            const Text(
              '2 / 3',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Top 5 Lagu $username 🔥',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
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
            color: Colors.white.withOpacity(0.65),
            fontSize: 11.2,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: rapot.topSongs.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada lagu yang diputar minggu ini.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white60, fontSize: 12.5),
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
                        decoration: BoxDecoration(
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
                                  color:
                                      i == 0 ? primaryAccent : Colors.white70,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
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
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                  Text(
                                    item.song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white60,
                                      fontSize: 10.5,
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
                              decoration: BoxDecoration(
                                color: primaryAccent.withOpacity(0.16),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '${item.playCount}x',
                                style: TextStyle(
                                  color: primaryAccent,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: primaryAccent.withOpacity(0.16),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: primaryAccent.withOpacity(0.4)),
              ),
              child: Text(
                'TOP ARTISTS • ${rapot.weekId}',
                style: TextStyle(
                  color: primaryAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 0.7,
                ),
              ),
            ),
            const Spacer(),
            const Text(
              '3 / 3',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Artis Favorit $username 🌟',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
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
            color: Colors.white.withOpacity(0.65),
            fontSize: 11.2,
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: rapot.topArtists.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada statistik artis minggu ini.',
                    style: TextStyle(color: Colors.white60, fontSize: 12.5),
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
                        decoration: BoxDecoration(
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
                                  color:
                                      i == 0 ? primaryAccent : Colors.white70,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            ClipOval(
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
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                artist.artistName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            Text(
                              '${artist.playCount}x • ${artist.totalMinutes} mnt',
                              style: TextStyle(
                                color: i == 0 ? primaryAccent : Colors.white70,
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
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
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
              Icon(icon, color: color, size: 13),
              const SizedBox(width: 5),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white54,
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWatermarkFooter(Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(Icons.graphic_eq_rounded, color: accent, size: 15),
            const SizedBox(width: 5),
            const Text(
              'ZUNIFY 2.0',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                fontSize: 11,
                letterSpacing: 1.1,
              ),
            ),
          ],
        ),
        Text(
          'Crafted by Fannz',
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
    return Container(
      width: size,
      height: size,
      color: Colors.white10,
      child: Icon(
        Icons.music_note_rounded,
        color: accent,
        size: size * 0.45,
      ),
    );
  }
}
