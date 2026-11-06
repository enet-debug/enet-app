import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/enet_theme.dart';

/// Живой фон: медленно дрейфующие световые пятна («аврора») и тонкая орбита.
/// Цикл бесшовный, учитывает системную настройку «уменьшить движение».
class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key, required this.child, this.animated = true});
  final Widget child;
  final bool animated;

  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 48));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant AmbientBackground oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  void _sync() {
    final run = widget.animated && !MediaQuery.disableAnimationsOf(context);
    if (run && !_controller.isAnimating) _controller.repeat();
    if (!run && _controller.isAnimating) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: ENetColors.background),
      RepaintBoundary(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, _) => CustomPaint(
              painter: _AuroraPainter(_controller.value),
              size: Size.infinite,
            ),
          ),
        ),
      ),
      widget.child,
    ]);
  }
}

class _AuroraPainter extends CustomPainter {
  const _AuroraPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final longest = math.max(w, h);

    // (цвет, x, y, радиус, обороты за цикл, фаза, прозрачность)
    final blobs = <(Color, double, double, double, int, double, double)>[
      (ENetColors.mint, .94, .06, .64, 1, .00, .23),
      (const Color(0xFF00E8B3), .02, .88, .60, 2, .33, .11),
      (ENetColors.cyan, .48, 1.02, .46, 1, .66, .12),
    ];
    for (final (color, bx, by, rf, k, phase, alpha) in blobs) {
      final a = (t * k + phase) * math.pi * 2;
      final c = Offset(w * bx + math.cos(a) * w * .06, h * by + math.sin(a) * h * .06);
      final radius = longest * rf;
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [
            color.withValues(alpha: alpha * (w < 820 ? .55 : 1.0)),
            color.withValues(alpha: 0),
          ])
              .createShader(Rect.fromCircle(center: c, radius: radius)),
      );
    }

    // The supplied desktop reference uses open, cinematic light ribbons.
    // Avoid the three concentric circles that read as an unrelated target icon.
    if (w >= 820) {
      final upper = Path()
        ..moveTo(w * .46, h * .29)
        ..cubicTo(w * .61, h * .33, w * .63, h * .04, w * .77, h * .06)
        ..cubicTo(w * .87, h * .07, w * .93, -h * .12, w * 1.10, -h * .16);
      final lower = Path()
        ..moveTo(-w * .12, h * 1.01)
        ..cubicTo(w * .23, h * .91, w * .29, h * .63, w * .53, h * .60)
        ..cubicTo(w * .70, h * .57, w * .74, h * .30, w * .94, h * .19);
      for (final (path, alpha) in [(upper, .90), (lower, .35)]) {
        canvas.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 54
          ..color = ENetColors.mint.withValues(alpha: .25 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 27));
        canvas.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round
          ..strokeWidth = 10
          ..color = ENetColors.cyan.withValues(alpha: .25 * alpha)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13));
        canvas.drawPath(path, Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = const Color(0xFF66FFE5).withValues(alpha: .70 * alpha));
      }
      final star = Offset(w * .76 + math.cos(t * 2 * math.pi) * 12, h * .06);
      canvas.drawCircle(star, 6, Paint()
        ..color = ENetColors.mint.withValues(alpha: .24)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13));
    }
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => oldDelegate.t != t;
}
