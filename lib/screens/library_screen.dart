import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
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
          'Buat Playlist Baru 🎵',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                hintText: 'Nama Playlist (misal: Vibe Malam Fannz)',
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
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
                      // Prominent Rekap Mingguan Pill Button
                      InkWell(
                        borderRadius: BorderRadius.circular(20),
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
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: accent.withOpacity(0.4)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.auto_awesome_rounded,
                                color: accent,
                                size: 15,
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
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                        onPressed: () =>
                            _showCreatePlaylistDialog(context, library, accent),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text(
                          'Baru',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
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
              labelColor: accent,
              unselectedLabelColor: Colors.white54,
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
                  // Tab 1: Playlists (Spotify Import + YT Music Import + Local)
                  _buildPlaylistsTab(library, player, accent),

                  // Tab 2: Private In-App Downloaded Songs
                  _buildSongList(
                    library.downloadedSongs,
                    emptyText:
                        'Belum ada lagu di Private Vault.\nKetuk ikon Download di player atau pencarian untuk mendengar offline tanpa kuota!',
                    player: player,
                    library: library,
                    accent: accent,
                    allowDeleteDownload: true,
                  ),

                  // Tab 3: Favorite Songs
                  _buildSongList(
                    library.favorites,
                    emptyText: 'Belum ada lagu favorit (❤️).',
                    player: player,
                    library: library,
                    accent: accent,
                    allowDeleteDownload: false,
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
    required PlayerProvider player,
    required LibraryProvider library,
    required Color accent,
    required bool allowDeleteDownload,
  }) {
    if (songs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            emptyText,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white54, height: 1.5),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 110),
      itemCount: songs.length,
      itemBuilder: (context, idx) {
        final song = songs[idx];
        return ListTile(
          leading: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: CachedNetworkImage(
              imageUrl: song.thumbnailUrl,
              width: 50,
              height: 50,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(
                width: 50,
                height: 50,
                color: Colors.white10,
                child: Icon(Icons.music_note, color: accent),
              ),
            ),
          ),
          title: Text(
            song.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
            ),
          ),
          subtitle: Text(
            '${song.artist} • ${song.formattedDuration}',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Tambah ke Antrean',
                icon: const Icon(
                  Icons.playlist_add_rounded,
                  color: Colors.white60,
                ),
                onPressed: () {
                  player.addToQueue(song);
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
              allowDeleteDownload
                  ? IconButton(
                      icon: const Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.white54,
                      ),
                      onPressed: () => library.removeDownloadedSong(song.videoId),
                    )
                  : IconButton(
                      icon: Icon(Icons.favorite_rounded, color: accent),
                      onPressed: () => library.toggleFavorite(song),
                    ),
            ],
          ),
          onTap: () => player.playSong(song, customQueue: songs),
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
            'Belum ada playlist.\nBuat playlist baru atau Import dari Spotify & YouTube Music di tab Cari!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white54, height: 1.5),
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 110),
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

        final String songPreview = pl.songs.isEmpty
            ? 'Ketuk untuk melihat detail playlist'
            : pl.songs.take(3).map((s) => s.title).join(' • ');

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.08)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => showPlaylistDetailSheet(context, pl.id),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Playlist Cover Art
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: coverArt != null && coverArt.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: coverArt,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => _fallbackCover(accent),
                          )
                        : _fallbackCover(accent),
                  ),
                  const SizedBox(width: 14),

                  // Playlist Info + Song Preview
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: badgeColor.withOpacity(0.45),
                                ),
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
                            const SizedBox(width: 7),
                            Text(
                              '${pl.songs.length} lagu',
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          pl.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          songPreview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white54,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Quick Play Button
                  IconButton(
                    tooltip: 'Putar Playlist',
                    icon: Icon(
                      Icons.play_circle_fill_rounded,
                      size: 38,
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
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.18),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(Icons.queue_music_rounded, color: accent, size: 30),
    );
  }
}

/// Full Interactive Playlist Detail Sheet
/// Allows inspecting all songs inside Spotify/YTM/Local playlists, searching inside the playlist,
/// playing any track, shuffling, adding to queue, or removing tracks.
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
    if (idx < 0) {
      return const SizedBox.shrink();
    }
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
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(4),
            ),
          ),

          // Playlist Hero Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: coverArt != null && coverArt.isNotEmpty
                      ? CachedNetworkImage(
                          imageUrl: coverArt,
                          width: 92,
                          height: 92,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => _heroFallback(accent),
                        )
                      : _heroFallback(accent),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: badgeColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: badgeColor.withOpacity(0.45)),
                        ),
                        child: Text(
                          playlist.originBadgeLabel,
                          style: TextStyle(
                            color: badgeColor,
                            fontSize: 10.5,
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
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${playlist.songs.length} lagu siap diputar',
                        style: const TextStyle(
                          color: Colors.white60,
                          fontSize: 12.5,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, color: Colors.white70),
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
                  itemBuilder: (_) => [
                    const PopupMenuItem(
                      value: 'queue_all',
                      child: Row(
                        children: [
                          Icon(Icons.playlist_add_rounded, color: Colors.white, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Tambah Semua ke Antrean',
                            style: TextStyle(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                          SizedBox(width: 10),
                          Text(
                            'Hapus Playlist',
                            style: TextStyle(color: Colors.redAccent),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Action Buttons Row: Play All & Shuffle Play
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 12),
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
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: const Text(
                      'Putar Semua',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.18)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: playlist.songs.isEmpty
                        ? null
                        : () {
                            final shuffled = List<ZunifySong>.from(playlist.songs)
                              ..shuffle();
                            player.playSong(
                              shuffled.first,
                              customQueue: shuffled,
                            );
                          },
                    icon: Icon(Icons.shuffle_rounded, size: 19, color: accent),
                    label: const Text(
                      'Putar Acak',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Filter Search Inside Playlist
          if (playlist.songs.length > 4)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SizedBox(
                height: 42,
                child: TextField(
                  controller: _filterCtrl,
                  onChanged: (v) => setState(() => _searchQuery = v),
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Cari lagu di dalam playlist ini...',
                    hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.06),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    prefixIcon: Icon(Icons.search_rounded, color: accent, size: 18),
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
          const SizedBox(height: 8),

          // Complete Song List inside the Playlist
          Expanded(
            child: filteredSongs.isEmpty
                ? Center(
                    child: Text(
                      playlist.songs.isEmpty
                          ? 'Playlist ini masih kosong.'
                          : 'Tidak ada lagu yang cocok dengan pencarian.',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
                    itemCount: filteredSongs.length,
                    itemBuilder: (context, index) {
                      final song = filteredSongs[index];
                      final isPlayingNow =
                          player.currentSong?.videoId == song.videoId;

                      return Container(
                        margin: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isPlayingNow
                              ? accent.withOpacity(0.14)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(14),
                          border: isPlayingNow
                              ? Border.all(color: accent.withOpacity(0.4))
                              : null,
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 2,
                          ),
                          leading: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 24,
                                child: Text(
                                  '${index + 1}',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: isPlayingNow ? accent : Colors.white54,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: CachedNetworkImage(
                                  imageUrl: song.thumbnailUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    width: 48,
                                    height: 48,
                                    color: Colors.white10,
                                    child: Icon(
                                      Icons.music_note_rounded,
                                      color: accent,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          title: Text(
                            song.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isPlayingNow ? accent : Colors.white,
                              fontWeight:
                                  isPlayingNow ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            '${song.artist} • ${song.formattedDuration}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 12,
                            ),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Tambah ke Antrean',
                                icon: const Icon(
                                  Icons.playlist_add_rounded,
                                  color: Colors.white60,
                                  size: 21,
                                ),
                                onPressed: () {
                                  player.addToQueue(song);
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
                              PopupMenuButton<String>(
                                icon: const Icon(
                                  Icons.more_vert_rounded,
                                  color: Colors.white54,
                                  size: 20,
                                ),
                                color: const Color(0xFF171C2B),
                                onSelected: (action) {
                                  if (action == 'play_next') {
                                    player.playNextInQueue(song);
                                  } else if (action == 'fav') {
                                    library.toggleFavorite(song);
                                  } else if (action == 'remove') {
                                    library.removeSongFromPlaylist(
                                      playlist.id,
                                      song.videoId,
                                    );
                                  }
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'play_next',
                                    child: Text(
                                      'Putar Berikutnya',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'fav',
                                    child: Text(
                                      'Tambah / Hapus Favorit',
                                      style: TextStyle(color: Colors.white),
                                    ),
                                  ),
                                  const PopupMenuItem(
                                    value: 'remove',
                                    child: Text(
                                      'Hapus dari Playlist',
                                      style: TextStyle(color: Colors.redAccent),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            player.playSong(song, customQueue: playlist.songs);
                          },
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
      width: 92,
      height: 92,
      decoration: BoxDecoration(
        color: accent.withOpacity(0.18),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Icon(Icons.queue_music_rounded, color: accent, size: 42),
    );
  }
}
