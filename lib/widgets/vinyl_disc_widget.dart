import 'dart:io';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

/// Gaya 2 Rotating Vinyl Record Disc + Circular Audio Spectrum Visualizer Ring
/// Spins smoothly when music is playing, featuring 42 radial neon equalizer bars,
/// realistic vinyl micro-grooves, anisotropic light sheen, and center song artwork.
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
    this.size = 256,
  });

  @override
  State<VinylDiscWidget> createState() => _VinylDiscWidgetState();
}

class _VinylDiscWidgetState extends State<VinylDiscWidget>
    with TickerProviderStateMixin {
  late final AnimationController _spinController;
  late final AnimationController _spectrumController;

  @override
  void initState() {
    super.initState();
    _spinController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 16),
    );
    _spectrumController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (widget.isPlaying) {
      _spinController.repeat();
      _spectrumController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant VinylDiscWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPlaying && !_spinController.isAnimating) {
      _spinController.repeat();
      _spectrumController.repeat();
    } else if (!widget.isPlaying && _spinController.isAnimating) {
      _spinController.stop();
      _spectrumController.stop();
    }
  }

  @override
  void dispose() {
    _spinController.dispose();
    _spectrumController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SizedBox(
        width: widget.size + 44,
        height: widget.size + 44,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Outer Ambient Neon Halo
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: widget.size + 14,
              height: widget.size + 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: widget.accentColor
                        .withOpacity(widget.isPlaying ? 0.36 : 0.12),
                    blurRadius: widget.isPlaying ? 46 : 18,
                    spreadRadius: widget.isPlaying ? 6 : 1,
                  ),
                ],
              ),
            ),

            // Circular Neon Audio Spectrum Visualizer Ring around Vinyl Rim
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _spectrumController,
                builder: (context, _) {
                  return CustomPaint(
                    size: Size(widget.size + 40, widget.size + 40),
                    painter: _CircularSpectrumPainter(
                      phase: _spectrumController.value * 2 * math.pi,
                      isPlaying: widget.isPlaying,
                      accentColor: widget.accentColor,
                    ),
                  );
                },
              ),
            ),

            // Rotating Vinyl Record
            RepaintBoundary(
              child: RotationTransition(
                turns: _spinController,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const SweepGradient(
                      colors: [
                        Color(0xFF0A0B0F),
                        Color(0xFF232836),
                        Color(0xFF0A0B0F),
                        Color(0xFF1E2330),
                        Color(0xFF0A0B0F),
                      ],
                    ),
                    border: Border.all(
                      color: widget.accentColor.withOpacity(0.65),
                      width: 2.0,
                    ),
                  ),
                  child: CustomPaint(
                    painter: _VinylGroovesPainter(accentColor: widget.accentColor),
                    child: Center(
                      // Inner Album Art Label
                      child: Container(
                        width: widget.size * 0.45,
                        height: widget.size * 0.45,
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
                                  width: 17,
                                  height: 17,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF07080C),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: widget.accentColor.withOpacity(0.9),
                                      width: 2.2,
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
      ),
    );
  }

  Widget _buildCenterArt() {
    if (widget.localImagePath != null &&
        File(widget.localImagePath!).existsSync()) {
      return Image.file(
        File(widget.localImagePath!),
        cacheWidth: 280,
        fit: BoxFit.cover,
      );
    }
    if (widget.imageUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.imageUrl,
        memCacheWidth: 280,
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 150),
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
          fontSize: 40,
          fontWeight: FontWeight.w900,
          color: widget.accentColor,
        ),
      ),
    );
  }
}

class _CircularSpectrumPainter extends CustomPainter {
  final double phase;
  final bool isPlaying;
  final Color accentColor;

  _CircularSpectrumPainter({
    required this.phase,
    required this.isPlaying,
    required this.accentColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final baseRadius = (size.width / 2) - 18;
    const int barCount = 48;

    final barPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 3.2;

    for (int i = 0; i < barCount; i++) {
      final angle = (i / barCount) * 2 * math.pi;
      double amplitude = 3.0;
      if (isPlaying) {
        final wave1 = math.sin(phase * 2.0 + i * 0.45).abs();
        final wave2 = math.cos(phase * 3.0 - i * 0.7).abs();
        final wave3 = math.sin(phase + i * 0.25).abs();
        amplitude = 4.0 + (wave1 * 0.45 + wave2 * 0.35 + wave3 * 0.20) * 14.0;
      }

      final start = Offset(
        center.dx + math.cos(angle) * (baseRadius + 2),
        center.dy + math.sin(angle) * (baseRadius + 2),
      );
      final end = Offset(
        center.dx + math.cos(angle) * (baseRadius + 2 + amplitude),
        center.dy + math.sin(angle) * (baseRadius + 2 + amplitude),
      );

      barPaint.color = accentColor.withOpacity(
        isPlaying ? (0.35 + (amplitude / 20.0) * 0.55).clamp(0.3, 0.95) : 0.18,
      );
      canvas.drawLine(start, end, barPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _CircularSpectrumPainter oldDelegate) {
    return oldDelegate.phase != phase ||
        oldDelegate.isPlaying != isPlaying ||
        oldDelegate.accentColor != accentColor;
  }
}

class _VinylGroovesPainter extends CustomPainter {
  final Color accentColor;

  _VinylGroovesPainter({required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = size.width / 2;
    final minRadius = maxRadius * 0.47;

    final groovePaint = Paint()
      ..color = Colors.white.withOpacity(0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (double r = minRadius; r < maxRadius - 6; r += 4.5) {
      canvas.drawCircle(center, r, groovePaint);
    }

    // Accent neon ring inside grooves
    final accentRing = Paint()
      ..color = accentColor.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawCircle(center, maxRadius * 0.76, accentRing);

    // Subtle sheen arc
    final arcPaint = Paint()
      ..color = Colors.white.withOpacity(0.09)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;
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

/// Compact Animated Audio Spectrum Equalizer Bars
/// Used in Mini-Player, Active Song Tiles, and Live Lyrics Header
class MiniAudioSpectrumBars extends StatefulWidget {
  final bool isPlaying;
  final Color color;
  final double height;

  const MiniAudioSpectrumBars({
    super.key,
    required this.isPlaying,
    required this.color,
    this.height = 16,
  });

  @override
  State<MiniAudioSpectrumBars> createState() => _MiniAudioSpectrumBarsState();
}

class _MiniAudioSpectrumBarsState extends State<MiniAudioSpectrumBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.isPlaying) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant MiniAudioSpectrumBars oldWidget) {
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
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value * 2 * math.pi;
          final factors = widget.isPlaying
              ? [
                  0.35 + 0.65 * math.sin(t).abs(),
                  0.25 + 0.75 * math.cos(t * 1.3 + 0.8).abs(),
                  0.40 + 0.60 * math.sin(t * 1.7 + 1.9).abs(),
                  0.30 + 0.70 * math.cos(t * 1.1 + 2.5).abs(),
                ]
              : [0.25, 0.45, 0.30, 0.25];

          return SizedBox(
            height: widget.height,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(4, (i) {
                return Container(
                  width: 2.8,
                  height: (widget.height * factors[i]).clamp(3.0, widget.height),
                  margin: const EdgeInsets.symmetric(horizontal: 1.2),
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }
}
