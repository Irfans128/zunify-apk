import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/liquid_background_widget.dart';
import '../widgets/song_tile_widget.dart';
import 'search_screen.dart';

/// Opens the full interactive Playlist Detail Sheet (Spotify Import, YT Music Import, and Local Playlists)
void showPlaylistDetailSheet(BuildContext context, String playlistId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PlaylistDetailSheet(playlistId: playlistId),
  );
}

/// Opens a True Frosted Liquid Glass / Neo-Brutalism "Buat Playlist" Sheet
void showCreatePlaylistSheet(
  BuildContext context, {
  ZunifySong? initialSong,
}) {
  final nameCtrl = TextEditingController();
  final descCtrl = TextEditingController();
  final library = context.read<LibraryProvider>();

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      final theme = ctx.watch<ThemeProvider>();
      final accent = theme.accentColor;
      final isBrutal = theme.isNeoBrutalism;

      Future<void> submitCreate() async {
        final cleanName = nameCtrl.text.trim();
        if (cleanName.isEmpty) return;
        await library.createLocalPlaylist(cleanName, descCtrl.text.trim());
        if (initialSong != null && library.playlists.isNotEmpty) {
          await library.addSongToPlaylist(
            library.playlists.first.id,
            initialSong,
          );
        }
        if (ctx.mounted) Navigator.pop(ctx);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: accent,
              duration: const Duration(seconds: 1),
              content: Text(
                initialSong != null
                    ? 'Playlist "$cleanName" dibuat & lagu disimpan'
                    : 'Playlist "$cleanName" berhasil dibuat',
                style: const TextStyle(
                  color: Color(0xFF111111),
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          );
        }
      }

      return ZunifySheetContainer(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 14,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
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
                  Container(
                    width: 38,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: isBrutal
                        ? BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.brutalBorderColor,
                              width: 2.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.brutalShadowColor,
                                blurRadius: 0,
                                offset: const Offset(2.2, 2.2),
                              ),
                            ],
                          )
                        : BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.24),
                                accent.withOpacity(0.32),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.34),
                              width: 1.0,
                            ),
                          ),
                    child: Icon(
                      Icons.playlist_add_rounded,
                      color: isBrutal ? const Color(0xFF111111) : Colors.white,
                      size: 21,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Buat Playlist Baru',
                      style: GoogleFonts.plusJakartaSans(
                        color: theme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                  IosGlassIconButton(
                    icon: Icons.close_rounded,
                    size: 34,
                    iconSize: 17,
                    onTap: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              LiquidGlassBox(
                borderRadius: 16,
                tintOpacity: 0.10,
                rimIntensity: 0.42,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                child: TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  textInputAction: TextInputAction.next,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Nama Playlist',
                    hintStyle: TextStyle(
                      color: theme.textMuted,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    icon: Icon(
                      Icons.queue_music_rounded,
                      color: theme.accentText,
                      size: 20,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              LiquidGlassBox(
                borderRadius: 16,
                tintOpacity: 0.08,
                rimIntensity: 0.36,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                child: TextField(
                  controller: descCtrl,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => submitCreate(),
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Catatan singkat (opsional)',
                    hintStyle: TextStyle(
                      color: theme.textMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    border: InputBorder.none,
                    icon: Icon(
                      Icons.notes_rounded,
                      color: theme.textMuted,
                      size: 19,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: LiquidGlassBox(
                      height: 46,
                      borderRadius: isBrutal ? 12 : 23,
                      tintOpacity: 0.08,
                      rimIntensity: 0.34,
                      onTap: () => Navigator.pop(ctx),
                      child: Text(
                        'Batal',
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 6,
                    child: IosSpringButton(
                      borderRadius: isBrutal ? 12 : 23,
                      onTap: submitCreate,
                      child: Container(
                        height: 46,
                        alignment: Alignment.center,
                        decoration: isBrutal
                            ? BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: theme.brutalBorderColor,
                                  width: 2.2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.brutalShadowColor,
                                    blurRadius: 0,
                                    offset: const Offset(3.5, 3.5),
                                  ),
                                ],
                              )
                            : BoxDecoration(
                                borderRadius: BorderRadius.circular(23),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color.lerp(Colors.white, accent, 0.72)!,
                                    accent,
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.42),
                                  width: 1.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withOpacity(0.38),
                                    blurRadius: 18,
                                    offset: const Offset(0, 6),
                                  ),
                                ],
                              ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.check_rounded,
                              color: Color(0xFF111111),
                              size: 19,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Buat Playlist',
                              style: TextStyle(
                                color: Color(0xFF111111),
                                fontWeight: FontWeight.w800,
                                fontSize: 13.8,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final library = context.watch<LibraryProvider>();
    final player = context.watch<PlayerProvider>();
    final accent = theme.accentColor;
    final isBrutal = theme.isNeoBrutalism;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Logical Header: Koleksi + Import Playlist & Buat Baru
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Koleksi',
                    style: GoogleFonts.plusJakartaSans(
                      color: theme.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IosGlassPillButton(
                        icon: Icons.add_link_rounded,
                        label: 'Import',
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        activeColor: accent,
                        onTap: () => showImportPlaylistSheet(context),
                      ),
                      const SizedBox(width: 8),
                      IosGlassPillButton(
                        icon: Icons.add_rounded,
                        label: 'Buat Baru',
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        activeColor: accent,
                        isActive: true,
                        onTap: () => showCreatePlaylistSheet(context),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Segmented Tab Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: LiquidGlassBox(
                borderRadius: 20,
                padding: const EdgeInsets.all(3.5),
                tintOpacity: 0.08,
                rimIntensity: 0.34,
                child: TabBar(
                  controller: _tabController,
                  indicator: isBrutal
                      ? BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(9),
                          border: Border.all(
                            color: theme.brutalBorderColor,
                            width: 1.8,
                          ),
                        )
                      : BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.white.withOpacity(0.18),
                              accent.withOpacity(0.24),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.28),
                            width: 0.9,
                          ),
                        ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor:
                      isBrutal ? const Color(0xFF111111) : Colors.white,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.0,
                  ),
                  unselectedLabelColor:
                      isBrutal ? theme.textSecondary : Colors.white60,
                  unselectedLabelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 12.0,
                  ),
                  tabs: [
                    Tab(
                      height: 34,
                      text: 'Playlist (${library.playlists.length})',
                    ),
                    Tab(
                      height: 34,
                      text: 'Diunduh (${library.downloadedSongs.length})',
                    ),
                    Tab(
                      height: 34,
                      text: 'Disukai (${library.favorites.length})',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPlaylistsTab(library, player, theme, accent),
                  _buildSongList(
                    library.downloadedSongs,
                    player: player,
                    theme: theme,
                    accent: accent,
                    contextLabel: 'Lagu Diunduh',
                    emptyText: 'Belum ada lagu yang diunduh.',
                  ),
                  _buildSongList(
                    library.favorites,
                    player: player,
                    theme: theme,
                    accent: accent,
                    contextLabel: 'Lagu Disukai',
                    emptyText: 'Belum ada lagu yang disukai.',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSongList(
    List<ZunifySong> songs, {
    required PlayerProvider player,
    required ThemeProvider theme,
    required Color accent,
    required String contextLabel,
    required String emptyText,
  }) {
    if (songs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            emptyText,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: theme.textMuted,
              height: 1.5,
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(18, 4, 18, 6),
          child: Row(
            children: [
              IosGlassPillButton(
                icon: Icons.play_arrow_rounded,
                label: 'Putar Semua',
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                activeColor: accent,
                isActive: true,
                onTap: () {
                  player.playSong(
                    songs.first,
                    customQueue: songs,
                    contextName: contextLabel,
                  );
                },
              ),
              const SizedBox(width: 8),
              IosGlassPillButton(
                icon: Icons.shuffle_rounded,
                label: 'Acak',
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                activeColor: accent,
                onTap: () {
                  final shuffled = List<ZunifySong>.from(songs)..shuffle();
                  player.playSong(
                    shuffled.first,
                    customQueue: shuffled,
                    contextName: contextLabel,
                  );
                },
              ),
              const Spacer(),
              Text(
                '${songs.length} lagu',
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 176),
            physics: const BouncingScrollPhysics(),
            itemCount: songs.length,
            itemBuilder: (context, idx) {
              return ZunifySongTile(
                song: songs[idx],
                queueContext: songs,
                contextName: contextLabel,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistsTab(
    LibraryProvider library,
    PlayerProvider player,
    ThemeProvider theme,
    Color accent,
  ) {
    final isBrutal = theme.isNeoBrutalism;
    if (library.playlists.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Belum ada playlist.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: theme.textMuted,
                  height: 1.5,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 14),
              IosGlassPillButton(
                icon: Icons.add_link_rounded,
                label: 'Import dari Spotify / YT Music',
                height: 36,
                activeColor: accent,
                isActive: true,
                onTap: () => showImportPlaylistSheet(context),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(18, 8, 18, 176),
      physics: const BouncingScrollPhysics(),
      itemCount: library.playlists.length,
      itemBuilder: (context, i) {
        final ZunifyPlaylist pl = library.playlists[i];
        final Color badgeColor = pl.origin == PlaylistOrigin.spotifyImport
            ? const Color(0xFF1DB954)
            : pl.origin == PlaylistOrigin.youtubeMusicImport
                ? const Color(0xFFFF4E45)
                : accent;
        final Color badgeTextColor = pl.origin == PlaylistOrigin.spotifyImport
            ? (theme.isLightCanvas
                ? const Color(0xFF0F7A35)
                : const Color(0xFF1DB954))
            : pl.origin == PlaylistOrigin.youtubeMusicImport
                ? (theme.isLightCanvas
                    ? const Color(0xFFC5221F)
                    : const Color(0xFFFF4E45))
                : theme.accentText;

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: LiquidGlassBox(
            borderRadius: 20,
            padding: const EdgeInsets.all(10),
            tintOpacity: 0.07,
            rimIntensity: 0.34,
            onTap: () => showPlaylistDetailSheet(context, pl.id),
            child: Row(
              children: [
                Container(
                  decoration: isBrutal
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                            color: theme.brutalBorderColor,
                            width: 1.8,
                          ),
                        )
                      : null,
                  child: _buildPlaylistCoverThumb(pl, theme, accent),
                ),
                const SizedBox(width: 13),
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
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(
                                isBrutal ? 0.22 : 0.16,
                              ),
                              borderRadius: BorderRadius.circular(6),
                              border: isBrutal
                                  ? Border.all(
                                      color: theme.brutalBorderColor
                                          .withOpacity(0.55),
                                      width: 1.2,
                                    )
                                  : null,
                            ),
                            child: Text(
                              pl.originBadgeLabel,
                              style: TextStyle(
                                color: badgeTextColor,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${pl.songs.length} lagu',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.textSecondary,
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
                const SizedBox(width: 8),
                IosGlassIconButton(
                  icon: Icons.play_arrow_rounded,
                  size: 38,
                  iconSize: 20,
                  isActive: pl.songs.isNotEmpty,
                  activeColor: accent,
                  onTap: () {
                    if (pl.songs.isNotEmpty) {
                      player.playSong(
                        pl.songs.first,
                        customQueue: pl.songs,
                        contextName: pl.name,
                      );
                    } else {
                      showPlaylistDetailSheet(context, pl.id);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildPlaylistCoverThumb(
    ZunifyPlaylist pl,
    ThemeProvider theme,
    Color accent,
  ) {
    final radius = theme.isNeoBrutalism ? 9.2 : 14.0;
    if (pl.coverUrl != null && pl.coverUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedNetworkImage(
          imageUrl: pl.coverUrl!,
          width: 58,
          height: 58,
          memCacheWidth: 174,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _fallbackCover(theme, accent, radius),
        ),
      );
    }
    if (pl.songs.length >= 4) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: 58,
          height: 58,
          child: Column(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CachedNetworkImage(
                        imageUrl: pl.songs[0].thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: theme.subtleFill),
                      ),
                    ),
                    Expanded(
                      child: CachedNetworkImage(
                        imageUrl: pl.songs[1].thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: theme.subtleFill),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      child: CachedNetworkImage(
                        imageUrl: pl.songs[2].thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: theme.subtleFill),
                      ),
                    ),
                    Expanded(
                      child: CachedNetworkImage(
                        imageUrl: pl.songs[3].thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: theme.subtleFill),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }
    if (pl.songs.isNotEmpty && pl.songs.first.thumbnailUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: CachedNetworkImage(
          imageUrl: pl.songs.first.thumbnailUrl,
          width: 58,
          height: 58,
          memCacheWidth: 174,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _fallbackCover(theme, accent, radius),
        ),
      );
    }
    return _fallbackCover(theme, accent, radius);
  }

  Widget _fallbackCover(ThemeProvider theme, Color accent, double radius) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.18),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Icon(
        Icons.queue_music_rounded,
        color: theme.accentText,
        size: 26,
      ),
    );
  }
}

/// Clean Interactive Playlist Detail Sheet (Liquid Glass & Neo-Brutalism)
class PlaylistDetailSheet extends StatefulWidget {
  final String playlistId;

  const PlaylistDetailSheet({super.key, required this.playlistId});

  @override
  State<PlaylistDetailSheet> createState() => _PlaylistDetailSheetState();
}

class _PlaylistDetailSheetState extends State<PlaylistDetailSheet> {
  final TextEditingController _filterCtrl = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final library = context.watch<LibraryProvider>();
    final player = context.watch<PlayerProvider>();
    final accent = theme.accentColor;
    final isBrutal = theme.isNeoBrutalism;

    final idx = library.playlists.indexWhere((p) => p.id == widget.playlistId);
    if (idx < 0) return const SizedBox.shrink();

    final ZunifyPlaylist playlist = library.playlists[idx];
    final String? coverArt = playlist.coverUrl ??
        (playlist.songs.isNotEmpty ? playlist.songs.first.highResArtUrl : null);

    final Color badgeColor = playlist.origin == PlaylistOrigin.spotifyImport
        ? const Color(0xFF1DB954)
        : playlist.origin == PlaylistOrigin.youtubeMusicImport
            ? const Color(0xFFFF4E45)
            : accent;
    final Color badgeTextColor =
        playlist.origin == PlaylistOrigin.spotifyImport
            ? (theme.isLightCanvas
                ? const Color(0xFF0F7A35)
                : const Color(0xFF1DB954))
            : playlist.origin == PlaylistOrigin.youtubeMusicImport
                ? (theme.isLightCanvas
                    ? const Color(0xFFC5221F)
                    : const Color(0xFFFF4E45))
                : theme.accentText;

    final filteredSongs = _searchQuery.trim().isEmpty
        ? playlist.songs
        : playlist.songs.where((s) {
            final q = _searchQuery.toLowerCase();
            return s.title.toLowerCase().contains(q) ||
                s.artist.toLowerCase().contains(q);
          }).toList();

    return ZunifySheetContainer(
      height: MediaQuery.of(context).size.height * 0.88,
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Playlist Hero Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
            child: Row(
              children: [
                Container(
                  decoration: isBrutal
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
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
                      : null,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isBrutal ? 10 : 14),
                    child: coverArt != null && coverArt.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: coverArt,
                            width: 80,
                            height: 80,
                            memCacheWidth: 240,
                            fadeInDuration: const Duration(milliseconds: 140),
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) =>
                                _heroFallback(theme, accent),
                          )
                        : _heroFallback(theme, accent),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(isBrutal ? 0.22 : 0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          playlist.originBadgeLabel,
                          style: TextStyle(
                            color: badgeTextColor,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        playlist.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${playlist.songs.length} lagu',
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: theme.textSecondary,
                  ),
                  color: theme.cardBgColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isBrutal ? 11 : 14),
                    side: isBrutal
                        ? BorderSide(color: theme.brutalBorderColor, width: 2.0)
                        : BorderSide(color: theme.dividerColor),
                  ),
                  onSelected: (val) async {
                    if (val == 'queue_all') {
                      for (final s in playlist.songs) {
                        player.addToQueue(s);
                      }
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: accent,
                          content: Text(
                            '${playlist.songs.length} lagu ditambahkan ke antrean',
                            style: const TextStyle(
                              color: Color(0xFF111111),
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      );
                    } else if (val == 'delete') {
                      await library.deletePlaylist(playlist.id);
                      if (!context.mounted) return;
                      Navigator.pop(context);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(
                      value: 'queue_all',
                      child: Text(
                        'Tambah ke Antrean',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Hapus Playlist',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Play All & Shuffle Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: IosSpringButton(
                    onTap: playlist.songs.isEmpty
                        ? null
                        : () {
                            player.playSong(
                              playlist.songs.first,
                              customQueue: playlist.songs,
                              contextName: playlist.name,
                            );
                          },
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(isBrutal ? 11 : 14),
                        border: isBrutal
                            ? Border.all(
                                color: theme.brutalBorderColor,
                                width: 2.0,
                              )
                            : null,
                        boxShadow: isBrutal
                            ? [
                                BoxShadow(
                                  color: theme.brutalShadowColor,
                                  blurRadius: 0,
                                  offset: const Offset(3.0, 3.0),
                                ),
                              ]
                            : null,
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: Color(0xFF111111),
                            size: 20,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Putar Semua',
                            style: TextStyle(
                              color: Color(0xFF111111),
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: LiquidGlassBox(
                    height: 42,
                    borderRadius: 14,
                    tintOpacity: 0.10,
                    rimIntensity: 0.35,
                    onTap: playlist.songs.isEmpty
                        ? null
                        : () {
                            final shuffled =
                                List<ZunifySong>.from(playlist.songs)
                                  ..shuffle();
                            player.playSong(
                              shuffled.first,
                              customQueue: shuffled,
                              contextName: playlist.name,
                            );
                          },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.shuffle_rounded,
                          size: 18,
                          color: theme.accentText,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Putar Acak',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          if (playlist.songs.length > 4)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: SizedBox(
                height: 40,
                child: TextField(
                  controller: _filterCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: TextStyle(color: theme.textPrimary, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Cari di playlist ini...',
                    hintStyle: TextStyle(
                      color: theme.textMuted,
                      fontSize: 12.5,
                    ),
                    filled: true,
                    fillColor: isBrutal ? theme.cardBgColor : theme.subtleFill,
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: theme.accentText,
                      size: 18,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IosSpringButton(
                            onTap: () {
                              _filterCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: Icon(
                              Icons.clear_rounded,
                              size: 16,
                              color: theme.textMuted,
                            ),
                          )
                        : null,
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(isBrutal ? 10 : 12),
                      borderSide: isBrutal
                          ? BorderSide(
                              color: theme.brutalBorderColor,
                              width: 1.8,
                            )
                          : BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(isBrutal ? 10 : 12),
                      borderSide: BorderSide(
                        color: isBrutal ? theme.brutalBorderColor : accent,
                        width: isBrutal ? 2.0 : 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),

          Expanded(
            child: filteredSongs.isEmpty
                ? Center(
                    child: Text(
                      'Tidak ada lagu ditemukan.',
                      style: TextStyle(color: theme.textMuted),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
                    physics: const BouncingScrollPhysics(),
                    itemCount: filteredSongs.length,
                    itemBuilder: (context, i) {
                      final song = filteredSongs[i];
                      return Dismissible(
                        key: ValueKey('${playlist.id}_${song.videoId}_$i'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(0.25),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.delete_outline_rounded,
                            color: Colors.redAccent,
                          ),
                        ),
                        onDismissed: (_) {
                          library.removeSongFromPlaylist(
                            playlist.id,
                            song.videoId,
                          );
                        },
                        child: ZunifySongTile(
                          song: song,
                          queueContext: playlist.songs,
                          contextName: playlist.name,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _heroFallback(ThemeProvider theme, Color accent) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.18),
        borderRadius: BorderRadius.circular(theme.isNeoBrutalism ? 10 : 14),
      ),
      child: Icon(
        Icons.library_music_rounded,
        color: theme.accentText,
        size: 34,
      ),
    );
  }
}
