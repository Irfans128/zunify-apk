import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../providers/theme_provider.dart';
import 'liquid_background_widget.dart';

/// Minimalist, Theme-Adaptive QRIS Donation Bottom Sheet (Liquid Glass & Neo-Brutalism)
void showQrisDonationSheet(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _QrisDonationSheet(),
  );
}

class _QrisDonationSheet extends StatefulWidget {
  const _QrisDonationSheet();

  @override
  State<_QrisDonationSheet> createState() => _QrisDonationSheetState();
}

class _QrisDonationSheetState extends State<_QrisDonationSheet> {
  static const MethodChannel _channel = MethodChannel(
    'com.fannz.zunify/equalizer',
  );
  static const String _fullQrisAsset = 'assets/images/qris_fannz_full.jpg';
  static const String _squareQrAsset = 'assets/images/qris_fannz_qr.png';

  bool _isSaving = false;

  Future<void> _saveQrisToGallery() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final data = await rootBundle.load(_fullQrisAsset);
      final bytes = data.buffer.asUint8List();
      final ok = await _channel.invokeMethod<bool>('saveImageToGallery', {
        'bytes': bytes,
        'fileName': 'QRIS_7FANNZ_STORE.jpg',
      });
      if (!mounted) return;
      final accent = context.read<ThemeProvider>().accentColor;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: ok == true ? accent : Colors.redAccent,
          content: Text(
            ok == true
                ? 'Gambar QRIS berhasil disimpan ke Galeri!'
                : 'Gagal menyimpan gambar QRIS.',
            style: TextStyle(
              color: ok == true ? const Color(0xFF111111) : Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      );
    } catch (_) {
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _shareQrisImage() async {
    try {
      final data = await rootBundle.load(_fullQrisAsset);
      final tempDir = await getTemporaryDirectory();
      final file = File('${tempDir.path}/QRIS_7FANNZ_STORE.jpg');
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Donasi QRIS Zunify — 7FANNZ STORE',
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = theme.accentColor;
    final isBrutal = theme.isNeoBrutalism;

    return ZunifySheetContainer(
      blurSigma: 34,
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: theme.dividerColor,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 14),

            // Minimalist Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    LiquidGlassBox(
                      width: 36,
                      height: 36,
                      borderRadius: 11,
                      tintColor: accent,
                      tintOpacity: isBrutal ? 0.28 : 0.22,
                      rimIntensity: 0.46,
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.favorite_rounded,
                        color: isBrutal ? const Color(0xFF111111) : accent,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Donasi QRIS',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        Text(
                          'Dukung pengembangan Zunify',
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IosGlassIconButton(
                  icon: Icons.close_rounded,
                  size: 32,
                  iconSize: 17,
                  onTap: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Minimalist Theme-Matched QRIS Card
            LiquidGlassBox(
              width: double.infinity,
              borderRadius: isBrutal ? 15 : 22,
              tintColor: accent,
              tintOpacity: isBrutal ? 0.0 : 0.09,
              rimIntensity: 0.44,
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '7FANNZ STORE',
                            style: TextStyle(
                              color: theme.textPrimary,
                              fontSize: 14.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 1.5),
                          Text(
                            'NMID: ID1026599848318',
                            style: TextStyle(
                              color: theme.textMuted,
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isBrutal ? accent : accent.withOpacity(0.20),
                          borderRadius: BorderRadius.circular(isBrutal ? 7 : 9),
                          border: isBrutal
                              ? Border.all(
                                  color: theme.brutalBorderColor,
                                  width: 1.5,
                                )
                              : Border.all(
                                  color: accent.withOpacity(0.45),
                                  width: 0.9,
                                ),
                        ),
                        child: Text(
                          'QRIS',
                          style: TextStyle(
                            color: isBrutal ? const Color(0xFF111111) : accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Crisp Scan-Safe White QR Frame
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(isBrutal ? 12 : 18),
                      border: isBrutal
                          ? Border.all(
                              color: theme.brutalBorderColor,
                              width: 2.2,
                            )
                          : Border.all(
                              color: Colors.white.withOpacity(0.85),
                              width: 1.2,
                            ),
                      boxShadow: isBrutal
                          ? [
                              BoxShadow(
                                color: theme.brutalShadowColor,
                                blurRadius: 0,
                                offset: const Offset(3.5, 3.5),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.24),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isBrutal ? 6 : 10),
                      child: Image.asset(
                        _squareQrAsset,
                        width: 204,
                        height: 204,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                  ),
                  const SizedBox(height: 13),
                  Text(
                    'Mendukung semua e-Wallet & m-Banking',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Minimalist Action Row: Simpan QRIS + Bagikan
            Row(
              children: [
                Expanded(
                  child: IosSpringButton(
                    onTap: _isSaving ? null : _saveQrisToGallery,
                    child: Container(
                      height: 46,
                      alignment: Alignment.center,
                      decoration: isBrutal
                          ? BoxDecoration(
                              color: accent,
                              borderRadius: BorderRadius.circular(11),
                              border: Border.all(
                                color: theme.brutalBorderColor,
                                width: 2.2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: theme.brutalShadowColor,
                                  blurRadius: 0,
                                  offset: const Offset(3, 3),
                                ),
                              ],
                            )
                          : BoxDecoration(
                              borderRadius: BorderRadius.circular(15),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  Color.lerp(accent, Colors.white, 0.22)!,
                                  accent,
                                ],
                              ),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.38),
                                width: 1.1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: accent.withOpacity(0.36),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.download_rounded,
                            size: 19,
                            color: Color(0xFF0B0E17),
                          ),
                          const SizedBox(width: 7),
                          Text(
                            _isSaving ? 'Menyimpan...' : 'Simpan QRIS',
                            style: const TextStyle(
                              color: Color(0xFF0B0E17),
                              fontSize: 13.5,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IosGlassIconButton(
                  icon: Icons.share_rounded,
                  size: 46,
                  iconSize: 20,
                  tooltip: 'Bagikan QRIS',
                  onTap: _shareQrisImage,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
