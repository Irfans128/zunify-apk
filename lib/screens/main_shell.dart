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
import '../widgets/permissions_sheet.dart';
import '../widgets/update_sheet.dart';
import '../widgets/vinyl_disc_widget.dart';
import '../widgets/weekly_rapot_modal.dart';
import '../widgets/whats_new_v3_sheet.dart';
import '../widgets/zidny_birthday_dialog.dart';
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
  late final List<Widget> _screens;
  bool _checkedInitialMainStartup = false;

  @override
  void initState() {
    super.initState();
    _screens = [
      HomeScreen(ytMusicService: widget.ytMusicService),
      SearchScreen(ytMusicService: widget.ytMusicService),
      const LibraryScreen(),
      const SettingsScreen(),
    ];
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> _checkMissingPermissions() async {
    await Future.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    if (!context.read<LibraryProvider>().hasCompletedOnboarding) return;
    await AppPermissionsManager.checkAndPromptIfMissing(context);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkMissingPermissions();
    }
  }

  Future<void> _checkBackgroundUpdate() async {
    await Future.delayed(const Duration(milliseconds: 1800));
    if (!mounted) return;
    if (!context.read<LibraryProvider>().hasCompletedOnboarding) return;
    await showZidnyBirthdayIfFirstOpen(context);
    if (!mounted) return;
    await showWhatsNewV3IfNeeded(context);
    if (!mounted) return;
    final updater = UpdateService();
    try {
      final info = await updater.checkForUpdate(manual: false);
      if (info != null &&
          mounted &&
          context.read<LibraryProvider>().hasCompletedOnboarding) {
        await showUpdateSheet(context, info);
      }
    } catch (_) {}
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
    final hasCompletedOnboarding = context.select<LibraryProvider, bool>(
      (l) => l.hasCompletedOnboarding,
    );
    if (!hasCompletedOnboarding) {
      return const OnboardingScreen();
    }

    if (!_checkedInitialMainStartup) {
      _checkedInitialMainStartup = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _checkMissingPermissions();
        _checkSunday18WIBRapotPopup();
        _checkBackgroundUpdate();
      });
    }

    final theme = context.watch<ThemeProvider>();
    final accent = theme.accentColor;
    final currentArtUrl = context.select<PlayerProvider, String?>(
      (p) => p.currentSong?.highResArtUrl,
    );
    final hasCurrentSong = context.select<PlayerProvider, bool>(
      (p) => p.currentSong != null,
    );

    return Scaffold(
      backgroundColor: theme.scaffoldBgColor,
      extendBody: true,
      resizeToAvoidBottomInset: false,
      body: LiquidBackgroundWidget(
        primaryColor: theme.playerAmbientColor,
        secondaryColor: theme.secondaryAccentColor,
        baseColor: theme.scaffoldBgColor,
        imageUrl: currentArtUrl,
        intensity: (0.46 * theme.blurIntensity).clamp(0.20, 0.60),
        child: Stack(
          children: [
            RepaintBoundary(
              child: TweenAnimationBuilder<double>(
                key: ValueKey<int>(_selectedIndex),
                tween: Tween<double>(begin: 0.988, end: 1.0),
                duration: theme.animDuration(190),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  final opacity = ((value - 0.988) / 0.012).clamp(0.0, 1.0);
                  return Opacity(
                    opacity: 0.80 + (0.20 * opacity),
                    child: Transform.scale(
                      scale: value,
                      child: child,
                    ),
                  );
                },
                child: IndexedStack(
                  index: _selectedIndex,
                  children: _screens,
                ),
              ),
            ),

            // Unified Dynamic Floating Dock (Mini-Player + Navigation in 1 Capsule)
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.viewPaddingOf(context).bottom + 8,
              child: RepaintBoundary(
                child: _buildUnifiedDynamicDock(
                  context: context,
                  theme: theme,
                  accent: accent,
                  hasCurrentSong: hasCurrentSong,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Unified Dynamic Floating Dock (Live-Lyric Mini-Player + Slim Navigation)
  Widget _buildUnifiedDynamicDock({
    required BuildContext context,
    required ThemeProvider theme,
    required Color accent,
    required bool hasCurrentSong,
  }) {
    final isBrutal = theme.isNeoBrutalism;
    final isIpod = theme.isClassicIpod;

    return LiquidGlassBox(
      borderRadius: isBrutal ? 16 : (isIpod ? 18 : 28),
      tintColor: (isBrutal || isIpod) ? Colors.white : theme.playerAmbientColor,
      tintOpacity: 0.16,
      rimIntensity: 0.48,
      enableBlur: true,
      enableShadow: true,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (hasCurrentSong)
            Consumer2<PlayerProvider, LibraryProvider>(
              builder: (ctx, player, library, _) {
                if (player.currentSong == null) {
                  return const SizedBox.shrink();
                }
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDockMiniPlayerContent(
                      ctx,
                      player,
                      library,
                      theme,
                      accent,
                    ),
                    Divider(
                      height: 1,
                      thickness: isBrutal ? 1.5 : 0.8,
                      color: isBrutal
                          ? theme.brutalBorderColor.withOpacity(0.25)
                          : theme.dividerColor,
                    ),
                  ],
                );
              },
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
            child: _buildSlimNavRow(theme, accent),
          ),
        ],
      ),
    );
  }

  Widget _buildSlimNavRow(ThemeProvider theme, Color accent) {
    final isBrutal = theme.isNeoBrutalism;
    final isIpod = theme.isClassicIpod;
    const items = [
      {'icon': Icons.home_rounded, 'label': 'Beranda'},
      {'icon': Icons.search_rounded, 'label': 'Cari'},
      {'icon': Icons.library_music_rounded, 'label': 'Koleksi'},
      {'icon': Icons.tune_rounded, 'label': 'Pengaturan'},
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final tabWidth = constraints.maxWidth / items.length;
        return Stack(
          alignment: Alignment.centerLeft,
          children: [
            AnimatedPositioned(
              duration: theme.animDuration(260),
              curve: Curves.easeOutBack,
              left: _selectedIndex * tabWidth,
              top: 0,
              bottom: 0,
              width: tabWidth,
              child: DecoratedBox(
                decoration: isBrutal
                    ? BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(11),
                        border: Border.all(
                          color: theme.brutalBorderColor,
                          width: 1.7,
                        ),
                      )
                    : isIpod
                        ? BoxDecoration(
                            color: accent.withOpacity(0.14),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: accent.withOpacity(0.45),
                              width: 1.0,
                            ),
                          )
                        : BoxDecoration(
                            borderRadius: BorderRadius.circular(22),
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withOpacity(0.18),
                                accent.withOpacity(0.26),
                              ],
                            ),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.32),
                              width: 1.0,
                            ),
                          ),
              ),
            ),
            Row(
              children: List.generate(items.length, (idx) {
                final selected = _selectedIndex == idx;
                final icon = items[idx]['icon'] as IconData;
                final label = items[idx]['label'] as String;

                final Color activeFg = isBrutal
                    ? const Color(0xFF111111)
                    : (isIpod ? accent : accent);
                final Color activeLabelFg = isBrutal
                    ? const Color(0xFF111111)
                    : (isIpod ? theme.textPrimary : Colors.white);
                final Color inactiveIconFg = (isBrutal || isIpod)
                    ? theme.textSecondary
                    : Colors.white60;
                final Color inactiveLabelFg = (isBrutal || isIpod)
                    ? theme.textMuted
                    : Colors.white54;

                return Expanded(
                  child: IosSpringButton(
                    scaleDown: 0.88,
                    borderRadius: isBrutal ? 11 : 22,
                    onTap: () => setState(() => _selectedIndex = idx),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            icon,
                            color: selected ? activeFg : inactiveIconFg,
                            size: 19,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: selected
                                  ? activeLabelFg
                                  : inactiveLabelFg,
                              fontSize: 10,
                              fontWeight:
                                  selected ? FontWeight.w800 : FontWeight.w600,
                              letterSpacing: -0.1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDockMiniPlayerContent(
    BuildContext context,
    PlayerProvider player,
    LibraryProvider library,
    ThemeProvider theme,
    Color accent,
  ) {
    final song = player.currentSong!;
    final isBrutal = theme.isNeoBrutalism;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
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
            transitionDuration: theme.animDuration(380),
            reverseTransitionDuration: theme.animDuration(300),
            pageBuilder: (_, __, ___) => const NowPlayingScreen(),
            transitionsBuilder: (_, anim, __, child) {
              final curved = CurvedAnimation(
                parent: anim,
                curve: Curves.easeOutCubic,
                reverseCurve: Curves.easeInCubic,
              );
              return FadeTransition(
                opacity: curved,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, 0.06),
                    end: Offset.zero,
                  ).animate(curved),
                  child: RepaintBoundary(child: child),
                ),
              );
            },
          ),
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 8, 8, 6),
            child: Row(
              children: [
                Hero(
                  tag: 'zunify_now_playing_art',
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(isBrutal ? 8 : 11),
                    child: CachedNetworkImage(
                      imageUrl: song.highResArtUrl,
                      width: 40,
                      height: 40,
                      memCacheWidth: 110,
                      fadeInDuration: const Duration(milliseconds: 120),
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(
                        width: 40,
                        height: 40,
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
                            color: theme.accentText,
                            height: 10,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              song.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 1.5),
                      Text(
                        song.artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: theme.textSecondary,
                          fontSize: 11.2,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (player.isLoadingTrack)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        color: theme.accentText,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else
                  IconButton(
                    icon: Icon(
                      player.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: theme.textPrimary,
                      size: 26,
                    ),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => player.togglePlayPause(),
                  ),
                IconButton(
                  icon: Icon(
                    Icons.skip_next_rounded,
                    color: theme.textSecondary,
                    size: 23,
                  ),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => player.playNext(),
                ),
              ],
            ),
          ),
          // Ultra-thin live progress bar
          StreamBuilder<Duration>(
            stream: player.audioPlayer.positionStream,
            builder: (context, snapshot) {
              final pos = snapshot.data ?? player.position;
              final totalMs = player.duration.inMilliseconds;
              final progress = totalMs > 0
                  ? (pos.inMilliseconds / totalMs).clamp(0.0, 1.0)
                  : 0.0;
              return LinearProgressIndicator(
                value: progress,
                minHeight: 2.0,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(accent),
              );
            },
          ),
        ],
      ),
    );
  }

}
