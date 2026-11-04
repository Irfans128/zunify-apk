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

  @override
  void dispose() {
    _lyricsScrollController.dispose();
    super.dispose();
  }

  void _autoScrollLyrics(int activeIdx) {
    if (!_showLyricsView || !_lyricsScrollController.hasClients) return;
    if (activeIdx == _lastScrolledLyricIdx) return;
    _lastScrolledLyricIdx = activeIdx;

    final targetOffset = (activeIdx * 92.0 - 140.0).clamp(
      0.0,
      _lyricsScrollController.position.maxScrollExtent,
    );
    _lyricsScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
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

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollLyrics(player.activeLyricIndex);
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
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
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
                            onTap: () => setState(() => _showLyricsView = true),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Bagikan Kartu Lirik',
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

                // Centerpiece: Vinyl + Spectrum + Glass Lyrics Card OR Full Ambient Blur Lyrics
                Expanded(
                  child: GestureDetector(
                    onVerticalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) < -280 &&
                          !_showLyricsView) {
                        setState(() => _showLyricsView = true);
                      } else if ((details.primaryVelocity ?? 0) > 280 &&
                          _showLyricsView) {
                        setState(() => _showLyricsView = false);
                      }
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 360),
                      child: _showLyricsView
                          ? _buildAmbientBlurLyricsView(player, accent)
                          : Column(
                              key: const ValueKey('vinyl_view'),
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                VinylDiscWidget(
                                  imageUrl: song.highResArtUrl,
                                  localImagePath: song.localArtPath,
                                  isPlaying: player.isPlaying,
                                  accentColor: accent,
                                  size: 232,
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

                // Floating Frosted Bottom Dock: Lirik • Equalizer • Sleep Timer • Download • Antrean
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
                        border: Border.all(color: Colors.white.withOpacity(0.12)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _dockIcon(
                            icon: Icons.lyrics_rounded,
                            label: 'Lirik',
                            active: _showLyricsView,
                            accent: accent,
                            onTap: () => setState(
                              () => _showLyricsView = !_showLyricsView,
                            ),
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
                            label: 'Antrean',
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

  /// Upgrade B: AusDMusic / Spotify-style Frosted Glass Live Lyrics Preview Card
  /// Displays directly below the Vinyl disc so the user always sees live synced lyrics + translation!
  Widget _buildLiveLyricsGlassCard(PlayerProvider player, Color accent) {
    final lyrics = player.currentLyrics;
    final isLoading = player.isLoadingLyrics;

    return GestureDetector(
      onTap: () => setState(() => _showLyricsView = true),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
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
                // Card Top Header: Spectrum + Source Badge + Expand Pill
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
                    if (lyrics != null && lyrics.lines.length > 1) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          lyrics.sourceName,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                    const Spacer(),
                    const Text(
                      'Layar Penuh',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 3),
                    const Icon(
                      Icons.open_in_full_rounded,
                      color: Colors.white54,
                      size: 12,
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
                      final idx = player.activeLyricIndex
                          .clamp(0, lyrics.lines.length - 1);
                      final activeLine = lyrics.lines[idx];
                      final nextLine = idx + 1 < lyrics.lines.length
                          ? lyrics.lines[idx + 1]
                          : null;

                      return Column(
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
                      );
                    },
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Upgrade D: Apple Music / AusDMusic Karaoke Glow + Ambient Blur Lyrics View
  Widget _buildAmbientBlurLyricsView(PlayerProvider player, Color accent) {
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
      key: const ValueKey('ambient_lyrics_view'),
      children: [
        // AusDMusic-style Lyrics Control Strip: Source • Terjemahan Toggle • Offset Sync
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.16),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: accent.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.verified_rounded, color: accent, size: 13),
                      const SizedBox(width: 5),
                      Text(
                        lyrics.sourceName,
                        style: TextStyle(
                          color: accent,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (lyrics.shouldShowTranslation)
                  GestureDetector(
                    onTap: () => player.toggleTranslationDisplay(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: player.showTranslation
                            ? Colors.white.withOpacity(0.18)
                            : Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.translate_rounded,
                            color: player.showTranslation
                                ? Colors.white
                                : Colors.white54,
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            player.isTranslatingLyrics
                                ? 'Menerjemahkan...'
                                : (player.showTranslation
                                    ? 'Terjemahan ID: ON'
                                    : 'Terjemahan ID: OFF'),
                            style: TextStyle(
                              color: player.showTranslation
                                  ? Colors.white
                                  : Colors.white54,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                // Sync Offset Adjuster (-0.5s / +0.5s) like AusDMusic
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.07),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      GestureDetector(
                        onTap: () => player.adjustLyricsOffset(-500),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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

        // Main Synced Karaoke Scroll List
        Expanded(
          child: ListView.builder(
            controller: _lyricsScrollController,
            padding: const EdgeInsets.symmetric(vertical: 48),
            itemCount: lyrics.lines.length,
            itemBuilder: (context, index) {
              final line = lyrics.lines[index];
              final isActive = index == player.activeLyricIndex;
              final distance = (index - player.activeLyricIndex).abs();
              final blurSigma = isActive ? 0.0 : (distance == 1 ? 1.0 : 2.1);

              return GestureDetector(
                onTap: () => player.seekTo(line.timestamp),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 340),
                  curve: Curves.easeOutCubic,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: EdgeInsets.symmetric(
                    horizontal: isActive ? 14 : 10,
                    vertical: isActive ? 12 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withOpacity(0.09)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(18),
                    border: isActive
                        ? Border.all(color: accent.withOpacity(0.38), width: 1.2)
                        : null,
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: accent.withOpacity(0.14),
                              blurRadius: 20,
                              spreadRadius: 1,
                            ),
                          ]
                        : null,
                  ),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                    ),
                    child: AnimatedOpacity(
                      duration: const Duration(milliseconds: 320),
                      opacity: isActive ? 1.0 : (distance == 1 ? 0.46 : 0.25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isActive) ...[
                                Padding(
                                  padding: const EdgeInsets.only(
                                    top: 4,
                                    right: 8,
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
                                    height: 1.32,
                                    letterSpacing: -0.3,
                                    shadows: isActive
                                        ? [
                                            Shadow(
                                              color: accent.withOpacity(0.45),
                                              blurRadius: 18,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Automatic Indonesian Translation (Hidden if song is already Indonesian)
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

  void _showQueueBottomSheet(
    BuildContext context,
    PlayerProvider player,
    Color accent,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0E111A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Antrean Berikutnya',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: player.queue.length,
                  itemBuilder: (ctx, i) {
                    final item = player.queue[i];
                    final isCurrent = i == player.currentIndex;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: item.thumbnailUrl,
                          width: 46,
                          height: 46,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent ? accent : Colors.white,
                          fontWeight:
                              isCurrent ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        item.artist,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      trailing: isCurrent
                          ? MiniAudioSpectrumBars(
                              isPlaying: player.isPlaying,
                              color: accent,
                              height: 16,
                            )
                          : null,
                      onTap: () {
                        Navigator.pop(ctx);
                        player.playSong(item, customQueue: player.queue);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
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
