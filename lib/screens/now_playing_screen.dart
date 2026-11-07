import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/lyric_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/equalizer_sheet.dart';
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
                    margin: const EdgeInsets.only(top: 2, bottom: 6),
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                // Top Navigation Bar: Close | Musik / Lirik | More
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IosGlassIconButton(
                      icon: Icons.keyboard_arrow_down_rounded,
                      size: 38,
                      iconSize: 24,
                      onTap: () => Navigator.pop(context),
                    ),
                    LiquidGlassBox(
                      height: 38,
                      borderRadius: 19,
                      padding: const EdgeInsets.all(3),
                      tintOpacity: 0.10,
                      rimIntensity: 0.38,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _modePillButton(
                            label: 'Musik',
                            selected: !_showLyricsView,
                            theme: theme,
                            accent: accent,
                            onTap: () => setState(() => _showLyricsView = false),
                          ),
                          _modePillButton(
                            label: 'Lirik',
                            selected: _showLyricsView,
                            theme: theme,
                            accent: accent,
                            onTap: () {
                              setState(() {
                                _showLyricsView = true;
                                _userScrollingLyrics = false;
                                _lastScrolledLyricIdx = -99;
                              });
                              WidgetsBinding.instance.addPostFrameCallback((_) {
                                if (!mounted) return;
                                _scrollToActiveLyric(
                                  song.videoId,
                                  player.activeLyricIndex,
                                  totalLyricLines,
                                  force: true,
                                );
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    IosGlassIconButton(
                      icon: Icons.more_horiz_rounded,
                      size: 38,
                      iconSize: 21,
                      onTap: () => showSongActionSheet(
                        context,
                        song: song,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6 * theme.playerSpacingFactor),

                // Main Centerpiece: Synced Lyrics View OR Responsive Artwork/Vinyl + Live Lyrics Card
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
                                final availableForArt = math
                                    .min(
                                      constraints.maxWidth - 20,
                                      constraints.maxHeight - 104,
                                    )
                                    .clamp(160.0, 294.0);
                                return Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    Stack(
                                      alignment: Alignment.topRight,
                                      children: [
                                        theme.playerCoverStyle == 'vinyl'
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
                                        Positioned(
                                          right: 8,
                                          top: 8,
                                          child: IosGlassIconButton(
                                            icon: theme.playerCoverStyle ==
                                                    'vinyl'
                                                ? Icons.crop_square_rounded
                                                : Icons.album_rounded,
                                            size: 32,
                                            iconSize: 15,
                                            tooltip:
                                                theme.playerCoverStyle == 'vinyl'
                                                    ? 'Mode Sampul'
                                                    : 'Mode Piringan',
                                            onTap: () =>
                                                theme.setPlayerCoverStyle(
                                              theme.playerCoverStyle == 'vinyl'
                                                  ? 'artwork'
                                                  : 'vinyl',
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    _buildLiveLyricsGlassCard(
                                      player,
                                      theme,
                                      accent,
                                      song.videoId,
                                      totalLyricLines,
                                    ),
                                  ],
                                );
                              },
                            ),
                          ),
                  ),
                ),

                SizedBox(height: 8 * theme.playerSpacingFactor),

                // Song Title, Artist & Quick Actions (Share + Favorite)
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
                              fontSize: 20.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.4,
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
                                      fontSize: 14,
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
                    const SizedBox(width: 8),
                    IosGlassIconButton(
                      icon: Icons.ios_share_rounded,
                      size: 38,
                      iconSize: 18,
                      tooltip: 'Bagikan Lirik / Lagu',
                      onTap: () => _openShareModal(context, player),
                    ),
                    const SizedBox(width: 8),
                    IosGlassIconButton(
                      icon: isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 38,
                      iconSize: 19,
                      activeColor: accent,
                      isActive: isFav,
                      tooltip: 'Sukai Lagu',
                      onTap: () => library.toggleFavorite(song),
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

                // Main Transport Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IosGlassIconButton(
                      icon: Icons.shuffle_rounded,
                      size: 40,
                      iconSize: 19,
                      activeColor: accent,
                      isActive: player.shuffleEnabled,
                      tooltip: 'Acak Lagu',
                      onTap: () => player.toggleShuffle(),
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
                                  width: 2.6,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.brutalShadowColor,
                                    blurRadius: 0,
                                    offset: const Offset(4.0, 4.0),
                                  ),
                                ],
                              )
                            : BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withOpacity(0.40),
                                    blurRadius: 26,
                                    spreadRadius: 2,
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
                    IosGlassIconButton(
                      icon: player.repeatMode == 2
                          ? Icons.repeat_one_rounded
                          : Icons.repeat_rounded,
                      size: 40,
                      iconSize: 19,
                      activeColor: accent,
                      isActive: player.repeatMode > 0,
                      tooltip: 'Mode Ulang',
                      onTap: () => player.cycleRepeatMode(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Logical 5-Slot Bottom Utility Dock: [Tempo | Equalizer | Timer | Unduh | Antrean]
                LiquidGlassBox(
                  borderRadius: 24,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 8,
                  ),
                  tintOpacity: 0.09,
                  rimIntensity: 0.38,
                  child: Row(
                    children: [
                      Expanded(
                        child: _dockIcon(
                          icon: Icons.speed_rounded,
                          label: player.hasCustomSpeedOrPitch
                              ? player.speedPitchModeLabel
                              : 'Tempo',
                          active: player.hasCustomSpeedOrPitch,
                          theme: theme,
                          accent: accent,
                          onTap: () => _showSpeedPitchStudioSheet(
                            context,
                            player,
                          ),
                        ),
                      ),
                      Expanded(
                        child: _dockIcon(
                          icon: Icons.equalizer_rounded,
                          label: 'Equalizer',
                          active: player.eqEnabled,
                          theme: theme,
                          accent: accent,
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const EqualizerSheet(),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: _dockIcon(
                          icon: Icons.bedtime_outlined,
                          label: 'Timer',
                          active: player.hasActiveSleepTimer,
                          theme: theme,
                          accent: accent,
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              backgroundColor: Colors.transparent,
                              builder: (_) => const SleepTimerSheet(),
                            );
                          },
                        ),
                      ),
                      Expanded(
                        child: downloadProgress != null
                            ? Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    value: downloadProgress,
                                    color: theme.accentText,
                                    strokeWidth: 2.2,
                                  ),
                                ),
                              )
                            : _dockIcon(
                                icon: isDownloaded
                                    ? Icons.download_done_rounded
                                    : Icons.download_outlined,
                                label: isDownloaded ? 'Tersimpan' : 'Unduh',
                                active: isDownloaded,
                                theme: theme,
                                accent: accent,
                                onTap: () {
                                  if (!isDownloaded) {
                                    library.downloadSong(
                                      song,
                                      highQuality: true,
                                    );
                                  }
                                },
                              ),
                      ),
                      Expanded(
                        child: _dockIcon(
                          icon: Icons.queue_music_rounded,
                          label: 'Antrean',
                          badgeText: '${player.upcomingCount}',
                          active: false,
                          theme: theme,
                          accent: accent,
                          onTap: () => _showQueueBottomSheet(context, player),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Live Lyrics Preview Card below Artwork
  Widget _buildLiveLyricsGlassCard(
    PlayerProvider player,
    ThemeProvider theme,
    Color accent,
    String videoId,
    int totalLyricLines,
  ) {
    final lyrics = player.currentLyrics;
    final isLoading = player.isLoadingLyrics;
    final isBrutal = theme.isNeoBrutalism;

    return LiquidGlassBox(
      borderRadius: 20,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      tintOpacity: 0.08,
      rimIntensity: 0.36,
      onTap: () {
        setState(() {
          _showLyricsView = true;
          _userScrollingLyrics = false;
          _lastScrolledLyricIdx = -99;
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _scrollToActiveLyric(
            videoId,
            player.activeLyricIndex,
            totalLyricLines,
            force: true,
          );
        });
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              MiniAudioSpectrumBars(
                isPlaying: player.isPlaying,
                color: theme.accentText,
                height: 11,
              ),
              const SizedBox(width: 6),
              Text(
                'LIRIK LANGSUNG',
                style: TextStyle(
                  color: theme.accentText,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (lyrics != null &&
                  lyrics.lines.length > 1 &&
                  lyrics.shouldShowTranslation)
                GestureDetector(
                  onTap: () => player.toggleTranslationDisplay(),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: player.showTranslation
                          ? accent
                          : theme.subtleFill,
                      borderRadius: BorderRadius.circular(isBrutal ? 6 : 8),
                      border: isBrutal
                          ? Border.all(
                              color: theme.brutalBorderColor,
                              width: 1.4,
                            )
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.translate_rounded,
                          color: player.showTranslation
                              ? const Color(0xFF111111)
                              : theme.textSecondary,
                          size: 10.5,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          player.isTranslatingLyrics
                              ? 'Proses...'
                              : 'Terjemahkan',
                          style: TextStyle(
                            color: player.showTranslation
                                ? const Color(0xFF111111)
                                : theme.textSecondary,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              Icon(
                Icons.open_in_full_rounded,
                color: theme.textMuted,
                size: 12,
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (isLoading)
            Text(
              'Memuat lirik sinkron...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.textSecondary, fontSize: 12.5),
            )
          else if (lyrics == null || lyrics.lines.isEmpty)
            Text(
              '♪ Instrumental / Lirik belum tersedia ♪',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: theme.textMuted, fontSize: 12.5),
            )
          else
            Builder(
              builder: (context) {
                final rawIdx = player.activeLyricIndex;
                final isIntro = rawIdx < 0;
                final idx = rawIdx.clamp(0, lyrics.lines.length - 1);
                final activeLine = lyrics.lines[idx];
                final nextLine = !isIntro && idx + 1 < lyrics.lines.length
                    ? lyrics.lines[idx + 1]
                    : null;

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (child, anim) =>
                      FadeTransition(opacity: anim, child: child),
                  child: Column(
                    key: ValueKey('preview_${rawIdx}_${player.showTranslation}'),
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isIntro
                            ? '•  •  •'
                            : (activeLine.originalText.isEmpty ||
                                    activeLine.originalText.contains('•')
                                ? '•  •  •'
                                : activeLine.originalText),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                      if (!isIntro &&
                          player.showTranslation &&
                          lyrics.shouldShowTranslation &&
                          activeLine.translatedIndoText != null &&
                          activeLine.translatedIndoText!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          activeLine.translatedIndoText!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.dmSans(
                            color: theme.accentText,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ] else if (isIntro) ...[
                        const SizedBox(height: 2),
                        Text(
                          activeLine.originalText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: theme.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ] else if (nextLine != null &&
                          nextLine.originalText.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          nextLine.originalText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: theme.textMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
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
        // Uniform 32px Lyrics Toolbar
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (lyrics.shouldShowTranslation) ...[
                  IosGlassPillButton(
                    icon: Icons.translate_rounded,
                    label: player.isTranslatingLyrics
                        ? 'Proses...'
                        : 'Terjemahkan',
                    height: 32,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    activeColor: accent,
                    isActive: player.showTranslation,
                    fontSize: 11.2,
                    onTap: () => player.toggleTranslationDisplay(),
                  ),
                  const SizedBox(width: 6),
                ],

                // Sumber Lirik Switcher Pill
                IosGlassPillButton(
                  icon: Icons.cloud_done_rounded,
                  label: lyrics.sourceName.replaceAll(' Synced', ''),
                  height: 32,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  activeColor: accent,
                  fontSize: 11.2,
                  onTap: () => _showLyricsProviderSheet(context, player),
                ),
                const SizedBox(width: 6),

                // 1-Tap Lyric Alignment Toggle
                IosGlassIconButton(
                  icon: theme.lyricsCenterAligned
                      ? Icons.format_align_center_rounded
                      : Icons.format_align_left_rounded,
                  size: 32,
                  iconSize: 15,
                  activeColor: accent,
                  isActive: theme.lyricsCenterAligned,
                  onTap: () =>
                      theme.setLyricsCenterAligned(!theme.lyricsCenterAligned),
                ),
                const SizedBox(width: 6),

                // Sync Offset Pill (-0.25s / +0.25s)
                LiquidGlassBox(
                  height: 32,
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tintOpacity: 0.08,
                  rimIntensity: 0.30,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IosSpringButton(
                        scaleDown: 0.84,
                        borderRadius: 10,
                        onTap: () => player.adjustLyricsOffset(-250),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 4,
                          ),
                          child: Text(
                            '-0.25s',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 10.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      IosSpringButton(
                        scaleDown: 0.84,
                        borderRadius: 10,
                        onTap: () => player.resetLyricsOffset(),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 4,
                          ),
                          child: Text(
                            '${(player.lyricsOffsetMs / 1000).toStringAsFixed(2)}s',
                            style: TextStyle(
                              color: player.lyricsOffsetMs == 0
                                  ? theme.textMuted
                                  : theme.accentText,
                              fontSize: 10.8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      IosSpringButton(
                        scaleDown: 0.84,
                        borderRadius: 10,
                        onTap: () => player.adjustLyricsOffset(250),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 5,
                            vertical: 4,
                          ),
                          child: Text(
                            '+0.25s',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 10.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),

        // Synced Lyrics Viewport
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _lyricsViewportHeight = constraints.maxHeight;
              const double topSafePad = 68.0;
              final double bottomSafePad =
                  (constraints.maxHeight * 0.58).clamp(140.0, 260.0);
              final activeIdx = player.activeLyricIndex < 0
                  ? 0
                  : player.activeLyricIndex.clamp(0, lyrics.lines.length - 1);

              return Stack(
                children: [
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
                    child: NotificationListener<UserScrollNotification>(
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
                                    ? 0.52
                                    : (distance == 2
                                        ? 0.30
                                        : (isPassed ? 0.18 : 0.22)));

                            final isInterlude = line.originalText.isEmpty ||
                                line.originalText.contains('•');
                            final nextTimestamp =
                                index + 1 < lyrics.lines.length
                                    ? lyrics.lines[index + 1].timestamp
                                    : player.duration;

                            final Widget lineBody = isInterlude
                                ? _buildInterludeIndicator(
                                    isActive: isActive,
                                    theme: theme,
                                    accent: accent,
                                    centerAligned: theme.lyricsCenterAligned,
                                    lineTimestamp: line.timestamp,
                                    nextTimestamp: nextTimestamp,
                                  )
                                : _buildBitChordLyricContent(
                                    isActive: isActive,
                                    line: line,
                                    translatedText: (player.showTranslation &&
                                            lyrics.shouldShowTranslation)
                                        ? line.translatedIndoText
                                        : null,
                                    theme: theme,
                                    accent: accent,
                                    centerAligned: theme.lyricsCenterAligned,
                                    fontScale: theme.lyricsFontScale,
                                    nextTimestamp: nextTimestamp,
                                  );

                            return _MeasuredLyricItem(
                              index: index,
                              onHeightMeasured: (idx, h) {
                                final prev = _lineHeights[idx];
                                if (prev == null || (prev - h).abs() > 1.0) {
                                  _lineHeights[idx] = h;
                                }
                              },
                              child: IosSpringButton(
                                scaleDown: 0.96,
                                borderRadius: isBrutal ? 13 : 18,
                                onTap: () {
                                  setState(() => _userScrollingLyrics = false);
                                  player.seekTo(line.timestamp);
                                },
                                child: AnimatedContainer(
                                  duration: theme.animDuration(260),
                                  curve: Curves.easeOutCubic,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 11,
                                    horizontal: 14,
                                  ),
                                  decoration: isBrutal && isActive
                                      ? BoxDecoration(
                                          color: Color.lerp(
                                            theme.cardBgColor,
                                            accent,
                                            0.28,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(13),
                                          border: Border.all(
                                            color: theme.brutalBorderColor,
                                            width: 2.0,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: theme.brutalShadowColor,
                                              blurRadius: 0,
                                              offset: const Offset(3.0, 3.0),
                                            ),
                                          ],
                                        )
                                      : BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(18),
                                          color: isActive
                                              ? Colors.white.withOpacity(0.06)
                                              : Colors.transparent,
                                        ),
                                  child: AnimatedScale(
                                    scale: isActive
                                        ? 1.0
                                        : (distance == 1 ? 0.95 : 0.92),
                                    alignment: theme.lyricsCenterAligned
                                        ? Alignment.center
                                        : Alignment.centerLeft,
                                    duration: theme.animDuration(300),
                                    curve: Curves.easeOutCubic,
                                    child: AnimatedOpacity(
                                      duration: theme.animDuration(240),
                                      curve: Curves.easeOutCubic,
                                      opacity: itemOpacity,
                                      child: lineBody,
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }),
                        ),
                      ),
                    ),
                  ),

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
    required LyricLine line,
    required String? translatedText,
    required ThemeProvider theme,
    required Color accent,
    required bool centerAligned,
    required double fontScale,
    required Duration nextTimestamp,
  }) {
    final displayText = line.originalText;
    final words = line.words;
    final fgColor = theme.textPrimary;
    final unsungColor = fgColor.withOpacity(0.36);

    final baseStyle = GoogleFonts.plusJakartaSans(
      color: fgColor,
      fontSize: 23.0 * fontScale,
      fontWeight: FontWeight.w800,
      height: 1.30,
      letterSpacing: -0.45,
    );
    final crossAlign =
        centerAligned ? CrossAxisAlignment.center : CrossAxisAlignment.start;
    final wrapAlign =
        centerAligned ? WrapAlignment.center : WrapAlignment.start;
    final textAlign = centerAligned ? TextAlign.center : TextAlign.left;

    if (!isActive) {
      return Column(
        crossAxisAlignment: crossAlign,
        children: [
          if (words.isNotEmpty)
            Wrap(
              alignment: wrapAlign,
              spacing: 6.0,
              runSpacing: 4,
              children: words
                  .map((w) => Text(w.text, style: baseStyle))
                  .toList(),
            )
          else
            Text(displayText, textAlign: textAlign, style: baseStyle),
          if (translatedText != null && translatedText.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              translatedText,
              textAlign: textAlign,
              style: GoogleFonts.dmSans(
                color: theme.textSecondary,
                fontSize: 14.2 * fontScale,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
                height: 1.28,
              ),
            ),
          ],
        ],
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
                spacing: 6.0,
                runSpacing: 4,
                children: words.map((w) {
                  final span = (w.endMs - w.startMs).clamp(60, 15000);
                  final wProg = ((curMs - w.startMs) / span).clamp(0.0, 1.0);

                  final activeWordStyle = baseStyle.copyWith(
                    shadows: (!theme.isLightCanvas && wProg > 0.05)
                        ? [
                            Shadow(
                              color: accent.withOpacity(0.62 * wProg),
                              blurRadius: 16,
                            ),
                          ]
                        : null,
                  );

                  if (wProg >= 0.99) {
                    return Text(w.text, style: activeWordStyle);
                  }
                  if (wProg <= 0.01) {
                    return Text(
                      w.text,
                      style: baseStyle.copyWith(color: unsungColor),
                    );
                  }
                  return ShaderMask(
                    shaderCallback: (rect) => LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        fgColor,
                        unsungColor,
                      ],
                      stops: [
                        wProg.clamp(0.0, 1.0),
                        (wProg + 0.22).clamp(0.0, 1.0),
                      ],
                    ).createShader(rect),
                    blendMode: BlendMode.srcIn,
                    child: Text(w.text, style: activeWordStyle),
                  );
                }).toList(),
              )
            else
              Text(
                displayText,
                textAlign: textAlign,
                style: baseStyle.copyWith(
                  shadows: !theme.isLightCanvas
                      ? [
                          Shadow(
                            color: accent.withOpacity(0.50),
                            blurRadius: 16,
                          ),
                        ]
                      : null,
                ),
              ),
            if (translatedText != null && translatedText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                translatedText,
                textAlign: textAlign,
                style: GoogleFonts.dmSans(
                  color: theme.accentText,
                  fontSize: 14.5 * fontScale,
                  fontStyle: FontStyle.italic,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
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
    required ThemeProvider theme,
    required Color accent,
    required bool centerAligned,
    required Duration lineTimestamp,
    required Duration nextTimestamp,
  }) {
    final fgColor = theme.textPrimary;
    if (!isActive) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          mainAxisAlignment:
              centerAligned ? MainAxisAlignment.center : MainAxisAlignment.start,
          mainAxisSize: centerAligned ? MainAxisSize.max : MainAxisSize.min,
          children: List.generate(3, (i) {
            return Container(
              margin: EdgeInsets.only(right: i < 2 ? 10 : 0),
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: fgColor.withOpacity(0.28),
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
            mainAxisAlignment: centerAligned
                ? MainAxisAlignment.center
                : MainAxisAlignment.start,
            mainAxisSize: centerAligned ? MainAxisSize.max : MainAxisSize.min,
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

  Widget _modePillButton({
    required String label,
    required bool selected,
    required ThemeProvider theme,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final isBrutal = theme.isNeoBrutalism;
    return IosSpringButton(
      scaleDown: 0.88,
      borderRadius: isBrutal ? 9 : 16,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: isBrutal
            ? BoxDecoration(
                color: selected ? accent : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                border: selected
                    ? Border.all(color: theme.brutalBorderColor, width: 1.8)
                    : null,
              )
            : BoxDecoration(
                gradient: selected
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.24),
                          accent.withOpacity(0.26),
                        ],
                      )
                    : null,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: selected
                      ? Colors.white.withOpacity(0.36)
                      : Colors.transparent,
                  width: 0.95,
                ),
              ),
        child: Text(
          label,
          style: TextStyle(
            color: selected
                ? (isBrutal ? const Color(0xFF111111) : Colors.white)
                : theme.textSecondary,
            fontSize: 12,
            fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
            height: 1.1,
          ),
        ),
      ),
    );
  }

  Widget _dockIcon({
    required IconData icon,
    required String label,
    required bool active,
    required ThemeProvider theme,
    required Color accent,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    final isBrutal = theme.isNeoBrutalism;
    final activeFg = theme.accentText;
    return IosSpringButton(
      scaleDown: 0.84,
      borderRadius: 16,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                AnimatedScale(
                  scale: active ? 1.08 : 1.0,
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutBack,
                  child: Icon(
                    icon,
                    color: active ? activeFg : theme.textSecondary,
                    size: 20,
                  ),
                ),
                if (badgeText != null)
                  Positioned(
                    right: -10,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4.5,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(8),
                        border: isBrutal
                            ? Border.all(
                                color: theme.brutalBorderColor,
                                width: 1.2,
                              )
                            : null,
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: active ? activeFg : theme.textMuted,
                fontSize: 10,
                fontWeight: active ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
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

                bool hasUserAddedItems = false;
                for (int k = curIdx + 1; k < total; k++) {
                  if (livePlayer.sourceAt(k) == QueueSource.user) {
                    hasUserAddedItems = true;
                    break;
                  }
                }

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
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IosGlassPillButton(
                                icon: Icons.auto_awesome_rounded,
                                label: 'Autoplay',
                                height: 30,
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 10),
                                activeColor: accent,
                                isActive: livePlayer.autoplayEnabled,
                                fontSize: 11,
                                onTap: () => livePlayer.setAutoplayEnabled(
                                  !livePlayer.autoplayEnabled,
                                ),
                              ),
                              const SizedBox(width: 6),
                              IosGlassIconButton(
                                icon: Icons.shuffle_rounded,
                                size: 32,
                                iconSize: 16,
                                activeColor: accent,
                                isActive: livePlayer.shuffleEnabled,
                                tooltip: 'Acak Antrean',
                                onTap: () => livePlayer.toggleShuffle(),
                              ),
                            ],
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
                                        sectionTitle = 'AUTOPLAY';
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
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  sectionTitle,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: source ==
                                                            QueueSource.user
                                                        ? theme.accentText
                                                        : theme.textMuted,
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w800,
                                                    letterSpacing: 0.7,
                                                  ),
                                                ),
                                              ),
                                              if (source == QueueSource.user &&
                                                  hasUserAddedItems)
                                                GestureDetector(
                                                  onTap: () => livePlayer
                                                      .clearUserQueue(),
                                                  child: Text(
                                                    'Bersihkan',
                                                    style: TextStyle(
                                                      color: theme.accentText,
                                                      fontSize: 11.5,
                                                      fontWeight:
                                                          FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                            ],
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
