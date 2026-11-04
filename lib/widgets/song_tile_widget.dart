import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import 'share_card_modal.dart';
import 'vinyl_disc_widget.dart';

/// Clean Modern Song Row (Spotify / Apple Music style)
/// Displays cover art, title, artist, subtle status badges, and a single clean `⋮` menu button.
class ZunifySongTile extends StatelessWidget {
  final ZunifySong song;
  final List<ZunifySong> queueContext;
  final String? contextName;
  final int? rank;
  final String? playlistIdForRemoval;
  final VoidCallback? onTapOverride;

  const ZunifySongTile({
    super.key,
    required this.song,
    required this.queueContext,
    this.contextName,
    this.rank,
    this.playlistIdForRemoval,
    this.onTapOverride,
  });

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final library = context.watch<LibraryProvider>();
    final theme = context.watch<ThemeProvider>();
    final accent = theme.accentColor;

    final isCurrent = player.currentSong?.videoId == song.videoId;
    final isFav = library.isFavorite(song.videoId);
    final isDownloaded = library.isDownloaded(song.videoId);
    final downloadProgress = library.activeDownloadProgress[song.videoId];

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTapOverride ??
          () => player.playSong(
                song,
                customQueue: queueContext,
                contextName: contextName,
              ),
      onLongPress: () => showSongActionSheet(
        context,
        song: song,
        playlistIdForRemoval: playlistIdForRemoval,
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        margin: const EdgeInsets.only(bottom: 4),
        decoration: BoxDecoration(
          color: isCurrent
              ? accent.withOpacity(0.11)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            if (rank != null) ...[
              SizedBox(
                width: 24,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isCurrent
                        ? accent
                        : (rank! <= 3 ? Colors.white : Colors.white54),
                    fontWeight: rank! <= 3 ? FontWeight.w800 : FontWeight.w600,
                    fontSize: 13.5,
                  ),
                ),
              ),
              const SizedBox(width: 8),
            ],

            // Cover Art Thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: CachedNetworkImage(
                imageUrl: song.thumbnailUrl,
                width: 48,
                height: 48,
                memCacheWidth: 144,
                fadeInDuration: const Duration(milliseconds: 120),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 48,
                  height: 48,
                  color: Colors.white.withOpacity(0.08),
                  child: Icon(Icons.music_note_rounded, color: accent, size: 22),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Song Title & Subtitle with clean inline status indicators
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      if (isCurrent) ...[
                        MiniAudioSpectrumBars(
                          isPlaying: player.isPlaying,
                          color: accent,
                          height: 12,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Expanded(
                        child: Text(
                          song.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isCurrent ? accent : Colors.white,
                            fontWeight:
                                isCurrent ? FontWeight.w800 : FontWeight.w600,
                            fontSize: 14.5,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      if (isDownloaded) ...[
                        Icon(
                          Icons.arrow_circle_down_rounded,
                          color: accent,
                          size: 13.5,
                        ),
                        const SizedBox(width: 4),
                      ] else if (downloadProgress != null) ...[
                        SizedBox(
                          width: 11,
                          height: 11,
                          child: CircularProgressIndicator(
                            value: downloadProgress,
                            strokeWidth: 1.8,
                            color: accent,
                          ),
                        ),
                        const SizedBox(width: 5),
                      ],
                      if (isFav) ...[
                        Icon(
                          Icons.favorite_rounded,
                          color: accent,
                          size: 12,
                        ),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(
                          song.duration.inSeconds > 0
                              ? '${song.artist} • ${song.formattedDuration}'
                              : song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.58),
                            fontSize: 12.2,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Single Clean More Button (⋮)
            IconButton(
              visualDensity: VisualDensity.compact,
              splashRadius: 20,
              icon: const Icon(
                Icons.more_vert_rounded,
                color: Colors.white54,
                size: 20,
              ),
              onPressed: () => showSongActionSheet(
                context,
                song: song,
                playlistIdForRemoval: playlistIdForRemoval,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Opens a clean Spotify / Apple Music style bottom sheet for song actions
void showSongActionSheet(
  BuildContext context, {
  required ZunifySong song,
  String? playlistIdForRemoval,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final player = ctx.watch<PlayerProvider>();
      final library = ctx.watch<LibraryProvider>();
      final theme = ctx.watch<ThemeProvider>();
      final accent = theme.accentColor;

      final isFav = library.isFavorite(song.videoId);
      final isDownloaded = library.isDownloaded(song.videoId);

      return Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        decoration: BoxDecoration(
          color: const Color(0xFF101420),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),

              // Song Header Preview
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: song.highResArtUrl,
                      width: 54,
                      height: 54,
                      memCacheWidth: 162,
                      fadeInDuration: const Duration(milliseconds: 120),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 54,
                        height: 54,
                        color: Colors.white10,
                        child: Icon(Icons.music_note_rounded, color: accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
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
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${song.artist} • ${song.formattedDuration}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => library.toggleFavorite(song),
                    icon: Icon(
                      isFav
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      color: isFav ? accent : Colors.white60,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: Colors.white.withOpacity(0.08), height: 1),
              const SizedBox(height: 6),

              // Action Items
              _sheetActionTile(
                icon: Icons.playlist_play_rounded,
                title: 'Putar Berikutnya',
                subtitle: 'Dimainkan tepat setelah lagu saat ini selesai',
                accent: accent,
                onTap: () {
                  player.playNextInQueue(song);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: accent,
                      duration: const Duration(seconds: 1),
                      content: Text(
                        'Diputar berikutnya: ${song.title}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
              _sheetActionTile(
                icon: Icons.queue_music_rounded,
                title: 'Tambahkan ke Antrean',
                subtitle: 'Masuk ke urutan paling bawah antrean',
                accent: accent,
                onTap: () {
                  player.addToQueue(song);
                  Navigator.pop(ctx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: accent,
                      duration: const Duration(seconds: 1),
                      content: Text(
                        'Ditambahkan ke antrean: ${song.title}',
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  );
                },
              ),
              _sheetActionTile(
                icon: Icons.playlist_add_rounded,
                title: 'Simpan ke Playlist...',
                subtitle: 'Tambahkan lagu ini ke koleksi playlist kamu',
                accent: accent,
                onTap: () {
                  Navigator.pop(ctx);
                  _showPlaylistPickerSheet(context, library, song, accent);
                },
              ),
              _sheetActionTile(
                icon: isDownloaded
                    ? Icons.delete_outline_rounded
                    : Icons.download_for_offline_outlined,
                title: isDownloaded
                    ? 'Hapus dari Penyimpanan Offline'
                    : 'Unduh untuk Mode Offline',
                subtitle: isDownloaded
                    ? 'Lagu sudah tersimpan di Private Vault'
                    : 'Dengarkan kapan saja tanpa kuota internet',
                accent: accent,
                onTap: () {
                  Navigator.pop(ctx);
                  if (isDownloaded) {
                    library.removeDownloadedSong(song.videoId);
                  } else {
                    library.downloadSong(
                      song,
                      highQuality: player.highQualityAudio,
                    );
                  }
                },
              ),
              _sheetActionTile(
                icon: Icons.ios_share_rounded,
                title: 'Bagikan Kartu Lagu ke Story / SW',
                subtitle: 'Buat kartu estetik untuk WhatsApp atau IG Story',
                accent: accent,
                onTap: () {
                  Navigator.pop(ctx);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => ShareCardModal(
                      song: song,
                      lyrics: player.currentSong?.videoId == song.videoId
                          ? player.currentLyrics
                          : null,
                      initialLyricIndex:
                          player.activeLyricIndex < 0 ? 0 : player.activeLyricIndex,
                    ),
                  );
                },
              ),
              if (playlistIdForRemoval != null)
                _sheetActionTile(
                  icon: Icons.remove_circle_outline_rounded,
                  title: 'Hapus dari Playlist Ini',
                  accent: Colors.redAccent,
                  isDestructive: true,
                  onTap: () {
                    library.removeSongFromPlaylist(
                      playlistIdForRemoval,
                      song.videoId,
                    );
                    Navigator.pop(ctx);
                  },
                ),
            ],
          ),
        ),
      );
    },
  );
}

Widget _sheetActionTile({
  required IconData icon,
  required String title,
  String? subtitle,
  required Color accent,
  required VoidCallback onTap,
  bool isDestructive = false,
}) {
  return ListTile(
    contentPadding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
    leading: Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: isDestructive
            ? Colors.redAccent.withOpacity(0.12)
            : Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Icon(
        icon,
        color: isDestructive ? Colors.redAccent : Colors.white,
        size: 20,
      ),
    ),
    title: Text(
      title,
      style: TextStyle(
        color: isDestructive ? Colors.redAccent : Colors.white,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    ),
    subtitle: subtitle != null
        ? Text(
            subtitle,
            style: const TextStyle(color: Colors.white54, fontSize: 11.5),
          )
        : null,
    onTap: onTap,
  );
}

void _showPlaylistPickerSheet(
  BuildContext context,
  LibraryProvider library,
  ZunifySong song,
  Color accent,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF101420),
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (ctx) {
      return SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Simpan ke Playlist',
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
                    'Buat Playlist Baru "Favoritku"',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
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
                ...library.playlists.take(6).map((pl) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: accent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.queue_music_rounded, color: accent),
                    ),
                    title: Text(
                      pl.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
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
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            backgroundColor: accent,
                            duration: const Duration(seconds: 1),
                            content: Text(
                              'Ditambahkan ke "${pl.name}"',
                              style: const TextStyle(
                                color: Colors.black,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      }
                    },
                  );
                }),
            ],
          ),
        ),
      );
    },
  );
}
