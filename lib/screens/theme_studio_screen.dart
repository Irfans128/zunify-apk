import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/liquid_background_widget.dart';

/// Dedicated Full-Screen "Studio Tema" for Zunify v3.0.0.
/// Displays 3 full-width visual theme showcases (zero horizontal cut-off)
/// plus Dark/OLED switch and Accent color customization.
class ThemeStudioScreen extends StatelessWidget {
  const ThemeStudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = theme.accentColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBgColor,
      body: LiquidBackgroundWidget(
        primaryColor: theme.playerAmbientColor,
        secondaryColor: theme.secondaryAccentColor,
        baseColor: theme.scaffoldBgColor,
        intensity: 0.36,
        child: SafeArea(
          child: Column(
            children: [
              // Clean Editorial Top Header
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
                child: Row(
                  children: [
                    IosGlassIconButton(
                      icon: Icons.arrow_back_rounded,
                      size: 40,
                      iconSize: 20,
                      onTap: () => Navigator.pop(context),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Studio Tema',
                            style: GoogleFonts.plusJakartaSans(
                              color: theme.textPrimary,
                              fontSize: 21,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.4,
                            ),
                          ),
                          Text(
                            'Pilih identitas visual Zunify v3.0',
                            style: TextStyle(
                              color: theme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: ListView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(18, 8, 18, 36),
                  children: [
                    // 1. LIQUID GLASS FULL-WIDTH SHOWCASE
                    _buildThemeShowcaseCard(
                      selected: !theme.isNeoBrutalism && !theme.isClassicIpod,
                      title: 'Liquid Glass',
                      subtitle:
                          'Kaca transparan sinematik, gradasi warna sampul & lirik blur lembut ala Apple Music.',
                      badge: 'SINEMATIK',
                      accentColor: const Color(0xFF38BDF8),
                      cardBgGradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF131C34), Color(0xFF0A0E1A)],
                      ),
                      textColor: Colors.white,
                      subColor: Colors.white70,
                      borderColor: !theme.isNeoBrutalism && !theme.isClassicIpod
                          ? const Color(0xFF38BDF8)
                          : Colors.white24,
                      mockup: _liquidGlassMiniMockup(),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        theme.setUiThemeMode('liquid_glass');
                      },
                    ),
                    const SizedBox(height: 14),

                    // 2. NEO-BRUTALISM FULL-WIDTH SHOWCASE
                    _buildThemeShowcaseCard(
                      selected: theme.isNeoBrutalism,
                      title: 'Neo-Brutalism',
                      subtitle:
                          'Gaya editorial krem hangat dengan kontras tinggi, daftar lagu lega & tombol tegas.',
                      badge: 'EDITORIAL',
                      accentColor: const Color(0xFFFAAE2B),
                      cardBgGradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFFFAF4E6), Color(0xFFF3E8D0)],
                      ),
                      textColor: const Color(0xFF111111),
                      subColor: const Color(0xFF3F3D38),
                      borderColor: const Color(0xFF111111),
                      hardShadow: true,
                      mockup: _neoBrutalMiniMockup(),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        theme.setUiThemeMode('neo_brutalism');
                      },
                    ),
                    const SizedBox(height: 14),

                    // 3. CLASSIC IPOD FULL-WIDTH SHOWCASE
                    _buildThemeShowcaseCard(
                      selected: theme.isClassicIpod,
                      title: 'Classic iPod',
                      subtitle:
                          'Bodi metalik iPod Gen 6, layar Cover Flow 3D, Click Wheel putar & lirik putih gaya Brat.',
                      badge: 'BARU • RETRO',
                      accentColor: const Color(0xFF2563EB),
                      cardBgGradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFF4F6F9), Color(0xFFDDE2E8)],
                      ),
                      textColor: const Color(0xFF0F172A),
                      subColor: const Color(0xFF475569),
                      borderColor: theme.isClassicIpod
                          ? const Color(0xFF2563EB)
                          : const Color(0xFFCBD5E1),
                      mockup: _classicIpodMiniMockup(),
                      onTap: () {
                        HapticFeedback.mediumImpact();
                        theme.setUiThemeMode('classic_ipod');
                      },
                    ),

                    const SizedBox(height: 24),
                    Text(
                      'PENGATURAN WARNA & KONTRAST',
                      style: TextStyle(
                        color: theme.textMuted,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.9,
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Dark / OLED Switch + Dynamic Color
                    LiquidGlassBox(
                      borderRadius: 18,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeColor: accent,
                            title: Text(
                              theme.isClassicIpod
                                  ? 'Edisi Hitam Matte (iPod Black)'
                                  : (theme.isNeoBrutalism
                                      ? 'Mode Gelap Neo-Brutalism'
                                      : 'Hitam Pekat AMOLED'),
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'Ubah kanvas dasar menjadi gelap pekat',
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 11.5,
                              ),
                            ),
                            value: theme.oledPureBlack,
                            onChanged: (v) => theme.setOledPureBlack(v),
                          ),
                          Divider(color: theme.dividerColor, height: 1),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            activeColor: accent,
                            title: Text(
                              'Warna Dinamis dari Sampul Lagu',
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            subtitle: Text(
                              'Aksen otomatis mengikuti palet cover album aktif',
                              style: TextStyle(
                                color: theme.textMuted,
                                fontSize: 11.5,
                              ),
                            ),
                            value: theme.dynamicFullAccentEnabled,
                            onChanged: (v) =>
                                theme.setDynamicFullAccentEnabled(v),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),
                    // Accent Swatches
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: ThemeProvider.accentPresets.map((preset) {
                        final isSel = !theme.dynamicFullAccentEnabled &&
                            theme.selectedPresetId == preset.id;
                        return GestureDetector(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            theme.setAccentPreset(preset.id);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: isSel
                                  ? preset.primary.withOpacity(0.18)
                                  : theme.cardBgColor,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isSel
                                    ? preset.primary
                                    : theme.dividerColor,
                                width: isSel ? 1.8 : 1.0,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 14,
                                  height: 14,
                                  decoration: BoxDecoration(
                                    color: preset.primary,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Text(
                                  preset.name,
                                  style: TextStyle(
                                    color: theme.textPrimary,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
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

  Widget _buildThemeShowcaseCard({
    required bool selected,
    required String title,
    required String subtitle,
    required String badge,
    required Color accentColor,
    required Gradient cardBgGradient,
    required Color textColor,
    required Color subColor,
    required Color borderColor,
    required Widget mockup,
    required VoidCallback onTap,
    bool hardShadow = false,
  }) {
    return IosSpringButton(
      onTap: onTap,
      scaleDown: 0.97,
      borderRadius: 20,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: cardBgGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? accentColor : borderColor,
            width: selected ? 2.4 : (hardShadow ? 1.8 : 1.1),
          ),
          boxShadow: [
            if (hardShadow)
              BoxShadow(
                color: const Color(0xFF111111),
                blurRadius: 0,
                offset: Offset(selected ? 4 : 2.5, selected ? 4 : 2.5),
              )
            else
              BoxShadow(
                color: (selected ? accentColor : Colors.black).withOpacity(
                  selected ? 0.24 : 0.16,
                ),
                blurRadius: selected ? 20 : 12,
                offset: const Offset(0, 6),
              ),
          ],
        ),
        child: Row(
          children: [
            mockup,
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: accentColor.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            color: hardShadow ? const Color(0xFF111111) : accentColor,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.4,
                          ),
                        ),
                      ),
                      const Spacer(),
                      if (selected)
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: accentColor,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.check_rounded,
                            color: hardShadow
                                ? const Color(0xFF111111)
                                : Colors.white,
                            size: 15,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: subColor,
                      fontSize: 12,
                      height: 1.38,
                      fontWeight: FontWeight.w500,
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

  Widget _liquidGlassMiniMockup() {
    return Container(
      width: 72,
      height: 102,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF38BDF8), Color(0xFF1E1B4B)],
        ),
        border: Border.all(color: Colors.white30, width: 1),
      ),
      child: Column(
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.22),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.album_rounded, color: Colors.white, size: 22),
            ),
          ),
          const Spacer(),
          Container(
            height: 5,
            width: 44,
            decoration: BoxDecoration(
              color: Colors.white70,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.skip_previous, color: Colors.white70, size: 13),
              const SizedBox(width: 4),
              Container(
                width: 20,
                height: 20,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Color(0xFF0F172A),
                  size: 14,
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.skip_next, color: Colors.white70, size: 13),
            ],
          ),
        ],
      ),
    );
  }

  Widget _neoBrutalMiniMockup() {
    return Container(
      width: 72,
      height: 102,
      padding: const EdgeInsets.all(7),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFDF8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF111111), width: 1.8),
        boxShadow: const [
          BoxShadow(color: Color(0xFF111111), offset: Offset(2.5, 2.5)),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: const Color(0xFFFAAE2B),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: const Color(0xFF111111), width: 1.5),
            ),
            child: const Center(
              child: Icon(
                Icons.music_note_rounded,
                color: Color(0xFF111111),
                size: 22,
              ),
            ),
          ),
          const Spacer(),
          Container(
            height: 5,
            width: 46,
            color: const Color(0xFF111111),
          ),
          const SizedBox(height: 7),
          Container(
            height: 18,
            decoration: BoxDecoration(
              color: const Color(0xFF111111),
              borderRadius: BorderRadius.circular(5),
            ),
            child: const Center(
              child: Icon(Icons.play_arrow, color: Color(0xFFFAAE2B), size: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _classicIpodMiniMockup() {
    return Container(
      width: 72,
      height: 102,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFECEFF4), Color(0xFFCFD6DF)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF94A3B8), width: 1.3),
      ),
      child: Column(
        children: [
          // Mini LCD Screen
          Container(
            height: 40,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: const Color(0xFF1E293B), width: 1.5),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2563EB),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(height: 3.5, color: const Color(0xFF0F172A)),
                      const SizedBox(height: 3),
                      Container(
                        height: 2.5,
                        width: 18,
                        color: const Color(0xFF94A3B8),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Spacer(),
          // Mini Click Wheel
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF94A3B8), width: 1),
            ),
            child: Center(
              child: Container(
                width: 15,
                height: 15,
                decoration: BoxDecoration(
                  color: const Color(0xFFDDE2E8),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFF94A3B8), width: 0.8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
