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

          // Header + Hardware DSP Switch
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.equalizer_rounded, color: accent, size: 26),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Equalizer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        player.eqEnabled
                            ? 'Aktif • ${player.selectedEqPresetName}'
                            : 'Nonaktif (Suara Original)',
                        style: TextStyle(
                          color: player.eqEnabled ? accent : Colors.white54,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Switch(
                value: player.eqEnabled,
                activeColor: accent,
                onChanged: (v) => player.setEqualizerEnabled(v),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Preset Chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: EqualizerService.presets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final preset = EqualizerService.presets[index];
                final isSelected = player.selectedEqPresetName == preset.name;
                return ChoiceChip(
                  label: Text(preset.name),
                  selected: isSelected,
                  selectedColor: accent.withOpacity(0.22),
                  backgroundColor: Colors.white.withOpacity(0.05),
                  labelStyle: TextStyle(
                    color: isSelected ? accent : Colors.white70,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 12.5,
                  ),
                  side: BorderSide(
                    color: isSelected ? accent : Colors.white12,
                  ),
                  onSelected: (_) async {
                    if (!player.eqEnabled) {
                      await player.setEqualizerEnabled(true);
                    }
                    await player.selectEqPreset(preset);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 22),

          // 5-Band Vertical Sliders
          SizedBox(
            height: 185,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: List.generate(EqualizerService.bandLabels.length, (i) {
                final level = player.bandLevels[i];
                final dbValue = (level / 100).toStringAsFixed(1);
                return Column(
                  children: [
                    Text(
                      '${level >= 0 ? '+' : ''}$dbValue dB',
                      style: TextStyle(
                        color: player.eqEnabled ? accent : Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Expanded(
                      child: RotatedBox(
                        quarterTurns: 3,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            activeTrackColor: accent,
                            inactiveTrackColor: Colors.white12,
                            thumbColor: accent,
                            trackHeight: 4,
                          ),
                          child: Slider(
                            value: level.toDouble().clamp(-1500, 1500),
                            min: -1500,
                            max: 1500,
                            onChanged: player.eqEnabled
                                ? (v) => player.updateCustomBandLevel(i, v.round())
                                : null,
                          ),
                        ),
                      ),
                    ),
                    Text(
                      EqualizerService.bandLabels[i],
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                );
              }),
            ),
          ),
          const SizedBox(height: 16),

          // Bass Boost & 3D Virtualizer Sliders
          _buildEffectSlider(
            label: 'Bass Boost 🔥',
            value: player.bassBoostStrength,
            enabled: player.eqEnabled,
            accent: accent,
            onChanged: (v) => player.updateBassBoost(v),
          ),
          const SizedBox(height: 8),
          _buildEffectSlider(
            label: '3D Spatial Audio / Virtualizer 🎧',
            value: player.virtualizerStrength,
            enabled: player.eqEnabled,
            accent: theme.secondaryAccentColor,
            onChanged: (v) => player.updateVirtualizer(v),
          ),
        ],
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
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              '$pct%',
              style: TextStyle(
                color: enabled ? accent : Colors.white38,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        Slider(
          value: value.toDouble().clamp(0, 1000),
          min: 0,
          max: 1000,
          activeColor: accent,
          inactiveColor: Colors.white12,
          onChanged: enabled ? (v) => onChanged(v.round()) : null,
        ),
      ],
    );
  }
}
