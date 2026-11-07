import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import 'liquid_background_widget.dart';

class SleepTimerSheet extends StatelessWidget {
  const SleepTimerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final theme = context.watch<ThemeProvider>();
    final accent = theme.accentColor;

    final options = <Map<String, dynamic>>[
      {'label': '15 Menit', 'mins': 15},
      {'label': '30 Menit', 'mins': 30},
      {'label': '45 Menit', 'mins': 45},
      {'label': '60 Menit', 'mins': 60},
    ];

    return ZunifySheetContainer(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: theme.dividerColor,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Icon(
                  Icons.bedtime_rounded,
                  color: theme.accentText,
                  size: 22,
                ),
                const SizedBox(width: 8),
                Text(
                  'Timer Tidur',
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            if (player.hasActiveSleepTimer)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: accent.withOpacity(theme.isLightCanvas ? 0.30 : 0.16),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: theme.isNeoBrutalism
                        ? theme.brutalBorderColor
                        : accent.withOpacity(0.45),
                    width: theme.isNeoBrutalism ? 1.8 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        player.stopAfterCurrentSong
                            ? 'Berhenti di akhir lagu ini'
                            : 'Sisa ${player.remainingSleepTime?.inMinutes ?? 0} menit',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    IosSpringButton(
                      onTap: () => player.cancelSleepTimer(),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        child: Text(
                          'Matikan',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                mainAxisExtent: 46,
              ),
              itemBuilder: (context, i) {
                final opt = options[i];
                return LiquidGlassBox(
                  borderRadius: 14,
                  tintOpacity: 0.08,
                  rimIntensity: 0.32,
                  alignment: Alignment.center,
                  onTap: () {
                    player.setSleepTimerDuration(
                      Duration(minutes: opt['mins'] as int),
                    );
                    Navigator.pop(context);
                  },
                  child: Text(
                    opt['label'] as String,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.5,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            LiquidGlassBox(
              height: 46,
              width: double.infinity,
              borderRadius: 14,
              tintColor: accent,
              tintOpacity: 0.16,
              rimIntensity: 0.40,
              alignment: Alignment.center,
              onTap: () {
                player.setSleepTimerEndOfTrack();
                Navigator.pop(context);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.music_off_rounded,
                    size: 18,
                    color: theme.textPrimary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Berhenti di Akhir Lagu Ini',
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w800,
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
}
