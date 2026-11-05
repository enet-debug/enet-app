import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/glass.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_repository.dart';

/// Decorative mountain landscape, painted by Flutter on every screen size.
class MobileWelcomeScene extends StatelessWidget {
  const MobileWelcomeScene({super.key, required this.name, required this.onOpenProfile});
  final String name;
  final VoidCallback onOpenProfile;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onOpenProfile,
      child: Ink(
        height: 150,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: ENetColors.cyan.withValues(alpha: .28)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: Stack(fit: StackFit.expand, children: [
            const CustomPaint(painter: _MountainScenePainter()),
            const Positioned(
              top: 10, left: 0, right: 0,
              child: Center(child: ENetMark(size: 48)),
            ),
            Positioned(
              left: 18, right: 46, bottom: 16,
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('ДОБРО ПОЖАЛОВАТЬ', style: TextStyle(
                  color: Color(0xFFC9FFEA), fontSize: 10,
                  letterSpacing: 1.5, fontWeight: FontWeight.w800,
                )),
                const SizedBox(height: 4),
                Text(name, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ENetColors.text,
                    fontSize: 25, fontWeight: FontWeight.w800)),
              ]),
            ),
            const Positioned(
              right: 16, bottom: 24,
              child: Icon(Icons.arrow_outward_rounded, color: ENetColors.cyan, size: 20),
            ),
          ]),
        ),
      ),
    ),
  );
}

class _MountainScenePainter extends CustomPainter {
  const _MountainScenePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final bounds = Offset.zero & size;
    canvas.drawRect(bounds, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0xFF09212B), Color(0xFF15545C),
        Color(0xFF0A2E30), Color(0xFF071C1B)],
    ).createShader(bounds));

    final glow = Offset(w * .5, h * .42);
    canvas.drawCircle(glow, w * .55, Paint()..shader = RadialGradient(
      colors: [ENetColors.mint.withValues(alpha: .22),
        ENetColors.mint.withValues(alpha: 0)],
    ).createShader(Rect.fromCircle(center: glow, radius: w * .55)));

    for (final (peak, base, phase, color) in <(double, double, double, Color)>[
      (.15, .60, .3, const Color(0xFF23555C)),
      (.13, .73, 2.1, const Color(0xFF174144)),
      (.12, .84, 1.5, const Color(0xFF0C2D2E)),
      (.07, .93, 3.3, const Color(0xFF07191A)),
    ]) {
      final p = Path()..moveTo(0, h)..lineTo(0, h * base);
      for (var i = 0; i <= 40; i++) {
        final v = i / 40;
        final ridge = math.sin(v * math.pi * 4.2 + phase) * h * peak;
        final sharp = math.pow(math.sin(v * math.pi * 8 + phase), 5).toDouble()
            * h * peak * .28;
        p.lineTo(w * v, h * base - ridge - sharp);
      }
      p..lineTo(w, h)..close();
      canvas.drawPath(p, Paint()..color = color);
    }
    canvas.drawRect(bounds, Paint()..shader = const LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [Color(0x00031915), Color(0xB8031915)],
    ).createShader(bounds));
  }

  @override
  bool shouldRepaint(covariant _MountainScenePainter oldDelegate) => false;
}

/// Restrained luminous trails inspired by the supplied desktop mockup.
/// Purely decorative. Does not imply any connected service.
class WorkspaceLightTrails extends StatelessWidget {
  const WorkspaceLightTrails({super.key});

  @override
  Widget build(BuildContext context) => const IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(painter: _WorkspaceLightTrailPainter()),
    ),
  );
}

class _WorkspaceLightTrailPainter extends CustomPainter {
  const _WorkspaceLightTrailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final clip = Rect.fromLTWH(0, 0, w, h);
    canvas.save();
    canvas.clipRect(clip);

    final highlight = Paint()..shader = LinearGradient(
      begin: Alignment.centerLeft,
      end: Alignment.centerRight,
      colors: [
        ENetColors.mint.withValues(alpha: 0),
        ENetColors.mint.withValues(alpha: .1),
        ENetColors.cyan.withValues(alpha: .84),
      ],
    ).createShader(clip);

    for (var i = 0; i < 3; i++) {
      final path = Path()
        ..moveTo(w * (.35 + i * .04), h * 1.35)
        ..cubicTo(
          w * (.52 + i * .02), h * .60,
          w * (.65 + i * .01), h * 1.15,
          w * 1.12, -h * (.38 + i * .12),
        );

      canvas.drawPath(path, Paint()
        ..color = ENetColors.mint.withValues(alpha: .13)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 12 - i * 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 15));

      canvas.drawPath(path, highlight
        ..style = PaintingStyle.stroke
        ..strokeWidth = i == 0 ? 2.0 : 1.2);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WorkspaceLightTrailPainter oldDelegate) => false;
}

/// A real account-backed metric replaces the speculative balance from the mockup.
class WorkspaceTaskSnapshot extends StatefulWidget {
  const WorkspaceTaskSnapshot({super.key, required this.auth, required this.onOpenTasks});
  final AuthController auth;
  final VoidCallback onOpenTasks;

  @override
  State<WorkspaceTaskSnapshot> createState() => _WorkspaceTaskSnapshotState();
}

class _WorkspaceTaskSnapshotState extends State<WorkspaceTaskSnapshot> {
  List<WorkspaceTask>? _tasks;
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    try {
      final result = await widget.auth.listTasks();
      if (!mounted) return;
      setState(() { _tasks = result; _error = null; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Нет соединения'; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final tasks = _tasks;
    final open = tasks?.where((item) => !item.completed).length ?? 0;
    return Glass(
      radius: 18, blur: 10,
      padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          const Icon(Icons.checklist_rounded, color: ENetColors.cyan, size: 19),
          const SizedBox(width: 7),
          const Expanded(child: Text('МОИ ЗАДАЧИ', style: TextStyle(
            color: ENetColors.text, fontSize: 11, fontWeight: FontWeight.w800,
            letterSpacing: .8,
          ))),
          IconButton(
            tooltip: 'Обновить задачи',
            onPressed: _reload,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.refresh_rounded, color: ENetColors.cyan, size: 17),
          ),
        ]),
        const SizedBox(height: 5),
        Text(tasks == null ? (_error ?? 'Загрузка…') : '${open} в работе',
          style: const TextStyle(color: ENetColors.text,
            fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 5),
        Text(tasks == null
          ? 'Данные из eNet API'
          : 'Всего ${tasks.length} · Выполнено ${tasks.length - open}',
          style: const TextStyle(color: ENetColors.muted, fontSize: 10.5)),
        const SizedBox(height: 8),
        Material(color: Colors.transparent, child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onOpenTasks,
          child: const Padding(
            padding: EdgeInsets.symmetric(vertical: 4),
            child: Row(children: [
              Text('Открыть задачи', style: TextStyle(
                color: ENetColors.cyan, fontSize: 11.5, fontWeight: FontWeight.w700)),
              Spacer(),
              Icon(Icons.arrow_forward_rounded, color: ENetColors.cyan, size: 17),
            ]),
          ),
        )),
      ]),
    );
  }
}
