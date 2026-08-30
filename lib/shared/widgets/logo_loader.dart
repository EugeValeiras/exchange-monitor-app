import 'package:flutter/material.dart';

/// Animated logo loader widget that matches the webapp design.
/// Shows a chart icon with animated trend line and data points.
class LogoLoader extends StatefulWidget {
  final double size;
  final bool showText;
  final String text;
  final bool float;

  const LogoLoader({
    super.key,
    this.size = 64,
    this.showText = true,
    this.text = 'Cargando...',
    this.float = true,
  });

  @override
  State<LogoLoader> createState() => _LogoLoaderState();
}

class _LogoLoaderState extends State<LogoLoader> with TickerProviderStateMixin {
  late AnimationController _floatController;
  late AnimationController _lineController;
  late AnimationController _pulseController;
  late Animation<double> _floatAnimation;
  late Animation<double> _lineAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();

    // Float animation (up and down)
    _floatController = AnimationController(
      duration: const Duration(milliseconds: 3000),
      vsync: this,
    );
    _floatAnimation = Tween<double>(begin: 0, end: 6).animate(
      CurvedAnimation(parent: _floatController, curve: Curves.easeInOut),
    );
    if (widget.float) {
      _floatController.repeat(reverse: true);
    }

    // Line drawing animation (repeating)
    _lineController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _lineAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _lineController, curve: Curves.easeOut),
    );
    _lineController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _lineController.reset();
            _lineController.forward();
          }
        });
      }
    });
    _lineController.forward();

    // Pulse animation for glow effect
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    _pulseController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatController.dispose();
    _lineController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_floatAnimation, _lineAnimation, _pulseAnimation]),
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Transform.translate(
              offset: Offset(0, widget.float ? -_floatAnimation.value : 0),
              child: CustomPaint(
                size: Size(widget.size, widget.size),
                painter: _LogoPainter(
                  lineProgress: _lineAnimation.value,
                  pulseValue: _pulseAnimation.value,
                ),
              ),
            ),
            if (widget.showText) ...[
              SizedBox(height: widget.size * 0.15),
              Opacity(
                opacity: 0.7 + (_pulseAnimation.value * 0.3),
                child: Text(
                  widget.text,
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: widget.size * 0.18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _LogoPainter extends CustomPainter {
  final double lineProgress;
  final double pulseValue;

  /// El cian del logotipo. Es el ÚNICO color de marca que sobrevive en la app,
  /// y sólo acá: en el splash y en la puerta de entrada. Dentro del producto no
  /// aparece nunca — el resto de la interfaz deja el color libre para el dinero
  /// (ver EmColors).
  static const Color accentColor = Color(0xFF00C2FF);

  _LogoPainter({
    required this.lineProgress,
    required this.pulseValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 64;

    // Border rectangle with pulse
    final borderPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.12 + (pulseValue * 0.13))
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale;

    final borderRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(6 * scale, 6 * scale, 52 * scale, 52 * scale),
      Radius.circular(14 * scale),
    );
    canvas.drawRRect(borderRect, borderPaint);

    // Grid lines
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2 * scale
      ..strokeCap = StrokeCap.round;

    canvas.drawLine(
      Offset(18 * scale, 44 * scale),
      Offset(46 * scale, 44 * scale),
      gridPaint,
    );

    gridPaint.color = Colors.white.withValues(alpha: 0.06);
    canvas.drawLine(
      Offset(18 * scale, 32 * scale),
      Offset(42 * scale, 32 * scale),
      gridPaint,
    );

    // Trend line points
    final points = [
      Offset(18 * scale, 40 * scale),
      Offset(28 * scale, 30 * scale),
      Offset(36 * scale, 34 * scale),
      Offset(46 * scale, 22 * scale),
    ];

    // Calculate path length for animation
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    // Draw glow effect
    final glowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.3 * pulseValue)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 4 * scale);

    // Draw animated line with glow
    final animatedPath = _getAnimatedPath(path, lineProgress);
    canvas.drawPath(animatedPath, glowPaint);

    // Draw the main trend line
    final linePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4 * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(animatedPath, linePaint);

    // Draw data points with staggered animation
    final pointPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    final pointGlowPaint = Paint()
      ..color = accentColor.withValues(alpha: 0.4 * pulseValue)
      ..style = PaintingStyle.fill
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 3 * scale);

    for (int i = 0; i < points.length; i++) {
      // Each point appears at different progress values
      final pointProgress = ((lineProgress - (i * 0.2)).clamp(0.0, 0.3) / 0.3);
      if (pointProgress > 0) {
        final pointScale = pointProgress * (1 + (pulseValue - 0.5) * 0.15);
        final radius = 3.2 * scale * pointScale;

        // Draw glow
        canvas.drawCircle(points[i], radius + 2 * scale, pointGlowPaint);
        // Draw point
        canvas.drawCircle(points[i], radius, pointPaint);
      }
    }
  }

  Path _getAnimatedPath(Path originalPath, double progress) {
    if (progress <= 0) return Path();
    final pathMetrics = originalPath.computeMetrics().toList();
    if (pathMetrics.isEmpty) return Path();
    final metrics = pathMetrics.first;
    final length = metrics.length * progress;
    return metrics.extractPath(0, length);
  }

  @override
  bool shouldRepaint(covariant _LogoPainter oldDelegate) {
    return oldDelegate.lineProgress != lineProgress ||
        oldDelegate.pulseValue != pulseValue;
  }
}
