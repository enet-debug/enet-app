import 'package:flutter/material.dart';

import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../auth/application/auth_controller.dart';

/// Live API status for the dashboard. No fabricated database or cloud metrics.
class DashboardStatus extends StatefulWidget {
  const DashboardStatus({
    super.key,
    required this.auth,
  });

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
    final timer = Stopwatch()..start();
    final result = await widget.auth.checkServer();
    timer.stop();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _online = result;
      _responseMs = result ? timer.elapsedMilliseconds : null;
    });
  }

  @override
  Widget build(BuildContext context) => Glass(
    radius: 17,
    blur: 12,
    padding: const EdgeInsets.fromLTRB(13, 11, 13, 9),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        const Expanded(child: Text('СТАТУС СИСТЕМЫ', style: TextStyle(
          color: ENetColors.text,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: .7,
        ))),
        const Icon(Icons.signal_cellular_alt_rounded,
          color: ENetColors.cyan, size: 19),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        AnimatedContainer(
          duration: ENetMotion.medium,
          width: 10,
          height: 10,
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
                  .withValues(alpha: .38),
                blurRadius: 10,
              ),
            ],
          ),
        ),
        const SizedBox(width: 9),
        const Expanded(child: Text('eNet API', style: TextStyle(
          color: ENetColors.text, fontSize: 12,
          fontWeight: FontWeight.w700,
        ))),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: (_checking ? ENetColors.muted
              : _online ? ENetColors.mint : ENetColors.danger)
              .withValues(alpha: .14),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            _checking ? 'Проверка' : _online ? 'Работает' : 'Нет связи',
            style: TextStyle(
              color: _checking ? ENetColors.muted
                : _online ? ENetColors.mint : ENetColors.danger,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ]),
      const SizedBox(height: 5),
      Text(
        _checking
          ? 'Проверяем соединение с сервером'
          : _online
            ? 'Время ответа: ${_responseMs ?? 0} мс'
            : 'Сервер не отвечает',
        style: const TextStyle(color: ENetColors.muted, fontSize: 10.5),
      ),
      const SizedBox(height: 9),
      const Divider(height: 12, color: ENetColors.border),
      const Row(children: [
        Icon(Icons.storage_outlined, color: ENetColors.muted, size: 15),
        SizedBox(width: 7),
        Expanded(child: Text('База данных', style: TextStyle(
          color: ENetColors.muted, fontSize: 10.5))),
        Text('Не проверено', style: TextStyle(
          color: ENetColors.faint, fontSize: 9.5)),
      ]),
      const SizedBox(height: 8),
      const Row(children: [
        Icon(Icons.cloud_outlined, color: ENetColors.muted, size: 15),
        SizedBox(width: 7),
        Expanded(child: Text('eNet Cloud', style: TextStyle(
          color: ENetColors.muted, fontSize: 10.5))),
        Text('Не подключено', style: TextStyle(
          color: ENetColors.faint, fontSize: 9.5)),
      ]),
      const SizedBox(height: 7),
      Align(
        alignment: Alignment.centerRight,
        child: TextButton(
          onPressed: _checking ? null : _check,
          style: TextButton.styleFrom(
            foregroundColor: ENetColors.cyan,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            visualDensity: VisualDensity.compact,
          ),
          child: const Text('Проверить', style: TextStyle(fontFamily: 'Roboto', fontSize: 10.5)),
        ),
      ),
    ]),
  );
}
