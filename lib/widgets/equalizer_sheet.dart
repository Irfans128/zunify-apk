import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/player_provider.dart';
import '../providers/theme_provider.dart';
import '../services/equalizer_service.dart';
import 'liquid_background_widget.dart';

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

    return ZunifySheetContainer(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
              const SizedBox(height: 14),

              // Header + Reset + Switch
              Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: player.eqEnabled
                          ? accent.withOpacity(theme.isLightCanvas ? 0.35 : 0.18)
                          : theme.subtleFill,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(
                        color: theme.isNeoBrutalism
                            ? theme.brutalBorderColor
                            : (player.eqEnabled
                                ? accent.withOpacity(0.4)
                                : theme.dividerColor),
                        width: theme.isNeoBrutalism ? 1.8 : 1.0,
                      ),
                    ),
                    child: Icon(
                      Icons.graphic_eq_rounded,
                      color: player.eqEnabled
                          ? (theme.isLightCanvas
                              ? const Color(0xFF111111)
                              : accent)
                          : theme.textMuted,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Equalizer',
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          player.eqEnabled
                              ? (activePreset != null
                                  ? activePreset.name
                                  : player.selectedEqPresetName)
                              : 'Nonaktif',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: player.eqEnabled
                                ? theme.accentText
                                : theme.textMuted,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (player.eqEnabled)
                    TextButton(
                      onPressed: () =>
                          player.selectEqPreset(EqualizerService.presets.first),
                      child: Text(
                        'Reset',
                        style: TextStyle(
                          color: theme.textSecondary,
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
                  physics: const BouncingScrollPhysics(),
                  itemCount: EqualizerService.presets.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final preset = EqualizerService.presets[index];
                    final isSelected =
                        player.selectedEqPresetName == preset.name;
                    return IosGlassPillButton(
                      label: preset.name,
                      height: 34,
                      activeColor: accent,
                      isActive: isSelected,
                      onTap: () async {
                        if (!player.eqEnabled) {
                          await player.setEqualizerEnabled(true);
                        }
                        await player.selectEqPreset(preset);
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),

              // Frequency Response Curve Visualizer
              Container(
                height: 64,
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: theme.isLightCanvas
                      ? const Color(0xFF18181B)
                      : Colors.black.withOpacity(0.28),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: theme.isNeoBrutalism
                        ? theme.brutalBorderColor
                        : Colors.white.withOpacity(0.08),
                    width: theme.isNeoBrutalism ? 2.0 : 1.0,
                  ),
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
                height: 174,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children:
                      List.generate(EqualizerService.bandLabels.length, (i) {
                    final level = player.bandLevels[i];
                    final dbValue = (level / 100).toStringAsFixed(1);
                    return Column(
                      children: [
                        Text(
                          '${level >= 0 ? '+' : ''}$dbValue',
                          style: TextStyle(
                            color: player.eqEnabled
                                ? theme.accentText
                                : theme.textMuted,
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
                                inactiveTrackColor: theme.dividerColor,
                                thumbColor: theme.textPrimary,
                                overlayColor: accent.withOpacity(0.18),
                                trackHeight: 4.5,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 7,
                                ),
                              ),
                              child: Slider(
                                value: level.toDouble().clamp(-1500, 1500),
                                min: -1500,
                                max: 1500,
                                onChanged: player.eqEnabled
                                    ? (v) => player.updateCustomBandLevel(
                                          i,
                                          v.round(),
                                        )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                        Text(
                          EqualizerService.bandLabels[i],
                          style: TextStyle(
                            color: theme.textPrimary,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          EqualizerService.bandSubLabels[i],
                          style: TextStyle(
                            color: theme.textMuted,
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),

              _buildEffectSlider(
                theme: theme,
                label: 'Bass Boost',
                value: player.bassBoostStrength,
                enabled: player.eqEnabled,
                accent: accent,
                onChanged: (v) => player.updateBassBoost(v),
              ),
              const SizedBox(height: 4),
              _buildEffectSlider(
                theme: theme,
                label: 'Efek Ruang 3D',
                value: player.virtualizerStrength,
                enabled: player.eqEnabled,
                accent: secondary,
                onChanged: (v) => player.updateVirtualizer(v),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEffectSlider({
    required ThemeProvider theme,
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
              style: TextStyle(
                color: theme.textPrimary,
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              '$pct%',
              style: TextStyle(
                color: enabled ? theme.accentText : theme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            activeTrackColor: accent,
            inactiveTrackColor: theme.dividerColor,
            thumbColor: theme.textPrimary,
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

    final refPaint = Paint()
      ..color = Colors.white.withOpacity(0.12)
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

    final activeColor = enabled ? accent : Colors.white38;
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
