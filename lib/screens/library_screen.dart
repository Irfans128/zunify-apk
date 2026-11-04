import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/playlist_model.dart';
import '../models/song_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/weekly_rapot_modal.dart';

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

  void _showCreatePlaylistDialog(BuildContext context, LibraryProvider library, Color accent) {
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
                      IconButton(
                        tooltip: 'Rapot Mingguan',
                        icon: Icon(Icons.bar_chart_rounded, color: accent),
                        onPressed: () async {
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
                      const SizedBox(width: 4),
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
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
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
                Tab(text: 'Offline (${library.downloadedSongs.length})'),
                Tab(text: 'Playlist (${library.playlists.length})'),
                Tab(text: 'Favorit (${library.favorites.length})'),
              ],
            ),

            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // Tab 1: Private In-App Downloaded Songs
                  _buildSongList(
                    library.downloadedSongs,
                    emptyText:
                        'Belum ada lagu di Private Vault.\nKetuk ikon Download di player atau pencarian untuk mendengar offline tanpa kuota!',
                    player: player,
                    library: library,
                    accent: accent,
                    allowDeleteDownload: true,
                  ),

                  // Tab 2: Playlists (Local + Spotify Import + YT Music Import)
                  _buildPlaylistsTab(library, player, accent),

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
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            '${song.artist} • ${song.audioBitrateKbps} kbps',
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          trailing: allowDeleteDownload
              ? IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, color: Colors.white54),
                  onPressed: () => library.removeDownloadedSong(song.videoId),
                )
              : IconButton(
                  icon: Icon(Icons.favorite_rounded, color: accent),
                  onPressed: () => library.toggleFavorite(song),
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
        return Card(
          color: Colors.white.withOpacity(0.05),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.queue_music_rounded, color: accent, size: 28),
            ),
            title: Text(
              pl.name,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15.5,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${pl.originBadgeLabel} • ${pl.songs.length} lagu',
                  style: TextStyle(color: accent, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                if (pl.description.isNotEmpty)
                  Text(
                    pl.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white54, fontSize: 12),
                  ),
              ],
            ),
            trailing: IconButton(
              icon: const Icon(Icons.play_circle_fill_rounded, size: 36),
              color: accent,
              onPressed: () {
                if (pl.songs.isNotEmpty) {
                  player.playSong(pl.songs.first, customQueue: pl.songs);
                }
              },
            ),
          ),
        );
      },
    );
  }
}
