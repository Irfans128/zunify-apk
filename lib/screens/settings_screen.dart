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
              : BorderSide(color: Colors.white.withOpacity(0.10)),
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
    );
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
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 176),
          children: [
            Text(
              'Pengaturan',
              style: GoogleFonts.plusJakartaSans(
                color: theme.textPrimary,
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

            // 2. 2-Theme Selector: Liquid Glass vs Neo-Brutalism
            _sectionLabel('Tema Aplikasi', theme),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildLiquidGlassThemePreviewCard(
                    selected: !theme.isNeoBrutalism,
                    accent: accent,
                    onTap: () => theme.setUiThemeMode('liquid_glass'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildNeoBrutalismThemePreviewCard(
                    selected: theme.isNeoBrutalism,
                    onTap: () => theme.setUiThemeMode('neo_brutalism'),
                  ),
                ),
              ],
            ),
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
                    icon: Icons.system_update_rounded,
                    iconBg: const Color(0xFF3B82F6),
                    title: 'Cek Update',
                    valueText: 'v$kAppVersion',
                    theme: theme,
                    onTap: () => runManualUpdateCheck(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // 5. Creator Footer (Only place with Crafted with ❤️ by Fannz)
            LiquidGlassBox(
              borderRadius: 22,
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              tintOpacity: 0.07,
              rimIntensity: 0.32,
              child: Row(
                children: [
                  Container(
                    decoration: isBrutal
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: theme.brutalBorderColor,
                              width: 1.8,
                            ),
                          )
                        : null,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(isBrutal ? 10.2 : 14),
                      child: Image.asset(
                        'assets/images/zunify_logo.png',
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
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
                              'Zunify',
                              style: TextStyle(
                                color: theme.textPrimary,
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
                                color: isBrutal
                                    ? accent
                                    : accent.withOpacity(0.18),
                                borderRadius: BorderRadius.circular(6),
                                border: isBrutal
                                    ? Border.all(
                                        color: theme.brutalBorderColor,
                                        width: 1.4,
                                      )
                                    : null,
                              ),
                              child: Text(
                                'v$kAppVersion',
                                style: TextStyle(
                                  color: isBrutal
                                      ? const Color(0xFF111111)
                                      : accent,
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
                            color: theme.accentText,
                            fontWeight: FontWeight.w800,
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

  /// Visual Preview Card for iOS Liquid Glass Theme
  Widget _buildLiquidGlassThemePreviewCard({
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
  }) {
    const glassAccent = Color(0xFF5EEAD4);
    return IosSpringButton(
      onTap: onTap,
      borderRadius: 20,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A2238),
              Color(0xFF0D111E),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? glassAccent
                : Colors.white.withOpacity(0.22),
            width: selected ? 2.0 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: selected
                  ? glassAccent.withOpacity(0.26)
                  : Colors.black.withOpacity(0.18),
              blurRadius: selected ? 18 : 10,
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
                    gradient: LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.24),
                        glassAccent.withOpacity(0.28),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.blur_on_rounded,
                    size: 19,
                    color: Colors.white,
                  ),
                ),
                if (selected)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: glassAccent,
                    size: 20,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Liquid Glass',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Transparan & Blur',
              style: TextStyle(
                color: selected ? glassAccent : Colors.white60,
                fontWeight: FontWeight.w600,
                fontSize: 11.2,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Authentic Visual Preview Card for Neo-Brutalism Theme (Cream Paper + Mustard + Solid Black Border & Hard Shadow)
  Widget _buildNeoBrutalismThemePreviewCard({
    required bool selected,
    required VoidCallback onTap,
  }) {
    const brutalCream = Color(0xFFFAF4E6);
    const brutalMustard = Color(0xFFFAAE2B);
    const brutalInk = Color(0xFF111111);

    return IosSpringButton(
      onTap: onTap,
      borderRadius: 13,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: brutalCream,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: brutalInk,
            width: selected ? 2.6 : 2.2,
          ),
          boxShadow: [
            BoxShadow(
              color: brutalInk,
              blurRadius: 0,
              offset: Offset(selected ? 4.5 : 3.2, selected ? 4.5 : 3.2),
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
                    color: brutalMustard,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: brutalInk, width: 1.8),
                  ),
                  child: const Icon(
                    Icons.bolt_rounded,
                    size: 19,
                    color: brutalInk,
                  ),
                ),
                if (selected)
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: brutalMustard,
                      shape: BoxShape.circle,
                      border: Border.all(color: brutalInk, width: 1.6),
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: brutalInk,
                      size: 13,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'Neo-Brutalism',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: brutalInk,
                fontWeight: FontWeight.w900,
                fontSize: 14.5,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Krem & Garis Tegas',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: brutalInk.withOpacity(0.72),
                fontWeight: FontWeight.w700,
                fontSize: 11.2,
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
