import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_shell.dart';
import 'services/lite_audio_handler.dart';
import 'services/lite_download_service.dart';
import 'services/lite_ytm_service.dart';
import 'state/zunifyg_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ultra-lean image RAM cap for potato devices
  PaintingBinding.instance.imageCache.maximumSize = 36;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 8 * 1024 * 1024;

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  LiteAudioHandler? handler;
  try {
    handler = await AudioService.init(
      builder: () => LiteAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.fannz.zunifyg.channel.audio',
        androidNotificationChannelName: 'ZunifyG Playback',
        androidNotificationChannelDescription:
            'Kontrol pemutaran musik ZunifyG di notifikasi & layar kunci',
        androidNotificationIcon: 'drawable/ic_stat_zunifyg',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
        androidShowNotificationBadge: true,
      ),
    );
  } catch (_) {}

  final ytm = LiteYtmService();
  final controller = ZunifyGController(
    handler: handler,
    ytm: ytm,
    downloader: LiteDownloadService(ytm),
  );
  await controller.init();

  runApp(ZunifyGApp(controller: controller));
}

class ZunifyGApp extends StatelessWidget {
  final ZunifyGController controller;

  const ZunifyGApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final baseTheme = ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF09090B),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00E676),
        onPrimary: Colors.black,
        surface: Color(0xFF141418),
        onSurface: Color(0xFFF4F4F5),
      ),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
      useMaterial3: true,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF0F0F13),
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: MaterialApp(
        title: 'ZunifyG',
        debugShowCheckedModeBanner: false,
        theme: baseTheme,
        home: HomeShell(controller: controller),
      ),
    );
  }
}
