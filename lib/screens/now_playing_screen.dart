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

    final targetOffset = (activeIdx * 84.0 - 150.0).clamp(
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
        intensity: _showLyricsView ? 0.58 : 0.45,
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
            child: Column(
              children: [
                // Minimalist Clean Top Bar: Collapse • Pill Switcher • Share Button
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

                    // Clean Vinyl / LirikSegmented Pill
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
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
                            label: 'Lirik',
                            selected: _showLyricsView,
                            accent: accent,
                            onTap: () => setState(() => _showLyricsView = true),
                          ),
                        ],
                      ),
                    ),

                    // Dedicated Share Button at Top-Right (Clean & Accessible)
                    IconButton(
                      icon: const Icon(
                        Icons.ios_share_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                      onPressed: () => _openShareModal(context, player),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Centerpiece: Vinyl Disc OR Ambient Blur Aesthetic Lyrics
                Expanded(
                  child: GestureDetector(
                    onVerticalDragEnd: (details) {
                      if ((details.primaryVelocity ?? 0) < -280 && !_showLyricsView) {
                        setState(() => _showLyricsView = true);
                      } else if ((details.primaryVelocity ?? 0) > 280 && _showLyricsView) {
                        setState(() => _showLyricsView = false);
                      }
                    },
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 380),
                      child: _showLyricsView
                          ? _buildAmbientBlurLyricsView(player, accent)
                          : Column(
                              key: const ValueKey('vinyl_view'),
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                VinylDiscWidget(
                                  imageUrl: song.highResArtUrl,
                                  localImagePath: song.localArtPath,
                                  isPlaying: player.isPlaying,
                                  accentColor: accent,
                                  size: 270,
                                ),
                                const SizedBox(height: 24),
                                _buildMinimalFloatingLyricLine(player, accent),
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
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            song.artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.68),
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
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
                        isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isFav ? accent : Colors.white70,
                        size: 26,
                      ),
                      onPressed: () => library.toggleFavorite(song),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Sleek Seek Bar
                StreamBuilder<Duration>(
                  stream: player.audioPlayer.positionStream,
                  builder: (context, snapshot) {
                    final position = snapshot.data ?? Duration.zero;
                    final total = player.audioPlayer.duration ?? song.duration;
                    final maxSec =
                        total.inSeconds > 0 ? total.inSeconds.toDouble() : 1.0;
                    final curSec = position.inSeconds.toDouble().clamp(0.0, maxSec);

                    return Column(
                      children: [
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: Colors.white,
                            inactiveTrackColor: Colors.white.withOpacity(0.16),
                            thumbColor: Colors.white,
                            trackHeight: 3.5,
                            overlayShape:
                                const RoundSliderOverlayShape(overlayRadius: 12),
                            thumbShape:
                                const RoundSliderThumbShape(enabledThumbRadius: 5.5),
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
                                  color: Colors.white54,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                _formatDuration(total),
                                style: const TextStyle(
                                  color: Colors.white54,
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
                const SizedBox(height: 10),

                // Main Transport Controls
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      icon: Icon(
                        Icons.equalizer_rounded,
                        color: player.eqEnabled ? accent : Colors.white60,
                        size: 24,
                      ),
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (_) => const EqualizerSheet(),
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.skip_previous_rounded,
                        color: Colors.white,
                        size: 40,
                      ),
                      onPressed: () => player.playPrevious(),
                    ),
                    GestureDetector(
                      onTap: () => player.togglePlayPause(),
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withOpacity(0.25),
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
                        size: 40,
                      ),
                      onPressed: () => player.playNext(),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.queue_music_rounded,
                        color: Colors.white60,
                        size: 24,
                      ),
                      onPressed: () => _showQueueBottomSheet(context, player, accent),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Minimalist Floating Bottom Dock (Lyrics • Sleep Timer • Download • Share)
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.06),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Colors.white.withOpacity(0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _dockIcon(
                            icon: Icons.lyrics_outlined,
                            active: _showLyricsView,
                            accent: accent,
                            onTap: () =>
                                setState(() => _showLyricsView = !_showLyricsView),
                          ),
                          _dockIcon(
                            icon: Icons.bedtime_outlined,
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
                            icon: Icons.auto_awesome_mosaic_rounded,
                            active: false,
                            accent: accent,
                            onTap: () => _openShareModal(context, player),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ),
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.white.withOpacity(0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : Colors.white54,
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _dockIcon({
    required IconData icon,
    required bool active,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Icon(
          icon,
          color: active ? accent : Colors.white70,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildMinimalFloatingLyricLine(PlayerProvider player, Color accent) {
    final lyrics = player.currentLyrics;
    if (player.isLoadingLyrics || lyrics == null || lyrics.lines.isEmpty) {
      return const SizedBox(height: 36);
    }
    final idx = player.activeLyricIndex.clamp(0, lyrics.lines.length - 1);
    final line = lyrics.lines[idx];

    return GestureDetector(
      onTap: () => setState(() => _showLyricsView = true),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Column(
          children: [
            Text(
              line.originalText,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 15,
              ),
            ),
            if (lyrics.shouldShowTranslation && line.translatedIndoText != null) ...[
              const SizedBox(height: 3),
              Text(
                line.translatedIndoText!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white60,
                  fontSize: 12.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Ambient Blur Live Lyrics + Aesthetic Font View
  /// Active line is crisp, scaled, and glowing; inactive lines have subtle optical blur.
  Widget _buildAmbientBlurLyricsView(PlayerProvider player, Color accent) {
    final SyncedLyrics? lyrics = player.currentLyrics;
    if (player.isLoadingLyrics) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white70),
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

    return ListView.builder(
      key: const ValueKey('ambient_lyrics_view'),
      controller: _lyricsScrollController,
      padding: const EdgeInsets.symmetric(vertical: 60),
      itemCount: lyrics.lines.length,
      itemBuilder: (context, index) {
        final line = lyrics.lines[index];
        final isActive = index == player.activeLyricIndex;
        final distance = (index - player.activeLyricIndex).abs();
        final blurSigma = isActive ? 0.0 : (distance == 1 ? 1.2 : 2.2);

        return GestureDetector(
          onTap: () => player.seekTo(line.timestamp),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 340),
            curve: Curves.easeOutCubic,
            margin: const EdgeInsets.symmetric(vertical: 12),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            child: ImageFiltered(
              imageFilter: ImageFilter.blur(
                sigmaX: blurSigma,
                sigmaY: blurSigma,
              ),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 320),
                opacity: isActive ? 1.0 : (distance == 1 ? 0.42 : 0.24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Aesthetic Main Lyric Line
                    Text(
                      line.originalText,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: isActive ? 24 : 19,
                        fontWeight: isActive ? FontWeight.w800 : FontWeight.w700,
                        height: 1.32,
                        letterSpacing: -0.3,
                        shadows: isActive
                            ? [
                                Shadow(
                                  color: Colors.white.withOpacity(0.35),
                                  blurRadius: 18,
                                ),
                              ]
                            : null,
                      ),
                    ),

                    // Automatic Indonesian Translation (Hidden if song is already Indonesian)
                    if (lyrics.shouldShowTranslation &&
                        line.translatedIndoText != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        line.translatedIndoText!,
                        style: GoogleFonts.dmSans(
                          color: isActive ? accent : Colors.white70,
                          fontSize: isActive ? 15.5 : 13.5,
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.w500,
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
                'Berikutnya',
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
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.w500,
                        ),
                      ),
                      subtitle: Text(
                        item.artist,
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                      trailing: isCurrent
                          ? Icon(Icons.graphic_eq_rounded, color: accent)
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
                      await library.addSongToPlaylist(library.playlists.first.id, song);
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
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
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
