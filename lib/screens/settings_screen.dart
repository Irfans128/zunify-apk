import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/equalizer_sheet.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _showEditProfileDialog(BuildContext context, LibraryProvider library, Color accent) {
    final nameCtrl = TextEditingController(text: library.profile.username);
    final bioCtrl = TextEditingController(text: library.profile.bioTagline);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF131722),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: const Text(
          'Edit Akun Lokal Zunify 👤',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Nama Panggilan di Zunify',
                labelStyle: TextStyle(color: Colors.white60),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: bioCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Status / Bio Musik',
                labelStyle: TextStyle(color: Colors.white60),
              ),
            ),
          ],
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
              library.updateUserProfile(
                username: nameCtrl.text.trim(),
                bioTagline: bioCtrl.text.trim(),
              );
              Navigator.pop(ctx);
            },
            child: const Text('Simpan', style: TextStyle(fontWeight: FontWeight.bold)),
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
      backgroundColor: theme.scaffoldBgColor,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 115),
          children: [
            const Text(
              'Pengaturan ⚙️',
              style: TextStyle(
                color: Colors.white,
                fontSize: 23,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 18),

            // 1. Local Account Profile Card (No Login Required)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardBgColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: accent.withOpacity(0.35)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: accent.withOpacity(0.2),
                    child: Text(
                      library.profile.username.isNotEmpty
                          ? library.profile.username[0].toUpperCase()
                          : 'F',
                      style: TextStyle(
                        color: accent,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          library.profile.username,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          library.profile.bioTagline,
                          style: const TextStyle(color: Colors.white60, fontSize: 12.5),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Akun Lokal Zunify • Privasi 100% Aman',
                          style: TextStyle(color: accent, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.edit_rounded, color: accent),
                    onPressed: () => _showEditProfileDialog(context, library, accent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 2. UI Color Theme Picker
            _sectionTitle('🎨 Tema & Pilihan Warna UI'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardBgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pilih Warna Aksen Zunify:',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: ThemeProvider.accentPresets.map((preset) {
                      final selected = theme.selectedPresetId == preset.id;
                      return GestureDetector(
                        onTap: () => theme.setAccentPreset(preset.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: preset.primary.withOpacity(selected ? 0.22 : 0.08),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: selected ? preset.primary : Colors.white12,
                              width: selected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: preset.primary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                preset.name,
                                style: TextStyle(
                                  color: selected ? preset.primary : Colors.white70,
                                  fontWeight:
                                      selected ? FontWeight.bold : FontWeight.normal,
                                  fontSize: 12.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const Divider(color: Colors.white12, height: 26),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'OLED Pure Black Mode 🖤',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Hitam pekat untuk layar AMOLED & jauh lebih hemat baterai',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    value: theme.oledPureBlack,
                    activeColor: accent,
                    onChanged: (v) => theme.setOledPureBlack(v),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Dynamic Album Art Glow ✨',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Warna background player mengikuti warna cover lagu',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    value: theme.dynamicAlbumColorEnabled,
                    activeColor: accent,
                    onChanged: (v) => theme.setDynamicAlbumColorEnabled(v),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),

            // 3. Audio Quality Selector (Fitur F) & Hardware Equalizer
            _sectionTitle('🎧 Kualitas Audio & Hardware DSP'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.cardBgColor,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    activeColor: accent,
                    title: const Text(
                      'High Quality (160 kbps Opus/M4A)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Suara jernih & bass maksimal untuk earphone/headphone',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    value: true,
                    groupValue: player.highQualityAudio,
                    onChanged: (v) => player.setHighQualityAudio(v ?? true),
                  ),
                  RadioListTile<bool>(
                    contentPadding: EdgeInsets.zero,
                    activeColor: accent,
                    title: const Text(
                      'Hemat Kuota Data (96 kbps)',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Konsumsi kuota super irit untuk streaming & download',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    value: false,
                    groupValue: player.highQualityAudio,
                    onChanged: (v) => player.setHighQualityAudio(v ?? false),
                  ),
                  const Divider(color: Colors.white12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.equalizer_rounded, color: accent),
                    title: const Text(
                      'Buka Hardware Equalizer & Bass Boost',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Preset aktif: ${player.selectedEqPresetName}',
                      style: TextStyle(color: accent, fontSize: 12),
                    ),
                    trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white54),
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
            const SizedBox(height: 22),

            // 4. Official Creator Credit Card (Fannz)
            _sectionTitle('👑 Tentang Aplikasi & Pembuat'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(22),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    accent.withOpacity(0.22),
                    theme.cardBgColor,
                  ],
                ),
                border: Border.all(color: accent.withOpacity(0.45), width: 1.5),
              ),
              child: Column(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF07080C),
                      border: Border.all(color: accent, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withOpacity(0.35),
                          blurRadius: 18,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Z',
                      style: TextStyle(
                        color: accent,
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ZUNIFY v1.0.0',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: accent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Crafted with ❤️ by Fannz',
                      style: TextStyle(
                        color: accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Standalone Music Player • Synced Karaoke Bilingual Lyrics • Hardware DSP Equalizer • Private Vault Offline • Weekly Rapot (Minggu 18:00 WIB)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 12,
                      height: 1.45,
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

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15.5,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
