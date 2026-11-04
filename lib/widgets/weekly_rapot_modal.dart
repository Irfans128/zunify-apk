import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/weekly_rapot_model.dart';
import '../providers/library_provider.dart';
import '../providers/theme_provider.dart';

/// Zunify Rapot Mingguan (Weekly Wrap) Story Modal
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

  Future<void> _shareRapotCard() async {
    setState(() => _isSharing = true);
    try {
      final boundary = _rapotCaptureKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/zunify_weekly_rapot.png');
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '📊 Ini Rapot Musik Mingguan gw di Zunify! (${widget.rapot.formattedListenTime}) • Crafted by Fannz',
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final library = context.watch<LibraryProvider>();
    final accent = theme.accentColor;
    final rapot = widget.rapot;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
      decoration: BoxDecoration(
        color: theme.cardBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: SingleChildScrollView(
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
            const SizedBox(height: 16),

            RepaintBoundary(
              key: _rapotCaptureKey,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      accent.withOpacity(0.28),
                      const Color(0xFF0E121D),
                      const Color(0xFF07080D),
                    ],
                  ),
                  border: Border.all(color: accent.withOpacity(0.45), width: 1.5),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Badge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.18),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: accent.withOpacity(0.4)),
                          ),
                          child: Text(
                            'RAPOT MINGGUAN • ${rapot.weekId}',
                            style: TextStyle(
                              color: accent,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                        const Text(
                          'Minggu 18:00 WIB',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    Text(
                      'Rekap Musik ${library.profile.username} 🎧',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Vibe Persona Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'VIBE PERSONA MINGGU INI',
                            style: TextStyle(
                              color: Colors.white54,
                              fontSize: 10.5,
                              letterSpacing: 1.1,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rapot.vibePersonaTitle,
                            style: TextStyle(
                              color: accent,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            rapot.vibePersonaSubtitle,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Stats Row
                    Row(
                      children: [
                        Expanded(
                          child: _statBox(
                            'Total Waktu Dengar',
                            rapot.formattedListenTime,
                            accent,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _statBox(
                            'Total Lagu Diputar',
                            '${rapot.totalTracksPlayed}x Putar',
                            theme.secondaryAccentColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),

                    // Top Songs Section
                    const Text(
                      '🔥 TOP LAGU TERATAS MINGGU INI',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 11.5,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (rapot.topSongs.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Mulai putar lagu favoritmu untuk mengisi daftar Top 5 minggu ini!',
                          style: TextStyle(color: Colors.white54, fontSize: 12.5),
                        ),
                      )
                    else
                      ...List.generate(rapot.topSongs.length, (i) {
                        final item = rapot.topSongs[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            children: [
                              Text(
                                '#${i + 1}',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  '${item.song.title} — ${item.song.artist}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                '${item.playCount}x',
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        );
                      }),

                    const SizedBox(height: 16),
                    Divider(color: Colors.white.withOpacity(0.1)),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'ZUNIFY WEEKLY WRAP',
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                          ),
                        ),
                        const Text(
                          'Crafted with ❤️ by Fannz',
                          style: TextStyle(color: Colors.white54, fontSize: 11),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isSharing ? null : _shareRapotCard,
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text(
                  'Pamerkan Rapot ke Teman / Story',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statBox(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
