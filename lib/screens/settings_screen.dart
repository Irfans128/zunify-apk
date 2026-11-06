import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app_version.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/equalizer_sheet.dart';
import '../widgets/liquid_background_widget.dart';
import '../widgets/update_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showEditProfileDialog(
    BuildContext context,
    LibraryProvider library,
    Color accent,
  ) {
    final nameCtrl = TextEditingController(text: library.profile.username);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF121622),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Ubah Nama',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Nama kamu...',
            hintStyle: TextStyle(color: Colors.white38),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              library.updateUserProfile(username: nameCtrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text(
              'Simpan',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final library = context.watch<LibraryProvider>();
    final player = context.watch<PlayerProvider>();
    final accent = theme.accentColor;

    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 176),
          children: [
            Text(
              'Pengaturan',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.6,
              ),
            ),
            const SizedBox(height: 16),

            // 1. Compact Profile Card
            LiquidGlassBox(
              borderRadius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              tintOpacity: 0.08,
              rimIntensity: 0.36,
              onTap: () => _showEditProfileDialog(context, library, accent),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
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
                        color: accent,
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
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Ketuk untuk ubah nama',
                          style: TextStyle(
                            color: Colors.white54,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.edit_rounded, color: accent, size: 19),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 2. 2-Theme Selector: Liquid Glass vs Saweria
            _sectionLabel('Tema Aplikasi'),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildThemeCard(
                    title: 'Liquid Glass',
                    subtitle: 'Transparan & Blur',
                    icon: Icons.blur_on_rounded,
                    selected: !theme.isSaweriaTheme,
                    accent: accent,
                    isSaweriaPreview: false,
                    onTap: () => theme.setUiThemeMode('liquid_glass'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildThemeCard(
                    title: 'Saweria',
                    subtitle: 'Tegas & Kontras',
                    icon: Icons.bolt_rounded,
                    selected: theme.isSaweriaTheme,
                    accent: const Color(0xFFFAA61A),
                    isSaweriaPreview: true,
                    onTap: () {
                      theme.setUiThemeMode('saweria');
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // 3. Direct Audio Quality Selector (Rendah, Standar, Tinggi)
            _sectionLabel('Kualitas Audio'),
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
                        accent: accent,
                        onTap: () => player.setAudioQualityTier('low'),
                      ),
                      const SizedBox(width: 8),
                      _buildQualityOption(
                        label: 'Standar',
                        sub: 'Seimbang',
                        selected: player.audioQualityTier == 'standard',
                        accent: accent,
                        onTap: () => player.setAudioQualityTier('standard'),
                      ),
                      const SizedBox(width: 8),
                      _buildQualityOption(
                        label: 'Tinggi',
                        sub: 'Jernih',
                        selected: player.audioQualityTier == 'high',
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
                        color: accent,
                        size: 15,
                      ),
                      const SizedBox(width: 6),
                      const Expanded(
                        child: Text(
                          'Unduh lagu otomatis memakai Kualitas Tinggi',
                          style: TextStyle(
                            color: Colors.white60,
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
            _sectionLabel('Menu'),
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
                    accent: accent,
                    onTap: () => _openColorMenuSheet(context),
                  ),
                  _menuDivider(),
                  _menuTile(
                    icon: Icons.album_rounded,
                    iconBg: const Color(0xFF8B5CF6),
                    title: 'Pemutar & Lirik',
                    valueText: theme.playerCoverStyle == 'vinyl'
                        ? 'Vinyl'
                        : 'Sampul 3D',
                    accent: accent,
                    onTap: () => _openPlayerLyricsMenuSheet(context),
                  ),
                  _menuDivider(),
                  _menuTile(
                    icon: Icons.speed_rounded,
                    iconBg: const Color(0xFF06B6D4),
                    title: 'Animasi & Layar',
                    valueText: '90/120Hz',
                    accent: accent,
                    onTap: () => _openDisplayAnimationMenuSheet(context),
                  ),
                  _menuDivider(),
                  _menuTile(
                    icon: Icons.swap_horiz_rounded,
                    iconBg: const Color(0xFF10B981),
                    title: 'Pemutaran & Transisi',
                    valueText: player.crossfadeSeconds == 0
                        ? 'Normal'
                        : 'Crossfade ${player.crossfadeSeconds}s',
                    accent: accent,
                    onTap: () => _openPlaybackMenuSheet(context),
                  ),
                  _menuDivider(),
                  _menuTile(
                    icon: Icons.equalizer_rounded,
                    iconBg: const Color(0xFFF59E0B),
                    title: 'Equalizer',
                    valueText: player.eqEnabled
                        ? player.selectedEqPresetName
                        : 'Off',
                    accent: accent,
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const EqualizerSheet(),
                      );
                    },
                  ),
                  _menuDivider(),
                  _menuTile(
                    icon: Icons.system_update_rounded,
                    iconBg: const Color(0xFF3B82F6),
                    title: 'Cek Update',
                    valueText: 'v$kAppVersion',
                    accent: accent,
                    onTap: () => runManualUpdateCheck(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5. Minimalist Creator Footer (Only place with Crafted by Fannz)
            LiquidGlassBox(
              borderRadius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              tintOpacity: 0.07,
              rimIntensity: 0.32,
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/images/zunify_logo.png',
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text(
                              'Zunify',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                letterSpacing: -0.3,
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
                                'v$kAppVersion',
                                style: TextStyle(
                                  color: accent,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Crafted with ❤️ by Fannz',
                          style: TextStyle(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool selected,
    required Color accent,
    required bool isSaweriaPreview,
    required VoidCallback onTap,
  }) {
    return IosSpringButton(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSaweriaPreview
              ? (selected ? const Color(0xFF231F16) : const Color(0xFF171A24))
              : (selected
                  ? Colors.white.withOpacity(0.13)
                  : Colors.white.withOpacity(0.06)),
          borderRadius: BorderRadius.circular(isSaweriaPreview ? 16 : 20),
          border: Border.all(
            color: selected
                ? accent
                : Colors.white.withOpacity(isSaweriaPreview ? 0.28 : 0.14),
            width: isSaweriaPreview ? 2.0 : 1.3,
          ),
          boxShadow: isSaweriaPreview
              ? [
                  BoxShadow(
                    color: selected
                        ? accent.withOpacity(0.85)
                        : const Color(0xFF05070B),
                    blurRadius: 0,
                    offset: const Offset(3.5, 3.5),
                  ),
                ]
              : [
                  if (selected)
                    BoxShadow(
                      color: accent.withOpacity(0.22),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: selected
                        ? accent
                        : Colors.white.withOpacity(0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    icon,
                    size: 18,
                    color: selected ? Colors.black : Colors.white,
                  ),
                ),
                if (selected)
                  Icon(Icons.check_circle_rounded, color: accent, size: 19),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                color: selected ? accent : Colors.white54,
                fontWeight: FontWeight.w600,
                fontSize: 11.5,
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
    required Color accent,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: IosSpringButton(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          decoration: BoxDecoration(
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
                  color: selected ? Colors.black : Colors.white,
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
                      ? Colors.black.withOpacity(0.72)
                      : Colors.white54,
                  fontWeight: FontWeight.w600,
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
    required Color accent,
    required VoidCallback onTap,
  }) {
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
                color: iconBg.withOpacity(0.20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconBg, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              valueText,
              style: const TextStyle(
                color: Colors.white54,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.chevron_right_rounded,
              color: Colors.white38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _menuDivider() {
    return Divider(
      color: Colors.white.withOpacity(0.08),
      height: 1,
      indent: 46,
    );
  }

  void _openColorMenuSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101420),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          final accent = theme.accentColor;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetHandle(),
                  const SizedBox(height: 14),
                  const Text(
                    'Warna & Aksen',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Ikuti Warna Sampul Lagu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    value: theme.dynamicFullAccentEnabled,
                    activeColor: accent,
                    onChanged: (v) => theme.setDynamicFullAccentEnabled(v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Cahaya Latar Sampul',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    value: theme.dynamicAlbumColorEnabled,
                    activeColor: accent,
                    onChanged: (v) => theme.setDynamicAlbumColorEnabled(v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Hitam Pekat OLED',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    value: theme.oledPureBlack,
                    activeColor: accent,
                    onChanged: (v) => theme.setOledPureBlack(v),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Pilihan Warna',
                    style: TextStyle(
                      color: Colors.white70,
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
                          decoration: BoxDecoration(
                            color: selected
                                ? preset.primary.withOpacity(0.22)
                                : Colors.white.withOpacity(0.06),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: selected ? preset.primary : Colors.white12,
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
                                ),
                                child: selected
                                    ? const Icon(
                                        Icons.check_rounded,
                                        size: 13,
                                        color: Colors.black,
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  preset.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
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
      backgroundColor: const Color(0xFF101420),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          final accent = theme.accentColor;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetHandle(),
                  const SizedBox(height: 14),
                  const Text(
                    'Pemutar & Lirik',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sheetSubLabel('Gaya Sampul'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _optionSegmentButton(
                        label: 'Sampul 3D',
                        icon: Icons.album_rounded,
                        selected: theme.playerCoverStyle != 'vinyl',
                        accent: accent,
                        onTap: () => theme.setPlayerCoverStyle('artwork'),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Vinyl',
                        icon: Icons.radio_button_checked_rounded,
                        selected: theme.playerCoverStyle == 'vinyl',
                        accent: accent,
                        onTap: () => theme.setPlayerCoverStyle('vinyl'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _sheetSubLabel('Tata Letak Pemutar'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _optionSegmentButton(
                        label: 'Kompak',
                        selected: theme.playerSpacingMode == 'compact',
                        accent: accent,
                        onTap: () => theme.setPlayerSpacingMode('compact'),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Seimbang',
                        selected: theme.playerSpacingMode == 'balanced',
                        accent: accent,
                        onTap: () => theme.setPlayerSpacingMode('balanced'),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Lega',
                        selected: theme.playerSpacingMode == 'spacious',
                        accent: accent,
                        onTap: () => theme.setPlayerSpacingMode('spacious'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  _sheetSubLabel('Posisi & Ukuran Lirik'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _optionSegmentButton(
                        label: 'Rata Kiri',
                        icon: Icons.format_align_left_rounded,
                        selected: !theme.lyricsCenterAligned,
                        accent: accent,
                        onTap: () => theme.setLyricsCenterAligned(false),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Rata Tengah',
                        icon: Icons.format_align_center_rounded,
                        selected: theme.lyricsCenterAligned,
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
                        accent: accent,
                        onTap: () => theme.setLyricsFontScale(0.90),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Normal',
                        selected: theme.lyricsFontScale >= 0.95 &&
                            theme.lyricsFontScale <= 1.07,
                        accent: accent,
                        onTap: () => theme.setLyricsFontScale(1.0),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Besar',
                        selected: theme.lyricsFontScale > 1.07,
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
      backgroundColor: const Color(0xFF101420),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Consumer<ThemeProvider>(
        builder: (context, theme, _) {
          final accent = theme.accentColor;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetHandle(),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Animasi & Layar',
                        style: TextStyle(
                          color: Colors.white,
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
                          color: accent.withOpacity(0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '90 / 120Hz Aktif',
                          style: TextStyle(
                            color: accent,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _sheetSubLabel('Kecepatan Gerakan Animasi'),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _optionSegmentButton(
                        label: 'Cepat',
                        selected: theme.animationSpeedMultiplier < 0.82,
                        accent: accent,
                        onTap: () => theme.setAnimationSpeedMultiplier(0.72),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Responsif',
                        selected: theme.animationSpeedMultiplier >= 0.82 &&
                            theme.animationSpeedMultiplier <= 1.05,
                        accent: accent,
                        onTap: () => theme.setAnimationSpeedMultiplier(0.88),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Halus',
                        selected: theme.animationSpeedMultiplier > 1.05,
                        accent: accent,
                        onTap: () => theme.setAnimationSpeedMultiplier(1.20),
                      ),
                    ],
                  ),
                  if (!theme.isSaweriaTheme) ...[
                    const SizedBox(height: 16),
                    _sheetSubLabel('Intensitas Blur Kaca'),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _optionSegmentButton(
                          label: 'Ringan',
                          selected: theme.blurIntensity <= 0.50,
                          accent: accent,
                          onTap: () => theme.setBlurIntensity(0.40),
                        ),
                        const SizedBox(width: 8),
                        _optionSegmentButton(
                          label: 'Seimbang',
                          selected: theme.blurIntensity > 0.50 &&
                              theme.blurIntensity < 0.90,
                          accent: accent,
                          onTap: () => theme.setBlurIntensity(0.75),
                        ),
                        const SizedBox(width: 8),
                        _optionSegmentButton(
                          label: 'Maksimal',
                          selected: theme.blurIntensity >= 0.90,
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
      backgroundColor: const Color(0xFF101420),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (_) => Consumer2<PlayerProvider, ThemeProvider>(
        builder: (context, player, theme, _) {
          final accent = theme.accentColor;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 22),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sheetHandle(),
                  const SizedBox(height: 14),
                  const Text(
                    'Pemutaran & Transisi',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sheetSubLabel('Crossfade Pergantian Lagu'),
                  const SizedBox(height: 8),
                  Row(
                    children: [0, 3, 4, 6, 8].map((sec) {
                      final selected = player.crossfadeSeconds == sec;
                      return _optionSegmentButton(
                        label: sec == 0 ? 'Off' : '${sec}s',
                        selected: selected,
                        accent: accent,
                        onTap: () => player.setCrossfadeSeconds(sec),
                      );
                    }).expand((w) => [w, const SizedBox(width: 6)]).toList()
                      ..removeLast(),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Putar Otomatis Saat Antrean Habis',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    value: player.autoplayEnabled,
                    activeColor: accent,
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

  Widget _sheetHandle() {
    return Center(
      child: Container(
        width: 38,
        height: 4,
        decoration: BoxDecoration(
          color: Colors.white24,
          borderRadius: BorderRadius.circular(4),
        ),
      ),
    );
  }

  Widget _sheetSubLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _optionSegmentButton({
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Expanded(
      child: IosSpringButton(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 6),
          decoration: BoxDecoration(
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
                  color: selected ? Colors.black : Colors.white70,
                ),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.black : Colors.white70,
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

  Widget _sectionLabel(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.w700,
      ),
    );
  }
}
