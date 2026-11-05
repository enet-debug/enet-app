import 'package:flutter/material.dart';
import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../auth/application/auth_controller.dart';

/// Only displays states verified against the local API, never invented metrics.
class DashboardStatus extends StatefulWidget {
  const DashboardStatus({super.key, required this.auth, required this.openAccount, required this.openSettings});
  final AuthController auth;
  final VoidCallback openAccount;
  final VoidCallback openSettings;

  @override
  State<DashboardStatus> createState() => _DashboardStatusState();
}

class _DashboardStatusState extends State<DashboardStatus> {
  bool checking = true;
  bool online = false;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (!mounted) return;
    setState(() => checking = true);
    final result = await widget.auth.checkServer();
    if (!mounted) return;
    setState(() {
      checking = false;
      online = result;
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final narrow = constraints.maxWidth < 620;
      final status = _DashboardTile(
        icon: checking ? Icons.sync_rounded : online ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
        title: 'eNet API',
        subtitle: checking ? 'Проверяем соединение' : online ? 'Сервер отвечает' : 'Нет подключения',
        color: checking ? ENetColors.muted : online ? ENetColors.mint : ENetColors.danger,
        onTap: checking ? null : _check,
        actionIcon: Icons.refresh_rounded,
        actionLabel: 'Проверить API',
      );
      final account = _DashboardTile(
        icon: Icons.verified_user_outlined,
        title: 'eNet ID',
        subtitle: 'Управление профилем',
        color: ENetColors.cyan,
        onTap: widget.openAccount,
        actionIcon: Icons.arrow_forward_rounded,
        actionLabel: 'Открыть профиль',
      );
      final security = _DashboardTile(
        icon: Icons.shield_outlined,
        title: 'Безопасность',
        subtitle: 'Пароли и устройства',
        color: ENetColors.blue,
        onTap: widget.openSettings,
        actionIcon: Icons.arrow_forward_rounded,
        actionLabel: 'Открыть настройки безопасности',
      );
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ОБЗОР ПЛАТФОРМЫ', style: TextStyle(color: ENetColors.muted,
          fontWeight: FontWeight.w700, fontSize: 11, letterSpacing: 2)),
        const SizedBox(height: 14),
        if (narrow)
          Column(children: [
            status,
            const SizedBox(height: 10),
            account,
            const SizedBox(height: 10),
            security,
          ])
        else
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: status),
            const SizedBox(width: 12),
            Expanded(child: account),
            const SizedBox(width: 12),
            Expanded(child: security),
          ]),
      ]);
    });
  }
}

class _DashboardTile extends StatelessWidget {
  const _DashboardTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.actionIcon,
    required this.actionLabel,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final IconData actionIcon;
  final String actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Glass(
    radius: 22,
    blur: 18,
    padding: const EdgeInsets.all(17),
    child: Semantics(
      button: onTap != null,
      label: '$title, $subtitle. $actionLabel',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Row(children: [
          Container(
            height: 44, width: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .13),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withValues(alpha: .26)),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(
              fontSize: 13.5, height: 1.15, fontWeight: FontWeight.w700, color: ENetColors.text)),
            const SizedBox(height: 4),
            Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 11.5, height: 1.2, color: ENetColors.muted)),
          ])),
          const SizedBox(width: 4),
          Icon(actionIcon, size: 17, color: ENetColors.muted),
        ]),
        ),
      ),
    ),
  );
}
