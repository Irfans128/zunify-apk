import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/song_model.dart';
import '../providers/library_provider.dart';
import '../providers/theme_provider.dart';
import '../services/ytmusic_service.dart';
import '../widgets/liquid_background_widget.dart';
import '../widgets/song_tile_widget.dart';
import 'artist_profile_screen.dart';
import 'library_screen.dart';

/// Reusable Import Playlist Bottom Sheet (Spotify & YouTube Music) — True Liquid Glass & Neo-Brutalism
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
            blurSigma: 32,
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
                    LiquidGlassBox(
                      width: 40,
                      height: 40,
                      borderRadius: 13,
                      tintColor: accent,
                      tintOpacity: isBrutal ? 0.24 : 0.22,
                      rimIntensity: 0.50,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.playlist_add_check_circle_rounded,
                        color: isBrutal ? const Color(0xFF111111) : accent,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Import Playlist',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 17.5,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Tempel link playlist Spotify atau YouTube Music',
                            style: TextStyle(
                              color: theme.textMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LiquidGlassBox(
                  borderRadius: 18,
                  tintColor: accent,
                  tintOpacity: isBrutal ? 0.0 : 0.08,
                  rimIntensity: 0.46,
                  padding: const EdgeInsets.fromLTRB(14, 4, 8, 4),
                  child: Row(
                    children: [
                      Icon(
                        Icons.link_rounded,
                        color: theme.accentText,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: urlController,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            hintText: 'https://open.spotify.com/playlist/...',
                            hintStyle: TextStyle(
                              color: theme.textMuted,
                              fontSize: 12.5,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 11,
                            ),
                          ),
                        ),
                      ),
                      IosSpringButton(
                        onTap: () async {
                          final clip = await Clipboard.getData(
                            Clipboard.kTextPlain,
                          );
                          final text = (clip?.text ?? '').trim();
                          if (text.isNotEmpty) {
                            urlController.text = text;
                            urlController.selection =
                                TextSelection.fromPosition(
                                  TextPosition(offset: text.length),
                                );
                            setModalState(() {});
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: isBrutal
                                ? accent.withOpacity(0.28)
                                : Colors.white.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(
                              isBrutal ? 8 : 11,
                            ),
                            border: Border.all(
                              color: isBrutal
                                  ? theme.brutalBorderColor
                                  : Colors.white.withOpacity(0.20),
                              width: isBrutal ? 1.5 : 0.9,
                            ),
                          ),
                          child: Text(
                            'Tempel',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (isImporting) ...[
                  LiquidGlassBox(
                    borderRadius: 14,
                    tintColor: accent,
                    tintOpacity: 0.10,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 11,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progressValue > 0 ? progressValue : null,
                            color: accent,
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
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                ] else if (progressStatus.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      progressStatus,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.redAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
                Row(
                  children: [
                    Expanded(
                      child: LiquidGlassBox(
                        height: 46,
                        borderRadius: 15,
                        tintOpacity: 0.06,
                        rimIntensity: 0.30,
                        alignment: Alignment.center,
                        onTap: isImporting ? null : () => Navigator.pop(ctx),
                        child: Text(
                          'Batal',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: IosSpringButton(
                        enabled: !isImporting,
                        onTap: () async {
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
                                      progressValue =
                                          tot > 0 ? cur / tot : 0.0;
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
                        child: Container(
                          height: 46,
                          alignment: Alignment.center,
                          decoration: isBrutal
                              ? BoxDecoration(
                                  color: accent,
                                  borderRadius: BorderRadius.circular(11),
                                  border: Border.all(
                                    color: theme.brutalBorderColor,
                                    width: 2.2,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: theme.brutalShadowColor,
                                      blurRadius: 0,
                                      offset: const Offset(3, 3),
                                    ),
                                  ],
                                )
                              : BoxDecoration(
                                  borderRadius: BorderRadius.circular(15),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color.lerp(accent, Colors.white, 0.24)!,
                                      accent,
                                    ],
                                  ),
                                  border: Border.all(
                                    color: Colors.white.withOpacity(0.38),
                                    width: 1.1,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: accent.withOpacity(0.38),
                                      blurRadius: 18,
                                      offset: const Offset(0, 6),
                                    ),
                                  ],
                                ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.cloud_download_rounded,
                                size: 19,
                                color: Color(0xFF0B0E17),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isImporting ? 'Mengimpor...' : 'Import Sekarang',
                                style: const TextStyle(
                                  color: Color(0xFF0B0E17),
                                  fontWeight: FontWeight.w900,
                                  fontSize: 13.5,
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
  }) async {
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

    final res = await widget.ytMusicService.searchSongs(
      clean,
      limit: 25,
    );
    ZunifyArtistSummary? topArtist;
    if (allowArtistCard && res.isNotEmpty) {
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

  /// Custom In-App Multilingual Voice Search Sheet (Liquid Glass & Neo-Brutalism — No Google Popup)
  Future<void> _openVoiceSearchModal(BuildContext context) async {
    _searchFocusNode.unfocus();

    String selectedLang = 'auto'; // 'auto' | 'id-ID' | 'en-US' | 'ja-JP' | 'ko-KR'
    bool isListening = false;
    bool isProcessing = false;
    bool modalClosed = false;
    String liveTranscript = '';
    String statusText = 'Mendengarkan judul lagu atau artis...';
    double rmsLevel = 0.0; // normalized 0.0 .. 1.0

    const langOptions = [
      {'code': 'auto', 'label': 'Otomatis'},
      {'code': 'id-ID', 'label': 'ID'},
      {'code': 'en-US', 'label': 'EN'},
      {'code': 'ja-JP', 'label': 'JP'},
      {'code': 'ko-KR', 'label': 'KR'},
    ];

    StateSetter? sheetSetState;

    void safeSetModal(VoidCallback fn) {
      if (modalClosed || !mounted || sheetSetState == null) return;
      try {
        sheetSetState!(fn);
      } catch (_) {}
    }

    Future<void> startListeningSession() async {
      safeSetModal(() {
        isListening = true;
        isProcessing = false;
        liveTranscript = '';
        rmsLevel = 0.14;
        statusText = 'Mendengarkan judul lagu atau artis...';
      });
      try {
        await _nativeChannel.invokeMethod('startCustomVoice', {
          'lang': selectedLang,
        });
      } catch (_) {
        safeSetModal(() {
          isListening = false;
          isProcessing = false;
          rmsLevel = 0.0;
          statusText = 'Mesin suara belum tersedia di perangkat ini.';
        });
      }
    }

    Future<void> stopOrToggleSession() async {
      if (isListening) {
        if (liveTranscript.trim().isNotEmpty) {
          final query = liveTranscript.trim();
          modalClosed = true;
          unawaited(_nativeChannel.invokeMethod('cancelCustomVoice'));
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          }
          _performSearch(query);
          return;
        }
        safeSetModal(() {
          isListening = false;
          isProcessing = true;
          rmsLevel = 0.06;
          statusText = 'Memproses suara...';
        });
        try {
          await _nativeChannel.invokeMethod('stopCustomVoice');
        } catch (_) {}
      } else {
        await startListeningSession();
      }
    }

    _nativeChannel.setMethodCallHandler((call) async {
      if (call.method != 'onVoiceEvent' || modalClosed || !mounted) return;
      final raw = call.arguments;
      if (raw is! Map) return;
      final type = (raw['type'] ?? '').toString();

      switch (type) {
        case 'ready':
          safeSetModal(() {
            isListening = true;
            isProcessing = false;
            statusText = 'Sebutkan judul lagu atau nama artis...';
          });
          break;
        case 'speaking':
          safeSetModal(() {
            isListening = true;
            isProcessing = false;
            statusText = 'Mendeteksi suara...';
          });
          break;
        case 'rms':
          final db = (raw['rms'] as num?)?.toDouble() ?? 0.0;
          final norm = ((db + 2.0) / 12.0).clamp(0.05, 1.0);
          safeSetModal(() {
            rmsLevel = norm;
          });
          break;
        case 'partial':
          final text = (raw['text'] ?? '').toString().trim();
          if (text.isNotEmpty) {
            safeSetModal(() {
              liveTranscript = text;
            });
          }
          break;
        case 'processing':
          safeSetModal(() {
            isListening = false;
            isProcessing = true;
            rmsLevel = 0.08;
            statusText = 'Mencocokkan judul lagu...';
          });
          break;
        case 'result':
          final text = (raw['text'] ?? '').toString().trim();
          if (text.isNotEmpty) {
            modalClosed = true;
            if (Navigator.canPop(context)) {
              Navigator.pop(context);
            }
            _performSearch(text);
          } else {
            safeSetModal(() {
              isListening = false;
              isProcessing = false;
              rmsLevel = 0.0;
              statusText = 'Belum terdengar jelas. Ketuk mikrofon lagi.';
            });
          }
          break;
        case 'permission_denied':
          safeSetModal(() {
            isListening = false;
            isProcessing = false;
            rmsLevel = 0.0;
            statusText = 'Izinkan akses mikrofon untuk pencarian suara.';
          });
          break;
        case 'error':
          final msg = (raw['message'] ?? '').toString().trim();
          safeSetModal(() {
            isListening = false;
            isProcessing = false;
            rmsLevel = 0.0;
            statusText = msg.isNotEmpty
                ? msg
                : 'Suara belum terdeteksi. Ketuk mikrofon untuk ulangi.';
          });
          break;
      }
    });

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        var autoStarted = false;
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            sheetSetState = setModalState;
            final theme = ctx.watch<ThemeProvider>();
            final accent = theme.accentColor;
            final secondary = theme.secondaryGlowColor;
            final isBrutal = theme.isNeoBrutalism;

            if (!autoStarted) {
              autoStarted = true;
              Future.microtask(startListeningSession);
            }

            const waveWeights = [0.34, 0.56, 0.80, 0.96, 1.0, 0.92, 0.76, 0.52, 0.32];

            return ZunifySheetContainer(
              blurSigma: 34,
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
                    const SizedBox(height: 14),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.graphic_eq_rounded,
                              color: theme.accentText,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pencarian Suara',
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 16.5,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.3,
                              ),
                            ),
                          ],
                        ),
                        IosGlassIconButton(
                          icon: Icons.close_rounded,
                          size: 32,
                          iconSize: 17,
                          onTap: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Minimal Multilingual Quick Selector (Auto: ID/EN/JP/KR)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: langOptions.map((opt) {
                          final code = opt['code']!;
                          final label = opt['label']!;
                          final active = selectedLang == code;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3.5),
                            child: IosSpringButton(
                              onTap: () {
                                if (selectedLang == code) return;
                                setModalState(() => selectedLang = code);
                                startListeningSession();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 180),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                                decoration: isBrutal
                                    ? BoxDecoration(
                                        color: active ? accent : theme.cardBgColor,
                                        borderRadius: BorderRadius.circular(9),
                                        border: Border.all(
                                          color: theme.brutalBorderColor,
                                          width: active ? 2.0 : 1.5,
                                        ),
                                        boxShadow: active
                                            ? [
                                                BoxShadow(
                                                  color: theme.brutalShadowColor,
                                                  blurRadius: 0,
                                                  offset: const Offset(2, 2),
                                                ),
                                              ]
                                            : const [],
                                      )
                                    : BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        color: active
                                            ? accent.withOpacity(0.24)
                                            : Colors.white.withOpacity(0.06),
                                        border: Border.all(
                                          color: active
                                              ? accent.withOpacity(0.65)
                                              : Colors.white.withOpacity(0.14),
                                          width: 1.0,
                                        ),
                                      ),
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    color: active
                                        ? (isBrutal
                                              ? const Color(0xFF111111)
                                              : Colors.white)
                                        : theme.textSecondary,
                                    fontSize: 11.8,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                    const SizedBox(height: 22),

                    // Live 9-Bar Theme-Integrated Soundwave Visualizer
                    SizedBox(
                      height: 44,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: List.generate(waveWeights.length, (i) {
                          final weight = waveWeights[i];
                          final activeEnergy = isListening
                              ? math.max(0.16, rmsLevel * weight)
                              : (isProcessing ? 0.25 * weight : 0.12);
                          final barHeight = (8.0 + activeEnergy * 34.0).clamp(
                            8.0,
                            42.0,
                          );
                          final barColor = isBrutal
                              ? (isListening ? accent : theme.brutalBorderColor)
                              : Color.lerp(
                                  accent,
                                  secondary,
                                  i / (waveWeights.length - 1),
                                )!;

                          return AnimatedContainer(
                            duration: const Duration(milliseconds: 95),
                            curve: Curves.easeOut,
                            margin: const EdgeInsets.symmetric(horizontal: 3.5),
                            width: isBrutal ? 6.5 : 5.5,
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: isListening || isProcessing
                                  ? barColor
                                  : theme.dividerColor,
                              borderRadius: BorderRadius.circular(
                                isBrutal ? 3 : 99,
                              ),
                              border: isBrutal
                                  ? Border.all(
                                      color: theme.brutalBorderColor,
                                      width: 1.2,
                                    )
                                  : null,
                              boxShadow: (!isBrutal && isListening)
                                  ? [
                                      BoxShadow(
                                        color: barColor.withOpacity(0.45),
                                        blurRadius: 8,
                                      ),
                                    ]
                                  : const [],
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Live Spoken Song Title / Status Display
                    ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 160),
                          child: Text(
                            liveTranscript.isNotEmpty
                                ? '"$liveTranscript"'
                                : statusText,
                            key: ValueKey(
                              liveTranscript.isNotEmpty
                                  ? liveTranscript
                                  : statusText,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: liveTranscript.isNotEmpty
                                  ? theme.textPrimary
                                  : theme.textSecondary,
                              fontSize: liveTranscript.isNotEmpty ? 17 : 13.5,
                              fontWeight: liveTranscript.isNotEmpty
                                  ? FontWeight.w800
                                  : FontWeight.w700,
                              letterSpacing: -0.2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // Single Clean Central Mic Button
                    IosSpringButton(
                      onTap: stopOrToggleSession,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        width: 78,
                        height: 78,
                        decoration: isBrutal
                            ? BoxDecoration(
                                color: isListening ? accent : theme.cardBgColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: theme.brutalBorderColor,
                                  width: 2.5,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.brutalShadowColor,
                                    blurRadius: 0,
                                    offset: const Offset(4, 4),
                                  ),
                                ],
                              )
                            : BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: isListening
                                    ? LinearGradient(
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                        colors: [
                                          Color.lerp(accent, Colors.white, 0.25)!,
                                          accent,
                                        ],
                                      )
                                    : LinearGradient(
                                        colors: [
                                          Colors.white.withOpacity(0.14),
                                          accent.withOpacity(0.18),
                                        ],
                                      ),
                                boxShadow: [
                                  BoxShadow(
                                    color: accent.withOpacity(
                                      isListening ? 0.50 : 0.22,
                                    ),
                                    blurRadius: isListening ? 28 : 14,
                                    spreadRadius: isListening ? 3 : 0,
                                  ),
                                ],
                                border: Border.all(
                                  color: Colors.white.withOpacity(
                                    isListening ? 0.52 : 0.28,
                                  ),
                                  width: 1.4,
                                ),
                              ),
                        child: Icon(
                          isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                          color: isListening
                              ? const Color(0xFF0B0E17)
                              : theme.accentText,
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isListening
                          ? 'Mendukung judul Indonesia, Inggris, Jepang & Korea'
                          : 'Ketuk mikrofon untuk mulai mendengarkan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 11.5,
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
    ).whenComplete(() {
      modalClosed = true;
      sheetSetState = null;
      _nativeChannel.setMethodCallHandler(null);
      unawaited(_nativeChannel.invokeMethod('cancelCustomVoice'));
    });
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
                          hintText: 'Cari judul lagu atau nama artis...',
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
              const SizedBox(height: 14),

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
                              memCacheWidth: 156,
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
        'subtitle': 'Hits Tanah Air',
        'query': 'Lagu Pop Indonesia Hits',
        'color': 0xFF10B981,
        'icon': Icons.music_note_rounded,
      },
      {
        'title': 'Hits Global',
        'subtitle': 'Chart Dunia',
        'query': 'Top Global Hits',
        'color': 0xFF6366F1,
        'icon': Icons.public_rounded,
      },
      {
        'title': 'Indie & Senja',
        'subtitle': 'Akustik & Folk',
        'query': 'Hindia Perunggu Feast Indie',
        'color': 0xFFF59E0B,
        'icon': Icons.wb_twilight_rounded,
      },
      {
        'title': 'Galau Malam',
        'subtitle': 'Ballad Pilihan',
        'query': 'Lagu Galau Indonesia Terbaik',
        'color': 0xFF38BDF8,
        'icon': Icons.nightlight_round,
      },
      {
        'title': 'J-Pop & Anime',
        'subtitle': 'OST & Viral',
        'query': 'YOASOBI Kenshi Yonezu Anime',
        'color': 0xFFEC4899,
        'icon': Icons.auto_awesome_rounded,
      },
      {
        'title': 'K-Pop Hits',
        'subtitle': 'Idol Terbaik',
        'query': 'NewJeans aespa DAY6 Kpop',
        'color': 0xFFA855F7,
        'icon': Icons.bolt_rounded,
      },
      {
        'title': 'R&B & Hip-Hop',
        'subtitle': 'Groove Modern',
        'query': 'RnB Hip Hop Hits',
        'color': 0xFFF43F5E,
        'icon': Icons.headphones_rounded,
      },
      {
        'title': 'Lofi & Fokus',
        'subtitle': 'Santai & Kerja',
        'query': 'Lofi Chill Beats Study',
        'color': 0xFF14B8A6,
        'icon': Icons.spa_rounded,
      },
    ];

    const popularSearches = [
      {
        'title': 'Night Changes',
        'artist': 'One Direction',
        'query': 'One Direction Night Changes',
      },
      {
        'title': 'Untungnya, Hidup Harus Tetap Berjalan',
        'artist': 'Bernadya',
        'query': 'Bernadya Untungnya Hidup Harus Tetap Berjalan',
      },
      {
        'title': 'Evaluasi',
        'artist': 'Hindia',
        'query': 'Hindia Evaluasi',
      },
      {
        'title': 'Hati-Hati di Jalan',
        'artist': 'Tulus',
        'query': 'Tulus Hati-Hati di Jalan',
      },
      {
        'title': 'Dan...',
        'artist': 'Sheila On 7',
        'query': 'Sheila On 7 Dan',
      },
      {
        'title': 'Die For You',
        'artist': 'The Weeknd',
        'query': 'The Weeknd Die For You',
      },
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
                  letterSpacing: -0.2,
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
                rimIntensity: 0.32,
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
          const SizedBox(height: 20),
        ],

        // Redesigned Kategori Musik Section
        Row(
          children: [
            Icon(
              Icons.grid_view_rounded,
              color: theme.accentText,
              size: 17,
            ),
            const SizedBox(width: 7),
            Text(
              'Kategori Musik',
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15.5,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: categories.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            mainAxisExtent: 72,
          ),
          itemBuilder: (context, idx) {
            final item = categories[idx];
            final cardColor = Color(item['color'] as int);
            final iconData = item['icon'] as IconData;
            return LiquidGlassBox(
              borderRadius: 18,
              padding: EdgeInsets.zero,
              tintColor: cardColor,
              tintOpacity: isBrutal ? 0.16 : 0.24,
              rimIntensity: 0.44,
              onTap: () {
                final q = item['query'] as String;
                _searchController.text = item['title'] as String;
                _performSearch(q, allowArtistCard: false);
              },
              child: Stack(
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned(
                    right: -8,
                    bottom: -10,
                    child: Icon(
                      iconData,
                      size: 54,
                      color: cardColor.withOpacity(isBrutal ? 0.15 : 0.18),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            gradient: isBrutal
                                ? null
                                : LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [
                                      Color.lerp(cardColor, Colors.white, 0.22)!
                                          .withOpacity(0.85),
                                      cardColor.withOpacity(0.55),
                                    ],
                                  ),
                            color: isBrutal ? cardColor : null,
                            borderRadius: BorderRadius.circular(
                              isBrutal ? 9 : 11,
                            ),
                            border: Border.all(
                              color: isBrutal
                                  ? theme.brutalBorderColor
                                  : Colors.white.withOpacity(0.32),
                              width: isBrutal ? 1.8 : 1.0,
                            ),
                          ),
                          child: Icon(iconData, color: Colors.white, size: 19),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item['title'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 13.0,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item['subtitle'] as String,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isBrutal
                                      ? theme.textSecondary
                                      : Colors.white.withOpacity(0.70),
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11.0,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 22),

        // Redesigned Populer Dicari Section — Structured Ranked List
        Row(
          children: [
            Icon(
              Icons.local_fire_department_rounded,
              color: theme.accentText,
              size: 18,
            ),
            const SizedBox(width: 6),
            Text(
              'Populer Dicari',
              style: TextStyle(
                color: theme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 15.5,
                letterSpacing: -0.2,
              ),
            ),
          ],
        ),
        const SizedBox(height: 11),
        LiquidGlassBox(
          borderRadius: 20,
          tintColor: accent,
          tintOpacity: isBrutal ? 0.0 : 0.06,
          rimIntensity: 0.38,
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: List.generate(popularSearches.length, (i) {
              final entry = popularSearches[i];
              final rank = (i + 1).toString().padLeft(2, '0');
              final isTop3 = i < 3;
              final isLast = i == popularSearches.length - 1;

              return Column(
                children: [
                  IosSpringButton(
                    onTap: () {
                      final q = entry['query']!;
                      _searchController.text = q;
                      _performSearch(q);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 9.5,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: isTop3
                                  ? (isBrutal
                                        ? accent
                                        : accent.withOpacity(0.20))
                                  : (isBrutal
                                        ? theme.subtleFill
                                        : Colors.white.withOpacity(0.06)),
                              borderRadius: BorderRadius.circular(
                                isBrutal ? 7 : 9,
                              ),
                              border: isBrutal
                                  ? Border.all(
                                      color: theme.brutalBorderColor,
                                      width: 1.5,
                                    )
                                  : Border.all(
                                      color: isTop3
                                          ? accent.withOpacity(0.45)
                                          : Colors.white.withOpacity(0.10),
                                      width: 0.9,
                                    ),
                            ),
                            child: Text(
                              rank,
                              style: TextStyle(
                                color: isTop3
                                    ? (isBrutal
                                          ? const Color(0xFF111111)
                                          : accent)
                                    : theme.textMuted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  entry['title']!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.15,
                                  ),
                                ),
                                const SizedBox(height: 1.5),
                                Text(
                                  entry['artist']!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.textMuted,
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.north_west_rounded,
                            color: isTop3 ? theme.accentText : theme.textMuted,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (!isLast)
                    Divider(
                      height: 1,
                      thickness: isBrutal ? 1.2 : 0.7,
                      indent: 54,
                      endIndent: 14,
                      color: theme.dividerColor,
                    ),
                ],
              );
            }),
          ),
        ),
      ],
    );
  }
}
