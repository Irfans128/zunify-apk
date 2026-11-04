import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/lyric_model.dart';
import '../models/song_model.dart';
import '../providers/theme_provider.dart';

/// Aesthetic Lyric & Song Share Card Generator (Fitur C)
/// Captures a high-resolution card image (Cover Art + Selected Lyric + Translation
/// + "Zunify • Crafted by Fannz" watermark) and shares directly to IG Story / WhatsApp!
class ShareCardModal extends StatefulWidget {
  final ZunifySong song;
  final SyncedLyrics? lyrics;
  final int initialLyricIndex;

  const ShareCardModal({
    super.key,
    required this.song,
    this.lyrics,
    this.initialLyricIndex = 0,
  });

  @override
  State<ShareCardModal> createState() => _ShareCardModalState();
}

class _ShareCardModalState extends State<ShareCardModal> {
  final GlobalKey _cardRepaintKey = GlobalKey();
  late int _selectedIndex;
  bool _includeIndoTranslation = true;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialLyricIndex;
    if (widget.lyrics != null && widget.lyrics!.isOriginalIndonesian) {
      _includeIndoTranslation = false;
    }
  }

  Future<void> _exportAndShareCard() async {
    setState(() => _isSharing = true);
    try {
      final boundary = _cardRepaintKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;

      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final Uint8List pngBytes = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File(
        '${tempDir.path}/zunify_lyric_card_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await file.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '🎧 Sedang mendengarkan "${widget.song.title}" - ${widget.song.artist} di Zunify (by Fannz)',
      );
    } catch (_) {
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = theme.accentColor;
    final lines = widget.lyrics?.lines ?? [];
    final currentLine = (lines.isNotEmpty && _selectedIndex < lines.length)
        ? lines[_selectedIndex]
        : const LyricLine(
            timestamp: Duration.zero,
            originalText: '♪ Rasakan setiap detak musikmu di Zunify ♪',
          );

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      decoration: BoxDecoration(
        color: theme.cardBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Bagikan Kartu Lirik Aesthetic ✨',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),

            // Renderable Share Card Preview
            RepaintBoundary(
              key: _cardRepaintKey,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      theme.playerAmbientColor.withOpacity(0.55),
                      const Color(0xFF0A0C14),
                      const Color(0xFF06070B),
                    ],
                  ),
                  border: Border.all(
                    color: accent.withOpacity(0.45),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: accent.withOpacity(0.18),
                      blurRadius: 28,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Song Header
                    Row(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: SizedBox(
                            width: 54,
                            height: 54,
                            child: CachedNetworkImage(
                              imageUrl: widget.song.highResArtUrl,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                color: Colors.black54,
                                child: Icon(Icons.album, color: accent),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.song.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                widget.song.artist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Highlighted Lyric Quote
                    Text(
                      '"${currentLine.originalText}"',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 21,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                    ),

                    // Optional Indonesian Translation
                    if (_includeIndoTranslation &&
                        widget.lyrics?.shouldShowTranslation == true &&
                        currentLine.translatedIndoText != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        currentLine.translatedIndoText!,
                        style: TextStyle(
                          color: accent.withOpacity(0.9),
                          fontSize: 14.5,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],

                    const SizedBox(height: 26),
                    Divider(color: Colors.white.withOpacity(0.12)),
                    const SizedBox(height: 8),

                    // Watermark Footer
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: accent.withOpacity(0.2),
                              ),
                              child: Text(
                                'Z',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'ZUNIFY MUSIC',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                fontSize: 11.5,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          'Crafted with ❤️ by Fannz',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.55),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Lyric Line Picker
            if (lines.length > 1) ...[
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Pilih baris lirik favoritmu:',
                  style: TextStyle(color: Colors.white70, fontSize: 12.5),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 40,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: lines.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, idx) {
                    final selected = idx == _selectedIndex;
                    return ChoiceChip(
                      label: Text(
                        lines[idx].originalText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      selected: selected,
                      selectedColor: accent.withOpacity(0.25),
                      onSelected: (_) => setState(() => _selectedIndex = idx),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (widget.lyrics?.shouldShowTranslation == true)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text(
                  'Tampilkan Terjemahan Indonesia',
                  style: TextStyle(color: Colors.white, fontSize: 13.5),
                ),
                value: _includeIndoTranslation,
                activeColor: accent,
                onChanged: (v) => setState(() => _includeIndoTranslation = v),
              ),

            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _isSharing ? null : _exportAndShareCard,
                icon: _isSharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.share_rounded),
                label: const Text(
                  'Share ke IG Story / WhatsApp',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
