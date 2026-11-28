import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_version.dart';
import '../providers/theme_provider.dart';
import '../screens/theme_studio_screen.dart';
import 'liquid_background_widget.dart';

const String _kWhatsNewV300ShownKey = 'whats_new_v3_0_0_shown';
const MethodChannel _kLauncherPreviewChannel =
    MethodChannel('com.fannz.zunify/launcher');

/// Shows the one-time "Apa yang Baru di v3.0.0" showcase sheet after updating.
Future<void> showWhatsNewV3IfNeeded(BuildContext context) async {
  final prefs = await SharedPreferences.getInstance();
  final alreadyShown = prefs.getBool(_kWhatsNewV300ShownKey) ?? false;
  if (alreadyShown) return;
  await prefs.setBool(_kWhatsNewV300ShownKey, true);
  if (!context.mounted) return;
  await showWhatsNewV3Sheet(context);
}

/// Opens the "Apa yang Baru di v3.0.0" showcase sheet on demand (e.g. from Settings).
Future<void> showWhatsNewV3Sheet(BuildContext context) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _WhatsNewV3Sheet(),
  );
}

class _WhatsNewV3Sheet extends StatelessWidget {
  const _WhatsNewV3Sheet();

  static const _features = [
    (
      icon: Icons.auto_awesome_rounded,
      color: Color(0xFF38BDF8),
      title: 'Studio Tema & Liquid Glass Optik',
      subtitle:
          '3 tema penuh (Liquid Glass micro-grain, Neo-Brutalism, & Classic iPod) plus transisi Hero sampul halus.',
    ),
    (
      icon: Icons.dashboard_customize_rounded,
      color: Color(0xFFA78BFA),
      title: 'Zunify Built-In Launcher & Dynamic Capsule',
      subtitle:
          'Home Screen 100% Native ringan di dalam 1 APK dengan Dynamic Capsule musik + lirik live anti-nabrak.',
    ),
    (
      icon: Icons.lyrics_rounded,
      color: Color(0xFF34D399),
      title: 'Lirik Duet 2 Sisi & Mode iPod Minimalis',
      subtitle:
          'Penyanyi bergantian rata kiri/kanan ala Spotify, bebas kredit acak, dan layar lirik putih bersih di iPod.',
    ),
    (
      icon: Icons.graphic_eq_rounded,
      color: Color(0xFFF59E0B),
      title: 'Crossfade S-Curve, Grid Playlist & Share Card',
      subtitle:
          'Transisi lagu mulus, Unduh 1 Playlist sekaligus, Pin/Sortir playlist, serta kartu bagikan Minimalist & Polaroid.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = theme.accentColor;
    final isBrutal = theme.isNeoBrutalism;
    final bottomPad = MediaQuery.viewPaddingOf(context).bottom;

    return ZunifySheetContainer(
      padding: EdgeInsets.fromLTRB(20, 12, 20, bottomPad + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(isBrutal ? 0.92 : 0.18),
                    borderRadius: BorderRadius.circular(20),
                    border: isBrutal
                        ? Border.all(
                            color: theme.brutalBorderColor,
                            width: 1.5,
                          )
                        : Border.all(
                            color: accent.withOpacity(0.45),
                            width: 1.0,
                          ),
                  ),
                  child: Text(
                    'BARU DI v$kAppVersion',
                    style: TextStyle(
                      color: isBrutal
                          ? const Color(0xFF111111)
                          : theme.accentText,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
                const Spacer(),
                IosGlassIconButton(
                  icon: Icons.close_rounded,
                  size: 32,
                  iconSize: 17,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'Selamat Datang di Zunify 3.0',
              style: GoogleFonts.plusJakartaSans(
                color: theme.textPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.6,
                height: 1.15,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Pembaruan terbesar untuk tampilan, lirik, pemutaran, dan Home Screen bawaan.',
              style: TextStyle(
                color: theme.textSecondary,
                fontSize: 12.6,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ..._features.map((f) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: LiquidGlassBox(
                  borderRadius: 16,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  tintColor: f.color,
                  tintOpacity: isBrutal ? 0.14 : 0.08,
                  rimIntensity: 0.30,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: f.color.withOpacity(isBrutal ? 0.88 : 0.18),
                          borderRadius: BorderRadius.circular(11),
                          border: isBrutal
                              ? Border.all(
                                  color: theme.brutalBorderColor,
                                  width: 1.4,
                                )
                              : null,
                        ),
                        child: Icon(
                          f.icon,
                          color: isBrutal ? const Color(0xFF111111) : f.color,
                          size: 19,
                        ),
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              f.title,
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              f.subtitle,
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontSize: 11.7,
                                fontWeight: FontWeight.w500,
                                height: 1.38,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: IosGlassPillButton(
                    icon: Icons.palette_rounded,
                    label: 'Studio Tema',
                    height: 40,
                    expand: true,
                    fontSize: 12.2,
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ThemeStudioScreen(),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: IosGlassPillButton(
                    icon: Icons.rocket_launch_rounded,
                    label: 'Pratinjau Launcher',
                    height: 40,
                    expand: true,
                    fontSize: 12.2,
                    onTap: () async {
                      Navigator.pop(context);
                      try {
                        await _kLauncherPreviewChannel
                            .invokeMethod('openZunifyLauncherPreview');
                      } catch (_) {}
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: IosSpringButton(
                onTap: () => Navigator.pop(context),
                borderRadius: isBrutal ? 12 : 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(isBrutal ? 12 : 16),
                    border: isBrutal
                        ? Border.all(
                            color: theme.brutalBorderColor,
                            width: 1.8,
                          )
                        : null,
                  ),
                  child: const Text(
                    'Mulai Dengarkan Musik',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 13.8,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
