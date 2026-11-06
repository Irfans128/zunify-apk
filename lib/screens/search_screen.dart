import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_model.dart';
import '../providers/library_provider.dart';
import '../providers/theme_provider.dart';
import '../services/ytmusic_service.dart';
import '../widgets/song_tile_widget.dart';
import 'artist_profile_screen.dart';
import 'library_screen.dart';

class SearchScreen extends StatefulWidget {
  final YTMusicService ytMusicService;

  const SearchScreen({super.key, required this.ytMusicService});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const String _kSearchHistoryKey = 'zunify_search_history_v1';

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<ZunifySong> _results = [];
  ZunifyArtistSummary? _matchedArtist;
  List<String> _suggestions = [];
  List<String> _searchHistory = [];

  bool _isSearching = false;
  bool _showingSuggestions = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadSearchHistory();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  Future<void> _loadSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getStringList(_kSearchHistoryKey) ?? [];
      if (mounted) {
        setState(() => _searchHistory = saved);
      }
    } catch (_) {}
  }

  Future<void> _saveQueryToHistory(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    final updated = <String>[
      clean,
      ..._searchHistory.where(
        (item) => item.toLowerCase() != clean.toLowerCase(),
      ),
    ].take(15).toList();
    setState(() => _searchHistory = updated);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kSearchHistoryKey, updated);
    } catch (_) {}
  }

  Future<void> _removeHistoryItem(String query) async {
    final updated = _searchHistory.where((item) => item != query).toList();
    setState(() => _searchHistory = updated);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_kSearchHistoryKey, updated);
    } catch (_) {}
  }

  Future<void> _clearAllHistory() async {
    setState(() => _searchHistory = []);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kSearchHistoryKey);
    } catch (_) {}
  }

  void _onSearchTextChanged(String text) {
    _debounceTimer?.cancel();
    final trimmed = text.trim();
    if (trimmed.isEmpty) {
      setState(() {
        _suggestions = [];
        _showingSuggestions = false;
        _results = [];
        _matchedArtist = null;
      });
      return;
    }

    setState(() {
      _showingSuggestions = true;
    });

    _debounceTimer = Timer(const Duration(milliseconds: 220), () async {
      final fetched = await widget.ytMusicService.getSearchSuggestions(trimmed);
      if (!mounted) return;
      if (_searchController.text.trim() == trimmed) {
        setState(() {
          _suggestions = fetched;
        });
      }
    });
  }

  Future<void> _performSearch(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    _debounceTimer?.cancel();
    _searchFocusNode.unfocus();
    _searchController.text = clean;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: clean.length),
    );

    unawaited(_saveQueryToHistory(clean));

    setState(() {
      _isSearching = true;
      _showingSuggestions = false;
    });

    final resultsFuture = widget.ytMusicService.searchSongs(clean, limit: 25);
    final artistFuture = widget.ytMusicService.searchTopArtistMatch(clean);

    final res = await resultsFuture;
    ZunifyArtistSummary? topArtist;
    try {
      topArtist = await artistFuture;
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _results = res;
      _matchedArtist = topArtist;
      _isSearching = false;
      _showingSuggestions = false;
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
                    'Tempel link playlist publik dari Spotify atau YouTube Music. Zunify otomatis mengambil seluruh daftar lagunya tanpa batas jumlah lagu.',
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
                  focusNode: _searchFocusNode,
                  textInputAction: TextInputAction.search,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                  onChanged: _onSearchTextChanged,
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
                              _debounceTimer?.cancel();
                              _searchController.clear();
                              setState(() {
                                _results = [];
                                _matchedArtist = null;
                                _suggestions = [];
                                _showingSuggestions = false;
                              });
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

              // Results, Live Autocomplete Suggestions, or Browse Categories
              Expanded(
                child: _isSearching
                    ? Center(child: CircularProgressIndicator(color: accent))
                    : (_showingSuggestions && _suggestions.isNotEmpty)
                        ? _buildLiveSuggestionsList(accent)
                        : _results.isEmpty
                            ? _buildBrowseAndSuggestions(accent)
                            : _buildSearchResultsList(accent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveSuggestionsList(Color accent) {
    final currentText = _searchController.text.trim();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 112),
      itemCount: _suggestions.length,
      itemBuilder: (context, idx) {
        final suggestion = _suggestions[idx];
        return InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _performSearch(suggestion),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: accent.withOpacity(0.85),
                  size: 20,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildHighlightedSuggestionText(
                    suggestion,
                    currentText,
                    accent,
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: 'Isi ke kolom pencarian',
                  icon: const Icon(
                    Icons.north_west_rounded,
                    color: Colors.white38,
                    size: 18,
                  ),
                  onPressed: () {
                    _searchController.text = suggestion;
                    _searchController.selection = TextSelection.fromPosition(
                      TextPosition(offset: suggestion.length),
                    );
                    _onSearchTextChanged(suggestion);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHighlightedSuggestionText(
    String suggestion,
    String query,
    Color accent,
  ) {
    if (query.isEmpty) {
      return Text(
        suggestion,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14.2,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final lowerSug = suggestion.toLowerCase();
    final lowerQ = query.toLowerCase();
    final matchIdx = lowerSug.indexOf(lowerQ);
    if (matchIdx < 0) {
      return Text(
        suggestion,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 14.2,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    final before = suggestion.substring(0, matchIdx);
    final matched = suggestion.substring(matchIdx, matchIdx + query.length);
    final after = suggestion.substring(matchIdx + query.length);
    return RichText(
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14.2,
          fontWeight: FontWeight.w500,
        ),
        children: [
          if (before.isNotEmpty) TextSpan(text: before),
          TextSpan(
            text: matched,
            style: TextStyle(
              color: accent,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (after.isNotEmpty)
            TextSpan(
              text: after,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsList(Color accent) {
    final hasArtistCard = _matchedArtist != null;
    final totalCount = _results.length + (hasArtistCard ? 1 : 0);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 112),
      cacheExtent: 500,
      itemCount: totalCount,
      itemBuilder: (context, idx) {
        if (hasArtistCard && idx == 0) {
          final artist = _matchedArtist!;
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ArtistProfileScreen(
                    artistName: artist.name,
                    browseId: artist.browseId,
                    initialAvatarUrl: artist.thumbnailUrl,
                  ),
                ),
              );
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accent.withOpacity(0.20),
                    Colors.white.withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: accent.withOpacity(0.32)),
              ),
              child: Row(
                children: [
                  ClipOval(
                    child: artist.thumbnailUrl.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: artist.thumbnailUrl,
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              width: 56,
                              height: 56,
                              color: Colors.white10,
                              child: Icon(
                                Icons.person_rounded,
                                color: accent,
                                size: 28,
                              ),
                            ),
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            color: Colors.white10,
                            child: Icon(
                              Icons.person_rounded,
                              color: accent,
                              size: 28,
                            ),
                          ),
                  ),
                  const SizedBox(width: 14),
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
                                color: accent.withOpacity(0.22),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'PROFIL ARTIS',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.7,
                                ),
                              ),
                            ),
                            if (artist.subscribers.isNotEmpty) ...[
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  artist.subscribers,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Lihat lagu populer, album & single lengkap',
                          style: TextStyle(
                            color: Colors.white60,
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: accent,
                    size: 16,
                  ),
                ],
              ),
            ),
          );
        }

        final songIdx = hasArtistCard ? idx - 1 : idx;
        final item = _results[songIdx];
        return ZunifySongTile(
          song: item,
          queueContext: const [],
          contextName: 'Radio ${item.title}',
        );
      },
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
        if (_searchHistory.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Riwayat Pencarian',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              GestureDetector(
                onTap: _clearAllHistory,
                child: Text(
                  'Hapus Semua',
                  style: TextStyle(
                    color: accent,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._searchHistory.take(8).map((historyQuery) {
            return InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => _performSearch(historyQuery),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                child: Row(
                  children: [
                    const Icon(
                      Icons.history_rounded,
                      color: Colors.white54,
                      size: 19,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        historyQuery,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onTap: () => _removeHistoryItem(historyQuery),
                      child: const Padding(
                        padding: EdgeInsets.all(4.0),
                        child: Icon(
                          Icons.close_rounded,
                          color: Colors.white38,
                          size: 17,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 18),
        ],

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
