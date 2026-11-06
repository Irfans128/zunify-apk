import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// Dynamic Liquid + Ambient Blur Background Engine for Zunify 2.0
/// Respects user's blur settings & animation speed multiplier while staying ultra-lightweight.
class LiquidBackgroundWidget extends StatefulWidget {
  final Color primaryColor;
  final Color secondaryColor;
  final Color baseColor;
  final String? imageUrl;
  final double intensity;
  final Widget child;

  const LiquidBackgroundWidget({
    super.key,
    required this.primaryColor,
    required this.secondaryColor,
    required this.baseColor,
    this.imageUrl,
    this.intensity = 0.42,
    required this.child,
  });

  @override
  State<LiquidBackgroundWidget> createState() => _LiquidBackgroundWidgetState();
}

class _LiquidBackgroundWidgetState extends State<LiquidBackgroundWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final blurMult = theme.blurIntensity;
    final effectiveIntensity = (widget.intensity * (0.55 + 0.55 * blurMult))
        .clamp(0.14, 0.78);
    final blurSigma = (44.0 * blurMult).clamp(16.0, 52.0);
    final speedFactor = (1.0 / theme.animationSpeedMultiplier).clamp(0.55, 1.55);

    return Stack(
      fit: StackFit.expand,
      children: [
        // Base Deep Dark Canvas + Cached Blurred Album Art (Static per song — zero 60fps blur cost)
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: widget.baseColor),
              if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                Opacity(
                  opacity: effectiveIntensity * 0.72,
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                      tileMode: TileMode.decal,
                    ),
                    child: CachedNetworkImage(
                      imageUrl: widget.imageUrl!,
                      memCacheWidth: 140,
                      fit: BoxFit.cover,
                      fadeInDuration: const Duration(milliseconds: 240),
                      errorWidget: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Animated Dynamic Liquid Orbs (RadialGradients — lightweight & smooth)
        RepaintBoundary(
          child: IgnorePointer(
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final t = _controller.value * 2 * math.pi * speedFactor;
                return CustomPaint(
                  painter: _LiquidOrbsPainter(
                    phase: t,
                    primaryColor:
                        widget.primaryColor.withOpacity(effectiveIntensity),
                    secondaryColor: widget.secondaryColor
                        .withOpacity(effectiveIntensity * 0.85),
                  ),
                );
              },
            ),
          ),
        ),

        // Ambient Depth Vignette Overlay
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  widget.baseColor.withOpacity(0.28),
                  widget.baseColor.withOpacity(0.72),
                  widget.baseColor.withOpacity(0.94),
                ],
              ),
            ),
          ),
        ),

        // Foreground Screen Content
        widget.child,
      ],
    );
  }
}

class _LiquidOrbsPainter extends CustomPainter {
  final double phase;
  final Color primaryColor;
  final Color secondaryColor;

  _LiquidOrbsPainter({
    required this.phase,
    required this.primaryColor,
    required this.secondaryColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final orb1Center = Offset(
      w * (0.3 + 0.25 * math.sin(phase)),
      h * (0.22 + 0.14 * math.cos(phase * 1.2)),
    );
    final orb2Center = Offset(
      w * (0.72 + 0.22 * math.cos(phase * 0.8)),
      h * (0.48 + 0.18 * math.sin(phase)),
    );
    final orb3Center = Offset(
      w * (0.45 + 0.2 * math.sin(phase + 1.8)),
      h * (0.78 + 0.12 * math.cos(phase * 0.9)),
    );

    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [primaryColor, primaryColor.withOpacity(0.0)],
      ).createShader(Rect.fromCircle(center: orb1Center, radius: w * 0.65));

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [secondaryColor, secondaryColor.withOpacity(0.0)],
      ).createShader(Rect.fromCircle(center: orb2Center, radius: w * 0.60));

    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [primaryColor.withOpacity(0.5), primaryColor.withOpacity(0.0)],
      ).createShader(Rect.fromCircle(center: orb3Center, radius: w * 0.55));

    canvas.drawCircle(orb1Center, w * 0.65, paint1);
    canvas.drawCircle(orb2Center, w * 0.60, paint2);
    canvas.drawCircle(orb3Center, w * 0.55, paint3);
  }

  @override
  bool shouldRepaint(covariant _LiquidOrbsPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.secondaryColor != secondaryColor;
}
