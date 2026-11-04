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

    // Show First-Time Welcome Login Screen if user hasn't entered their name yet
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
        intensity: 0.28,
        child: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              children: screens,
            ),

            // Floating Liquid Glass Mini-Player
            if (player.currentSong != null)
              Positioned(
                left: 14,
                right: 14,
                bottom: 10,
                child: _buildFloatingMiniPlayer(context, player, theme, accent),
              ),
          ],
        ),
      ),
      bottomNavigationBar: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBgColor.withOpacity(0.82),
              border: Border(
                top: BorderSide(color: Colors.white.withOpacity(0.08)),
              ),
            ),
            child: NavigationBarTheme(
              data: NavigationBarThemeData(
                backgroundColor: Colors.transparent,
                indicatorColor: accent.withOpacity(0.18),
                labelTextStyle: WidgetStateProperty.resolveWith((states) {
                  if (states.contains(WidgetState.selected)) {
                    return TextStyle(
                      color: accent,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                    );
                  }
                  return const TextStyle(color: Colors.white54, fontSize: 11);
                }),
              ),
              child: NavigationBar(
                height: 62,
                selectedIndex: _selectedIndex,
                onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined, color: Colors.white60),
                    selectedIcon: Icon(Icons.home_rounded, color: accent),
                    label: 'Beranda',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.search_rounded, color: Colors.white60),
                    selectedIcon: Icon(Icons.search_rounded, color: accent),
                    label: 'Cari',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.library_music_outlined, color: Colors.white60),
                    selectedIcon: Icon(Icons.library_music_rounded, color: accent),
                    label: 'Koleksi',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.tune_rounded, color: Colors.white60),
                    selectedIcon: Icon(Icons.tune_rounded, color: accent),
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
    ThemeProvider theme,
    Color accent,
  ) {
    final song = player.currentSong!;
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
                ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
                child: child,
              );
            },
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.09),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 8, 6),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: CachedNetworkImage(
                          imageUrl: song.highResArtUrl,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            width: 44,
                            height: 44,
                            color: Colors.black38,
                            child: Icon(Icons.music_note, color: accent),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
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
                                  height: 13,
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
                              style: const TextStyle(
                                color: Colors.white60,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.skip_previous_rounded,
                          color: Colors.white70,
                          size: 24,
                        ),
                        onPressed: () => player.playPrevious(),
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
                          icon: Icon(
                            player.isPlaying
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            color: accent,
                            size: 34,
                          ),
                          onPressed: () => player.togglePlayPause(),
                        ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
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
                      minHeight: 2.5,
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
