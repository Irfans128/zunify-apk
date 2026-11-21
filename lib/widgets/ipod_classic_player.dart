import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/song_model.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';

/// Authentic Classic iPod Player UI (Backlit LCD + Interactive Click Wheel).
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
    if (dist < size.width * 0.18) return; // Ignore center button area

    final angle = math.atan2(dy, dx);
    if (_lastWheelAngle != null) {
      double delta = angle - _lastWheelAngle!;
      if (delta > math.pi) delta -= 2 * math.pi;
      if (delta < -math.pi) delta += 2 * math.pi;
      _accumulatedAngle += delta;

      // Every ~18 degrees of wheel rotation scrubs +/- 3 seconds
      const stepRad = 0.31;
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
    final accent = theme.accentColor;

    final chassisTop =
        isDarkIpod ? const Color(0xFF1D1F27) : const Color(0xFFF3F5F8);
    final chassisBot =
        isDarkIpod ? const Color(0xFF121318) : const Color(0xFFDDE2E8);
    final lcdBg =
        isDarkIpod ? const Color(0xFF0E1117) : const Color(0xFFFFFFFF);
    final lcdText = isDarkIpod ? Colors.white : const Color(0xFF111827);
    final lcdSub =
        isDarkIpod ? Colors.white60 : const Color(0xFF4B5563);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
        child: Column(
          children: [
            // Authentic iPod Bezel + Backlit LCD Screen
            Expanded(
              flex: 11,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [chassisTop, chassisBot],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isDarkIpod
                        ? const Color(0xFF313543)
                        : const Color(0xFFBCC4CF),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDarkIpod ? 0.45 : 0.14),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    color: lcdBg,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF111111).withOpacity(0.75),
                      width: 2.2,
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Classic iPod Status Bar
                      Container(
                        height: 28,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: isDarkIpod
                                ? const [Color(0xFF272B36), Color(0xFF1B1E26)]
                                : const [Color(0xFFF3F4F6), Color(0xFFD1D5DB)],
                          ),
                          border: Border(
                            bottom: BorderSide(
                              color: isDarkIpod
                                  ? Colors.white12
                                  : Colors.black.withOpacity(0.15),
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
                              color: accent,
                            ),
                            const SizedBox(width: 5),
                            Expanded(
                              child: Text(
                                widget.showLyrics ? 'Lyrics • iPod' : 'Now Playing',
                                style: TextStyle(
                                  color: lcdText,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            Text(
                              '${player.currentIndex + 1} / ${player.queue.length}',
                              style: TextStyle(
                                color: lcdSub,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(width: 8),
                            const Icon(
                              Icons.battery_charging_full_rounded,
                              size: 15,
                              color: Color(0xFF10B981),
                            ),
                          ],
                        ),
                      ),

                      // Screen Body: Artwork+Meta OR Brat White-Screen Synced Lyrics
                      Expanded(
                        child: widget.showLyrics
                            ? Container(
                                color: Colors.white,
                                child: widget.lyricsBuilder,
                              )
                            : Padding(
                                padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                                child: Column(
                                  children: [
                                    Expanded(
                                      child: Row(
                                        children: [
                                          // Crisp Square Album Art with subtle reflection frame
                                          AspectRatio(
                                            aspectRatio: 1,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: lcdSub.withOpacity(0.25),
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: Colors.black
                                                        .withOpacity(0.18),
                                                    blurRadius: 10,
                                                    offset: const Offset(0, 4),
                                                  ),
                                                ],
                                              ),
                                              clipBehavior: Clip.antiAlias,
                                              child: CachedNetworkImage(
                                                imageUrl: song.highResArtUrl,
                                                fit: BoxFit.cover,
                                                errorWidget: (_, __, ___) => Icon(
                                                  Icons.music_note_rounded,
                                                  color: accent,
                                                  size: 44,
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 14),
                                          Expanded(
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  song.title,
                                                  maxLines: 3,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: lcdText,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w800,
                                                    height: 1.2,
                                                  ),
                                                ),
                                                const SizedBox(height: 6),
                                                Text(
                                                  song.artist,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: accent,
                                                    fontSize: 13,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                const SizedBox(height: 3),
                                                Text(
                                                  song.album,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: lcdSub,
                                                    fontSize: 11.5,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    // Retro Scrub Progress Bar
                                    StreamBuilder<Duration>(
                                      stream: player.audioPlayer.positionStream,
                                      builder: (_, snap) {
                                        final pos = snap.data ?? player.position;
                                        final dur = player.duration;
                                        final maxMs = dur.inMilliseconds > 0
                                            ? dur.inMilliseconds.toDouble()
                                            : 1.0;
                                        final val = pos.inMilliseconds
                                            .toDouble()
                                            .clamp(0.0, maxMs);
                                        return Column(
                                          children: [
                                            SliderTheme(
                                              data: SliderTheme.of(context)
                                                  .copyWith(
                                                trackHeight: 6,
                                                thumbShape:
                                                    const RoundSliderThumbShape(
                                                  enabledThumbRadius: 6,
                                                ),
                                                overlayShape:
                                                    const RoundSliderOverlayShape(
                                                  overlayRadius: 12,
                                                ),
                                                activeTrackColor: accent,
                                                inactiveTrackColor:
                                                    lcdSub.withOpacity(0.22),
                                                thumbColor: accent,
                                              ),
                                              child: Slider(
                                                value: val,
                                                max: maxMs,
                                                onChanged: (v) => player.seekTo(
                                                  Duration(
                                                    milliseconds: v.round(),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Text(
                                                    _fmt(pos),
                                                    style: TextStyle(
                                                      color: lcdSub,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                  Text(
                                                    '-${_fmt(dur - pos)}',
                                                    style: TextStyle(
                                                      color: lcdSub,
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Interactive Click Wheel
            Expanded(
              flex: 10,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: LayoutBuilder(
                    builder: (_, constraints) {
                      final wheelSize = Size(
                        constraints.maxWidth,
                        constraints.maxHeight,
                      );
                      final wheelFg =
                          isDarkIpod ? Colors.white70 : const Color(0xFF475569);
                      return GestureDetector(
                        onPanStart: (d) => _handleWheelPanStart(d, wheelSize),
                        onPanUpdate: (d) =>
                            _handleWheelPanUpdate(d, wheelSize),
                        onPanEnd: _handleWheelPanEnd,
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.ipodWheelBg,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.ipodWheelBorder,
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(
                                  isDarkIpod ? 0.40 : 0.10,
                                ),
                                blurRadius: 16,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              // Top: MENU
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
                                      horizontal: 18,
                                      vertical: 8,
                                    ),
                                    child: Text(
                                      'MENU',
                                      style: TextStyle(
                                        color: wheelFg,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.1,
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
                                    size: 28,
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
                                    size: 28,
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
                                    size: 28,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    player.togglePlayPause();
                                  },
                                ),
                              ),
                              // Center Select Button (Toggles Lyrics View!)
                              GestureDetector(
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  widget.onToggleLyrics();
                                },
                                child: Container(
                                  width: wheelSize.width * 0.36,
                                  height: wheelSize.height * 0.36,
                                  decoration: BoxDecoration(
                                    color: theme.ipodCenterBtnBg,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: theme.ipodWheelBorder,
                                      width: 1.2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Icon(
                                      widget.showLyrics
                                          ? Icons.album_rounded
                                          : Icons.lyrics_rounded,
                                      color: accent,
                                      size: 26,
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

            const SizedBox(height: 10),
            widget.utilityRow,
          ],
        ),
      ),
    );
  }
}
