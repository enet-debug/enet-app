import 'package:flutter/material.dart';
import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_repository.dart';

class DeviceSessionsPanel extends StatefulWidget {
  const DeviceSessionsPanel({super.key, required this.auth});
  final AuthController auth;

  @override
  State<DeviceSessionsPanel> createState() => _DeviceSessionsPanelState();
}

class _DeviceSessionsPanelState extends State<DeviceSessionsPanel> {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  List<AccountSession> _sessions = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await widget.auth.listSessions();
      if (!mounted) return;
      setState(() {
        _sessions = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  String _date(DateTime d) {
    final local = d.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day.$month.${local.year} $hour:$minute';
  }

  Future<void> _revoke(AccountSession session) async {
    if (session.current || _busy) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Завершить сеанс?'),
        content: Text('Доступ для устройства «${session.device}» будет закрыт.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Завершить')),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.auth.revokeSession(session.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Сеанс завершён')));
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Glass(
    radius: 28,
    padding: const EdgeInsets.all(24),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(child: Text('АКТИВНЫЕ УСТРОЙСТВА',
          style: TextStyle(color: ENetColors.muted, fontSize: 11,
              letterSpacing: 1.8, fontWeight: FontWeight.w700))),
        IconButton(
          tooltip: 'Обновить список устройств',
          onPressed: (_loading || _busy) ? null : _reload,
          icon: const Icon(Icons.refresh_rounded, color: ENetColors.cyan),
        ),
      ]),
      const SizedBox(height: 8),
      if (_loading) const LinearProgressIndicator()
      else if (_error != null)
        Text('Не удалось загрузить сеансы: $_error',
            style: const TextStyle(color: ENetColors.danger, fontSize: 13))
      else if (_sessions.isEmpty)
        const Text('Активных сеансов не найдено.',
            style: TextStyle(color: ENetColors.muted))
      else
        for (final session in _sessions)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(session.current ? Icons.desktop_windows_rounded : Icons.devices_other_rounded,
                  color: session.current ? ENetColors.mint : ENetColors.cyan),
              title: Text(session.device, maxLines: 2, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ENetColors.text, fontSize: 14)),
              subtitle: Text('Последняя активность: ${_date(session.lastSeenAt)}',
                  style: const TextStyle(color: ENetColors.muted, fontSize: 12)),
              trailing: session.current
                  ? const Text('Этот сеанс',
                      style: TextStyle(color: ENetColors.mint, fontSize: 12))
                  : IconButton(
                      tooltip: 'Завершить сеанс',
                      onPressed: _busy ? null : () => _revoke(session),
                      icon: const Icon(Icons.logout_rounded, color: ENetColors.danger),
                    ),
            ),
          ),
      const SizedBox(height: 12),
      const Text('Названия устройств передаются клиентом и могут быть неточными.',
          style: TextStyle(color: ENetColors.muted, fontSize: 12)),
    ]),
  );
}
