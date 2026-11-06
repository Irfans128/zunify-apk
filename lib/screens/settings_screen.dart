import 'package:flutter/material.dart';
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
      body: SafeArea(
        bottom: false,
        child: ListView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 176),
          children: [
            const Text(
              'Pengaturan',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: 18),

            // Profile Card
            _glassCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: accent.withOpacity(0.2),
                  child: Text(
                    library.profile.username.isNotEmpty
                        ? library.profile.username[0].toUpperCase()
                        : 'F',
                    style: TextStyle(
                      color: accent,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                title: Text(
                  library.profile.username,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: const Text(
                  'Akun Lokal Zunify',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: IconButton(
                  icon: Icon(Icons.edit_rounded, color: accent, size: 20),
                  onPressed: () =>
                      _showEditProfileDialog(context, library, accent),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Dynamic Liquid Theme Colors
            _sectionLabel('Tema & Warna Dinamis'),
            const SizedBox(height: 10),
            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Warna Tema Otomatis Ikuti Sampul Lagu',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: const Text(
                      'Aksen UI, tombol, & lirik otomatis menyesuaikan warna sampul lagu yang diputar',
                      style: TextStyle(color: Colors.white54, fontSize: 11.8),
                    ),
                    value: theme.dynamicFullAccentEnabled,
                    activeColor: accent,
                    onChanged: (v) => theme.setDynamicFullAccentEnabled(v),
                  ),
                  const Divider(color: Colors.white12, height: 22),
                  const Text(
                    'Preset Warna Manual / Default',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: ThemeProvider.accentPresets.map((preset) {
                      final selected = !theme.dynamicFullAccentEnabled &&
                          theme.selectedPresetId == preset.id;
                      return GestureDetector(
                        onTap: () => theme.setAccentPreset(preset.id),
                        child: AnimatedContainer(
                          duration: theme.animDuration(220),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: preset.primary
                                .withOpacity(selected ? 0.22 : 0.07),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: selected ? preset.primary : Colors.white12,
                              width: selected ? 1.8 : 1,
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
                              const SizedBox(width: 8),
                              Text(
                                preset.name.replaceAll('Zunify ', ''),
                                style: TextStyle(
                                  color: selected
                                      ? preset.primary
                                      : Colors.white70,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.w500,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const Divider(color: Colors.white12, height: 24),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Dynamic Liquid Cover Glow',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Pencahayaan latar belakang sinematik dari sampul album',
                      style: TextStyle(color: Colors.white54, fontSize: 11.8),
                    ),
                    value: theme.dynamicAlbumColorEnabled,
                    activeColor: accent,
                    onChanged: (v) => theme.setDynamicAlbumColorEnabled(v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'OLED Pure Black',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Latar hitam pekat hemat baterai untuk layar AMOLED',
                      style: TextStyle(color: Colors.white54, fontSize: 11.8),
                    ),
                    value: theme.oledPureBlack,
                    activeColor: accent,
                    onChanged: (v) => theme.setOledPureBlack(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Appearance, Animation Speed, Player Spacing & Blur Controls
            _sectionLabel('Kustomisasi Tampilan & Animasi'),
            const SizedBox(height: 10),
            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Player Cover Style
                  const Text(
                    'Gaya Sampul Pemutar Utama',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Pilih tampilan sampul album 3D modern atau piringan vinyl klasik (bisa juga diketuk langsung di layar pemutar)',
                    style: TextStyle(color: Colors.white54, fontSize: 11.8),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _optionSegmentButton(
                        label: 'Sampul 3D Modern',
                        icon: Icons.album_rounded,
                        selected: theme.playerCoverStyle != 'vinyl',
                        accent: accent,
                        onTap: () => theme.setPlayerCoverStyle('artwork'),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Piringan Vinyl',
                        icon: Icons.radio_button_checked_rounded,
                        selected: theme.playerCoverStyle == 'vinyl',
                        accent: accent,
                        onTap: () => theme.setPlayerCoverStyle('vinyl'),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),

                  // 2. Animation Speed
                  const Text(
                    'Kecepatan Animasi UI & Lirik',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Atur kecepatan transisi antarmuka dan gerakan scroll lirik',
                    style: TextStyle(color: Colors.white54, fontSize: 11.8),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _optionSegmentButton(
                        label: 'Cepat',
                        selected: theme.animationSpeedMultiplier < 0.85,
                        accent: accent,
                        onTap: () => theme.setAnimationSpeedMultiplier(0.72),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Normal',
                        selected: theme.animationSpeedMultiplier >= 0.85 &&
                            theme.animationSpeedMultiplier <= 1.15,
                        accent: accent,
                        onTap: () => theme.setAnimationSpeedMultiplier(1.0),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Sinematik',
                        selected: theme.animationSpeedMultiplier > 1.15,
                        accent: accent,
                        onTap: () => theme.setAnimationSpeedMultiplier(1.38),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),

                  // 3. Player Spacing
                  const Text(
                    'Kerapatan Tata Letak Pemutar (Player Spacing)',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sesuaikan jarak antar elemen dan ukuran sampul di layar pemutar lagu',
                    style: TextStyle(color: Colors.white54, fontSize: 11.8),
                  ),
                  const SizedBox(height: 10),
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
                  const Divider(color: Colors.white12, height: 24),

                  // 4. Blur & Liquid Glass Settings
                  const Text(
                    'Intensitas Blur & Efek Kaca',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Mode Ringan menghemat baterai & GPU, Ultra Glass memberikan efek kaca buram maksimal',
                    style: TextStyle(color: Colors.white54, fontSize: 11.8),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _optionSegmentButton(
                        label: 'Ringan (Hemat)',
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
                        label: 'Ultra Glass',
                        selected: theme.blurIntensity >= 0.90,
                        accent: accent,
                        onTap: () => theme.setBlurIntensity(1.0),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 24),

                  // 5. Lyrics Alignment & Font Scale
                  const Text(
                    'Tampilan & Ukuran Lirik',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 14.5,
                    ),
                  ),
                  const SizedBox(height: 10),
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
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _optionSegmentButton(
                        label: 'Font Kompak',
                        selected: theme.lyricsFontScale < 0.95,
                        accent: accent,
                        onTap: () => theme.setLyricsFontScale(0.90),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Font Normal',
                        selected: theme.lyricsFontScale >= 0.95 &&
                            theme.lyricsFontScale <= 1.07,
                        accent: accent,
                        onTap: () => theme.setLyricsFontScale(1.0),
                      ),
                      const SizedBox(width: 8),
                      _optionSegmentButton(
                        label: 'Font Besar',
                        selected: theme.lyricsFontScale > 1.07,
                        accent: accent,
                        onTap: () => theme.setLyricsFontScale(1.14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Audio & Equalizer
            _sectionLabel('Audio & Pemutaran Pintar'),
            const SizedBox(height: 10),
            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Kualitas Audio Otomatis (Wi-Fi / Data)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      player.activeQualityLabel,
                      style: TextStyle(
                        color:
                            player.autoQualityEnabled ? accent : Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    value: player.autoQualityEnabled,
                    activeColor: accent,
                    onChanged: (v) => player.setAutoQualityEnabled(v),
                  ),
                  if (!player.autoQualityEnabled) ...[
                    const Divider(color: Colors.white12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text(
                        'Kualitas Tinggi Manual (160 kbps)',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text(
                        player.highQualityAudio
                            ? 'Mode Jernih Maksimal (160 kbps)'
                            : 'Mode Hemat Kuota (96 kbps)',
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                      value: player.highQualityAudio,
                      activeColor: accent,
                      onChanged: (v) => player.setHighQualityAudio(v),
                    ),
                  ],
                  const Divider(color: Colors.white12),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Crossfade Transisi Lagu Mulus',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              player.crossfadeSeconds == 0
                                  ? 'Nonaktif'
                                  : '${player.crossfadeSeconds} Detik',
                              style: TextStyle(
                                color: player.crossfadeSeconds > 0
                                    ? accent
                                    : Colors.white54,
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Transisi volume halus saat lagu berganti otomatis',
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 10),
                        Row(
                          children: [0, 3, 4, 6, 8].map((sec) {
                            final selected = player.crossfadeSeconds == sec;
                            return Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 3),
                                child: GestureDetector(
                                  onTap: () => player.setCrossfadeSeconds(sec),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 180),
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? accent
                                          : Colors.white.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected
                                            ? accent
                                            : Colors.white12,
                                      ),
                                    ),
                                    alignment: Alignment.center,
                                    child: Text(
                                      sec == 0 ? 'Off' : '${sec}s',
                                      style: TextStyle(
                                        color: selected
                                            ? Colors.black
                                            : Colors.white70,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ],
                    ),
                  ),
                  const Divider(color: Colors.white12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Autoplay Rekomendasi Pintar',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Putar lagu serupa otomatis saat antrean habis',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    value: player.autoplayEnabled,
                    activeColor: accent,
                    onChanged: (v) => player.setAutoplayEnabled(v),
                  ),
                  const Divider(color: Colors.white12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.equalizer_rounded, color: accent),
                    title: const Text(
                      'Equalizer',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      player.eqEnabled
                          ? 'Aktif • ${player.selectedEqPresetName}'
                          : 'Nonaktif (Default)',
                      style: TextStyle(
                        color: player.eqEnabled ? accent : Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white54,
                    ),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => const EqualizerSheet(),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Aplikasi & Update
            _sectionLabel('Aplikasi & Pembaruan'),
            const SizedBox(height: 10),
            _glassCard(
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.system_update_rounded, color: accent),
                title: const Text(
                  'Cek Update Aplikasi',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                subtitle: const Text(
                  'Versi saat ini: v$kAppVersion',
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Cek',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                onTap: () => runManualUpdateCheck(context),
              ),
            ),
            const SizedBox(height: 20),

            // Clean Creator Credit Card (Fannz) with new Zunify 2.0 Logo
            _glassCard(
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      'assets/images/zunify_logo.png',
                      width: 58,
                      height: 58,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Zunify',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'v$kAppVersion • Next-Gen Audio & Lyric Engine',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Crafted with ❤️ by Fannz',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
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

  Widget _optionSegmentButton({
    required String label,
    required bool selected,
    required Color accent,
    required VoidCallback onTap,
    IconData? icon,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
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
                    fontSize: 11.5,
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
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Widget _glassCard({required Widget child}) {
    return LiquidGlassBox(
      borderRadius: 24,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      tintOpacity: 0.08,
      rimIntensity: 0.36,
      child: child,
    );
  }
}
