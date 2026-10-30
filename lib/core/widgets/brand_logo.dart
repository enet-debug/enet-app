import 'package:flutter/material.dart';
import '../theme/enet_theme.dart';

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 58, this.showName = true});
  final double size;
  final bool showName;
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: size, height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * .27),
        border: Border.all(color: ENetColors.cyan.withValues(alpha: .4)),
        boxShadow: [BoxShadow(color: ENetColors.blue.withValues(alpha: .2), blurRadius: 27)],
      ),
      clipBehavior: Clip.antiAlias,
      child: Image.asset('assets/enet_logo.jpg', fit: BoxFit.cover),
    ),
    if (showName) ...[
      const SizedBox(width: 13),
      const Text('eNet', style: TextStyle(color: ENetColors.text, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -1.5)),
    ],
  ]);
}
