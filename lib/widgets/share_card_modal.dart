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
import 'liquid_background_widget.dart';

/// Zunify v2.0 iOS 26 Lyric Share Studio
/// - Select 1–5 lyric lines
/// - 5 Curated Aesthetic Templates:
///   0: 💧 iOS Liquid Glass
///   1: 🎵 Apple Music
///   2: 💿 Vinyl Studio
///   3: 📸 Polaroid Matte
///   4: 🌸 Pastel Aurora
/// - Exports 3x HD PNG or 9:16 `.mp4` Story Video with 20s song audio
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
  int _selectedTemplate = 0;
  bool _includeIndoTranslation = false;
  bool _centerAlignLyrics = false;
  bool _isSharing = false;
  bool _isCreatingVideo = false;
  String _statusMessage = '';

  static const MethodChannel _nativeChannel =
      MethodChannel('com.fannz.zunify/equalizer');

  static const List<String> _templateNames = [
    '💧 iOS Liquid Glass',
    '🎵 Apple Music',
    '💿 Vinyl Studio',
    '📸 Polaroid Matte',
    '🌸 Pastel Aurora',
  ];

  @override
  void initState() {
    super.initState();
    final lines = (widget.lyrics?.lines ?? [])
        .where((l) => !l.originalText.contains('•') && l.originalText.trim().isNotEmpty)
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
      _statusMessage = 'Menyiapkan kartu lirik HD...';
    });
    try {
      final file = await _renderCardPngToFile();
      if (file == null) return;

      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'image/png')],
        text:
            '🎧 "${widget.song.title}" - ${widget.song.artist} • Zunify Music',
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

  Future<void> _exportAndShareVideoWithAudio(
    PlayerProvider player,
    List<LyricLine> chosenLines,
  ) async {
    setState(() {
      _isCreatingVideo = true;
      _statusMessage = 'Menyiapkan audio lagu & kartu lirik...';
    });
    try {
      final pngFile = await _renderCardPngToFile();
      if (pngFile == null) return;

      final audioPath = await player.prepareAudioFileForStory(widget.song);
      if (audioPath == null) {
        await _exportAndShareCard();
        return;
      }

      if (mounted) {
        setState(() => _statusMessage = 'Merender Video Story + Musik (.mp4)...');
      }

      int startMs = 0;
      if (chosenLines.isNotEmpty &&
          chosenLines.first.timestamp.inMilliseconds > 0) {
        startMs = (chosenLines.first.timestamp.inMilliseconds - 800)
            .clamp(0, widget.song.duration.inMilliseconds);
      } else if (player.currentSong?.videoId == widget.song.videoId) {
        startMs = player.audioPlayer.position.inMilliseconds;
      }

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
              '🎧 "${widget.song.title}" - ${widget.song.artist} • Zunify Music',
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
        .where((l) => !l.originalText.contains('•') && l.originalText.trim().isNotEmpty)
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

    final canTranslate = liveLyrics?.shouldShowTranslation == true;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      padding: EdgeInsets.fromLTRB(
        18,
        12,
        18,
        MediaQuery.of(context).padding.bottom + 18,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0D16),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Top Header Row
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bagikan Lirik',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Pilih hingga 5 baris lirik & gaya kartu estetik',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.56),
                          fontSize: 11.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                LiquidGlassBox(
                  height: 30,
                  borderRadius: 15,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  tintColor: accent,
                  tintOpacity: 0.20,
                  rimIntensity: 0.42,
                  child: Text(
                    '${chosenLines.length}/5 Baris',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11.2,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IosGlassIconButton(
                  icon: Icons.close_rounded,
                  size: 32,
                  iconSize: 17,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Template Style Selector Pills
            SizedBox(
              height: 35,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: _templateNames.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final selected = i == _selectedTemplate;
                  return IosGlassPillButton(
                    label: _templateNames[i],
                    height: 35,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    activeColor: accent,
                    isActive: selected,
                    fontSize: 12,
                    onTap: () => setState(() => _selectedTemplate = i),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),

            // Quick Formatting Toolbar (Translation + Alignment)
            Row(
              children: [
                IosGlassPillButton(
                  icon: _centerAlignLyrics
                      ? Icons.format_align_center_rounded
                      : Icons.format_align_left_rounded,
                  label: _centerAlignLyrics ? 'Rata Tengah' : 'Rata Kiri',
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  activeColor: accent,
                  isActive: _centerAlignLyrics,
                  fontSize: 11.2,
                  onTap: () =>
                      setState(() => _centerAlignLyrics = !_centerAlignLyrics),
                ),
                if (canTranslate) ...[
                  const SizedBox(width: 8),
                  IosGlassPillButton(
                    icon: Icons.translate_rounded,
                    label: player.isTranslatingLyrics
                        ? 'Menerjemahkan...'
                        : 'Terjemahan Indo',
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    activeColor: accent,
                    isActive: _includeIndoTranslation,
                    fontSize: 11.2,
                    onTap: () async {
                      final next = !_includeIndoTranslation;
                      setState(() => _includeIndoTranslation = next);
                      if (next && !player.showTranslation) {
                        await player.toggleTranslationDisplay();
                      }
                    },
                  ),
                ],
              ],
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
                showIndo: _includeIndoTranslation && canTranslate,
              ),
            ),
            const SizedBox(height: 14),

            // Multi-Line Lyric Selector List
            if (lines.length > 1) ...[
              Text(
                'Ketuk Baris Lirik untuk Memilih (Maks 5 Baris):',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.75),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              LiquidGlassBox(
                height: 148,
                borderRadius: 18,
                tintOpacity: 0.06,
                rimIntensity: 0.28,
                child: ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  itemCount: lines.length,
                  itemBuilder: (ctx, idx) {
                    final selected = _selectedIndices.contains(idx);
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _toggleLineSelection(idx),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 160),
                        margin: const EdgeInsets.symmetric(vertical: 2.5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7.5,
                        ),
                        decoration: BoxDecoration(
                          color: selected
                              ? accent.withOpacity(0.20)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selected
                                ? accent.withOpacity(0.52)
                                : Colors.transparent,
                            width: 0.9,
                          ),
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
                            const SizedBox(width: 9),
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
              const SizedBox(height: 14),
            ],

            if (_statusMessage.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
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

            // Bottom Action Bar (Uniform 46px Height Buttons)
            Row(
              children: [
                Expanded(
                  flex: 6,
                  child: IosSpringButton(
                    scaleDown: 0.92,
                    borderRadius: 23,
                    onTap: (_isSharing || _isCreatingVideo)
                        ? null
                        : () => _exportAndShareVideoWithAudio(
                              player,
                              chosenLines,
                            ),
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(23),
                        boxShadow: [
                          BoxShadow(
                            color: accent.withOpacity(0.36),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.movie_creation_rounded,
                            color: Colors.black,
                            size: 18,
                          ),
                          SizedBox(width: 7),
                          Text(
                            'Story + Lagu (.mp4)',
                            style: TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 4,
                  child: LiquidGlassBox(
                    height: 46,
                    borderRadius: 23,
                    tintOpacity: 0.12,
                    rimIntensity: 0.42,
                    onTap: (_isSharing || _isCreatingVideo)
                        ? null
                        : _exportAndShareCard,
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_rounded,
                          color: Colors.white,
                          size: 17,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Gambar HD',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.8,
                          ),
                        ),
                      ],
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

    // Template 1: Apple Music Minimal Editorial Card
    if (_selectedTemplate == 1) {
      final topColor = Color.lerp(ambient, const Color(0xFF181C2C), 0.25)!;
      final bottomColor = Color.lerp(ambient, const Color(0xFF080A11), 0.72)!;
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 26, 24, 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [topColor, bottomColor],
          ),
          border: Border.all(
            color: Colors.white.withOpacity(0.18),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: _centerAlignLyrics
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            ...chosenLines.map(
              (l) => _buildLyricBlock(
                l,
                accent,
                showIndo,
                fontSize: chosenLines.length <= 2 ? 21.5 : 18.5,
              ),
            ),
            const SizedBox(height: 18),
            Divider(color: Colors.white.withOpacity(0.16), height: 1),
            const SizedBox(height: 14),
            Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(11),
                  child: CachedNetworkImage(
                    imageUrl: song.highResArtUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      color: Colors.white12,
                      child: Icon(Icons.music_note_rounded, color: accent),
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
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.68),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'Zunify',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Template 3: Polaroid Matte Frame
    if (_selectedTemplate == 3) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFF11131C),
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: Colors.white.withOpacity(0.18),
            width: 1.2,
          ),
        ),
        child: Column(
          crossAxisAlignment: _centerAlignLyrics
              ? CrossAxisAlignment.center
              : CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                alignment: Alignment.bottomLeft,
                children: [
                  CachedNetworkImage(
                    imageUrl: song.highResArtUrl,
                    height: 176,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Container(
                    height: 92,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black87],
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
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
            const SizedBox(height: 12),
            _buildWatermarkFooter(accent),
          ],
        ),
      );
    }

    // Templates 0 (iOS Liquid Glass), 2 (Vinyl Studio), 4 (Pastel Aurora)
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Stack(
        children: [
          // Blurred Cover Art Backdrop for iOS Liquid Glass & Pastel Aurora
          if (_selectedTemplate == 0 || _selectedTemplate == 4)
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 32, sigmaY: 32),
                child: CachedNetworkImage(
                  imageUrl: song.highResArtUrl,
                  fit: BoxFit.cover,
                ),
              ),
            ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _selectedTemplate == 0
                      ? [
                          Colors.white.withOpacity(0.14),
                          const Color(0xFF0A0D18).withOpacity(0.76),
                          const Color(0xFF070911).withOpacity(0.88),
                        ]
                      : _selectedTemplate == 2
                          ? [
                              const Color(0xFF161926),
                              const Color(0xFF090B12),
                            ]
                          : [
                              const Color(0xFFF48FB1).withOpacity(0.42),
                              const Color(0xFFB39DDB).withOpacity(0.38),
                              const Color(0xFF0D101B).withOpacity(0.84),
                            ],
                ),
              ),
            ),
          ),

          // Decorative Grooved Vinyl Disc in Corner for Template 2 (Vinyl Studio)
          if (_selectedTemplate == 2)
            Positioned(
              right: -34,
              top: -24,
              child: Container(
                width: 138,
                height: 138,
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
                    color: accent.withOpacity(0.45),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Container(
                  width: 42,
                  height: 42,
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
                      fontSize: 19,
                    ),
                  ),
                ),
              ),
            ),

          // Main iOS 26 Optical Glass Surface
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: Colors.white.withOpacity(0.28),
                width: 1.1,
              ),
            ),
            child: Column(
              crossAxisAlignment: _centerAlignLyrics
                  ? CrossAxisAlignment.center
                  : CrossAxisAlignment.start,
              children: [
                // Song Header with Artwork + Frosted Pill
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: CachedNetworkImage(
                        imageUrl: song.highResArtUrl,
                        width: 54,
                        height: 54,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 54,
                          height: 54,
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
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.74),
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.14),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.white.withOpacity(0.26),
                          width: 0.9,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.graphic_eq_rounded,
                        color: accent,
                        size: 17,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),

                // Inner Frosted Glass Lyric Lens for Template 0 (iOS Liquid Glass)
                if (_selectedTemplate == 0)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.24),
                        width: 0.9,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: _centerAlignLyrics
                          ? CrossAxisAlignment.center
                          : CrossAxisAlignment.start,
                      children: chosenLines
                          .map((line) => _buildLyricBlock(line, accent, showIndo))
                          .toList(),
                    ),
                  )
                else
                  ...chosenLines.map(
                    (line) => _buildLyricBlock(line, accent, showIndo),
                  ),

                const SizedBox(height: 16),

                // Subtle iOS 26 Audio Progress Scrubber Bar
                Row(
                  children: [
                    Icon(Icons.play_arrow_rounded, color: accent, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(28, (i) {
                          final active = i < 16;
                          final h = 4.0 + ((i * 7) % 12);
                          return Container(
                            width: 2.5,
                            height: h,
                            decoration: BoxDecoration(
                              color: active
                                  ? Colors.white
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

  Widget _buildLyricBlock(
    LyricLine line,
    Color accent,
    bool showIndo, {
    double fontSize = 18.0,
  }) {
    final align = _centerAlignLyrics ? TextAlign.center : TextAlign.left;
    final crossAlign =
        _centerAlignLyrics ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: crossAlign,
        children: [
          Text(
            line.originalText,
            textAlign: align,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: fontSize,
              fontWeight: FontWeight.w800,
              height: 1.30,
              letterSpacing: -0.3,
            ),
          ),
          if (showIndo &&
              line.translatedIndoText != null &&
              line.translatedIndoText!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Text(
              line.translatedIndoText!,
              textAlign: align,
              style: GoogleFonts.dmSans(
                color: accent,
                fontSize: 13.2,
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
                color: Colors.white.withOpacity(0.18),
                border: Border.all(
                  color: Colors.white.withOpacity(0.32),
                  width: 0.8,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                'Z',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w900,
                  fontSize: 11.5,
                ),
              ),
            ),
            const SizedBox(width: 7),
            const Text(
              'ZUNIFY MUSIC',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.0,
                fontSize: 10.5,
              ),
            ),
          ],
        ),
        Text(
          'Zunify Lyric Studio',
          style: TextStyle(
            color: Colors.white.withOpacity(0.60),
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
