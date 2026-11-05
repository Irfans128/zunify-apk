import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../app_version.dart';
import '../providers/library_provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/update_service.dart';
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

  Future<void> _showBroadcastAdminDialog(
    BuildContext context,
    Color accent,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('fannz_admin_gh_token') ?? '';
    final titleCtrl = TextEditingController(text: 'Pesan dari Fannz 🎵');
    final msgCtrl = TextEditingController();
    final tokenCtrl = TextEditingController(text: savedToken);
    bool sending = false;

    if (!context.mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF121622),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
            side: BorderSide(color: accent.withOpacity(0.35)),
          ),
          title: Row(
            children: [
              Icon(Icons.campaign_rounded, color: accent, size: 22),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Broadcast Notif Fannz',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kirim notifikasi bar HP & popup ke semua pengguna Zunify:',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: titleCtrl,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  decoration: InputDecoration(
                    labelText: 'Judul Notifikasi',
                    labelStyle: TextStyle(color: accent, fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: msgCtrl,
                  maxLines: 3,
                  style: const TextStyle(color: Colors.white, fontSize: 13.5),
                  decoration: InputDecoration(
                    labelText: 'Isi Pesan ke User',
                    hintText: 'Contoh: Halo guys, jangan lupa update ya!',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 12),
                    labelStyle: TextStyle(color: accent, fontSize: 12),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: tokenCtrl,
                  obscureText: true,
                  style: const TextStyle(color: Colors.white, fontSize: 12.5),
                  decoration: InputDecoration(
                    labelText: 'GitHub Token Admin (Simpan Sekali)',
                    hintText: 'ghp_... (khusus Fannz untuk broadcast)',
                    hintStyle: const TextStyle(color: Colors.white30, fontSize: 11.5),
                    labelStyle: const TextStyle(color: Colors.white54, fontSize: 11.5),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: accent,
                      side: BorderSide(color: accent.withOpacity(0.45)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () async {
                      final t = titleCtrl.text.trim().isEmpty
                          ? 'Pesan dari Fannz 🎵'
                          : titleCtrl.text.trim();
                      final m = msgCtrl.text.trim().isEmpty
                          ? 'Tes notifikasi Zunify dari Fannz berhasil muncul di HP kamu!'
                          : msgCtrl.text.trim();
                      await UpdateService.showSystemPushNotification(
                        id: 890,
                        title: t,
                        body: m,
                      );
                      if (ctx.mounted) {
                        ScaffoldMessenger.of(ctx).showSnackBar(
                          const SnackBar(
                            content: Text('Notifikasi tes dikirim ke bar HP ini!'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.notifications_active_rounded, size: 16),
                    label: const Text(
                      'Tes Notif di HP Ini',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: sending ? null : () => Navigator.pop(ctx),
              child: const Text('Tutup', style: TextStyle(color: Colors.white54)),
            ),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              onPressed: sending
                  ? null
                  : () async {
                      final msg = msgCtrl.text.trim();
                      final token = tokenCtrl.text.trim();
                      if (msg.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Isi pesan tidak boleh kosong'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      if (token.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Masukkan GitHub Token Admin Fannz untuk kirim ke semua user',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                        return;
                      }
                      setDialogState(() => sending = true);
                      await prefs.setString('fannz_admin_gh_token', token);
                      final ok = await UpdateService()
                          .publishBroadcastAnnouncement(
                            title: titleCtrl.text.trim(),
                            message: msg,
                            githubToken: token,
                          );
                      if (!ctx.mounted) return;
                      setDialogState(() => sending = false);
                      if (ok) {
                        Navigator.pop(ctx);
                        await UpdateService.showSystemPushNotification(
                          id: 891,
                          title: titleCtrl.text.trim(),
                          body: msg,
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Broadcast berhasil dikirim ke semua user Zunify!',
                              ),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Gagal kirim broadcast. Pastikan GitHub Token punya izin repo.',
                            ),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              icon: sending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(
                sending ? 'Mengirim...' : 'Kirim ke Semua User',
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
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
                        color: player.autoQualityEnabled ? accent : Colors.white54,
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
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
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
                                padding: const EdgeInsets.symmetric(horizontal: 3),
                                child: GestureDetector(
                                  onTap: () => player.setCrossfadeSeconds(sec),
                                  child: AnimatedContainer(
                                    duration: const Duration(milliseconds: 180),
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? accent
                                          : Colors.white.withOpacity(0.06),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: selected ? accent : Colors.white12,
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
            _sectionLabel('Aplikasi & Notifikasi'),
            const SizedBox(height: 10),
            _glassCard(
              child: Column(
                children: [
                  ListTile(
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
                      'Versi saat ini: v$kAppVersion • Notifikasi aktif',
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
                  const Divider(color: Colors.white12),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.campaign_rounded, color: accent),
                    title: const Text(
                      'Kirim Broadcast Notifikasi (Admin Fannz)',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: const Text(
                      'Kirim pengumuman & notifikasi ke semua user Zunify',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                    trailing: const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.white54,
                    ),
                    onTap: () => _showBroadcastAdminDialog(context, accent),
                  ),
                ],
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
