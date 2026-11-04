import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';

class SleepTimerSheet extends StatelessWidget {
  const SleepTimerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final theme = context.watch<ThemeProvider>();
    final accent = theme.accentColor;

    final options = <Map<String, dynamic>>[
      {'label': '15 Menit', 'mins': 15, 'icon': Icons.bedtime_outlined},
      {'label': '30 Menit', 'mins': 30, 'icon': Icons.nightlight_round},
      {'label': '45 Menit', 'mins': 45, 'icon': Icons.dark_mode_outlined},
      {'label': '60 Menit (1 Jam)', 'mins': 60, 'icon': Icons.hotel_rounded},
    ];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
      decoration: BoxDecoration(
        color: theme.cardBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.timer_outlined, color: accent, size: 24),
              const SizedBox(width: 10),
              const Text(
                'Sleep Timer (Pengatur Waktu Tidur)',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Musik otomatis berhenti agar baterai HP lu tetap awet sampai pagi.',
            style: TextStyle(color: Colors.white60, fontSize: 12.5),
          ),
          const SizedBox(height: 16),

          if (player.hasActiveSleepTimer)
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: accent.withOpacity(0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withOpacity(0.4)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    player.stopAfterCurrentSong
                        ? 'Aktif: Berhenti setelah lagu ini selesai'
                        : 'Aktif: Sisa ${player.remainingSleepTime?.inMinutes ?? 0} menit lagi',
                    style: TextStyle(
                      color: accent,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  TextButton(
                    onPressed: () => player.cancelSleepTimer(),
                    child: const Text(
                      'Matikan',
                      style: TextStyle(color: Colors.redAccent),
                    ),
                  ),
                ],
              ),
            ),

          ...options.map((opt) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 6),
              leading: Icon(opt['icon'] as IconData, color: accent),
              title: Text(
                opt['label'] as String,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
              ),
              onTap: () {
                player.setSleepTimerDuration(Duration(minutes: opt['mins'] as int));
                Navigator.pop(context);
              },
            );
          }),

          ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 6),
            leading: Icon(Icons.music_off_rounded, color: theme.secondaryAccentColor),
            title: const Text(
              'Selesai Lagu Ini',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
            subtitle: const Text(
              'Stop otomatis tepat saat lagu yang diputar habis',
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            onTap: () {
              player.setSleepTimerEndOfTrack();
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }
}
