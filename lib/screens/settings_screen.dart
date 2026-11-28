import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app_version.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/update_service.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/liquid_background_widget.dart';
import '../widgets/qris_donation_sheet.dart';
import '../widgets/update_sheet.dart';
import '../widgets/whats_new_v3_sheet.dart';
import 'theme_studio_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showEditProfileDialog(
    BuildContext context,
    LibraryProvider library,
    ThemeProvider theme,
    Color accent,
  ) {
    final nameCtrl = TextEditingController(text: library.profile.username);
    final isBrutal = theme.isNeoBrutalism;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: theme.sheetBgColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isBrutal ? 15 : 22),
          side: isBrutal
              ? BorderSide(color: theme.brutalBorderColor, width: 2.4)
              : BorderSide(color: theme.dividerColor),
        ),
        title: Text(
          'Ubah Nama',
          style: TextStyle(
            color: theme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: TextStyle(color: theme.textPrimary),
          decoration: InputDecoration(
            hintText: 'Nama kamu...',
            hintStyle: TextStyle(color: theme.textMuted),
            filled: true,
            fillColor: isBrutal ? theme.cardBgColor : theme.subtleFill,
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isBrutal ? 10 : 12),
              borderSide: isBrutal
                  ? BorderSide(color: theme.brutalBorderColor, width: 1.8)
                  : BorderSide(color: theme.dividerColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isBrutal ? 10 : 12),
              borderSide: BorderSide(
                color: isBrutal ? theme.brutalBorderColor : accent,
                width: isBrutal ? 2.2 : 1.4,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Batal',
              style: TextStyle(
                color: theme.textMuted,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: const Color(0xFF111111),
              elevation: 0,
              side: isBrutal
                  ? BorderSide(color: theme.brutalBorderColor, width: 2.0)
                  : BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isBrutal ? 10 : 12),
              ),
            ),
            onPressed: () {
              library.updateUserProfile(username: nameCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text(
              'Simpan',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ).whenComplete(() {
      Future.delayed(const Duration(milliseconds: 350), nameCtrl.dispose);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final library = context.watch<LibraryProvider>();
    final player = context.watch<PlayerProvider>();
    final accent = theme.accentColor;
    final isBrutal = theme.isNeoBrutalism;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 196),
          children: [
            Text(
              'KONTROL',
              style: TextStyle(
                color: theme.accentText,
                fontSize: 10.5,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.4,
              ),
            ),
            const SizedBox(height: 1),
            Text(
              'Pengaturan',
              style: GoogleFonts.plusJakartaSans(
                color: theme.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.8,
                height: 1.08,
              ),
            ),
            const SizedBox(height: 16),

            // 1. Compact Profile Card
            LiquidGlassBox(
              borderRadius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              tintOpacity: 0.08,
              rimIntensity: 0.36,
              onTap: () =>
                  _showEditProfileDialog(context, library, theme, accent),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: isBrutal
                        ? BoxDecoration(
                            color: accent,
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: theme.brutalBorderColor,
                              width: 2.0,
                            ),
                          )
                        : BoxDecoration(
                            shape: BoxShape.circle,
                            color: accent.withOpacity(0.22),
                            border: Border.all(
                              color: accent.withOpacity(0.55),
                              width: 1.2,
                            ),
                          ),
                    alignment: Alignment.center,
                    child: Text(
                      library.profile.username.isNotEmpty
                          ? library.profile.username[0].toUpperCase()
                          : 'Z',
                      style: TextStyle(
                        color: isBrutal ? const Color(0xFF111111) : accent,
                        fontSize: 19,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          library.profile.username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Ketuk untuk ubah nama',
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.edit_rounded,
                    color: theme.accentText,
                    size: 19,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 2. Prominent Entry to Dedicated Full-Screen "Studio Tema" (No cut-off horizontal strip!)
            _sectionLabel('Tampilan & Tema', theme),
            const SizedBox(height: 8),
            LiquidGlassBox(
              borderRadius: 20,
              padding: const EdgeInsets.all(14),
              tintColor: accent,
              tintOpacity: isBrutal ? 0.16 : 0.10,
              rimIntensity: 0.42,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const ThemeStudioScreen()),
                );
              },
              child: Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(isBrutal ? 0.90 : 0.20),
                      borderRadius: BorderRadius.circular(13),
                      border: isBrutal
                          ? Border.all(color: theme.brutalBorderColor, width: 1.6)
                          : null,
                    ),
                    child: Icon(
                      theme.isClassicIpod
                          ? Icons.radio_button_checked_rounded
                          : (theme.isNeoBrutalism
                              ? Icons.auto_awesome_mosaic_rounded
                              : Icons.blur_on_rounded),
                      color: isBrutal ? const Color(0xFF111111) : accent,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'Studio Tema',
                              style: GoogleFonts.plusJakartaSans(
                                color: theme.textPrimary,
                                fontSize: 15.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                theme.isClassicIpod
                                    ? 'Classic iPod'
                                    : (theme.isNeoBrutalism
                                        ? 'Neo-Brutalism'
                                        : 'Liquid Glass'),
                                style: TextStyle(
                                  color: theme.accentText,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Liquid Glass • Neo-Brutalism • Classic iPod & Warna',
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
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: theme.textMuted,
                    size: 16,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 2b. Built-In Native Zunify Launcher Card (Default OFF, Toggle + Live Preview)
            const _ZunifyLauncherSettingsCard(),
            const SizedBox(height: 18),

            // 3. Direct Audio Quality Selector (Rendah, Standar, Tinggi)
            _sectionLabel('Kualitas Audio', theme),
            const SizedBox(height: 8),
            LiquidGlassBox(
              borderRadius: 22,
              padding: const EdgeInsets.all(14),
              tintOpacity: 0.08,
              rimIntensity: 0.36,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildQualityOption(
                        label: 'Rendah',
                        sub: 'Hemat Data',
                        selected: player.audioQualityTier == 'low',
                        theme: theme,
                        accent: accent,
                        onTap: () => player.setAudioQualityTier('low'),
                      ),
                      const SizedBox(width: 8),
                      _buildQualityOption(
                        label: 'Standar',
                        sub: 'Seimbang',
                        selected: player.audioQualityTier == 'standard',
                        theme: theme,
                        accent: accent,
                        onTap: () => player.setAudioQualityTier('standard'),
                      ),
                      const SizedBox(width: 8),
                      _buildQualityOption(
                        label: 'Tinggi',
                        sub: 'Jernih',
                        selected: player.audioQualityTier == 'high',
                        theme: theme,
                        accent: accent,
                        onTap: () => player.setAudioQualityTier('high'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.download_done_rounded,
                        color: theme.accentText,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Unduh lagu otomatis memakai Kualitas Tinggi',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 4. Clean Categorized Menu List
            _sectionLabel('Menu', theme),
            const SizedBox(height: 8),
            LiquidGlassBox(
              borderRadius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              tintOpacity: 0.08,
              rimIntensity: 0.36,
              child: Column(
                children: [
                  _menuTile(
                    icon: Icons.palette_rounded,
                    iconBg: const Color(0xFFEC4899),
                    title: 'Warna & Aksen',
                    valueText: theme.dynamicFullAccentEnabled
                        ? 'Ikuti Sampul'
                        : 'Manual',
                    theme: theme,
                    onTap: () => _openColorMenuSheet(context),
                  ),
                  _menuDivider(theme),
                  _menuTile(
                    icon: Icons.album_rounded,
                    iconBg: const Color(0xFF8B5CF6),
                    title: 'Pemutar & Lirik',
                    valueText: theme.playerCoverStyle == 'vinyl'
                        ? 'Vinyl'
                        : 'Sampul 3D',
                    theme: theme,
                    onTap: () => _openPlayerLyricsMenuSheet(context),
                  ),
                  _menuDivider(theme),
                  _menuTile(
                    icon: Icons.speed_rounded,
                    iconBg: const Color(0xFF06B6D4),
                    title: 'Animasi & Layar',
                    valueText: '90/120Hz',
                    theme: theme,
                    onTap: () => _openDisplayAnimationMenuSheet(context),
                  ),
                  _menuDivider(theme),
                  _menuTile(
                    icon: Icons.swap_horiz_rounded,
                    iconBg: const Color(0xFF10B981),
                    title: 'Pemutaran & Transisi',
                    valueText: player.crossfadeSeconds == 0
                        ? 'Normal'
                        : 'Crossfade ${player.crossfadeSeconds}s',
                    theme: theme,
                    onTap: () => _openPlaybackMenuSheet(context),
                  ),
                  _menuDivider(theme),
                  _menuTile(
                    icon: Icons.equalizer_rounded,
                    iconBg: const Color(0xFFF59E0B),
                    title: 'Equalizer',
                    valueText: player.eqEnabled
                        ? player.selectedEqPresetName
                        : 'Off',
                    theme: theme,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const EqualizerSheet(),
                      );
                    },
                  ),
                  _menuDivider(theme),
                  _menuTile(
                    icon: Icons.qr_code_2_rounded,
                    iconBg: const Color(0xFFF43F5E),
                    title: 'Donasi QRIS',
                    valueText: 'Dukung',
                    theme: theme,
                    onTap: () => showQrisDonationSheet(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5. Merged APK Version & Check Update Card + Pure-Text Creator Watermark
            _sectionLabel('Tentang Aplikasi', theme),
            const SizedBox(height: 8),
            LiquidGlassBox(
              borderRadius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
              tintOpacity: 0.08,
              rimIntensity: 0.36,
              onTap: () => runManualUpdateCheck(context),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    decoration: isBrutal
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(11),
                            border: Border.all(
                              color: theme.brutalBorderColor,
                              width: 1.9,
                            ),
                          )
                        : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isBrutal ? 9.1 : 14),
                      child: Image.asset(
                        'assets/images/zunify_logo.png',
                        width: 44,
                        height: 44,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Zunify',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Versi v$kAppVersion',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Padding(
                    padding: EdgeInsets.only(
                      right: isBrutal ? 3 : 0,
                      bottom: isBrutal ? 3 : 0,
                    ),
                    child: IosGlassPillButton(
                      icon: Icons.refresh_rounded,
                      label: 'Cek Update',
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      activeColor: accent,
                      isActive: true,
                      fontSize: 11.5,
                      onTap: () => runManualUpdateCheck(context),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            LiquidGlassBox(
              borderRadius: 18,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              tintColor: accent,
              tintOpacity: isBrutal ? 0.14 : 0.08,
              rimIntensity: 0.34,
              onTap: () => showWhatsNewV3Sheet(context),
              child: Row(
                children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: accent.withOpacity(isBrutal ? 0.90 : 0.18),
                      borderRadius: BorderRadius.circular(10),
                      border: isBrutal
                          ? Border.all(
                              color: theme.brutalBorderColor,
                              width: 1.5,
                            )
                          : null,
                    ),
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: isBrutal ? const Color(0xFF111111) : accent,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Apa yang Baru di v$kAppVersion',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 13.8,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          'Lihat ringkasan fitur & tema terbaru',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 11.4,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: theme.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ZunifyG Companion App Card (Ultra-Lite Gaming Edition)
            LiquidGlassBox(
              borderRadius: 20,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              tintColor: const Color(0xFF00E676),
              tintOpacity: isBrutal ? 0.14 : 0.08,
              rimIntensity: 0.36,
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF00E676).withOpacity(0.16),
                      borderRadius: BorderRadius.circular(11),
                    ),
                    child: const Icon(
                      Icons.bolt_rounded,
                      color: Color(0xFF00E676),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ZunifyG • Ultra-Lite',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 14.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Versi super ringan khusus HP kentang & gaming',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IosGlassPillButton(
                    icon: Icons.download_rounded,
                    label: 'Unduh',
                    height: 33,
                    padding: const EdgeInsets.symmetric(horizontal: 11),
                    activeColor: const Color(0xFF00E676),
                    isActive: true,
                    fontSize: 11.5,
                    onTap: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      messenger.showSnackBar(
                        const SnackBar(
                          duration: Duration(seconds: 1),
                          content: Text('Mengambil link ZunifyG...'),
                        ),
                      );
                      final info =
                          await UpdateService().fetchLatestReleaseInfo();
                      if (!context.mounted) return;
                      messenger.hideCurrentSnackBar();
                      if (info == null || !info.hasZunifyG) {
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text(
                              'ZunifyG belum tersedia atau koneksi gagal.',
                            ),
                          ),
                        );
                        return;
                      }
                      await showUpdateSheet(context, info.asZunifyGDownload());
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Pure-Text Creator Watermark (Visible, aesthetic, non-intrusive, zero external link shortcuts)
            IgnorePointer(
              child: LiquidGlassBox(
                width: double.infinity,
                borderRadius: 20,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                tintColor: accent,
                tintOpacity: isBrutal ? 0.12 : 0.07,
                rimIntensity: 0.34,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      'Create by Fannz/Irfan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.1,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 3,
                      children: [
                        Text(
                          'WA (+6283122013652)',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 11.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          '•',
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'TikTok (@fannnamikaze_)',
                          style: TextStyle(
                            color: theme.textSecondary,
                            fontSize: 11.8,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQualityOption({
    required String label,
    required String sub,
    required bool selected,
    required ThemeProvider theme,
    required Color accent,
    required VoidCallback onTap,
  }) {
    final isBrutal = theme.isNeoBrutalism;
    return Expanded(
      child: IosSpringButton(
        onTap: onTap,
        borderRadius: isBrutal ? 10 : 14,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: isBrutal
              ? BoxDecoration(
                  color: selected ? accent : theme.cardBgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.brutalBorderColor,
                    width: selected ? 2.2 : 1.7,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: theme.brutalShadowColor,
                            blurRadius: 0,
                            offset: const Offset(2.5, 2.5),
                          ),
                        ]
                      : null,
                )
              : BoxDecoration(
                  color: selected ? accent : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: selected ? accent : Colors.white12,
                    width: 1.2,
                  ),
                ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF111111)
                      : theme.textPrimary,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected
                      ? const Color(0xFF111111).withOpacity(0.74)
                      : theme.textMuted,
                  fontWeight: FontWeight.w700,
                  fontSize: 10,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _menuTile({
    required IconData icon,
    required Color iconBg,
    required String title,
    required String valueText,
    required ThemeProvider theme,
    required VoidCallback onTap,
  }) {
    final isBrutal = theme.isNeoBrutalism;
    return IosSpringButton(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: isBrutal ? iconBg : iconBg.withOpacity(0.20),
                borderRadius: BorderRadius.circular(isBrutal ? 9 : 10),
                border: isBrutal
                    ? Border.all(color: theme.brutalBorderColor, width: 1.6)
                    : null,
              ),
              child: Icon(
                icon,
                color: isBrutal ? Colors.white : iconBg,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  color: theme.textPrimary,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              valueText,
              style: TextStyle(
                color: theme.textMuted,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.textMuted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuDivider(ThemeProvider theme) {
    return Divider(
      color: theme.dividerColor,
      height: 1,
      indent: 46,
    );
  }

  void _openColorMenuSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          final accent = theme.accentColor;
          final isBrutal = theme.isNeoBrutalism;
          return ZunifySheetContainer(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetHandle(theme),
                  const SizedBox(height: 14),
                  Text(
                    'Warna & Aksen',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Ikuti Warna Sampul Lagu',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    value: theme.dynamicFullAccentEnabled,
                    activeColor: theme.accentText,
                    onChanged: (v) => theme.setDynamicFullAccentEnabled(v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Cahaya Latar Sampul',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    value: theme.dynamicAlbumColorEnabled,
                    activeColor: theme.accentText,
                    onChanged: (v) => theme.setDynamicAlbumColorEnabled(v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      isBrutal ? 'Mode Gelap Neo-Brutalism' : 'Hitam Pekat OLED',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    value: theme.oledPureBlack,
                    activeColor: theme.accentText,
                    onChanged: (v) => theme.setOledPureBlack(v),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pilihan Warna Manual',
                    style: TextStyle(
                      color: theme.textSecondary,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: ThemeProvider.accentPresets.length,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      mainAxisExtent: 48,
                    ),
                    itemBuilder: (context, idx) {
                      final preset = ThemeProvider.accentPresets[idx];
                      final selected = theme.selectedPresetId == preset.id &&
                          !theme.dynamicFullAccentEnabled;
                      return IosSpringButton(
                        onTap: () {
                          if (theme.dynamicFullAccentEnabled) {
                            theme.setDynamicFullAccentEnabled(false);
                          }
                          theme.setAccentPreset(preset.id);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10),
                          decoration: isBrutal
                              ? BoxDecoration(
                                  color: selected
                                      ? Color.lerp(
                                          theme.cardBgColor,
                                          preset.primary,
                                          0.35,
                                        )
                                      : theme.cardBgColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: theme.brutalBorderColor,
                                    width: selected ? 2.2 : 1.7,
                                  ),
                                  boxShadow: selected
                                      ? [
                                          BoxShadow(
                                            color: theme.brutalShadowColor,
                                            blurRadius: 0,
                                            offset: const Offset(2.5, 2.5),
                                          ),
                                        ]
                                      : null,
                                )
                              : BoxDecoration(
                                  color: selected
                                      ? preset.primary.withOpacity(0.22)
                                      : Colors.white.withOpacity(0.06),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: selected
                                        ? preset.primary
                                        : accent.withOpacity(0.08),
                                  ),
                                ),
                          child: Row(
                            children: [
                              Container(
                                width: 22,
                                height: 22,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [preset.primary, preset.secondary],
                                  ),
                                  border: isBrutal
                                      ? Border.all(
                                          color: theme.brutalBorderColor,
                                          width: 1.5,
                                        )
                                      : null,
                                ),
                                child: selected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 13,
                                        color: Color(0xFF111111),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  preset.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openPlayerLyricsMenuSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          final accent = theme.accentColor;
          return ZunifySheetContainer(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetHandle(theme),
                  const SizedBox(height: 14),
                  Text(
                    'Pemutar & Lirik',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sheetSubLabel('Gaya Sampul', theme),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _optionSegmentButton(
                        label: 'Sampul 3D',
                        icon: Icons.album_rounded,
                        selected: theme.playerCoverStyle != 'vinyl',
                        theme: theme,
                        accent: accent,
                        onTap: () => theme.setPlayerCoverStyle('artwork'),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Vinyl',
                        icon: Icons.radio_button_checked_rounded,
                        selected: theme.playerCoverStyle == 'vinyl',
                        theme: theme,
                        accent: accent,
                        onTap: () => theme.setPlayerCoverStyle('vinyl'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _sheetSubLabel('Tata Letak Pemutar', theme),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _optionSegmentButton(
                        label: 'Kompak',
                        selected: theme.playerSpacingMode == 'compact',
                        theme: theme,
                        accent: accent,
                        onTap: () => theme.setPlayerSpacingMode('compact'),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Seimbang',
                        selected: theme.playerSpacingMode == 'balanced',
                        theme: theme,
                        accent: accent,
                        onTap: () => theme.setPlayerSpacingMode('balanced'),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Lega',
                        selected: theme.playerSpacingMode == 'spacious',
                        theme: theme,
                        accent: accent,
                        onTap: () => theme.setPlayerSpacingMode('spacious'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _sheetSubLabel('Posisi & Ukuran Lirik', theme),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _optionSegmentButton(
                        label: 'Rata Kiri',
                        icon: Icons.format_align_left_rounded,
                        selected: !theme.lyricsCenterAligned,
                        theme: theme,
                        accent: accent,
                        onTap: () => theme.setLyricsCenterAligned(false),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Rata Tengah',
                        icon: Icons.format_align_center_rounded,
                        selected: theme.lyricsCenterAligned,
                        theme: theme,
                        accent: accent,
                        onTap: () => theme.setLyricsCenterAligned(true),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _optionSegmentButton(
                        label: 'Kecil',
                        selected: theme.lyricsFontScale < 0.95,
                        theme: theme,
                        accent: accent,
                        onTap: () => theme.setLyricsFontScale(0.90),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Normal',
                        selected: theme.lyricsFontScale >= 0.95 &&
                            theme.lyricsFontScale <= 1.07,
                        theme: theme,
                        accent: accent,
                        onTap: () => theme.setLyricsFontScale(1.0),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Besar',
                        selected: theme.lyricsFontScale > 1.07,
                        theme: theme,
                        accent: accent,
                        onTap: () => theme.setLyricsFontScale(1.14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openDisplayAnimationMenuSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          final accent = theme.accentColor;
          final isBrutal = theme.isNeoBrutalism;
          return ZunifySheetContainer(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetHandle(theme),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Animasi & Layar',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: isBrutal ? accent : accent.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(isBrutal ? 7 : 10),
                          border: isBrutal
                              ? Border.all(
                                  color: theme.brutalBorderColor,
                                  width: 1.5,
                                )
                              : null,
                        ),
                        child: Text(
                          '90 / 120Hz Aktif',
                          style: TextStyle(
                            color: isBrutal ? const Color(0xFF111111) : accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _sheetSubLabel('Kecepatan Gerakan Animasi', theme),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _optionSegmentButton(
                        label: 'Cepat',
                        selected: theme.animationSpeedMultiplier < 0.82,
                        theme: theme,
                        accent: accent,
                        onTap: () => theme.setAnimationSpeedMultiplier(0.72),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Responsif',
                        selected: theme.animationSpeedMultiplier >= 0.82 &&
                            theme.animationSpeedMultiplier <= 1.05,
                        theme: theme,
                        accent: accent,
                        onTap: () => theme.setAnimationSpeedMultiplier(0.88),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Halus',
                        selected: theme.animationSpeedMultiplier > 1.05,
                        theme: theme,
                        accent: accent,
                        onTap: () => theme.setAnimationSpeedMultiplier(1.20),
                      ),
                    ],
                  ),
                  if (!theme.isNeoBrutalism) ...[
                    const SizedBox(height: 16),
                    _sheetSubLabel('Intensitas Blur Kaca', theme),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _optionSegmentButton(
                          label: 'Ringan',
                          selected: theme.blurIntensity <= 0.50,
                          theme: theme,
                          accent: accent,
                          onTap: () => theme.setBlurIntensity(0.40),
                        ),
                        const SizedBox(width: 8),
                        _optionSegmentButton(
                          label: 'Seimbang',
                          selected: theme.blurIntensity > 0.50 &&
                              theme.blurIntensity < 0.90,
                          theme: theme,
                          accent: accent,
                          onTap: () => theme.setBlurIntensity(0.80),
                        ),
                        const SizedBox(width: 8),
                        _optionSegmentButton(
                          label: 'Maksimal',
                          selected: theme.blurIntensity >= 0.90,
                          theme: theme,
                          accent: accent,
                          onTap: () => theme.setBlurIntensity(1.0),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openPlaybackMenuSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Consumer2<PlayerProvider, ThemeProvider>(
        builder: (context, player, theme, _) {
          final accent = theme.accentColor;
          return ZunifySheetContainer(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
            child: SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetHandle(theme),
                  const SizedBox(height: 14),
                  Text(
                    'Pemutaran & Transisi',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sheetSubLabel('Crossfade Pergantian Lagu', theme),
                  const SizedBox(height: 8),
                  Row(
                    children: [0, 3, 4, 6, 8].map((sec) {
                      final selected = player.crossfadeSeconds == sec;
                      return _optionSegmentButton(
                        label: sec == 0 ? 'Off' : '${sec}s',
                        selected: selected,
                        theme: theme,
                        accent: accent,
                        onTap: () => player.setCrossfadeSeconds(sec),
                      );
                    }).expand((w) => [w, const SizedBox(width: 6)]).toList()
                      ..removeLast(),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Putar Otomatis Saat Antrean Habis',
                      style: TextStyle(
                        color: theme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    value: player.autoplayEnabled,
                    activeColor: theme.accentText,
                    onChanged: (v) => player.setAutoplayEnabled(v),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sheetHandle(ThemeProvider theme) {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: theme.dividerColor,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _sheetSubLabel(String text, ThemeProvider theme) {
    return Text(
      text,
      style: TextStyle(
        color: theme.textSecondary,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _optionSegmentButton({
    required String label,
    required bool selected,
    required ThemeProvider theme,
    required Color accent,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    final isBrutal = theme.isNeoBrutalism;
    return Expanded(
      child: IosSpringButton(
        onTap: onTap,
        borderRadius: isBrutal ? 10 : 13,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: isBrutal
              ? BoxDecoration(
                  color: selected ? accent : theme.cardBgColor,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: theme.brutalBorderColor,
                    width: selected ? 2.0 : 1.6,
                  ),
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            color: theme.brutalShadowColor,
                            blurRadius: 0,
                            offset: const Offset(2.2, 2.2),
                          ),
                        ]
                      : null,
                )
              : BoxDecoration(
                  color: selected ? accent : Colors.white.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                    color: selected ? accent : Colors.white12,
                  ),
                ),
          alignment: Alignment.center,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  size: 14,
                  color: selected
                      ? const Color(0xFF111111)
                      : theme.textSecondary,
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF111111)
                        : theme.textPrimary,
                    fontWeight: FontWeight.w800,
                    fontSize: 11.8,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionLabel(String title, ThemeProvider theme) {
    return Text(
      title,
      style: TextStyle(
        color: theme.textSecondary,
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

/// Built-in Native Zunify Launcher toggle + instant live preview card
class _ZunifyLauncherSettingsCard extends StatefulWidget {
  const _ZunifyLauncherSettingsCard();

  @override
  State<_ZunifyLauncherSettingsCard> createState() =>
      _ZunifyLauncherSettingsCardState();
}

class _ZunifyLauncherSettingsCardState
    extends State<_ZunifyLauncherSettingsCard> with WidgetsBindingObserver {
  static const MethodChannel _launcherChannel =
      MethodChannel('com.fannz.zunify/launcher');

  bool _enabled = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refreshLauncherStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _refreshLauncherStatus();
    }
  }

  Future<void> _refreshLauncherStatus() async {
    try {
      final res =
          await _launcherChannel.invokeMethod<bool>('isZunifyLauncherEnabled');
      if (mounted && res != null) {
        setState(() => _enabled = res);
      }
    } catch (_) {}
  }

  Future<void> _toggleLauncher(bool nextValue) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final res = await _launcherChannel.invokeMethod<bool>(
        'setZunifyLauncherEnabled',
        {'enabled': nextValue, 'openPicker': nextValue},
      );
      if (mounted) {
        setState(() => _enabled = res ?? nextValue);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            duration: const Duration(seconds: 2),
            content: Text(
              nextValue
                  ? 'Zunify Launcher aktif! Pilih "Zunify Launcher" sebagai Home default.'
                  : 'Zunify Launcher dimatikan. Home Screen kembali normal.',
            ),
          ),
        );
      }
    } catch (_) {} finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openPreview() async {
    try {
      await _launcherChannel.invokeMethod('openZunifyLauncherPreview');
    } catch (_) {}
  }

  Future<void> _openHomePicker() async {
    try {
      await _launcherChannel.invokeMethod('openHomeSettingsPicker');
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = theme.accentColor;
    final isBrutal = theme.isNeoBrutalism;

    return LiquidGlassBox(
      borderRadius: 20,
      padding: const EdgeInsets.all(14),
      tintColor: const Color(0xFFA78BFA),
      tintOpacity: isBrutal ? 0.14 : 0.08,
      rimIntensity: 0.38,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFA78BFA)
                      .withOpacity(isBrutal ? 0.88 : 0.20),
                  borderRadius: BorderRadius.circular(13),
                  border: isBrutal
                      ? Border.all(color: theme.brutalBorderColor, width: 1.6)
                      : null,
                ),
                child: Icon(
                  Icons.dashboard_customize_rounded,
                  color: isBrutal
                      ? const Color(0xFF111111)
                      : const Color(0xFFA78BFA),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            'Zunify Launcher',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              color: theme.textPrimary,
                              fontSize: 15,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                        const SizedBox(width: 7),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: (_enabled
                                    ? const Color(0xFF10B981)
                                    : theme.textMuted)
                                .withOpacity(0.18),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _enabled ? 'Aktif' : 'Nonaktif',
                            style: TextStyle(
                              color: _enabled
                                  ? const Color(0xFF10B981)
                                  : theme.textMuted,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Home Screen Native ringan + Dynamic Capsule musik',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: theme.textSecondary,
                        fontSize: 11.4,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Switch.adaptive(
                value: _enabled,
                activeColor: accent,
                onChanged: _busy ? null : _toggleLauncher,
              ),
            ],
          ),
          const SizedBox(height: 11),
          Row(
            children: [
              Expanded(
                child: IosGlassPillButton(
                  icon: Icons.visibility_rounded,
                  label: 'Pratinjau',
                  height: 34,
                  expand: true,
                  fontSize: 11.8,
                  activeColor: accent,
                  isActive: true,
                  onTap: _openPreview,
                ),
              ),
              if (_enabled) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: IosGlassPillButton(
                    icon: Icons.home_rounded,
                    label: 'Pilih Default',
                    height: 34,
                    expand: true,
                    fontSize: 11.8,
                    onTap: _openHomePicker,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
