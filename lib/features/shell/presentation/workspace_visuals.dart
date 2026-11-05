import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/enet_theme.dart';
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
        height: 177,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ENetColors.cyan.withValues(alpha: .23)),
        ),
        child: Stack(fit: StackFit.expand, children: [
          const CustomPaint(painter: _MobileMountainPainter()),
          const Positioned(
            top: 8, left: 0, right: 0,
            child: Center(child: Icon(Icons.auto_awesome_rounded,
              color: ENetColors.cyan, size: 21)),
          ),
          Positioned(
            left: 18, right: 55, bottom: 17,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Добро пожаловать,', style: TextStyle(
                  color: ENetColors.text,
                  fontSize: 16, fontWeight: FontWeight.w600)),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
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

class _MobileMountainPainter extends CustomPainter {
  const _MobileMountainPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final w = size.width, h = size.height;
    canvas.drawRect(bounds, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color(0xFF071B23),
        Color(0xFF154951),
        Color(0xFF092522),
        Color(0xFF03110F),
      ],
    ).createShader(bounds));
    final glow = Offset(w * .53, h * .35);
    canvas.drawCircle(glow, w * .45,
      Paint()..shader = RadialGradient(colors: [
        ENetColors.cyan.withValues(alpha: .3),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: glow, radius: w * .45)));

    for (final (phase, peak, base, color) in <(double,double,double,Color)>[
      (.2,.18,.62,Color(0xFF2D7377)),
      (1.6,.15,.72,Color(0xFF1B4E51)),
      (3.0,.10,.84,Color(0xFF0C2E30)),
      (2.2,.06,.93,Color(0xFF071B1C)),
    ]) {
      final ridge = Path()..moveTo(0,h)..lineTo(0,h*base);
      for (var i=0; i<=36; i++) {
        final t=i/36.0;
        final undulation=math.sin(t*math.pi*4.5+phase)*h*peak;
        final peaks=math.pow(math.sin(t*math.pi*7.5+phase),5).toDouble()*h*peak*.4;
        ridge.lineTo(w*t,h*base-undulation-peaks);
      }
      ridge..lineTo(w,h)..close();
      canvas.drawPath(ridge,Paint()..color=color);
    }
    canvas.drawRect(bounds,Paint()..shader=const LinearGradient(
      begin: Alignment.topCenter,end:Alignment.bottomCenter,
      colors:[Color(0x00031212),Color(0xC4031212)],
    ).createShader(bounds));
  }

  @override
  bool shouldRepaint(covariant _MobileMountainPainter oldDelegate)=>false;
}
