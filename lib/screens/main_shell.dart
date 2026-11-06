import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/update_service.dart';
import '../services/ytmusic_service.dart';
import '../widgets/liquid_background_widget.dart';
import '../widgets/update_sheet.dart';
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

class _MainShellState extends State<MainShell> with WidgetsBindingObserver {
  int _selectedIndex = 0;
  Timer? _broadcastPollTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkSunday18WIBRapotPopup();
      _checkBackgroundUpdate();
    });
    _broadcastPollTimer = Timer.periodic(
      const Duration(minutes: 3),
      (_) => _pollBroadcastOnly(),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _broadcastPollTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _pollBroadcastOnly();
    }
  }

  Future<void> _pollBroadcastOnly() async {
    if (!mounted) return;
    try {
      final broadcast = await UpdateService().checkBroadcastAnnouncement();
      if (broadcast != null && mounted) {
        _showBroadcastDialog(context, broadcast);
      }
    } catch (_) {}
  }

  Future<void> _checkBackgroundUpdate() async {
    await Future.delayed(const Duration(milliseconds: 3500));
    if (!mounted) return;
    final updater = UpdateService();
    try {
      final info = await updater.checkForUpdate(manual: false);
      if (info != null && mounted) {
        await showUpdateSheet(context, info);
      }
    } catch (_) {}

    if (!mounted) return;
    try {
      final broadcast = await updater.checkBroadcastAnnouncement();
      if (broadcast != null && mounted) {
        _showBroadcastDialog(context, broadcast);
      }
    } catch (_) {}
  }

  void _showBroadcastDialog(BuildContext context, BroadcastAnnouncement item) {
    final accent = context.read<ThemeProvider>().accentColor;
    final player = context.read<PlayerProvider>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF101420),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: accent.withOpacity(0.35)),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.16),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.campaign_rounded, color: accent, size: 22),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                item.title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (item.imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: CachedNetworkImage(
                    imageUrl: item.imageUrl,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorWidget: (_, __, ___) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 14),
              ],
              Text(
                item.message,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13.8,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '— ${item.sender}',
                style: TextStyle(
                  color: accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (item.songQuery.isNotEmpty) ...[
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () async {
                      Navigator.pop(ctx);
                      try {
                        final songs = await widget.ytMusicService
                            .searchSongs(item.songQuery);
                        if (songs.isNotEmpty) {
                          await player.playSong(
                            songs.first,
                            customQueue: songs,
                            contextName: 'Pilihan Fannz',
                          );
                        }
                      } catch (_) {}
                    },
                    icon: const Icon(Icons.play_circle_fill_rounded, size: 18),
                    label: Text(
                      'Putar: ${item.songQuery}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
              if (item.actionUrl.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pop(ctx);
                      UpdateService.openExternalUrl(item.actionUrl);
                    },
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: const Text(
                      'Buka Link',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Siap, Mengerti',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
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
      extendBody: true,
      body: LiquidBackgroundWidget(
        primaryColor: theme.playerAmbientColor,
        secondaryColor: theme.secondaryAccentColor,
        baseColor: theme.scaffoldBgColor,
        imageUrl: player.currentSong?.highResArtUrl,
        intensity: (0.44 * theme.blurIntensity).clamp(0.18, 0.56),
        child: Stack(
          children: [
            IndexedStack(
              index: _selectedIndex,
              children: screens,
            ),

            // BitChord Floating Bottom Stack: Liquid Glass MiniPlayer + FloatingTabBar Capsule
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.of(context).padding.bottom + 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (player.currentSong != null) ...[
                    _buildFloatingMiniPlayer(
                      context,
                      player,
                      library,
                      theme,
                      accent,
                    ),
                    const SizedBox(height: 8),
                  ],
                  _buildBitChordFloatingTabBar(theme, accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// BitChord `FloatingTabBarKt` + `GlassSelectionPill`
  Widget _buildBitChordFloatingTabBar(ThemeProvider theme, Color accent) {
    const items = [
      {'icon': Icons.home_rounded, 'label': 'Beranda'},
      {'icon': Icons.search_rounded, 'label': 'Cari'},
      {'icon': Icons.library_music_rounded, 'label': 'Koleksi'},
      {'icon': Icons.tune_rounded, 'label': 'Pengaturan'},
    ];

    return LiquidGlassBox(
      borderRadius: 30,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      tintOpacity: 0.11,
      rimIntensity: 0.44,
      child: Row(
        children: List.generate(items.length, (idx) {
          final selected = _selectedIndex == idx;
          final icon = items[idx]['icon'] as IconData;
          final label = items[idx]['label'] as String;

          return Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _selectedIndex = idx),
              child: AnimatedContainer(
                duration: theme.animDuration(240),
                curve: Curves.easeOutCubic,
                padding: const EdgeInsets.symmetric(vertical: 7),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: selected
                      ? LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            accent.withOpacity(0.26),
                            Colors.white.withOpacity(0.10),
                          ],
                        )
                      : null,
                  border: Border.all(
                    color: selected
                        ? accent.withOpacity(0.48)
                        : Colors.transparent,
                    width: 1.0,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      color: selected ? accent : Colors.white60,
                      size: 21,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: selected ? Colors.white : Colors.white54,
                        fontSize: 10.5,
                        fontWeight:
                            selected ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFloatingMiniPlayer(
    BuildContext context,
    PlayerProvider player,
    LibraryProvider library,
    ThemeProvider theme,
    Color accent,
  ) {
    final song = player.currentSong!;
    final isFav = library.isFavorite(song.videoId);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final vx = details.primaryVelocity ?? 0.0;
        if (vx < -280) {
          player.playNext();
        } else if (vx > 280) {
          player.playPrevious();
        }
      },
      onTap: () {
        Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: theme.animDuration(320),
            reverseTransitionDuration: theme.animDuration(260),
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
      child: LiquidGlassBox(
        borderRadius: 22,
        tintColor: theme.playerAmbientColor,
        tintOpacity: 0.14,
        rimIntensity: 0.46,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 7, 6, 7),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: song.highResArtUrl,
                      width: 43,
                      height: 43,
                      memCacheWidth: 130,
                      fadeInDuration: const Duration(milliseconds: 120),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 43,
                        height: 43,
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
                                  fontWeight: FontWeight.w800,
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
                            color: Colors.white.withOpacity(0.65),
                            fontSize: 11.8,
                            fontWeight: FontWeight.w600,
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
            RepaintBoundary(
              child: StreamBuilder<Duration>(
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
            ),
          ],
        ),
      ),
    );
  }
}
