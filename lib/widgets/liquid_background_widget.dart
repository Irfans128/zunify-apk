import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// Authentic iOS 26 Optical Liquid Glass Container.
///
/// Performance-engineered for 60/120fps:
/// - By default (`enableBlur: false`), renders pure optical iOS 26 Liquid Glass
///   (convex top-left lens sheen, translucent frosted gradient, and `-135°`
///   specular rim highlight) with zero GPU `saveLayer` offscreen blur cost.
/// - Set `enableBlur: true` ONLY on floating bars/sheets that pass over
///   scrolling content (e.g. Floating Tab Bar, Floating Mini-Player, Modals).
class LiquidGlassBox extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Color? tintColor;
  final double tintOpacity;
  final double rimIntensity;
  final double? blurSigma;
  final bool enableBlur;
  final bool enableShadow;
  final AlignmentGeometry? alignment;
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
    this.enableBlur = false,
    this.enableShadow = false,
    this.alignment,
    this.width,
    this.height,
    this.onTap,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final baseTint = tintColor ?? Colors.white;
    final effectiveAlignment =
        alignment ?? ((width != null || height != null) ? Alignment.center : null);

    Widget innerSurface = CustomPaint(
      foregroundPainter: _LiquidGlassRimPainter(
        borderRadius: borderRadius,
        rimIntensity: rimIntensity,
        accentTint: baseTint,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          gradient: LinearGradient(
            begin: const Alignment(-0.9, -0.95),
            end: const Alignment(0.9, 0.95),
            colors: [
              Colors.white.withOpacity((tintOpacity + 0.075).clamp(0.0, 0.42)),
              Color.lerp(const Color(0xFF1A1B24), baseTint, 0.38)!
                  .withOpacity((tintOpacity + 0.16).clamp(0.0, 0.58)),
              baseTint.withOpacity((tintOpacity * 0.72).clamp(0.0, 0.32)),
            ],
            stops: const [0.0, 0.52, 1.0],
          ),
        ),
        child: Container(
          alignment: effectiveAlignment,
          padding: padding ?? EdgeInsets.zero,
          child: child,
        ),
      ),
    );

    if (enableBlur) {
      final sigma =
          blurSigma ?? context.select<ThemeProvider, double>((t) => t.glassBlurSigma);
      innerSurface = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: sigma.clamp(10.0, 28.0),
            sigmaY: sigma.clamp(10.0, 28.0),
          ),
          child: innerSurface,
        ),
      );
    } else {
      innerSurface = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: innerSurface,
      );
    }

    final effectiveShadows = boxShadow ??
        (enableShadow
            ? [
                BoxShadow(
                  color: Colors.black.withOpacity(0.28),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ]
            : null);

    Widget glass = Container(
      width: width,
      height: height,
      margin: margin,
      decoration: effectiveShadows != null
          ? BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: effectiveShadows,
            )
          : null,
      child: innerSurface,
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

/// Reusable iOS 26 Circular Liquid Glass Icon Button.
/// Ensures 100% consistent size, centering, optical sheen, and tap feedback.
class IosGlassIconButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? iconColor;
  final Color? activeColor;
  final bool isActive;
  final String? tooltip;

  const IosGlassIconButton({
    super.key,
    required this.icon,
    this.onTap,
    this.size = 38.0,
    this.iconSize = 19.0,
    this.iconColor,
    this.activeColor,
    this.isActive = false,
    this.tooltip,
  });

  @override
  State<IosGlassIconButton> createState() => _IosGlassIconButtonState();
}

class _IosGlassIconButtonState extends State<IosGlassIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final tint = widget.isActive
        ? (widget.activeColor ?? Colors.white)
        : Colors.white;
    final fgColor = widget.isActive
        ? (widget.activeColor ?? Colors.white)
        : (widget.iconColor ?? Colors.white.withOpacity(0.92));

    Widget button = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.onTap != null ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.91 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: LiquidGlassBox(
          width: widget.size,
          height: widget.size,
          borderRadius: widget.size / 2,
          tintColor: tint,
          tintOpacity: widget.isActive ? 0.20 : 0.08,
          rimIntensity: widget.isActive ? 0.48 : 0.32,
          alignment: Alignment.center,
          child: Icon(
            widget.icon,
            size: widget.iconSize,
            color: fgColor,
          ),
        ),
      ),
    );

    if (widget.tooltip != null) {
      return Tooltip(message: widget.tooltip!, child: button);
    }
    return button;
  }
}

/// Reusable iOS 26 Capsule Liquid Glass Pill Button.
/// Keeps icon + label uniformly aligned with crisp iOS 26 specular border.
class IosGlassPillButton extends StatefulWidget {
  final IconData? icon;
  final String label;
  final VoidCallback? onTap;
  final double height;
  final EdgeInsetsGeometry padding;
  final Color? activeColor;
  final bool isActive;
  final double fontSize;

  const IosGlassPillButton({
    super.key,
    this.icon,
    required this.label,
    this.onTap,
    this.height = 34.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 13),
    this.activeColor,
    this.isActive = false,
    this.fontSize = 12.0,
  });

  @override
  State<IosGlassPillButton> createState() => _IosGlassPillButtonState();
}

class _IosGlassPillButtonState extends State<IosGlassPillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final accent = widget.activeColor ?? Colors.white;
    final fgColor = widget.isActive
        ? Colors.white
        : Colors.white.withOpacity(0.86);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.onTap != null ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        child: LiquidGlassBox(
          height: widget.height,
          borderRadius: widget.height / 2,
          padding: widget.padding,
          tintColor: widget.isActive ? accent : Colors.white,
          tintOpacity: widget.isActive ? 0.24 : 0.08,
          rimIntensity: widget.isActive ? 0.52 : 0.30,
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: widget.fontSize + 2.5,
                  color: widget.isActive ? accent : fgColor,
                ),
                const SizedBox(width: 6),
              ],
              Text(
                widget.label,
                style: TextStyle(
                  color: fgColor,
                  fontSize: widget.fontSize,
                  fontWeight:
                      widget.isActive ? FontWeight.w700 : FontWeight.w600,
                  letterSpacing: -0.1,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Optical `-135°` iOS 26 Specular Rim + Convex Lens Sheen Painter
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
    final radius = borderRadius.clamp(0.0, math.min(size.width, size.height) / 2);
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(radius),
    );

    // 1. iOS 26 Convex Top-Half Lens Sheen
    final cushionRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.48);
    final cushionPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity((rimIntensity * 0.26).clamp(0.0, 0.20)),
          Colors.white.withOpacity(0.0),
        ],
      ).createShader(cushionRect);
    canvas.save();
    canvas.clipRRect(rrect);
    canvas.drawRect(cushionRect, cushionPaint);
    canvas.restore();

    // 2. Crisp -135° Specular Rim (Top-Left bright -> Side soft -> Bottom-Right caustic glint)
    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: const Alignment(-1.0, -1.0),
        end: const Alignment(1.0, 1.0),
        colors: [
          Colors.white.withOpacity((rimIntensity * 1.38).clamp(0.0, 0.66)),
          accentTint.withOpacity((rimIntensity * 0.48).clamp(0.0, 0.30)),
          Colors.white.withOpacity((rimIntensity * 0.14).clamp(0.0, 0.10)),
          Colors.white.withOpacity((rimIntensity * 0.72).clamp(0.0, 0.38)),
        ],
        stops: const [0.0, 0.30, 0.70, 1.0],
      ).createShader(rect);

    canvas.drawRRect(rrect, rimPaint);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassRimPainter oldDelegate) =>
      oldDelegate.borderRadius != borderRadius ||
      oldDelegate.rimIntensity != rimIntensity ||
      oldDelegate.accentTint != accentTint;
}

/// Full-Bleed iOS 26 Ambient Artwork Mesh Backdrop Engine
/// Optimized with isolated RepaintBoundaries for zero scroll jank.
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
    this.intensity = 0.50,
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
      duration: const Duration(seconds: 24),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final blurMult =
        context.select<ThemeProvider, double>((t) => t.blurIntensity);
    final animSpeed = context
        .select<ThemeProvider, double>((t) => t.animationSpeedMultiplier);
    final effectiveIntensity =
        (widget.intensity * (0.60 + 0.48 * blurMult)).clamp(0.18, 0.82);
    final blurSigma = (44.0 * blurMult).clamp(20.0, 54.0);
    final speedFactor = (1.0 / animSpeed).clamp(0.55, 1.45);

    return Stack(
      fit: StackFit.expand,
      children: [
        // 1. Static Blurred Cover Art + Ambient Orbs inside a single isolated RepaintBoundary
        RepaintBoundary(
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: widget.baseColor),
              if (widget.imageUrl != null && widget.imageUrl!.isNotEmpty)
                Opacity(
                  opacity: (effectiveIntensity * 0.80).clamp(0.0, 0.72),
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(
                      sigmaX: blurSigma,
                      sigmaY: blurSigma,
                      tileMode: TileMode.decal,
                    ),
                    child: Transform.scale(
                      scale: 1.22,
                      child: CachedNetworkImage(
                        imageUrl: widget.imageUrl!,
                        memCacheWidth: 120,
                        fit: BoxFit.cover,
                        fadeInDuration: const Duration(milliseconds: 260),
                        errorWidget: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    ),
                  ),
                ),
              IgnorePointer(
                child: AnimatedBuilder(
                  animation: _controller,
                  builder: (context, _) {
                    final t = _controller.value * 2 * math.pi * speedFactor;
                    return CustomPaint(
                      isComplex: true,
                      painter: _LiquidOrbsPainter(
                        phase: t,
                        primaryColor:
                            widget.primaryColor.withOpacity(effectiveIntensity),
                        secondaryColor: widget.secondaryColor
                            .withOpacity(effectiveIntensity * 0.84),
                      ),
                    );
                  },
                ),
              ),
              IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        widget.baseColor.withOpacity(0.20),
                        widget.baseColor.withOpacity(0.56),
                        widget.baseColor.withOpacity(0.88),
                      ],
                      stops: const [0.0, 0.54, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Foreground UI (completely decoupled from background repaints)
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
      w * (0.24 + 0.20 * math.sin(phase)),
      h * (0.18 + 0.10 * math.cos(phase * 1.1)),
    );
    final orb2Center = Offset(
      w * (0.76 + 0.18 * math.cos(phase * 0.85)),
      h * (0.40 + 0.14 * math.sin(phase)),
    );
    final orb3Center = Offset(
      w * (0.34 + 0.18 * math.sin(phase + 1.9)),
      h * (0.72 + 0.12 * math.cos(phase * 0.9)),
    );

    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [primaryColor, primaryColor.withOpacity(0.0)],
      ).createShader(Rect.fromCircle(center: orb1Center, radius: w * 0.76));

    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [secondaryColor, secondaryColor.withOpacity(0.0)],
      ).createShader(Rect.fromCircle(center: orb2Center, radius: w * 0.70));

    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [
          primaryColor.withOpacity(0.55),
          primaryColor.withOpacity(0.0),
        ],
      ).createShader(Rect.fromCircle(center: orb3Center, radius: w * 0.64));

    canvas.drawCircle(orb1Center, w * 0.76, paint1);
    canvas.drawCircle(orb2Center, w * 0.70, paint2);
    canvas.drawCircle(orb3Center, w * 0.64, paint3);
  }

  @override
  bool shouldRepaint(covariant _LiquidOrbsPainter oldDelegate) =>
      oldDelegate.phase != phase ||
      oldDelegate.primaryColor != primaryColor ||
      oldDelegate.secondaryColor != secondaryColor;
}
