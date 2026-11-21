import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/ytmusic_service.dart';
import '../widgets/liquid_background_widget.dart';
import '../widgets/song_tile_widget.dart';
import '../widgets/weekly_rapot_modal.dart';
import 'theme_studio_screen.dart';

/// Zunify v3.0.0 Editorial Music Magazine Home Screen.
/// - Clean editorial header with 1-tap Theme Studio shortcut & Wrapped access
/// - Swipeable full-bleed Hero Recommendation Carousel
/// - Lightweight typographic mood selector (zero nested box clutter)
/// - Spacious borderless cover gallery & crisp open tracklist
class HomeScreen extends StatefulWidget {
  final YTMusicService ytMusicService;

  const HomeScreen({super.key, required this.ytMusicService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<Map<String, String>> _moods = [
    {'id': 'Semua', 'label': 'Untukmu'},
    {'id': 'Pop Indo', 'label': 'Pop Indo'},
    {'id': 'Pop Barat', 'label': 'Barat'},
    {'id': 'Galau', 'label': 'Galau'},
    {'id': 'Chill', 'label': 'Chill'},
    {'id': 'K-Pop', 'label': 'K-Pop'},
    {'id': 'Anime', 'label': 'Anime'},
    {'id': 'Workout', 'label': 'Workout'},
    {'id': 'Fokus', 'label': 'Fokus'},
  ];

  final PageController _heroPageCtrl = PageController(viewportFraction: 0.92);
  int _heroPage = 0;

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

  @override
  void dispose() {
    _heroPageCtrl.dispose();
    super.dispose();
  }

  String _getTimeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 4 && hour < 11) return 'PAGI';
    if (hour >= 11 && hour < 15) return 'SIANG';
    if (hour >= 15 && hour < 18) return 'SORE';
    return 'MALAM';
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
    HapticFeedback.selectionClick();
    setState(() {
      _selectedMood = mood;
      _isLoadingCharts = true;
      _heroPage = 0;
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

  List<_HeroEditorialItem> _buildHeroItems({
    required PlayerProvider player,
    required LibraryProvider library,
    required bool isAllTab,
  }) {
    final items = <_HeroEditorialItem>[];
    final seen = <String>{};

    void addItem(ZunifySong s, String kicker, List<ZunifySong> queue) {
      if (seen.add(s.videoId)) {
        items.add(_HeroEditorialItem(song: s, kicker: kicker, queue: queue));
      }
    }

    if (isAllTab) {
      if (player.currentSong != null) {
        addItem(
          player.currentSong!,
          'LANJUTKAN DENGAR',
          player.queue.isNotEmpty ? player.queue : [player.currentSong!],
        );
      } else if (library.recentlyPlayed.isNotEmpty) {
        addItem(
          library.recentlyPlayed.first,
          'TERAKHIR DIPUTAR',
          library.recentlyPlayed,
        );
      }
      if (_moodSongs.isNotEmpty) {
        addItem(_moodSongs.first, 'PILIHAN EDITOR', _moodSongs);
      }
      if (_trendingIndo.isNotEmpty) {
        addItem(_trendingIndo.first, 'TRENDING INDONESIA', _trendingIndo);
      }
      if (_trendingGlobal.isNotEmpty) {
        addItem(_trendingGlobal.first, 'TOP GLOBAL', _trendingGlobal);
      }
    } else {
      for (final s in _moodSongs.take(4)) {
        addItem(s, 'MIX ${_selectedMood.toUpperCase()}', _moodSongs);
      }
    }
    return items.take(4).toList();
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final player = context.watch<PlayerProvider>();
    final theme = context.watch<ThemeProvider>();
    final accent = theme.accentColor;
    final isBrutal = theme.isNeoBrutalism;
    final isIpod = theme.isClassicIpod;
    final isAllTab = _selectedMood == 'Semua';

    final heroItems = _buildHeroItems(
      player: player,
      library: library,
      isAllTab: isAllTab,
    );

    final curatedList = isAllTab
        ? [..._trendingIndo.take(4), ..._trendingGlobal.take(3)]
        : _moodSongs;

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
            padding: const EdgeInsets.only(top: 10, bottom: 168),
            children: [
              // 1. Editorial Magazine Header + 1-Tap Theme Studio Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'SELAMAT ${_getTimeGreeting()}',
                            style: TextStyle(
                              color: theme.accentText,
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1.4,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            library.profile.username,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: theme.textPrimary,
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.9,
                              height: 1.08,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // 1-Tap Theme Studio Shortcut (Top Right of Home!)
                    IosGlassIconButton(
                      icon: Icons.palette_outlined,
                      size: 38,
                      iconSize: 19,
                      activeColor: accent,
                      isActive: isIpod || isBrutal,
                      tooltip: 'Studio Tema',
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ThemeStudioScreen(),
                          ),
                        );
                      },
                    ),
                    const SizedBox(width: 8),
                    IosGlassIconButton(
                      icon: Icons.auto_awesome_rounded,
                      size: 38,
                      iconSize: 19,
                      activeColor: accent,
                      isActive: false,
                      tooltip: 'Wrapped Mingguan',
                      onTap: () => _openWeeklyRapotModal(context),
                    ),
                    const SizedBox(width: 8),
                    IosGlassIconButton(
                      icon: player.offlineModeEnabled
                          ? Icons.cloud_off_rounded
                          : Icons.wifi_rounded,
                      size: 38,
                      iconSize: 18,
                      activeColor: accent,
                      isActive: player.offlineModeEnabled,
                      tooltip: 'Mode Offline',
                      onTap: () =>
                          player.setOfflineMode(!player.offlineModeEnabled),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              if (player.offlineModeEnabled)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: _buildOfflineList(library, player, theme, accent),
                )
              else ...[
                // 2. Ultra-Clean Typographic Mood Tabs (Zero heavy boxes!)
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: _moods.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 18),
                    itemBuilder: (_, i) {
                      final moodId = _moods[i]['id']!;
                      final label = _moods[i]['label']!;
                      final selected = moodId == _selectedMood;
                      return GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _selectMood(moodId),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              label,
                              style: GoogleFonts.plusJakartaSans(
                                color: selected
                                    ? theme.textPrimary
                                    : theme.textMuted,
                                fontSize: selected ? 15 : 14,
                                fontWeight: selected
                                    ? FontWeight.w900
                                    : FontWeight.w600,
                                letterSpacing: -0.2,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 220),
                              height: 2.5,
                              width: selected ? 20 : 0,
                              decoration: BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 16),

                // 3. Swipeable Full-Bleed Editorial Hero Carousel
                if (heroItems.isNotEmpty) ...[
                  SizedBox(
                    height: 214,
                    child: PageView.builder(
                      controller: _heroPageCtrl,
                      itemCount: heroItems.length,
                      onPageChanged: (i) => setState(() => _heroPage = i),
                      itemBuilder: (_, i) {
                        final item = heroItems[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: _buildEditorialHeroCard(
                            item: item,
                            player: player,
                            theme: theme,
                            accent: accent,
                          ),
                        );
                      },
                    ),
                  ),
                  if (heroItems.length > 1) ...[
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        heroItems.length,
                        (i) => AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _heroPage == i ? 18 : 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: _heroPage == i
                                ? accent
                                : theme.textMuted.withOpacity(0.35),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 26),
                ],

                // 4. Clean Spacious Horizontal Cover Gallery (For 'Semua' tab)
                if (isAllTab) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _editorialSectionHeader(
                      title: 'Pilihan Hari Ini',
                      subtitle: 'Kurasi musik sesuai selera',
                      theme: theme,
                      accent: accent,
                      onPlayAll: _moodSongs.isEmpty
                          ? null
                          : () => player.playSong(
                                _moodSongs.first,
                                customQueue: _moodSongs,
                                contextName: 'Pilihan Hari Ini',
                              ),
                    ),
                  ),
                  const SizedBox(height: 14),
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
                      height: 196,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: _moodSongs.take(10).length,
                        separatorBuilder: (_, __) => const SizedBox(width: 14),
                        itemBuilder: (_, idx) => _buildMinimalAlbumCard(
                          _moodSongs[idx],
                          player,
                          theme,
                          accent,
                        ),
                      ),
                    ),
                  const SizedBox(height: 28),
                ],

                // 5. Open Borderless Tracklist
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _editorialSectionHeader(
                        title: isAllTab
                            ? 'Sedang Ramai'
                            : 'Daftar $_selectedMood',
                        subtitle: isAllTab
                            ? 'Lagu paling banyak diputar sekarang'
                            : 'Langsung putar tanpa jeda',
                        theme: theme,
                        accent: accent,
                        onPlayAll: curatedList.isEmpty
                            ? null
                            : () => player.playSong(
                                  curatedList.first,
                                  customQueue: curatedList,
                                  contextName: isAllTab
                                      ? 'Sedang Ramai'
                                      : 'Mix $_selectedMood',
                                ),
                      ),
                      const SizedBox(height: 10),
                      if (_isLoadingCharts && curatedList.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 40),
                          child: Center(
                            child: CircularProgressIndicator(
                              color: theme.accentText,
                            ),
                          ),
                        )
                      else
                        ...curatedList.asMap().entries.map(
                              (entry) => ZunifySongTile(
                                song: entry.value,
                                queueContext: isAllTab
                                    ? const []
                                    : curatedList,
                                contextName: isAllTab
                                    ? 'Radio ${entry.value.title}'
                                    : 'Mix $_selectedMood',
                                rank: entry.key + 1,
                              ),
                            ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditorialHeroCard({
    required _HeroEditorialItem item,
    required PlayerProvider player,
    required ThemeProvider theme,
    required Color accent,
  }) {
    final isBrutal = theme.isNeoBrutalism;
    final isIpod = theme.isClassicIpod;
    final radius = isBrutal ? 18.0 : (isIpod ? 18.0 : 26.0);
    final isPlayingThis =
        player.currentSong?.videoId == item.song.videoId && player.isPlaying;

    return IosSpringButton(
      scaleDown: 0.97,
      borderRadius: radius,
      onTap: () => player.playSong(
        item.song,
        customQueue: item.queue,
        contextName: item.kicker,
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          border: isBrutal
              ? Border.all(color: theme.brutalBorderColor, width: 2.0)
              : Border.all(
                  color: Colors.white.withOpacity(0.18),
                  width: 1.0,
                ),
          boxShadow: isBrutal
              ? [
                  BoxShadow(
                    color: theme.brutalShadowColor,
                    offset: const Offset(3.5, 3.5),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.28),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Full-Bleed Background Artwork
            CachedNetworkImage(
              imageUrl: item.song.highResArtUrl,
              fit: BoxFit.cover,
              memCacheWidth: 520,
              errorWidget: (_, __, ___) => ColoredBox(color: theme.cardBgColor),
            ),
            // Smooth Editorial Dark Scrim for High-Contrast Typography
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.15),
                    Colors.black.withOpacity(0.42),
                    Colors.black.withOpacity(0.86),
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Editorial Tag
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isBrutal ? accent : Colors.black.withOpacity(0.45),
                      borderRadius: BorderRadius.circular(8),
                      border: isBrutal
                          ? Border.all(color: const Color(0xFF111111), width: 1.4)
                          : Border.all(color: Colors.white24),
                    ),
                    child: Text(
                      item.kicker,
                      style: TextStyle(
                        color: isBrutal ? const Color(0xFF111111) : Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.9,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.song.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 21,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.5,
                                height: 1.12,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.80),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: accent,
                          shape: BoxShape.circle,
                          border: isBrutal
                              ? Border.all(
                                  color: const Color(0xFF111111),
                                  width: 1.8,
                                )
                              : null,
                        ),
                        child: Icon(
                          isPlayingThis
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: const Color(0xFF111111),
                          size: 28,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMinimalAlbumCard(
    ZunifySong song,
    PlayerProvider player,
    ThemeProvider theme,
    Color accent,
  ) {
    final isBrutal = theme.isNeoBrutalism;
    final isIpod = theme.isClassicIpod;
    final isPlaying = player.currentSong?.videoId == song.videoId;

    return IosSpringButton(
      scaleDown: 0.96,
      borderRadius: 16,
      onTap: () => player.playSong(
        song,
        customQueue: const [],
        contextName: 'Radio ${song.title}',
      ),
      child: SizedBox(
        width: 138,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 138,
              height: 138,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(isIpod ? 10 : 16),
                border: isBrutal
                    ? Border.all(color: theme.brutalBorderColor, width: 1.6)
                    : null,
                boxShadow: [
                  if (isBrutal)
                    BoxShadow(
                      color: theme.brutalShadowColor.withOpacity(0.85),
                      offset: const Offset(2.5, 2.5),
                    )
                  else
                    BoxShadow(
                      color: Colors.black.withOpacity(0.18),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: CachedNetworkImage(
                imageUrl: song.highResArtUrl,
                fit: BoxFit.cover,
                memCacheWidth: 280,
                errorWidget: (_, __, ___) => ColoredBox(
                  color: theme.cardBgColor,
                  child: Icon(Icons.music_note_rounded, color: accent),
                ),
              ),
            ),
            const SizedBox(height: 9),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: isPlaying ? theme.accentText : theme.textPrimary,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 1.5),
            Text(
              song.artist,
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
    );
  }

  Widget _editorialSectionHeader({
    required String title,
    required String subtitle,
    required ThemeProvider theme,
    required Color accent,
    VoidCallback? onPlayAll,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  color: theme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: theme.textMuted,
                  fontSize: 11.8,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (onPlayAll != null)
          GestureDetector(
            onTap: onPlayAll,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Text(
                'Putar Semua',
                style: TextStyle(
                  color: theme.accentText,
                  fontSize: 12.2,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildOfflineList(
    LibraryProvider library,
    PlayerProvider player,
    ThemeProvider theme,
    Color accent,
  ) {
    final downloaded = library.downloadedSongs;
    if (downloaded.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 64),
        child: Column(
          children: [
            Icon(Icons.cloud_off_rounded, color: theme.textMuted, size: 46),
            const SizedBox(height: 12),
            Text(
              'Mode Offline Aktif',
              style: GoogleFonts.plusJakartaSans(
                color: theme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Belum ada lagu tersimpan. Matikan Mode Offline untuk mengunduh lagu favoritmu.',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.textSecondary, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _editorialSectionHeader(
          title: 'Vault Offline (${downloaded.length})',
          subtitle: 'Siap diputar tanpa koneksi internet',
          theme: theme,
          accent: accent,
          onPlayAll: () => player.playSong(
            downloaded.first,
            customQueue: downloaded,
            contextName: 'Vault Offline',
          ),
        ),
        const SizedBox(height: 12),
        ...downloaded.map(
          (song) => ZunifySongTile(
            song: song,
            queueContext: downloaded,
            contextName: 'Vault Offline',
          ),
        ),
      ],
    );
  }
}

class _HeroEditorialItem {
  final ZunifySong song;
  final String kicker;
  final List<ZunifySong> queue;

  const _HeroEditorialItem({
    required this.song,
    required this.kicker,
    required this.queue,
  });
}
