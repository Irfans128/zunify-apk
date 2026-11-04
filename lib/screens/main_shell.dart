import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/ytmusic_service.dart';
import '../widgets/liquid_background_widget.dart';
import '../widgets/vinyl_disc_widget.dart';
import '../widgets/weekly_rapot_modal.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'now_playing_screen.dart';
import 'onboarding_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class MainShell extends StatefulWidget {
  final YTMusicService ytMusicService;

  const MainShell({super.key, required this.ytMusicService});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSunday18WIBRapotPopup();
    });
  }

  Future<void> _checkSunday18WIBRapotPopup() async {
    final now = DateTime.now();
    if (now.weekday == DateTime.sunday && now.hour >= 18) {
      final prefs = await SharedPreferences.getInstance();
      final key = 'rapot_shown_${now.year}_${now.month}_${now.day}';
      final alreadyShown = prefs.getBool(key) ?? false;
      if (!alreadyShown && mounted) {
        await prefs.setBool(key, true);
        final player = context.read<PlayerProvider>();
        final rapot = await player.getWeeklyRapot();
        if (!mounted) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => WeeklyRapotModal(rapot: rapot),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final library = context.watch<LibraryProvider>();
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<PlayerProvider>();
    final accent = theme.accentColor;

    if (!library.hasCompletedOnboarding) {
      return const OnboardingScreen();
    }

    final screens = [
      HomeScreen(ytMusicService: widget.ytMusicService),
      SearchScreen(ytMusicService: widget.ytMusicService),
      const LibraryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBgColor,
      body: LiquidBackgroundWidget(
        primaryColor: theme.playerAmbientColor,
        secondaryColor: theme.secondaryAccentColor,
        baseColor: theme.scaffoldBgColor,
        imageUrl: player.currentSong?.highResArtUrl,
        intensity: 0.24,
        child: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              children: screens,
            ),

            // Clean Spotify / Apple Music Floating Mini-Player
            if (player.currentSong != null)
              Positioned(
                left: 12,
                right: 12,
                bottom: 8,
                child: _buildFloatingMiniPlayer(
                  context,
                  player,
                  library,
                  accent,
                ),
              ),
          ],
        ),
      ),
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBgColor.withOpacity(0.88),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.07)),
              ),
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.transparent,
                indicatorColor: accent.withOpacity(0.16),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    );
                  }
                  return const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  );
                }),
              ),
              child: NavigationBar(
                height: 60,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (idx) =>
                    setState(() => _selectedIndex = idx),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(
                      Icons.home_outlined,
                      color: Colors.white60,
                      size: 23,
                    ),
                    selectedIcon: Icon(
                      Icons.home_rounded,
                      color: accent,
                      size: 23,
                    ),
                    label: 'Beranda',
                  ),
                  NavigationDestination(
                    icon: const Icon(
                      Icons.search_rounded,
                      color: Colors.white60,
                      size: 23,
                    ),
                    selectedIcon: Icon(
                      Icons.search_rounded,
                      color: accent,
                      size: 23,
                    ),
                    label: 'Cari',
                  ),
                  NavigationDestination(
                    icon: const Icon(
                      Icons.library_music_outlined,
                      color: Colors.white60,
                      size: 22,
                    ),
                    selectedIcon: Icon(
                      Icons.library_music_rounded,
                      color: accent,
                      size: 22,
                    ),
                    label: 'Koleksi',
                  ),
                  NavigationDestination(
                    icon: const Icon(
                      Icons.tune_rounded,
                      color: Colors.white60,
                      size: 22,
                    ),
                    selectedIcon: Icon(
                      Icons.tune_rounded,
                      color: accent,
                      size: 22,
                    ),
                    label: 'Pengaturan',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFloatingMiniPlayer(
    BuildContext context,
    PlayerProvider player,
    LibraryProvider library,
    Color accent,
  ) {
    final song = player.currentSong!;
    final isFav = library.isFavorite(song.videoId);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            pageBuilder: (_, __, ___) => const NowPlayingScreen(),
            transitionsBuilder: (_, anim, __, child) {
              return SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 1),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
                ),
                child: child,
              );
            },
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 26, sigmaY: 26),
          child: Container(
            decoration: BoxDecoration(
              color: const Color(0xFF141824).withOpacity(0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.11)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: CachedNetworkImage(
                          imageUrl: song.highResArtUrl,
                          width: 42,
                          height: 42,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 42,
                            height: 42,
                            color: Colors.black38,
                            child: Icon(
                              Icons.music_note_rounded,
                              color: accent,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                MiniAudioSpectrumBars(
                                  isPlaying: player.isPlaying,
                                  color: accent,
                                  height: 11,
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    song.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              song.artist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.60),
                                fontSize: 11.8,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        splashRadius: 18,
                        icon: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFav ? accent : Colors.white60,
                          size: 21,
                        ),
                        onPressed: () => library.toggleFavorite(song),
                      ),
                      if (player.isLoadingTrack)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              color: accent,
                              strokeWidth: 2.2,
                            ),
                          ),
                        )
                      else
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          splashRadius: 20,
                          icon: Icon(
                            player.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                          onPressed: () => player.togglePlayPause(),
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        splashRadius: 18,
                        icon: const Icon(
                          Icons.skip_next_rounded,
                          color: Colors.white70,
                          size: 24,
                        ),
                        onPressed: () => player.playNext(),
                      ),
                    ],
                  ),
                ),
                StreamBuilder<Duration>(
                  stream: player.audioPlayer.positionStream,
                  builder: (context, snapshot) {
                    final pos = snapshot.data ?? Duration.zero;
                    final total = player.audioPlayer.duration ?? song.duration;
                    final progress = total.inMilliseconds > 0
                        ? (pos.inMilliseconds / total.inMilliseconds)
                            .clamp(0.0, 1.0)
                        : 0.0;
                    return LinearProgressIndicator(
                      value: progress,
                      minHeight: 2.2,
                      backgroundColor: Colors.white.withOpacity(0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(accent),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
