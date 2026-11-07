import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/ytmusic_service.dart';
import '../widgets/liquid_background_widget.dart';
import '../widgets/song_tile_widget.dart';
import 'artist_profile_screen.dart';
import 'library_screen.dart';

/// Reusable Import Playlist Bottom Sheet (Spotify & YouTube Music)
void showImportPlaylistSheet(BuildContext context) {
  final urlController = TextEditingController();
  final library = context.read<LibraryProvider>();

  bool isImporting = false;
  String progressStatus = '';
  double progressValue = 0.0;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final theme = ctx.watch<ThemeProvider>();
          final accent = theme.accentColor;
          final isBrutal = theme.isNeoBrutalism;

          return ZunifySheetContainer(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 14,
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
                      color: theme.dividerColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(
                      Icons.playlist_add_check_circle_rounded,
                      color: theme.accentText,
                      size: 24,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Import Playlist',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: urlController,
                  style: TextStyle(color: theme.textPrimary, fontSize: 13.5),
                  decoration: InputDecoration(
                    hintText: 'Tempel link playlist Spotify atau YouTube Music',
                    hintStyle: TextStyle(
                      color: theme.textMuted,
                      fontSize: 12.5,
                    ),
                    filled: true,
                    fillColor: isBrutal ? theme.cardBgColor : theme.subtleFill,
                    prefixIcon: Icon(
                      Icons.link_rounded,
                      color: theme.accentText,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(isBrutal ? 11 : 14),
                      borderSide: isBrutal
                          ? BorderSide(color: theme.brutalBorderColor, width: 2.0)
                          : BorderSide(color: theme.dividerColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(isBrutal ? 11 : 14),
                      borderSide: BorderSide(
                        color: isBrutal ? theme.brutalBorderColor : accent,
                        width: isBrutal ? 2.2 : 1.4,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                if (isImporting) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: progressValue > 0 ? progressValue : null,
                      color: theme.accentText,
                      backgroundColor: theme.dividerColor,
                      minHeight: 5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    progressStatus,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.accentText,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                ] else if (progressStatus.isNotEmpty) ...[
                  Text(
                    progressStatus,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: const Color(0xFF111111),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: isBrutal
                          ? BorderSide(
                              color: theme.brutalBorderColor,
                              width: 2.2,
                            )
                          : BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isBrutal ? 11 : 14),
                      ),
                    ),
                    onPressed: isImporting
                        ? null
                        : () async {
                            final rawUrl = urlController.text.trim();
                            if (rawUrl.isEmpty) return;

                            setModalState(() {
                              isImporting = true;
                              progressStatus = 'Memuat playlist...';
                            });

                            try {
                              final imported =
                                  await library.importExternalPlaylist(
                                rawUrl,
                                onProgress: (cur, tot, name) {
                                  if (!ctx.mounted) return;
                                  setModalState(() {
                                    progressValue = tot > 0 ? cur / tot : 0.0;
                                    progressStatus = '($cur/$tot) $name';
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
                                      'Berhasil import "${imported.name}" (${imported.songs.length} lagu)',
                                      style: const TextStyle(
                                        color: Color(0xFF111111),
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                );
                                showPlaylistDetailSheet(context, imported.id);
                              }
                            } catch (e) {
                              if (!ctx.mounted) return;
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
                      'Import Sekarang',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
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

class SearchScreen extends StatefulWidget {
  final YTMusicService ytMusicService;

  const SearchScreen({super.key, required this.ytMusicService});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  static const String _kSearchHistoryKey = 'zunify_search_history_v1';
  static const MethodChannel _nativeChannel = MethodChannel(
    'com.fannz.zunify/equalizer',
  );

  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();

  List<ZunifySong> _results = [];
  ZunifyArtistSummary? _matchedArtist;
  List<String> _suggestions = [];
  List<String> _searchHistory = [];

  bool _isSearching = false;
  bool _showingSuggestions = false;
  String _activeFilter = 'all'; // 'all' | 'official' | 'lyrics'
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

    _debounceTimer = Timer(const Duration(milliseconds: 200), () async {
      final fetched = await widget.ytMusicService.getSearchSuggestions(trimmed);
      if (!mounted) return;
      if (_searchController.text.trim() == trimmed) {
        setState(() {
          _suggestions = fetched;
        });
      }
    });
  }

  Future<void> _performSearch(
    String query, {
    bool allowArtistCard = true,
    String? filterMode,
  }) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    _debounceTimer?.cancel();
    _searchFocusNode.unfocus();
    _searchController.text = clean;
    _searchController.selection = TextSelection.fromPosition(
      TextPosition(offset: clean.length),
    );

    final effectiveFilter = filterMode ?? _activeFilter;
    unawaited(_saveQueryToHistory(clean));

    setState(() {
      _isSearching = true;
      _showingSuggestions = false;
      _activeFilter = effectiveFilter;
    });

    String effectiveQuery = clean;
    if (effectiveFilter == 'lyrics') {
      effectiveQuery = '$clean lyrics';
    } else if (effectiveFilter == 'official') {
      effectiveQuery = '$clean official audio';
    }

    final res = await widget.ytMusicService.searchSongs(
      effectiveQuery,
      limit: 25,
    );
    ZunifyArtistSummary? topArtist;
    if (allowArtistCard && effectiveFilter == 'all' && res.isNotEmpty) {
      try {
        topArtist = await widget.ytMusicService.resolveArtistForSearchQuery(
          clean,
          res,
        );
      } catch (_) {}
    }

    if (!mounted) return;
    setState(() {
      _results = res;
      _matchedArtist = topArtist;
      _isSearching = false;
      _showingSuggestions = false;
    });
  }

  /// Unified Voice Search Modal (Cari Lagu / Artis & Cari dari Lirik)
  Future<void> _openVoiceSearchModal(BuildContext context) async {
    _searchFocusNode.unfocus();

    String voiceMode = 'song'; // 'song' | 'lyrics'
    bool isListening = false;
    String statusText = 'Ketuk mikrofon untuk mulai bicara';

    Future<void> triggerSpeechRecognition(StateSetter setModalState) async {
      setModalState(() {
        isListening = true;
        statusText = voiceMode == 'lyrics'
            ? 'Mendengarkan potongan lirik...'
            : 'Sebutkan judul lagu atau artis...';
      });
      try {
        final spoken = await _nativeChannel.invokeMethod<String>(
          'startVoiceSearch',
        );
        if (!mounted) return;
        final cleaned = (spoken ?? '').trim();
        if (cleaned.isNotEmpty) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          _performSearch(
            cleaned,
            filterMode: voiceMode == 'lyrics' ? 'lyrics' : 'all',
          );
        } else {
          setModalState(() {
            isListening = false;
            statusText = 'Suara belum terdengar. Ketuk mikrofon untuk ulangi.';
          });
        }
      } catch (_) {
        if (!mounted) return;
        setModalState(() {
          isListening = false;
          statusText = 'Pencarian suara tidak tersedia di perangkat ini.';
        });
      }
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        var autoStarted = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final theme = ctx.watch<ThemeProvider>();
            final accent = theme.accentColor;
            final isBrutal = theme.isNeoBrutalism;

            if (!autoStarted) {
              autoStarted = true;
              Future.microtask(() => triggerSpeechRecognition(setModalState));
            }
            return ZunifySheetContainer(
              padding: const EdgeInsets.fromLTRB(22, 14, 22, 26),
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
                    const SizedBox(height: 18),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IosGlassPillButton(
                          label: 'Lagu / Artis',
                          icon: Icons.music_note_rounded,
                          isActive: voiceMode == 'song',
                          activeColor: accent,
                          onTap: () {
                            setModalState(() => voiceMode = 'song');
                            triggerSpeechRecognition(setModalState);
                          },
                        ),
                        const SizedBox(width: 10),
                        IosGlassPillButton(
                          label: 'Dari Lirik',
                          icon: Icons.lyrics_rounded,
                          isActive: voiceMode == 'lyrics',
                          activeColor: accent,
                          onTap: () {
                            setModalState(() => voiceMode = 'lyrics');
                            triggerSpeechRecognition(setModalState);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    IosSpringButton(
                      onTap: () => triggerSpeechRecognition(setModalState),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 84,
                        height: 84,
                        decoration: isBrutal
                            ? BoxDecoration(
                                color: isListening ? accent : theme.cardBgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: theme.brutalBorderColor,
                                  width: 2.6,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.brutalShadowColor,
                                    blurRadius: 0,
                                    offset: const Offset(4.5, 4.5),
                                  ),
                                ],
                              )
                            : BoxDecoration(
                                shape: BoxShape.circle,
                                color: isListening
                                    ? accent
                                    : accent.withOpacity(0.18),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withOpacity(
                                      isListening ? 0.48 : 0.20,
                                    ),
                                    blurRadius: isListening ? 28 : 14,
                                    spreadRadius: isListening ? 4 : 1,
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.32),
                                  width: 1.5,
                                ),
                              ),
                        child: Icon(
                          Icons.mic_rounded,
                          color: isListening
                              ? const Color(0xFF111111)
                              : theme.accentText,
                          size: 38,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      statusText,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      voiceMode == 'lyrics'
                          ? 'Ucapkan lirik lagu yang kamu ingat'
                          : 'Ucapkan judul lagu atau nama penyanyi',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
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
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Clean Header + Single Import Playlist Action (No Duplicate Mic Pill)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Cari',
                    style: GoogleFonts.plusJakartaSans(
                      color: theme.textPrimary,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                    ),
                  ),
                  IosGlassPillButton(
                    icon: Icons.add_link_rounded,
                    label: 'Import Playlist',
                    height: 34,
                    padding: const EdgeInsets.symmetric(horizontal: 13),
                    activeColor: accent,
                    isActive: true,
                    onTap: () => showImportPlaylistSheet(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Unified Search Input + Integrated YouTube-Style Voice Mic Button
              Row(
                children: [
                  Expanded(
                    child: LiquidGlassBox(
                      borderRadius: 23,
                      height: 46,
                      tintOpacity: 0.10,
                      rimIntensity: 0.38,
                      alignment: Alignment.center,
                      child: TextField(
                        controller: _searchController,
                        focusNode: _searchFocusNode,
                        textInputAction: TextInputAction.search,
                        textAlignVertical: TextAlignVertical.center,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                        onChanged: _onSearchTextChanged,
                        onSubmitted: (val) => _performSearch(val),
                        decoration: InputDecoration(
                          isDense: true,
                          hintText: 'Cari lagu, artis, atau lirik...',
                          hintStyle: TextStyle(
                            color: theme.textMuted,
                            fontSize: 13.5,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 11,
                          ),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: theme.accentText,
                            size: 20,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IosSpringButton(
                                  onTap: () {
                                    _debounceTimer?.cancel();
                                    _searchController.clear();
                                    setState(() {
                                      _results = [];
                                      _matchedArtist = null;
                                      _suggestions = [];
                                      _showingSuggestions = false;
                                    });
                                  },
                                  child: Icon(
                                    Icons.cancel_rounded,
                                    color: theme.textMuted,
                                    size: 18,
                                  ),
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IosGlassIconButton(
                    icon: Icons.mic_rounded,
                    size: 46,
                    iconSize: 21,
                    isActive: true,
                    activeColor: accent,
                    tooltip: 'Cari pakai suara',
                    onTap: () => _openVoiceSearchModal(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Quick Filter Pills when results or search active
              if (_results.isNotEmpty || _isSearching) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      IosGlassPillButton(
                        icon: Icons.music_note_rounded,
                        label: 'Semua Lagu',
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        activeColor: accent,
                        isActive: _activeFilter == 'all',
                        onTap: () {
                          if (_activeFilter != 'all') {
                            _performSearch(
                              _searchController.text,
                              filterMode: 'all',
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      IosGlassPillButton(
                        icon: Icons.verified_rounded,
                        label: 'Audio Resmi',
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        activeColor: accent,
                        isActive: _activeFilter == 'official',
                        onTap: () {
                          if (_activeFilter != 'official') {
                            _performSearch(
                              _searchController.text,
                              filterMode: 'official',
                            );
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      IosGlassPillButton(
                        icon: Icons.lyrics_rounded,
                        label: 'Dari Lirik',
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        activeColor: accent,
                        isActive: _activeFilter == 'lyrics',
                        onTap: () {
                          if (_activeFilter != 'lyrics') {
                            _performSearch(
                              _searchController.text,
                              filterMode: 'lyrics',
                            );
                          }
                        },
                      ),
                      if (_results.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        IosGlassPillButton(
                          icon: Icons.play_arrow_rounded,
                          label: 'Putar Semua',
                          height: 32,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          activeColor: accent,
                          onTap: () {
                            context.read<PlayerProvider>().playSong(
                              _results.first,
                              customQueue: _results,
                              contextName:
                                  'Pencarian ${_searchController.text.trim()}',
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 10),
              ],

              // Results, Live Autocomplete Suggestions, or Browse Categories
              Expanded(
                child: _isSearching
                    ? Center(
                        child: CircularProgressIndicator(
                          color: theme.accentText,
                        ),
                      )
                    : (_showingSuggestions && _suggestions.isNotEmpty)
                        ? _buildLiveSuggestionsList(theme)
                        : _results.isEmpty
                            ? _buildBrowseAndSuggestions(theme, accent)
                            : _buildSearchResultsList(theme, accent),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveSuggestionsList(ThemeProvider theme) {
    final currentText = _searchController.text.trim();
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 176),
      physics: const BouncingScrollPhysics(),
      itemCount: _suggestions.length,
      itemBuilder: (context, idx) {
        final suggestion = _suggestions[idx];
        return IosSpringButton(
          onTap: () => _performSearch(suggestion),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 9),
            child: Row(
              children: [
                Icon(
                  Icons.search_rounded,
                  color: theme.accentText,
                  size: 19,
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _buildHighlightedSuggestionText(
                    suggestion,
                    currentText,
                    theme,
                  ),
                ),
                IosSpringButton(
                  onTap: () {
                    _searchController.text = suggestion;
                    _searchController.selection = TextSelection.fromPosition(
                      TextPosition(offset: suggestion.length),
                    );
                    _onSearchTextChanged(suggestion);
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(6.0),
                    child: Icon(
                      Icons.north_west_rounded,
                      color: theme.textMuted,
                      size: 17,
                    ),
                  ),
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
    ThemeProvider theme,
  ) {
    if (query.isEmpty) {
      return Text(
        suggestion,
        style: TextStyle(
          color: theme.textPrimary,
          fontSize: 14,
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
        style: TextStyle(
          color: theme.textPrimary,
          fontSize: 14,
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
        style: TextStyle(
          color: theme.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        children: [
          if (before.isNotEmpty) TextSpan(text: before),
          TextSpan(
            text: matched,
            style: TextStyle(
              color: theme.accentText,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (after.isNotEmpty)
            TextSpan(
              text: after,
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResultsList(ThemeProvider theme, Color accent) {
    final hasArtistCard = _matchedArtist != null;
    final totalCount = _results.length + (hasArtistCard ? 1 : 0);

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 176),
      physics: const BouncingScrollPhysics(),
      cacheExtent: 500,
      itemCount: totalCount,
      itemBuilder: (context, idx) {
        if (hasArtistCard && idx == 0) {
          final artist = _matchedArtist!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: LiquidGlassBox(
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              tintColor: accent,
              tintOpacity: 0.14,
              rimIntensity: 0.44,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ArtistProfileScreen(
                      artistName: artist.name,
                      browseId: artist.browseId,
                    ),
                  ),
                );
              },
              child: Row(
                children: [
                  Container(
                    decoration: theme.isNeoBrutalism
                        ? BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: theme.brutalBorderColor,
                              width: 2.0,
                            ),
                          )
                        : null,
                    child: ClipOval(
                      child: artist.avatarUrl.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: artist.avatarUrl,
                              width: 52,
                              height: 52,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 52,
                                height: 52,
                                color: theme.subtleFill,
                                child: Icon(
                                  Icons.person_rounded,
                                  color: theme.accentText,
                                  size: 26,
                                ),
                              ),
                            )
                          : Container(
                              width: 52,
                              height: 52,
                              color: theme.subtleFill,
                              child: Icon(
                                Icons.person_rounded,
                                color: theme.accentText,
                                size: 26,
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
                          artist.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          artist.subtitle.isNotEmpty
                              ? artist.subtitle
                              : 'Profil Artis',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.accentText,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: theme.accentText,
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
          queueContext: _results,
          contextName: 'Pencarian',
        );
      },
    );
  }

  Widget _buildBrowseAndSuggestions(ThemeProvider theme, Color accent) {
    final isBrutal = theme.isNeoBrutalism;
    const categories = [
      {
        'title': 'Pop Indonesia',
        'query': 'Lagu Pop Indonesia Hits',
        'color': 0xFF10B981,
        'icon': Icons.music_note_rounded,
      },
      {
        'title': 'Hits Global',
        'query': 'Top Global Hits 2025',
        'color': 0xFF6366F1,
        'icon': Icons.public_rounded,
      },
      {
        'title': 'Galau Malam',
        'query': 'Lagu Galau Indonesia Terbaik',
        'color': 0xFF3B82F6,
        'icon': Icons.nightlight_round,
      },
      {
        'title': 'Indie & Senja',
        'query': 'Hindia Perunggu Feast Indie',
        'color': 0xFFF59E0B,
        'icon': Icons.wb_twilight_rounded,
      },
      {
        'title': 'J-Pop & Anime',
        'query': 'YOASOBI Kenshi Yonezu Anime',
        'color': 0xFFEC4899,
        'icon': Icons.auto_awesome_rounded,
      },
      {
        'title': 'K-Pop Hits',
        'query': 'NewJeans aespa DAY6 Kpop',
        'color': 0xFF8B5CF6,
        'icon': Icons.bolt_rounded,
      },
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
      padding: const EdgeInsets.only(bottom: 176),
      physics: const BouncingScrollPhysics(),
      children: [
        if (_searchHistory.isNotEmpty) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Riwayat Pencarian',
                style: TextStyle(
                  color: theme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 15.5,
                ),
              ),
              IosSpringButton(
                onTap: _clearAllHistory,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 4,
                  ),
                  child: Text(
                    'Hapus Semua',
                    style: TextStyle(
                      color: theme.accentText,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _searchHistory.take(8).map((historyQuery) {
              return LiquidGlassBox(
                borderRadius: 16,
                padding: const EdgeInsets.fromLTRB(12, 7, 8, 7),
                tintOpacity: 0.08,
                rimIntensity: 0.28,
                onTap: () => _performSearch(historyQuery),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.history_rounded,
                      color: theme.textMuted,
                      size: 15,
                    ),
                    const SizedBox(width: 6),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 170),
                      child: Text(
                        historyQuery,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IosSpringButton(
                      onTap: () => _removeHistoryItem(historyQuery),
                      child: Padding(
                        padding: const EdgeInsets.all(2.0),
                        child: Icon(
                          Icons.close_rounded,
                          color: theme.textMuted,
                          size: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 18),
        ],

        Text(
          'Kategori Musik',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 15.5,
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
            mainAxisExtent: 64,
          ),
          itemBuilder: (context, idx) {
            final item = categories[idx];
            final cardColor = Color(item['color'] as int);
            final iconData = item['icon'] as IconData;
            return LiquidGlassBox(
              borderRadius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
              tintColor: cardColor,
              tintOpacity: isBrutal ? 0.14 : 0.22,
              rimIntensity: 0.38,
              onTap: () {
                final q = item['query'] as String;
                _searchController.text = item['title'] as String;
                _performSearch(q, allowArtistCard: false);
              },
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: isBrutal
                          ? cardColor
                          : cardColor.withOpacity(0.28),
                      borderRadius: BorderRadius.circular(isBrutal ? 8 : 10),
                      border: isBrutal
                          ? Border.all(
                              color: theme.brutalBorderColor,
                              width: 1.7,
                            )
                          : null,
                    ),
                    child: Icon(iconData, color: Colors.white, size: 18),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      item['title'] as String,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.0,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Text(
          'Populer Dicari',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w800,
            fontSize: 15.5,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: quickQueries.map((s) {
            return IosGlassPillButton(
              icon: Icons.trending_up_rounded,
              label: s,
              height: 34,
              activeColor: accent,
              onTap: () {
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
