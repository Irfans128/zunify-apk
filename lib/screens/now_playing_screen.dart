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

  // Deterministic Measured-Height LyricPlayhead Engine (BitChord style)
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

        // Continuously verify active lyric scroll position so lyrics NEVER freeze
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

  /// BitChord `LyricPlayhead` Deterministic Auto-Scroll Engine:
  /// Sums exact measured heights of lines `[0 .. targetIdx - 1]` and positions
  /// the active line at the upper-third focal playhead (`playheadTopPad = 68px`)
  /// so line 0 is NEVER cut off at the top and every subsequent line glides smoothly.
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

    // Top padding inside SingleChildScrollView equals playhead focal offset (68px),
    // so for targetIdx == 0, sumBefore == 0 -> targetOffset == 0.0 (never clipped!).
    double sumBefore = 0.0;
    for (int i = 0; i < targetIdx; i++) {
      sumBefore += (_lineHeights[i] ?? 72.0);
    }

    final activeHeight = _lineHeights[targetIdx] ?? 76.0;
    // Center the active line comfortably around 26% of viewport height
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
                      color: Colors.white.withOpacity(0.26),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),

                // iOS 26 Liquid Glass Top Navigation Bar
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
                            accent: accent,
                            onTap: () => setState(() => _showLyricsView = false),
                          ),
                          _modePillButton(
                            label: 'Lirik',
                            selected: _showLyricsView,
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

                // Main Centerpiece: Either Lyrics View (NO conflicting vertical gesture wrapper!)
                // OR Artwork/Vinyl View (with swipe gestures)
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
                                final availableForArt =
                                    (constraints.maxHeight - 128)
                                        .clamp(150.0, 256.0);
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

                SizedBox(height: 6 * theme.playerSpacingFactor),

                // Audio Pipeline & Tempo Studio Badge (iOS 26 Liquid Glass Pill)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: IosGlassPillButton(
                      icon: Icons.graphic_eq_rounded,
                      label: player.hasCustomSpeedOrPitch
                          ? '${player.activeAudioFormatBadge} • ${player.speedPitchModeLabel}'
                          : player.activeAudioFormatBadge,
                      height: 26,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      activeColor: accent,
                      isActive: player.hasCustomSpeedOrPitch,
                      fontSize: 10.2,
                      onTap: () =>
                          _showSpeedPitchStudioSheet(context, player, accent),
                    ),
                  ),
                ),

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
                              color: Colors.white,
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
                                      color: Colors.white.withOpacity(0.72),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 2),
                                Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white.withOpacity(0.50),
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
                      onTap: () => library.toggleFavorite(song),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // BitChord `ThinSlider` Capsule Progress Scrubber (Expands on touch)
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
                                  height: _isDraggingSeekSlider ? 11.0 : 6.0,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(99),
                                  ),
                                  child: Align(
                                    alignment: Alignment.centerLeft,
                                    child: FractionallySizedBox(
                                      widthFactor: progress,
                                      child: Container(
                                        decoration: BoxDecoration(
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
                                                  _isDraggingSeekSlider ? 14 : 8,
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
                                    ? Colors.white
                                    : Colors.white54,
                                fontSize: 11.2,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              _formatDuration(total),
                              style: const TextStyle(
                                color: Colors.white54,
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

                // Symmetrical iOS 26 Main Transport Controls
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
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => player.playPrevious(),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Icon(
                            Icons.skip_previous_rounded,
                            color: Colors.white,
                            size: 36,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => player.togglePlayPause(),
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.36),
                              blurRadius: 24,
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
                                  color: Colors.black,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Icon(
                                player.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 38,
                              ),
                      ),
                    ),
                    GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: () => player.playNext(),
                      child: const SizedBox(
                        width: 48,
                        height: 48,
                        child: Center(
                          child: Icon(
                            Icons.skip_next_rounded,
                            color: Colors.white,
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

                // iOS 26 Floating Liquid Glass PlayerDock (5 Equal-Width Columns)
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
                          icon: Icons.lyrics_outlined,
                          label: 'Lirik',
                          active: _showLyricsView,
                          accent: accent,
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
                      ),
                      Expanded(
                        child: _dockIcon(
                          icon: Icons.equalizer_rounded,
                          label: 'Equalizer',
                          active: player.eqEnabled,
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
                                    color: accent,
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
                                accent: accent,
                                onTap: () {
                                  if (!isDownloaded) {
                                    library.downloadSong(
                                      song,
                                      highQuality: player.highQualityAudio,
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
                          accent: accent,
                          onTap: () =>
                              _showQueueBottomSheet(context, player, accent),
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

  /// BitChord Liquid Glass Live Lyrics Preview Card below Artwork
  Widget _buildLiveLyricsGlassCard(
    PlayerProvider player,
    Color accent,
    String videoId,
    int totalLyricLines,
  ) {
    final lyrics = player.currentLyrics;
    final isLoading = player.isLoadingLyrics;

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
                color: accent,
                height: 11,
              ),
              const SizedBox(width: 6),
              Text(
                'LIRIK LANGSUNG',
                style: TextStyle(
                  color: accent,
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
                          : Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.translate_rounded,
                          color: player.showTranslation
                              ? Colors.black
                              : Colors.white70,
                          size: 10.5,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          player.isTranslatingLyrics
                              ? 'Proses...'
                              : 'Terjemahkan',
                          style: TextStyle(
                            color: player.showTranslation
                                ? Colors.black
                                : Colors.white70,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const Icon(
                Icons.open_in_full_rounded,
                color: Colors.white54,
                size: 12,
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (isLoading)
            const Text(
              'Memuat lirik sinkron...',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white60, fontSize: 12.5),
            )
          else if (lyrics == null || lyrics.lines.isEmpty)
            const Text(
              '♪ Instrumental / Lirik belum tersedia ♪',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.white54, fontSize: 12.5),
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
                          color: Colors.white,
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
                            color: accent,
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ] else if (isIntro) ...[
                        const SizedBox(height: 2),
                        Text(
                          activeLine.originalText,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white38,
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
                            color: Colors.white38,
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

  /// BitChord `PlayerLyricsKt` + `LyricFocusKt` Full-Screen Synced Lyrics View
  Widget _buildBitChordLyricsView(
    String videoId,
    PlayerProvider player,
    ThemeProvider theme,
    Color accent,
  ) {
    final SyncedLyrics? lyrics = player.currentLyrics;
    if (player.isLoadingLyrics) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: accent),
            const SizedBox(height: 12),
            const Text(
              'Memuat lirik lagu...',
              style: TextStyle(color: Colors.white70, fontSize: 13.5),
            ),
          ],
        ),
      );
    }
    if (lyrics == null || lyrics.lines.isEmpty) {
      return const Center(
        child: Text(
          '♪ Instrumental / Lirik belum tersedia ♪',
          style: TextStyle(color: Colors.white54, fontSize: 15),
        ),
      );
    }

    return Column(
      key: const ValueKey('bitchord_lyrics_view'),
      children: [
        // iOS 26 Uniform 32px Liquid Glass Lyrics Toolbar:
        // Translate • Provider Switcher • Alignment • Sync Offset (-0.25s / +0.25s)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (lyrics.shouldShowTranslation) ...[
                  LiquidGlassBox(
                    height: 32,
                    borderRadius: 16,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    tintColor: player.showTranslation ? accent : Colors.white,
                    tintOpacity: player.showTranslation ? 0.24 : 0.08,
                    rimIntensity: player.showTranslation ? 0.52 : 0.30,
                    onTap: () => player.toggleTranslationDisplay(),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (player.isTranslatingLyrics) ...[
                          SizedBox(
                            width: 11,
                            height: 11,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accent,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ] else ...[
                          Icon(
                            Icons.translate_rounded,
                            color: player.showTranslation
                                ? accent
                                : Colors.white70,
                            size: 13.5,
                          ),
                          const SizedBox(width: 5),
                        ],
                        Text(
                          player.isTranslatingLyrics
                              ? 'Proses...'
                              : 'Terjemahkan',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.2,
                            fontWeight: player.showTranslation
                                ? FontWeight.w800
                                : FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // "Pilih Penyedia Lirik" Switcher Pill (Height 32)
                LiquidGlassBox(
                  height: 32,
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 11),
                  tintOpacity: 0.08,
                  rimIntensity: 0.30,
                  onTap: () => _showLyricsProviderSheet(context, player, accent),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.cloud_done_rounded,
                        color: accent,
                        size: 13.5,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        lyrics.sourceName.replaceAll(' Synced', ''),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 2),
                      const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white70,
                        size: 14,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),

                // 1-Tap Lyric Alignment Toggle (32x32 Circular Glass)
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

                // Sync Offset Pill (-0.25s / +0.25s, Height 32)
                LiquidGlassBox(
                  height: 32,
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tintOpacity: 0.08,
                  rimIntensity: 0.30,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => player.adjustLyricsOffset(-250),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                          child: Text(
                            '-0.25s',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 10.8,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
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
                                  ? Colors.white54
                                  : accent,
                              fontSize: 10.8,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => player.adjustLyricsOffset(250),
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                          child: Text(
                            '+0.25s',
                            style: TextStyle(
                              color: Colors.white70,
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

        // BitChord Floating Synced Lyrics Viewport (Pure typography, never clipped!)
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              _lyricsViewportHeight = constraints.maxHeight;
              // Top padding = 68px so Line 0 starts cleanly below the top fade!
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
                                    ? 0.46
                                    : (distance == 2
                                        ? 0.26
                                        : (isPassed ? 0.14 : 0.18)));

                            final isInterlude = line.originalText.isEmpty ||
                                line.originalText.contains('•');
                            final nextTimestamp =
                                index + 1 < lyrics.lines.length
                                    ? lyrics.lines[index + 1].timestamp
                                    : player.duration;

                            final Widget lineBody = isInterlude
                                ? _buildInterludeIndicator(
                                    isActive: isActive,
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
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
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
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
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
                      child: LiquidGlassBox(
                        borderRadius: 20,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        tintColor: accent,
                        tintOpacity: 0.28,
                        rimIntensity: 0.52,
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
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.my_location_rounded,
                              color: accent,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            const Text(
                              'Ikuti Lirik',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
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

  /// BitChord "Pilih Penyedia Lirik" Bottom Sheet
  void _showLyricsProviderSheet(
    BuildContext context,
    PlayerProvider player,
    Color accent,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E121D),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Consumer<PlayerProvider>(
          builder: (context, livePlayer, _) {
            final options = livePlayer.availableLyricsProviders;
            final currentSource =
                livePlayer.currentLyrics?.sourceName ?? 'Otomatis';

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
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
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.lyrics_rounded, color: accent, size: 22),
                        const SizedBox(width: 8),
                        const Text(
                          'Pilih Penyedia Lirik',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ganti sumber lirik jika waktu sinkronisasi kurang pas dengan lagu ini.',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (options.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'Hanya 1 sumber lirik tersedia untuk lagu ini.',
                          style: TextStyle(color: Colors.white60, fontSize: 13),
                        ),
                      )
                    else
                      ...options.map((opt) {
                        final isSelected = opt.sourceName == currentSource;
                        final hasWordSync =
                            opt.lines.any((l) => l.words.length > 1);
                        return GestureDetector(
                          onTap: () {
                            livePlayer.selectLyricsProvider(opt);
                            Navigator.pop(ctx);
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent.withOpacity(0.16)
                                  : Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(16),
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
                                  color: isSelected ? accent : Colors.white70,
                                  size: 19,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        opt.sourceName,
                                        style: TextStyle(
                                          color: isSelected
                                              ? Colors.white
                                              : Colors.white.withOpacity(0.88),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                      Text(
                                        '${opt.lines.length} baris • ${hasWordSync ? "Word-by-Word Karaoke Sync" : "Line Synced LRC"}',
                                        style: const TextStyle(
                                          color: Colors.white54,
                                          fontSize: 11.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (isSelected)
                                  Icon(
                                    Icons.check_circle_rounded,
                                    color: accent,
                                    size: 20,
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
    required Color accent,
    required bool centerAligned,
    required double fontScale,
    required Duration nextTimestamp,
  }) {
    final displayText = line.originalText;
    final words = line.words;

    final baseStyle = GoogleFonts.plusJakartaSans(
      color: Colors.white,
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
                color: Colors.white70,
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
                    shadows: wProg > 0.05
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
                      style: baseStyle.copyWith(
                        color: Colors.white.withOpacity(0.36),
                      ),
                    );
                  }
                  return ShaderMask(
                    shaderCallback: (rect) => LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white,
                        Colors.white.withOpacity(0.36),
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
                  shadows: [
                    Shadow(
                      color: accent.withOpacity(0.50),
                      blurRadius: 16,
                    ),
                  ],
                ),
              ),
            if (translatedText != null && translatedText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                translatedText,
                textAlign: textAlign,
                style: GoogleFonts.dmSans(
                  color: accent,
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

  /// Spotify / Apple Music / BitChord 3 Animated Instrumental Dots (`•  •  •`)
  Widget _buildInterludeIndicator({
    required bool isActive,
    required Color accent,
    required bool centerAligned,
    required Duration lineTimestamp,
    required Duration nextTimestamp,
  }) {
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
                color: Colors.white.withOpacity(0.28),
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
                        Colors.white.withOpacity(0.32),
                        Colors.white,
                        dotFill,
                      ),
                      boxShadow: dotFill > 0.2
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

  /// Modern 3D Floating Album Cover (`PlayerArtworkKt` from BitChord)
  Widget _buildModern3DAlbumArtwork({
    required String imageUrl,
    required bool isPlaying,
    required Color accent,
    required Color ambient,
    required ThemeProvider theme,
    required double size,
  }) {
    return AnimatedScale(
      scale: isPlaying ? 1.0 : 0.88,
      duration: theme.animDuration(380),
      curve: Curves.easeOutBack,
      child: AnimatedContainer(
        duration: theme.animDuration(380),
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
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
          borderRadius: BorderRadius.circular(28),
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 180),
                errorWidget: (_, __, ___) => Container(
                  color: Colors.white10,
                  child: Icon(
                    Icons.music_note_rounded,
                    color: accent,
                    size: size * 0.36,
                  ),
                ),
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
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

  /// Audio Tempo & Pitch Studio Bottom Sheet
  void _showSpeedPitchStudioSheet(
    BuildContext context,
    PlayerProvider player,
    Color accent,
  ) {
    final presets = <Map<String, dynamic>>[
      {'label': 'Normal (1.0x)', 'speed': 1.0, 'pitch': 1.0},
      {'label': 'Slowed + Aesthetic', 'speed': 0.86, 'pitch': 0.88},
      {'label': 'Daycore Deep', 'speed': 0.92, 'pitch': 0.92},
      {'label': 'Sped Up', 'speed': 1.12, 'pitch': 1.08},
      {'label': 'Nightcore', 'speed': 1.20, 'pitch': 1.20},
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF101420),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Consumer<PlayerProvider>(
          builder: (context, livePlayer, _) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
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
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.tune_rounded, color: accent, size: 22),
                            const SizedBox(width: 8),
                            const Text(
                              'Zunify Audio & Tempo Studio',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        if (livePlayer.hasCustomSpeedOrPitch)
                          GestureDetector(
                            onTap: () => livePlayer.resetSpeedPitch(),
                            child: Text(
                              'Reset 1.0x',
                              style: TextStyle(
                                color: accent,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: presets.map((p) {
                        final sp = p['speed'] as double;
                        final pt = p['pitch'] as double;
                        final isSelected =
                            (livePlayer.playbackSpeed - sp).abs() < 0.02 &&
                                (livePlayer.playbackPitch - pt).abs() < 0.02;
                        return GestureDetector(
                          onTap: () => livePlayer.setSpeedPitchPreset(sp, pt),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? accent
                                  : Colors.white.withOpacity(0.07),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSelected ? accent : Colors.white12,
                              ),
                            ),
                            child: Text(
                              p['label'] as String,
                              style: TextStyle(
                                color: isSelected ? Colors.black : Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Kecepatan Lagu (Speed)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${livePlayer.playbackSpeed.toStringAsFixed(2)}x',
                          style: TextStyle(
                            color: accent,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: livePlayer.playbackSpeed.clamp(0.70, 1.35),
                      min: 0.70,
                      max: 1.35,
                      activeColor: accent,
                      inactiveColor: Colors.white12,
                      onChanged: (v) => livePlayer.setPlaybackSpeed(v),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Nada Vokal (Pitch)',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '${livePlayer.playbackPitch.toStringAsFixed(2)}x',
                          style: TextStyle(
                            color: accent,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: livePlayer.playbackPitch.clamp(0.70, 1.35),
                      min: 0.70,
                      max: 1.35,
                      activeColor: accent,
                      inactiveColor: Colors.white12,
                      onChanged: (v) => livePlayer.setPlaybackPitch(v),
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
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                selected ? Colors.white.withOpacity(0.28) : Colors.transparent,
            width: 0.9,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white60,
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
    required Color accent,
    required VoidCallback onTap,
    String? badgeText,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: active ? accent : Colors.white70,
                  size: 20,
                ),
                if (badgeText != null)
                  Positioned(
                    right: -10,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        badgeText,
                        style: const TextStyle(
                          color: Colors.black,
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
              style: TextStyle(
                color: active ? accent : Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w700,
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
    Color accent,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0C101B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (ctx, scrollCtrl) {
            return Consumer<PlayerProvider>(
              builder: (context, livePlayer, _) {
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

                return Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  child: Column(
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Antrean Pemutaran',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                livePlayer.contextName.isNotEmpty
                                    ? 'Dari: ${livePlayer.contextName}'
                                    : 'Tahan & geser ≡ untuk ubah urutan',
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => livePlayer.setAutoplayEnabled(
                                  !livePlayer.autoplayEnabled,
                                ),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: livePlayer.autoplayEnabled
                                        ? accent.withOpacity(0.18)
                                        : Colors.white.withOpacity(0.07),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: livePlayer.autoplayEnabled
                                          ? accent.withOpacity(0.45)
                                          : Colors.white12,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.auto_awesome_rounded,
                                        size: 13,
                                        color: livePlayer.autoplayEnabled
                                            ? accent
                                            : Colors.white54,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Autoplay',
                                        style: TextStyle(
                                          color: livePlayer.autoplayEnabled
                                              ? accent
                                              : Colors.white54,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Acak Antrean',
                                icon: Icon(
                                  Icons.shuffle_rounded,
                                  color: livePlayer.shuffleEnabled
                                      ? accent
                                      : Colors.white60,
                                  size: 20,
                                ),
                                onPressed: () => livePlayer.toggleShuffle(),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      if (currentSong != null) ...[
                        Text(
                          'SEDANG DIPUTAR',
                          style: TextStyle(
                            color: accent,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: accent.withOpacity(0.35)),
                          ),
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
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14,
                                      ),
                                    ),
                                    Text(
                                      currentSong.artist,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: Colors.white60,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              MiniAudioSpectrumBars(
                                isPlaying: livePlayer.isPlaying,
                                color: accent,
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
                                  style: const TextStyle(color: Colors.white54),
                                ),
                              )
                            : ReorderableListView.builder(
                                scrollController: scrollCtrl,
                                buildDefaultDragHandles: false,
                                proxyDecorator: (child, index, animation) {
                                  return Material(
                                    color: const Color(0xFF181D2C),
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
                                            ? 'BERIKUTNYA DARI: ${livePlayer.contextName.toUpperCase()}'
                                            : 'BERIKUTNYA DARI DAFTAR PUTAR';
                                        break;
                                      case QueueSource.autoplay:
                                        sectionTitle =
                                            'REKOMENDASI OTOMATIS (AUTOPLAY)';
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
                                                        ? accent
                                                        : Colors.white54,
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
                                                      color: accent,
                                                      fontSize: 11.5,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                      Container(
                                        margin: const EdgeInsets.symmetric(
                                          vertical: 2.5,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withOpacity(0.04),
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
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 13.5,
                                            ),
                                          ),
                                          subtitle: Text(
                                            item.artist,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              color: Colors.white54,
                                              fontSize: 11.5,
                                            ),
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              IconButton(
                                                visualDensity:
                                                    VisualDensity.compact,
                                                icon: const Icon(
                                                  Icons.close_rounded,
                                                  color: Colors.white38,
                                                  size: 18,
                                                ),
                                                onPressed: () => livePlayer
                                                    .removeFromQueue(qIdx),
                                              ),
                                              ReorderableDragStartListener(
                                                index: relIdx,
                                                child: const Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 8,
                                                  ),
                                                  child: Icon(
                                                    Icons.drag_handle_rounded,
                                                    color: Colors.white54,
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

/// Measures each rendered lyric line's height after layout so `_scrollToActiveLyric`
/// can compute deterministic scroll offsets without `localToGlobal` coordinate bugs.
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
