import 'dart:ui' show FontFeature;
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
    final isBrutal = theme.isNeoBrutalism;

    const options = <Map<String, dynamic>>[
      {'label': '5 Menit', 'mins': 5},
      {'label': '10 Menit', 'mins': 10},
      {'label': '15 Menit', 'mins': 15},
      {'label': '30 Menit', 'mins': 30},
      {'label': '45 Menit', 'mins': 45},
      {'label': '60 Menit', 'mins': 60},
    ];

    return ZunifySheetContainer(
      blurSigma: 32,
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
                LiquidGlassBox(
                  width: 38,
                  height: 38,
                  borderRadius: 12,
                  tintColor: accent,
                  tintOpacity: isBrutal ? 0.25 : 0.20,
                  rimIntensity: 0.45,
                  alignment: Alignment.center,
                  child: Icon(
                    Icons.bedtime_rounded,
                    color: isBrutal ? const Color(0xFF111111) : accent,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Timer Tidur',
                        style: TextStyle(
                          color: theme.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.2,
                        ),
                      ),
                      Text(
                        'Musik meredup & berhenti otomatis',
                        style: TextStyle(
                          color: theme.textMuted,
                          fontSize: 11.8,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            if (player.hasActiveSleepTimer)
              Padding(
                padding: const EdgeInsets.only(bottom: 14),
                child: LiquidGlassBox(
                  borderRadius: 16,
                  tintColor: accent,
                  tintOpacity: isBrutal ? 0.22 : 0.18,
                  rimIntensity: 0.48,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 11,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.timer_outlined,
                        color: theme.accentText,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              player.stopAfterCurrentSong
                                  ? 'Berhenti di akhir lagu ini'
                                  : 'Sisa waktu aktif',
                              style: TextStyle(
                                color: theme.textSecondary,
                                fontWeight: FontWeight.w700,
                                fontSize: 11.5,
                              ),
                            ),
                            if (!player.stopAfterCurrentSong)
                              Text(
                                player.formattedRemainingSleepTime,
                                style: TextStyle(
                                  color: theme.textPrimary,
                                  fontWeight: FontWeight.w900,
                                  fontSize: 19,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!player.stopAfterCurrentSong) ...[
                        IosSpringButton(
                          onTap: () => player.addSleepTimerMinutes(5),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isBrutal
                                  ? theme.cardBgColor
                                  : Colors.white.withOpacity(0.10),
                              borderRadius: BorderRadius.circular(
                                isBrutal ? 8 : 10,
                              ),
                              border: Border.all(
                                color: isBrutal
                                    ? theme.brutalBorderColor
                                    : Colors.white.withOpacity(0.22),
                                width: isBrutal ? 1.5 : 0.9,
                              ),
                            ),
                            child: Text(
                              '+5m',
                              style: TextStyle(
                                color: theme.textPrimary,
                                fontWeight: FontWeight.w800,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      IosSpringButton(
                        onTap: () => player.cancelSleepTimer(),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 11,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.redAccent.withOpacity(
                              isBrutal ? 0.18 : 0.16,
                            ),
                            borderRadius: BorderRadius.circular(
                              isBrutal ? 8 : 10,
                            ),
                            border: Border.all(
                              color: isBrutal
                                  ? theme.brutalBorderColor
                                  : Colors.redAccent.withOpacity(0.45),
                              width: isBrutal ? 1.5 : 0.9,
                            ),
                          ),
                          child: const Text(
                            'Matikan',
                            style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w800,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: options.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 9,
                crossAxisSpacing: 9,
                mainAxisExtent: 46,
              ),
              itemBuilder: (context, i) {
                final opt = options[i];
                final mins = opt['mins'] as int;
                return LiquidGlassBox(
                  borderRadius: 14,
                  tintColor: accent,
                  tintOpacity: 0.08,
                  rimIntensity: 0.36,
                  alignment: Alignment.center,
                  onTap: () {
                    player.setSleepTimerDuration(Duration(minutes: mins));
                    Navigator.pop(context);
                  },
                  child: Text(
                    opt['label'] as String,
                    style: TextStyle(
                      color: theme.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 13.0,
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
              tintOpacity: isBrutal ? 0.22 : 0.16,
              rimIntensity: 0.44,
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
                    color: player.stopAfterCurrentSong
                        ? theme.accentText
                        : theme.textPrimary,
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
