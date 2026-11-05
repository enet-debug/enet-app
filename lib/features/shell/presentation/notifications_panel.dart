import 'package:flutter/material.dart';
import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_repository.dart';

/// API-backed notifications. Never fabricates messages or unread counts.
class NotificationsPanel extends StatefulWidget {
  const NotificationsPanel({super.key, required this.auth});
  final AuthController auth;

  @override
  State<NotificationsPanel> createState() => _NotificationsPanelState();
}

class _NotificationsPanelState extends State<NotificationsPanel> {
  NotificationFeed? _feed;
  bool _loading = true;
  bool _readingAll = false;
  final Set<String> _reading = {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    if (!mounted) return;
    setState(() { _loading = true; _error = null; });
    try {
      final feed = await widget.auth.listNotifications();
      if (mounted) setState(() => _feed = feed);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notify(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _markRead(AccountNotification item) async {
    if (!item.unread || _reading.contains(item.id)) return;
    setState(() => _reading.add(item.id));
    try {
      await widget.auth.readNotification(item.id);
      await _reload();
    } catch (e) {
      _notify(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _reading.remove(item.id));
    }
  }

  Future<void> _markAllRead() async {
    if (_readingAll || (_feed?.unreadCount ?? 0) == 0) return;
    setState(() => _readingAll = true);
    try {
      await widget.auth.readAllNotifications();
      await _reload();
    } catch (e) {
      _notify(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _readingAll = false);
    }
  }

  String _timestamp(DateTime date) {
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}.${two(local.month)}.${local.year} · ${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    final items = _feed?.notifications ?? const <AccountNotification>[];
    final unread = _feed?.unreadCount ?? 0;
    return Column(
      key: const ValueKey('real-notifications'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('АКТИВНОСТЬ АККАУНТА',
              style: TextStyle(color: ENetColors.cyan, fontSize: 11,
                letterSpacing: 2, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            const Text('Уведомления',
              style: TextStyle(color: ENetColors.text, fontSize: 32,
                fontWeight: FontWeight.w800, letterSpacing: -.8)),
            const SizedBox(height: 8),
            const Text('События входа и сообщения eNet ID',
              style: TextStyle(color: ENetColors.muted, fontSize: 14)),
          ])),
          IconButton(
            tooltip: 'Обновить уведомления',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh_rounded, color: ENetColors.cyan),
          ),
        ]),
        const SizedBox(height: 24),
        Glass(
          radius: 24,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                gradient: ENetColors.accent,
                borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.notifications_active_outlined,
                size: 23, color: ENetColors.onAccent),
            ),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(unread == 0 ? 'Всё прочитано' : 'Непрочитанных: $unread',
                style: const TextStyle(color: ENetColors.text,
                  fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 3),
              const Text('История сохраняется в твоём eNet ID',
                style: TextStyle(color: ENetColors.muted, fontSize: 12)),
            ])),
            if (unread > 0)
              IconButton(
                tooltip: 'Прочитать все уведомления',
                onPressed: _readingAll ? null : _markAllRead,
                icon: const Icon(Icons.done_all_rounded, color: ENetColors.cyan)),
          ]),
        ),
        const SizedBox(height: 18),
        if (_loading && _feed == null)
          const Center(child: Padding(
            padding: EdgeInsets.all(32), child: CircularProgressIndicator()))
        else if (_error != null && _feed == null)
          Glass(
            padding: const EdgeInsets.all(22),
            child: Column(children: [
              const Icon(Icons.cloud_off_outlined, color: ENetColors.danger, size: 32),
              const SizedBox(height: 12),
              Text('Не удалось загрузить уведомления: $_error',
                textAlign: TextAlign.center,
                style: const TextStyle(color: ENetColors.muted)),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _reload,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Повторить')),
            ]),
          )
        else if (items.isEmpty)
          Glass(
            radius: 26,
            padding: const EdgeInsets.all(34),
            child: const SizedBox(width: double.infinity,
              child: Column(children: [
                Icon(Icons.mark_email_read_outlined,
                  color: ENetColors.mint, size: 40),
                SizedBox(height: 16),
                Text('Пока нет уведомлений',
                  style: TextStyle(color: ENetColors.text,
                    fontSize: 20, fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                Text('Новые события аккаунта появятся здесь.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: ENetColors.muted)),
              ]),
            ),
          )
        else
          for (final item in items) ...[
            _NotificationCard(
              key: ValueKey(item.id),
              notification: item,
              timeLabel: _timestamp(item.createdAt),
              busy: _reading.contains(item.id),
              onRead: item.unread ? () => _markRead(item) : null,
            ),
            const SizedBox(height: 12),
          ],
        if (_error != null && _feed != null)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text('Не удалось обновить данные: $_error',
              style: const TextStyle(color: ENetColors.danger, fontSize: 12))),
        if (_loading && _feed != null)
          const LinearProgressIndicator(),
        const SizedBox(height: 10),
        const Text('Показаны последние 50 сообщений eNet ID.',
          style: TextStyle(color: ENetColors.faint, fontSize: 11.5, height: 1.5)),
      ],
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    super.key,
    required this.notification,
    required this.timeLabel,
    required this.busy,
    required this.onRead,
  });

  final AccountNotification notification;
  final String timeLabel;
  final bool busy;
  final VoidCallback? onRead;

  @override
  Widget build(BuildContext context) {
    final security = notification.type == 'security';
    final accent = security ? ENetColors.cyan : ENetColors.mint;
    return Glass(
      radius: 24,
      shadow: notification.unread,
      strength: notification.unread ? 1.5 : .55,
      padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 18),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          height: 44, width: 44,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: .14),
            border: Border.all(color: accent.withValues(alpha: .28)),
            borderRadius: BorderRadius.circular(15)),
          child: Icon(security ? Icons.shield_outlined : Icons.auto_awesome_rounded,
            color: accent, size: 21)),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(notification.title,
              style: TextStyle(
                color: ENetColors.text, fontSize: 15.5,
                fontWeight: notification.unread ? FontWeight.w800 : FontWeight.w600))),
            if (notification.unread)
              Container(width: 8, height: 8,
                decoration: const BoxDecoration(
                  color: ENetColors.mint, shape: BoxShape.circle)),
          ]),
          const SizedBox(height: 6),
          Text(notification.body,
            style: const TextStyle(color: ENetColors.muted, height: 1.55,
              fontSize: 13.5)),
          const SizedBox(height: 10),
          Wrap(crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12, runSpacing: 3,
            children: [
              Text(timeLabel,
                style: const TextStyle(color: ENetColors.faint, fontSize: 11.5)),
              if (notification.unread)
                TextButton.icon(
                  onPressed: busy ? null : onRead,
                  icon: Icon(busy ? Icons.hourglass_top_rounded :
                    Icons.done_rounded, size: 16),
                  label: const Text('Отметить прочитанным')),
            ]),
        ])),
      ]),
    );
  }
}
