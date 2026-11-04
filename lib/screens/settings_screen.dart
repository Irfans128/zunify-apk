import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_version.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/equalizer_sheet.dart';
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
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 115),
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
                  onPressed: () => _showEditProfileDialog(context, library, accent),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Dynamic Liquid Theme Colors
            _sectionLabel('Tema Dynamic Liquid'),
            const SizedBox(height: 10),
            _glassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: ThemeProvider.accentPresets.map((preset) {
                      final selected = theme.selectedPresetId == preset.id;
                      return GestureDetector(
                        onTap: () => theme.setAccentPreset(preset.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9,
                          ),
                          decoration: BoxDecoration(
                            color: preset.primary.withOpacity(selected ? 0.22 : 0.07),
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
                                  color: selected ? preset.primary : Colors.white70,
                                  fontWeight:
                                      selected ? FontWeight.bold : FontWeight.w500,
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
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    value: theme.dynamicAlbumColorEnabled,
                    activeColor: accent,
                    onChanged: (v) => theme.setDynamicAlbumColorEnabled(v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'OLED Pure Black',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    value: theme.oledPureBlack,
                    activeColor: accent,
                    onChanged: (v) => theme.setOledPureBlack(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Audio & Equalizer
            _sectionLabel('Audio'),
            const SizedBox(height: 10),
            _glassCard(
              child: Column(
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Kualitas Tinggi (160 kbps)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      player.highQualityAudio
                          ? 'Mode Jernih Maksimal'
                          : 'Mode Hemat Kuota (96 kbps)',
                      style: const TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    value: player.highQualityAudio,
                    activeColor: accent,
                    onChanged: (v) => player.setHighQualityAudio(v),
                  ),
                  const Divider(color: Colors.white12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Autoplay Rekomendasi Pintar',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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

            // Clean Creator Credit Card (Fannz)
            _glassCard(
              child: Column(
                children: [
                  const Text(
                    'Zunify',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: child,
    );
  }
}
