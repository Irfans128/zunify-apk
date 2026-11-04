import 'dart:async';
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

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool _showLyricsView = false;
  final ScrollController _lyricsScrollController = ScrollController();
  int _lastScrolledLyricIdx = -2;
  String? _lastSongId;
  bool _userScrollingLyrics = false;
  Timer? _resumeAutoScrollTimer;

  @override
  void dispose() {
    _resumeAutoScrollTimer?.cancel();
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

  void _autoScrollLyrics(String videoId, int activeIdx, int totalLines) {
    if (!_showLyricsView || _userScrollingLyrics) return;
    if (_lastSongId == videoId && activeIdx == _lastScrolledLyricIdx) return;
    _lastSongId = videoId;
    _lastScrolledLyricIdx = activeIdx;

    if (activeIdx < 0) {
      if (_lyricsScrollController.hasClients) {
        _lyricsScrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
        );
      }
      return;
    }

    final itemKey = GlobalObjectKey('lyric_${videoId}_$activeIdx');
    final ctx = itemKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.30,
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    if (_lyricsScrollController.hasClients && totalLines > 0) {
      final maxExtent = _lyricsScrollController.position.maxScrollExtent;
      final approxOffset =
          ((activeIdx / totalLines) * maxExtent).clamp(0.0, maxExtent);
      _lyricsScrollController.animateTo(
        approxOffset,
        duration: const Duration(milliseconds: 380),
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
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 10),
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
                const SizedBox(height: 6),

                // Responsive Centerpiece: Adaptive Vinyl + Compact Lyrics Pill OR Full Smooth Lyrics
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
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 260),
                      child: _showLyricsView
                          ? _buildSmoothLyricsView(
                              song.videoId,
                              player,
                              accent,
                            )
                          : LayoutBuilder(
                              key: const ValueKey('vinyl_view'),
                              builder: (context, constraints) {
                                final availableForVinyl =
                                    (constraints.maxHeight - 148)
                                        .clamp(150.0, 224.0);
                                return Column(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceEvenly,
                                  children: [
                                    VinylDiscWidget(
                                      imageUrl: song.highResArtUrl,
                                      localImagePath: song.localArtPath,
                                      isPlaying: player.isPlaying,
                                      accentColor: accent,
                                      size: availableForVinyl,
                                    ),
                                    _buildLiveLyricsGlassCard(player, accent),
                                  ],
                                );
                              },
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 10),

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
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.68),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
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
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2.5,
                      ),
                      decoration: BoxDecoration(
                        color: player.showTranslation
                            ? accent.withOpacity(0.22)
                            : Colors.white.withOpacity(0.09),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.translate_rounded,
                            color:
                                player.showTranslation ? accent : Colors.white70,
                            size: 10.5,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            player.isTranslatingLyrics
                                ? 'Proses...'
                                : (player.showTranslation
                                    ? 'Terjemahan ON'
                                    : 'Terjemahkan'),
                            style: TextStyle(
                              color: player.showTranslation
                                  ? accent
                                  : Colors.white70,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
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
                              ? '♪ Intro Musik...'
                              : (activeLine.originalText.isEmpty
                                  ? '♪ • • • ♪'
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

  /// Smooth, Beat-Accurate, Clean Lyrics View (Spotify / Apple Music Style)
  Widget _buildSmoothLyricsView(
    String videoId,
    PlayerProvider player,
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
        // Symmetrical Top Toolbar: Manual Translate Button (Left) • Sync Offset (Right)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (lyrics.shouldShowTranslation)
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
                              : (player.showTranslation
                                  ? 'Indonesia ON'
                                  : 'Terjemahkan'),
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
                )
              else
                const SizedBox.shrink(),

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

        // Smooth Synced Lyrics Scroll List
        Expanded(
          child: Stack(
            children: [
              NotificationListener<UserScrollNotification>(
                onNotification: (n) {
                  _onUserScrollNotification(n);
                  return false;
                },
                child: ListView.builder(
                  controller: _lyricsScrollController,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.only(top: 28, bottom: 130),
                  itemCount: lyrics.lines.length,
                  itemBuilder: (context, index) {
                    final line = lyrics.lines[index];
                    final activeIdx = player.activeLyricIndex;
                    final isActive = index == activeIdx;
                    final isPassed = activeIdx >= 0 && index < activeIdx;
                    final distance =
                        activeIdx < 0 ? (index + 1) : (index - activeIdx).abs();

                    final double itemOpacity = isActive
                        ? 1.0
                        : (distance == 1
                            ? 0.50
                            : (distance == 2
                                ? 0.32
                                : (isPassed ? 0.20 : 0.24)));

                    final displayText = line.originalText.isEmpty
                        ? '•   •   •'
                        : line.originalText;

                    return InkWell(
                      key: GlobalObjectKey('lyric_${videoId}_$index'),
                      borderRadius: BorderRadius.circular(14),
                      onTap: () {
                        setState(() => _userScrollingLyrics = false);
                        player.seekTo(line.timestamp);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOutCubic,
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? Colors.white.withOpacity(0.06)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: AnimatedScale(
                          scale: isActive ? 1.0 : 0.96,
                          alignment: Alignment.centerLeft,
                          duration: const Duration(milliseconds: 280),
                          curve: Curves.easeOutCubic,
                          child: AnimatedOpacity(
                            duration: const Duration(milliseconds: 240),
                            opacity: itemOpacity,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  displayText,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: isActive ? Colors.white : Colors.white,
                                    fontSize: isActive ? 22 : 18.5,
                                    fontWeight: isActive
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    height: 1.35,
                                    letterSpacing: -0.3,
                                    shadows: isActive
                                        ? [
                                            Shadow(
                                              color: accent.withOpacity(0.45),
                                              blurRadius: 16,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                if (player.showTranslation &&
                                    lyrics.shouldShowTranslation &&
                                    line.translatedIndoText != null &&
                                    line.translatedIndoText!.isNotEmpty) ...[
                                  const SizedBox(height: 5),
                                  Text(
                                    line.translatedIndoText!,
                                    style: GoogleFonts.dmSans(
                                      color: isActive ? accent : Colors.white70,
                                      fontSize: isActive ? 15 : 13.5,
                                      fontStyle: FontStyle.italic,
                                      fontWeight: FontWeight.w600,
                                      height: 1.3,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // "Ikuti Lagu" button when user scrolls manually
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
          ),
        ),
      ],
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
