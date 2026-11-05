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
      (ENetColors.blue, .90, .08, .60, 1, .00, .20),
      (ENetColors.violet, .02, .90, .58, 2, .33, .09),
      (ENetColors.mint, .52, 1.0, .40, 1, .66, .10),
    ];
    for (final (color, bx, by, rf, k, phase, alpha) in blobs) {
      final a = (t * k + phase) * math.pi * 2;
      final c = Offset(w * bx + math.cos(a) * w * .06, h * by + math.sin(a) * h * .06);
      final radius = longest * rf;
      canvas.drawCircle(
        c,
        radius,
        Paint()
          ..shader = RadialGradient(colors: [color.withValues(alpha: alpha), color.withValues(alpha: 0)])
              .createShader(Rect.fromCircle(center: c, radius: radius)),
      );
    }

    // Тонкая орбита — фирменный мотив eNet.
    final center = Offset(w * .84, h * .26);
    final r = math.min(math.min(w * .3, 320.0), h * .5);
    for (var i = 0; i < 3; i++) {
      canvas.drawCircle(
        center,
        r * (.7 + .34 * i),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == 0 ? 1.2 : .7
          ..color = ENetColors.cyan.withValues(alpha: i == 0 ? .16 : .06),
      );
    }
    final theta = t * math.pi * 2 - .4;
    final p = center + Offset(math.cos(theta) * r, math.sin(theta) * r);
    canvas.drawCircle(
      p,
      9,
      Paint()
        ..color = ENetColors.cyan.withValues(alpha: .25)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12),
    );
    canvas.drawCircle(p, 3, Paint()..color = ENetColors.cyan);
  }

  @override
  bool shouldRepaint(covariant _AuroraPainter oldDelegate) => oldDelegate.t != t;
}
