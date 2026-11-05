import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import '../theme/enet_theme.dart';

/// «Матовое стекло» в стиле visionOS / Fluent Acrylic: размытие фона,
/// тонкий светлый контур и мягкая глубокая тень.
class Glass extends StatelessWidget {
  const Glass({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.radius = 22,
    this.blur = 16,
    this.strength = 1,
    this.shadow = true,
    this.tint,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final double strength;
  final bool shadow;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final r = BorderRadius.circular(radius);
    final base = tint ?? ENetColors.mint;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: r,
        boxShadow: shadow
            ? const [BoxShadow(color: Color(0x44000000), blurRadius: 24, offset: Offset(0, 10))]
            : null,
      ),
      child: ClipRRect(
        borderRadius: r,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: r,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  base.withValues(alpha: .075 * strength),
                  ENetColors.surface.withValues(alpha: .93),
                ],
              ),
              border: Border.all(color: ENetColors.mint.withValues(alpha: .12)),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
