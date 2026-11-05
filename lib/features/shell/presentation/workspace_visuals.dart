import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/glass.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_repository.dart';

/// The reference hero uses a broad emerald ribbon rather than a mountain
/// illustration. This painter keeps the artwork crisp at desktop and phone sizes.
class HeroRibbonArtwork extends StatelessWidget {
  const HeroRibbonArtwork({super.key});

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(painter: _HeroRibbonPainter()),
    ),
  );
}

class _HeroRibbonPainter extends CustomPainter {
  const _HeroRibbonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRect(bounds);

    final glow = Offset(w * .73, h * .42);
    final glowRadius = math.max(w * .46, h * 1.6);
    canvas.drawCircle(
      glow,
      glowRadius,
      Paint()
        ..shader = RadialGradient(colors: [
          ENetColors.mint.withValues(alpha: .22),
          const Color(0xFF00C78B).withValues(alpha: .09),
          Colors.transparent,
        ]).createShader(Rect.fromCircle(center: glow, radius: glowRadius)),
    );

    final ribbon = Path()
      ..moveTo(w * 1.08, -h * .22)
      ..cubicTo(w * .82, -h * .08, w * .78, h * .20, w * .62, h * .57)
      ..cubicTo(w * .48, h * .91, w * .70, h * .96, w * 1.10, h * .47);

    final bandShader = const LinearGradient(
      begin: Alignment.bottomLeft,
      end: Alignment.topRight,
      colors: [
        Color(0x0000E6A5),
        Color(0xAA00DDA0),
        Color(0xDD39FFD0),
        Color(0x6600A77A),
      ],
      stops: [0, .35, .68, 1],
    ).createShader(bounds);

    canvas.drawPath(ribbon, Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(26, h * .36)
      ..color = ENetColors.mint.withValues(alpha: .18)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 22));

    canvas.drawPath(ribbon, Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = math.max(19, h * .25)
      ..shader = bandShader);

    canvas.drawPath(ribbon, Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.8
      ..color = const Color(0xFF8CFFE4).withValues(alpha: .76));

    final second = Path()
      ..moveTo(w * 1.10, -h * .12)
      ..cubicTo(w * .84, h * .02, w * .80, h * .25, w * .65, h * .62)
      ..cubicTo(w * .51, h * .93, w * .73, h * 1.00, w * 1.10, h * .53);
    canvas.drawPath(second, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = ENetColors.cyan.withValues(alpha: .38));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _HeroRibbonPainter oldDelegate) => false;
}

/// A compact, API-backed snapshot of active account sessions.
class DashboardSessionsSnapshot extends StatefulWidget {
  const DashboardSessionsSnapshot({
    super.key,
    required this.auth,
    required this.onManage,
  });

  final AuthController auth;
  final VoidCallback onManage;

  @override
  State<DashboardSessionsSnapshot> createState() => _DashboardSessionsSnapshotState();
}

class _DashboardSessionsSnapshotState extends State<DashboardSessionsSnapshot> {
  bool _loading = true;
  String? _error;
  List<AccountSession> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final sessions = await widget.auth.listSessions();
      if (!mounted) return;
      setState(() { _sessions = sessions; _loading = false; });
    } catch (_) {
      if (!mounted) return;
      setState(() { _error = 'Не удалось загрузить сеансы'; _loading = false; });
    }
  }

  String _sessionDate(DateTime value) {
    const months = [
      'янв', 'фев', 'мар', 'апр', 'май', 'июн',
      'июл', 'авг', 'сен', 'окт', 'ноя', 'дек',
    ];
    final local = value.toLocal();
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '${local.day} ${months[local.month - 1]}, $hour:$minute';
  }

  @override
  Widget build(BuildContext context) => Glass(
    radius: 18,
    blur: 12,
    padding: const EdgeInsets.fromLTRB(13, 11, 13, 9),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(child: Text('АКТИВНЫЕ СЕАНСЫ', style: TextStyle(
          color: ENetColors.text,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .7,
        ))),
        if (!_loading && _error == null)
          Text('${_sessions.length}', style: const TextStyle(
            color: ENetColors.cyan, fontSize: 11, fontWeight: FontWeight.w800)),
        IconButton(
          tooltip: 'Обновить сеансы',
          onPressed: _loading ? null : _load,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.refresh_rounded, color: ENetColors.cyan, size: 17),
        ),
      ]),
      if (_loading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 10),
          child: LinearProgressIndicator(minHeight: 2),
        )
      else if (_error != null)
        Text(_error!, style: const TextStyle(
          color: ENetColors.muted, fontSize: 11))
      else if (_sessions.isEmpty)
        const Text('Нет активных сеансов', style: TextStyle(
          color: ENetColors.muted, fontSize: 11))
      else
        for (final session in _sessions.take(2))
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Row(children: [
              Icon(
                session.current ? Icons.laptop_mac_rounded : Icons.devices_rounded,
                color: session.current ? ENetColors.mint : ENetColors.muted,
                size: 18,
              ),
              const SizedBox(width: 9),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(session.device, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ENetColors.text,
                      fontSize: 11.5, fontWeight: FontWeight.w700)),
                  Text(
                    'Последняя активность · ${_sessionDate(session.lastSeenAt)}',
                    style: const TextStyle(color: ENetColors.muted, fontSize: 9.5)),
                ],
              )),
              const Icon(Icons.chevron_right_rounded,
                color: ENetColors.cyan, size: 18),
            ]),
          ),
      const SizedBox(height: 7),
      Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onManage,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Icon(Icons.devices_rounded, color: ENetColors.cyan, size: 15),
              SizedBox(width: 8),
              Expanded(child: Text('Управление сеансами', style: TextStyle(
                color: ENetColors.cyan, fontSize: 10.5, fontWeight: FontWeight.w700))),
              Icon(Icons.chevron_right_rounded, color: ENetColors.cyan, size: 17),
            ]),
          ),
        ),
      ),
    ]),
  );
}

class MobileWelcomeScene extends StatelessWidget {
  const MobileWelcomeScene({super.key, required this.name, required this.onOpenProfile});
  final String name;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onOpenProfile,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        height: 235,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ENetColors.cyan.withValues(alpha: .08)),
        ),
        child: Stack(fit: StackFit.expand, children: [
          const CustomPaint(painter: _MobileMountainPainter()),
          const Positioned(
            top: 8, left: 0, right: 0,
            child: Center(child: ENetMark(size: 46)),
          ),
          Positioned(
            left: 18, right: 55, bottom: 17,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Добро пожаловать,', style: TextStyle(
                  color: ENetColors.text,
                  fontSize: 16, fontWeight: FontWeight.w600)),
                Text('$name 👋', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ENetColors.text,
                    fontSize: 23, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
          const Positioned(
            right: 16, bottom: 20,
            child: Icon(Icons.arrow_forward_ios_rounded,
              color: ENetColors.cyan, size: 16),
          ),
        ]),
      ),
    ),
  );
}

/// Layered alpine valley artwork based on the approved phone reference.
/// Entirely rendered in Flutter so it scales cleanly without external images.
class _MobileMountainPainter extends CustomPainter {
  const _MobileMountainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRect(bounds);
    canvas.drawRect(bounds, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      stops: [0.0, .42, .7, 1.0],
      colors: [
        Color(0xFF03131D),
        Color(0xFF0B3540),
        Color(0xFF17535B),
        Color(0xFF051617),
      ],
    ).createShader(bounds));

    final dawn = Offset(w * .52, h * .57);
    canvas.drawCircle(dawn, w * .65,
      Paint()..shader = RadialGradient(colors: [
        const Color(0xFF7BDFE3).withValues(alpha: .29),
        const Color(0xFF1897A4).withValues(alpha: .12),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: dawn, radius: w * .65)));

    void ridge(List<Offset> points, Color color) {
      final path = Path()..moveTo(0, h);
      for (final p in points) {
        path.lineTo(p.dx * w, p.dy * h);
      }
      path..lineTo(w, h)..close();
      canvas.drawPath(path, Paint()..color = color);
    }

    // Distant snowy ridges create the deep mountain valley from the reference.
    ridge(const [
      Offset(0, .64), Offset(.11, .48), Offset(.18, .54),
      Offset(.29, .40), Offset(.38, .56), Offset(.47, .51),
      Offset(.58, .59), Offset(.69, .43), Offset(.76, .50),
      Offset(.88, .38), Offset(1, .54),
    ], const Color(0xFF3B7480));
    ridge(const [
      Offset(0, .73), Offset(.14, .52), Offset(.21, .59),
      Offset(.31, .47), Offset(.40, .62), Offset(.50, .58),
      Offset(.60, .64), Offset(.72, .50), Offset(.82, .58),
      Offset(.92, .47), Offset(1, .60),
    ], const Color(0xFF245B65));

    final snow = Paint()..color = const Color(0xFFB6E9E8).withValues(alpha: .33);
    canvas.drawPath(Path()
      ..moveTo(w * .28, h * .43)..lineTo(w * .32, h * .49)
      ..lineTo(w * .30, h * .47)..lineTo(w * .23, h * .54)
      ..lineTo(w * .28, h * .43)..close(), snow);
    canvas.drawPath(Path()
      ..moveTo(w * .88, h * .38)..lineTo(w * .92, h * .49)
      ..lineTo(w * .87, h * .45)..lineTo(w * .81, h * .54)
      ..lineTo(w * .88, h * .38)..close(), snow);

    ridge(const [
      Offset(0, .53), Offset(.07, .58), Offset(.16, .70),
      Offset(.23, .66), Offset(.35, .82), Offset(.49, .88),
      Offset(.58, .83), Offset(.68, .73), Offset(.79, .63),
      Offset(.9, .55), Offset(1, .60),
    ], const Color(0xFF123B42));
    ridge(const [
      Offset(0, .64), Offset(.09, .70), Offset(.18, .79),
      Offset(.28, .83), Offset(.40, .95), Offset(.53, 1.0),
      Offset(.65, .90), Offset(.80, .77), Offset(.91, .70),
      Offset(1, .68),
    ], const Color(0xFF092B31));

    final mist = Rect.fromLTWH(0, h * .60, w, h * .36);
    canvas.drawRect(mist, Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [
        const Color(0xFF91D9D7).withValues(alpha: .12),
        const Color(0xFF073031).withValues(alpha: .04),
        const Color(0xFF021314).withValues(alpha: .82),
      ],
    ).createShader(mist));
    canvas.drawRect(bounds, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      stops: [0, .48, 1],
      colors: [Color(0x22020F10), Color(0x00020F10), Color(0xF0031010)],
    ).createShader(bounds));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MobileMountainPainter oldDelegate) => false;
}

