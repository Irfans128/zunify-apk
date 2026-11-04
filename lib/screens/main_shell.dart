import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/ytmusic_service.dart';
import '../widgets/weekly_rapot_modal.dart';
import 'home_screen.dart';
import 'library_screen.dart';
import 'now_playing_screen.dart';
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

  /// Automatically pops up the Rapot Mingguan modal on Sunday >= 18:00 WIB
  /// if not yet viewed for that Sunday!
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
    final theme = context.watch<ThemeProvider>();
    final player = context.watch<PlayerProvider>();
    final accent = theme.accentColor;

    final screens = [
      HomeScreen(ytMusicService: widget.ytMusicService),
      SearchScreen(ytMusicService: widget.ytMusicService),
      const LibraryScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      backgroundColor: theme.scaffoldBgColor,
      body: Stack(
        children: [
          IndexedStack(
            index: _selectedIndex,
            children: screens,
          ),

          // Persistent Floating Glassmorphism Mini-Player Bar
          if (player.currentSong != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 10,
              child: _buildFloatingMiniPlayer(context, player, theme, accent),
            ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: theme.cardBgColor,
          border: Border(
            top: BorderSide(color: Colors.white.withOpacity(0.07)),
          ),
        ),
        child: NavigationBarTheme(
          data: NavigationBarThemeData(
            backgroundColor: theme.cardBgColor,
            indicatorColor: accent.withOpacity(0.18),
            labelTextStyle: WidgetStateProperty.resolveWith((states) {
              if (states.contains(WidgetState.selected)) {
                return TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                );
              }
              return const TextStyle(color: Colors.white54, fontSize: 11.5);
            }),
          ),
          child: NavigationBar(
            height: 64,
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
                label: 'Koleksiku',
              ),
              NavigationDestination(
                icon: const Icon(Icons.settings_outlined, color: Colors.white60),
                selectedIcon: Icon(Icons.settings_rounded, color: accent),
                label: 'Pengaturan',
              ),
            ],
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
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: theme.cardBgColor.withOpacity(0.92),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: accent.withOpacity(0.35)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.55),
                  blurRadius: 18,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                // Mini Vinyl Disc Thumbnail
                ClipOval(
                  child: CachedNetworkImage(
                    imageUrl: song.thumbnailUrl,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => Container(
                      width: 44,
                      height: 44,
                      color: Colors.black,
                      child: Icon(Icons.album, color: accent),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: accent.withOpacity(0.9),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(
                    player.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    color: accent,
                    size: 30,
                  ),
                  onPressed: () => player.togglePlayPause(),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.skip_next_rounded,
                    color: Colors.white70,
                    size: 26,
                  ),
                  onPressed: () => player.playNext(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
