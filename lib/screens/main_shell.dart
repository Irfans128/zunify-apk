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
    await Future.delayed(const Duration(milliseconds: 2200));
    if (!mounted) return;
    if (!context.read<LibraryProvider>().hasCompletedOnboarding) return;
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

            // Floating Bottom Stack: Never pushed up by keyboard (`resizeToAvoidBottomInset: false`)
            Positioned(
              left: 12,
              right: 12,
              bottom: MediaQuery.viewPaddingOf(context).bottom + 8,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (hasCurrentSong) ...[
                    RepaintBoundary(
                      child: Consumer2<PlayerProvider, LibraryProvider>(
                        builder: (ctx, player, library, _) {
                          if (player.currentSong == null) {
                            return const SizedBox.shrink();
                          }
                          return _buildFloatingMiniPlayer(
                            ctx,
                            player,
                            library,
                            theme,
                            accent,
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                  ],
                  RepaintBoundary(
                    child: _buildBitChordFloatingTabBar(theme, accent),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Floating Tab Bar (Liquid Glass Capsule & Authentic Neo-Brutalist Sticker Bar)
  Widget _buildBitChordFloatingTabBar(ThemeProvider theme, Color accent) {
    final isBrutal = theme.isNeoBrutalism;
    const items = [
      {'icon': Icons.home_rounded, 'label': 'Beranda'},
      {'icon': Icons.search_rounded, 'label': 'Cari'},
      {'icon': Icons.library_music_rounded, 'label': 'Koleksi'},
      {'icon': Icons.tune_rounded, 'label': 'Pengaturan'},
    ];

    return LiquidGlassBox(
      borderRadius: isBrutal ? 14 : 34,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      tintOpacity: 0.16,
      rimIntensity: 0.50,
      enableBlur: true,
      enableShadow: true,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final tabWidth = constraints.maxWidth / items.length;
          return Stack(
            alignment: Alignment.centerLeft,
            children: [
              // Fluid Sliding Active Tab Indicator
              AnimatedPositioned(
                duration: theme.animDuration(290),
                curve: Curves.easeOutBack,
                left: _selectedIndex * tabWidth,
                top: 0,
                bottom: 0,
                width: tabWidth,
                child: DecoratedBox(
                  decoration: isBrutal
                      ? BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: theme.brutalBorderColor,
                            width: 2.0,
                          ),
                        )
                      : BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withOpacity(0.22),
                              accent.withOpacity(0.28),
                            ],
                          ),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.38),
                            width: 1.0,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: accent.withOpacity(0.22),
                              blurRadius: 12,
                              spreadRadius: -2,
                            ),
                          ],
                        ),
                ),
              ),
              Row(
                children: List.generate(items.length, (idx) {
                  final selected = _selectedIndex == idx;
                  final icon = items[idx]['icon'] as IconData;
                  final label = items[idx]['label'] as String;

                  final Color activeFg =
                      isBrutal ? const Color(0xFF111111) : accent;
                  final Color activeLabelFg =
                      isBrutal ? const Color(0xFF111111) : Colors.white;
                  final Color inactiveIconFg =
                      isBrutal ? theme.textSecondary : Colors.white60;
                  final Color inactiveLabelFg =
                      isBrutal ? theme.textMuted : Colors.white54;

                  return Expanded(
                    child: IosSpringButton(
                      scaleDown: 0.88,
                      borderRadius: isBrutal ? 10 : 28,
                      onTap: () => setState(() => _selectedIndex = idx),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            AnimatedScale(
                              scale: selected ? 1.08 : 1.0,
                              duration: theme.animDuration(220),
                              curve: Curves.easeOutBack,
                              child: Icon(
                                icon,
                                color: selected ? activeFg : inactiveIconFg,
                                size: 20,
                              ),
                            ),
                            const SizedBox(height: 2.5),
                            Text(
                              label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: selected
                                    ? activeLabelFg
                                    : inactiveLabelFg,
                                fontSize: 10.5,
                                fontWeight: selected
                                    ? FontWeight.w800
                                    : FontWeight.w600,
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
    final isBrutal = theme.isNeoBrutalism;

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        final vx = details.primaryVelocity ?? 0.0;
        if (vx < -280) {
          player.playNext();
        } else if (vx > 280) {
          player.playPrevious();
        }
      },
      child: LiquidGlassBox(
        borderRadius: isBrutal ? 14 : 26,
        tintColor: isBrutal ? Colors.white : theme.playerAmbientColor,
        tintOpacity: 0.18,
        rimIntensity: 0.50,
        enableBlur: true,
        enableShadow: true,
        scaleDown: 0.96,
        onTap: () {
          Navigator.of(context).push(
            PageRouteBuilder(
              transitionDuration: theme.animDuration(320),
              reverseTransitionDuration: theme.animDuration(250),
              pageBuilder: (_, __, ___) => const NowPlayingScreen(),
              transitionsBuilder: (_, anim, __, child) {
                final slideCurve = CurvedAnimation(
                  parent: anim,
                  curve: Curves.easeOutQuart,
                  reverseCurve: Curves.easeInCubic,
                );
                final fadeCurve = CurvedAnimation(
                  parent: anim,
                  curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
                );
                return FadeTransition(
                  opacity: Tween<double>(begin: 0.35, end: 1.0).animate(fadeCurve),
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, 0.94),
                      end: Offset.zero,
                    ).animate(slideCurve),
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
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: isBrutal
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: theme.brutalBorderColor,
                              width: 1.8,
                            ),
                          )
                        : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isBrutal ? 8.2 : 13),
                      child: CachedNetworkImage(
                        imageUrl: song.highResArtUrl,
                        width: 44,
                        height: 44,
                        memCacheWidth: 130,
                        fadeInDuration: const Duration(milliseconds: 120),
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => Container(
                          width: 44,
                          height: 44,
                          color: theme.subtleFill,
                          child: Icon(
                            Icons.music_note_rounded,
                            color: theme.accentText,
                            size: 20,
                          ),
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
                              color: theme.accentText,
                              height: 11,
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
                            color: theme.textSecondary,
                            fontSize: 11.8,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IosSpringButton(
                    scaleDown: 0.82,
                    borderRadius: 18,
                    onTap: () => library.toggleFavorite(song),
                    child: SizedBox(
                      width: 34,
                      height: 36,
                      child: Center(
                        child: Icon(
                          isFav
                              ? Icons.favorite_rounded
                              : Icons.favorite_border_rounded,
                          color: isFav
                              ? (isBrutal
                                  ? const Color(0xFFE11D48)
                                  : accent)
                              : theme.textMuted,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (player.isLoadingTrack)
                    SizedBox(
                      width: 36,
                      height: 36,
                      child: Center(
                        child: SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: theme.accentText,
                            strokeWidth: 2.2,
                          ),
                        ),
                      ),
                    )
                  else
                    IosSpringButton(
                      scaleDown: 0.84,
                      borderRadius: isBrutal ? 10 : 18,
                      onTap: () => player.togglePlayPause(),
                      child: Container(
                        width: 36,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: isBrutal
                            ? BoxDecoration(
                                color: accent,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: theme.brutalBorderColor,
                                  width: 2.0,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: theme.brutalShadowColor,
                                    blurRadius: 0,
                                    offset: const Offset(2.0, 2.0),
                                  ),
                                ],
                              )
                            : BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withOpacity(0.24),
                                    Colors.white.withOpacity(0.10),
                                  ],
                                ),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.36),
                                  width: 1.0,
                                ),
                              ),
                        child: Icon(
                          player.isPlaying
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          color: isBrutal
                              ? const Color(0xFF111111)
                              : Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                  const SizedBox(width: 4),
                  IosSpringButton(
                    scaleDown: 0.84,
                    borderRadius: 18,
                    onTap: () => player.playNext(),
                    child: SizedBox(
                      width: 34,
                      height: 36,
                      child: Center(
                        child: Icon(
                          Icons.skip_next_rounded,
                          color: theme.textSecondary,
                          size: 23,
                        ),
                      ),
                    ),
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
                    minHeight: isBrutal ? 3.0 : 2.0,
                    backgroundColor: theme.dividerColor,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      isBrutal ? theme.accentText : accent,
                    ),
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
