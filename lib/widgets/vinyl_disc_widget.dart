import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Gaya 2 Rotating Vinyl Record Disc Widget
/// Spins smoothly when music is playing, featuring realistic vinyl micro-grooves,
/// anisotropic light sheen, and center song artwork with a vinyl spindle hole.
class VinylDiscWidget extends StatefulWidget {
  final String imageUrl;
  final String? localImagePath;
  final bool isPlaying;
  final Color accentColor;
  final double size;

  const VinylDiscWidget({
    super.key,
    required this.imageUrl,
    this.localImagePath,
    required this.isPlaying,
    required this.accentColor,
    this.size = 290,
  });

  @override
  State<VinylDiscWidget> createState() => _VinylDiscWidgetState();
}

class _VinylDiscWidgetState extends State<VinylDiscWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant VinylDiscWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.isPlaying && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer Ambient Neon Halo
          AnimatedContainer(
            duration: const Duration(milliseconds: 600),
            width: widget.size + 18,
            height: widget.size + 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: widget.accentColor.withOpacity(widget.isPlaying ? 0.34 : 0.14),
                  blurRadius: widget.isPlaying ? 44 : 20,
                  spreadRadius: widget.isPlaying ? 6 : 1,
                ),
              ],
            ),
          ),

          // Rotating Vinyl Record (Wrapped in RepaintBoundary so 60/120fps spin
          // never repaints the expensive BackdropFilter blur behind it!)
          RepaintBoundary(
            child: RotationTransition(
              turns: _controller,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const SweepGradient(
                    colors: [
                      Color(0xFF0A0B0F),
                      Color(0xFF222631),
                      Color(0xFF0A0B0F),
                      Color(0xFF1F2430),
                      Color(0xFF0A0B0F),
                    ],
                  ),
                  border: Border.all(
                    color: widget.accentColor.withOpacity(0.55),
                    width: 2.0,
                  ),
                ),
                child: CustomPaint(
                  painter: _VinylGroovesPainter(),
                  child: Center(
                    // Inner Album Art Label
                    child: Container(
                      width: widget.size * 0.44,
                      height: widget.size * 0.44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.black87,
                          width: 4,
                        ),
                      ),
                      child: ClipOval(
                        child: Stack(
                          fit: StackFit.expand,
                          alignment: Alignment.center,
                          children: [
                            _buildCenterArt(),
                            // Vinyl Center Spindle Hole
                            Center(
                              child: Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF07080C),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: widget.accentColor.withOpacity(0.8),
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCenterArt() {
    if (widget.localImagePath != null && File(widget.localImagePath!).existsSync()) {
      return Image.file(
        File(widget.localImagePath!),
        fit: BoxFit.cover,
      );
    }
    if (widget.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.imageUrl,
        fit: BoxFit.cover,
        errorWidget: (_, __, ___) => _defaultZMonogram(),
      );
    }
    return _defaultZMonogram();
  }

  Widget _defaultZMonogram() {
    return Container(
      color: const Color(0xFF10131C),
      alignment: Alignment.center,
      child: Text(
        'Z',
        style: TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w900,
          color: widget.accentColor,
        ),
      ),
    );
  }
}

class _VinylGroovesPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final minRadius = maxRadius * 0.46;

    final groovePaint = Paint()
      ..color = Colors.white.withOpacity(0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double r = minRadius; r < maxRadius - 6; r += 4.5) {
      canvas.drawCircle(center, r, groovePaint);
    }

    // Subtle sheen arc
    final arcPaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: maxRadius * 0.72),
      -math.pi / 4,
      math.pi / 3,
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
