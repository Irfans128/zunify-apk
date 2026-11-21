import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/song_model.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';

/// Authentic iPod Classic 6th Gen Player UI:
/// - Brushed Aluminum Silver / Matte Black Chassis
/// - Glossy Retro Status Bar + Split-Screen Cover Flow 3D LCD + Glossy Blue Progress Bar
/// - Viral White-Screen Brat Lyrics Mode (toggled via Center Select Button)
/// - Realistic Beveled Interactive Click Wheel with Circular Scrub & Haptics
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
        ? const [Color(0xFF232630), Color(0xFF15171E), Color(0xFF0E1015)]
        : const [Color(0xFFF3F5F8), Color(0xFFE3E7EE), Color(0xFFD2D8E2)];
    final bezelBorder =
        isDarkIpod ? const Color(0xFF343846) : const Color(0xFFB5BECA);
    final lcdBg = Colors.white;
    const lcdInk = Color(0xFF0F172A);
    const lcdSub = Color(0xFF475569);
    const ipodGlossBlue = Color(0xFF2563EB);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: chassisColors,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          child: Column(
            children: [
              // 1. iPod Classic 6th Gen Recessed Glass LCD Frame
              Expanded(
                flex: 12,
                child: RepaintBoundary(
                  child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(4.5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF111318),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: bezelBorder, width: 1.6),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDarkIpod ? 0.55 : 0.22),
                        blurRadius: 18,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Container(
                    decoration: BoxDecoration(
                      color: lcdBg,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Authentic Glossy Metallic iPod Top Status Bar
                        Container(
                          height: 29,
                          padding: const EdgeInsets.symmetric(horizontal: 11),
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Color(0xFFF9FAFB),
                                Color(0xFFE5E7EB),
                                Color(0xFFD1D5DB),
                              ],
                              stops: [0.0, 0.52, 1.0],
                            ),
                            border: Border(
                              bottom: BorderSide(
                                color: Color(0xFF9CA3AF),
                                width: 0.9,
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
                                color: ipodGlossBlue,
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                child: Text(
                                  widget.showLyrics
                                      ? 'brat lyrics'
                                      : 'Now Playing',
                                  style: const TextStyle(
                                    color: lcdInk,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                              ),
                              if (widget.showLyrics &&
                                  (player.currentLyrics?.shouldShowTranslation ??
                                      false))
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    player.toggleTranslationDisplay();
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(right: 8),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: player.showTranslation
                                          ? const Color(0xFF111111)
                                          : Colors.black12,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'ID',
                                      style: TextStyle(
                                        color: player.showTranslation
                                            ? Colors.white
                                            : lcdInk,
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                  ),
                                ),
                              if (player.shuffleEnabled)
                                Padding(
                                  padding: const EdgeInsets.only(right: 5),
                                  child: Icon(
                                    Icons.shuffle_rounded,
                                    color: ipodGlossBlue,
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
                                    color: ipodGlossBlue,
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
                              // Retro Green Metallic Battery Glyph
                              Container(
                                width: 20,
                                height: 10,
                                padding: const EdgeInsets.all(1.3),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: const Color(0xFF374151),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(2),
                                ),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [
                                        Color(0xFF4ADE80),
                                        Color(0xFF16A34A),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // LCD Body: Split-Screen 3D Cover Flow OR Pure White Brat Lyrics
                        Expanded(
                          child: widget.showLyrics
                              ? ColoredBox(
                                  color: Colors.white,
                                  child: widget.lyricsBuilder,
                                )
                              : _buildCoverFlowLcdBody(
                                  context: context,
                                  song: song,
                                  player: player,
                                  lcdInk: lcdInk,
                                  lcdSub: lcdSub,
                                  glossBlue: ipodGlossBlue,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
                ),
              ),

              const SizedBox(height: 18),

              // 2. Realistic Beveled Click Wheel
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
                            ? const Color(0xFFD1D5DB)
                            : const Color(0xFF64748B);
                        final wheelColors = isDarkIpod
                            ? const [Color(0xFF1D2028), Color(0xFF14161C)]
                            : const [Color(0xFFFFFFFF), Color(0xFFF1F5F9)];

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
                                    ? const Color(0xFF343846)
                                    : const Color(0xFFCBD5E1),
                                width: 1.6,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(
                                    isDarkIpod ? 0.50 : 0.14,
                                  ),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                                BoxShadow(
                                  color: Colors.white.withOpacity(
                                    isDarkIpod ? 0.05 : 0.80,
                                  ),
                                  blurRadius: 4,
                                  offset: const Offset(-2, -2),
                                ),
                              ],
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Top: MENU (Exit / Back)
                                Positioned(
                                  top: 14,
                                  child: GestureDetector(
                                    behavior: HitTestBehavior.opaque,
                                    onTap: () {
                                      HapticFeedback.lightImpact();
                                      widget.onMenuTap();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 8,
                                      ),
                                      child: Text(
                                        'MENU',
                                        style: TextStyle(
                                          color: wheelFg,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                // Left: Previous
                                Positioned(
                                  left: 14,
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.fast_rewind_rounded,
                                      color: wheelFg,
                                      size: 29,
                                    ),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      player.playPrevious();
                                    },
                                  ),
                                ),
                                // Right: Next
                                Positioned(
                                  right: 14,
                                  child: IconButton(
                                    icon: Icon(
                                      Icons.fast_forward_rounded,
                                      color: wheelFg,
                                      size: 29,
                                    ),
                                    onPressed: () {
                                      HapticFeedback.lightImpact();
                                      player.playNext();
                                    },
                                  ),
                                ),
                                // Bottom: Play/Pause
                                Positioned(
                                  bottom: 12,
                                  child: IconButton(
                                    icon: Icon(
                                      player.isPlaying
                                          ? Icons.pause_rounded
                                          : Icons.play_arrow_rounded,
                                      color: wheelFg,
                                      size: 29,
                                    ),
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      player.togglePlayPause();
                                    },
                                  ),
                                ),
                                // Recessed Center Select Button (Cover Flow <-> Brat Lyrics)
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
                                      width: wheelSize.width * 0.36,
                                      height: wheelSize.height * 0.36,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                          colors: isDarkIpod
                                              ? const [
                                                  Color(0xFF111319),
                                                  Color(0xFF1F222C),
                                                ]
                                              : const [
                                                  Color(0xFFDCE1E8),
                                                  Color(0xFFF3F5F8),
                                                ],
                                        ),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDarkIpod
                                              ? const Color(0xFF2D313E)
                                              : const Color(0xFFBDC5D1),
                                          width: 1.4,
                                        ),
                                      ),
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            widget.showLyrics
                                                ? Icons.album_rounded
                                                : Icons.lyrics_rounded,
                                            color: ipodGlossBlue,
                                            size: 22,
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            widget.showLyrics ? 'COVER' : 'BRAT',
                                            style: TextStyle(
                                              color: wheelFg,
                                              fontSize: 8.5,
                                              fontWeight: FontWeight.w900,
                                              letterSpacing: 0.8,
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

              const SizedBox(height: 12),
              widget.utilityRow,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCoverFlowLcdBody({
    required BuildContext context,
    required ZunifySong song,
    required PlayerProvider player,
    required Color lcdInk,
    required Color lcdSub,
    required Color glossBlue,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final availH = constraints.maxHeight;
        final isCompact = availH < 210;
        final artSize = (availH * (isCompact ? 0.38 : 0.43)).clamp(72.0, 128.0);
        final showReflection = availH >= 200;

        return Padding(
          padding: EdgeInsets.fromLTRB(
            14,
            isCompact ? 8 : 12,
            14,
            isCompact ? 8 : 11,
          ),
          child: Column(
            children: [
              // Centered Vertical Layout: 3D Tilted Cover Art on Top + Full-Width Title & Artist Below
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 3D Cover Flow Artwork + Subtle Glossy Floor Reflection
                    Transform(
                      alignment: Alignment.center,
                      transform: Matrix4.identity()
                        ..setEntry(3, 2, 0.0020)
                        ..rotateY(0.16),
                      child: Container(
                        width: artSize,
                        height: artSize,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.24),
                              blurRadius: 12,
                              offset: const Offset(3, 6),
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
                    if (showReflection)
                      Transform(
                        alignment: Alignment.topCenter,
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.0020)
                          ..rotateY(0.16),
                        child: ClipRect(
                          child: Align(
                            alignment: Alignment.topCenter,
                            heightFactor: 0.14,
                            child: Transform(
                              alignment: Alignment.center,
                              transform: Matrix4.diagonal3Values(1, -1, 1),
                              child: Opacity(
                                opacity: 0.18,
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

                    // Full-Width Song Title (up to 2 lines, never cramped!)
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        song.title,
                        textAlign: TextAlign.center,
                        maxLines: isCompact ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: lcdInk,
                          fontSize: isCompact ? 14.2 : 15.6,
                          fontWeight: FontWeight.w900,
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
                        style: TextStyle(
                          color: lcdSub,
                          fontSize: isCompact ? 12.2 : 13.0,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 6),

              // Classic Glossy Blue iPod Scrubber Bar
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
                              height: 10,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: const Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(3),
                                border: Border.all(
                                  color: const Color(0xFF9CA3AF),
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
