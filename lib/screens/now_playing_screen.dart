import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/lyric_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/equalizer_sheet.dart';
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

    final targetOffset = (activeIdx * 76.0 - 140.0).clamp(
      0.0,
      _lyricsScrollController.position.maxScrollExtent,
    );
    _lyricsScrollController.animateTo(
      targetOffset,
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final library = context.watch<LibraryProvider>();
    final theme = context.watch<ThemeProvider>();
    final song = player.currentSong;

    if (song == null) {
      return const Scaffold(
        body: Center(child: Text('Belum ada lagu yang diputar')),
      );
    }

    final accent = theme.accentColor;
    final ambient = theme.playerAmbientColor;
    final isFav = library.isFavorite(song.videoId);
    final isDownloaded = library.isDownloaded(song.videoId);
    final downloadProgress = library.activeDownloadProgress[song.videoId];

    // Auto scroll karaoke lyrics when active index advances
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollLyrics(player.activeLyricIndex);
    });

    return Scaffold(
      backgroundColor: theme.scaffoldBgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Dynamic Blurred Album Art Background
          if (song.highResArtUrl.isNotEmpty)
            Opacity(
              opacity: theme.oledPureBlack ? 0.16 : 0.32,
              child: CachedNetworkImage(
                imageUrl: song.highResArtUrl,
                fit: BoxFit.cover,
              ),
            ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 55, sigmaY: 55),
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    ambient.withOpacity(0.28),
                    theme.scaffoldBgColor.withOpacity(0.88),
                    theme.scaffoldBgColor,
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
              child: Column(
                children: [
                  // Top Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: Colors.white,
                          size: 32,
                        ),
                        onPressed: () => Navigator.pop(context),
                      ),
                      Column(
                        children: [
                          Text(
                            player.offlineModeEnabled
                                ? 'MODE OFFLINE • PRIVATE VAULT'
                                : 'ZUNIFY RADIO • ${player.highQualityAudio ? "160 KBPS HQ" : "96 KBPS HEMAT"}',
                            style: TextStyle(
                              color: accent,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            song.album,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      // Toggle Vinyl vs Karaoke Lyrics Button
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: _showLyricsView
                              ? accent.withOpacity(0.22)
                              : Colors.white.withOpacity(0.08),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () => setState(() => _showLyricsView = !_showLyricsView),
                        icon: Icon(
                          _showLyricsView ? Icons.album_rounded : Icons.lyrics_rounded,
                          color: _showLyricsView ? accent : Colors.white,
                          size: 18,
                        ),
                        label: Text(
                          _showLyricsView ? 'Vinyl' : 'Lirik',
                          style: TextStyle(
                            color: _showLyricsView ? accent : Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Centerpiece: Rotating Vinyl Record OR Karaoke Synced Bilingual Lyrics
                  Expanded(
                    child: GestureDetector(
                      onVerticalDragEnd: (details) {
                        if ((details.primaryVelocity ?? 0) < -300 && !_showLyricsView) {
                          setState(() => _showLyricsView = true);
                        } else if ((details.primaryVelocity ?? 0) > 300 && _showLyricsView) {
                          setState(() => _showLyricsView = false);
                        }
                      },
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 350),
                        child: _showLyricsView
                            ? _buildKaraokeLyricsView(player, accent)
                            : Column(
                                key: const ValueKey('vinyl_view'),
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  VinylDiscWidget(
                                    imageUrl: song.highResArtUrl,
                                    localImagePath: song.localArtPath,
                                    isPlaying: player.isPlaying,
                                    accentColor: accent,
                                    size: 275,
                                  ),
                                  const SizedBox(height: 18),
                                  // Compact Live Lyric Preview Pill (Tap / Swipe up for full screen)
                                  _buildMiniLiveLyricPreview(player, accent),
                                ],
                              ),
                      ),
                    ),
                  ),

                  // Song Title, Artist & Favorite Heart
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
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tambah ke Playlist',
                        icon: const Icon(
                          Icons.playlist_add_rounded,
                          color: Colors.white70,
                          size: 28,
                        ),
                        onPressed: () => _showAddToPlaylistSheet(
                          context,
                          library,
                          song,
                          accent,
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: isFav ? accent : Colors.white70,
                          size: 28,
                        ),
                        onPressed: () => library.toggleFavorite(song),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Seek Slider
                  StreamBuilder<Duration>(
                    stream: player.audioPlayer.positionStream,
                    builder: (context, snapshot) {
                      final position = snapshot.data ?? Duration.zero;
                      final total = player.audioPlayer.duration ?? song.duration;
                      final maxSec = total.inSeconds > 0 ? total.inSeconds.toDouble() : 1.0;
                      final curSec = position.inSeconds.toDouble().clamp(0.0, maxSec);

                      return Column(
                        children: [
                          SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: accent,
                              inactiveTrackColor: Colors.white12,
                              thumbColor: accent,
                              trackHeight: 4,
                              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
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
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                                Text(
                                  _formatDuration(total),
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),

                  // Playback Transport Controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shuffle_rounded, color: Colors.white70),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.skip_previous_rounded,
                          color: Colors.white,
                          size: 38,
                        ),
                        onPressed: () => player.playPrevious(),
                      ),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [accent, theme.secondaryAccentColor],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: player.isLoadingTrack
                              ? const SizedBox(
                                  width: 26,
                                  height: 26,
                                  child: CircularProgressIndicator(
                                    color: Colors.black,
                                    strokeWidth: 2.8,
                                  ),
                                )
                              : Icon(
                                  player.isPlaying
                                      ? Icons.pause_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 38,
                                ),
                          onPressed: () => player.togglePlayPause(),
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
                        icon: const Icon(Icons.queue_music_rounded, color: Colors.white70),
                        onPressed: () => _showQueueBottomSheet(context, player, accent),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Quick Action Bar: Download, Sleep Timer, Equalizer, Share Lyric Card
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        // 1. One-Click Private Vault Download
                        _quickActionButton(
                          icon: isDownloaded
                              ? Icons.download_done_rounded
                              : Icons.download_for_offline_outlined,
                          label: downloadProgress != null
                              ? '${(downloadProgress * 100).round()}%'
                              : (isDownloaded ? 'Tersimpan' : 'Download'),
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

                        // 2. Sleep Timer
                        _quickActionButton(
                          icon: Icons.bedtime_outlined,
                          label: player.hasActiveSleepTimer ? 'Timer On' : 'Sleep Timer',
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

                        // 3. Hardware Equalizer
                        _quickActionButton(
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

                        // 4. Share Aesthetic Lyric Card
                        _quickActionButton(
                          icon: Icons.auto_awesome_mosaic_rounded,
                          label: 'Share Card',
                          active: false,
                          accent: accent,
                          onTap: () {
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
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniLiveLyricPreview(PlayerProvider player, Color accent) {
    final lyrics = player.currentLyrics;
    if (player.isLoadingLyrics) {
      return const Text(
        'Memuat lirik sinkron & terjemahan...',
        style: TextStyle(color: Colors.white54, fontSize: 12.5),
      );
    }
    if (lyrics == null || lyrics.lines.isEmpty) {
      return const SizedBox.shrink();
    }
    final idx = player.activeLyricIndex.clamp(0, lyrics.lines.length - 1);
    final line = lyrics.lines[idx];

    return GestureDetector(
      onTap: () => setState(() => _showLyricsView = true),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white10),
        ),
        child: Column(
          children: [
            Text(
              line.originalText,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: accent,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            if (lyrics.shouldShowTranslation && line.translatedIndoText != null) ...[
              const SizedBox(height: 3),
              Text(
                line.translatedIndoText!,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Full-Screen Synced Karaoke Lyrics + Smart Bahasa Indonesia Translation
  Widget _buildKaraokeLyricsView(PlayerProvider player, Color accent) {
    final SyncedLyrics? lyrics = player.currentLyrics;
    if (player.isLoadingLyrics) {
      return Center(
        child: CircularProgressIndicator(color: accent),
      );
    }
    if (lyrics == null || lyrics.lines.isEmpty) {
      return const Center(
        child: Text(
          'Lirik belum tersedia untuk lagu ini',
          style: TextStyle(color: Colors.white60),
        ),
      );
    }

    return Column(
      key: const ValueKey('lyrics_view'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Status Badge (Shows whether Indonesian Translation is active or auto-hidden)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  lyrics.isOriginalIndonesian
                      ? '🇮🇩 Lirik Bahasa Indonesia (Tanpa Terjemahan)'
                      : '🌐 Lirik Sinkron + Terjemahan Indonesia',
                  style: TextStyle(
                    color: accent,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const Text(
                'Ketuk baris untuk lompat detik',
                style: TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
        ),

        Expanded(
          child: ListView.builder(
            controller: _lyricsScrollController,
            padding: const EdgeInsets.symmetric(vertical: 28),
            itemCount: lyrics.lines.length,
            itemBuilder: (context, index) {
              final line = lyrics.lines[index];
              final isActive = index == player.activeLyricIndex;

              return GestureDetector(
                onTap: () => player.seekTo(line.timestamp),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 280),
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isActive
                        ? accent.withOpacity(0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    border: isActive
                        ? Border.all(color: accent.withOpacity(0.35))
                        : null,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Primary Original Lyric Line
                      Text(
                        line.originalText,
                        style: TextStyle(
                          color: isActive ? Colors.white : Colors.white38,
                          fontSize: isActive ? 20.5 : 16.5,
                          fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                          height: 1.3,
                        ),
                      ),

                      // Indonesian Translation Line (Hidden automatically if song is Indonesian!)
                      if (lyrics.shouldShowTranslation &&
                          line.translatedIndoText != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          line.translatedIndoText!,
                          style: TextStyle(
                            color: isActive
                                ? accent.withOpacity(0.95)
                                : Colors.white24,
                            fontSize: isActive ? 14.5 : 13.0,
                            fontStyle: FontStyle.italic,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _quickActionButton({
    required IconData icon,
    required String label,
    required bool active,
    required Color accent,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: active ? accent : Colors.white70,
              size: 22,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: active ? accent : Colors.white60,
                fontSize: 11,
                fontWeight: active ? FontWeight.bold : FontWeight.normal,
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
      backgroundColor: const Color(0xFF10131C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: accent, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Antrean Up Next • Algoritma Radio Zunify',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: ListView.builder(
                  itemCount: player.queue.length,
                  itemBuilder: (ctx, i) {
                    final item = player.queue[i];
                    final isCurrent = i == player.currentIndex;
                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: CachedNetworkImage(
                          imageUrl: item.thumbnailUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isCurrent ? accent : Colors.white,
                          fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
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
      backgroundColor: const Color(0xFF10131C),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Simpan Lagu ke Playlist 🎵',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              if (library.playlists.isEmpty)
                ListTile(
                  leading: Icon(Icons.add_circle_outline_rounded, color: accent),
                  title: const Text(
                    'Buat Playlist Pertama ("Favorit Fannz")',
                    style: TextStyle(color: Colors.white),
                  ),
                  onTap: () async {
                    await library.createLocalPlaylist('Favorit Fannz', 'Koleksi pilihan');
                    if (library.playlists.isNotEmpty) {
                      await library.addSongToPlaylist(library.playlists.first.id, song);
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                  },
                )
              else
                ...library.playlists.map((pl) {
                  return ListTile(
                    leading: Icon(Icons.queue_music_rounded, color: accent),
                    title: Text(
                      pl.name,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${pl.songs.length} lagu',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    onTap: () async {
                      await library.addSongToPlaylist(pl.id, song);
                      if (ctx.mounted) Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: accent,
                          content: Text(
                            'Ditambahkan ke "${pl.name}"!',
                            style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      );
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
