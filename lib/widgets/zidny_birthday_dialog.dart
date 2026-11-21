import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/theme_provider.dart';
import '../services/update_service.dart';
import 'liquid_background_widget.dart';

/// One-time birthday greeting popup for Zidny on Zunify v3.0.0 first launch.
/// Marked permanently in SharedPreferences so it only appears once per device.
Future<void> showZidnyBirthdayIfFirstOpen(BuildContext context) async {
  const kPrefDialogShown = 'zidny_bday_v300_dialog_shown';
  const kPrefNotifShown = 'zidny_bday_v300_notif_shown';

  final prefs = await SharedPreferences.getInstance();
  final alreadyShown = prefs.getBool(kPrefDialogShown) ?? false;
  if (alreadyShown) return;

  await prefs.setBool(kPrefDialogShown, true);

  final notifShown = prefs.getBool(kPrefNotifShown) ?? false;
  if (!notifShown) {
    await prefs.setBool(kPrefNotifShown, true);
    String? bannerLocalPath;
    try {
      final bytes = await rootBundle.load('assets/images/zidny_notif_banner.jpg');
      final tmp = await getTemporaryDirectory();
      final f = File('${tmp.path}/zidny_bday_banner.jpg');
      await f.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
      bannerLocalPath = f.path;
    } catch (_) {}

    await UpdateService.showSystemPushNotification(
      id: 10122026,
      title: '🎉 Selamat Ulang Tahun, Zidny!',
      body:
          'Barakallahu fi umrik Zidny! Sehat selalu, panjang umur, dan makin sukses dari Fannz & Zunify.',
      localImagePath: bannerLocalPath,
    );
  }

  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _ZidnyBirthdayDialog(),
  );
}

class _ZidnyBirthdayDialog extends StatefulWidget {
  const _ZidnyBirthdayDialog();

  @override
  State<_ZidnyBirthdayDialog> createState() => _ZidnyBirthdayDialogState();
}

class _ZidnyBirthdayDialogState extends State<_ZidnyBirthdayDialog> {
  final PageController _pageCtrl = PageController();
  int _page = 0;

  static const _photos = [
    {'path': 'assets/images/zidny_1.jpg', 'alignY': 0.42},
    {'path': 'assets/images/zidny_2.jpg', 'alignY': -0.10},
    {'path': 'assets/images/zidny_3.jpg', 'alignY': -0.16},
  ];

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = theme.accentColor;
    final isBrutal = theme.isNeoBrutalism;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 22, vertical: 24),
      child: Container(
        decoration: BoxDecoration(
          color: theme.sheetBgColor,
          borderRadius: BorderRadius.circular(isBrutal ? 18 : 26),
          border: Border.all(
            color: isBrutal
                ? theme.brutalBorderColor
                : accent.withOpacity(0.45),
            width: isBrutal ? 2.2 : 1.3,
          ),
          boxShadow: [
            BoxShadow(
              color: isBrutal
                  ? theme.brutalShadowColor
                  : Colors.black.withOpacity(0.55),
              blurRadius: isBrutal ? 0 : 28,
              offset: isBrutal ? const Offset(4, 4) : const Offset(0, 14),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Swipeable 3-Photo Carousel of Zidny (Individually face-centered!)
              SizedBox(
                height: 340,
                width: double.infinity,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    PageView.builder(
                      controller: _pageCtrl,
                      itemCount: _photos.length,
                      onPageChanged: (i) => setState(() => _page = i),
                      itemBuilder: (_, i) {
                        final item = _photos[i];
                        return Image.asset(
                          item['path'] as String,
                          fit: BoxFit.cover,
                          alignment: Alignment(
                            0.0,
                            (item['alignY'] as double),
                          ),
                        );
                      },
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      height: 80,
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.68),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          '🎂 10 Desember • Spesial',
                          style: TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 10,
                      left: 0,
                      right: 0,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          _photos.length,
                          (i) => AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            width: _page == i ? 18 : 6,
                            height: 6,
                            decoration: BoxDecoration(
                              color: _page == i ? accent : Colors.white54,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Warm Birthday Greeting
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selamat Ulang Tahun, Zidny! 🎉',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Barakallahu fi umrik, bro! Semoga di umur yang baru ini makin sehat, makin lancar rezekinya, tercapai semua impiannya, dan selalu seru bareng terus. Nikmatin musik favoritmu di Zunify v3.0!',
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 13.5,
                        height: 1.48,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      '— Fannz & Zunify',
                      style: TextStyle(
                        color: theme.accentText,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
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
                            borderRadius:
                                BorderRadius.circular(isBrutal ? 12 : 16),
                            border: isBrutal
                                ? Border.all(
                                    color: theme.brutalBorderColor,
                                    width: 1.8,
                                  )
                                : null,
                          ),
                          child: const Text(
                            'Aamiin, Lanjut Dengerin Musik 🎧',
                            style: TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
