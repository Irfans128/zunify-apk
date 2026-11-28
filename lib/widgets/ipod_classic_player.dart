import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/lyric_model.dart';
import '../models/song_model.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';

/// Refined Authentic iPod Classic 6th Gen Player UI:
/// - Anodized Brushed Aluminum / Matte Graphite Chassis with subtle bevel highlights
/// - Recessed Glossy Black Glass Bezel + Classic Aqua Status Bar ('Now Playing' / 'Lirik')
/// - Full-Width Vertical Cover Flow LCD (zero text truncation)
/// - Reference Minimalist White-Screen Single-Block Justified Lyrics Mode + Matching ID Translation
/// - Precision Recessed Click Wheel with Circular Scrub & Haptics
class IpodClassicPlayer extends StatefulWidget {
  final ZunifySong song;
  final PlayerProvider player;
  final ThemeProvider theme;
  final bool showLyrics;
  final VoidCallback onToggleLyrics;
  final VoidCallback onMenuTap;
  final Widget lyricsBuilder;
  final Widget utilityRow;

  const IpodClassicPlayer({
    super.key,
    required this.song,
    required this.player,
    required this.theme,
    required this.showLyrics,
    required this.onToggleLyrics,
    required this.onMenuTap,
    required this.lyricsBuilder,
    required this.utilityRow,
  });

  @override
  State<IpodClassicPlayer> createState() => _IpodClassicPlayerState();
}

class _IpodClassicPlayerState extends State<IpodClassicPlayer> {
  double? _lastWheelAngle;
  double _accumulatedAngle = 0.0;
  bool _centerPressed = false;

  String _fmt(Duration d) {
    final s = d.inSeconds.clamp(0, 86400);
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  void _handleWheelPanStart(DragStartDetails details, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = details.localPosition.dx - center.dx;
    final dy = details.localPosition.dy - center.dy;
    _lastWheelAngle = math.atan2(dy, dx);
    _accumulatedAngle = 0.0;
  }

  void _handleWheelPanUpdate(DragUpdateDetails details, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final dx = details.localPosition.dx - center.dx;
    final dy = details.localPosition.dy - center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    if (dist < size.width * 0.18) return;

    final angle = math.atan2(dy, dx);
    if (_lastWheelAngle != null) {
      double delta = angle - _lastWheelAngle!;
      if (delta > math.pi) delta -= 2 * math.pi;
      if (delta < -math.pi) delta += 2 * math.pi;
      _accumulatedAngle += delta;

      const stepRad = 0.28;
      if (_accumulatedAngle.abs() >= stepRad) {
        final steps = (_accumulatedAngle / stepRad).truncate();
        _accumulatedAngle -= steps * stepRad;
        HapticFeedback.selectionClick();
        final cur = widget.player.position;
        final dur = widget.player.duration;
        final nextPos = Duration(
          milliseconds: (cur.inMilliseconds + steps * 3000)
              .clamp(0, dur.inMilliseconds > 0 ? dur.inMilliseconds : 600000),
        );
        widget.player.seekTo(nextPos);
      }
    }
    _lastWheelAngle = angle;
  }

  void _handleWheelPanEnd(DragEndDetails _) {
    _lastWheelAngle = null;
    _accumulatedAngle = 0.0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final player = widget.player;
    final song = widget.song;
    final isDarkIpod = !theme.isLightCanvas;

    final chassisColors = isDarkIpod
        ? const [Color(0xFF282C36), Color(0xFF171A22), Color(0xFF0E1016)]
        : const [Color(0xFFF6F8FA), Color(0xFFE6EAF0), Color(0xFFD5DCE6)];
    final bezelOuter =
        isDarkIpod ? const Color(0xFF3A4050) : const Color(0xFFBCC4D0);
    const lcdInk = Color(0xFF0F172A);
    const lcdSub = Color(0xFF475569);
    const ipodAquaBlue = Color(0xFF2563EB);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: chassisColors,
          stops: const [0.0, 0.52, 1.0],
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          child: Column(
            children: [
              // 1. iPod Classic 6th Gen Recessed Glass LCD Frame
              Expanded(
                flex: 13,
                child: RepaintBoundary(
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(5.5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF1F232C), Color(0xFF0A0C10)],
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: bezelOuter, width: 1.5),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withOpacity(isDarkIpod ? 0.58 : 0.20),
                          blurRadius: 22,
                          offset: const Offset(0, 10),
                        ),
                        BoxShadow(
                          color: Colors.white
                              .withOpacity(isDarkIpod ? 0.06 : 0.85),
                          blurRadius: 2,
                          offset: const Offset(0, -1),
                        ),
                      ],
                    ),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14.5),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        children: [
                          // Authentic Glossy Platinum iPod Status Bar
                          Container(
                            height: 30,
                            padding: const EdgeInsets.symmetric(horizontal: 11),
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0xFFFCFDFF),
                                  Color(0xFFEAECEF),
                                  Color(0xFFD5D9E0),
                                ],
                                stops: [0.0, 0.50, 1.0],
                              ),
                              border: Border(
                                bottom: BorderSide(
                                  color: Color(0xFFA7B0BE),
                                  width: 0.85,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  player.isPlaying
                                      ? Icons.play_arrow_rounded
                                      : Icons.pause_rounded,
                                  size: 15,
                                  color: ipodAquaBlue,
                                ),
                                const SizedBox(width: 5),
                                Expanded(
                                  child: Text(
                                    widget.showLyrics ? 'Lirik' : 'Now Playing',
                                    style: GoogleFonts.plusJakartaSans(
                                      color: lcdInk,
                                      fontSize: 12.2,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -0.25,
                                    ),
                                  ),
                                ),
                                if (widget.showLyrics &&
                                    (player.currentLyrics
                                            ?.shouldShowTranslation ??
                                        false))
                                  GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      player.toggleTranslationDisplay();
                                    },
                                    child: Container(
                                      margin: const EdgeInsets.only(right: 8),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6.5,
                                        vertical: 2.2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: player.showTranslation
                                            ? const Color(0xFF111111)
                                            : Colors.black.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(5),
                                      ),
                                      child: Text(
                                        player.isTranslatingLyrics ? '...' : 'ID',
                                        style: TextStyle(
                                          color: player.showTranslation
                                              ? Colors.white
                                              : lcdInk,
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 0.2,
                                        ),
                                      ),
                                    ),
                                  ),
                                if (player.shuffleEnabled)
                                  const Padding(
                                    padding: EdgeInsets.only(right: 5),
                                    child: Icon(
                                      Icons.shuffle_rounded,
                                      color: ipodAquaBlue,
                                      size: 13,
                                    ),
                                  ),
                                if (player.repeatMode > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(right: 6),
                                    child: Icon(
                                      player.repeatMode == 2
                                          ? Icons.repeat_one_rounded
                                          : Icons.repeat_rounded,
                                      color: ipodAquaBlue,
                                      size: 13,
                                    ),
                                  ),
                                Text(
                                  '${player.currentIndex + 1} of ${player.queue.length}',
                                  style: const TextStyle(
                                    color: lcdSub,
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                // Classic Retro Metallic Green Battery
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 10.5,
                                      padding: const EdgeInsets.all(1.3),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFF475569),
                                          width: 1,
                                        ),
                                        borderRadius: BorderRadius.circular(2.2),
                                      ),
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Color(0xFF6EE7B7),
                                              Color(0xFF16A34A),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 1.8,
                                      height: 4.5,
                                      decoration: const BoxDecoration(
                                        color: Color(0xFF475569),
                                        borderRadius: BorderRadius.horizontal(
                                          right: Radius.circular(1),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // LCD Body: Vertical Cover Flow OR Reference Minimalist White Lyrics
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragEnd: (details) {
                                final vx = details.primaryVelocity ?? 0;
                                if (vx < -280) {
                                  HapticFeedback.lightImpact();
                                  player.playNext();
                                } else if (vx > 280) {
                                  HapticFeedback.lightImpact();
                                  player.playPrevious();
                                }
                              },
                              child: AnimatedSwitcher(
                                duration: const Duration(milliseconds: 220),
                                child: widget.showLyrics
                                    ? _buildReferenceMinimalLyricsLcd(
                                        key: const ValueKey('ipod_lyrics_lcd'),
                                        player: player,
                                        glossBlue: ipodAquaBlue,
                                      )
                                    : _buildCoverFlowLcdBody(
                                        key: const ValueKey('ipod_cover_lcd'),
                                        context: context,
                                        song: song,
                                        player: player,
                                        lcdInk: lcdInk,
                                        lcdSub: lcdSub,
                                        glossBlue: ipodAquaBlue,
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // 2. Refined Recessed Click Wheel
              Expanded(
                flex: 11,
                child: RepaintBoundary(
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: LayoutBuilder(
                        builder: (_, constraints) {
                          final wheelSize = Size(
                            constraints.maxWidth,
                            constraints.maxHeight,
                          );
                          final wheelFg = isDarkIpod
                              ? const Color(0xFFD6DAE2)
                              : const Color(0xFF64748B);
                          final wheelColors = isDarkIpod
                              ? const [
                                  Color(0xFF20242E),
                                  Color(0xFF151820),
                                  Color(0xFF101218),
                                ]
                              : const [
                                  Color(0xFFFFFFFF),
                                  Color(0xFFF6F8FB),
                                  Color(0xFFE9EEF5),
                                ];

                          return GestureDetector(
                            onPanStart: (d) =>
                                _handleWheelPanStart(d, wheelSize),
                            onPanUpdate: (d) =>
                                _handleWheelPanUpdate(d, wheelSize),
                            onPanEnd: _handleWheelPanEnd,
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: wheelColors,
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isDarkIpod
                                      ? const Color(0xFF383E4E)
                                      : const Color(0xFFCBD5E1),
                                  width: 1.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(
                                      isDarkIpod ? 0.55 : 0.13,
                                    ),
                                    blurRadius: 22,
                                    offset: const Offset(0, 9),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withOpacity(
                                      isDarkIpod ? 0.05 : 0.88,
                                    ),
                                    blurRadius: 5,
                                    offset: const Offset(-2, -2),
                                  ),
                                ],
                              ),
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Subtle inner precision ring
                                  Container(
                                    width: wheelSize.width * 0.90,
                                    height: wheelSize.height * 0.90,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: isDarkIpod
                                            ? Colors.white.withOpacity(0.03)
                                            : Colors.black.withOpacity(0.03),
                                        width: 1.0,
                                      ),
                                    ),
                                  ),
                                  // Top: MENU (Back)
                                  Positioned(
                                    top: 13,
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.opaque,
                                      onTap: () {
                                        HapticFeedback.lightImpact();
                                        widget.onMenuTap();
                                      },
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 22,
                                          vertical: 8,
                                        ),
                                        child: Text(
                                          'MENU',
                                          style: GoogleFonts.plusJakartaSans(
                                            color: wheelFg,
                                            fontSize: 12.8,
                                            fontWeight: FontWeight.w800,
                                            letterSpacing: 1.6,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  // Left: Previous
                                  Positioned(
                                    left: 13,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.fast_rewind_rounded,
                                        color: wheelFg,
                                        size: 27,
                                      ),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        player.playPrevious();
                                      },
                                    ),
                                  ),
                                  // Right: Next
                                  Positioned(
                                    right: 13,
                                    child: IconButton(
                                      icon: Icon(
                                        Icons.fast_forward_rounded,
                                        color: wheelFg,
                                        size: 27,
                                      ),
                                      onPressed: () {
                                        HapticFeedback.lightImpact();
                                        player.playNext();
                                      },
                                    ),
                                  ),
                                  // Bottom: Play/Pause
                                  Positioned(
                                    bottom: 11,
                                    child: IconButton(
                                      icon: Icon(
                                        player.isPlaying
                                            ? Icons.pause_rounded
                                            : Icons.play_arrow_rounded,
                                        color: wheelFg,
                                        size: 28,
                                      ),
                                      onPressed: () {
                                        HapticFeedback.mediumImpact();
                                        player.togglePlayPause();
                                      },
                                    ),
                                  ),
                                  // Recessed Center Select Button (Cover <-> Lirik)
                                  GestureDetector(
                                    onTapDown: (_) =>
                                        setState(() => _centerPressed = true),
                                    onTapUp: (_) {
                                      setState(() => _centerPressed = false);
                                      HapticFeedback.mediumImpact();
                                      widget.onToggleLyrics();
                                    },
                                    onTapCancel: () =>
                                        setState(() => _centerPressed = false),
                                    child: AnimatedScale(
                                      scale: _centerPressed ? 0.93 : 1.0,
                                      duration: const Duration(milliseconds: 90),
                                      child: Container(
                                        width: wheelSize.width * 0.35,
                                        height: wheelSize.height * 0.35,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: isDarkIpod
                                                ? const [
                                                    Color(0xFF101319),
                                                    Color(0xFF212530),
                                                  ]
                                                : const [
                                                    Color(0xFFD7DDE6),
                                                    Color(0xFFF6F8FA),
                                                  ],
                                          ),
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isDarkIpod
                                                ? const Color(0xFF303544)
                                                : const Color(0xFFB8C2D0),
                                            width: 1.3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                isDarkIpod ? 0.32 : 0.08,
                                              ),
                                              blurRadius: 6,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              widget.showLyrics
                                                  ? Icons.album_rounded
                                                  : Icons.lyrics_rounded,
                                              color: ipodAquaBlue,
                                              size: 20,
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              widget.showLyrics
                                                  ? 'COVER'
                                                  : 'LIRIK',
                                              style: TextStyle(
                                                color: wheelFg,
                                                fontSize: 8.5,
                                                fontWeight: FontWeight.w900,
                                                letterSpacing: 1.0,
                                              ),
                                            ),
                                          ],
                                        ),
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
                  ),
                ),
              ),

              const SizedBox(height: 10),
              widget.utilityRow,
            ],
          ),
        ),
      ),
    );
  }

  /// Reference-accurate iPod Minimalist White Lyrics LCD:
  /// - Crisp #FFFFFF pure white screen
  /// - One active lyric phrase centered at a time (blank white during instrumental rests)
  /// - Clean regular condensed sans-serif, all lowercase, block-justified aesthetic
  /// - Matching lowercase Indonesian translation directly below when `ID` is active
  Widget _buildReferenceMinimalLyricsLcd({
    Key? key,
    required PlayerProvider player,
    required Color glossBlue,
  }) {
    final SyncedLyrics? lyrics = player.currentLyrics;

    if (player.isLoadingLyrics) {
      return Container(
        key: key,
        color: Colors.white,
        alignment: Alignment.center,
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2.0,
            color: glossBlue,
          ),
        ),
      );
    }

    if (lyrics == null || lyrics.lines.isEmpty) {
      return Container(
        key: key,
        color: Colors.white,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: const Text(
          'lirik belum tersedia',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'sans-serif',
            color: Color(0xFF94A3B8),
            fontSize: 16,
            fontWeight: FontWeight.w400,
            letterSpacing: -0.4,
          ),
        ),
      );
    }

    final idx = player.activeLyricIndex;
    final LyricLine? activeLine =
        (idx >= 0 && idx < lyrics.lines.length) ? lyrics.lines[idx] : null;
    final bool isBlankRest = activeLine == null ||
        activeLine.originalText.trim().isEmpty ||
        activeLine.originalText.contains('•');

    final String mainText =
        isBlankRest ? '' : activeLine.originalText.trim().toLowerCase();
    final String? bgText = (!isBlankRest &&
            activeLine.backgroundText != null &&
            activeLine.backgroundText!.trim().isNotEmpty)
        ? activeLine.backgroundText!.trim().toLowerCase()
        : null;
    final String? translatedText = (!isBlankRest &&
            player.showTranslation &&
            lyrics.shouldShowTranslation &&
            activeLine.translatedIndoText != null &&
            activeLine.translatedIndoText!.trim().isNotEmpty)
        ? activeLine.translatedIndoText!.trim().toLowerCase()
        : null;

    return Container(
      key: key,
      color: Colors.white,
      width: double.infinity,
      height: double.infinity,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final boxWidth = (constraints.maxWidth * 0.78).clamp(160.0, 290.0);
          final wordCount =
              mainText.isEmpty ? 0 : mainText.split(RegExp(r'\s+')).length;
          final baseFontSize = mainText.length > 52
              ? 18.5
              : (mainText.length > 34 ? 21.0 : 24.5);

          return Stack(
            children: [
              // Main centered lyric block with crisp fade between phrases
              Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 190),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  child: isBlankRest
                      ? const SizedBox.shrink(key: ValueKey('ipod_blank_rest'))
                      : SizedBox(
                          key: ValueKey('ipod_line_${idx}_$mainText'),
                          width: boxWidth,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildBratJustifiedTextBlock(
                                text: mainText,
                                wordCount: wordCount,
                                fontSize: baseFontSize,
                                color: const Color(0xFF0A0A0A),
                              ),
                              if (bgText != null) ...[
                                const SizedBox(height: 6),
                                Text(
                                  bgText,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontFamily: 'sans-serif',
                                    color: Color(0xFF71717A),
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w400,
                                    letterSpacing: -0.4,
                                    height: 1.2,
                                  ),
                                ),
                              ],
                              if (translatedText != null) ...[
                                const SizedBox(height: 12),
                                _buildBratJustifiedTextBlock(
                                  text: translatedText,
                                  wordCount: translatedText
                                      .split(RegExp(r'\s+'))
                                      .length,
                                  fontSize: (baseFontSize * 0.64).clamp(
                                    13.0,
                                    15.5,
                                  ),
                                  color: const Color(0xFF6B7280),
                                ),
                              ],
                            ],
                          ),
                        ),
                ),
              ),

              // Whisper-thin playback hairline at very bottom of LCD
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: StreamBuilder<Duration>(
                  stream: player.audioPlayer.positionStream,
                  builder: (_, snap) {
                    final pos = snap.data ?? player.position;
                    final dur = player.duration;
                    final totalMs =
                        dur.inMilliseconds > 0 ? dur.inMilliseconds : 1;
                    final frac =
                        (pos.inMilliseconds / totalMs).clamp(0.0, 1.0);
                    return Container(
                      height: 2.5,
                      color: const Color(0xFFF1F5F9),
                      alignment: Alignment.centerLeft,
                      child: FractionallySizedBox(
                        widthFactor: frac,
                        child: Container(color: const Color(0xFF111111)),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Renders the exact aesthetic from the user's reference video:
  /// - Short 1-3 word phrases: cleanly centered (`i miss you`, `you know it's true`)
  /// - Longer phrases: 2 balanced lines where the final 2-word line spreads edge-to-edge
  ///   (`i wish i didn't but i` / `miss        you`, `and you pick up` / `the       phone`).
  Widget _buildBratJustifiedTextBlock({
    required String text,
    required int wordCount,
    required double fontSize,
    required Color color,
  }) {
    final style = TextStyle(
      fontFamily: 'sans-serif',
      color: color,
      fontSize: fontSize,
      fontWeight: FontWeight.w400,
      letterSpacing: -0.95,
      height: 1.16,
    );

    // Short 1-3 word phrases stay crisp and centered
    if (wordCount <= 3) {
      return Text(
        text,
        textAlign: TextAlign.center,
        style: style,
      );
    }

    // For 4-8 word phrases with reasonable line widths, craft the signature reference 2-line justified spread
    final words = text.split(RegExp(r'\s+'));
    if (words.length >= 4 && words.length <= 8) {
      final splitAt = (words.length * 0.62).ceil().clamp(2, words.length - 1);
      final topWords = words.sublist(0, splitAt);
      final bottomWords = words.sublist(splitAt);
      final topLen = topWords.join(' ').length;
      final bottomLen = bottomWords.join(' ').length;

      if (topLen <= 24 && bottomLen <= 22) {
        return LayoutBuilder(
          builder: (ctx, box) {
            final minW = box.maxWidth.isFinite ? box.maxWidth : 0.0;
            Widget buildSpreadRow(List<String> rowWords) {
              return FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.center,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: minW),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: rowWords
                        .map(
                          (w) => Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: Text(w, style: style),
                          ),
                        )
                        .toList(),
                  ),
                ),
              );
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                buildSpreadRow(topWords),
                const SizedBox(height: 1.5),
                if (bottomWords.length == 1)
                  Text(
                    bottomWords.first,
                    textAlign: TextAlign.left,
                    style: style,
                  )
                else
                  buildSpreadRow(bottomWords),
              ],
            );
          },
        );
      }
    }

    // Longer lines wrap cleanly justified across full block width
    return Text(
      text,
      textAlign: TextAlign.justify,
      style: style,
    );
  }

  Widget _buildCoverFlowLcdBody({
    Key? key,
    required BuildContext context,
    required ZunifySong song,
    required PlayerProvider player,
    required Color lcdInk,
    required Color lcdSub,
    required Color glossBlue,
  }) {
    return LayoutBuilder(
      key: key,
      builder: (context, constraints) {
        final availH = constraints.maxHeight;
        final isCompact = availH < 210;
        final artSize = (availH * (isCompact ? 0.39 : 0.45)).clamp(74.0, 134.0);
        final showReflection = availH >= 200;

        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFFFFFFF), Color(0xFFF4F6FA)],
            ),
          ),
          padding: EdgeInsets.fromLTRB(
            14,
            isCompact ? 8 : 12,
            14,
            isCompact ? 8 : 11,
          ),
          child: Column(
            children: [
              // Centered Vertical Layout: 3D Cover Art on Top + Full-Width Title & Artist Below
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Hero(
                      tag: 'zunify_now_playing_art',
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0020)
                          ..rotateY(0.14),
                        child: Container(
                          width: artSize,
                          height: artSize,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.24),
                                blurRadius: 14,
                                offset: const Offset(2, 7),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: CachedNetworkImage(
                            imageUrl: song.highResArtUrl,
                            memCacheWidth: 360,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => ColoredBox(
                              color: const Color(0xFFE5E7EB),
                              child: Icon(
                                Icons.music_note_rounded,
                                color: glossBlue,
                                size: artSize * 0.36,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (showReflection)
                      Transform(
                        alignment: Alignment.topCenter,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0020)
                          ..rotateY(0.14),
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.topCenter,
                            heightFactor: 0.13,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.diagonal3Values(1, -1, 1),
                              child: Opacity(
                                opacity: 0.17,
                                child: ShaderMask(
                                  shaderCallback: (r) => const LinearGradient(
                                    begin: Alignment.bottomCenter,
                                    end: Alignment.topCenter,
                                    colors: [Colors.black, Colors.transparent],
                                  ).createShader(r),
                                  blendMode: BlendMode.dstIn,
                                  child: CachedNetworkImage(
                                    imageUrl: song.highResArtUrl,
                                    width: artSize,
                                    height: artSize,
                                    memCacheWidth: 240,
                                    fit: BoxFit.cover,
                                    errorWidget: (_, __, ___) =>
                                        const SizedBox.shrink(),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),

                    SizedBox(height: isCompact ? 6 : 8),

                    // Full-Width Song Title (never truncated prematurely)
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        song.title,
                        textAlign: TextAlign.center,
                        maxLines: isCompact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: lcdInk,
                          fontSize: isCompact ? 14.2 : 15.8,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.35,
                          height: 1.18,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Full-Width Artist Name
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        song.artist,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: lcdSub,
                          fontSize: isCompact ? 12.2 : 13.0,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // Authentic Glossy Aqua iPod Scrubber Bar
              StreamBuilder<Duration>(
                stream: player.audioPlayer.positionStream,
                builder: (_, snap) {
                  final pos = snap.data ?? player.position;
                  final dur = player.duration;
                  final totalMs = dur.inMilliseconds > 0 ? dur.inMilliseconds : 1;
                  final frac = (pos.inMilliseconds / totalMs).clamp(0.0, 1.0);
                  return Column(
                    children: [
                      LayoutBuilder(
                        builder: (barCtx, barCons) {
                          final barW =
                              barCons.maxWidth > 0 ? barCons.maxWidth : 1.0;
                          return GestureDetector(
                            onHorizontalDragUpdate: (d) {
                              final p = (d.localPosition.dx / barW).clamp(
                                0.0,
                                1.0,
                              );
                              player.seekTo(
                                Duration(milliseconds: (p * totalMs).round()),
                              );
                            },
                            child: Container(
                              height: 10.5,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter,
                                  end: Alignment.bottomCenter,
                                  colors: [
                                    Color(0xFFDDE3EC),
                                    Color(0xFFF1F5F9),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(3.5),
                                border: Border.all(
                                  color: const Color(0xFF94A3B8),
                                  width: 0.8,
                                ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: FractionallySizedBox(
                                  widthFactor: frac,
                                  child: Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF93C5FD),
                                          Color(0xFF3B82F6),
                                          Color(0xFF1D4ED8),
                                        ],
                                        stops: [0.0, 0.45, 1.0],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 5),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _fmt(pos),
                            style: TextStyle(
                              color: lcdInk,
                              fontSize: 10.8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '-${_fmt(dur - pos)}',
                            style: TextStyle(
                              color: lcdInk,
                              fontSize: 10.8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
