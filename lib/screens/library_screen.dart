import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
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
          'Buat Playlist Baru',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Nama Playlist (misal: Vibe Malam)',
                hintStyle: TextStyle(color: Colors.white38),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Deskripsi singkat (opsional)',
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
              'Simpan',
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
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Koleksi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  Row(
                    children: [
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
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
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(color: accent.withOpacity(0.35)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: accent,
                                size: 14,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Rekap',
                                style: TextStyle(
                                  color: accent,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(18),
                        onTap: () =>
                            _showCreatePlaylistDialog(context, library, accent),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.add_rounded,
                                color: Colors.black,
                                size: 17,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Playlist',
                                style: TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            TabBar(
              controller: _tabController,
              indicatorColor: accent,
              indicatorWeight: 2.5,
              dividerColor: Colors.white.withOpacity(0.06),
              labelColor: Colors.white,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
              unselectedLabelColor: Colors.white54,
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              tabs: [
                Tab(text: 'Playlist (${library.playlists.length})'),
                Tab(text: 'Offline (${library.downloadedSongs.length})'),
                Tab(text: 'Favorit (${library.favorites.length})'),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildPlaylistsTab(library, player, accent),
                  _buildSongList(
                    library.downloadedSongs,
                    emptyText:
                        'Belum ada lagu tersimpan di Private Vault.\nKetuk titik tiga (⋮) pada lagu mana saja untuk mengunduh offline.',
                  ),
                  _buildSongList(
                    library.favorites,
                    emptyText: 'Belum ada lagu favorit (❤️).',
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

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 112),
      itemCount: songs.length,
      itemBuilder: (context, idx) {
        return ZunifySongTile(
          song: songs[idx],
          queueContext: songs,
        );
      },
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
            'Belum ada playlist.\nBuat playlist baru atau Import dari Spotify & YouTube Music di tab Cari.',
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
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 112),
      itemCount: library.playlists.length,
      itemBuilder: (context, i) {
        final ZunifyPlaylist pl = library.playlists[i];
        final String? coverArt = pl.coverUrl ??
            (pl.songs.isNotEmpty ? pl.songs.first.thumbnailUrl : null);

        final Color badgeColor = pl.origin == PlaylistOrigin.spotifyImport
            ? const Color(0xFF1DB954)
            : pl.origin == PlaylistOrigin.youtubeMusicImport
                ? const Color(0xFFFF4E45)
                : accent;

        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.07)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => showPlaylistDetailSheet(context, pl.id),
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: coverArt != null && coverArt.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: coverArt,
                            width: 58,
                            height: 58,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _fallbackCover(accent),
                          )
                        : _fallbackCover(accent),
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 1.5,
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
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '${pl.songs.length} lagu',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 34,
                      color: accent,
                    ),
                    onPressed: () {
                      if (pl.songs.isNotEmpty) {
                        player.playSong(pl.songs.first, customQueue: pl.songs);
                      } else {
                        showPlaylistDetailSheet(context, pl.id);
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _fallbackCover(Color accent) {
    return Container(
      width: 58,
      height: 58,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.16),
        borderRadius: BorderRadius.circular(12),
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
                          width: 84,
                          height: 84,
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
                            '${playlist.songs.length} lagu ditambahkan ke antrean!',
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
                        'Tambah Semua ke Antrean',
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

          // Play All & Shuffle Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: playlist.songs.isEmpty
                        ? null
                        : () {
                            player.playSong(
                              playlist.songs.first,
                              customQueue: playlist.songs,
                            );
                          },
                    icon: const Icon(Icons.play_arrow_rounded, size: 20),
                    label: const Text(
                      'Putar Semua',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.15)),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: playlist.songs.isEmpty
                        ? null
                        : () {
                            final shuffled =
                                List<ZunifySong>.from(playlist.songs)
                                  ..shuffle();
                            player.playSong(
                              shuffled.first,
                              customQueue: shuffled,
                            );
                          },
                    icon: Icon(Icons.shuffle_rounded, size: 18, color: accent),
                    label: const Text(
                      'Putar Acak',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Filter Search Inside Playlist
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
                    hintText: 'Cari lagu di playlist ini...',
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
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              size: 16,
                              color: Colors.white54,
                            ),
                            onPressed: () {
                              _filterCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
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

          // Clean Song List using ZunifySongTile
          Expanded(
            child: filteredSongs.isEmpty
                ? Center(
                    child: Text(
                      playlist.songs.isEmpty
                          ? 'Playlist ini masih kosong.'
                          : 'Tidak ada lagu yang cocok.',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
                    itemCount: filteredSongs.length,
                    itemBuilder: (context, index) {
                      final song = filteredSongs[index];
                      return ZunifySongTile(
                        song: song,
                        queueContext: playlist.songs,
                        rank: index + 1,
                        playlistIdForRemoval: playlist.id,
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
      width: 84,
      height: 84,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.queue_music_rounded, color: accent, size: 36),
    );
  }
}
