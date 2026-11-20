import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_shell.dart';
import 'services/lite_audio_handler.dart';
import 'services/lite_ytm_service.dart';
import 'state/zunifyg_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Ultra-low RAM cap for low-end / potato gaming phones (max 24 tiny thumbs / 6 MB)
  PaintingBinding.instance.imageCache.maximumSize = 24;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 6 * 1024 * 1024;

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
            'Kontrol pemutaran musik ultra-ringan ZunifyG',
        androidNotificationIcon: 'drawable/ic_stat_zunifyg',
        androidNotificationOngoing: true,
        androidStopForegroundOnPause: true,
      ),
    );
  } catch (_) {}

  final controller = ZunifyGController(
    handler: handler,
    ytm: LiteYtmService(),
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
      scaffoldBackgroundColor: const Color(0xFF0B0C10),
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF00E676),
        onPrimary: Colors.black,
        surface: Color(0xFF14161D),
        onSurface: Color(0xFFF3F4F6),
      ),
      useMaterial3: true,
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Color(0xFF14161D),
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
