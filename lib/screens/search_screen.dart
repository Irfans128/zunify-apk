import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/library_provider.dart';
import '../providers/theme_provider.dart';
import '../services/ytmusic_service.dart';
import '../widgets/song_tile_widget.dart';
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
      backgroundColor: const Color(0xFF101420),
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
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.playlist_add_check_circle_rounded,
                        color: accent,
                        size: 26,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Import Playlist Spotify & YT Music',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Tempel link playlist publik dari Spotify atau YouTube Music. Zunify otomatis mengambil seluruh daftar lagunya.',
                    style: TextStyle(color: Colors.white60, fontSize: 12.5),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: urlController,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText:
                          'https://open.spotify.com/playlist/... atau music.youtube.com/...',
                      hintStyle: const TextStyle(
                        color: Colors.white38,
                        fontSize: 12.5,
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.06),
                      prefixIcon: Icon(Icons.link_rounded, color: accent),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (isImporting) ...[
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: progressValue > 0 ? progressValue : null,
                        color: accent,
                        backgroundColor: Colors.white12,
                        minHeight: 5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      progressStatus,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
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
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      onPressed: isImporting
                          ? null
                          : () async {
                              final rawUrl = urlController.text.trim();
                              if (rawUrl.isEmpty) return;

                              setModalState(() {
                                isImporting = true;
                                progressStatus =
                                    'Membaca daftar lagu playlist...';
                              });

                              try {
                                final imported =
                                    await library.importExternalPlaylist(
                                  rawUrl,
                                  onProgress: (cur, tot, name) {
                                    setModalState(() {
                                      progressValue = cur / tot;
                                      progressStatus =
                                          'Mencocokkan ($cur/$tot): $name';
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
                                  progressStatus = e
                                      .toString()
                                      .replaceAll('Exception: ', '');
                                });
                              }
                            },
                      icon: const Icon(Icons.cloud_download_rounded, size: 20),
                      label: const Text(
                        'Import Playlist Sekarang',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14.5,
                        ),
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
    final accent = theme.accentColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
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
                  InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _showImportPlaylistModal(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.07),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.add_link_rounded, color: accent, size: 17),
                          const SizedBox(width: 6),
                          const Text(
                            'Import Playlist',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Clean Search Input Field
              SizedBox(
                height: 46,
                child: TextField(
                  controller: _searchController,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onChanged: (_) => setState(() {}),
                  onSubmitted: _performSearch,
                  decoration: InputDecoration(
                    hintText: 'Lagu, artis, atau album...',
                    hintStyle: const TextStyle(
                      color: Colors.white38,
                      fontSize: 13.5,
                    ),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.08),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    prefixIcon: Icon(
                      Icons.search_rounded,
                      color: accent,
                      size: 20,
                    ),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(
                              Icons.clear_rounded,
                              color: Colors.white54,
                              size: 18,
                            ),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _results = []);
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Results or Browse Categories
              Expanded(
                child: _isSearching
                    ? Center(child: CircularProgressIndicator(color: accent))
                    : _results.isEmpty
                        ? _buildBrowseAndSuggestions(accent)
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 112),
                            cacheExtent: 500,
                            itemCount: _results.length,
                            itemBuilder: (context, idx) {
                              final item = _results[idx];
                              return ZunifySongTile(
                                song: item,
                                queueContext: const [],
                                contextName: 'Radio ${item.title}',
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

  Widget _buildBrowseAndSuggestions(Color accent) {
    const categories = [
      {'title': 'Pop Indonesia', 'query': 'Lagu Pop Indonesia Hits', 'color': 0xFF10B981},
      {'title': 'Hits Global', 'query': 'Top Global Hits 2025', 'color': 0xFF6366F1},
      {'title': 'Galau Malam', 'query': 'Lagu Galau Indonesia Terbaik', 'color': 0xFF3B82F6},
      {'title': 'Indie & Senja', 'query': 'Hindia Perunggu Feast Indie', 'color': 0xFFF59E0B},
      {'title': 'J-Pop & Anime', 'query': 'YOASOBI Kenshi Yonezu Anime', 'color': 0xFFEC4899},
      {'title': 'K-Pop Hits', 'query': 'NewJeans aespa DAY6 Kpop', 'color': 0xFF8B5CF6},
    ];

    const quickQueries = [
      'One Direction Night Changes',
      'Bernadya Untungnya Bumi Masih Berputar',
      'Hindia Evaluasi',
      'Tulus Hati-Hati di Jalan',
      'Sheila On 7 Dan',
      'The Weeknd Die For You',
    ];

    return ListView(
      padding: const EdgeInsets.only(bottom: 112),
      children: [
        const Text(
          'Jelajahi Genre',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 68,
          ),
          itemBuilder: (context, idx) {
            final item = categories[idx];
            final cardColor = Color(item['color'] as int);
            return GestureDetector(
              onTap: () {
                final q = item['query'] as String;
                _searchController.text = item['title'] as String;
                _performSearch(q);
              },
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      cardColor.withOpacity(0.65),
                      cardColor.withOpacity(0.25),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Colors.white.withOpacity(0.10)),
                ),
                alignment: Alignment.centerLeft,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        item['title'] as String,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    Icon(
                      Icons.play_circle_fill_rounded,
                      color: Colors.white.withOpacity(0.85),
                      size: 24,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 22),
        const Text(
          'Pencarian Populer',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quickQueries.map((s) {
            return InkWell(
              borderRadius: BorderRadius.circular(18),
              onTap: () {
                _searchController.text = s;
                _performSearch(s);
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.trending_up_rounded, color: accent, size: 15),
                    const SizedBox(width: 6),
                    Text(
                      s,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.2,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}
