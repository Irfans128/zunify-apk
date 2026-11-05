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
import '../providers/theme_provider.dart';

/// Zunify v1.7 Rapot Mingguan (Weekly Wrapped) — Clean 2-Slide Story Deck
/// Slide 1: Aura Musik, #1 Lagu Teratas, & 2x2 Bento Statistik (Anti-Overflow)
/// Slide 2: Top 5 Lagu Minggu Ini Poster + Watermark
class WeeklyRapotModal extends StatefulWidget {
  final WeeklyRapot rapot;

  const WeeklyRapotModal({super.key, required this.rapot});

  @override
  State<WeeklyRapotModal> createState() => _WeeklyRapotModalState();
}

class _WeeklyRapotModalState extends State<WeeklyRapotModal> {
  final GlobalKey _slide1CaptureKey = GlobalKey();
  final GlobalKey _slide2CaptureKey = GlobalKey();
  late final PageController _pageController;

  bool _isSharing = false;
  int _currentSlide = 0; // 0 = Slide 1 (Aura & Stats), 1 = Slide 2 (Top 5 Songs)
  int _selectedThemeIndex = 0; // 0: Dynamic Liquid, 1: Cyber Aurora, 2: Vinyl Gold

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

  Future<void> _shareActiveSlide() async {
    setState(() => _isSharing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 60));
      final key = _currentSlide == 0 ? _slide1CaptureKey : _slide2CaptureKey;
      final boundary =
          key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.2);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/zunify_wrapped_slide${_currentSlide + 1}_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text:
            '🎧 Rekap Musik Mingguan gw di Zunify (${widget.rapot.formattedListenTime} • ${widget.rapot.vibePersonaTitle}) — Crafted by Fannz',
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  List<Color> _getGradientColors(Color dynamicAccent) {
    switch (_selectedThemeIndex) {
      case 1: // Cyber Aurora
        return const [
          Color(0xFF2E1065),
          Color(0xFF0F172A),
          Color(0xFF070A14),
        ];
      case 2: // Vinyl Gold
        return const [
          Color(0xFF3B2308),
          Color(0xFF17110B),
          Color(0xFF090705),
        ];
      default: // Dynamic Liquid
        return [
          dynamicAccent.withOpacity(0.32),
          const Color(0xFF0E1424),
          const Color(0xFF070910),
        ];
    }
  }

  Color _getPrimaryAccent(Color dynamicAccent) {
    switch (_selectedThemeIndex) {
      case 1:
        return const Color(0xFF38BDF8);
      case 2:
        return const Color(0xFFFBBF24);
      default:
        return dynamicAccent;
    }
  }

  Color _getSecondaryAccent(Color dynamicSecondary) {
    switch (_selectedThemeIndex) {
      case 1:
        return const Color(0xFFC084FC);
      case 2:
        return const Color(0xFFF97316);
      default:
        return dynamicSecondary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final library = context.watch<LibraryProvider>();
    final primaryAccent = _getPrimaryAccent(theme.accentColor);
    final secondaryAccent = _getSecondaryAccent(theme.secondaryAccentColor);
    final gradientColors = _getGradientColors(theme.accentColor);
    final rapot = widget.rapot;

    const themeLabels = [
      '✨ Dynamic',
      '🌌 Aurora',
      '💿 Gold',
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E17),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 10),

            // Top Bar: Title + Slide Selector Pills + Close
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Rekap Mingguan ✨',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                _slideTabButton(
                  label: '1 • Aura',
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
                  label: '2 • Top 5',
                  active: _currentSlide == 1,
                  accent: primaryAccent,
                  onTap: () => _pageController.animateToPage(
                    1,
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeOutCubic,
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: Colors.white54,
                    size: 20,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Theme selector pills
            SizedBox(
              height: 30,
              child: Row(
                children: List.generate(themeLabels.length, (idx) {
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
                              : Colors.white.withOpacity(0.06),
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
                }),
              ),
            ),
            const SizedBox(height: 12),

            // 2-Slide Swipeable Story Deck (Fits cleanly on phone screens)
            SizedBox(
              height: 455,
              child: PageView(
                controller: _pageController,
                onPageChanged: (idx) => setState(() => _currentSlide = idx),
                children: [
                  // SLIDE 1: Vibe Persona + #1 Song Hero + 2x2 Stats Grid
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: RepaintBoundary(
                      key: _slide1CaptureKey,
                      child: _buildStoryContainer(
                        primaryAccent: primaryAccent,
                        secondaryAccent: secondaryAccent,
                        gradientColors: gradientColors,
                        child: _buildSlide1Content(
                          username: library.profile.username,
                          rapot: rapot,
                          primaryAccent: primaryAccent,
                          secondaryAccent: secondaryAccent,
                        ),
                      ),
                    ),
                  ),

                  // SLIDE 2: Top 5 Songs Ranking Poster
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: RepaintBoundary(
                      key: _slide2CaptureKey,
                      child: _buildStoryContainer(
                        primaryAccent: primaryAccent,
                        secondaryAccent: secondaryAccent,
                        gradientColors: gradientColors,
                        child: _buildSlide2Content(
                          username: library.profile.username,
                          rapot: rapot,
                          primaryAccent: primaryAccent,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),

            // Page indicator dots + swipe hint
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _dot(_currentSlide == 0, primaryAccent),
                const SizedBox(width: 6),
                _dot(_currentSlide == 1, primaryAccent),
                const SizedBox(width: 10),
                const Text(
                  'Geser kiri/kanan untuk pindah slide',
                  style: TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 12),

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
                  elevation: 4,
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
                      ? 'Menyiapkan Kartu Story HD...'
                      : 'Bagikan Slide ${_currentSlide + 1} ke SW / IG Story',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
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
          color: active ? accent.withOpacity(0.20) : Colors.white.withOpacity(0.06),
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
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: Border.all(
          color: primaryAccent.withOpacity(0.42),
          width: 1.4,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
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
                  color: primaryAccent.withOpacity(0.18),
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
                  color: secondaryAccent.withOpacity(0.14),
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
        // Clean Top Header Row (Never overflows)
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
                'WRAPPED • ${rapot.weekId}',
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
              'SLIDE 1/2',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // User Vibe Title
        Text(
          'Vibe Musik $username',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 21,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.4,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          '${rapot.vibePersonaTitle} — ${rapot.vibePersonaSubtitle}',
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: Colors.white.withOpacity(0.75),
            fontSize: 11.8,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 14),

        // #1 Top Song Spotlight Card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.06),
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
                        width: 66,
                        height: 66,
                        memCacheWidth: 200,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            _fallbackThumb(66, primaryAccent),
                      )
                    : _fallbackThumb(66, primaryAccent),
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
                        fontSize: 14.5,
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
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Spacious 2x2 Bento Stats Grid
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
        const SizedBox(height: 10),
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
              'SLIDE 2/2',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
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
            fontSize: 11.5,
          ),
        ),
        const SizedBox(height: 12),

        Expanded(
          child: rapot.topSongs.isEmpty
              ? Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Text(
                      'Putar lagu favoritmu minimal 15 detik untuk melihat daftar Top 5 Mingguan di sini!',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white60, fontSize: 12.5),
                    ),
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
                                  color: i == 0 ? primaryAccent : Colors.white70,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(
                                imageUrl: item.song.thumbnailUrl,
                                width: 38,
                                height: 38,
                                memCacheWidth: 120,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) =>
                                    _fallbackThumb(38, primaryAccent),
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
                                      fontSize: 12.8,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    item.song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: primaryAccent.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(9),
                              ),
                              child: Text(
                                '${item.playCount}x',
                                style: TextStyle(
                                  color: primaryAccent,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
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
        const SizedBox(height: 10),
        _buildWatermarkFooter(primaryAccent),
      ],
    );
  }

  Widget _buildWatermarkFooter(Color primaryAccent) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Divider(color: Colors.white.withOpacity(0.10), height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: primaryAccent,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.graphic_eq_rounded,
                    size: 11,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'ZUNIFY MUSIC',
                  style: TextStyle(
                    color: primaryAccent,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ),
            const Text(
              'Crafted with ❤️ by Fannz',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _fallbackThumb(double size, Color accent) {
    return Container(
      width: size,
      height: size,
      color: Colors.white10,
      child: Icon(Icons.music_note_rounded, color: accent, size: size * 0.42),
    );
  }

  Widget _bentoBox({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
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
                    letterSpacing: 0.5,
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
              color: color,
              fontSize: 13.8,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
