import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:just_audio_background/just_audio_background.dart';
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

/// ZUNIFY v1.0.0 - Standalone Aesthetic Music Player
/// Crafted with ❤️ by Fannz (`com.fannz.zunify`)
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Lock portrait orientation for sleek mobile UX
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Initialize Foreground Audio Service & Lockscreen Notification Controls
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.fannz.zunify.channel.audio',
      androidNotificationChannelName: 'Zunify Music Playback',
      androidNotificationIcon: 'mipmap/launcher_icon',
      androidNotificationOngoing: true,
      androidShowNotificationBadge: true,
    );
  } catch (_) {}

  // Initialize Standalone Services
  final ytMusicService = YTMusicService();
  final lyricsService = LyricsTranslationService();
  final downloadService = DownloadService(ytMusicService, lyricsService);
  final importerService = PlaylistImporterService(ytMusicService);
  final equalizerService = EqualizerService();
  final rapotService = RapotService();

  // Initialize State Providers
  final themeProvider = ThemeProvider();
  await themeProvider.loadPreferences();

  final libraryProvider = LibraryProvider(downloadService, importerService);
  await libraryProvider.loadLibrary();

  await rapotService.init(username: libraryProvider.profile.username);

  final playerProvider = PlayerProvider(
    ytMusicService: ytMusicService,
    lyricsService: lyricsService,
    downloadService: downloadService,
    equalizerService: equalizerService,
    rapotService: rapotService,
    libraryProvider: libraryProvider,
    themeProvider: themeProvider,
  );
  await playerProvider.initPreferences();

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
