import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/library_provider.dart';
import 'providers/player_provider.dart';
import 'providers/theme_provider.dart';
import 'screens/main_shell.dart';
import 'services/download_service.dart';
import 'services/equalizer_service.dart';
import 'services/lyrics_translation_service.dart';
import 'services/playlist_importer_service.dart';
import 'services/rapot_service.dart';
import 'services/ytmusic_service.dart';
import 'services/zunify_audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep decoded image bitmap cache lightweight in RAM (~45 MB max, 120 images)
  PaintingBinding.instance.imageCache.maximumSize = 120;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 45 * 1024 * 1024;

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  ZunifyAudioHandler? audioHandler;
  try {
    audioHandler = await AudioService.init(
      builder: () => ZunifyAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.fannz.zunify.channel.audio',
        androidNotificationChannelName: 'Zunify Music Playback',
        androidNotificationChannelDescription:
            'Kontrol pemutaran musik Zunify di latar belakang & layar kunci',
        androidNotificationIcon: 'drawable/ic_stat_zunify',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidShowNotificationBadge: true,
      ),
    );
  } catch (_) {}

  final ytMusicService = YTMusicService();
  final lyricsService = LyricsTranslationService();
  final downloadService = DownloadService(ytMusicService, lyricsService);
  final importerService = PlaylistImporterService(ytMusicService);
  final equalizerService = EqualizerService();
  final rapotService = RapotService();

  final themeProvider = ThemeProvider();
  final libraryProvider = LibraryProvider(downloadService, importerService);
  final playerProvider = PlayerProvider(
    audioHandler: audioHandler,
    ytMusicService: ytMusicService,
    lyricsService: lyricsService,
    downloadService: downloadService,
    equalizerService: equalizerService,
    rapotService: rapotService,
    libraryProvider: libraryProvider,
    themeProvider: themeProvider,
  );

  await Future.wait([
    themeProvider.loadPreferences(),
    libraryProvider.loadLibrary(),
    playerProvider.initPreferences(),
  ]);

  await rapotService.init(username: libraryProvider.profile.username);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: themeProvider),
        ChangeNotifierProvider.value(value: libraryProvider),
        ChangeNotifierProvider.value(value: playerProvider),
      ],
      child: ZunifyApp(ytMusicService: ytMusicService),
    ),
  );
}

class ZunifyApp extends StatelessWidget {
  final YTMusicService ytMusicService;

  const ZunifyApp({super.key, required this.ytMusicService});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isLight = theme.isLightCanvas;

    final baseTextTheme = isLight
        ? ThemeData.light().textTheme
        : ThemeData.dark().textTheme;

    final appTheme = ThemeData(
      brightness: isLight ? Brightness.light : Brightness.dark,
      scaffoldBackgroundColor: theme.scaffoldBgColor,
      primaryColor: theme.accentColor,
      colorScheme: ColorScheme(
        brightness: isLight ? Brightness.light : Brightness.dark,
        primary: theme.accentColor,
        onPrimary: const Color(0xFF111111),
        secondary: theme.secondaryAccentColor,
        onSecondary: const Color(0xFF111111),
        error: Colors.redAccent,
        onError: Colors.white,
        surface: theme.cardBgColor,
        onSurface: theme.textPrimary,
      ),
      textTheme: GoogleFonts.plusJakartaSansTextTheme(baseTextTheme).apply(
        bodyColor: theme.textPrimary,
        displayColor: theme.textPrimary,
      ),
      iconTheme: IconThemeData(color: theme.textPrimary),
      useMaterial3: true,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness:
            isLight ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness:
            isLight ? Brightness.dark : Brightness.light,
      ),
      child: MaterialApp(
        title: 'Zunify',
        debugShowCheckedModeBanner: false,
        themeMode: isLight ? ThemeMode.light : ThemeMode.dark,
        theme: appTheme,
        darkTheme: appTheme,
        home: MainShell(ytMusicService: ytMusicService),
      ),
    );
  }
}
