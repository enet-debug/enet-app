import 'package:flutter/material.dart';
import '../theme/enet_theme.dart';

/// The mint italic "e" from the supplied eNet App visual reference.
/// Its vector outline is traced from the reference, without a square
/// thumbnail, background, bitmap color filter or external font dependency.
class ENetMark extends StatelessWidget {
  const ENetMark({super.key, this.size = 58});
  final double size;

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'Логотип eNet',
    image: true,
    child: SizedBox(
      width: size,
      height: size,
      child: const CustomPaint(painter: _ENetMarkPainter()),
    ),
  );
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.size = 58, this.showName = true});

  final double size;
  final bool showName;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ENetMark(size: size),
      if (showName) ...[
        SizedBox(width: size * .14),
        Text(
          'eNet',
          style: TextStyle(
            color: ENetColors.text,
            fontSize: size * .53,
            fontWeight: FontWeight.w800,
            letterSpacing: -size * .025,
          ),
        ),
      ],
    ],
  );
}

class _ENetMarkPainter extends CustomPainter {
  const _ENetMarkPainter();

  // Coordinates are scaled into a 76×76 viewBox. A rounded quadratic path
  // reproduces the characteristic open tail and loop of the reference e.
  static const List<Offset> _outline = [
    Offset(66,6), Offset(56,3), Offset(41,5), Offset(34,8),
    Offset(25,14), Offset(16,23), Offset(11,30), Offset(3,30),
    Offset(2,31), Offset(9,35), Offset(6,43), Offset(6,56),
    Offset(9,62), Offset(14,67), Offset(23,71), Offset(38,71),
    Offset(42,69), Offset(45,69), Offset(57,62), Offset(63,57),
    Offset(70,49), Offset(71,46), Offset(68,46), Offset(57,53),
    Offset(47,58), Offset(40,60), Offset(28,60), Offset(24,58),
    Offset(19,52), Offset(19,41), Offset(21,38), Offset(31,41),
    Offset(45,42), Offset(46,41), Offset(55,40), Offset(67,33),
    Offset(72,26), Offset(73,23), Offset(73,15), Offset(71,11),
  ];

  static const List<Offset> _counter = [
    Offset(61,19), Offset(60,23), Offset(53,30), Offset(51,30),
    Offset(48,32), Offset(37,33), Offset(36,34), Offset(29,34),
    Offset(23,32), Offset(32,21), Offset(41,15), Offset(47,13),
    Offset(56,13),
  ];

  static Path _makeGlyph() {
    final path = Path()..fillType = PathFillType.evenOdd;
    for (final contour in [_outline, _counter]) {
      Offset midpoint(Offset a, Offset b) =>
          Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);

      path.moveTo(
        midpoint(contour.last, contour.first).dx,
        midpoint(contour.last, contour.first).dy,
      );
      for (var i = 0; i < contour.length; i++) {
        final point = contour[i];
        final next = contour[(i + 1) % contour.length];
        final end = midpoint(point, next);
        path.quadraticBezierTo(point.dx, point.dy, end.dx, end.dy);
      }
      path.close();
    }
    return path;
  }

  static final Path _glyph = _makeGlyph();

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 76, size.height / 76);

    canvas.drawShadow(
      _glyph,
      ENetColors.mint.withValues(alpha: .22),
      2,
      false,
    );
    final paint = Paint()
      ..isAntiAlias = true
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFF14CDB4),
          Color(0xFF24F4CD),
          Color(0xFF76FFC3),
        ],
        stops: [0, .5, 1],
      ).createShader(const Rect.fromLTWH(0, 0, 76, 76));
    canvas.drawPath(_glyph, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _ENetMarkPainter oldDelegate) => false;
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
        gradient: SweepGradient(colors: [ENetColors.cyan, ENetColors.blue, ENetColors.mint, ENetColors.cyan]),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Color(0xFF0D211B)),
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
