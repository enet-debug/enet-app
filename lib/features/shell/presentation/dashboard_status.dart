import 'package:flutter/material.dart';

import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../auth/application/auth_controller.dart';

/// The eNet 0.7 SystemStatusCard, backed by the current live API.
class DashboardStatus extends StatefulWidget {
  const DashboardStatus({super.key, required this.auth});
  final AuthController auth;

  @override
  State<DashboardStatus> createState() => _DashboardStatusState();
}

class _DashboardStatusState extends State<DashboardStatus> {
  bool _checking = true;
  bool _online = false;
  int? _responseMs;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    if (!mounted) return;
    setState(() => _checking = true);
    final watch = Stopwatch()..start();
    var online = false;
    try {
      online = await widget.auth.checkServer();
    } catch (_) {
      // An unavailable API is an offline state, never a blank card.
    }
    watch.stop();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _online = online;
      _responseMs = online ? watch.elapsedMilliseconds : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = _checking ? ENetColors.muted :
      _online ? ENetColors.mint : ENetColors.danger;
    final headline = _checking ? 'Проверяем систему' :
      _online ? 'Система работает' : 'Есть проблемы';
    return Glass(
      radius: 22,
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          AnimatedContainer(
            duration: ENetMotion.medium,
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [BoxShadow(
                color: color.withValues(alpha: .55), blurRadius: 10)],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: AnimatedSwitcher(
            duration: ENetMotion.quick,
            child: Text(headline, key: ValueKey(headline),
              style: const TextStyle(
                color: ENetColors.text,
                fontSize: 14.5, fontWeight: FontWeight.w700)),
          )),
          Icon(Icons.signal_cellular_alt_rounded, size: 20, color: color),
        ]),
        const SizedBox(height: 13),
        _line(Icons.dns_outlined, 'eNet API',
          _checking ? 'Проверка' : _online ? 'Работает' : 'Нет связи', color),
        const SizedBox(height: 5),
        Text(
          _checking ? 'Проверяем соединение с сервером' :
          _online ? 'Время ответа: \${_responseMs ?? 0} мс' :
          'Сервер не отвечает',
          style: const TextStyle(color: ENetColors.faint, fontSize: 10.5)),
        _line(Icons.fingerprint_rounded, 'eNet ID',
          widget.auth.user == null ? 'Нет сеанса' : 'Сеанс активен',
          widget.auth.user == null ? ENetColors.muted : ENetColors.mint),
        _line(Icons.info_outline_rounded, 'Приложение',
          'v0.8.0', ENetColors.muted),
        const SizedBox(height: 8),
        Align(alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: _checking ? null : _check,
            style: TextButton.styleFrom(
              foregroundColor: ENetColors.cyan,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2)),
            child: const Text('Проверить',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
          ),
        ),
      ]),
    );
  }

  Widget _line(IconData icon, String label, String value, Color color) =>
    Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [
        Icon(icon, size: 16, color: ENetColors.muted),
        const SizedBox(width: 9),
        Text(label, style: const TextStyle(
          color: ENetColors.muted, fontSize: 12.5)),
        const Spacer(),
        Text(value, style: TextStyle(
          color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
}
