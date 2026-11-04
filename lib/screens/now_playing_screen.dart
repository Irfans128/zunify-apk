import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
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
import '../widgets/vinyl_disc_widget.dart';

class NowPlayingScreen extends StatefulWidget {
  const NowPlayingScreen({super.key});

  @override
  State<NowPlayingScreen> createState() => _NowPlayingScreenState();
}

class _NowPlayingScreenState extends State<NowPlayingScreen> {
  bool _showLyricsView = false;
  final ScrollController _lyricsScrollController = ScrollController();
  int _lastScrolledLyricIdx = -1;
  String? _lastSongId;

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    super.dispose();
  }

  void _autoScrollLyrics(String videoId, int activeIdx, int totalLines) {
    if (!_showLyricsView) return;
    if (_lastSongId == videoId && activeIdx == _lastScrolledLyricIdx) return;
    _lastSongId = videoId;
    _lastScrolledLyricIdx = activeIdx;

    // Try precision GlobalObjectKey centering first for butter-smooth variable-height scrolling
    final itemKey = GlobalObjectKey('lyric_${videoId}_$activeIdx');
    final ctx = itemKey.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(
        ctx,
        alignment: 0.34,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
      return;
    }

    // Fallback proportional offset if target item is offscreen
    if (_lyricsScrollController.hasClients && totalLines > 0) {
      final maxExtent = _lyricsScrollController.position.maxScrollExtent;
      final approxOffset =
          ((activeIdx / totalLines) * maxExtent).clamp(0.0, maxExtent);
      _lyricsScrollController.animateTo(
        approxOffset,
        duration: const Duration(milliseconds: 420),
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
        initialLyricIndex: player.activeLyricIndex,
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
        intensity: _showLyricsView ? 0.60 : 0.48,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 6),
            child: Column(
              children: [
                // Top Bar: Collapse • Segmented Mode Pill • Share Button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: const Icon(
                        Icons.keyboard_arrow_down_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                      onPressed: () => Navigator.pop(context),
                    ),
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
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
                            label: 'Lirik Karaoke',
                            selected: _showLyricsView,
                            accent: accent,
                            onTap: () {
                              setState(() {
                                _showLyricsView = true;
                                _lastScrolledLyricIdx = -1;
                              });
                            },
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Bagikan Lirik / Lagu ke SW',
                      icon: const Icon(
                        Icons.ios_share_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () => _openShareModal(context, player),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                // Centerpiece: Vinyl + Spectrum + Glass Lyrics Card OR Smooth 120fps Karaoke Lyrics
                Expanded(
                  child: GestureDetector(
                    onVerticalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) < -280 &&
                          !_showLyricsView) {
                        setState(() {
                          _showLyricsView = true;
                          _lastScrolledLyricIdx = -1;
                        });
                      } else if ((details.primaryVelocity ?? 0) > 280 &&
                          _showLyricsView) {
                        setState(() => _showLyricsView = false);
                      }
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 320),
                      child: _showLyricsView
                          ? _buildSmoothKaraokeLyricsView(
                              song.videoId,
                              player,
                              accent,
                            )
                          : Column(
                              key: const ValueKey('vinyl_view'),
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                VinylDiscWidget(
                                  imageUrl: song.highResArtUrl,
                                  localImagePath: song.localArtPath,
                                  isPlaying: player.isPlaying,
                                  accentColor: accent,
                                  size: 228,
                                ),
                                _buildLiveLyricsGlassCard(player, accent),
                              ],
                            ),
                    ),
                  ),
                ),

                const SizedBox(height: 8),

                // Song Info + Add to Playlist + Love
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
                              fontSize: 21,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.70),
                                    fontSize: 14.5,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: accent.withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: accent.withOpacity(0.35),
                                  ),
                                ),
                                child: Text(
                                  player.highQualityAudio ? 'HQ AAC' : 'HEMAT',
                                  style: TextStyle(
                                    color: accent,
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.playlist_add_rounded,
                        color: Colors.white70,
                        size: 26,
                      ),
                      onPressed: () =>
                          _showAddToPlaylistSheet(context, library, song, accent),
                    ),
                    IconButton(
                      icon: Icon(
                        isFav
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        color: isFav ? accent : Colors.white70,
                        size: 26,
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
                    final maxSec =
                        total.inSeconds > 0 ? total.inSeconds.toDouble() : 1.0;
                    final curSec =
                        position.inSeconds.toDouble().clamp(0.0, maxSec);

                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: accent,
                            inactiveTrackColor: Colors.white.withOpacity(0.16),
                            thumbColor: Colors.white,
                            trackHeight: 3.8,
                            overlayShape: const RoundSliderOverlayShape(
                              overlayRadius: 12,
                            ),
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 6,
                            ),
                          ),
                          child: Slider(
                            value: curSec,
                            min: 0,
                            max: maxSec,
                            onChanged: (v) =>
                                player.seekTo(Duration(seconds: v.round())),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _formatDuration(position),
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatDuration(total),
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11.5,
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

                // Main Transport Controls: Shuffle • Prev • Play/Pause • Next • Repeat
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      tooltip: 'Acak Lagu (Shuffle)',
                      icon: Icon(
                        Icons.shuffle_rounded,
                        color: player.shuffleEnabled ? accent : Colors.white54,
                        size: 23,
                      ),
                      onPressed: () => player.toggleShuffle(),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                      onPressed: () => player.playPrevious(),
                    ),
                    GestureDetector(
                      onTap: () => player.togglePlayPause(),
                      child: Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [Colors.white, accent.withOpacity(0.9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.38),
                              blurRadius: 24,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: player.isLoadingTrack
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  color: Colors.black,
                                  strokeWidth: 2.6,
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
                    IconButton(
                      icon: const Icon(
                        Icons.skip_next_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                      onPressed: () => player.playNext(),
                    ),
                    IconButton(
                      tooltip: 'Mode Ulang (Repeat)',
                      icon: Icon(
                        player.repeatMode == 2
                            ? Icons.repeat_one_rounded
                            : Icons.repeat_rounded,
                        color: player.repeatMode > 0 ? accent : Colors.white54,
                        size: 23,
                      ),
                      onPressed: () => player.cycleRepeatMode(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Floating Frosted Bottom Dock: Lirik • Equalizer • Timer • Download • Antrean
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _dockIcon(
                            icon: Icons.lyrics_rounded,
                            label: 'Lirik',
                            active: _showLyricsView,
                            accent: accent,
                            onTap: () => setState(() {
                              _showLyricsView = !_showLyricsView;
                              _lastScrolledLyricIdx = -1;
                            }),
                          ),
                          _dockIcon(
                            icon: Icons.equalizer_rounded,
                            label: 'DSP EQ',
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
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    value: downloadProgress,
                                    color: accent,
                                    strokeWidth: 2.4,
                                  ),
                                )
                              : _dockIcon(
                                  icon: isDownloaded
                                      ? Icons.download_done_rounded
                                      : Icons.download_rounded,
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
                            label: 'Antrean (${player.queue.length})',
                            active: false,
                            accent: accent,
                            onTap: () =>
                                _showQueueBottomSheet(context, player, accent),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Frosted Glass Live Lyrics Preview Card below Vinyl Disc
  Widget _buildLiveLyricsGlassCard(PlayerProvider player, Color accent) {
    final lyrics = player.currentLyrics;
    final isLoading = player.isLoadingLyrics;

    return GestureDetector(
      onTap: () => setState(() {
        _showLyricsView = true;
        _lastScrolledLyricIdx = -1;
      }),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Card Top Header: Spectrum + Source Badge + Manual Translate Button + Expand
            Row(
              children: [
                MiniAudioSpectrumBars(
                  isPlaying: player.isPlaying,
                  color: accent,
                  height: 12,
                ),
                const SizedBox(width: 7),
                Text(
                  'LIRIK LIVE',
                  style: TextStyle(
                    color: accent,
                    fontSize: 10.5,
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
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: player.showTranslation
                            ? accent.withOpacity(0.22)
                            : Colors.white.withOpacity(0.10),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: player.showTranslation
                              ? accent.withOpacity(0.55)
                              : Colors.white24,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.translate_rounded,
                            color:
                                player.showTranslation ? accent : Colors.white70,
                            size: 11,
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
                  color: Colors.white54,
                  size: 13,
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (isLoading)
              Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      color: accent,
                      strokeWidth: 2,
                    ),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Memuat lirik tersinkronisasi...',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              )
            else if (lyrics == null || lyrics.lines.isEmpty)
              const Text(
                '♪ Instrumental / Lirik belum tersedia ♪',
                style: TextStyle(color: Colors.white60, fontSize: 13.5),
              )
            else ...[
              Builder(
                builder: (context) {
                  final idx =
                      player.activeLyricIndex.clamp(0, lyrics.lines.length - 1);
                  final activeLine = lyrics.lines[idx];
                  final nextLine = idx + 1 < lyrics.lines.length
                      ? lyrics.lines[idx + 1]
                      : null;

                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 260),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0, 0.16),
                          end: Offset.zero,
                        ).animate(anim),
                        child: child,
                      ),
                    ),
                    child: Column(
                      key: ValueKey('preview_line_$idx'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activeLine.originalText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                            height: 1.28,
                          ),
                        ),
                        if (player.showTranslation &&
                            lyrics.shouldShowTranslation &&
                            activeLine.translatedIndoText != null) ...[
                          const SizedBox(height: 3),
                          Text(
                            activeLine.translatedIndoText!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.dmSans(
                              color: accent,
                              fontSize: 13,
                              fontStyle: FontStyle.italic,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ] else if (nextLine != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            nextLine.originalText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white38,
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Butter-Smooth 120fps Karaoke Lyrics View (Zero GPU `ImageFilter.blur` jank!)
  /// Uses hardware-accelerated `AnimatedScale` + `AnimatedOpacity` + soft optical `Shadow`
  /// and a dedicated Manual Translation Button ("🌐 Terjemahkan ke Indonesia").
  Widget _buildSmoothKaraokeLyricsView(
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
              'Mencari lirik sinkronisasi terbaik...',
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
      key: const ValueKey('smooth_karaoke_lyrics_view'),
      children: [
        // Top Control Bar: Source Badge • Manual "Terjemahkan" Button • Sync Offset
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Manual Translate Toggle Button (Primary CTA)
                if (lyrics.shouldShowTranslation)
                  GestureDetector(
                    onTap: () => player.toggleTranslationDisplay(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: player.showTranslation
                            ? accent
                            : Colors.white.withOpacity(0.11),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: player.showTranslation
                              ? accent
                              : Colors.white.withOpacity(0.22),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (player.isTranslatingLyrics) ...[
                            SizedBox(
                              width: 12,
                              height: 12,
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
                              size: 14,
                            ),
                            const SizedBox(width: 5),
                          ],
                          Text(
                            player.isTranslatingLyrics
                                ? 'Menerjemahkan...'
                                : (player.showTranslation
                                    ? 'Sembunyikan Terjemahan'
                                    : 'Terjemahkan ke Indonesia'),
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
                if (lyrics.shouldShowTranslation) const SizedBox(width: 8),

                // Source Badge
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, color: accent, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        lyrics.sourceName,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Sync Offset Adjuster (-0.5s / +0.5s)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => player.adjustLyricsOffset(-500),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            '-0.5s',
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
                            '${(player.lyricsOffsetMs / 1000).toStringAsFixed(1)}s',
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
                        onTap: () => player.adjustLyricsOffset(500),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          child: Text(
                            '+0.5s',
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
        ),

        // Butter-Smooth 60/120fps Synced Karaoke Scroll List
        Expanded(
          child: ListView.builder(
            controller: _lyricsScrollController,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(vertical: 110),
            itemCount: lyrics.lines.length,
            itemBuilder: (context, index) {
              final line = lyrics.lines[index];
              final isActive = index == player.activeLyricIndex;
              final distance = (index - player.activeLyricIndex).abs();
              final itemOpacity = isActive
                  ? 1.0
                  : (distance == 1
                      ? 0.48
                      : (distance == 2 ? 0.28 : 0.18));

              return GestureDetector(
                key: GlobalObjectKey('lyric_${videoId}_$index'),
                onTap: () => player.seekTo(line.timestamp),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 320),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: EdgeInsets.symmetric(
                    horizontal: isActive ? 16 : 12,
                    vertical: isActive ? 14 : 8,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withOpacity(0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                    border: isActive
                        ? Border.all(
                            color: accent.withOpacity(0.45),
                            width: 1.2,
                          )
                        : null,
                  ),
                  child: AnimatedScale(
                    scale: isActive ? 1.02 : 0.96,
                    alignment: Alignment.centerLeft,
                    duration: const Duration(milliseconds: 320),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 280),
                      opacity: itemOpacity,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isActive) ...[
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 5,
                                    right: 10,
                                  ),
                                  child: MiniAudioSpectrumBars(
                                    isPlaying: player.isPlaying,
                                    color: accent,
                                    height: 16,
                                  ),
                                ),
                              ],
                              Expanded(
                                child: Text(
                                  line.originalText,
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontSize: isActive ? 22.5 : 18.5,
                                    fontWeight: isActive
                                        ? FontWeight.w800
                                        : FontWeight.w700,
                                    height: 1.34,
                                    letterSpacing: -0.3,
                                    shadows: isActive
                                        ? [
                                            Shadow(
                                              color: accent.withOpacity(0.48),
                                              blurRadius: 16,
                                            ),
                                          ]
                                        : [
                                            Shadow(
                                              color: Colors.white
                                                  .withOpacity(0.18),
                                              blurRadius:
                                                  distance == 1 ? 3 : 6,
                                            ),
                                          ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // On-Demand Indonesian Translation (Shown only when user taps Terjemahkan)
                          if (player.showTranslation &&
                              lyrics.shouldShowTranslation &&
                              line.translatedIndoText != null) ...[
                            const SizedBox(height: 6),
                            Text(
                              line.translatedIndoText!,
                              style: GoogleFonts.dmSans(
                                color: isActive ? accent : Colors.white70,
                                fontSize: isActive ? 15.5 : 13.5,
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
      ],
    );
  }

  Widget _modePillButton({
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
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
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active ? accent : Colors.white70,
              size: 20,
            ),
            const SizedBox(height: 2),
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

  /// Spotify-style Interactive Queue Bottom Sheet with Drag-and-Drop Reordering
  void _showQueueBottomSheet(
    BuildContext context,
    PlayerProvider player,
    Color accent,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0B0E17),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.92,
          builder: (ctx, scrollCtrl) {
            return Consumer<PlayerProvider>(
              builder: (context, livePlayer, _) {
                final currentSong = livePlayer.currentSong;
                return Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                  child: Column(
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
                          const Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Antrean Pemutaran',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 19,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Tahan & geser ikon ≡ untuk ubah urutan lagu',
                                style: TextStyle(
                                  color: Colors.white54,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              IconButton(
                                tooltip: 'Acak Antrean',
                                icon: Icon(
                                  Icons.shuffle_rounded,
                                  color: livePlayer.shuffleEnabled
                                      ? accent
                                      : Colors.white60,
                                ),
                                onPressed: () => livePlayer.toggleShuffle(),
                              ),
                              if (livePlayer.queue.length >
                                  livePlayer.currentIndex + 1)
                                TextButton(
                                  onPressed: () =>
                                      livePlayer.clearUpcomingQueue(),
                                  child: Text(
                                    'Bersihkan',
                                    style: TextStyle(
                                      color: accent,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Now Playing Highlight Card
                      if (currentSong != null) ...[
                        Text(
                          'SEDANG DIPUTAR',
                          style: TextStyle(
                            color: accent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: accent.withOpacity(0.4)),
                          ),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: currentSong.highResArtUrl,
                                  width: 46,
                                  height: 46,
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
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              MiniAudioSpectrumBars(
                                isPlaying: livePlayer.isPlaying,
                                color: accent,
                                height: 16,
                              ),
                              const SizedBox(width: 6),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      const Text(
                        'DAFTAR ANTREAN (DRAG UNTUK UBAH URUTAN)',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 6),

                      // Reorderable Queue List
                      Expanded(
                        child: ReorderableListView.builder(
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
                          itemCount: livePlayer.queue.length,
                          onReorder: (oldIdx, newIdx) {
                            livePlayer.reorderQueue(oldIdx, newIdx);
                          },
                          itemBuilder: (ctx, i) {
                            final item = livePlayer.queue[i];
                            final isCurrent = i == livePlayer.currentIndex;
                            return Container(
                              key: ValueKey('queue_${i}_${item.videoId}'),
                              margin: const EdgeInsets.symmetric(vertical: 3),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? accent.withOpacity(0.10)
                                    : Colors.white.withOpacity(0.04),
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.only(
                                  left: 10,
                                  right: 4,
                                ),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(9),
                                  child: CachedNetworkImage(
                                    imageUrl: item.thumbnailUrl,
                                    width: 42,
                                    height: 42,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                                title: Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: isCurrent ? accent : Colors.white,
                                    fontWeight: isCurrent
                                        ? FontWeight.w800
                                        : FontWeight.w600,
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
                                    if (!isCurrent &&
                                        livePlayer.queue.length > 1)
                                      IconButton(
                                        visualDensity: VisualDensity.compact,
                                        tooltip: 'Hapus dari antrean',
                                        icon: const Icon(
                                          Icons.close_rounded,
                                          color: Colors.white38,
                                          size: 18,
                                        ),
                                        onPressed: () =>
                                            livePlayer.removeFromQueue(i),
                                      ),
                                    ReorderableDragStartListener(
                                      index: i,
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 8,
                                        ),
                                        child: Icon(
                                          Icons.drag_handle_rounded,
                                          color: Colors.white54,
                                          size: 22,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                onTap: () {
                                  livePlayer.jumpToQueueIndex(i);
                                },
                              ),
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

  void _showAddToPlaylistSheet(
    BuildContext context,
    LibraryProvider library,
    dynamic song,
    Color accent,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E111A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Tambah ke Playlist',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              if (library.playlists.isEmpty)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.add_circle_outline_rounded, color: accent),
                  title: const Text(
                    'Buat Playlist Baru',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    await library.createLocalPlaylist('Favoritku', '');
                    if (library.playlists.isNotEmpty) {
                      await library.addSongToPlaylist(
                        library.playlists.first.id,
                        song,
                      );
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                )
              else
                ...library.playlists.map((pl) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.queue_music_rounded, color: accent),
                    title: Text(
                      pl.name,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${pl.songs.length} lagu',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    onTap: () async {
                      await library.addSongToPlaylist(pl.id, song);
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  );
                }),
            ],
          ),
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
