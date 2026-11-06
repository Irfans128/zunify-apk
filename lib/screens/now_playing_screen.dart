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
  final GlobalKey _lyricsViewportKey = GlobalKey();
  int _lastScrolledLyricIdx = -2;
  String? _lastSongId;
  bool _userScrollingLyrics = false;
  Timer? _resumeAutoScrollTimer;
  Timer? _postLayoutVerifyTimer;
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
      const Duration(milliseconds: 22),
      (_) {
        if (!mounted || !_showLyricsView) return;
        final player = context.read<PlayerProvider>();
        final ms =
            player.audioPlayer.position.inMilliseconds + player.lyricsOffsetMs;
        if (_smoothPosMs.value != ms) {
          _smoothPosMs.value = ms;
        }
      },
    );
  }

  @override
  void dispose() {
    _resumeAutoScrollTimer?.cancel();
    _postLayoutVerifyTimer?.cancel();
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
      _resumeAutoScrollTimer = Timer(const Duration(milliseconds: 3500), () {
        if (!mounted) return;
        setState(() {
          _userScrollingLyrics = false;
          _lastScrolledLyricIdx = -2;
        });
      });
    }
  }

  void _autoScrollLyrics(
    String videoId,
    int activeIdx,
    int totalLines, {
    bool force = false,
  }) {
    if (!_showLyricsView || _userScrollingLyrics || totalLines <= 0) return;

    final targetIdx = activeIdx < 0 ? 0 : activeIdx.clamp(0, totalLines - 1);
    final isNewTarget =
        force || _lastSongId != videoId || _lastScrolledLyricIdx != activeIdx;

    final viewportCtx = _lyricsViewportKey.currentContext;
    final itemKey = GlobalObjectKey('lyric_${videoId}_$targetIdx');
    final itemCtx = itemKey.currentContext;

    if (viewportCtx != null &&
        itemCtx != null &&
        _lyricsScrollController.hasClients) {
      final viewportBox = viewportCtx.findRenderObject() as RenderBox?;
      final itemBox = itemCtx.findRenderObject() as RenderBox?;
      if (viewportBox != null &&
          itemBox != null &&
          viewportBox.hasSize &&
          itemBox.hasSize) {
        final viewportHeight = viewportBox.size.height;
        final itemTop =
            itemBox.localToGlobal(Offset.zero, ancestor: viewportBox).dy;
        final itemHeight = itemBox.size.height;
        final itemCenter = itemTop + (itemHeight * 0.5);

        // Place active lyric card comfortably at 38% of viewport height
        // and strictly enforce a minimum 46px top safety margin so it is NEVER cut off at the top!
        final desiredCenter =
            (viewportHeight * 0.38).clamp(86.0, viewportHeight - 86.0);
        double delta = itemCenter - desiredCenter;
        final projectedTop = itemTop - delta;
        if (projectedTop < 46.0) {
          delta -= (46.0 - projectedTop);
        }

        final needsCorrection = isNewTarget ||
            delta.abs() > 16.0 ||
            itemTop < 40.0 ||
            (itemTop + itemHeight) > (viewportHeight - 28.0);

        if (needsCorrection) {
          _lastSongId = videoId;
          _lastScrolledLyricIdx = activeIdx;
          final maxExt = _lyricsScrollController.position.maxScrollExtent;
          final targetOffset =
              (_lyricsScrollController.offset + delta).clamp(0.0, maxExt);
          if ((targetOffset - _lyricsScrollController.offset).abs() > 1.5) {
            final dur = context.read<ThemeProvider>().animDuration(360);
            _lyricsScrollController.animateTo(
              targetOffset,
              duration: dur,
              curve: Curves.easeOutCubic,
            );
          }

          // Schedule a post-animation verification pass after AnimatedContainer finishes resizing
          if (isNewTarget) {
            _postLayoutVerifyTimer?.cancel();
            _postLayoutVerifyTimer =
                Timer(const Duration(milliseconds: 330), () {
              if (!mounted || !_showLyricsView || _userScrollingLyrics) return;
              _autoScrollLyrics(videoId, activeIdx, totalLines, force: true);
            });
          }
        }
        return;
      }
    }

    if (isNewTarget && _lyricsScrollController.hasClients && totalLines > 0) {
      _lastSongId = videoId;
      _lastScrolledLyricIdx = activeIdx;
      _postLayoutVerifyTimer?.cancel();
      _postLayoutVerifyTimer = Timer(const Duration(milliseconds: 280), () {
        if (!mounted || !_showLyricsView || _userScrollingLyrics) return;
        _autoScrollLyrics(videoId, activeIdx, totalLines, force: true);
      });
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollLyrics(
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
        intensity: _showLyricsView ? 0.56 : 0.44,
        child: SafeArea(
          child: Padding(
            padding: theme.playerHorizontalPadding,
            child: Column(
              children: [
                // Clean Top Navigation Bar: Collapse • Segmented Mode Pill ("Musik" | "Lirik") • More Menu
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Container(
                      padding: const EdgeInsets.all(3.5),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _modePillButton(
                            label: 'Musik',
                            selected: !_showLyricsView,
                            onTap: () => setState(() => _showLyricsView = false),
                          ),
                          _modePillButton(
                            label: 'Lirik',
                            selected: _showLyricsView,
                            onTap: () {
                              setState(() {
                                _showLyricsView = true;
                                _userScrollingLyrics = false;
                                _lastScrolledLyricIdx = -2;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Opsi Lagu',
                      icon: const Icon(
                        Icons.more_horiz_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                      onPressed: () => showSongActionSheet(
                        context,
                        song: song,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6 * theme.playerSpacingFactor),

                // Responsive Centerpiece: Modern 3D Artwork / Adaptive Vinyl + Compact Lyrics Pill OR Full Smooth Lyrics
                Expanded(
                  child: GestureDetector(
                    onVerticalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) < -280 &&
                          !_showLyricsView) {
                        setState(() {
                          _showLyricsView = true;
                          _userScrollingLyrics = false;
                          _lastScrolledLyricIdx = -2;
                        });
                      } else if ((details.primaryVelocity ?? 0) > 280 &&
                          _showLyricsView) {
                        setState(() => _showLyricsView = false);
                      }
                    },
                    onHorizontalDragEnd: (details) {
                      if (_showLyricsView) return;
                      final vx = details.primaryVelocity ?? 0;
                      if (vx < -320) {
                        player.playNext();
                      } else if (vx > 320) {
                        player.playPrevious();
                      }
                    },
                    child: AnimatedSwitcher(
                      duration: theme.animDuration(260),
                      child: _showLyricsView
                          ? _buildSmoothLyricsView(
                              song.videoId,
                              player,
                              theme,
                              accent,
                            )
                          : LayoutBuilder(
                              key: const ValueKey('artwork_or_vinyl_view'),
                              builder: (context, constraints) {
                                final availableForArt =
                                    (constraints.maxHeight - 138)
                                        .clamp(152.0, 246.0);
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
                                          right: 4,
                                          top: 4,
                                          child: GestureDetector(
                                            onTap: () =>
                                                theme.setPlayerCoverStyle(
                                              theme.playerCoverStyle == 'vinyl'
                                                  ? 'artwork'
                                                  : 'vinyl',
                                            ),
                                            child: Container(
                                              padding: const EdgeInsets.all(6),
                                              decoration: BoxDecoration(
                                                color: Colors.black
                                                    .withOpacity(0.45),
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white
                                                      .withOpacity(0.16),
                                                ),
                                              ),
                                              child: Icon(
                                                theme.playerCoverStyle ==
                                                        'vinyl'
                                                    ? Icons.crop_square_rounded
                                                    : Icons.album_rounded,
                                                color: Colors.white70,
                                                size: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    _buildLiveLyricsGlassCard(player, accent),
                                  ],
                                );
                              },
                            ),
                    ),
                  ),
                ),

                SizedBox(height: 8 * theme.playerSpacingFactor),

                // Zunify 2.0 Audio Output Quality & Speed/Pitch Studio Badge
                Align(
                  alignment: Alignment.centerLeft,
                  child: GestureDetector(
                    onTap: () =>
                        _showSpeedPitchStudioSheet(context, player, accent),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: player.hasCustomSpeedOrPitch
                            ? accent.withOpacity(0.18)
                            : Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: player.hasCustomSpeedOrPitch
                              ? accent.withOpacity(0.45)
                              : Colors.white.withOpacity(0.10),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.graphic_eq_rounded,
                            color: accent,
                            size: 12.5,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            player.hasCustomSpeedOrPitch
                                ? '${player.activeAudioFormatBadge} • ${player.speedPitchModeLabel}'
                                : player.activeAudioFormatBadge,
                            style: TextStyle(
                              color: player.hasCustomSpeedOrPitch
                                  ? accent
                                  : Colors.white70,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.4,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.tune_rounded,
                            color: player.hasCustomSpeedOrPitch
                                ? accent
                                : Colors.white38,
                            size: 11.5,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Clean Song Info + Share & Love Buttons
                Row(
                  children: [
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
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
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
                                    style: TextStyle(
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
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Bagikan ke Story / SW',
                      icon: const Icon(
                        Icons.ios_share_rounded,
                        color: Colors.white70,
                        size: 22,
                      ),
                      onPressed: () => _openShareModal(context, player),
                    ),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Favorit',
                      icon: Icon(
                        isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFav ? accent : Colors.white70,
                        size: 25,
                      ),
                      onPressed: () => library.toggleFavorite(song),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Sleek Seek Bar
                StreamBuilder<Duration>(
                  stream: player.audioPlayer.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final total = player.audioPlayer.duration ?? song.duration;
                    final maxMs = total.inMilliseconds > 0
                        ? total.inMilliseconds.toDouble()
                        : 1.0;
                    final curMs =
                        position.inMilliseconds.toDouble().clamp(0.0, maxMs);

                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: accent,
                            inactiveTrackColor: Colors.white.withOpacity(0.16),
                            thumbColor: Colors.white,
                            trackHeight: 3.5,
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 10,
                            ),
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 5.5,
                            ),
                          ),
                          child: Slider(
                            value: curMs,
                            min: 0,
                            max: maxMs,
                            onChanged: (v) => player.seekTo(
                              Duration(milliseconds: v.round()),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(position),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatDuration(total),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11.2,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 6),

                // Symmetrical Main Transport Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: 'Acak Lagu',
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: player.shuffleEnabled ? accent : Colors.white54,
                        size: 22,
                      ),
                      onPressed: () => player.toggleShuffle(),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                      onPressed: () => player.playPrevious(),
                    ),
                    GestureDetector(
                      onTap: () => player.togglePlayPause(),
                      child: Container(
                        width: 62,
                        height: 62,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.32),
                              blurRadius: 20,
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
                                  color: Colors.black,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Icon(
                                player.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.black,
                                size: 36,
                              ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                      onPressed: () => player.playNext(),
                    ),
                    IconButton(
                      tooltip: 'Mode Ulang',
                      icon: Icon(
                        player.repeatMode == 2
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: player.repeatMode > 0 ? accent : Colors.white54,
                        size: 22,
                      ),
                      onPressed: () => player.cycleRepeatMode(),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Clean Bottom Utility Bar (Label: "Lirik", "Equalizer", "Timer", "Unduh", "Antrean")
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.09),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _dockIcon(
                        icon: Icons.lyrics_outlined,
                        label: 'Lirik',
                        active: _showLyricsView,
                        accent: accent,
                        onTap: () => setState(() {
                          _showLyricsView = !_showLyricsView;
                          _userScrollingLyrics = false;
                          _lastScrolledLyricIdx = -2;
                        }),
                      ),
                      _dockIcon(
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
                      _dockIcon(
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
                      downloadProgress != null
                          ? SizedBox(
                              width: 48,
                              child: Center(
                                child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    value: downloadProgress,
                                    color: accent,
                                    strokeWidth: 2.2,
                                  ),
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
                      _dockIcon(
                        icon: Icons.queue_music_rounded,
                        label: 'Antrean',
                        badgeText: '${player.upcomingCount}',
                        active: false,
                        accent: accent,
                        onTap: () =>
                            _showQueueBottomSheet(context, player, accent),
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

  /// Sleek Frosted Live Lyrics Preview Card below Vinyl Disc
  Widget _buildLiveLyricsGlassCard(PlayerProvider player, Color accent) {
    final lyrics = player.currentLyrics;
    final isLoading = player.isLoadingLyrics;

    return GestureDetector(
      onTap: () => setState(() {
        _showLyricsView = true;
        _userScrollingLyrics = false;
        _lastScrolledLyricIdx = -2;
      }),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.11)),
        ),
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
                  'LIRIK',
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
                            : Colors.white.withOpacity(0.09),
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
                  color: Colors.white38,
                  size: 12,
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (isLoading)
              const Text(
                'Memuat lirik...',
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
      ),
    );
  }

  /// Smooth, Beat-Accurate, Clean Lyrics View (Zunify 2.0 Liquid Glass Style)
  Widget _buildSmoothLyricsView(
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
      key: const ValueKey('smooth_lyrics_view'),
      children: [
        // Symmetrical Top Toolbar: Manual Translate + Alignment Toggle (Left) • Sync Offset (Right)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (lyrics.shouldShowTranslation) ...[
                    GestureDetector(
                      onTap: () => player.toggleTranslationDisplay(),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: player.showTranslation
                              ? accent
                              : Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (player.isTranslatingLyrics) ...[
                              SizedBox(
                                width: 11,
                                height: 11,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: player.showTranslation
                                      ? Colors.black
                                      : accent,
                                ),
                              ),
                              const SizedBox(width: 6),
                            ] else ...[
                              Icon(
                                Icons.translate_rounded,
                                color: player.showTranslation
                                    ? Colors.black
                                    : Colors.white,
                                size: 13.5,
                              ),
                              const SizedBox(width: 5),
                            ],
                            Text(
                              player.isTranslatingLyrics
                                  ? 'Menerjemahkan...'
                                  : 'Terjemahkan',
                              style: TextStyle(
                                color: player.showTranslation
                                    ? Colors.black
                                    : Colors.white,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  // 1-Tap Lyric Alignment Toggle (Left vs Center)
                  GestureDetector(
                    onTap: () => theme
                        .setLyricsCenterAligned(!theme.lyricsCenterAligned),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        theme.lyricsCenterAligned
                            ? Icons.format_align_center_rounded
                            : Icons.format_align_left_rounded,
                        color: Colors.white70,
                        size: 14,
                      ),
                    ),
                  ),
                ],
              ),

              // Sync Offset Pill (-0.25s / +0.25s for fine beat matching)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => player.adjustLyricsOffset(-250),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          '-0.25s',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => player.resetLyricsOffset(),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          '${(player.lyricsOffsetMs / 1000).toStringAsFixed(2)}s',
                          style: TextStyle(
                            color: player.lyricsOffsetMs == 0
                                ? Colors.white54
                                : accent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => player.adjustLyricsOffset(250),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        child: Text(
                          '+0.25s',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 10.5,
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

        // Smooth Apple Music "Liquid Glass" Synced Lyrics Scroll List (Locked Center Position)
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final topSafePad =
                  (constraints.maxHeight * 0.34).clamp(76.0, 168.0);
              final bottomSafePad =
                  (constraints.maxHeight * 0.46).clamp(110.0, 210.0);
              final activeIdx = player.activeLyricIndex < 0
                  ? 0
                  : player.activeLyricIndex;

              return Stack(
                key: _lyricsViewportKey,
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
                      stops: [0.0, 0.035, 0.93, 1.0],
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
                                    ? 0.48
                                    : (distance == 2
                                        ? 0.28
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
                                : _buildAppleMusicLyricContent(
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

                            return RepaintBoundary(
                              key: GlobalObjectKey('lyric_${videoId}_$index'),
                              child: GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  setState(() => _userScrollingLyrics = false);
                                  player.seekTo(line.timestamp);
                                },
                                child: AnimatedContainer(
                                  duration: theme.animDuration(290),
                                  curve: Curves.easeOutCubic,
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 4),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 16,
                                  ),
                                  decoration: isActive
                                      ? BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(22),
                                          gradient: LinearGradient(
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                            colors: [
                                              Colors.white.withOpacity(0.20),
                                              accent.withOpacity(0.14),
                                              Colors.white.withOpacity(0.05),
                                            ],
                                            stops: const [0.0, 0.50, 1.0],
                                          ),
                                          border: Border.all(
                                            color:
                                                Colors.white.withOpacity(0.30),
                                            width: 1.15,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: accent.withOpacity(0.16),
                                              blurRadius: 20,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        )
                                      : BoxDecoration(
                                          borderRadius:
                                              BorderRadius.circular(22),
                                          border: Border.all(
                                            color: Colors.transparent,
                                            width: 1.15,
                                          ),
                                        ),
                                  child: AnimatedScale(
                                    scale: isActive
                                        ? 1.0
                                        : (distance == 1 ? 0.94 : 0.91),
                                    alignment: theme.lyricsCenterAligned
                                        ? Alignment.center
                                        : Alignment.centerLeft,
                                    duration: theme.animDuration(310),
                                    curve: Curves.easeOutCubic,
                                    child: AnimatedOpacity(
                                      duration: theme.animDuration(250),
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
                      child: GestureDetector(
                        onTap: () {
                          _resumeAutoScrollTimer?.cancel();
                          setState(() {
                            _userScrollingLyrics = false;
                            _lastScrolledLyricIdx = -2;
                          });
                          _autoScrollLyrics(
                            videoId,
                            player.activeLyricIndex,
                            lyrics.lines.length,
                            force: true,
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(18),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 10,
                              ),
                            ],
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.my_location_rounded,
                                color: Colors.black,
                                size: 14,
                              ),
                              SizedBox(width: 5),
                              Text(
                                'Ikuti Lirik',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
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

  Widget _buildAppleMusicLyricContent({
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
      fontSize: 21.5 * fontScale,
      fontWeight: FontWeight.w800,
      height: 1.32,
      letterSpacing: -0.40,
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
            const SizedBox(height: 6),
            Text(
              translatedText,
              textAlign: textAlign,
              style: GoogleFonts.dmSans(
                color: Colors.white70,
                fontSize: 14.2 * fontScale,
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.w600,
                height: 1.3,
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
                              color: accent.withOpacity(0.55 * wProg),
                              blurRadius: 14,
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
                        color: Colors.white.withOpacity(0.38),
                      ),
                    );
                  }
                  return ShaderMask(
                    shaderCallback: (rect) => LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        Colors.white,
                        Colors.white.withOpacity(0.38),
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
              Text(displayText, textAlign: textAlign, style: baseStyle),
            if (translatedText != null && translatedText.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                translatedText,
                textAlign: textAlign,
                style: GoogleFonts.dmSans(
                  color: accent,
                  fontSize: 14.2 * fontScale,
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

  /// Spotify / Apple Music 3 Animated Instrumental Dots (`•  •  •`)
  /// Bounces in a smooth wave and fills left-to-right as the intro/interlude plays,
  /// with NO text labels.
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
              // Each dot fills up across its 1/3rd segment of the interlude
              final segStart = i / 3.0;
              final dotFill = ((progress - segStart) * 3.0).clamp(0.0, 1.0);
              // Smooth rhythmic wave bounce like Spotify & Apple Music
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

  /// Modern 3D Floating Album Cover (Apple Music / Zunify 2.0 Style)
  /// Scales dynamically with Play/Pause state and casts an ambient color shadow
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
          borderRadius: BorderRadius.circular(26),
          boxShadow: [
            BoxShadow(
              color: ambient.withOpacity(isPlaying ? 0.52 : 0.22),
              blurRadius: isPlaying ? 38 : 18,
              spreadRadius: isPlaying ? 3 : 0,
              offset: Offset(0, isPlaying ? 14 : 8),
            ),
            BoxShadow(
              color: Colors.black.withOpacity(0.55),
              blurRadius: 24,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
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
              // Subtle top-left glass specular border
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.16),
                      width: 1.1,
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

  /// Zunify 2.0 Audio Tempo, Pitch & Crossfade Studio Bottom Sheet
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
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 12,
            fontWeight: FontWeight.w700,
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
      borderRadius: BorderRadius.circular(12),
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
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Authentic Spotify-style Interactive Queue Bottom Sheet
  /// Shows:
  /// - SEDANG DIPUTAR
  /// - BERIKUTNYA DI ANTREAN (User added via "Putar Berikutnya" / "Tambah ke Antrean")
  /// - BERIKUTNYA DARI: [Context Name] (Playlist / Chart / Album)
  /// - REKOMENDASI OTOMATIS (Smart Autoplay Algorithm)
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
                final upcomingCount =
                    (total - curIdx - 1).clamp(0, total);

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

                      // Header + Autoplay Toggle + Shuffle
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
                              // Smart Autoplay Toggle Pill
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

                      // SEDANG DIPUTAR Card
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

                      // Upcoming Queue List (Spotify Sections: User Queue -> Context -> Autoplay)
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
