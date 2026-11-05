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
    final w = size.width, h = size.height;
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRect(bounds);

    // The reference hero has a thin luminous S-shaped ribbon, with its light
    // reflecting into the surrounding dark glass. Avoid a solid green strip.
    final lightCenter = Offset(w * .77, h * .22);
    final radius = w * .52;
    canvas.drawCircle(lightCenter, radius,
      Paint()..shader = RadialGradient(colors: [
        const Color(0xFF20FBB5).withValues(alpha: .38),
        const Color(0xFF03AD80).withValues(alpha: .10),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: lightCenter, radius: radius)));

    final primary = Path()
      ..moveTo(w * 1.07, -h * .41)
      ..cubicTo(w * .93, h * .02, w * .67, h * .01, w * .61, h * .40)
      ..cubicTo(w * .50, h * .93, w * .75, h * 1.06, w * 1.10, h * .54);
    final secondary = Path()
      ..moveTo(w * 1.13, -h * .29)
      ..cubicTo(w * .93, h * .20, w * .75, h * .18, w * .65, h * .57)
      ..cubicTo(w * .55, h * .94, w * .81, h * 1.09, w * 1.08, h * .67);

    // Four layers of wide soft light taper into a razor-thin white highlight.
    for (final (double width, double alpha, double blur) in [
      (h * .34, .15, 24.0),
      (h * .20, .26, 12.0),
      (h * .095, .34, 6.0),
    ]) {
      canvas.drawPath(primary, Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = width
        ..color = const Color(0xFF06FFA9).withValues(alpha: alpha)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur));
    }

    final sweep = const LinearGradient(
      begin: Alignment.topRight,
      end: Alignment.bottomLeft,
      stops: [0.0, .22, .48, .71, 1.0],
      colors: [
        Color(0x0037FFD8),
        Color(0x8844FFE1),
        Color(0xEE27F8B0),
        Color(0x9946FFC7),
        Color(0x0015A77B),
      ],
    ).createShader(bounds);
    canvas.drawPath(primary, Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = h * .085
      ..shader = sweep);
    canvas.drawPath(primary, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.3
      ..color = const Color(0xFFD1FFEF).withValues(alpha: .86)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5));
    canvas.drawPath(primary, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFEEFFF8).withValues(alpha: .92));
    canvas.drawPath(secondary, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = const Color(0xFF7EFFE4).withValues(alpha: .55));
    canvas.drawPath(secondary, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = h * .07
      ..color = const Color(0xFF19EAC0).withValues(alpha: .16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9));

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
                Row(children: [
                  Flexible(child: Text(name,
                    maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ENetColors.text,
                      fontSize: 23, fontWeight: FontWeight.w800))),
                  const SizedBox(width: 7),
                  const Icon(Icons.waving_hand_rounded,
                    color: Color(0xFFFFC15B), size: 19),
                ]),
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
    final w = size.width, h = size.height;
    final bounds = Offset.zero & size;
    canvas.save();
    canvas.clipRect(bounds);

    // Deep turquoise dawn, with a cool glow coming through the distant pass.
    canvas.drawRect(bounds, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      stops: [0, .34, .62, 1],
      colors: [
        Color(0xFF02101D), Color(0xFF082A39),
        Color(0xFF1B5260), Color(0xFF04171B),
      ],
    ).createShader(bounds));
    final light = Offset(w * .51, h * .51);
    canvas.drawCircle(light, w * .64, Paint()..shader = RadialGradient(
      stops: const [0, .42, 1],
      colors: [
        const Color(0xFFB7FCF0).withValues(alpha: .37),
        const Color(0xFF4EC5C5).withValues(alpha: .15),
        Colors.transparent,
      ],
    ).createShader(Rect.fromCircle(center: light, radius: w * .64)));

    // A gently irregular mountain skyline. All shapes are generated at paint
    // time, stay crisp at device pixel ratio, and never rely on stock photos.
    Path mountain(List<Offset> peaks) {
      final path = Path()..moveTo(0, h);
      for(final point in peaks) {
        path.lineTo(point.dx * w, point.dy * h);
      }
      return path..lineTo(w, h)..close();
    }
    final far = mountain(const [
      Offset(0,.46), Offset(.07,.51), Offset(.13,.41),
      Offset(.17,.46), Offset(.25,.35), Offset(.30,.46),
      Offset(.37,.40), Offset(.42,.54), Offset(.51,.59),
      Offset(.58,.53), Offset(.64,.42), Offset(.69,.48),
      Offset(.73,.41), Offset(.79,.33), Offset(.86,.46),
      Offset(.92,.38), Offset(1,.49),
    ]);
    canvas.drawPath(far, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFF6EABB4),Color(0xFF265D6B)],
    ).createShader(bounds));

    // Pale snow patches make ridges legible without the hard triangular look
    // of the previous placeholder terrain.
    final snow = Paint()..color = const Color(0xFFBCE9E6).withValues(alpha: .50);
    for(final peaks in <List<Offset>>[
      [const Offset(.25,.35),const Offset(.275,.385),const Offset(.25,.373),const Offset(.21,.425)],
      [const Offset(.79,.33),const Offset(.815,.405),const Offset(.787,.382),const Offset(.74,.42)],
      [const Offset(.13,.41),const Offset(.151,.456),const Offset(.126,.439),const Offset(.105,.47)],
      [const Offset(.92,.38),const Offset(.943,.439),const Offset(.917,.42),const Offset(.89,.45)],
    ]) {
      final snowcap = Path()..moveTo(peaks.first.dx*w,peaks.first.dy*h);
      for (final p in peaks.skip(1)) {
        snowcap.lineTo(p.dx * w, p.dy * h);
      }
      canvas.drawPath(snowcap..close(),snow);
    }

    // A narrow valley opening draws the eye into the horizon, like the source
    // reference. Layers gradually darken and soften toward the foreground.
    final mid = mountain(const [
      Offset(0,.28), Offset(.05,.35), Offset(.11,.43),
      Offset(.16,.49), Offset(.23,.53), Offset(.32,.59),
      Offset(.41,.67), Offset(.51,.69), Offset(.60,.66),
      Offset(.67,.59), Offset(.77,.51), Offset(.85,.43),
      Offset(.92,.32), Offset(1,.29),
    ]);
    canvas.drawPath(mid, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter,end: Alignment.bottomCenter,
      colors: [Color(0xFF1B4858),Color(0xFF082C36)],
    ).createShader(bounds));

    final sideLeft = mountain(const [
      Offset(0,.26),Offset(.04,.30),Offset(.10,.37),
      Offset(.18,.48),Offset(.26,.57),Offset(.34,.66),
      Offset(.41,.73),Offset(.53,.82),Offset(.62,.91),
      Offset(1,1.02),
    ]);
    canvas.drawPath(sideLeft, Paint()..shader = const LinearGradient(
      begin: Alignment.topLeft,end: Alignment.bottomRight,
      colors: [Color(0xFF0C3342),Color(0xFF031D27)],
    ).createShader(bounds));

    final sideRight = mountain(const [
      Offset(0,1.03),Offset(.42,.94),Offset(.52,.82),
      Offset(.63,.74),Offset(.70,.64),Offset(.79,.50),
      Offset(.87,.38),Offset(.94,.28),Offset(1,.22),
    ]);
    canvas.drawPath(sideRight, Paint()..shader = const LinearGradient(
      begin: Alignment.topRight,end: Alignment.bottomLeft,
      colors: [Color(0xFF163D4A),Color(0xFF031C27)],
    ).createShader(bounds));

    // Glacial mist: horizontal soft translucent wisps across the pass.
    for(final (double y,double alpha,double span) in [
      (.59,.18,.038),(.66,.14,.030),(.72,.11,.041),(.79,.09,.040),
    ]) {
      final fog = Rect.fromLTWH(-w*.06,h*y,w*1.12,h*span);
      canvas.drawOval(fog,Paint()
        ..color = const Color(0xFFA7E4E0).withValues(alpha: alpha)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14));
    }
    canvas.drawRect(bounds,Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter,end: Alignment.bottomCenter,
      stops:[0,.45,.70,1],
      colors:[
        Color(0x16010814),Color(0x08010814),
        Color(0xA9031419),Color(0xFC01151A),
      ],
    ).createShader(bounds));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _MobileMountainPainter oldDelegate) => false;
}

// Procedural cosmic orb from the original dashboard reference.
// It is abstract artwork, not a profile photograph.
class DashboardNebulaAvatar extends StatelessWidget {
  const DashboardNebulaAvatar({super.key, this.size = 48});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size, height: size,
    child: const RepaintBoundary(child: CustomPaint(
      painter: _DashboardNebulaPainter())),
  );
}

class _DashboardNebulaPainter extends CustomPainter {
  const _DashboardNebulaPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final center = Offset(size.width * .5, size.height * .5);
    canvas.save();
    canvas.clipPath(Path()..addOval(bounds));
    canvas.drawRect(bounds, Paint()..shader = const RadialGradient(
      center: Alignment(-.2, .1), radius: 1.0,
      colors: [Color(0xFF6938B8), Color(0xFF1E1F5D), Color(0xFF011E24)],
    ).createShader(bounds));

    final warm = Offset(size.width * .31, size.height * .63);
    canvas.drawCircle(warm, size.width * .39,
      Paint()..shader = RadialGradient(colors: [
        const Color(0xFFE76BE6).withValues(alpha: .82),
        const Color(0xFF7347F2).withValues(alpha: .25),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: warm, radius: size.width * .39)));
    final cool = Offset(size.width * .69, size.height * .26);
    canvas.drawCircle(cool, size.width * .36,
      Paint()..shader = RadialGradient(colors: [
        const Color(0xFF63FEE1).withValues(alpha: .8),
        const Color(0xFF3199C5).withValues(alpha: .12),
        Colors.transparent,
      ]).createShader(Rect.fromCircle(center: cool, radius: size.width * .36)));

    final trail = Path()
      ..moveTo(size.width * .05, size.height * .82)
      ..cubicTo(size.width * .36, size.height * .45,
        size.width * .70, size.height * .72,
        size.width * .95, size.height * .12);
    canvas.drawPath(trail, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * .04
      ..color = const Color(0xFFB3FFF1).withValues(alpha: .72)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    for (final p in const [
      Offset(.13, .28), Offset(.74, .15), Offset(.82, .46),
      Offset(.20, .81), Offset(.61, .77), Offset(.46, .34),
    ]) {
      canvas.drawCircle(Offset(p.dx * size.width, p.dy * size.height),
        size.width * .013, Paint()..color = const Color(0xFFE3FFFC));
    }
    canvas.restore();
    canvas.drawCircle(center, size.width * .5 - .8, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = ENetColors.cyan.withValues(alpha: .85));
  }

  @override
  bool shouldRepaint(covariant _DashboardNebulaPainter oldDelegate) => false;
}
