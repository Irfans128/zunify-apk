import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/ytmusic_service.dart';
import '../widgets/liquid_background_widget.dart';
import '../widgets/song_tile_widget.dart';
import '../widgets/vinyl_disc_widget.dart';
import '../widgets/weekly_rapot_modal.dart';

class HomeScreen extends StatefulWidget {
  final YTMusicService ytMusicService;

  const HomeScreen({super.key, required this.ytMusicService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<Map<String, String>> _moods = [
    {'id': 'Semua', 'label': 'Semua'},
    {'id': 'Pop Indo', 'label': 'Pop Indo'},
    {'id': 'Pop Barat', 'label': 'Pop Barat'},
    {'id': 'Galau', 'label': 'Galau'},
    {'id': 'Chill', 'label': 'Indie & Chill'},
    {'id': 'K-Pop', 'label': 'K-Pop'},
    {'id': 'Anime', 'label': 'Anime & J-Pop'},
    {'id': 'Workout', 'label': 'Workout'},
    {'id': 'Fokus', 'label': 'Fokus'},
  ];

  String _selectedMood = 'Semua';
  List<ZunifySong> _moodSongs = [];
  List<ZunifySong> _trendingIndo = [];
  List<ZunifySong> _trendingGlobal = [];
  bool _isLoadingCharts = true;

  @override
  void initState() {
    super.initState();
    _loadInitialHomeData();
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) return 'Selamat Pagi';
    if (hour >= 11 && hour < 15) return 'Selamat Siang';
    if (hour >= 15 && hour < 18) return 'Selamat Sore';
    return 'Selamat Malam';
  }

  Future<void> _loadInitialHomeData() async {
    setState(() => _isLoadingCharts = true);
    final results = await Future.wait([
      widget.ytMusicService.getSongsByMood(_selectedMood),
      widget.ytMusicService.getTrendingIndonesia(),
      widget.ytMusicService.getTrendingGlobal(),
    ]);
    if (!mounted) return;
    setState(() {
      _moodSongs = results[0];
      _trendingIndo = results[1];
      _trendingGlobal = results[2];
      _isLoadingCharts = false;
    });
  }

  Future<void> _selectMood(String mood) async {
    if (_selectedMood == mood && _moodSongs.isNotEmpty) return;
    setState(() {
      _selectedMood = mood;
      _isLoadingCharts = true;
    });
    final tracks = await widget.ytMusicService.getSongsByMood(mood);
    if (!mounted) return;
    setState(() {
      _moodSongs = tracks;
      _isLoadingCharts = false;
    });
  }

  Future<void> _openWeeklyRapotModal(BuildContext context) async {
    final player = context.read<PlayerProvider>();
    final rapot = await player.getWeeklyRapot();
    if (!context.mounted) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WeeklyRapotModal(rapot: rapot),
    );
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final player = context.watch<PlayerProvider>();
    final theme = context.watch<ThemeProvider>();
    final accent = theme.accentColor;
    final isBrutal = theme.isNeoBrutalism;

    final isAllTab = _selectedMood == 'Semua';

    // Build non-overlapping Quick Picks for 'Semua' tab (Recent + Favorites + Extra Charts, distinct from _moodSongs shelf)
    final shelfIds = _moodSongs.take(8).map((s) => s.videoId).toSet();
    final quickPicks = <ZunifySong>[];
    if (isAllTab) {
      final primaryPool = <ZunifySong>[
        ...library.recentlyPlayed,
        ...library.favorites,
        ..._trendingIndo.skip(5),
        ..._trendingGlobal.skip(5),
      ];
      final seenIds = <String>{};
      for (final s in primaryPool) {
        if (library.recentlyPlayed.any((r) => r.videoId == s.videoId) ||
            library.favorites.any((f) => f.videoId == s.videoId) ||
            !shelfIds.contains(s.videoId)) {
          if (seenIds.add(s.videoId)) {
            quickPicks.add(s);
            if (quickPicks.length >= 6) break;
          }
        }
      }
    }

    final hasRecentOrPlaying =
        player.currentSong != null || library.recentlyPlayed.isNotEmpty;
    final ZunifySong? heroSong = isAllTab
        ? (player.currentSong ??
            (library.recentlyPlayed.isNotEmpty
                ? library.recentlyPlayed.first
                : (_moodSongs.isNotEmpty
                    ? _moodSongs.first
                    : (_trendingIndo.isNotEmpty ? _trendingIndo.first : null))))
        : (_moodSongs.isNotEmpty ? _moodSongs.first : null);
    final String heroBadgeLabel = isAllTab
        ? (hasRecentOrPlaying ? 'LANJUTKAN DENGAR' : 'SOROTAN UTAMA')
        : 'MIX $_selectedMood'.toUpperCase();
    final List<ZunifySong> heroQueue = isAllTab && hasRecentOrPlaying
        ? (library.recentlyPlayed.isNotEmpty
            ? library.recentlyPlayed
            : _moodSongs)
        : (_moodSongs.isNotEmpty ? _moodSongs : _trendingIndo);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: theme.accentText,
          backgroundColor: theme.cardBgColor,
          onRefresh: _loadInitialHomeData,
          child: ListView(
            physics: const BouncingScrollPhysics(
              parent: AlwaysScrollableScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 176),
            children: [
              // 1. Clean Top Header
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  LiquidGlassBox(
                    width: 42,
                    height: 42,
                    borderRadius: 21,
                    tintColor: accent,
                    tintOpacity: isBrutal ? 0.65 : 0.22,
                    rimIntensity: 0.48,
                    alignment: Alignment.center,
                    child: Text(
                      library.profile.username.isNotEmpty
                          ? library.profile.username[0].toUpperCase()
                          : 'Z',
                      style: GoogleFonts.plusJakartaSans(
                        color:
                            isBrutal ? const Color(0xFF111111) : Colors.white,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getTimeGreeting(),
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.1,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          library.profile.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: theme.textPrimary,
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                            height: 1.15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IosGlassPillButton(
                    icon: Icons.auto_awesome_rounded,
                    label: 'Wrapped',
                    height: 36,
                    activeColor: accent,
                    isActive: true,
                    onTap: () => _openWeeklyRapotModal(context),
                  ),
                  const SizedBox(width: 8),
                  IosGlassIconButton(
                    icon: player.offlineModeEnabled
                        ? Icons.cloud_off_rounded
                        : Icons.wifi_rounded,
                    size: 36,
                    iconSize: 17,
                    activeColor: accent,
                    isActive: player.offlineModeEnabled,
                    tooltip: 'Mode Offline',
                    onTap: () =>
                        player.setOfflineMode(!player.offlineModeEnabled),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (player.offlineModeEnabled) ...[
                _buildOfflineList(library, player, theme, accent),
              ] else ...[
                // 2. Mood Filter Capsules
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    itemCount: _moods.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final moodId = _moods[i]['id']!;
                      final moodLabel = _moods[i]['label']!;
                      final selected = moodId == _selectedMood;
                      return IosGlassPillButton(
                        label: moodLabel,
                        height: 35,
                        padding: const EdgeInsets.symmetric(horizontal: 15),
                        activeColor: accent,
                        isActive: selected,
                        fontSize: 12.2,
                        onTap: () => _selectMood(moodId),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Hero Spotlight Banner
                if (heroSong != null) ...[
                  _buildHeroFeaturedBanner(
                    heroSong,
                    heroQueue,
                    heroBadgeLabel,
                    player,
                    theme,
                    accent,
                  ),
                  const SizedBox(height: 20),
                ],

                // 4A. When a specific Mood is selected: Show dedicated Mood Tracklist cleanly without duplicate shelves
                if (!isAllTab) ...[
                  _sectionHeader(
                    'Daftar Lagu $_selectedMood',
                    theme: theme,
                    onPlayAll: _moodSongs.isEmpty
                        ? null
                        : () => player.playSong(
                              _moodSongs.first,
                              customQueue: _moodSongs,
                              contextName: 'Mix $_selectedMood',
                            ),
                    accent: accent,
                  ),
                  const SizedBox(height: 10),
                  if (_isLoadingCharts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 44),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: theme.accentText,
                        ),
                      ),
                    )
                  else
                    ..._moodSongs.asMap().entries.map(
                          (entry) => ZunifySongTile(
                            song: entry.value,
                            queueContext: _moodSongs,
                            contextName: 'Mix $_selectedMood',
                            rank: entry.key + 1,
                          ),
                        ),
                ] else ...[
                  // 4B. 'Semua' Tab: Logical Non-Overlapping Sections
                  if (quickPicks.isNotEmpty) ...[
                    _sectionHeader(
                      library.recentlyPlayed.isNotEmpty
                          ? 'Terakhir Diputar'
                          : 'Dengarkan Cepat',
                      theme: theme,
                      onPlayAll: () => player.playSong(
                        quickPicks.first,
                        customQueue: quickPicks,
                        contextName: library.recentlyPlayed.isNotEmpty
                            ? 'Terakhir Diputar'
                            : 'Dengarkan Cepat',
                      ),
                      accent: accent,
                    ),
                    const SizedBox(height: 10),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: quickPicks.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 9,
                        crossAxisSpacing: 9,
                        mainAxisExtent: 60,
                      ),
                      itemBuilder: (context, i) {
                        final song = quickPicks[i];
                        return _buildQuickPickTile(
                          song,
                          player,
                          theme,
                          accent,
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                  ],

                  // 5. Horizontal Shelf: Rekomendasi Untukmu
                  _sectionHeader(
                    'Rekomendasi Untukmu',
                    theme: theme,
                    onPlayAll: _moodSongs.isEmpty
                        ? null
                        : () => player.playSong(
                              _moodSongs.first,
                              customQueue: _moodSongs,
                              contextName: 'Rekomendasi Untukmu',
                            ),
                    accent: accent,
                  ),
                  const SizedBox(height: 12),
                  if (_isLoadingCharts)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 36),
                      child: Center(
                        child: CircularProgressIndicator(
                          color: theme.accentText,
                        ),
                      ),
                    )
                  else
                    SizedBox(
                      height: 206,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _moodSongs.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (context, idx) {
                          final song = _moodSongs[idx];
                          return _squareSongCard(
                            song,
                            player,
                            theme,
                            accent,
                          );
                        },
                      ),
                    ),
                  const SizedBox(height: 24),

                  // 6. Populer di Indonesia
                  _sectionHeader(
                    'Populer di Indonesia',
                    theme: theme,
                    onPlayAll: _trendingIndo.isEmpty
                        ? null
                        : () => player.playSong(
                              _trendingIndo.first,
                              customQueue: _trendingIndo,
                              contextName: 'Populer di Indonesia',
                            ),
                    accent: accent,
                  ),
                  const SizedBox(height: 8),
                  ..._trendingIndo.take(5).toList().asMap().entries.map(
                        (entry) => ZunifySongTile(
                          song: entry.value,
                          queueContext: const [],
                          contextName: 'Radio ${entry.value.title}',
                          rank: entry.key + 1,
                        ),
                      ),
                  const SizedBox(height: 22),

                  // 7. Top Global
                  _sectionHeader(
                    'Top Global',
                    theme: theme,
                    onPlayAll: _trendingGlobal.isEmpty
                        ? null
                        : () => player.playSong(
                              _trendingGlobal.first,
                              customQueue: _trendingGlobal,
                              contextName: 'Top Global',
                            ),
                    accent: accent,
                  ),
                  const SizedBox(height: 8),
                  ..._trendingGlobal.take(5).toList().asMap().entries.map(
                        (entry) => ZunifySongTile(
                          song: entry.value,
                          queueContext: const [],
                          contextName: 'Radio ${entry.value.title}',
                          rank: entry.key + 1,
                        ),
                      ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroFeaturedBanner(
    ZunifySong song,
    List<ZunifySong> mixList,
    String badgeLabel,
    PlayerProvider player,
    ThemeProvider theme,
    Color accent,
  ) {
    final isBrutal = theme.isNeoBrutalism;
    final queueToPlay = mixList.isNotEmpty ? mixList : [song];
    return LiquidGlassBox(
      borderRadius: 26,
      padding: const EdgeInsets.all(15),
      tintColor: accent,
      tintOpacity: isBrutal ? 0.16 : 0.14,
      rimIntensity: 0.44,
      enableShadow: true,
      onTap: () => player.playSong(
        song,
        customQueue: queueToPlay,
        contextName: badgeLabel,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            decoration: isBrutal
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: theme.brutalBorderColor,
                      width: 2.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: theme.brutalShadowColor,
                        blurRadius: 0,
                        offset: const Offset(3.0, 3.0),
                      ),
                    ],
                  )
                : BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.32),
                        blurRadius: 14,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isBrutal ? 9.8 : 18),
              child: CachedNetworkImage(
                imageUrl: song.highResArtUrl,
                width: 92,
                height: 92,
                memCacheWidth: 260,
                fadeInDuration: const Duration(milliseconds: 140),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 92,
                  height: 92,
                  color: theme.subtleFill,
                  child: Icon(
                    Icons.music_note_rounded,
                    color: theme.accentText,
                    size: 30,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: isBrutal ? accent : accent.withOpacity(0.20),
                    borderRadius: BorderRadius.circular(isBrutal ? 6 : 8),
                    border: isBrutal
                        ? Border.all(color: theme.brutalBorderColor, width: 1.5)
                        : null,
                  ),
                  child: Text(
                    badgeLabel,
                    style: TextStyle(
                      color: isBrutal ? const Color(0xFF111111) : accent,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.7,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  song.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: theme.textPrimary,
                    fontSize: 16.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  song.artist,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: theme.textSecondary,
                    fontSize: 12.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 11),
                Row(
                  children: [
                    IosGlassPillButton(
                      icon: Icons.play_arrow_rounded,
                      label: 'Putar',
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      activeColor: accent,
                      isActive: true,
                      fontSize: 12,
                      onTap: () => player.playSong(
                        song,
                        customQueue: queueToPlay,
                        contextName: badgeLabel,
                      ),
                    ),
                    const SizedBox(width: 8),
                    IosGlassPillButton(
                      icon: Icons.shuffle_rounded,
                      label: 'Acak',
                      height: 32,
                      padding: const EdgeInsets.symmetric(horizontal: 13),
                      fontSize: 12,
                      onTap: () {
                        final shuffled = List<ZunifySong>.from(queueToPlay)
                          ..shuffle();
                        player.playSong(
                          shuffled.first,
                          customQueue: shuffled,
                          contextName: badgeLabel,
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickPickTile(
    ZunifySong song,
    PlayerProvider player,
    ThemeProvider theme,
    Color accent,
  ) {
    final isCurrent = player.currentSong?.videoId == song.videoId;
    final isBrutal = theme.isNeoBrutalism;
    return LiquidGlassBox(
      borderRadius: 16,
      padding: const EdgeInsets.all(5),
      tintColor: isCurrent ? accent : Colors.white,
      tintOpacity: isCurrent ? 0.22 : 0.08,
      rimIntensity: isCurrent ? 0.46 : 0.30,
      onTap: () => player.playSong(
        song,
        customQueue: const [],
        contextName: 'Radio ${song.title}',
      ),
      child: Row(
        children: [
          Container(
            decoration: isBrutal
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: theme.brutalBorderColor,
                      width: 1.5,
                    ),
                  )
                : null,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isBrutal ? 6.5 : 11),
              child: CachedNetworkImage(
                imageUrl: song.thumbnailUrl,
                width: 46,
                height: 46,
                memCacheWidth: 150,
                fadeInDuration: const Duration(milliseconds: 120),
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 46,
                  height: 46,
                  color: theme.subtleFill,
                  child: Icon(
                    Icons.music_note_rounded,
                    color: theme.accentText,
                    size: 18,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? theme.accentText : theme.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 12.2,
                      letterSpacing: -0.15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: theme.textMuted,
                      fontWeight: FontWeight.w600,
                      fontSize: 10.6,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (isCurrent)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: MiniAudioSpectrumBars(
                isPlaying: player.isPlaying,
                color: theme.accentText,
                height: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOfflineList(
    LibraryProvider library,
    PlayerProvider player,
    ThemeProvider theme,
    Color accent,
  ) {
    final songs = library.downloadedSongs;
    if (songs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: Text(
            'Belum ada lagu tersimpan untuk mode offline.',
            style: TextStyle(color: theme.textMuted),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Tersimpan Offline (${songs.length})',
          theme: theme,
          onPlayAll: () => player.playSong(
            songs.first,
            customQueue: songs,
            contextName: 'Tersimpan Offline',
          ),
          accent: accent,
        ),
        const SizedBox(height: 8),
        ...songs.map(
          (s) => ZunifySongTile(song: s, queueContext: songs),
        ),
      ],
    );
  }

  Widget _sectionHeader(
    String title, {
    required ThemeProvider theme,
    VoidCallback? onPlayAll,
    required Color accent,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: theme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
        ),
        if (onPlayAll != null)
          IosGlassPillButton(
            icon: Icons.play_arrow_rounded,
            label: 'Putar Semua',
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 11),
            activeColor: accent,
            isActive: true,
            fontSize: 11.2,
            onTap: onPlayAll,
          ),
      ],
    );
  }

  Widget _squareSongCard(
    ZunifySong song,
    PlayerProvider player,
    ThemeProvider theme,
    Color accent,
  ) {
    final isCurrent = player.currentSong?.videoId == song.videoId;
    final isBrutal = theme.isNeoBrutalism;
    return IosSpringButton(
      scaleDown: 0.92,
      borderRadius: isBrutal ? 13 : 18,
      onTap: () => player.playSong(
        song,
        customQueue: const [],
        contextName: 'Radio ${song.title}',
      ),
      onLongPress: () => showSongActionSheet(context, song: song),
      child: SizedBox(
        width: 144,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                Container(
                  decoration: isBrutal
                      ? BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(
                            color: isCurrent ? accent : theme.brutalBorderColor,
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
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: isCurrent
                                ? accent.withOpacity(0.65)
                                : Colors.white.withOpacity(0.14),
                            width: 1.0,
                          ),
                        ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isBrutal ? 10.8 : 17),
                    child: CachedNetworkImage(
                      imageUrl: song.highResArtUrl,
                      width: 144,
                      height: 144,
                      memCacheWidth: 360,
                      fadeInDuration: const Duration(milliseconds: 140),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 144,
                        height: 144,
                        color: theme.subtleFill,
                        child: Icon(
                          Icons.music_note_rounded,
                          color: theme.accentText,
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: isBrutal
                        ? BoxDecoration(
                            color: isCurrent ? accent : theme.cardBgColor,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.brutalBorderColor,
                              width: 1.8,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: theme.brutalShadowColor,
                                blurRadius: 0,
                                offset: const Offset(1.8, 1.8),
                              ),
                            ],
                          )
                        : BoxDecoration(
                            color: isCurrent
                                ? accent
                                : Colors.black.withOpacity(0.54),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white.withOpacity(0.28),
                              width: 0.8,
                            ),
                          ),
                    alignment: Alignment.center,
                    child: isCurrent
                        ? MiniAudioSpectrumBars(
                            isPlaying: player.isPlaying,
                            color: const Color(0xFF111111),
                            height: 11,
                          )
                        : Icon(
                            Icons.play_arrow_rounded,
                            color: isBrutal ? theme.textPrimary : Colors.white,
                            size: 18,
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 9),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isCurrent ? theme.accentText : theme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13.2,
                letterSpacing: -0.15,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
