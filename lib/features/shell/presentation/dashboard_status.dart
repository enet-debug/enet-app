import 'package:flutter/material.dart';

import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../auth/application/auth_controller.dart';

/// A compact, live status rail. Every state is backed by an API check.
class DashboardStatus extends StatefulWidget {
  const DashboardStatus({
    super.key,
    required this.auth,
    required this.openAccount,
    required this.openSettings,
  });

  final AuthController auth;
  final VoidCallback openAccount;
  final VoidCallback openSettings;

  @override
  State<DashboardStatus> createState() => _DashboardStatusState();
}

class _DashboardStatusState extends State<DashboardStatus> {
  bool _checking = true;
  bool _online = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (!mounted) return;
    setState(() => _checking = true);
    final result = await widget.auth.checkServer();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _online = result;
    });
  }

  @override
  Widget build(BuildContext context) => Glass(
    radius: 21,
    blur: 14,
    padding: const EdgeInsets.fromLTRB(15, 14, 15, 10),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        AnimatedContainer(
          duration: ENetMotion.medium,
          width: 9,
          height: 9,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _checking
                ? ENetColors.muted
                : _online ? ENetColors.mint : ENetColors.danger,
            boxShadow: [
              BoxShadow(
                color: (_checking
                    ? ENetColors.muted
                    : _online ? ENetColors.mint : ENetColors.danger)
                    .withValues(alpha: .42),
                blurRadius: 12,
              ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(
          _checking ? 'Проверяем систему' : _online ? 'Система работает' : 'Нет соединения',
          style: const TextStyle(
            color: ENetColors.text,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        )),
        IconButton(
          tooltip: 'Проверить подключение',
          visualDensity: VisualDensity.compact,
          onPressed: _checking ? null : _check,
          icon: const Icon(Icons.refresh_rounded, color: ENetColors.cyan, size: 18),
        ),
      ]),
      const SizedBox(height: 5),
      _StatusLine(
        icon: Icons.cloud_done_rounded,
        title: 'API',
        subtitle: _checking
            ? 'Проверяем соединение'
            : _online ? 'Сервер отвечает' : 'Нет подключения',
        color: _checking
            ? ENetColors.muted
            : _online ? ENetColors.mint : ENetColors.danger,
        onTap: _checking ? null : _check,
      ),
      const Divider(height: 9, indent: 32),
      _StatusLine(
        icon: Icons.fingerprint_rounded,
        title: 'eNet ID',
        subtitle: 'Аккаунт и профиль',
        color: ENetColors.cyan,
        onTap: widget.openAccount,
      ),
      const Divider(height: 9, indent: 32),
      _StatusLine(
        icon: Icons.shield_outlined,
        title: 'Безопасность',
        subtitle: 'Пароль и активные сеансы',
        color: ENetColors.blue,
        onTap: widget.openSettings,
      ),
    ]),
  );
}

class _StatusLine extends StatelessWidget {
  const _StatusLine({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 2),
        child: Row(children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(width: 9),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(
                color: ENetColors.text,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              )),
              const SizedBox(height: 2),
              Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ENetColors.muted, fontSize: 10.5)),
            ],
          )),
          if (onTap != null)
            const Icon(Icons.chevron_right_rounded,
              color: ENetColors.faint, size: 17),
        ]),
      ),
    ),
  );
}
