import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/lyric_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/ipod_classic_player.dart';
import '../widgets/liquid_background_widget.dart';
import '../widgets/share_card_modal.dart';
import '../widgets/sleep_timer_sheet.dart';
import '../widgets/song_tile_widget.dart';
import '../widgets/vinyl_disc_widget.dart';
import 'artist_profile_screen.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool _showLyricsView = false;
  final ScrollController _lyricsScrollController = ScrollController();

  // Deterministic Measured-Height LyricPlayhead Engine
  final Map<int, double> _lineHeights = {};
  double _lyricsViewportHeight = 360.0;
  int _lastScrolledLyricIdx = -99;
  String? _lastSongId;
  bool _userScrollingLyrics = false;
  bool _isDraggingSeekSlider = false;
  double? _dragSeekMs;

  Timer? _resumeAutoScrollTimer;
  Timer? _smoothKaraokeTimer;
  final ValueNotifier<int> _smoothPosMs = ValueNotifier<int>(0);

  @override
  void initState() {
    super.initState();
    _startSmoothKaraokeClock();
  }

  void _startSmoothKaraokeClock() {
    _smoothKaraokeTimer?.cancel();
    _smoothKaraokeTimer = Timer.periodic(
      const Duration(milliseconds: 40),
      (_) {
        if (!mounted || !_showLyricsView) return;
        final player = context.read<PlayerProvider>();
        final song = player.currentSong;
        if (song == null) return;

        final ms =
            player.audioPlayer.position.inMilliseconds + player.lyricsOffsetMs;
        if ((ms - _smoothPosMs.value).abs() >= 36) {
          _smoothPosMs.value = ms;
        }

        if (!_userScrollingLyrics) {
          final totalLines = player.currentLyrics?.lines.length ?? 0;
          if (totalLines > 0) {
            final curIdx = player.activeLyricIndex;
            if (_lastSongId != song.videoId || _lastScrolledLyricIdx != curIdx) {
              _scrollToActiveLyric(
                song.videoId,
                curIdx,
                totalLines,
                force: true,
              );
            }
          }
        }
      },
    );
  }

  @override
  void dispose() {
    _resumeAutoScrollTimer?.cancel();
    _smoothKaraokeTimer?.cancel();
    _smoothPosMs.dispose();
    _lyricsScrollController.dispose();
    super.dispose();
  }

  void _onUserScrollNotification(UserScrollNotification notification) {
    if (notification.direction != ScrollDirection.idle) {
      _resumeAutoScrollTimer?.cancel();
      if (!_userScrollingLyrics) {
        setState(() => _userScrollingLyrics = true);
      }
      _resumeAutoScrollTimer = Timer(const Duration(milliseconds: 3200), () {
        if (!mounted) return;
        setState(() {
          _userScrollingLyrics = false;
          _lastScrolledLyricIdx = -99;
        });
        final player = context.read<PlayerProvider>();
        final song = player.currentSong;
        final totalLines = player.currentLyrics?.lines.length ?? 0;
        if (song != null && totalLines > 0) {
          _scrollToActiveLyric(
            song.videoId,
            player.activeLyricIndex,
            totalLines,
            force: true,
          );
        }
      });
    }
  }

  void _scrollToActiveLyric(
    String videoId,
    int activeIdx,
    int totalLines, {
    bool force = false,
  }) {
    if (!_showLyricsView || _userScrollingLyrics || totalLines <= 0) return;
    if (!_lyricsScrollController.hasClients) return;

    if (_lastSongId != videoId) {
      _lineHeights.clear();
      _lastSongId = videoId;
      _lastScrolledLyricIdx = -99;
    }

    final targetIdx = activeIdx < 0 ? 0 : activeIdx.clamp(0, totalLines - 1);
    if (!force && _lastScrolledLyricIdx == activeIdx) return;

    double sumBefore = 0.0;
    for (int i = 0; i < targetIdx; i++) {
      sumBefore += (_lineHeights[i] ?? 72.0);
    }

    final activeHeight = _lineHeights[targetIdx] ?? 76.0;
    final desiredPlayheadShift =
        ((_lyricsViewportHeight * 0.24) - 68.0 - (activeHeight * 0.15))
            .clamp(-12.0, 56.0);

    final maxExt = _lyricsScrollController.position.maxScrollExtent;
    final rawTarget = targetIdx == 0 ? 0.0 : (sumBefore - desiredPlayheadShift);
    final targetOffset = rawTarget.clamp(0.0, maxExt);

    _lastScrolledLyricIdx = activeIdx;

    if ((targetOffset - _lyricsScrollController.offset).abs() > 1.5) {
      final dur = context.read<ThemeProvider>().animDuration(360);
      _lyricsScrollController.animateTo(
        targetOffset,
        duration: dur,
        curve: Curves.easeOutCubic,
      );
    }
  }

  void _openShareModal(BuildContext context, PlayerProvider player) {
    final song = player.currentSong;
    if (song == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShareCardModal(
        song: song,
        lyrics: player.currentLyrics,
        initialLyricIndex:
            player.activeLyricIndex < 0 ? 0 : player.activeLyricIndex,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final library = context.watch<LibraryProvider>();
    final theme = context.watch<ThemeProvider>();
    final song = player.currentSong;

    if (song == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    final accent = theme.accentColor;
    final ambient = theme.playerAmbientColor;
    final isBrutal = theme.isNeoBrutalism;
    final isFav = library.isFavorite(song.videoId);
    final isDownloaded = library.isDownloaded(song.videoId);
    final downloadProgress = library.activeDownloadProgress[song.videoId];
    final totalLyricLines = player.currentLyrics?.lines.length ?? 0;

    if (_lastSongId != song.videoId) {
      _lineHeights.clear();
      _lastSongId = song.videoId;
      _lastScrolledLyricIdx = -99;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _scrollToActiveLyric(
        song.videoId,
        player.activeLyricIndex,
        totalLyricLines,
      );
    });

    final utilityDock = _buildUtilityDock(
      context: context,
      player: player,
      library: library,
      theme: theme,
      accent: accent,
      song: song,
      isDownloaded: isDownloaded,
      downloadProgress: downloadProgress,
      totalLyricLines: totalLyricLines,
    );

    if (theme.isClassicIpod) {
      return Scaffold(
        backgroundColor: theme.scaffoldBgColor,
        body: IpodClassicPlayer(
          song: song,
          player: player,
          theme: theme,
          showLyrics: _showLyricsView,
          onToggleLyrics: () {
            setState(() {
              _showLyricsView = !_showLyricsView;
              _userScrollingLyrics = false;
              _lastScrolledLyricIdx = -99;
            });
            if (_showLyricsView) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _scrollToActiveLyric(
                  song.videoId,
                  player.activeLyricIndex,
                  totalLyricLines,
                  force: true,
                );
              });
            }
          },
          onMenuTap: () => Navigator.pop(context),
          lyricsBuilder: _buildBitChordLyricsView(
            song.videoId,
            player,
            theme,
            accent,
          ),
          utilityRow: utilityDock,
        ),
      );
    }

    return Scaffold(
      backgroundColor: theme.scaffoldBgColor,
      body: LiquidBackgroundWidget(
        primaryColor: ambient,
        secondaryColor: accent,
        baseColor: theme.scaffoldBgColor,
        imageUrl: song.highResArtUrl,
        intensity: _showLyricsView ? 0.64 : 0.54,
        child: SafeArea(
          child: Padding(
            padding: theme.playerHorizontalPadding,
            child: Column(
              children: [
                // Top Drag Pill Handle
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(top: 2, bottom: 4),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                // Apple Music Ultra-Clean Top Bar (No bulky Musik|Lirik pill!)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IosSpringButton(
                      borderRadius: 20,
                      onTap: () {
                        if (_showLyricsView) {
                          setState(() => _showLyricsView = false);
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          _showLyricsView
                              ? Icons.arrow_back_ios_new_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: theme.textPrimary,
                          size: _showLyricsView ? 19 : 28,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _showLyricsView
                                ? 'LIRIK'
                                : (player.contextName.isNotEmpty
                                    ? player.contextName.toUpperCase()
                                    : 'SEDANG DIPUTAR'),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: theme.textMuted,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.1,
                            ),
                          ),
                          if (_showLyricsView &&
                              (player.currentLyrics?.hasMultipleSingers ??
                                  false)) ...[
                            const SizedBox(height: 1),
                            Text(
                              'Mode Duet • 2 Sisi',
                              style: TextStyle(
                                color: theme.accentText,
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    IosSpringButton(
                      borderRadius: 20,
                      onTap: () => showSongActionSheet(
                        context,
                        song: song,
                      ),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Icon(
                          Icons.more_horiz_rounded,
                          color: theme.textPrimary,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 4 * theme.playerSpacingFactor),

                // Main Centerpiece: Synced Lyrics View OR Spacious Apple Music Artwork/Vinyl
                Expanded(
                  child: AnimatedSwitcher(
                    duration: theme.animDuration(260),
                    child: _showLyricsView
                        ? _buildBitChordLyricsView(
                            song.videoId,
                            player,
                            theme,
                            accent,
                          )
                        : GestureDetector(
                            key: const ValueKey('artwork_or_vinyl_view'),
                            behavior: HitTestBehavior.translucent,
                            onVerticalDragEnd: (details) {
                              if ((details.primaryVelocity ?? 0) < -260) {
                                setState(() {
                                  _showLyricsView = true;
                                  _userScrollingLyrics = false;
                                  _lastScrolledLyricIdx = -99;
                                });
                              } else if ((details.primaryVelocity ?? 0) > 340) {
                                Navigator.pop(context);
                              }
                            },
                            onHorizontalDragEnd: (details) {
                              final vx = details.primaryVelocity ?? 0;
                              if (vx < -300) {
                                player.playNext();
                              } else if (vx > 300) {
                                player.playPrevious();
                              }
                            },
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isVinyl =
                                    theme.playerCoverStyle == 'vinyl';
                                final vinylRingReserve = isVinyl ? 44.0 : 0.0;
                                final maxFit = math.min(
                                      constraints.maxWidth - 4,
                                      constraints.maxHeight - 12,
                                    ) -
                                    vinylRingReserve;
                                final double availableForArt = maxFit <= 120.0
                                    ? math.max(80.0, maxFit)
                                    : maxFit.clamp(120.0, 356.0);
                                return Center(
                                  child: Stack(
                                    alignment: Alignment.topRight,
                                    children: [
                                      Hero(
                                        tag: 'zunify_now_playing_art',
                                        flightShuttleBuilder: (
                                          flightCtx,
                                          animation,
                                          direction,
                                          fromCtx,
                                          toCtx,
                                        ) {
                                          final radiusTween =
                                              BorderRadiusTween(
                                            begin: BorderRadius.circular(
                                              isBrutal ? 8 : 11,
                                            ),
                                            end: BorderRadius.circular(
                                              isBrutal ? 18 : 28,
                                            ),
                                          );
                                          return AnimatedBuilder(
                                            animation: animation,
                                            builder: (_, __) {
                                              return ClipRRect(
                                                borderRadius: radiusTween
                                                        .evaluate(animation) ??
                                                    BorderRadius.circular(20),
                                                child: CachedNetworkImage(
                                                  imageUrl: song.highResArtUrl,
                                                  memCacheWidth: 480,
                                                  fit: BoxFit.cover,
                                                  errorWidget: (_, __, ___) =>
                                                      Container(
                                                    color: theme.subtleFill,
                                                  ),
                                                ),
                                              );
                                            },
                                          );
                                        },
                                        child: theme.playerCoverStyle == 'vinyl'
                                            ? VinylDiscWidget(
                                                imageUrl: song.highResArtUrl,
                                                localImagePath:
                                                    song.localArtPath,
                                                isPlaying: player.isPlaying,
                                                accentColor: accent,
                                                size: availableForArt,
                                              )
                                            : _buildModern3DAlbumArtwork(
                                                imageUrl: song.highResArtUrl,
                                                isPlaying: player.isPlaying,
                                                accent: accent,
                                                ambient: ambient,
                                                theme: theme,
                                                size: availableForArt,
                                              ),
                                      ),
                                      Positioned(
                                        right: 10,
                                        top: 10,
                                        child: IosSpringButton(
                                          borderRadius: 16,
                                          onTap: () =>
                                              theme.setPlayerCoverStyle(
                                            theme.playerCoverStyle == 'vinyl'
                                                ? 'artwork'
                                                : 'vinyl',
                                          ),
                                          child: Container(
                                            width: 32,
                                            height: 32,
                                            decoration: BoxDecoration(
                                              color: Colors.black
                                                  .withOpacity(0.36),
                                              shape: BoxShape.circle,
                                            ),
                                            child: Icon(
                                              theme.playerCoverStyle == 'vinyl'
                                                  ? Icons.crop_square_rounded
                                                  : Icons.album_rounded,
                                              color: Colors.white
                                                  .withOpacity(0.92),
                                              size: 16,
                                            ),
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
                ),

                SizedBox(height: 8 * theme.playerSpacingFactor),

                if (_showLyricsView)
                  _buildFullscreenLyricsBottomBar(
                    context: context,
                    song: song,
                    player: player,
                    theme: theme,
                    accent: accent,
                  )
                else ...[
                // Clean Song Title, Artist & Borderless Quick Actions (Share + Favorite)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: theme.textPrimary,
                              fontSize: 21.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.45,
                            ),
                          ),
                          const SizedBox(height: 2),
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              final primaryArtist = song.artist
                                  .split(RegExp(
                                    r'\s*(?:,|&|\bfeat\.?|\bft\.?)\s*',
                                    caseSensitive: false,
                                  ))
                                  .first
                                  .trim();
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ArtistProfileScreen(
                                    artistName: primaryArtist.isNotEmpty
                                        ? primaryArtist
                                        : song.artist,
                                  ),
                                ),
                              );
                            },
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Flexible(
                                  child: Text(
                                    song.artist,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.plusJakartaSans(
                                      color: theme.textSecondary,
                                      fontSize: 14.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: theme.textMuted,
                                  size: 17,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    Tooltip(
                      message: 'Bagikan Lirik / Lagu',
                      child: IosSpringButton(
                        borderRadius: 20,
                        onTap: () => _openShareModal(context, player),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.ios_share_rounded,
                            color: theme.textSecondary,
                            size: 21,
                          ),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Sukai Lagu',
                      child: IosSpringButton(
                        borderRadius: 20,
                        onTap: () => library.toggleFavorite(song),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            isFav
                                ? Icons.favorite_rounded
                                : Icons.favorite_border_rounded,
                            color: isFav
                                ? (theme.isLightCanvas
                                    ? theme.accentText
                                    : accent)
                                : theme.textSecondary,
                            size: 23,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Capsule Progress Scrubber (Expands on touch)
                StreamBuilder<Duration>(
                  stream: player.audioPlayer.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final total = player.audioPlayer.duration ?? song.duration;
                    final maxMs = total.inMilliseconds > 0
                        ? total.inMilliseconds.toDouble()
                        : 1.0;
                    final curMs = _isDraggingSeekSlider && _dragSeekMs != null
                        ? _dragSeekMs!.clamp(0.0, maxMs)
                        : position.inMilliseconds.toDouble().clamp(0.0, maxMs);
                    final progress = (curMs / maxMs).clamp(0.0, 1.0);

                    return Column(
                      children: [
                        LayoutBuilder(
                          builder: (ctx, box) {
                            final barWidth = box.maxWidth;
                            return GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onHorizontalDragStart: (d) {
                                final p = (d.localPosition.dx / barWidth)
                                    .clamp(0.0, 1.0);
                                setState(() {
                                  _isDraggingSeekSlider = true;
                                  _dragSeekMs = p * maxMs;
                                });
                              },
                              onHorizontalDragUpdate: (d) {
                                final p = (d.localPosition.dx / barWidth)
                                    .clamp(0.0, 1.0);
                                setState(() {
                                  _dragSeekMs = p * maxMs;
                                });
                              },
                              onHorizontalDragEnd: (_) {
                                if (_dragSeekMs != null) {
                                  player.seekTo(
                                    Duration(milliseconds: _dragSeekMs!.round()),
                                  );
                                }
                                setState(() {
                                  _isDraggingSeekSlider = false;
                                  _dragSeekMs = null;
                                });
                              },
                              onTapDown: (d) {
                                final p = (d.localPosition.dx / barWidth)
                                    .clamp(0.0, 1.0);
                                player.seekTo(
                                  Duration(milliseconds: (p * maxMs).round()),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 180),
                                  curve: Curves.easeOutCubic,
                                  height: _isDraggingSeekSlider
                                      ? 12.0
                                      : (isBrutal ? 9.0 : 6.0),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: isBrutal
                                        ? theme.cardBgColor
                                        : Colors.white.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(99),
                                    border: isBrutal
                                        ? Border.all(
                                            color: theme.brutalBorderColor,
                                            width: 1.6,
                                          )
                                        : null,
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: progress,
                                      child: Container(
                                        decoration: isBrutal
                                            ? BoxDecoration(
                                                color: accent,
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                              )
                                            : BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                                gradient: LinearGradient(
                                                  colors: [
                                                    accent,
                                                    Colors.white,
                                                  ],
                                                  stops: const [0.7, 1.0],
                                                ),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: accent.withOpacity(
                                                      _isDraggingSeekSlider
                                                          ? 0.65
                                                          : 0.35,
                                                    ),
                                                    blurRadius:
                                                        _isDraggingSeekSlider
                                                            ? 14
                                                            : 8,
                                                  ),
                                                ],
                                              ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(
                                Duration(milliseconds: curMs.round()),
                              ),
                              style: TextStyle(
                                color: _isDraggingSeekSlider
                                    ? theme.textPrimary
                                    : theme.textMuted,
                                fontSize: 11.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _formatDuration(total),
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 11.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 6),

                // Main Transport Controls (Apple Music Ultra-Clean — borderless Shuffle & Repeat)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Tooltip(
                      message: 'Acak Lagu',
                      child: IosSpringButton(
                        borderRadius: 20,
                        onTap: () => player.toggleShuffle(),
                        child: SizedBox(
                          width: 42,
                          height: 42,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.shuffle_rounded,
                                color: player.shuffleEnabled
                                    ? (theme.isLightCanvas
                                        ? theme.accentText
                                        : accent)
                                    : theme.textMuted,
                                size: 21,
                              ),
                              if (player.shuffleEnabled)
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: theme.isLightCanvas
                                        ? theme.accentText
                                        : accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    IosSpringButton(
                      scaleDown: 0.80,
                      borderRadius: 24,
                      onTap: () => player.playPrevious(),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Icon(
                            Icons.skip_previous_rounded,
                            color: theme.textPrimary,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    IosSpringButton(
                      scaleDown: 0.85,
                      borderRadius: 34,
                      onTap: () => player.togglePlayPause(),
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: isBrutal
                            ? BoxDecoration(
                                shape: BoxShape.circle,
                                color: accent,
                                border: Border.all(
                                  color: theme.brutalBorderColor,
                                  width: 2.4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.brutalShadowColor,
                                    blurRadius: 0,
                                    offset: const Offset(3.5, 3.5),
                                  ),
                                ],
                              )
                            : BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withOpacity(0.36),
                                    blurRadius: 24,
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                        alignment: Alignment.center,
                        child: player.isLoadingTrack
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Color(0xFF111111),
                                  strokeWidth: 2.5,
                                ),
                              )
                            : AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                transitionBuilder: (child, anim) =>
                                    ScaleTransition(scale: anim, child: child),
                                child: Icon(
                                  player.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  key: ValueKey<bool>(player.isPlaying),
                                  color: const Color(0xFF111111),
                                  size: 38,
                                ),
                              ),
                      ),
                    ),
                    IosSpringButton(
                      scaleDown: 0.80,
                      borderRadius: 24,
                      onTap: () => player.playNext(),
                      child: SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Icon(
                            Icons.skip_next_rounded,
                            color: theme.textPrimary,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    Tooltip(
                      message: 'Mode Ulang',
                      child: IosSpringButton(
                        borderRadius: 20,
                        onTap: () => player.cycleRepeatMode(),
                        child: SizedBox(
                          width: 42,
                          height: 42,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                player.repeatMode == 2
                                    ? Icons.repeat_one_rounded
                                    : Icons.repeat_rounded,
                                color: player.repeatMode > 0
                                    ? (theme.isLightCanvas
                                        ? theme.accentText
                                        : accent)
                                    : theme.textMuted,
                                size: 21,
                              ),
                              if (player.repeatMode > 0)
                                Container(
                                  margin: const EdgeInsets.only(top: 3),
                                  width: 4,
                                  height: 4,
                                  decoration: BoxDecoration(
                                    color: theme.isLightCanvas
                                        ? theme.accentText
                                        : accent,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Apple Music Minimalist Bottom Floating Icon Bar
                utilityDock,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Whisper-thin bottom playback bar shown in Fullscreen Lyrics mode (85% pure lyrics!)
  Widget _buildFullscreenLyricsBottomBar({
    required BuildContext context,
    required dynamic song,
    required PlayerProvider player,
    required ThemeProvider theme,
    required Color accent,
  }) {
    final lyrics = player.currentLyrics;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StreamBuilder<Duration>(
          stream: player.audioPlayer.positionStream,
          builder: (_, snap) {
            final pos = snap.data ?? player.position;
            final totalMs = player.duration.inMilliseconds;
            final frac =
                totalMs > 0 ? (pos.inMilliseconds / totalMs).clamp(0.0, 1.0) : 0.0;
            return ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: frac,
                minHeight: 3,
                backgroundColor: theme.dividerColor,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              ),
            );
          },
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _showLyricsView = false),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                        imageUrl: song.thumbnailUrl,
                        width: 38,
                        height: 38,
                        memCacheWidth: 96,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            const SizedBox(width: 38, height: 38),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: theme.textPrimary,
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: theme.textSecondary,
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
            ),
            if (lyrics != null && lyrics.shouldShowTranslation) ...[
              IosGlassIconButton(
                icon: Icons.translate_rounded,
                size: 36,
                iconSize: 17,
                activeColor: accent,
                isActive: player.showTranslation,
                tooltip: 'Terjemahan Indonesia',
                onTap: () => player.toggleTranslationDisplay(),
              ),
              const SizedBox(width: 8),
            ],
            IosGlassIconButton(
              icon: Icons.tune_rounded,
              size: 36,
              iconSize: 17,
              activeColor: accent,
              tooltip: 'Pengaturan Lirik',
              onTap: () => _showLyricsSettingsSheet(context, player, theme, accent),
            ),
            const SizedBox(width: 8),
            IosSpringButton(
              onTap: () => player.togglePlayPause(),
              borderRadius: 20,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  player.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: const Color(0xFF111111),
                  size: 24,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showLyricsSettingsSheet(
    BuildContext context,
    PlayerProvider player,
    ThemeProvider theme,
    Color accent,
  ) {
    final lyrics = player.currentLyrics;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer2<PlayerProvider, ThemeProvider>(
        builder: (_, p, t, __) => ZunifySheetContainer(
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: t.dividerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Text(
                  'Pengaturan Lirik',
                  style: GoogleFonts.plusJakartaSans(
                    color: t.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.cloud_done_rounded, color: t.accentText),
                  title: Text(
                    'Sumber Lirik',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    lyrics?.sourceName ?? 'Otomatis',
                    style: TextStyle(color: t.textSecondary, fontSize: 12),
                  ),
                  trailing: Icon(
                    Icons.chevron_right_rounded,
                    color: t.textMuted,
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showLyricsProviderSheet(context, p);
                  },
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  activeColor: accent,
                  title: Text(
                    'Rata Tengah',
                    style: TextStyle(
                      color: t.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  subtitle: Text(
                    'Default rata kiri ala Apple Music',
                    style: TextStyle(color: t.textSecondary, fontSize: 12),
                  ),
                  value: t.lyricsCenterAligned,
                  onChanged: (v) => t.setLyricsCenterAligned(v),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      'Sinkronisasi Waktu',
                      style: TextStyle(
                        color: t.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    const Spacer(),
                    IosGlassPillButton(
                      label: '-0.25s',
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      onTap: () => p.adjustLyricsOffset(-250),
                    ),
                    const SizedBox(width: 6),
                    GestureDetector(
                      onTap: () => p.resetLyricsOffset(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        child: Text(
                          '${(p.lyricsOffsetMs / 1000).toStringAsFixed(2)}s',
                          style: TextStyle(
                            color: t.accentText,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    IosGlassPillButton(
                      label: '+0.25s',
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      onTap: () => p.adjustLyricsOffset(250),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Minimalist Floating Icon Bar ala Apple Music: [ Lirik | Alat | Unduh | Antrean ]
  Widget _buildUtilityDock({
    required BuildContext context,
    required PlayerProvider player,
    required LibraryProvider library,
    required ThemeProvider theme,
    required Color accent,
    required dynamic song,
    required bool isDownloaded,
    required double? downloadProgress,
    required int totalLyricLines,
  }) {
    final hasActiveAudioTool = player.hasCustomSpeedOrPitch ||
        player.eqEnabled ||
        player.hasActiveSleepTimer;
    final isBrutal = theme.isNeoBrutalism;
    final isIpod = theme.isClassicIpod;
    final dividerCol = theme.isLightCanvas
        ? Colors.black.withOpacity(0.10)
        : Colors.white.withOpacity(0.14);

    Widget buildBarIcon({
      required IconData icon,
      required VoidCallback onTap,
      required String tooltip,
      bool isActive = false,
      String? badgeText,
      double? progress,
    }) {
      final activeTint = isIpod
          ? const Color(0xFF2563EB)
          : (theme.isLightCanvas ? theme.accentText : accent);
      final fg = isActive ? activeTint : theme.textSecondary;

      return Tooltip(
        message: tooltip,
        child: IosSpringButton(
          borderRadius: 20,
          onTap: onTap,
          child: SizedBox(
            height: 38,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: isIpod ? 15 : 13),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      if (progress != null)
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            value: progress > 0 ? progress : null,
                            strokeWidth: 2.2,
                            color: activeTint,
                          ),
                        )
                      else
                        Icon(icon, size: 20.5, color: fg),
                      if (isActive && progress == null && badgeText == null)
                        Positioned(
                          right: -3,
                          top: -2,
                          child: Container(
                            width: 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: activeTint,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (badgeText != null) ...[
                    const SizedBox(width: 5),
                    Text(
                      badgeText,
                      style: TextStyle(
                        color: fg,
                        fontSize: 11.2,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        fontFeatures: const [ui.FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    }

    final barContent = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // 0. Lyrics toggle (for Liquid Glass & Neo-Brutalism; iPod uses Center Click Wheel!)
        if (!isIpod) ...[
          buildBarIcon(
            icon: Icons.lyrics_rounded,
            tooltip: 'Lirik Lagu',
            isActive: _showLyricsView,
            onTap: () {
              setState(() {
                _showLyricsView = !_showLyricsView;
                _userScrollingLyrics = false;
                _lastScrolledLyricIdx = -99;
              });
              if (_showLyricsView) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  _scrollToActiveLyric(
                    song.videoId,
                    player.activeLyricIndex,
                    totalLyricLines,
                    force: true,
                  );
                });
              }
            },
          ),
          Container(width: 0.8, height: 16, color: dividerCol),
        ],
        // 1. Audio Tools (EQ, Tempo & Pitch, Sleep Timer)
        buildBarIcon(
          icon: Icons.tune_rounded,
          tooltip: 'Alat Audio',
          isActive: hasActiveAudioTool,
          badgeText: player.hasActiveSleepTimer
              ? player.formattedRemainingSleepTime
              : null,
          onTap: () => _showAudioToolsSheet(
            context: context,
            player: player,
            library: library,
            theme: theme,
            accent: accent,
            song: song,
          ),
        ),
        Container(width: 0.8, height: 16, color: dividerCol),
        // 2. Direct One-Tap Offline Download
        buildBarIcon(
          icon: isDownloaded
              ? Icons.download_done_rounded
              : Icons.arrow_downward_rounded,
          tooltip: isDownloaded ? 'Tersimpan Offline' : 'Unduh Offline',
          isActive: isDownloaded || downloadProgress != null,
          progress: downloadProgress,
          onTap: () {
            if (!isDownloaded && downloadProgress == null) {
              HapticFeedback.lightImpact();
              library.downloadSong(song, highQuality: true);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  duration: const Duration(seconds: 1),
                  backgroundColor: accent,
                  content: const Text(
                    'Mengunduh lagu untuk offline...',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              );
            }
          },
        ),
        Container(width: 0.8, height: 16, color: dividerCol),
        // 3. Playback Queue
        buildBarIcon(
          icon: Icons.queue_music_rounded,
          tooltip: 'Antrean',
          badgeText: player.upcomingCount > 0 ? '${player.upcomingCount}' : null,
          onTap: () => _showQueueBottomSheet(context, player),
        ),
      ],
    );

    return Center(
      child: isIpod
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: theme.isLightCanvas
                    ? Colors.white.withOpacity(0.72)
                    : const Color(0xFF1C1F28).withOpacity(0.90),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: theme.isLightCanvas
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF333846),
                  width: 1.0,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(
                      theme.isLightCanvas ? 0.08 : 0.35,
                    ),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: barContent,
            )
          : LiquidGlassBox(
              borderRadius: isBrutal ? 14 : 24,
              tintOpacity: isBrutal ? 0.0 : 0.10,
              rimIntensity: 0.42,
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              child: barContent,
            ),
    );
  }

  void _showAudioToolsSheet({
    required BuildContext context,
    required PlayerProvider player,
    required LibraryProvider library,
    required ThemeProvider theme,
    required Color accent,
    required dynamic song,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Consumer2<PlayerProvider, LibraryProvider>(
        builder: (_, p, lib, __) {
          final isDl = lib.isDownloaded(song.videoId);
          final dlProg = lib.activeDownloadProgress[song.videoId];
          final divider = Divider(
            height: 1,
            thickness: 0.6,
            indent: 52,
            color: theme.dividerColor,
          );
          return ZunifySheetContainer(
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 36,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 14),
                      decoration: BoxDecoration(
                        color: theme.dividerColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      'Alat Audio',
                      style: GoogleFonts.plusJakartaSans(
                        color: theme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  LiquidGlassBox(
                    borderRadius: theme.isNeoBrutalism ? 14 : 20,
                    tintOpacity: theme.isNeoBrutalism ? 0.0 : 0.06,
                    rimIntensity: 0.34,
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _toolRow(
                          icon: Icons.speed_rounded,
                          title: 'Tempo & Pitch',
                          status: p.hasCustomSpeedOrPitch
                              ? p.speedPitchModeLabel
                              : '1.0x',
                          active: p.hasCustomSpeedOrPitch,
                          theme: theme,
                          accent: accent,
                          onTap: () {
                            Navigator.pop(ctx);
                            _showSpeedPitchStudioSheet(context, p);
                          },
                        ),
                        divider,
                        _toolRow(
                          icon: Icons.equalizer_rounded,
                          title: 'Equalizer DSP',
                          status: p.eqEnabled ? p.selectedEqPresetName : 'Mati',
                          active: p.eqEnabled,
                          theme: theme,
                          accent: accent,
                          onTap: () {
                            Navigator.pop(ctx);
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const EqualizerSheet(),
                            );
                          },
                        ),
                        divider,
                        _toolRow(
                          icon: Icons.bedtime_outlined,
                          title: 'Sleep Timer',
                          status: p.hasActiveSleepTimer
                              ? p.formattedRemainingSleepTime
                              : 'Mati',
                          active: p.hasActiveSleepTimer,
                          theme: theme,
                          accent: accent,
                          onTap: () {
                            Navigator.pop(ctx);
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const SleepTimerSheet(),
                            );
                          },
                        ),
                        divider,
                        // Inline Crossfade Halus Selector (Mati | 3d | 5d | 8d)
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: p.crossfadeSeconds > 0
                                      ? (theme.isClassicIpod
                                              ? const Color(0xFF2563EB)
                                              : (theme.isLightCanvas
                                                  ? theme.accentText
                                                  : accent))
                                          .withOpacity(0.16)
                                      : theme.subtleFill,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.graphic_eq_rounded,
                                  color: p.crossfadeSeconds > 0
                                      ? (theme.isClassicIpod
                                          ? const Color(0xFF2563EB)
                                          : (theme.isLightCanvas
                                              ? theme.accentText
                                              : accent))
                                      : theme.textSecondary,
                                  size: 17.5,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Crossfade',
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 13.8,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  for (final opt in const [
                                    (0, 'Mati'),
                                    (3, '3d'),
                                    (5, '5d'),
                                    (8, '8d'),
                                  ])
                                    Padding(
                                      padding: const EdgeInsets.only(left: 5),
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.selectionClick();
                                          p.setCrossfadeSeconds(opt.$1);
                                        },
                                        child: AnimatedContainer(
                                          duration: const Duration(
                                            milliseconds: 160,
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 9,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: p.crossfadeSeconds == opt.$1 ||
                                                    (opt.$1 == 3 &&
                                                        p.crossfadeSeconds == 4)
                                                ? accent
                                                : theme.subtleFill,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: theme.isNeoBrutalism &&
                                                    (p.crossfadeSeconds ==
                                                            opt.$1 ||
                                                        (opt.$1 == 3 &&
                                                            p.crossfadeSeconds ==
                                                                4))
                                                ? Border.all(
                                                    color:
                                                        theme.brutalBorderColor,
                                                    width: 1.4,
                                                  )
                                                : null,
                                          ),
                                          child: Text(
                                            opt.$2,
                                            style: TextStyle(
                                              color: p.crossfadeSeconds ==
                                                          opt.$1 ||
                                                      (opt.$1 == 3 &&
                                                          p.crossfadeSeconds ==
                                                              4)
                                                  ? const Color(0xFF111111)
                                                  : theme.textSecondary,
                                              fontSize: 11.2,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        divider,
                        _toolRow(
                          icon: isDl
                              ? Icons.download_done_rounded
                              : Icons.arrow_downward_rounded,
                          title: isDl ? 'Tersimpan Offline' : 'Unduh Offline',
                          status: dlProg != null
                              ? '${(dlProg * 100).toStringAsFixed(0)}%'
                              : (isDl ? 'Aktif' : 'Simpan'),
                          active: isDl || dlProg != null,
                          theme: theme,
                          accent: accent,
                          onTap: () {
                            if (!isDl && dlProg == null) {
                              lib.downloadSong(song, highQuality: true);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _toolRow({
    required IconData icon,
    required String title,
    required String status,
    required bool active,
    required ThemeProvider theme,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final activeTint = theme.isClassicIpod
        ? const Color(0xFF2563EB)
        : (theme.isLightCanvas ? theme.accentText : accent);

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: active
                    ? activeTint.withOpacity(0.16)
                    : theme.subtleFill,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: active ? activeTint : theme.textSecondary,
                size: 17.5,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 13.8,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              status,
              style: TextStyle(
                color: active ? activeTint : theme.textMuted,
                fontSize: 12.2,
                fontWeight: active ? FontWeight.w800 : FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.textMuted.withOpacity(0.65),
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  /// Full-Screen Synced Lyrics View (Liquid Glass & Neo-Brutalism)
  Widget _buildBitChordLyricsView(
    String videoId,
    PlayerProvider player,
    ThemeProvider theme,
    Color accent,
  ) {
    final isBrutal = theme.isNeoBrutalism;
    final SyncedLyrics? lyrics = player.currentLyrics;
    if (player.isLoadingLyrics) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: theme.accentText),
            const SizedBox(height: 12),
            Text(
              'Memuat lirik lagu...',
              style: TextStyle(color: theme.textSecondary, fontSize: 13.5),
            ),
          ],
        ),
      );
    }
    if (lyrics == null || lyrics.lines.isEmpty) {
      return Center(
        child: Text(
          '♪ Instrumental / Lirik belum tersedia ♪',
          style: TextStyle(color: theme.textMuted, fontSize: 15),
        ),
      );
    }

    return Column(
      key: const ValueKey('bitchord_lyrics_view'),
      children: [
        // Zero clutter above lyrics! Controls moved cleanly to bottom bar & iPod status bar.

        // Synced Lyrics Viewport (Zero horizontal overflow + Spotify/Apple Music 2-Side Duet Support!)
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _lyricsViewportHeight = constraints.maxHeight;
              final double viewportW = constraints.maxWidth;
              final bool isDuetSong =
                  lyrics.hasMultipleSingers && !theme.lyricsCenterAligned;
              const double topSafePad = 56.0;
              final double bottomSafePad =
                  (constraints.maxHeight * 0.56).clamp(140.0, 260.0);
              final activeIdx = player.activeLyricIndex < 0
                  ? 0
                  : player.activeLyricIndex.clamp(0, lyrics.lines.length - 1);

              final Widget lyricsScroll =
                  NotificationListener<UserScrollNotification>(
                    onNotification: (n) {
                      _onUserScrollNotification(n);
                      return false;
                    },
                    child: SingleChildScrollView(
                      controller: _lyricsScrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: EdgeInsets.only(
                        top: topSafePad,
                        bottom: bottomSafePad,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: List.generate(lyrics.lines.length, (index) {
                            final line = lyrics.lines[index];
                            final isActive = index == activeIdx;
                            final isPassed = index < activeIdx;
                            final distance = (index - activeIdx).abs();

                            final double itemOpacity = isActive
                                ? 1.0
                                : (distance == 1
                                    ? 0.50
                                    : (distance == 2
                                        ? 0.28
                                        : (isPassed ? 0.16 : 0.20)));

                            final isInterlude = line.originalText.isEmpty ||
                                line.originalText.contains('•');
                            final nextTimestamp =
                                index + 1 < lyrics.lines.length
                                    ? lyrics.lines[index + 1].timestamp
                                    : player.duration;

                            // Spotify/Apple Music 2-side alignment when duet singers alternate (v1 left, v2 right, group center)
                            final bool isRightSinger =
                                isDuetSong && line.vocalAgent == 'v2';
                            final bool isCenterLine = theme.lyricsCenterAligned ||
                                (isDuetSong && line.vocalAgent == 'group');

                            final Alignment scaleAnchor = isCenterLine
                                ? Alignment.center
                                : (isRightSinger
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft);

                            final double safeViewportW =
                                math.max(80.0, viewportW);
                            final double minLineW =
                                math.min(180.0, safeViewportW);
                            final double maxLineWidth = isDuetSong && !isCenterLine
                                ? (safeViewportW - 24)
                                        .clamp(minLineW, safeViewportW) *
                                    0.86
                                : (safeViewportW - 20)
                                    .clamp(minLineW, safeViewportW);

                            final Widget lineBody = isInterlude
                                ? _buildInterludeIndicator(
                                    isActive: isActive,
                                    inactiveOpacity: itemOpacity,
                                    theme: theme,
                                    accent: accent,
                                    centerAligned: isCenterLine,
                                    rightAligned: isRightSinger,
                                    lineTimestamp: line.timestamp,
                                    nextTimestamp: nextTimestamp,
                                  )
                                : _buildBitChordLyricContent(
                                    isActive: isActive,
                                    inactiveOpacity: itemOpacity,
                                    line: line,
                                    translatedText: (player.showTranslation &&
                                            lyrics.shouldShowTranslation)
                                        ? line.translatedIndoText
                                        : null,
                                    theme: theme,
                                    accent: accent,
                                    centerAligned: isCenterLine,
                                    rightAligned: isRightSinger,
                                    maxWidth: maxLineWidth,
                                    fontScale: theme.lyricsFontScale,
                                    nextTimestamp: nextTimestamp,
                                  );

                            // CRITICAL: Active scale is 1.00 (NEVER > 1.0!) so text NEVER clips past screen edges!
                            Widget lyricContentWidget = Align(
                              alignment: scaleAnchor,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(maxWidth: maxLineWidth),
                                child: AnimatedScale(
                                  scale: isActive
                                      ? 1.00
                                      : (distance == 1 ? 0.94 : 0.90),
                                  alignment: scaleAnchor,
                                  duration: theme.animDuration(260),
                                  curve: Curves.easeOutCubic,
                                  child: lineBody,
                                ),
                              ),
                            );

                            // Gentle Apple Music depth blur ONLY on far inactive lines
                            if (!isActive && distance >= 2) {
                              lyricContentWidget = ImageFiltered(
                                imageFilter: ui.ImageFilter.blur(
                                  sigmaX: distance >= 3 ? 2.1 : 1.15,
                                  sigmaY: distance >= 3 ? 2.1 : 1.15,
                                ),
                                child: lyricContentWidget,
                              );
                            }

                            return _MeasuredLyricItem(
                              index: index,
                              onHeightMeasured: (idx, h) {
                                final prev = _lineHeights[idx];
                                if (prev == null || (prev - h).abs() > 1.0) {
                                  _lineHeights[idx] = h;
                                }
                              },
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() => _userScrollingLyrics = false);
                                  player.seekTo(line.timestamp);
                                },
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 13,
                                    horizontal: 10,
                                  ),
                                  child: lyricContentWidget,
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    );

              final Color paperBg = theme.scaffoldBgColor;

              return Stack(
                children: [
                  if (isBrutal)
                    lyricsScroll
                  else
                    ShaderMask(
                      shaderCallback: (rect) => const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.white,
                          Colors.white,
                          Colors.transparent,
                        ],
                        stops: [0.0, 0.06, 0.88, 1.0],
                      ).createShader(rect),
                      blendMode: BlendMode.dstIn,
                      child: lyricsScroll,
                    ),

                  if (isBrutal) ...[
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 30,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [paperBg, paperBg.withOpacity(0.0)],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      height: 52,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: [paperBg, paperBg.withOpacity(0.0)],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],

                  // "Ikuti Lirik" button when user scrolls manually
                  if (_userScrollingLyrics)
                    Positioned(
                      right: 8,
                      bottom: 12,
                      child: IosGlassPillButton(
                        icon: Icons.my_location_rounded,
                        label: 'Ikuti Lirik',
                        height: 34,
                        activeColor: accent,
                        isActive: true,
                        onTap: () {
                          _resumeAutoScrollTimer?.cancel();
                          setState(() {
                            _userScrollingLyrics = false;
                            _lastScrolledLyricIdx = -99;
                          });
                          _scrollToActiveLyric(
                            videoId,
                            player.activeLyricIndex,
                            lyrics.lines.length,
                            force: true,
                          );
                        },
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }

  /// "Sumber Lirik" Bottom Sheet
  void _showLyricsProviderSheet(
    BuildContext context,
    PlayerProvider player,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer<PlayerProvider>(
          builder: (context, livePlayer, _) {
            final theme = context.watch<ThemeProvider>();
            final accent = theme.accentColor;
            final isBrutal = theme.isNeoBrutalism;
            final options = livePlayer.availableLyricsProviders;
            final currentSource =
                livePlayer.currentLyrics?.sourceName ?? 'Otomatis';

            return ZunifySheetContainer(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.lyrics_rounded,
                          color: theme.accentText,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Sumber Lirik',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (options.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Hanya 1 sumber lirik tersedia.',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 13,
                          ),
                        ),
                      )
                    else
                      ...options.map((opt) {
                        final isSelected = opt.sourceName == currentSource;
                        final hasWordSync =
                            opt.lines.any((l) => l.words.length > 1);
                        return IosSpringButton(
                          onTap: () {
                            livePlayer.selectLyricsProvider(opt);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 11,
                            ),
                            decoration: isBrutal
                                ? BoxDecoration(
                                    color: isSelected
                                        ? accent
                                        : theme.cardBgColor,
                                    borderRadius: BorderRadius.circular(11),
                                    border: Border.all(
                                      color: theme.brutalBorderColor,
                                      width: 2.0,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: theme.brutalShadowColor,
                                        blurRadius: 0,
                                        offset: const Offset(2.5, 2.5),
                                      ),
                                    ],
                                  )
                                : BoxDecoration(
                                    color: isSelected
                                        ? accent.withOpacity(0.16)
                                        : Colors.white.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? accent.withOpacity(0.55)
                                          : Colors.white.withOpacity(0.09),
                                    ),
                                  ),
                            child: Row(
                              children: [
                                Icon(
                                  hasWordSync
                                      ? Icons.auto_awesome_rounded
                                      : Icons.subtitles_rounded,
                                  color: isSelected
                                      ? (isBrutal
                                          ? const Color(0xFF111111)
                                          : accent)
                                      : theme.textSecondary,
                                  size: 18,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    '${opt.sourceName} (${opt.lines.length} baris)',
                                    style: TextStyle(
                                      color: isSelected && isBrutal
                                          ? const Color(0xFF111111)
                                          : theme.textPrimary,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: isBrutal
                                        ? const Color(0xFF111111)
                                        : accent,
                                    size: 19,
                                  ),
                              ],
                            ),
                          ),
                        );
                      }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildBitChordLyricContent({
    required bool isActive,
    required double inactiveOpacity,
    required LyricLine line,
    required String? translatedText,
    required ThemeProvider theme,
    required Color accent,
    required bool centerAligned,
    required bool rightAligned,
    required double maxWidth,
    required double fontScale,
    required Duration nextTimestamp,
  }) {
    final words = line.words;
    final fgColor = theme.textPrimary;
    final unsungColor = fgColor.withOpacity(theme.isLightCanvas ? 0.28 : 0.34);

    final baseStyle = GoogleFonts.plusJakartaSans(
      color: fgColor,
      fontSize: 26.0 * fontScale,
      fontWeight: FontWeight.w800,
      height: 1.24,
      letterSpacing: -0.60,
    );

    final crossAlign = centerAligned
        ? CrossAxisAlignment.center
        : (rightAligned ? CrossAxisAlignment.end : CrossAxisAlignment.start);
    final wrapAlign = centerAligned
        ? WrapAlignment.center
        : (rightAligned ? WrapAlignment.end : WrapAlignment.start);
    final textAlign = centerAligned
        ? TextAlign.center
        : (rightAligned ? TextAlign.right : TextAlign.left);

    final hasBg =
        line.backgroundText != null && line.backgroundText!.trim().isNotEmpty;

    Widget buildWordSafeText(String txt, TextStyle style) {
      return ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Text(
          txt,
          style: style,
          softWrap: true,
        ),
      );
    }

    if (!isActive) {
      final dimmedStyle = baseStyle.copyWith(
        color: fgColor.withOpacity(inactiveOpacity.clamp(0.14, 1.0)),
      );
      return AnimatedDefaultTextStyle(
        duration: theme.animDuration(220),
        curve: Curves.easeOutCubic,
        style: dimmedStyle,
        child: Column(
          crossAxisAlignment: crossAlign,
          children: [
            Text(
              line.originalText,
              textAlign: textAlign,
              softWrap: true,
            ),
            if (hasBg) ...[
              const SizedBox(height: 3),
              Text(
                '(${line.backgroundText!})',
                textAlign: textAlign,
                softWrap: true,
                style: GoogleFonts.plusJakartaSans(
                  color: fgColor.withOpacity(
                    (inactiveOpacity * 0.72).clamp(0.10, 0.45),
                  ),
                  fontSize: 16.0 * fontScale,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
            ],
            if (translatedText != null && translatedText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                translatedText,
                textAlign: textAlign,
                softWrap: true,
                style: GoogleFonts.plusJakartaSans(
                  color: theme.textSecondary.withOpacity(
                    (inactiveOpacity * 0.92).clamp(0.14, 0.62),
                  ),
                  fontSize: 14.0 * fontScale,
                  fontWeight: FontWeight.w500,
                  height: 1.3,
                ),
              ),
            ],
          ],
        ),
      );
    }

    return ValueListenableBuilder<int>(
      valueListenable: _smoothPosMs,
      builder: (context, curMs, _) {
        return Column(
          crossAxisAlignment: crossAlign,
          children: [
            if (words.isNotEmpty)
              Wrap(
                alignment: wrapAlign,
                spacing: 5.5,
                runSpacing: 4,
                children: words.map((w) {
                  final span = (w.endMs - w.startMs).clamp(60, 15000);
                  final wProg = ((curMs - w.startMs) / span).clamp(0.0, 1.0);
                  final liftDy =
                      (wProg > 0.02 && wProg < 0.98) ? -1.4 * math.sin(wProg * math.pi) : 0.0;

                  final activeWordStyle = baseStyle.copyWith(
                    shadows: (!theme.isLightCanvas && wProg > 0.05)
                        ? [
                            Shadow(
                              color: accent.withOpacity(0.56 * wProg),
                              blurRadius: 15,
                            ),
                          ]
                        : null,
                  );

                  Widget wordWidget;
                  if (wProg >= 0.99) {
                    wordWidget = buildWordSafeText(w.text, activeWordStyle);
                  } else if (wProg <= 0.01) {
                    wordWidget = buildWordSafeText(
                      w.text,
                      baseStyle.copyWith(color: unsungColor),
                    );
                  } else {
                    wordWidget = ShaderMask(
                      shaderCallback: (rect) => LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors: [fgColor, unsungColor],
                        stops: [
                          wProg.clamp(0.0, 1.0),
                          (wProg + 0.20).clamp(0.0, 1.0),
                        ],
                      ).createShader(rect),
                      blendMode: BlendMode.srcIn,
                      child: buildWordSafeText(w.text, activeWordStyle),
                    );
                  }

                  if (liftDy == 0.0) return wordWidget;
                  return Transform.translate(
                    offset: Offset(0, liftDy),
                    child: wordWidget,
                  );
                }).toList(),
              )
            else
              Text(
                line.originalText,
                textAlign: textAlign,
                softWrap: true,
                style: baseStyle.copyWith(
                  shadows: !theme.isLightCanvas
                      ? [
                          Shadow(
                            color: accent.withOpacity(0.45),
                            blurRadius: 14,
                          ),
                        ]
                      : null,
                ),
              ),

            // Separated Background / Filler Vocal Ad-Lib (Apple Music Style)
            if (hasBg) ...[
              const SizedBox(height: 5),
              Text(
                '(${line.backgroundText!})',
                textAlign: textAlign,
                softWrap: true,
                style: GoogleFonts.plusJakartaSans(
                  color: theme.textSecondary.withOpacity(0.78),
                  fontSize: 16.5 * fontScale,
                  fontWeight: FontWeight.w700,
                  height: 1.24,
                  letterSpacing: -0.25,
                ),
              ),
            ],

            if (translatedText != null && translatedText.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                translatedText,
                textAlign: textAlign,
                softWrap: true,
                style: GoogleFonts.plusJakartaSans(
                  color: theme.isLightCanvas
                      ? const Color(0xFF4B5563)
                      : Colors.white.withOpacity(0.74),
                  fontSize: 14.8 * fontScale,
                  fontWeight: FontWeight.w600,
                  height: 1.32,
                  letterSpacing: -0.15,
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  /// 3 Animated Instrumental Dots (`•  •  •`)
  Widget _buildInterludeIndicator({
    required bool isActive,
    required double inactiveOpacity,
    required ThemeProvider theme,
    required Color accent,
    required bool centerAligned,
    bool rightAligned = false,
    required Duration lineTimestamp,
    required Duration nextTimestamp,
  }) {
    final fgColor = theme.textPrimary;
    final rowAlign = centerAligned
        ? MainAxisAlignment.center
        : (rightAligned ? MainAxisAlignment.end : MainAxisAlignment.start);
    if (!isActive) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment: rowAlign,
          mainAxisSize:
              (centerAligned || rightAligned) ? MainAxisSize.max : MainAxisSize.min,
          children: List.generate(3, (i) {
            return Container(
              margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fgColor.withOpacity(
                  (0.45 * inactiveOpacity).clamp(0.10, 0.35),
                ),
              ),
            );
          }),
        ),
      );
    }

    final startMs = lineTimestamp.inMilliseconds;
    final endMs = nextTimestamp.inMilliseconds > startMs
        ? nextTimestamp.inMilliseconds
        : startMs + 6000;
    final spanMs = (endMs - startMs).clamp(500, 600000);

    return ValueListenableBuilder<int>(
      valueListenable: _smoothPosMs,
      builder: (context, curMs, _) {
        final progress = ((curMs - startMs) / spanMs).clamp(0.0, 1.0);
        final phase = curMs / 240.0;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            mainAxisAlignment: rowAlign,
            mainAxisSize:
                (centerAligned || rightAligned) ? MainAxisSize.max : MainAxisSize.min,
            children: List.generate(3, (i) {
              final segStart = i / 3.0;
              final dotFill = ((progress - segStart) * 3.0).clamp(0.0, 1.0);
              final wave = math.sin(phase - (i * 0.95));
              final dy = -3.2 * ((wave + 1.0) * 0.5);
              final scale = 0.88 + 0.24 * ((wave + 1.0) * 0.5);

              return Transform.translate(
                offset: Offset(0, dy),
                child: Transform.scale(
                  scale: scale,
                  child: Container(
                    margin: EdgeInsets.only(right: i < 2 ? 12 : 0),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(
                        fgColor.withOpacity(0.30),
                        fgColor,
                        dotFill,
                      ),
                      boxShadow: (!theme.isLightCanvas && dotFill > 0.2)
                          ? [
                              BoxShadow(
                                color: accent.withOpacity(0.65 * dotFill),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : null,
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  /// Modern 3D Floating Album Cover (Liquid Glass & Neo-Brutalism)
  Widget _buildModern3DAlbumArtwork({
    required String imageUrl,
    required bool isPlaying,
    required Color accent,
    required Color ambient,
    required ThemeProvider theme,
    required double size,
  }) {
    final isBrutal = theme.isNeoBrutalism;
    final artRadius = isBrutal ? 18.0 : 28.0;

    return AnimatedScale(
      scale: isPlaying ? 1.0 : 0.90,
      duration: theme.animDuration(360),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: theme.animDuration(360),
        width: size,
        height: size,
        decoration: isBrutal
            ? BoxDecoration(
                color: theme.cardBgColor,
                borderRadius: BorderRadius.circular(artRadius),
                border: Border.all(
                  color: theme.brutalBorderColor,
                  width: 2.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: theme.brutalShadowColor,
                    blurRadius: 0,
                    offset: Offset(isPlaying ? 6.5 : 4.5, isPlaying ? 6.5 : 4.5),
                  ),
                ],
              )
            : BoxDecoration(
                borderRadius: BorderRadius.circular(artRadius),
                boxShadow: [
                  BoxShadow(
                    color: ambient.withOpacity(isPlaying ? 0.58 : 0.24),
                    blurRadius: isPlaying ? 42 : 20,
                    spreadRadius: isPlaying ? 4 : 0,
                    offset: Offset(0, isPlaying ? 16 : 8),
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.58),
                    blurRadius: 26,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
        child: ClipRRect(
          borderRadius:
              BorderRadius.circular(isBrutal ? artRadius - 2.8 : artRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl,
                memCacheWidth: 720,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 180),
                errorWidget: (_, __, ___) => Container(
                  color: theme.subtleFill,
                  child: Icon(
                    Icons.music_note_rounded,
                    color: theme.accentText,
                    size: size * 0.36,
                  ),
                ),
              ),
              if (!isBrutal)
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(artRadius),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.20),
                        width: 1.15,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Minimalist Tempo & Pitch Bottom Sheet
  void _showSpeedPitchStudioSheet(
    BuildContext context,
    PlayerProvider player,
  ) {
    final presets = <Map<String, dynamic>>[
      {'label': 'Normal', 'speed': 1.0, 'pitch': 1.0},
      {'label': 'Slowed', 'speed': 0.86, 'pitch': 0.88},
      {'label': 'Daycore', 'speed': 0.92, 'pitch': 0.92},
      {'label': 'Sped Up', 'speed': 1.12, 'pitch': 1.08},
      {'label': 'Nightcore', 'speed': 1.20, 'pitch': 1.20},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Consumer<PlayerProvider>(
          builder: (context, livePlayer, _) {
            final theme = context.watch<ThemeProvider>();
            final accent = theme.accentColor;

            return ZunifySheetContainer(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.dividerColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.speed_rounded,
                              color: theme.accentText,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Tempo & Nada',
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        if (livePlayer.hasCustomSpeedOrPitch)
                          IosGlassPillButton(
                            label: 'Reset',
                            height: 28,
                            padding: const EdgeInsets.symmetric(horizontal: 11),
                            activeColor: accent,
                            isActive: true,
                            fontSize: 11,
                            onTap: () => livePlayer.resetSpeedPitch(),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        children: presets.map((p) {
                          final sp = p['speed'] as double;
                          final pt = p['pitch'] as double;
                          final isSelected =
                              (livePlayer.playbackSpeed - sp).abs() < 0.02 &&
                                  (livePlayer.playbackPitch - pt).abs() < 0.02;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: IosGlassPillButton(
                              label: p['label'] as String,
                              height: 33,
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 13),
                              activeColor: accent,
                              isActive: isSelected,
                              fontSize: 12,
                              onTap: () =>
                                  livePlayer.setSpeedPitchPreset(sp, pt),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Kecepatan',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${livePlayer.playbackSpeed.toStringAsFixed(2)}x',
                          style: TextStyle(
                            color: theme.accentText,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4.0,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7.0,
                        ),
                      ),
                      child: Slider(
                        value: livePlayer.playbackSpeed.clamp(0.70, 1.35),
                        min: 0.70,
                        max: 1.35,
                        activeColor: theme.accentText,
                        inactiveColor: theme.dividerColor,
                        onChanged: (v) => livePlayer.setPlaybackSpeed(v),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Nada',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${livePlayer.playbackPitch.toStringAsFixed(2)}x',
                          style: TextStyle(
                            color: theme.accentText,
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    SliderTheme(
                      data: SliderTheme.of(context).copyWith(
                        trackHeight: 4.0,
                        thumbShape: const RoundSliderThumbShape(
                          enabledThumbRadius: 7.0,
                        ),
                      ),
                      child: Slider(
                        value: livePlayer.playbackPitch.clamp(0.70, 1.35),
                        min: 0.70,
                        max: 1.35,
                        activeColor: theme.accentText,
                        inactiveColor: theme.dividerColor,
                        onChanged: (v) => livePlayer.setPlaybackPitch(v),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showQueueBottomSheet(
    BuildContext context,
    PlayerProvider player,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (ctx, scrollCtrl) {
            return Consumer<PlayerProvider>(
              builder: (context, livePlayer, _) {
                final theme = context.watch<ThemeProvider>();
                final accent = theme.accentColor;
                final isBrutal = theme.isNeoBrutalism;
                final currentSong = livePlayer.currentSong;
                final curIdx = livePlayer.currentIndex;
                final total = livePlayer.queue.length;
                final upcomingCount = (total - curIdx - 1).clamp(0, total);

                return ZunifySheetContainer(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: theme.dividerColor,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Antrean Pemutaran',
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 18.5,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  livePlayer.contextName.isNotEmpty
                                      ? 'Dari: ${livePlayer.contextName}'
                                      : 'Geser ikon garis untuk ubah urutan',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.textMuted,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IosGlassPillButton(
                            icon: Icons.shuffle_rounded,
                            label: 'Acak Antrean',
                            height: 32,
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            activeColor: accent,
                            isActive: livePlayer.shuffleEnabled,
                            fontSize: 11.5,
                            onTap: () => livePlayer.toggleShuffle(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (currentSong != null) ...[
                        Text(
                          'SEDANG DIPUTAR',
                          style: TextStyle(
                            color: theme.accentText,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        LiquidGlassBox(
                          borderRadius: 16,
                          padding: const EdgeInsets.all(10),
                          tintColor: accent,
                          tintOpacity: 0.16,
                          rimIntensity: 0.42,
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: currentSong.highResArtUrl,
                                  width: 44,
                                  height: 44,
                                  memCacheWidth: 132,
                                  fadeInDuration:
                                      const Duration(milliseconds: 120),
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      currentSong.title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: theme.textPrimary,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      currentSong.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: theme.textSecondary,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              MiniAudioSpectrumBars(
                                isPlaying: livePlayer.isPlaying,
                                color: theme.accentText,
                                height: 14,
                              ),
                              const SizedBox(width: 6),
                            ],
                          ),
                        ),
                        const SizedBox(height: 10),
                      ],
                      Expanded(
                        child: upcomingCount == 0
                            ? Center(
                                child: Text(
                                  livePlayer.isFetchingAutoplay
                                      ? 'Menyiapkan rekomendasi lagu serupa...'
                                      : 'Antrean berikutnya kosong.',
                                  style: TextStyle(color: theme.textMuted),
                                ),
                              )
                            : ReorderableListView.builder(
                                scrollController: scrollCtrl,
                                buildDefaultDragHandles: false,
                                proxyDecorator: (child, index, animation) {
                                  return Material(
                                    color: theme.cardBgColor,
                                    borderRadius: BorderRadius.circular(14),
                                    elevation: 8,
                                    child: child,
                                  );
                                },
                                itemCount: upcomingCount,
                                onReorder: (oldRel, newRel) {
                                  final base = curIdx + 1;
                                  livePlayer.reorderQueue(
                                    base + oldRel,
                                    base + newRel,
                                  );
                                },
                                itemBuilder: (ctx, relIdx) {
                                  final qIdx = curIdx + 1 + relIdx;
                                  final item = livePlayer.queue[qIdx];
                                  final source = livePlayer.sourceAt(qIdx);
                                  final prevSource = relIdx > 0
                                      ? livePlayer.sourceAt(qIdx - 1)
                                      : null;
                                  final showSectionHeader =
                                      relIdx == 0 || source != prevSource;

                                  String? sectionTitle;
                                  if (showSectionHeader) {
                                    switch (source) {
                                      case QueueSource.user:
                                        sectionTitle = 'BERIKUTNYA DI ANTREAN';
                                        break;
                                      case QueueSource.context:
                                        sectionTitle = livePlayer
                                                .contextName.isNotEmpty
                                            ? 'DARI: ${livePlayer.contextName.toUpperCase()}'
                                            : 'DAFTAR PUTAR';
                                        break;
                                      case QueueSource.autoplay:
                                        sectionTitle =
                                            'REKOMENDASI SESUAI GENRE & MOOD';
                                        break;
                                    }
                                  }

                                  return Column(
                                    key: ValueKey(
                                      'upcoming_${qIdx}_${item.videoId}',
                                    ),
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (sectionTitle != null)
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            top: 10,
                                            bottom: 6,
                                            left: 4,
                                            right: 4,
                                          ),
                                          child: Text(
                                            sectionTitle,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: source == QueueSource.user
                                                  ? theme.accentText
                                                  : theme.textMuted,
                                              fontSize: 10.5,
                                              fontWeight: FontWeight.w800,
                                              letterSpacing: 0.7,
                                            ),
                                          ),
                                        ),
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 3,
                                        ),
                                        decoration: isBrutal
                                            ? BoxDecoration(
                                                color: theme.cardBgColor,
                                                borderRadius:
                                                    BorderRadius.circular(11),
                                                border: Border.all(
                                                  color:
                                                      theme.brutalBorderColor,
                                                  width: 1.8,
                                                ),
                                              )
                                            : BoxDecoration(
                                                color: theme.subtleFill,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                        child: ListTile(
                                          dense: true,
                                          contentPadding:
                                              const EdgeInsets.only(
                                            left: 10,
                                            right: 4,
                                          ),
                                          leading: ClipRRect(
                                            borderRadius:
                                                BorderRadius.circular(8),
                                            child: CachedNetworkImage(
                                              imageUrl: item.thumbnailUrl,
                                              width: 40,
                                              height: 40,
                                              memCacheWidth: 120,
                                              fadeInDuration: const Duration(
                                                milliseconds: 120,
                                              ),
                                              fit: BoxFit.cover,
                                            ),
                                          ),
                                          title: Text(
                                            item.title,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: theme.textPrimary,
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          subtitle: Text(
                                            item.artist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: theme.textSecondary,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                icon: Icon(
                                                  Icons.close_rounded,
                                                  color: theme.textMuted,
                                                  size: 18,
                                                ),
                                                onPressed: () => livePlayer
                                                    .removeFromQueue(qIdx),
                                              ),
                                              ReorderableDragStartListener(
                                                index: relIdx,
                                                child: Padding(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                    horizontal: 8,
                                                    vertical: 8,
                                                  ),
                                                  child: Icon(
                                                    Icons.drag_handle_rounded,
                                                    color: theme.textMuted,
                                                    size: 20,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                          onTap: () => livePlayer
                                              .jumpToQueueIndex(qIdx),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration d) {
    final mins = d.inMinutes;
    final secs = d.inSeconds % 60;
    return '$mins:${secs.toString().padLeft(2, '0')}';
  }
}

class _MeasuredLyricItem extends StatefulWidget {
  final int index;
  final void Function(int index, double height) onHeightMeasured;
  final Widget child;

  const _MeasuredLyricItem({
    required this.index,
    required this.onHeightMeasured,
    required this.child,
  });

  @override
  State<_MeasuredLyricItem> createState() => _MeasuredLyricItemState();
}

class _MeasuredLyricItemState extends State<_MeasuredLyricItem> {
  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final rb = context.findRenderObject() as RenderBox?;
      if (rb != null && rb.hasSize && rb.size.height > 0) {
        widget.onHeightMeasured(widget.index, rb.size.height);
      }
    });
    return widget.child;
  }
}
