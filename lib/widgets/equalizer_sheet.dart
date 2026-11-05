import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/equalizer_service.dart';

class EqualizerSheet extends StatelessWidget {
  const EqualizerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final player = context.watch<PlayerProvider>();
    final theme = context.watch<ThemeProvider>();
    final accent = theme.accentColor;
    final secondary = theme.secondaryAccentColor;

    final activePreset = EqualizerService.presets
        .where((p) => p.name == player.selectedEqPresetName)
        .firstOrNull;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        color: theme.cardBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(color: Colors.white.withOpacity(0.09)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Header + Reset + Hardware DSP Switch
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: player.eqEnabled
                        ? accent.withOpacity(0.16)
                        : Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: player.eqEnabled
                          ? accent.withOpacity(0.35)
                          : Colors.white12,
                    ),
                  ),
                  child: Icon(
                    Icons.graphic_eq_rounded,
                    color: player.eqEnabled ? accent : Colors.white54,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Studio Audio Equalizer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        player.eqEnabled
                            ? (activePreset != null &&
                                    activePreset.subtitle.isNotEmpty
                                ? '${activePreset.name} • ${activePreset.subtitle}'
                                : 'Aktif • ${player.selectedEqPresetName}')
                            : 'Nonaktif (Bypass Suara Original)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: player.eqEnabled ? accent : Colors.white54,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (player.eqEnabled)
                  TextButton(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () =>
                        player.selectEqPreset(EqualizerService.presets.first),
                    child: const Text(
                      'Reset',
                      style: TextStyle(
                        color: Colors.white60,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Switch(
                  value: player.eqEnabled,
                  activeColor: accent,
                  onChanged: (v) => player.setEqualizerEnabled(v),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Preset Chips
            SizedBox(
              height: 36,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: EqualizerService.presets.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final preset = EqualizerService.presets[index];
                  final isSelected = player.selectedEqPresetName == preset.name;
                  return GestureDetector(
                    onTap: () async {
                      if (!player.eqEnabled) {
                        await player.setEqualizerEnabled(true);
                      }
                      await player.selectEqPreset(preset);
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? accent.withOpacity(0.22)
                            : Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: isSelected
                              ? accent
                              : Colors.white.withOpacity(0.10),
                        ),
                      ),
                      child: Text(
                        preset.name,
                        style: TextStyle(
                          color: isSelected ? accent : Colors.white70,
                          fontWeight:
                              isSelected ? FontWeight.w800 : FontWeight.w600,
                          fontSize: 12.2,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),

            // Live Cubic Bézier Frequency Response Curve Visualizer
            Container(
              height: 68,
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.28),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: CustomPaint(
                painter: _EqCurvePainter(
                  bandLevels: player.bandLevels,
                  enabled: player.eqEnabled,
                  accent: accent,
                  secondary: secondary,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // 5-Band Vertical Sliders
            SizedBox(
              height: 178,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(EqualizerService.bandLabels.length, (i) {
                  final level = player.bandLevels[i];
                  final dbValue = (level / 100).toStringAsFixed(1);
                  return Column(
                    children: [
                      Text(
                        '${level >= 0 ? '+' : ''}$dbValue',
                        style: TextStyle(
                          color: player.eqEnabled ? accent : Colors.white38,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Expanded(
                        child: RotatedBox(
                          quarterTurns: 3,
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              activeTrackColor: accent,
                              inactiveTrackColor: Colors.white12,
                              thumbColor: Colors.white,
                              overlayColor: accent.withOpacity(0.18),
                              trackHeight: 4.5,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 7.5,
                              ),
                            ),
                            child: Slider(
                              value: level.toDouble().clamp(-1500, 1500),
                              min: -1500,
                              max: 1500,
                              onChanged: player.eqEnabled
                                  ? (v) =>
                                      player.updateCustomBandLevel(i, v.round())
                                  : null,
                            ),
                          ),
                        ),
                      ),
                      Text(
                        EqualizerService.bandLabels[i],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        EqualizerService.bandSubLabels[i],
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
            const SizedBox(height: 14),

            // Bass Boost & 3D Virtualizer Sliders
            _buildEffectSlider(
              label: 'Sub-Bass Boost Pro 🔥',
              value: player.bassBoostStrength,
              enabled: player.eqEnabled,
              accent: accent,
              onChanged: (v) => player.updateBassBoost(v),
            ),
            const SizedBox(height: 6),
            _buildEffectSlider(
              label: 'Dolby 3D Spatial Virtualizer 🎧',
              value: player.virtualizerStrength,
              enabled: player.eqEnabled,
              accent: secondary,
              onChanged: (v) => player.updateVirtualizer(v),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEffectSlider({
    required String label,
    required int value,
    required bool enabled,
    required Color accent,
    required ValueChanged<int> onChanged,
  }) {
    final pct = (value / 10).round();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '$pct%',
              style: TextStyle(
                color: enabled ? accent : Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: accent,
            inactiveTrackColor: Colors.white12,
            thumbColor: Colors.white,
            overlayColor: accent.withOpacity(0.16),
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 7),
          ),
          child: Slider(
            value: value.toDouble().clamp(0, 1000),
            min: 0,
            max: 1000,
            onChanged: enabled ? (v) => onChanged(v.round()) : null,
          ),
        ),
      ],
    );
  }
}

class _EqCurvePainter extends CustomPainter {
  final List<int> bandLevels;
  final bool enabled;
  final Color accent;
  final Color secondary;

  const _EqCurvePainter({
    required this.bandLevels,
    required this.enabled,
    required this.accent,
    required this.secondary,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final midY = size.height / 2;

    // 0 dB center reference line
    final refPaint = Paint()
      ..color = Colors.white.withOpacity(0.10)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), refPaint);

    if (bandLevels.isEmpty) return;

    final points = <Offset>[];
    for (int i = 0; i < bandLevels.length; i++) {
      final x = (size.width / (bandLevels.length - 1)) * i;
      final norm = (enabled ? bandLevels[i] : 0).clamp(-1500, 1500) / 1500.0;
      final y = midY - (norm * (midY - 8));
      points.add(Offset(x, y));
    }

    final linePath = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 0; i < points.length - 1; i++) {
      final p0 = points[i];
      final p1 = points[i + 1];
      final ctrlX = (p0.dx + p1.dx) / 2;
      linePath.cubicTo(ctrlX, p0.dy, ctrlX, p1.dy, p1.dx, p1.dy);
    }

    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final activeColor = enabled ? accent : Colors.white30;
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          activeColor.withOpacity(enabled ? 0.35 : 0.08),
          secondary.withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final strokePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, strokePaint);

    final dotPaint = Paint()..color = Colors.white;
    for (final pt in points) {
      canvas.drawCircle(pt, 3.2, strokePaint);
      if (enabled) {
        canvas.drawCircle(pt, 1.8, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _EqCurvePainter oldDelegate) {
    if (oldDelegate.enabled != enabled || oldDelegate.accent != accent) {
      return true;
    }
    for (int i = 0; i < bandLevels.length; i++) {
      if (oldDelegate.bandLevels[i] != bandLevels[i]) return true;
    }
    return false;
  }
}
