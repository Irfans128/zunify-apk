import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../screens/artist_profile_screen.dart';
import '../screens/library_screen.dart';
import 'liquid_background_widget.dart';
import 'share_card_modal.dart';
import 'vinyl_disc_widget.dart';

/// Clean Song Row (Adapts seamlessly to Liquid Glass & Neo-Brutalism)
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
    final isBrutal = theme.isNeoBrutalism;

    final isCurrent = player.currentSong?.videoId == song.videoId;
    final isFav = library.isFavorite(song.videoId);
    final isDownloaded = library.isDownloaded(song.videoId);
    final downloadProgress = library.activeDownloadProgress[song.videoId];

    final BoxDecoration rowDecoration;
    if (isBrutal) {
      rowDecoration = BoxDecoration(
        color: isCurrent
            ? Color.lerp(theme.cardBgColor, accent, 0.36)
            : theme.cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.brutalBorderColor,
          width: isCurrent ? 2.2 : 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: theme.brutalShadowColor,
            blurRadius: 0,
            offset: Offset(isCurrent ? 3.5 : 2.5, isCurrent ? 3.5 : 2.5),
          ),
        ],
      );
    } else {
      rowDecoration = BoxDecoration(
        color: isCurrent ? accent.withOpacity(0.13) : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: isCurrent
            ? Border.all(color: accent.withOpacity(0.30), width: 0.9)
            : null,
      );
    }

    final activeTitleColor =
        isBrutal ? const Color(0xFF111111) : (isCurrent ? accent : Colors.white);

    return RepaintBoundary(
      child: IosSpringButton(
        scaleDown: 0.96,
        borderRadius: isBrutal ? 12 : 16,
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
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.symmetric(
            horizontal: isBrutal ? 11 : 10,
            vertical: isBrutal ? 9 : 8,
          ),
          margin: EdgeInsets.only(bottom: isBrutal ? 9 : 4),
          decoration: rowDecoration,
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
                          ? theme.accentText
                          : (rank! <= 3 ? theme.textPrimary : theme.textMuted),
                      fontWeight:
                          rank! <= 3 ? FontWeight.w900 : FontWeight.w700,
                      fontSize: 13.5,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],

              // Cover Art Thumbnail
              Container(
                decoration: isBrutal
                    ? BoxDecoration(
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: theme.brutalBorderColor,
                          width: 1.6,
                        ),
                      )
                    : null,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(isBrutal ? 7.5 : 10),
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
                      color: theme.subtleFill,
                      child: Icon(
                        Icons.music_note_rounded,
                        color: theme.accentText,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Song Title & Subtitle
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
                            color: isBrutal
                                ? const Color(0xFF111111)
                                : accent,
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
                              color: isBrutal && !isCurrent
                                  ? theme.textPrimary
                                  : activeTitleColor,
                              fontWeight: isCurrent
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              fontSize: 14.2,
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
                            Icons.download_done_rounded,
                            color: theme.accentText,
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
                              color: theme.accentText,
                            ),
                          ),
                          const SizedBox(width: 5),
                        ],
                        if (isFav) ...[
                          Icon(
                            Icons.favorite_rounded,
                            color: isBrutal
                                ? const Color(0xFFE11D48)
                                : accent,
                            size: 12.5,
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
                              color: isBrutal && isCurrent
                                  ? const Color(0xFF27272A)
                                  : theme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              IconButton(
                visualDensity: VisualDensity.compact,
                splashRadius: 20,
                icon: Icon(
                  Icons.more_vert_rounded,
                  color: isBrutal && isCurrent
                      ? const Color(0xFF111111)
                      : theme.textMuted,
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
      ),
    );
  }
}

/// Clean Song Action Bottom Sheet
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

      return ZunifySheetContainer(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 16),

              // Song Header Preview
              Row(
                children: [
                  Container(
                    decoration: theme.isNeoBrutalism
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: theme.brutalBorderColor,
                              width: 1.8,
                            ),
                          )
                        : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(
                        theme.isNeoBrutalism ? 9 : 12,
                      ),
                      child: CachedNetworkImage(
                        imageUrl: song.highResArtUrl,
                        width: 52,
                        height: 52,
                        memCacheWidth: 160,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 52,
                          height: 52,
                          color: theme.subtleFill,
                          child: Icon(
                            Icons.music_note_rounded,
                            color: theme.accentText,
                          ),
                        ),
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
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 15.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          song.duration.inSeconds > 0
                              ? '${song.artist} • ${song.formattedDuration}'
                              : song.artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 12.2,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IosGlassIconButton(
                    icon: isFav
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 38,
                    iconSize: 19,
                    isActive: isFav,
                    activeColor: accent,
                    onTap: () => library.toggleFavorite(song),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Divider(color: theme.dividerColor, height: 1),
              const SizedBox(height: 6),

              _sheetActionTile(
                theme: theme,
                icon: Icons.playlist_play_rounded,
                title: 'Putar Berikutnya',
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
                theme: theme,
                icon: Icons.queue_music_rounded,
                title: 'Tambahkan ke Antrean',
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
                theme: theme,
                icon: Icons.person_search_rounded,
                title: 'Profil Artis',
                onTap: () {
                  final primaryArtist = song.artist
                      .split(
                        RegExp(
                          r'\s*(?:,|&|\bfeat\.?|\bft\.?)\s*',
                          caseSensitive: false,
                        ),
                      )
                      .first
                      .trim();
                  Navigator.pop(ctx);
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
              ),
              _sheetActionTile(
                theme: theme,
                icon: Icons.playlist_add_rounded,
                title: 'Simpan ke Playlist',
                onTap: () {
                  Navigator.pop(ctx);
                  _showPlaylistPickerSheet(context, library, song, accent);
                },
              ),
              _sheetActionTile(
                theme: theme,
                icon: isDownloaded
                    ? Icons.delete_outline_rounded
                    : Icons.download_rounded,
                title: isDownloaded ? 'Hapus Unduhan' : 'Unduh Lagu',
                onTap: () {
                  Navigator.pop(ctx);
                  if (isDownloaded) {
                    library.removeDownloadedSong(song.videoId);
                  } else {
                    library.downloadSong(song, highQuality: true);
                  }
                },
              ),
              _sheetActionTile(
                theme: theme,
                icon: Icons.ios_share_rounded,
                title: 'Bagikan Lirik / Lagu',
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
                      initialLyricIndex: player.activeLyricIndex < 0
                          ? 0
                          : player.activeLyricIndex,
                    ),
                  );
                },
              ),
              if (playlistIdForRemoval != null)
                _sheetActionTile(
                  theme: theme,
                  icon: Icons.remove_circle_outline_rounded,
                  title: 'Hapus dari Playlist Ini',
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
  required ThemeProvider theme,
  required IconData icon,
  required String title,
  required VoidCallback onTap,
  bool isDestructive = false,
}) {
  final color = isDestructive ? Colors.redAccent : theme.textPrimary;
  return IosSpringButton(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isDestructive
                  ? Colors.redAccent.withOpacity(0.14)
                  : theme.subtleFill,
              borderRadius: BorderRadius.circular(10),
              border: theme.isNeoBrutalism
                  ? Border.all(
                      color: isDestructive
                          ? Colors.redAccent
                          : theme.brutalBorderColor,
                      width: 1.5,
                    )
                  : null,
            ),
            child: Icon(icon, color: color, size: 19),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: theme.textMuted,
            size: 18,
          ),
        ],
      ),
    ),
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
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final theme = ctx.watch<ThemeProvider>();
      return ZunifySheetContainer(
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Simpan ke Playlist',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 17.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  IosGlassPillButton(
                    icon: Icons.add_rounded,
                    label: 'Playlist Baru',
                    height: 31,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    activeColor: accent,
                    isActive: true,
                    fontSize: 11.5,
                    onTap: () {
                      Navigator.pop(ctx);
                      showCreatePlaylistSheet(context, initialSong: song);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (library.playlists.isEmpty)
                LiquidGlassBox(
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 13,
                  ),
                  tintOpacity: 0.08,
                  rimIntensity: 0.36,
                  onTap: () {
                    Navigator.pop(ctx);
                    showCreatePlaylistSheet(context, initialSong: song);
                  },
                  child: Row(
                    children: [
                      Icon(
                        Icons.add_circle_outline_rounded,
                        color: theme.accentText,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Belum ada playlist • Ketuk untuk buat baru',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                ...library.playlists.take(6).map((pl) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 7),
                    child: LiquidGlassBox(
                      borderRadius: 15,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 9,
                      ),
                      tintOpacity: 0.07,
                      rimIntensity: 0.34,
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
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: accent.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(10),
                              border: theme.isNeoBrutalism
                                  ? Border.all(
                                      color: theme.brutalBorderColor,
                                      width: 1.5,
                                    )
                                  : null,
                            ),
                            child: Icon(
                              Icons.queue_music_rounded,
                              color: theme.isLightCanvas
                                  ? const Color(0xFF111111)
                                  : accent,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  pl.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13.8,
                                  ),
                                ),
                                Text(
                                  '${pl.songs.length} lagu',
                                  style: TextStyle(
                                    color: theme.textMuted,
                                    fontSize: 11.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Icon(
                            Icons.add_rounded,
                            color: theme.accentText,
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
}
