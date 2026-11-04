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

/// Zunify Rapot Mingguan (Weekly Wrap) Aesthetic Story Modal
/// Auto-scheduled every Sunday at 18:00 WIB & accessible anytime from Home/Library.
class WeeklyRapotModal extends StatefulWidget {
  final WeeklyRapot rapot;

  const WeeklyRapotModal({super.key, required this.rapot});

  @override
  State<WeeklyRapotModal> createState() => _WeeklyRapotModalState();
}

class _WeeklyRapotModalState extends State<WeeklyRapotModal> {
  final GlobalKey _rapotCaptureKey = GlobalKey();
  bool _isSharing = false;
  int _selectedThemeIndex = 0; // 0: Dynamic Liquid, 1: Cyber Aurora, 2: Vinyl Gold

  Future<void> _shareRapotCard() async {
    setState(() => _isSharing = true);
    try {
      await Future.delayed(const Duration(milliseconds: 60));
      final boundary = _rapotCaptureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.5);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/zunify_weekly_rapot_${DateTime.now().millisecondsSinceEpoch}.png',
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
          Color(0xFF060913),
        ];
      case 2: // Vinyl Gold
        return const [
          Color(0xFF3B2308),
          Color(0xFF17110B),
          Color(0xFF090705),
        ];
      default: // Dynamic Liquid
        return [
          dynamicAccent.withOpacity(0.35),
          const Color(0xFF0D1322),
          const Color(0xFF06080E),
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
    final topOne = rapot.topSongs.isNotEmpty ? rapot.topSongs.first : null;
    final topArtist = topOne != null ? topOne.song.artist : 'Eksplorasi Baru';

    final themeLabels = [
      '✨ Dynamic Liquid',
      '🌌 Cyber Aurora',
      '💿 Vinyl Gold',
    ];

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E17),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 12),

          // Header + Theme Switcher
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rekap Mingguan Story ✨',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, color: Colors.white54),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),

          // Theme selector pills
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: themeLabels.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, idx) {
                final selected = _selectedThemeIndex == idx;
                return GestureDetector(
                  onTap: () => setState(() => _selectedThemeIndex = idx),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: selected
                          ? primaryAccent
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: selected ? primaryAccent : Colors.white12,
                      ),
                    ),
                    child: Text(
                      themeLabels[idx],
                      style: TextStyle(
                        color: selected ? Colors.black : Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 14),

          // Scrollable Story Card Preview
          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: RepaintBoundary(
                key: _rapotCaptureKey,
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: gradientColors,
                    ),
                    border: Border.all(
                      color: primaryAccent.withOpacity(0.45),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryAccent.withOpacity(0.18),
                        blurRadius: 28,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(27),
                    child: Stack(
                      children: [
                        // Decorative Ambient Glow Orbs
                        Positioned(
                          top: -50,
                          right: -40,
                          child: Container(
                            width: 170,
                            height: 170,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: primaryAccent.withOpacity(0.22),
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: -60,
                          left: -40,
                          child: Container(
                            width: 180,
                            height: 180,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: secondaryAccent.withOpacity(0.16),
                            ),
                          ),
                        ),

                        // Card Content
                        Padding(
                          padding: const EdgeInsets.all(22),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Top Header Badge Row
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 11,
                                      vertical: 5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: primaryAccent.withOpacity(0.16),
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(
                                        color: primaryAccent.withOpacity(0.45),
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.auto_awesome_rounded,
                                          color: primaryAccent,
                                          size: 12,
                                        ),
                                        const SizedBox(width: 5),
                                        Text(
                                          'WEEKLY RECAP • ${rapot.weekId}',
                                          style: TextStyle(
                                            color: primaryAccent,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w900,
                                            letterSpacing: 0.9,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 9,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.07),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Text(
                                      'Zunify Wrapped',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Listener Title & Vibe Persona
                              Text(
                                'Vibe Musik ${library.profile.username}',
                                style: GoogleFonts.plusJakartaSans(
                                  color: Colors.white,
                                  fontSize: 23,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${rapot.vibePersonaTitle} — ${rapot.vibePersonaSubtitle}',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.78),
                                  fontSize: 12.5,
                                  height: 1.35,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // #1 Top Song Spotlight Hero Card
                              if (topOne != null) ...[
                                Container(
                                  padding: const EdgeInsets.all(13),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        primaryAccent.withOpacity(0.22),
                                        Colors.white.withOpacity(0.05),
                                      ],
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: primaryAccent.withOpacity(0.4),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(14),
                                        child: CachedNetworkImage(
                                          imageUrl: topOne.song.highResArtUrl,
                                          width: 68,
                                          height: 68,
                                          fit: BoxFit.cover,
                                          errorWidget: (_, __, ___) => Container(
                                            width: 68,
                                            height: 68,
                                            color: Colors.white12,
                                            child: Icon(
                                              Icons.music_note_rounded,
                                              color: primaryAccent,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 14),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: primaryAccent,
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Text(
                                                '👑 #1 LAGU TERATAS',
                                                style: TextStyle(
                                                  color: Colors.black,
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.w900,
                                                  letterSpacing: 0.6,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 6),
                                            Text(
                                              topOne.song.title,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 15.5,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${topOne.song.artist} • Diputar ${topOne.playCount}x',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: primaryAccent,
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 14),
                              ],

                              // 2x2 Bento Stats Grid
                              Row(
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
                                      value: '${rapot.totalTracksPlayed}x Lagu',
                                      color: secondaryAccent,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: _bentoBox(
                                      icon: Icons.mic_external_on_rounded,
                                      label: 'ARTIS FAVORIT',
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
                              const SizedBox(height: 18),

                              // Top 5 Songs List with Thumbnails
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    '🔥 TOP CHARTS MINGGU INI',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                  Text(
                                    'Top ${rapot.topSongs.length}',
                                    style: TextStyle(
                                      color: primaryAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),

                              if (rapot.topSongs.isEmpty)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.04),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: const Text(
                                    'Putar lagu favoritmu minggu ini untuk melihat grafik Top 5 di sini!',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12.5,
                                    ),
                                  ),
                                )
                              else
                                ...List.generate(rapot.topSongs.length, (i) {
                                  final item = rapot.topSongs[i];
                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 10,
                                      vertical: 7,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(0.05),
                                      borderRadius: BorderRadius.circular(13),
                                      border: Border.all(
                                        color: i == 0
                                            ? primaryAccent.withOpacity(0.35)
                                            : Colors.white.withOpacity(0.05),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        SizedBox(
                                          width: 24,
                                          child: Text(
                                            '#${i + 1}',
                                            style: TextStyle(
                                              color: i == 0
                                                  ? primaryAccent
                                                  : Colors.white70,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                        ),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(8),
                                          child: CachedNetworkImage(
                                            imageUrl: item.song.thumbnailUrl,
                                            width: 36,
                                            height: 36,
                                            fit: BoxFit.cover,
                                            errorWidget: (_, __, ___) =>
                                                Container(
                                              width: 36,
                                              height: 36,
                                              color: Colors.white10,
                                              child: Icon(
                                                Icons.music_note_rounded,
                                                size: 16,
                                                color: primaryAccent,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.song.title,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13,
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
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 3,
                                          ),
                                          decoration: BoxDecoration(
                                            color: primaryAccent.withOpacity(0.15),
                                            borderRadius:
                                                BorderRadius.circular(10),
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
                                }),

                              const SizedBox(height: 10),
                              Divider(color: Colors.white.withOpacity(0.12)),
                              const SizedBox(height: 4),

                              // Watermark Footer
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(5),
                                        decoration: BoxDecoration(
                                          color: primaryAccent,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.graphic_eq_rounded,
                                          size: 12,
                                          color: Colors.black,
                                        ),
                                      ),
                                      const SizedBox(width: 7),
                                      Text(
                                        'ZUNIFY MUSIC',
                                        style: TextStyle(
                                          color: primaryAccent,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.2,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const Text(
                                    'Crafted with ❤️ by Fannz',
                                    style: TextStyle(
                                      color: Colors.white54,
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Share Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryAccent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                elevation: 4,
              ),
              onPressed: _isSharing ? null : _shareRapotCard,
              icon: _isSharing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.ios_share_rounded, size: 20),
              label: Text(
                _isSharing
                    ? 'Menyiapkan Kartu Story HD...'
                    : 'Bagikan Rekap ke SW / IG Story',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 14.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bentoBox({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
                    fontSize: 9.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: color,
              fontSize: 14.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}
