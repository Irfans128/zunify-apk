import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';

/// High-Refresh-Rate (90/120Hz) Interactive Button Wrapper.
/// - **Liquid Glass**: Fluid iOS spring squish + specular radial bloom.
/// - **Neo-Brutalism**: Physical `+3px, +3px` snap-into-shadow translation.
class IosSpringButton extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scaleDown;
  final double borderRadius;
  final bool enableHaptic;
  final bool enableBloom;
  final HitTestBehavior behavior;

  const IosSpringButton({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.scaleDown = 0.92,
    this.borderRadius = 999.0,
    this.enableHaptic = true,
    this.enableBloom = true,
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<IosSpringButton> createState() => _IosSpringButtonState();
}

class _IosSpringButtonState extends State<IosSpringButton> {
  bool _pressed = false;
  DateTime? _pressDownTime;
  Offset? _downPosition;
  Timer? _releaseTimer;

  bool get _isInteractive => widget.onTap != null || widget.onLongPress != null;

  void _handlePointerDown(PointerDownEvent event) {
    if (!_isInteractive) return;
    _releaseTimer?.cancel();
    _pressDownTime = DateTime.now();
    _downPosition = event.position;
    if (!_pressed && mounted) {
      setState(() => _pressed = true);
    }
  }

  void _handlePointerMove(PointerMoveEvent event) {
    if (!_pressed || _downPosition == null) return;
    if ((event.position - _downPosition!).distance > 12.0) {
      _releaseTimer?.cancel();
      if (mounted) {
        setState(() => _pressed = false);
      }
    }
  }

  void _scheduleRelease() {
    if (!_pressed) return;
    final elapsed = _pressDownTime != null
        ? DateTime.now().difference(_pressDownTime!).inMilliseconds
        : 100;
    const minPressMs = 80;
    if (elapsed < minPressMs) {
      _releaseTimer?.cancel();
      _releaseTimer = Timer(Duration(milliseconds: minPressMs - elapsed), () {
        if (mounted && _pressed) {
          setState(() => _pressed = false);
        }
      });
    } else {
      if (mounted) {
        setState(() => _pressed = false);
      }
    }
  }

  void _handlePointerUp(PointerUpEvent event) {
    _scheduleRelease();
  }

  void _handlePointerCancel(PointerCancelEvent event) {
    _releaseTimer?.cancel();
    if (_pressed && mounted) {
      setState(() => _pressed = false);
    }
  }

  void _handleTap() {
    if (widget.onTap == null) return;
    if (widget.enableHaptic) {
      HapticFeedback.lightImpact();
    }
    if (!_pressed && mounted) {
      setState(() => _pressed = true);
      _pressDownTime = DateTime.now();
    }
    _scheduleRelease();
    widget.onTap!();
  }

  @override
  void dispose() {
    _releaseTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInteractive) return widget.child;

    final isBrutal =
        context.select<ThemeProvider, bool>((t) => t.isNeoBrutalism);

    Widget animatedBody;
    if (isBrutal) {
      animatedBody = AnimatedContainer(
        duration: Duration(milliseconds: _pressed ? 55 : 150),
        curve: Curves.easeOutCubic,
        transform: Matrix4.translationValues(
          _pressed ? 3.0 : 0.0,
          _pressed ? 3.0 : 0.0,
          0.0,
        ),
        child: widget.child,
      );
    } else {
      animatedBody = AnimatedScale(
        scale: _pressed ? widget.scaleDown : 1.0,
        duration: Duration(milliseconds: _pressed ? 75 : 310),
        curve: _pressed ? Curves.easeOutCubic : const _Ios27SpringCurve(),
        child: widget.enableBloom
            ? Stack(
                alignment: Alignment.center,
                children: [
                  widget.child,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: AnimatedOpacity(
                        opacity: _pressed ? 1.0 : 0.0,
                        duration: Duration(milliseconds: _pressed ? 60 : 210),
                        curve: Curves.easeOut,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius:
                                BorderRadius.circular(widget.borderRadius),
                            gradient: RadialGradient(
                              center: const Alignment(-0.25, -0.35),
                              radius: 1.15,
                              colors: [
                                Colors.white.withOpacity(0.18),
                                Colors.white.withOpacity(0.05),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.55, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              )
            : widget.child,
      );
    }

    return Listener(
      behavior: widget.behavior,
      onPointerDown: _handlePointerDown,
      onPointerMove: _handlePointerMove,
      onPointerUp: _handlePointerUp,
      onPointerCancel: _handlePointerCancel,
      child: GestureDetector(
        behavior: widget.behavior,
        onTap: widget.onTap != null ? _handleTap : null,
        onLongPress: widget.onLongPress,
        child: animatedBody,
      ),
    );
  }
}

/// Custom 90/120Hz Fluid Spring Curve with subtle elastic overshoot
class _Ios27SpringCurve extends Curve {
  const _Ios27SpringCurve();

  @override
  double transformInternal(double t) {
    final inv = 1.0 - t;
    return 1.0 - (inv * inv * (math.cos(t * math.pi * 2.15) * 0.28 + 0.72));
  }
}

/// Dual-Theme Surface Container:
/// - **Liquid Glass**: 3D optical lens refraction + `-135°` specular rim.
/// - **Neo-Brutalism**: Warm cream/white solid surface + `2.4px` pitch-black border + `4px` hard black zero-blur shadow.
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
  final double scaleDown;
  final bool enableSpring;
  final List<BoxShadow>? boxShadow;

  const LiquidGlassBox({
    super.key,
    required this.child,
    this.borderRadius = 24.0,
    this.padding,
    this.margin,
    this.tintColor,
    this.tintOpacity = 0.09,
    this.rimIntensity = 0.36,
    this.blurSigma,
    this.enableBlur = false,
    this.enableShadow = false,
    this.alignment,
    this.width,
    this.height,
    this.onTap,
    this.scaleDown = 0.94,
    this.enableSpring = true,
    this.boxShadow,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isBrutal = theme.isNeoBrutalism;
    final baseTint = tintColor ?? Colors.white;
    final effectiveAlignment = alignment ??
        ((width != null || height != null) ? Alignment.center : null);

    if (isBrutal) {
      final hasCustomTint = tintColor != null && tintColor != Colors.white;
      final baseCard = theme.cardBgColor;
      final fillBg = hasCustomTint
          ? Color.lerp(
              baseCard,
              baseTint,
              theme.isLightCanvas
                  ? (tintOpacity * 1.55).clamp(0.16, 0.44)
                  : (tintOpacity * 1.35).clamp(0.14, 0.36),
            )!
          : baseCard;

      final brutalRadius = (width != null &&
              height != null &&
              (width! - height!).abs() < 2.0 &&
              borderRadius >= width! * 0.45)
          ? 12.0
          : borderRadius.clamp(10.0, 14.0);

      final shadowOffset = enableShadow ? 4.5 : 3.5;

      Widget brutalCard = Container(
        width: width,
        height: height,
        margin: margin,
        alignment: effectiveAlignment,
        padding: padding ?? EdgeInsets.zero,
        decoration: BoxDecoration(
          color: fillBg,
          borderRadius: BorderRadius.circular(brutalRadius),
          border: Border.all(
            color: theme.brutalBorderColor,
            width: 2.2,
          ),
          boxShadow: boxShadow ??
              [
                BoxShadow(
                  color: theme.brutalShadowColor,
                  blurRadius: 0,
                  offset: Offset(shadowOffset, shadowOffset),
                ),
              ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(math.max(0, brutalRadius - 2.2)),
          child: child,
        ),
      );

      if (onTap != null && enableSpring) {
        return IosSpringButton(
          onTap: onTap,
          scaleDown: scaleDown,
          borderRadius: brutalRadius,
          child: brutalCard,
        );
      } else if (onTap != null) {
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: brutalCard,
        );
      }
      return brutalCard;
    }

    // Liquid Glass Mode
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
            begin: const Alignment(-0.92, -0.96),
            end: const Alignment(0.92, 0.96),
            colors: [
              Colors.white.withOpacity((tintOpacity + 0.095).clamp(0.0, 0.46)),
              Color.lerp(const Color(0xFF171923), baseTint, 0.40)!
                  .withOpacity((tintOpacity + 0.17).clamp(0.0, 0.62)),
              Color.lerp(const Color(0xFF0E1017), baseTint, 0.25)!
                  .withOpacity((tintOpacity + 0.13).clamp(0.0, 0.54)),
              baseTint.withOpacity((tintOpacity * 0.85).clamp(0.0, 0.36)),
            ],
            stops: const [0.0, 0.42, 0.78, 1.0],
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
      final sigma = blurSigma ?? theme.glassBlurSigma;
      innerSurface = ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: sigma.clamp(12.0, 30.0),
            sigmaY: sigma.clamp(12.0, 30.0),
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
                  color: Colors.black.withOpacity(0.32),
                  blurRadius: 22,
                  spreadRadius: -2,
                  offset: const Offset(0, 9),
                ),
                BoxShadow(
                  color: baseTint.withOpacity(0.06),
                  blurRadius: 14,
                  offset: const Offset(0, -1),
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

    if (onTap != null && enableSpring) {
      return IosSpringButton(
        onTap: onTap,
        scaleDown: scaleDown,
        borderRadius: borderRadius,
        child: glass,
      );
    } else if (onTap != null) {
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: glass,
      );
    }
    return glass;
  }
}

/// Reusable Icon Button (Adapts to Liquid Glass & Neo-Brutalism)
class IosGlassIconButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = activeColor ?? theme.accentColor;

    if (theme.isNeoBrutalism) {
      final fill = isActive ? accent : theme.cardBgColor;
      final fg = isActive ? const Color(0xFF111111) : theme.textPrimary;
      Widget btn = IosSpringButton(
        onTap: onTap,
        borderRadius: 11,
        child: Container(
          width: size,
          height: size,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: theme.brutalBorderColor, width: 2.0),
            boxShadow: [
              BoxShadow(
                color: theme.brutalShadowColor,
                blurRadius: 0,
                offset: const Offset(2.8, 2.8),
              ),
            ],
          ),
          child: Icon(icon, size: iconSize, color: fg),
        ),
      );
      if (tooltip != null) {
        return Tooltip(message: tooltip!, child: btn);
      }
      return btn;
    }

    final tint = isActive ? accent : Colors.white;
    final fgColor = isActive
        ? accent
        : (iconColor ?? Colors.white.withOpacity(0.94));

    Widget button = IosSpringButton(
      onTap: onTap,
      scaleDown: 0.85,
      borderRadius: size / 2,
      child: LiquidGlassBox(
        width: size,
        height: size,
        borderRadius: size / 2,
        tintColor: tint,
        tintOpacity: isActive ? 0.22 : 0.09,
        rimIntensity: isActive ? 0.54 : 0.36,
        alignment: Alignment.center,
        enableSpring: false,
        child: Icon(
          icon,
          size: iconSize,
          color: fgColor,
        ),
      ),
    );

    if (tooltip != null) {
      return Tooltip(message: tooltip!, child: button);
    }
    return button;
  }
}

/// Reusable Pill / Sticker Button (Adapts to Liquid Glass & Neo-Brutalism)
class IosGlassPillButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final accent = activeColor ?? theme.accentColor;

    if (theme.isNeoBrutalism) {
      final fill = isActive ? accent : theme.cardBgColor;
      final fg = isActive ? const Color(0xFF111111) : theme.textPrimary;
      return IosSpringButton(
        onTap: onTap,
        borderRadius: 10,
        child: Container(
          height: height,
          padding: padding,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: theme.brutalBorderColor, width: 2.0),
            boxShadow: [
              BoxShadow(
                color: theme.brutalShadowColor,
                blurRadius: 0,
                offset: const Offset(2.8, 2.8),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: fontSize + 2.5, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                  color: fg,
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.1,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final fgColor = isActive ? Colors.white : Colors.white.withOpacity(0.88);

    return IosSpringButton(
      onTap: onTap,
      scaleDown: 0.90,
      borderRadius: height / 2,
      child: LiquidGlassBox(
        height: height,
        borderRadius: height / 2,
        padding: padding,
        tintColor: isActive ? accent : Colors.white,
        tintOpacity: isActive ? 0.25 : 0.09,
        rimIntensity: isActive ? 0.56 : 0.34,
        alignment: Alignment.center,
        enableSpring: false,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: fontSize + 2.5,
                color: isActive ? accent : fgColor,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                color: fgColor,
                fontSize: fontSize,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                letterSpacing: -0.1,
                height: 1.1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Theme-Aware Modal Bottom Sheet Container (Liquid Glass & Neo-Brutalism)
class ZunifySheetContainer extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double? height;
  final BoxConstraints? constraints;

  const ZunifySheetContainer({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(20, 12, 20, 22),
    this.height,
    this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final isBrutal = theme.isNeoBrutalism;
    final topRadius = isBrutal ? 18.0 : 28.0;

    return Container(
      height: height,
      constraints: constraints,
      padding: padding,
      decoration: BoxDecoration(
        color: theme.sheetBgColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(topRadius)),
        border: Border(
          top: BorderSide(
            color: isBrutal
                ? theme.brutalBorderColor
                : Colors.white.withOpacity(0.12),
            width: isBrutal ? 2.8 : 1.0,
          ),
          left: isBrutal
              ? BorderSide(color: theme.brutalBorderColor, width: 2.2)
              : BorderSide.none,
          right: isBrutal
              ? BorderSide(color: theme.brutalBorderColor, width: 2.2)
              : BorderSide.none,
        ),
      ),
      child: child,
    );
  }
}

/// Optical `-135°` Dual-Layer Specular Rim + 3D Convex Lens Refraction Painter
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
    final radius =
        borderRadius.clamp(0.0, math.min(size.width, size.height) / 2);
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.5),
      Radius.circular(radius),
    );

    canvas.save();
    canvas.clipRRect(rrect);

    final cushionRect = Rect.fromLTWH(0, 0, size.width, size.height * 0.44);
    final cushionPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withOpacity((rimIntensity * 0.34).clamp(0.0, 0.25)),
          Colors.white.withOpacity((rimIntensity * 0.08).clamp(0.0, 0.07)),
          Colors.white.withOpacity(0.0),
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(cushionRect);
    canvas.drawRect(cushionRect, cushionPaint);

    final causticHeight = (size.height * 0.24).clamp(6.0, 28.0);
    final causticRect = Rect.fromLTWH(
      0,
      size.height - causticHeight,
      size.width,
      causticHeight,
    );
    final causticPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [
          Color.lerp(Colors.white, accentTint, 0.45)!
              .withOpacity((rimIntensity * 0.16).clamp(0.0, 0.12)),
          Colors.transparent,
        ],
      ).createShader(causticRect);
    canvas.drawRect(causticRect, causticPaint);

    canvas.restore();

    if (size.width > 16 && size.height > 16) {
      final innerRadius = math.max(0.0, radius - 1.2);
      final innerRRect = RRect.fromRectAndRadius(
        rect.deflate(1.5),
        Radius.circular(innerRadius),
      );
      final innerRimPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.75
        ..shader = LinearGradient(
          begin: const Alignment(-0.9, -1.0),
          end: const Alignment(0.7, 0.8),
          colors: [
            Colors.white.withOpacity((rimIntensity * 0.42).clamp(0.0, 0.26)),
            Colors.transparent,
            Colors.white.withOpacity((rimIntensity * 0.14).clamp(0.0, 0.09)),
          ],
          stops: const [0.0, 0.50, 1.0],
        ).createShader(rect);
      canvas.drawRRect(innerRRect, innerRimPaint);
    }

    final rimPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = LinearGradient(
        begin: const Alignment(-1.0, -1.0),
        end: const Alignment(1.0, 1.0),
        colors: [
          Colors.white.withOpacity((rimIntensity * 1.52).clamp(0.0, 0.76)),
          Color.lerp(Colors.white, accentTint, 0.55)!
              .withOpacity((rimIntensity * 0.62).clamp(0.0, 0.38)),
          Colors.white.withOpacity((rimIntensity * 0.14).clamp(0.0, 0.10)),
          Color.lerp(Colors.white, accentTint, 0.35)!
              .withOpacity((rimIntensity * 0.82).clamp(0.0, 0.44)),
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

/// Full-Bleed Ambient Backdrop Engine (90/120Hz Optimized)
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
    final isBrutal =
        context.select<ThemeProvider, bool>((t) => t.isNeoBrutalism);
    final isLight =
        context.select<ThemeProvider, bool>((t) => t.isLightCanvas);
    final blurMult =
        context.select<ThemeProvider, double>((t) => t.blurIntensity);
    final animSpeed = context
        .select<ThemeProvider, double>((t) => t.animationSpeedMultiplier);
    final effectiveIntensity =
        (widget.intensity * (0.60 + 0.48 * blurMult)).clamp(0.18, 0.82);
    final blurSigma = (44.0 * blurMult).clamp(20.0, 54.0);
    final speedFactor = (1.0 / animSpeed).clamp(0.55, 1.45);

    if (isBrutal) {
      return Stack(
        fit: StackFit.expand,
        children: [
          RepaintBoundary(
            child: CustomPaint(
              painter: _NeoBrutalistBackdropPainter(
                baseColor: widget.baseColor,
                accentColor: widget.primaryColor,
                isLightCanvas: isLight,
              ),
            ),
          ),
          widget.child,
        ],
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
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
                        widget.baseColor.withOpacity(0.18),
                        widget.baseColor.withOpacity(0.54),
                        widget.baseColor.withOpacity(0.86),
                      ],
                      stops: const [0.0, 0.54, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        widget.child,
      ],
    );
  }
}

class _NeoBrutalistBackdropPainter extends CustomPainter {
  final Color baseColor;
  final Color accentColor;
  final bool isLightCanvas;

  const _NeoBrutalistBackdropPainter({
    required this.baseColor,
    required this.accentColor,
    required this.isLightCanvas,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = baseColor);

    // Subtle top-right warm tint wash
    final washPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.85, -0.82),
        radius: 0.95,
        colors: [
          accentColor.withOpacity(isLightCanvas ? 0.16 : 0.12),
          Colors.transparent,
        ],
      ).createShader(rect);
    canvas.drawRect(rect, washPaint);

    // Crisp Neo-Brutalist architectural dot-grid pattern
    final dotPaint = Paint()
      ..color = isLightCanvas
          ? const Color(0xFF111111).withOpacity(0.11)
          : Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.fill;
    const step = 22.0;
    for (double y = 14; y < size.height; y += step) {
      for (double x = 14; x < size.width; x += step) {
        canvas.drawCircle(Offset(x, y), 1.15, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _NeoBrutalistBackdropPainter oldDelegate) =>
      oldDelegate.baseColor != baseColor ||
      oldDelegate.accentColor != accentColor ||
      oldDelegate.isLightCanvas != isLightCanvas;
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
