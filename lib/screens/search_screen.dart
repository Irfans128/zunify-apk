import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/ytmusic_service.dart';
import 'library_screen.dart';

class SearchScreen extends StatefulWidget {
  final YTMusicService ytMusicService;

  const SearchScreen({super.key, required this.ytMusicService});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<ZunifySong> _results = [];
  bool _isSearching = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _performSearch(String query) async {
    if (query.trim().isEmpty) return;
    setState(() => _isSearching = true);
    final res = await widget.ytMusicService.searchSongs(query, limit: 25);
    if (!mounted) return;
    setState(() {
      _results = res;
      _isSearching = false;
    });
  }

  void _showImportPlaylistModal(BuildContext context) {
    final urlController = TextEditingController();
    final theme = context.read<ThemeProvider>();
    final library = context.read<LibraryProvider>();
    final accent = theme.accentColor;

    bool isImporting = false;
    String progressStatus = '';
    double progressValue = 0.0;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: theme.cardBgColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 18,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.playlist_add_check_circle_rounded, color: accent, size: 28),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Import Playlist Spotify & YT Music',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Paste link playlist publik dari Spotify atau YouTube Music. Zunify otomatis mencocokkan semua lagunya tanpa perlu login!',
                    style: TextStyle(color: Colors.white60, fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'https://open.spotify.com/playlist/... atau music.youtube.com/...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 13),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      prefixIcon: Icon(Icons.link_rounded, color: accent),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (isImporting) ...[
                    LinearProgressIndicator(
                      value: progressValue > 0 ? progressValue : null,
                      color: accent,
                      backgroundColor: Colors.white12,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      progressStatus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: accent, fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                  ],

                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: isImporting
                          ? null
                          : () async {
                              final rawUrl = urlController.text.trim();
                              if (rawUrl.isEmpty) return;

                              setModalState(() {
                                isImporting = true;
                                progressStatus = 'Membaca daftar lagu playlist...';
                              });

                              try {
                                final imported = await library.importExternalPlaylist(
                                  rawUrl,
                                  onProgress: (cur, tot, name) {
                                    setModalState(() {
                                      progressValue = cur / tot;
                                      progressStatus = 'Mencocokkan ($cur/$tot): $name';
                                    });
                                  },
                                );
                                if (!ctx.mounted) return;
                                Navigator.pop(ctx);
                                if (imported != null && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: accent,
                                      content: Text(
                                        'Berhasil import "${imported.name}" (${imported.songs.length} lagu)!',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  );
                                  showPlaylistDetailSheet(context, imported.id);
                                }
                              } catch (e) {
                                setModalState(() {
                                  isImporting = false;
                                  progressStatus = e.toString().replaceAll('Exception: ', '');
                                });
                              }
                            },
                      icon: const Icon(Icons.cloud_download_rounded),
                      label: const Text(
                        'Mulai Import Playlist Sekarang',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<PlayerProvider>();
    final library = context.watch<LibraryProvider>();
    final accent = theme.accentColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clean Header + Import Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Cari',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.4,
                    ),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.08),
                      foregroundColor: accent,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: Colors.white.withOpacity(0.12)),
                      ),
                    ),
                    onPressed: () => _showImportPlaylistModal(context),
                    icon: const Icon(Icons.add_link_rounded, size: 18),
                    label: const Text(
                      'Import Playlist',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Search Input Field
              TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                style: const TextStyle(color: Colors.white),
                onSubmitted: _performSearch,
                decoration: InputDecoration(
                  hintText: 'Lagu atau artis...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.07),
                  prefixIcon: Icon(Icons.search_rounded, color: accent),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, color: Colors.white54),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _results = []);
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(18),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Results List
              Expanded(
                child: _isSearching
                    ? Center(child: CircularProgressIndicator(color: accent))
                    : _results.isEmpty
                        ? _buildQuickSearchSuggestions(accent)
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 110),
                            itemCount: _results.length,
                            itemBuilder: (context, idx) {
                              final song = _results[idx];
                              final isDown = library.isDownloaded(song.videoId);
                              final isFav = library.isFavorite(song.videoId);

                              return ListTile(
                                contentPadding: const EdgeInsets.symmetric(vertical: 3),
                                leading: ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: CachedNetworkImage(
                                    imageUrl: song.thumbnailUrl,
                                    width: 52,
                                    height: 52,
                                    fit: BoxFit.cover,
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
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      tooltip: 'Tambah ke Antrean',
                                      visualDensity: VisualDensity.compact,
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
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(
                                        isFav
                                            ? Icons.favorite_rounded
                                            : Icons.favorite_border_rounded,
                                        color: isFav ? accent : Colors.white38,
                                        size: 20,
                                      ),
                                      onPressed: () => library.toggleFavorite(song),
                                    ),
                                    IconButton(
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(
                                        isDown
                                            ? Icons.offline_pin_rounded
                                            : Icons.download_for_offline_outlined,
                                        color: isDown ? accent : Colors.white54,
                                        size: 21,
                                      ),
                                      onPressed: () {
                                        if (!isDown) {
                                          library.downloadSong(
                                            song,
                                            highQuality: player.highQualityAudio,
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                                onTap: () => player.playSong(song, customQueue: _results),
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSearchSuggestions(Color accent) {
    const suggestions = [
      'One Direction Night Changes',
      'Hindia Evaluasi',
      'Bernadya Untungnya Bumi Masih Berputar',
      'Tulus Hati-Hati di Jalan',
      'Sheila On 7 Dan',
      'The Weeknd Die For You',
      'YOASOBI Idol',
      'Joji Glimpse of Us',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Pencarian Populer 🔥',
          style: TextStyle(
            color: Colors.white70,
            fontWeight: FontWeight.bold,
            fontSize: 14,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestions.map((s) {
            return ActionChip(
              backgroundColor: Colors.white.withOpacity(0.06),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
              avatar: Icon(Icons.trending_up_rounded, color: accent, size: 16),
              label: Text(
                s,
                style: const TextStyle(color: Colors.white, fontSize: 12.5),
              ),
              onPressed: () {
                _searchController.text = s;
                _performSearch(s);
              },
            );
          }).toList(),
        ),
      ],
    );
  }
}
