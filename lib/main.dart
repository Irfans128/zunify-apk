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

/// ZUNIFY v1.3.0 - Standalone Aesthetic Music Player
/// Crafted with ❤️ by Fannz (`com.fannz.zunify`)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Keep decoded image bitmap cache lightweight in RAM (~45 MB max, 120 images)
  PaintingBinding.instance.imageCache.maximumSize = 120;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 45 * 1024 * 1024;

  // Lock portrait orientation for sleek mobile UX
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialize Foreground Audio Service & Lockscreen Notification Controls
  // Uses transparent vector `@drawable/ic_stat_zunify` + full Prev/Play/Next buttons
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

  // Initialize Standalone Services
  final ytMusicService = YTMusicService();
  final lyricsService = LyricsTranslationService();
  final downloadService = DownloadService(ytMusicService, lyricsService);
  final importerService = PlaylistImporterService(ytMusicService);
  final equalizerService = EqualizerService();
  final rapotService = RapotService();

  // Initialize State Providers in parallel for instant cold startup
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

    return MaterialApp(
      title: 'Zunify',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: theme.scaffoldBgColor,
        primaryColor: theme.accentColor,
        colorScheme: ColorScheme.dark(
          primary: theme.accentColor,
          secondary: theme.secondaryAccentColor,
          surface: theme.cardBgColor,
        ),
        textTheme: GoogleFonts.plusJakartaSansTextTheme(
          ThemeData.dark().textTheme,
        ),
        useMaterial3: true,
      ),
      home: MainShell(ytMusicService: ytMusicService),
    );
  }
}
