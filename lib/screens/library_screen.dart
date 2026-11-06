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
import '../widgets/weekly_rapot_modal.dart';

/// Opens the full interactive Playlist Detail Sheet (works for Spotify Import, YT Music Import, and Local Playlists)
void showPlaylistDetailSheet(BuildContext context, String playlistId) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => PlaylistDetailSheet(playlistId: playlistId),
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

  void _showCreatePlaylistDialog(
    BuildContext context,
    LibraryProvider library,
    Color accent,
  ) {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131722),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Playlist Baru',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Nama Playlist',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Catatan (opsional)',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              if (nameCtrl.text.trim().isNotEmpty) {
                library.createLocalPlaylist(nameCtrl.text, descCtrl.text);
                Navigator.pop(ctx);
              }
            },
            child: const Text(
              'Buat',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final library = context.watch<LibraryProvider>();
    final player = context.watch<PlayerProvider>();
    final accent = theme.accentColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Clean Header + Wrapped & New Playlist Pills
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Koleksi',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IosGlassPillButton(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Wrapped',
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        activeColor: accent,
                        onTap: () async {
                          final rapot = await player.getWeeklyRapot();
                          if (!context.mounted) return;
                          showModalBottomSheet(
                            context: context,
                            isScrollControlled: true,
                            backgroundColor: Colors.transparent,
                            builder: (_) => WeeklyRapotModal(rapot: rapot),
                          );
                        },
                      ),
                      const SizedBox(width: 8),
                      IosGlassPillButton(
                        icon: Icons.add_rounded,
                        label: 'Buat Baru',
                        height: 34,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        activeColor: accent,
                        isActive: true,
                        onTap: () => _showCreatePlaylistDialog(
                          context,
                          library,
                          accent,
                        ),
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
                  indicator: BoxDecoration(
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
                  labelColor: Colors.white,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12.0,
                  ),
                  unselectedLabelColor: Colors.white60,
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
                  _buildPlaylistsTab(library, player, accent),
                  _buildSongList(
                    library.downloadedSongs,
                    player: player,
                    accent: accent,
                    contextLabel: 'Lagu Diunduh',
                    emptyText: 'Belum ada lagu yang diunduh.',
                  ),
                  _buildSongList(
                    library.favorites,
                    player: player,
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
            style: const TextStyle(
              color: Colors.white54,
              height: 1.5,
              fontSize: 13.5,
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
                style: const TextStyle(
                  color: Colors.white54,
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
    Color accent,
  ) {
    if (library.playlists.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'Belum ada playlist.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white54,
              height: 1.5,
              fontSize: 13.5,
            ),
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
                _buildPlaylistCoverThumb(pl, accent),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pl.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
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
                              color: badgeColor.withOpacity(0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              pl.originBadgeLabel,
                              style: TextStyle(
                                color: badgeColor,
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
                              style: const TextStyle(
                                color: Colors.white60,
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

  Widget _buildPlaylistCoverThumb(ZunifyPlaylist pl, Color accent) {
    if (pl.coverUrl != null && pl.coverUrl!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: CachedNetworkImage(
          imageUrl: pl.coverUrl!,
          width: 58,
          height: 58,
          memCacheWidth: 174,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _fallbackCover(accent),
        ),
      );
    }
    if (pl.songs.length >= 4) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(14),
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
                            Container(color: Colors.white10),
                      ),
                    ),
                    Expanded(
                      child: CachedNetworkImage(
                        imageUrl: pl.songs[1].thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: Colors.white10),
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
                            Container(color: Colors.white10),
                      ),
                    ),
                    Expanded(
                      child: CachedNetworkImage(
                        imageUrl: pl.songs[3].thumbnailUrl,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) =>
                            Container(color: Colors.white10),
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
        borderRadius: BorderRadius.circular(14),
        child: CachedNetworkImage(
          imageUrl: pl.songs.first.thumbnailUrl,
          width: 58,
          height: 58,
          memCacheWidth: 174,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _fallbackCover(accent),
        ),
      );
    }
    return _fallbackCover(accent);
  }

  Widget _fallbackCover(Color accent) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.queue_music_rounded, color: accent, size: 26),
    );
  }
}

/// Clean Interactive Playlist Detail Sheet
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

    final filteredSongs = _searchQuery.trim().isEmpty
        ? playlist.songs
        : playlist.songs.where((s) {
            final q = _searchQuery.toLowerCase();
            return s.title.toLowerCase().contains(q) ||
                s.artist.toLowerCase().contains(q);
          }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: BoxDecoration(
        color: const Color(0xFF0C101B),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Playlist Hero Header
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 16, 12, 12),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: coverArt != null && coverArt.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: coverArt,
                          width: 80,
                          height: 80,
                          memCacheWidth: 240,
                          fadeInDuration: const Duration(milliseconds: 140),
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _heroFallback(accent),
                        )
                      : _heroFallback(accent),
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
                          color: badgeColor.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          playlist.originBadgeLabel,
                          style: TextStyle(
                            color: badgeColor,
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
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${playlist.songs.length} lagu',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    color: Colors.white70,
                  ),
                  color: const Color(0xFF171C2B),
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
                              color: Colors.black,
                              fontWeight: FontWeight.bold,
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
                  itemBuilder: (_) => const [
                    PopupMenuItem(
                      value: 'queue_all',
                      child: Text(
                        'Tambah ke Antrean',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Hapus Playlist',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Play All & Shuffle Row with Spring Buttons
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
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.black,
                            size: 20,
                          ),
                          SizedBox(width: 6),
                          Text(
                            'Putar Semua',
                            style: TextStyle(
                              color: Colors.black,
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
                        Icon(Icons.shuffle_rounded, size: 18, color: accent),
                        const SizedBox(width: 6),
                        const Text(
                          'Putar Acak',
                          style: TextStyle(
                            color: Colors.white,
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
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Cari di playlist ini...',
                    hintStyle: const TextStyle(
                      color: Colors.white38,
                      fontSize: 12.5,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: accent,
                      size: 18,
                    ),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IosSpringButton(
                            onTap: () {
                              _filterCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                            child: const Icon(
                              Icons.clear_rounded,
                              size: 16,
                              color: Colors.white54,
                            ),
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(height: 6),

          Expanded(
            child: filteredSongs.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada lagu ditemukan.',
                      style: TextStyle(color: Colors.white54),
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

  Widget _heroFallback(Color accent) {
    return Container(
      width: 80,
      height: 80,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.library_music_rounded, color: accent, size: 34),
    );
  }
}
