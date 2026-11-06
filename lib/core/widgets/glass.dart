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
    this.radius = 18,
    this.blur = 19,
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
            ? [
                const BoxShadow(color: Color(0x76000208), blurRadius: 26, offset: Offset(0, 12)),
                BoxShadow(color: base.withValues(alpha: .11 * strength), blurRadius: 29),
              ]
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
                  base.withValues(alpha: .19 * strength),
                  ENetColors.surfaceRaised.withValues(alpha: .74),
                  ENetColors.surface.withValues(alpha: .94),
                ],
                stops: const [0, .35, 1],
              ),
              border: Border.all(color: base.withValues(alpha: .36 * strength), width: .9),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}
