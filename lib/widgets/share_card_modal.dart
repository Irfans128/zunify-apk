import 'dart:io';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/lyric_model.dart';
import '../models/song_model.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';

/// Zunify v1.4 Multi-Line Spotify-Style Lyric & Song Story Share Card Generator
/// - Select up to 5 lyric lines (like Spotify Lyrics Share!)
/// - 4 Aesthetic Card Templates: Blur Glass, Vinyl Studio, Polaroid Dark, Cyber Aurora
/// - Exports crisp 3x PNG directly to WhatsApp Status (SW) / IG Story
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
  late final Set<int> _selectedIndices;
  int _selectedTemplate = 0; // 0: Blur Glass, 1: Vinyl Studio, 2: Polaroid, 3: Cyber Aurora
  bool _includeIndoTranslation = false;
  bool _isSharing = false;
  bool _isCreatingVideo = false;
  String _statusMessage = '';

  static const MethodChannel _nativeChannel =
      MethodChannel('com.fannz.zunify/equalizer');

  static const List<String> _templateNames = [
    '✨ Blur Glass',
    '💿 Vinyl Studio',
    '📸 Polaroid',
    '🌌 Cyber Aurora',
  ];

  @override
  void initState() {
    super.initState();
    final lines = (widget.lyrics?.lines ?? [])
        .where((l) => !l.originalText.contains('•'))
        .toList();
    _selectedIndices = {};
    if (lines.isNotEmpty) {
      final first = widget.initialLyricIndex.clamp(0, lines.length - 1);
      _selectedIndices.add(first);
      if (first + 1 < lines.length && lines.length > 1) {
        _selectedIndices.add(first + 1);
      }
    }
  }

  void _toggleLineSelection(int idx) {
    setState(() {
      if (_selectedIndices.contains(idx)) {
        if (_selectedIndices.length > 1) {
          _selectedIndices.remove(idx);
        }
      } else {
        if (_selectedIndices.length >= 5) {
          // Remove earliest selected line if already at 5 max
          _selectedIndices.remove(_selectedIndices.first);
        }
        _selectedIndices.add(idx);
      }
    });
  }

  Future<File?> _renderCardPngToFile() async {
    await Future.delayed(const Duration(milliseconds: 50));
    final boundary = _cardRepaintKey.currentContext?.findRenderObject()
        as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
    final ByteData? byteData =
        await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    final Uint8List pngBytes = byteData.buffer.asUint8List();
    final tempDir = await getTemporaryDirectory();
    final file = File(
      '${tempDir.path}/zunify_story_${DateTime.now().millisecondsSinceEpoch}.png',
    );
    await file.writeAsBytes(pngBytes, flush: true);
    return file;
  }

  Future<void> _exportAndShareCard() async {
    setState(() {
      _isSharing = true;
      _statusMessage = 'Menyiapkan gambar HD...';
    });
    try {
      final file = await _renderCardPngToFile();
      if (file == null) return;

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text:
            '🎧 "${widget.song.title}" - ${widget.song.artist} • Zunify Music (Crafted by Fannz)',
      );
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() {
          _isSharing = false;
          _statusMessage = '';
        });
      }
    }
  }

  /// Exports a 9:16 `.mp4` Story Video combining the Lyric Card + 20s of the actual song audio
  /// starting right at the selected lyric line's timestamp!
  Future<void> _exportAndShareVideoWithAudio(
    PlayerProvider player,
    List<LyricLine> chosenLines,
  ) async {
    setState(() {
      _isCreatingVideo = true;
      _statusMessage = 'Menyiapkan potongan lagu & kartu lirik...';
    });
    try {
      final pngFile = await _renderCardPngToFile();
      if (pngFile == null) return;

      final audioPath = await player.prepareAudioFileForStory(widget.song);
      if (audioPath == null) {
        // Fallback to image share if offline/network failed
        await _exportAndShareCard();
        return;
      }

      if (mounted) {
        setState(() => _statusMessage = 'Merender Video Story + Musik (.mp4)...');
      }

      // Compute startMs from the earliest selected lyric line (or current playback position)
      int startMs = 0;
      if (chosenLines.isNotEmpty &&
          chosenLines.first.timestamp.inMilliseconds > 0) {
        startMs = (chosenLines.first.timestamp.inMilliseconds - 800)
            .clamp(0, widget.song.duration.inMilliseconds);
      } else if (player.currentSong?.videoId == widget.song.videoId) {
        startMs = player.audioPlayer.position.inMilliseconds;
      }

      // Compute durationMs (18..24 seconds covering selected lines)
      int durationMs = 20000;
      if (chosenLines.length >= 2) {
        final spanMs = chosenLines.last.timestamp.inMilliseconds -
            chosenLines.first.timestamp.inMilliseconds +
            6000;
        durationMs = spanMs.clamp(15000, 25000);
      }

      final tempDir = await getTemporaryDirectory();
      final outMp4Path =
          '${tempDir.path}/zunify_story_music_${DateTime.now().millisecondsSinceEpoch}.mp4';

      final createdPath = await _nativeChannel.invokeMethod<String>(
        'createStoryVideo',
        {
          'imagePath': pngFile.path,
          'audioPath': audioPath,
          'outputPath': outMp4Path,
          'startMs': startMs,
          'durationMs': durationMs,
        },
      );

      if (createdPath != null && File(createdPath).existsSync()) {
        await Share.shareXFiles(
          [XFile(createdPath, mimeType: 'video/mp4')],
          text:
              '🎧 "${widget.song.title}" - ${widget.song.artist} • Zunify Music (Crafted by Fannz)',
        );
      } else {
        await _exportAndShareCard();
      }
    } catch (_) {
      await _exportAndShareCard();
    } finally {
      if (mounted) {
        setState(() {
          _isCreatingVideo = false;
          _statusMessage = '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<PlayerProvider>();
    final accent = theme.accentColor;
    final liveLyrics = player.currentLyrics ?? widget.lyrics;
    final lines = (liveLyrics?.lines ?? [])
        .where((l) => !l.originalText.contains('•'))
        .toList();

    final sortedSelected = _selectedIndices.toList()..sort();
    final chosenLines = sortedSelected
        .where((i) => i >= 0 && i < lines.length)
        .map((i) => lines[i])
        .toList();

    if (chosenLines.isEmpty) {
      chosenLines.add(
        const LyricLine(
          timestamp: Duration.zero,
          originalText: '♪ Rasakan setiap detak musikmu di Zunify ♪',
        ),
      );
    }

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.90,
      ),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0E17),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Bagikan ke SW / IG Story ✨',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${chosenLines.length}/5 Baris Dipilih',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Template Style Selector
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _templateNames.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final selected = i == _selectedTemplate;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedTemplate = i),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: selected
                            ? accent
                            : Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        _templateNames[i],
                        style: TextStyle(
                          color: selected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // High-Resolution Capture Card Preview
            RepaintBoundary(
              key: _cardRepaintKey,
              child: _buildSelectedTemplateCard(
                chosenLines: chosenLines,
                accent: accent,
                secondaryAccent: theme.secondaryAccentColor,
                ambient: theme.playerAmbientColor,
                showIndo: _includeIndoTranslation &&
                    (liveLyrics?.shouldShowTranslation ?? false),
              ),
            ),
            const SizedBox(height: 14),

            // Multi-Line Spotify-Style Lyric Checklist
            if (lines.length > 1) ...[
              const Text(
                'Pilih Baris Lirik (Ketuk untuk pilih 1–5 baris seperti Spotify):',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                height: 150,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.04),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  itemCount: lines.length,
                  itemBuilder: (ctx, idx) {
                    final selected = _selectedIndices.contains(idx);
                    return GestureDetector(
                      onTap: () => _toggleLineSelection(idx),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 2.5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? accent.withOpacity(0.20)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                          border: selected
                              ? Border.all(color: accent.withOpacity(0.5))
                              : null,
                        ),
                        child: Row(
                          children: [
                            Icon(
                              selected
                                  ? Icons.check_circle_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              color: selected ? accent : Colors.white38,
                              size: 17,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                lines[idx].originalText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color:
                                      selected ? Colors.white : Colors.white70,
                                  fontWeight: selected
                                      ? FontWeight.w800
                                      : FontWeight.w500,
                                  fontSize: 12.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 10),
            ],

            if (liveLyrics?.shouldShowTranslation == true)
              SwitchListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(
                  player.isTranslatingLyrics
                      ? 'Menerjemahkan lirik ke Indonesia...'
                      : 'Sertakan Terjemahan Bahasa Indonesia',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                value: _includeIndoTranslation,
                activeColor: accent,
                onChanged: (v) async {
                  setState(() => _includeIndoTranslation = v);
                  if (v && !player.showTranslation) {
                    await player.toggleTranslationDisplay();
                  }
                },
              ),

            const SizedBox(height: 10),
            if (_statusMessage.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: accent,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        _statusMessage,
                        style: TextStyle(
                          color: accent,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            Row(
              children: [
                Expanded(
                  flex: 6,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: (_isSharing || _isCreatingVideo)
                        ? null
                        : () => _exportAndShareVideoWithAudio(
                              player,
                              chosenLines,
                            ),
                    icon: const Icon(Icons.movie_creation_rounded, size: 19),
                    label: const Text(
                      'Bagikan ke SW + Lagu',
                      style: TextStyle(
                        fontWeight: FontWeight.w900,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.18)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: (_isSharing || _isCreatingVideo)
                        ? null
                        : _exportAndShareCard,
                    icon: const Icon(Icons.image_outlined, size: 18),
                    label: const Text(
                      'Gambar Saja',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.8,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedTemplateCard({
    required List<LyricLine> chosenLines,
    required Color accent,
    required Color secondaryAccent,
    required Color ambient,
    required bool showIndo,
  }) {
    final song = widget.song;

    if (_selectedTemplate == 2) {
      // Template 2: Polaroid Dark Frame
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF10131D),
          borderRadius: BorderRadius.circular(26),
          border: Border.all(color: Colors.white.withOpacity(0.14), width: 1.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  CachedNetworkImage(
                    imageUrl: song.highResArtUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    height: 90,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: accent,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...chosenLines.map((l) => _buildLyricBlock(l, accent, showIndo)),
            const SizedBox(height: 14),
            _buildWatermarkFooter(accent),
          ],
        ),
      );
    }

    // Templates 0 (Blur Glass), 1 (Vinyl Studio), 3 (Cyber Aurora)
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: Stack(
        children: [
          // Background Layer: Blurred Album Cover for Template 0, Gradient for others
          if (_selectedTemplate == 0)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 28, sigmaY: 28),
                child: CachedNetworkImage(
                  imageUrl: song.highResArtUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _selectedTemplate == 0
                      ? [
                          Colors.black.withOpacity(0.55),
                          const Color(0xFF080A12).withOpacity(0.84),
                        ]
                      : _selectedTemplate == 1
                          ? [
                              const Color(0xFF141826),
                              const Color(0xFF090B12),
                            ]
                          : [
                              accent.withOpacity(0.38),
                              secondaryAccent.withOpacity(0.26),
                              const Color(0xFF070910),
                            ],
                ),
              ),
            ),
          ),

          // Decorative Vinyl Disc in Corner for Template 1 (Vinyl Studio)
          if (_selectedTemplate == 1)
            Positioned(
              right: -36,
              top: -26,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [
                      Color(0xFF0B0D13),
                      Color(0xFF282E3D),
                      Color(0xFF0B0D13),
                      Color(0xFF232836),
                      Color(0xFF0B0D13),
                    ],
                  ),
                  border: Border.all(
                    color: accent.withOpacity(0.5),
                    width: 2,
                  ),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent,
                  ),
                  alignment: Alignment.center,
                  child: const Text(
                    'Z',
                    style: TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.w900,
                      fontSize: 20,
                    ),
                  ),
                ),
              ),
            ),

          // Main Content
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: accent.withOpacity(0.45),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Song Header with Artwork + Audio Wave Badge
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CachedNetworkImage(
                        imageUrl: song.highResArtUrl,
                        width: 56,
                        height: 56,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 56,
                          height: 56,
                          color: Colors.black54,
                          child: Icon(Icons.album, color: accent),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.75),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
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
                        color: accent.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: accent.withOpacity(0.4)),
                      ),
                      child: Icon(
                        Icons.graphic_eq_rounded,
                        color: accent,
                        size: 18,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Multi-line Lyric Quotes
                ...chosenLines.map(
                  (line) => _buildLyricBlock(line, accent, showIndo),
                ),

                const SizedBox(height: 16),

                // Aesthetic Waveform Progress Bar Decoration
                Row(
                  children: [
                    Icon(Icons.play_circle_fill_rounded, color: accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(28, (i) {
                          final active = i < 16;
                          final h = 4.0 + ((i * 7) % 13);
                          return Container(
                            width: 2.5,
                            height: h,
                            decoration: BoxDecoration(
                              color: active
                                  ? accent
                                  : Colors.white.withOpacity(0.22),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Divider(color: Colors.white.withOpacity(0.14), height: 1),
                const SizedBox(height: 12),

                _buildWatermarkFooter(accent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLyricBlock(LyricLine line, Color accent, bool showIndo) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line.originalText,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 18.5,
              fontWeight: FontWeight.w800,
              height: 1.32,
              letterSpacing: -0.2,
            ),
          ),
          if (showIndo && line.translatedIndoText != null) ...[
            const SizedBox(height: 3),
            Text(
              line.translatedIndoText!,
              style: GoogleFonts.dmSans(
                color: accent,
                fontSize: 13.5,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
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
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accent,
              ),
              alignment: Alignment.center,
              child: const Text(
                'Z',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.w900,
                  fontSize: 12,
                ),
              ),
            ),
            const SizedBox(width: 7),
            const Text(
              'ZUNIFY MUSIC',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                fontSize: 11,
              ),
            ),
          ],
        ),
        Text(
          'Crafted with ❤️ by Fannz',
          style: TextStyle(
            color: Colors.white.withOpacity(0.68),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
