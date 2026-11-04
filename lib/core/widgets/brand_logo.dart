import 'package:flutter/material.dart';
import '../theme/enet_theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 58, this.showName = true});
  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .28),
          border: Border.all(color: Colors.white.withValues(alpha: .18)),
          boxShadow: [
            BoxShadow(color: ENetColors.blue.withValues(alpha: .35), blurRadius: size * .7, offset: Offset(0, size * .18)),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Image.asset('assets/enet_logo.jpg', fit: BoxFit.cover),
      ),
      if (showName) ...[
        SizedBox(width: size * .26),
        Text(
          'eNet',
          style: TextStyle(
            color: ENetColors.text,
            fontSize: size * .5,
            fontWeight: FontWeight.w800,
            letterSpacing: -size * .03,
          ),
        ),
      ],
    ]);
  }
}

/// Круглый аватар с градиентным кольцом и первой буквой имени.
class ENetAvatar extends StatelessWidget {
  const ENetAvatar({super.key, required this.name, this.size = 40});
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().isEmpty ? 'E' : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * .045),
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: SweepGradient(colors: [ENetColors.cyan, ENetColors.blue, ENetColors.violet, ENetColors.cyan]),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0B1424)),
        child: Center(
          child: Text(
            initial,
            style: TextStyle(fontSize: size * .42, fontWeight: FontWeight.w800, color: ENetColors.text),
          ),
        ),
      ),
    );
  }
}
