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
      backgroundColor: theme.scaffoldBgColor,
      body: SafeArea(
        child: RefreshIndicator(
          color: accent,
          onRefresh: _loadInitialHomeData,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 110),
            children: [
              // 1. Dynamic Greeting Header + Local Profile Avatar + Offline Switch
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          library.profile.timeBasedGreeting,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 21,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          library.profile.bioTagline,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Prominent Offline Mode Switch (Poin #4)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: player.offlineModeEnabled
                          ? accent.withOpacity(0.2)
                          : Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: player.offlineModeEnabled ? accent : Colors.white12,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          player.offlineModeEnabled
                              ? Icons.cloud_off_rounded
                              : Icons.wifi_rounded,
                          color: player.offlineModeEnabled ? accent : Colors.white70,
                          size: 16,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Offline',
                          style: TextStyle(
                            color: player.offlineModeEnabled ? accent : Colors.white70,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(
                          height: 28,
                          child: Switch(
                            value: player.offlineModeEnabled,
                            activeColor: accent,
                            onChanged: (v) => player.setOfflineMode(v),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // If Offline Mode is Active -> Show Private Vault Offline Songs directly!
              if (player.offlineModeEnabled) ...[
                _buildOfflineVaultBanner(library, player, accent),
              ] else ...[
                // 2. Weekly Rapot Banner (Auto triggers Sunday 18:00 WIB)
                GestureDetector(
                  onTap: () => _openWeeklyRapotModal(context),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: LinearGradient(
                        colors: [
                          accent.withOpacity(0.26),
                          theme.secondaryAccentColor.withOpacity(0.14),
                        ],
                      ),
                      border: Border.all(color: accent.withOpacity(0.45)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.22),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.insights_rounded, color: accent, size: 26),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Rapot Mingguan Zunify 📊',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15.5,
                                ),
                              ),
                              SizedBox(height: 3),
                              Text(
                                'Update otomatis tiap Minggu 18:00 WIB • Ketuk untuk lihat rekap musikmu!',
                                style: TextStyle(color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.chevron_right_rounded, color: accent),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // 3. Mood / Genre Chips
                SizedBox(
                  height: 38,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _moods.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final mood = _moods[i];
                      final selected = mood == _selectedMood;
                      return ChoiceChip(
                        label: Text(mood),
                        selected: selected,
                        selectedColor: accent,
                        backgroundColor: Colors.white.withOpacity(0.06),
                        labelStyle: TextStyle(
                          color: selected ? Colors.black : Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                        onSelected: (_) => _selectMood(mood),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 22),

                // 4. Recently Played ("Baru Saja Diputar")
                if (library.recentlyPlayed.isNotEmpty) ...[
                  _sectionHeader('Baru Saja Diputar 🕒', accent),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 168,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: library.recentlyPlayed.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, idx) {
                        final song = library.recentlyPlayed[idx];
                        return _horizontalSongCard(
                          song,
                          library.recentlyPlayed,
                          player,
                          accent,
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 22),
                ],

                // 5. Mood Mix Tracks
                _sectionHeader('Mix $_selectedMood Buat Lu ✨', accent),
                const SizedBox(height: 10),
                if (_isLoadingCharts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 30),
                    child: Center(child: CircularProgressIndicator(color: accent)),
                  )
                else
                  SizedBox(
                    height: 175,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _moodSongs.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 14),
                      itemBuilder: (context, idx) {
                        final song = _moodSongs[idx];
                        return _horizontalSongCard(song, _moodSongs, player, accent);
                      },
                    ),
                  ),
                const SizedBox(height: 22),

                // 6. Trending Indonesia
                _sectionHeader('🔥 Lagu Populer Indonesia', accent),
                const SizedBox(height: 8),
                ..._trendingIndo.take(6).map(
                      (song) => _verticalSongTile(
                        song,
                        _trendingIndo,
                        player,
                        library,
                        accent,
                      ),
                    ),
                const SizedBox(height: 22),

                // 7. Trending Global
                _sectionHeader('🌍 Top Global Charts', accent),
                const SizedBox(height: 8),
                ..._trendingGlobal.take(6).map(
                      (song) => _verticalSongTile(
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

  Widget _buildOfflineVaultBanner(
    LibraryProvider library,
    PlayerProvider player,
    Color accent,
  ) {
    final songs = library.downloadedSongs;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: accent.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withOpacity(0.4)),
          ),
          child: Row(
            children: [
              Icon(Icons.offline_pin_rounded, color: accent, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Mode Offline Aktif • Menampilkan ${songs.length} lagu dari penyimpanan internal Zunify (Bebas Kuota).',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        if (songs.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'Belum ada lagu yang di-download.\nMatikan Mode Offline untuk mencari & download lagu.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54),
              ),
            ),
          )
        else
          ...songs.map(
            (s) => _verticalSongTile(s, songs, player, library, accent),
          ),
      ],
    );
  }

  Widget _sectionHeader(String title, Color accent) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17.5,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _horizontalSongCard(
    ZunifySong song,
    List<ZunifySong> queueList,
    PlayerProvider player,
    Color accent,
  ) {
    return GestureDetector(
      onTap: () => player.playSong(song, customQueue: queueList),
      child: SizedBox(
        width: 128,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Stack(
                children: [
                  CachedNetworkImage(
                    imageUrl: song.highResArtUrl,
                    width: 128,
                    height: 118,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 128,
                      height: 118,
                      color: Colors.white10,
                      child: Icon(Icons.music_note, color: accent),
                    ),
                  ),
                  Positioned(
                    right: 6,
                    bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.play_arrow_rounded, color: accent, size: 18),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 7),
            Text(
              song.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
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

  Widget _verticalSongTile(
    ZunifySong song,
    List<ZunifySong> queueList,
    PlayerProvider player,
    LibraryProvider library,
    Color accent,
  ) {
    final isDownloaded = library.isDownloaded(song.videoId);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(vertical: 2),
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
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: 14,
        ),
      ),
      subtitle: Row(
        children: [
          if (isDownloaded) ...[
            Icon(Icons.download_done_rounded, color: accent, size: 14),
            const SizedBox(width: 4),
          ],
          Expanded(
            child: Text(
              '${song.artist} • ${song.formattedDuration}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
          ),
        ],
      ),
      trailing: IconButton(
        icon: Icon(
          isDownloaded
              ? Icons.offline_pin_rounded
              : Icons.download_for_offline_outlined,
          color: isDownloaded ? accent : Colors.white54,
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
