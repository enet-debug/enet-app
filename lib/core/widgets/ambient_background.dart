import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/enet_theme.dart';

class AmbientBackground extends StatefulWidget {
  const AmbientBackground({super.key, required this.child});
  final Widget child;
  @override
  State<AmbientBackground> createState() => _AmbientBackgroundState();
}

class _AmbientBackgroundState extends State<AmbientBackground> with SingleTickerProviderStateMixin {
  late final AnimationController animation = AnimationController(vsync: this, duration: const Duration(seconds: 18))..repeat();
  @override
  void dispose() { animation.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return Stack(fit: StackFit.expand, children: [
      const ColoredBox(color: ENetColors.background),
      IgnorePointer(child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) => CustomPaint(painter: _OrbitsPainter(reduceMotion ? 0 : animation.value)),
      )),
      widget.child,
    ]);
  }
}

class _OrbitsPainter extends CustomPainter {
  const _OrbitsPainter(this.t);
  final double t;
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .83, size.height * .3);
    final radius = math.min(size.width * .31, 330.0);
    final glow = Paint()..shader = RadialGradient(colors: [ENetColors.blue.withValues(alpha: .18), Colors.transparent]).createShader(Rect.fromCircle(center: center, radius: radius * 2));
    canvas.drawCircle(center, radius * 2, glow);
    for (var i = 0; i < 3; i++) {
      final circlePaint = Paint()..style = PaintingStyle.stroke..strokeWidth = i == 0 ? 1.5 : .8..color = ENetColors.cyan.withValues(alpha: i == 0 ? .24 : .11);
      canvas.drawCircle(center, radius * (.7 + .34 * i), circlePaint);
    }
    final theta = (t * math.pi * 2) - .4;
    final point = center + Offset(math.cos(theta) * radius, math.sin(theta) * radius);
    canvas.drawCircle(point, 9, Paint()..color = ENetColors.cyan.withValues(alpha: .22)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 13));
    canvas.drawCircle(point, 3.5, Paint()..color = ENetColors.cyan);
    for (var i = 0; i < 21; i++) {
      final x = (i * 127.3) % size.width;
      final y = (i * 79.7) % size.height;
      canvas.drawCircle(Offset(x, y), i % 4 == 0 ? 1.4 : .7, Paint()..color = ENetColors.cyan.withValues(alpha: i % 4 == 0 ? .38 : .15));
    }
  }
  @override
  bool shouldRepaint(covariant _OrbitsPainter oldDelegate) => oldDelegate.t != t;
}
