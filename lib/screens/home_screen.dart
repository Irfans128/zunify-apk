import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/song_model.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/ytmusic_service.dart';
import '../widgets/weekly_rapot_modal.dart';

class HomeScreen extends StatefulWidget {
  final YTMusicService ytMusicService;

  const HomeScreen({super.key, required this.ytMusicService});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const List<String> _moods = [
    'Pop Indo',
    'Chill',
    'Galau',
    'Workout',
    'Fokus',
    'K-Pop',
    'Anime',
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

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: RefreshIndicator(
          color: accent,
          onRefresh: _loadInitialHomeData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 110),
            children: [
              // Clean Top Header: Greeting + Rapot Icon + Offline Pill
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Halo, ${library.profile.username}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Rapot Mingguan',
                    icon: Icon(Icons.bar_chart_rounded, color: accent),
                    onPressed: () => _openWeeklyRapotModal(context),
                  ),
                  const SizedBox(width: 4),
                  GestureDetector(
                    onTap: () => player.setOfflineMode(!player.offlineModeEnabled),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 220),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: player.offlineModeEnabled
                            ? accent
                            : Colors.white.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(20),
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
                            size: 15,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Offline',
                            style: TextStyle(
                              color: player.offlineModeEnabled
                                  ? Colors.black
                                  : Colors.white70,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              if (player.offlineModeEnabled) ...[
                _buildOfflineList(library, player, accent),
              ] else ...[
                // Clean Mood Chips
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _moods.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final mood = _moods[i];
                      final selected = mood == _selectedMood;
                      return GestureDetector(
                        onTap: () => _selectMood(mood),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: selected
                                ? accent
                                : Colors.white.withOpacity(0.07),
                            borderRadius: BorderRadius.circular(18),
                          ),
                          child: Text(
                            mood,
                            style: TextStyle(
                              color: selected ? Colors.black : Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Recently Played
                if (library.recentlyPlayed.isNotEmpty) ...[
                  _sectionHeader('Baru Diputar'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 176,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: library.recentlyPlayed.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, idx) {
                        final song = library.recentlyPlayed[idx];
                        return _squareSongCard(
                          song,
                          library.recentlyPlayed,
                          player,
                          accent,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Mood Mix
                _sectionHeader(_selectedMood),
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
                    height: 176,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _moodSongs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, idx) {
                        final song = _moodSongs[idx];
                        return _squareSongCard(song, _moodSongs, player, accent);
                      },
                    ),
                  ),
                const SizedBox(height: 24),

                // Trending Indonesia
                _sectionHeader('Populer di Indonesia'),
                const SizedBox(height: 10),
                ..._trendingIndo.take(6).map(
                      (song) => _cleanSongRow(
                        song,
                        _trendingIndo,
                        player,
                        library,
                        accent,
                      ),
                    ),
                const SizedBox(height: 24),

                // Trending Global
                _sectionHeader('Top Global'),
                const SizedBox(height: 10),
                ..._trendingGlobal.take(6).map(
                      (song) => _cleanSongRow(
                        song,
                        _trendingGlobal,
                        player,
                        library,
                        accent,
                      ),
                    ),
              ],
            ],
          ),
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
        _sectionHeader('Tersimpan (${songs.length})'),
        const SizedBox(height: 10),
        ...songs.map(
          (s) => _cleanSongRow(s, songs, player, library, accent),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.3,
      ),
    );
  }

  Widget _squareSongCard(
    ZunifySong song,
    List<ZunifySong> queueList,
    PlayerProvider player,
    Color accent,
  ) {
    return GestureDetector(
      onTap: () => player.playSong(song, customQueue: queueList),
      child: SizedBox(
        width: 132,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: CachedNetworkImage(
                imageUrl: song.highResArtUrl,
                width: 132,
                height: 132,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => Container(
                  width: 132,
                  height: 132,
                  color: Colors.white10,
                  child: Icon(Icons.music_note, color: accent),
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
    Color accent,
  ) {
    final isDownloaded = library.isDownloaded(song.videoId);
    final isCurrent = player.currentSong?.videoId == song.videoId;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: CachedNetworkImage(
          imageUrl: song.highResArtUrl,
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => Container(
            width: 48,
            height: 48,
            color: Colors.white10,
            child: Icon(Icons.music_note, color: accent),
          ),
        ),
      ),
      title: Text(
        song.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: isCurrent ? accent : Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
      subtitle: Text(
        song.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white54, fontSize: 12),
      ),
      trailing: IconButton(
        icon: Icon(
          isDownloaded
              ? Icons.download_done_rounded
              : Icons.download_rounded,
          color: isDownloaded ? accent : Colors.white38,
          size: 20,
        ),
        onPressed: () {
          if (!isDownloaded) {
            library.downloadSong(song, highQuality: player.highQualityAudio);
          }
        },
      ),
      onTap: () => player.playSong(song, customQueue: queueList),
    );
  }
}
