import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/ytmusic_service.dart';
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
    {'id': 'Pop Indo', 'label': '🔥 Pop Indo'},
    {'id': 'Chill', 'label': '🌙 Chill'},
    {'id': 'Galau', 'label': '🌧️ Galau'},
    {'id': 'Workout', 'label': '⚡ Workout'},
    {'id': 'Fokus', 'label': '🎧 Fokus'},
    {'id': 'K-Pop', 'label': '✨ K-Pop'},
    {'id': 'Anime', 'label': '🌸 Anime'},
  ];

  String _selectedMood = 'Pop Indo';
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

    // Combine recently played + favorites + mood songs for 6-item Quick Picks Grid
    final quickPickPool = <ZunifySong>[
      ...library.recentlyPlayed,
      ...library.favorites,
      ..._moodSongs,
      ..._trendingIndo,
    ];
    final seenIds = <String>{};
    final quickPicks = <ZunifySong>[];
    for (final s in quickPickPool) {
      if (seenIds.add(s.videoId)) {
        quickPicks.add(s);
        if (quickPicks.length >= 6) break;
      }
    }

    final heroSong = player.currentSong ??
        (quickPicks.isNotEmpty
            ? quickPicks.first
            : (_trendingIndo.isNotEmpty ? _trendingIndo.first : null));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          color: accent,
          onRefresh: _loadInitialHomeData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 118),
            children: [
              // Rich Top Header: Avatar + Time Greeting + Rapot Pill + Offline Pill
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [accent, theme.secondaryAccentColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.32),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      library.profile.username.isNotEmpty
                          ? library.profile.username[0].toUpperCase()
                          : 'Z',
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 19,
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
                          _getTimeGreeting(),
                          style: TextStyle(
                            color: accent,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          library.profile.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Weekly Rapot Button
                  GestureDetector(
                    onTap: () => _openWeeklyRapotModal(context),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
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
                          Icon(Icons.insights_rounded, color: accent, size: 15),
                          const SizedBox(width: 5),
                          Text(
                            'Rapot',
                            style: TextStyle(
                              color: accent,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Offline Mode Toggle Pill
                  GestureDetector(
                    onTap: () =>
                        player.setOfflineMode(!player.offlineModeEnabled),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: player.offlineModeEnabled
                            ? accent
                            : Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.10),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            player.offlineModeEnabled
                                ? Icons.cloud_off_rounded
                                : Icons.wifi_rounded,
                            color: player.offlineModeEnabled
                                ? Colors.black
                                : Colors.white70,
                            size: 14,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            'Offline',
                            style: TextStyle(
                              color: player.offlineModeEnabled
                                  ? Colors.black
                                  : Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              if (player.offlineModeEnabled) ...[
                _buildOfflineList(library, player, accent),
              ] else ...[
                // Interactive Mood Chips with Icons
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _moods.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final moodId = _moods[i]['id']!;
                      final moodLabel = _moods[i]['label']!;
                      final selected = moodId == _selectedMood;
                      return GestureDetector(
                        onTap: () => _selectMood(moodId),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? accent
                                : Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected
                                  ? accent
                                  : Colors.white.withOpacity(0.10),
                            ),
                          ),
                          child: Text(
                            moodLabel,
                            style: TextStyle(
                              color: selected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),

                // Hero Featured Mix Banner Card ("Mix Spesial Untukmu")
                if (heroSong != null) ...[
                  _buildHeroFeaturedBanner(
                    heroSong,
                    _moodSongs.isNotEmpty ? _moodSongs : _trendingIndo,
                    player,
                    library.profile.username,
                    accent,
                    theme.secondaryAccentColor,
                  ),
                  const SizedBox(height: 20),
                ],

                // Spotify / AusDMusic 2-Column Quick Picks Grid (6 items)
                if (quickPicks.isNotEmpty) ...[
                  _sectionHeader('Pilihan Cepat', subtitle: 'Putar instan'),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: quickPicks.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      childAspectRatio: 3.05,
                    ),
                    itemBuilder: (context, i) {
                      final song = quickPicks[i];
                      return _buildQuickPickTile(
                        song,
                        quickPicks,
                        player,
                        accent,
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                ],

                // Mood Mix Carousel
                _sectionHeader(
                  'Mix $_selectedMood',
                  subtitle: 'Rekomendasi sesuai suasana hatimu',
                ),
                const SizedBox(height: 12),
                if (_isLoadingCharts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 36),
                    child: Center(
                      child: CircularProgressIndicator(color: accent),
                    ),
                  )
                else
                  SizedBox(
                    height: 182,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _moodSongs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, idx) {
                        final song = _moodSongs[idx];
                        return _squareSongCard(
                          song,
                          _moodSongs,
                          player,
                          accent,
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 22),

                // Trending Indonesia
                _sectionHeader(
                  'Populer di Indonesia 🇮🇩',
                  subtitle: 'Lagu paling sering diputar minggu ini',
                ),
                const SizedBox(height: 10),
                ..._trendingIndo.take(6).toList().asMap().entries.map(
                      (entry) => _cleanSongRow(
                        entry.value,
                        _trendingIndo,
                        player,
                        library,
                        accent,
                        rank: entry.key + 1,
                      ),
                    ),
                const SizedBox(height: 22),

                // Trending Global
                _sectionHeader(
                  'Top Global 🌍',
                  subtitle: 'Hits dunia yang lagi naik daun',
                ),
                const SizedBox(height: 10),
                ..._trendingGlobal.take(6).toList().asMap().entries.map(
                      (entry) => _cleanSongRow(
                        entry.value,
                        _trendingGlobal,
                        player,
                        library,
                        accent,
                        rank: entry.key + 1,
                      ),
                    ),
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
    PlayerProvider player,
    String username,
    Color accent,
    Color secondaryAccent,
  ) {
    final queueToPlay = mixList.isNotEmpty ? mixList : [song];
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                accent.withOpacity(0.24),
                secondaryAccent.withOpacity(0.14),
                Colors.white.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: accent.withOpacity(0.32)),
          ),
          child: Row(
            children: [
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
                        color: Colors.black.withOpacity(0.35),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        'MIX SPESIAL • $_selectedMood'.toUpperCase(),
                        style: TextStyle(
                          color: accent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${song.artist} & radio rekomendasi lainnya',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () =>
                              player.playSong(song, customQueue: queueToPlay),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow_rounded,
                                  color: Colors.black,
                                  size: 18,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Putar Mix',
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
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () {
                            if (!player.shuffleEnabled) {
                              player.toggleShuffle();
                            }
                            player.playSong(song, customQueue: queueToPlay);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.shuffle_rounded,
                                  color: Colors.white,
                                  size: 16,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Acak',
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
                  ],
                ),
              ),
              const SizedBox(width: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: CachedNetworkImage(
                  imageUrl: song.highResArtUrl,
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(
                    width: 96,
                    height: 96,
                    color: Colors.white10,
                    child: Icon(Icons.music_note, color: accent, size: 32),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickPickTile(
    ZunifySong song,
    List<ZunifySong> queueList,
    PlayerProvider player,
    Color accent,
  ) {
    final isCurrent = player.currentSong?.videoId == song.videoId;
    return GestureDetector(
      onTap: () => player.playSong(song, customQueue: queueList),
      child: Container(
        decoration: BoxDecoration(
          color: isCurrent
              ? accent.withOpacity(0.18)
              : Colors.white.withOpacity(0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isCurrent
                ? accent.withOpacity(0.45)
                : Colors.white.withOpacity(0.09),
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(
                left: Radius.circular(13),
              ),
              child: CachedNetworkImage(
                imageUrl: song.highResArtUrl,
                width: 54,
                height: double.infinity,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 54,
                  color: Colors.white10,
                  child: Icon(Icons.music_note, color: accent, size: 20),
                ),
              ),
            ),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    song.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCurrent ? accent : Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12.5,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    song.artist,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ),
            if (isCurrent)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: MiniAudioSpectrumBars(
                  isPlaying: player.isPlaying,
                  color: accent,
                  height: 13,
                ),
              )
            else
              const SizedBox(width: 6),
          ],
        ),
      ),
    );
  }

  Widget _buildOfflineList(
    LibraryProvider library,
    PlayerProvider player,
    Color accent,
  ) {
    final songs = library.downloadedSongs;
    if (songs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 80),
        child: Center(
          child: Text(
            'Belum ada lagu tersimpan untuk mode offline.',
            style: TextStyle(color: Colors.white54),
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeader(
          'Tersimpan Offline (${songs.length})',
          subtitle: 'Putar tanpa kuota internet',
        ),
        const SizedBox(height: 10),
        ...songs.map(
          (s) => _cleanSongRow(s, songs, player, library, accent),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, {String? subtitle}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
  }

  Widget _squareSongCard(
    ZunifySong song,
    List<ZunifySong> queueList,
    PlayerProvider player,
    Color accent,
  ) {
    final isCurrent = player.currentSong?.videoId == song.videoId;
    return GestureDetector(
      onTap: () => player.playSong(song, customQueue: queueList),
      child: SizedBox(
        width: 134,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: CachedNetworkImage(
                    imageUrl: song.highResArtUrl,
                    width: 134,
                    height: 134,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 134,
                      height: 134,
                      color: Colors.white10,
                      child: Icon(Icons.music_note, color: accent),
                    ),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? accent
                          : Colors.black.withOpacity(0.65),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: isCurrent
                        ? MiniAudioSpectrumBars(
                            isPlaying: player.isPlaying,
                            color: Colors.black,
                            height: 12,
                          )
                        : const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: isCurrent ? accent : Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
            Text(
              song.artist,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cleanSongRow(
    ZunifySong song,
    List<ZunifySong> queueList,
    PlayerProvider player,
    LibraryProvider library,
    Color accent, {
    int? rank,
  }) {
    final isDownloaded = library.isDownloaded(song.videoId);
    final isFav = library.isFavorite(song.videoId);
    final isCurrent = player.currentSong?.videoId == song.videoId;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(
        color: isCurrent
            ? accent.withOpacity(0.12)
            : Colors.white.withOpacity(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCurrent
              ? accent.withOpacity(0.35)
              : Colors.white.withOpacity(0.05),
        ),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (rank != null) ...[
              SizedBox(
                width: 20,
                child: Text(
                  '$rank',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: rank <= 3 ? accent : Colors.white54,
                    fontWeight: FontWeight.w900,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 6),
            ],
            ClipRRect(
              borderRadius: BorderRadius.circular(11),
              child: CachedNetworkImage(
                imageUrl: song.highResArtUrl,
                width: 46,
                height: 46,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 46,
                  height: 46,
                  color: Colors.white10,
                  child: Icon(Icons.music_note, color: accent),
                ),
              ),
            ),
          ],
        ),
        title: Row(
          children: [
            if (isCurrent) ...[
              MiniAudioSpectrumBars(
                isPlaying: player.isPlaying,
                color: accent,
                height: 12,
              ),
              const SizedBox(width: 6),
            ],
            Expanded(
              child: Text(
                song.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isCurrent ? accent : Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13.8,
                ),
              ),
            ),
          ],
        ),
        subtitle: Text(
          song.artist,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: Colors.white54, fontSize: 11.8),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                isFav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: isFav ? accent : Colors.white38,
                size: 19,
              ),
              onPressed: () => library.toggleFavorite(song),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              icon: Icon(
                isDownloaded
                    ? Icons.download_done_rounded
                    : Icons.download_rounded,
                color: isDownloaded ? accent : Colors.white38,
                size: 19,
              ),
              onPressed: () {
                if (!isDownloaded) {
                  library.downloadSong(
                    song,
                    highQuality: player.highQualityAudio,
                  );
                }
              },
            ),
          ],
        ),
        onTap: () => player.playSong(song, customQueue: queueList),
      ),
    );
  }
}
