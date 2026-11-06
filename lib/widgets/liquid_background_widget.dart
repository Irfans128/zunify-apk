import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// Optical Liquid Glass Container (Inspired by BitChord's `LiquidGlassKt` AGSL Shader)
/// Combines:
/// 1. Real-time Gaussian BackdropFilter blur (`sigmaX` / `sigmaY`)
/// 2. Inner Refraction Cushion (curved top-left lens sheen)
/// 3. Directional `-135°` (`-2.356 rad`) Specular Rim Highlight (`_LiquidGlassRimPainter`)
class LiquidGlassBox extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? tintColor;
  final double tintOpacity;
  final double rimIntensity;
  final double? blurSigma;
  final double? width;
  final double? height;
  final VoidCallback? onTap;
  final List<BoxShadow>? boxShadow;

  const LiquidGlassBox({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.padding,
    this.margin,
    this.tintColor,
    this.tintOpacity = 0.09,
    this.rimIntensity = 0.34,
    this.blurSigma,
    this.width,
    this.height,
    this.onTap,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final sigma = blurSigma ?? theme.glassBlurSigma;
    final baseTint = tintColor ?? Colors.white;

    Widget glass = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: boxShadow ??
            [
              BoxShadow(
                color: Colors.black.withOpacity(0.28),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
          child: CustomPaint(
            foregroundPainter: _LiquidGlassRimPainter(
              borderRadius: borderRadius,
              rimIntensity: rimIntensity,
              accentTint: baseTint,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(borderRadius),
                gradient: LinearGradient(
                  begin: const Alignment(-0.85, -0.95),
                  end: const Alignment(0.85, 0.95),
                  colors: [
                    Colors.white.withOpacity((tintOpacity + 0.06).clamp(0.0, 0.45)),
                    baseTint.withOpacity(tintOpacity.clamp(0.0, 0.38)),
                    Colors.white.withOpacity((tintOpacity * 0.45).clamp(0.0, 0.25)),
                  ],
                  stops: const [0.0, 0.48, 1.0],
                ),
              ),
              child: Padding(
                padding: padding ?? EdgeInsets.zero,
                child: child,
              ),
            ),
          ),
        ),
      ),
    );

    if (onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: glass,
      );
    }
    return glass;
  }
}

/// Optical `-135°` Specular Rim + Inner Refraction Cushion Painter
class _LiquidGlassRimPainter extends CustomPainter {
  final double borderRadius;
  final double rimIntensity;
  final Color accentTint;

  const _LiquidGlassRimPainter({
    required this.borderRadius,
    required this.rimIntensity,
    required this.accentTint,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.55),
      Radius.circular(borderRadius),
    );

    // 1. Inner Top-Left Refraction Cushion (Lens Sheen)
    final cushionRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.46);
    final cushionPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity((rimIntensity * 0.28).clamp(0.0, 0.22)),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(cushionRect);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(cushionRect, cushionPaint);
    canvas.restore();

    // 2. Directional -135° Specular Rim Highlight (Top-Left bright -> Center subtle -> Bottom-Right glint)
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.15
      ..shader = LinearGradient(
        begin: const Alignment(-1.0, -1.0),
        end: const Alignment(1.0, 1.0),
        colors: [
          Colors.white.withOpacity((rimIntensity * 1.35).clamp(0.0, 0.68)),
          accentTint.withOpacity((rimIntensity * 0.55).clamp(0.0, 0.34)),
          Colors.white.withOpacity((rimIntensity * 0.16).clamp(0.0, 0.14)),
          Colors.white.withOpacity((rimIntensity * 0.72).clamp(0.0, 0.42)),
        ],
        stops: const [0.0, 0.28, 0.68, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassRimPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.rimIntensity != rimIntensity ||
      oldDelegate.accentTint != accentTint;
}

/// Full-Bleed Artwork Mesh Backdrop Engine (`ArtworkMeshBackdropKt`)
/// Renders deep blurred cover artwork + 5-point dynamic mesh orbs + progressive dark scrim.
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
    this.intensity = 0.52,
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
      duration: const Duration(seconds: 20),
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
    final effectiveIntensity = (widget.intensity * (0.62 + 0.52 * blurMult))
        .clamp(0.18, 0.86);
    final blurSigma = (52.0 * blurMult).clamp(22.0, 64.0);
    final speedFactor =
        (1.0 / theme.animationSpeedMultiplier).clamp(0.55, 1.55);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Base Deep Canvas + Full-Bleed Blurred Album Artwork
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: widget.baseColor),
              if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                Opacity(
                  opacity: (effectiveIntensity * 0.85).clamp(0.0, 0.78),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                      tileMode: TileMode.decal,
                    ),
                    child: Transform.scale(
                      scale: 1.24,
                      child: CachedNetworkImage(
                        imageUrl: widget.imageUrl!,
                        memCacheWidth: 160,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 280),
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),

        // 2. 5-Point Animated Artwork Mesh Palette Orbs
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
                        .withOpacity(effectiveIntensity * 0.88),
                  ),
                );
              },
            ),
          ),
        ),

        // 3. Progressive Optical Scrim Overlay for Crisp Contrast
        IgnorePointer(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  widget.baseColor.withOpacity(0.22),
                  widget.baseColor.withOpacity(0.58),
                  widget.baseColor.withOpacity(0.88),
                ],
                stops: const [0.0, 0.52, 1.0],
              ),
            ),
          ),
        ),

        // 4. Foreground Content
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
      w * (0.24 + 0.24 * math.sin(phase)),
      h * (0.18 + 0.12 * math.cos(phase * 1.1)),
    );
    final orb2Center = Offset(
      w * (0.78 + 0.20 * math.cos(phase * 0.85)),
      h * (0.38 + 0.16 * math.sin(phase)),
    );
    final orb3Center = Offset(
      w * (0.36 + 0.22 * math.sin(phase + 1.9)),
      h * (0.68 + 0.14 * math.cos(phase * 0.9)),
    );
    final orb4Center = Offset(
      w * (0.72 + 0.16 * math.sin(phase * 0.7 + 0.9)),
      h * (0.84 + 0.10 * math.cos(phase * 1.3)),
    );

    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [primaryColor, primaryColor.withOpacity(0.0)],
      ).createShader(Rect.fromCircle(center: orb1Center, radius: w * 0.75));

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [secondaryColor, secondaryColor.withOpacity(0.0)],
      ).createShader(Rect.fromCircle(center: orb2Center, radius: w * 0.68));

    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withOpacity(0.62),
          primaryColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: orb3Center, radius: w * 0.64));

    final paint4 = Paint()
      ..shader = RadialGradient(
        colors: [
          secondaryColor.withOpacity(0.48),
          secondaryColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: orb4Center, radius: w * 0.56));

    canvas.drawCircle(orb1Center, w * 0.75, paint1);
    canvas.drawCircle(orb2Center, w * 0.68, paint2);
    canvas.drawCircle(orb3Center, w * 0.64, paint3);
    canvas.drawCircle(orb4Center, w * 0.56, paint4);
  }

  @override
  bool shouldRepaint(covariant _LiquidOrbsPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.secondaryColor != secondaryColor;
}
