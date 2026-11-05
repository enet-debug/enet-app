import 'package:flutter/material.dart';
import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/glass.dart';
import '../application/auth_controller.dart';

/// Configures the server before sign-in or from account settings.
///
/// This never assumes the owner's public domain is deployed. HTTPS is
/// enforced by the repository for non-loopback servers.
class ApiConnectionPanel extends StatefulWidget {
  const ApiConnectionPanel({super.key, required this.auth});
  final AuthController auth;

  @override
  State<ApiConnectionPanel> createState() => _ApiConnectionPanelState();
}

class _ApiConnectionPanelState extends State<ApiConnectionPanel> {
  String? _endpoint;
  bool _checking = false;
  bool? _reachable;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final endpoint = await widget.auth.getApiEndpoint();
      if (mounted) setState(() => _endpoint = endpoint);
    } catch (error) {
      if (mounted) setState(() => _message = error.toString());
    }
  }

  Future<void> _verify() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _message = null;
    });
    final result = await widget.auth.checkServer();
    if (!mounted) return;
    setState(() {
      _checking = false;
      _reachable = result;
    });
  }

  Future<void> _edit() async {
    final key = GlobalKey<FormState>();
    var typed = _endpoint ?? '';
    final updated = await showDialog<String>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Адрес eNet API'),
          content: SizedBox(
            width: 430,
            child: Form(
              key: key,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                TextFormField(
                  key: const ValueKey('api-endpoint-field'),
                  initialValue: typed,
                  onChanged: (value) => typed = value,
                  autofocus: true,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  textCapitalization: TextCapitalization.none,
                  decoration: const InputDecoration(
                    labelText: 'URL сервера',
                    hintText: 'https://api.example.ru',
                    prefixIcon: Icon(Icons.dns_outlined),
                  ),
                  validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Укажите адрес сервера' : null,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Удалённый API должен работать по HTTPS. '
                  'Локальный HTTP разрешён только для 127.0.0.1 и localhost. '
                  'При смене сервера потребуется войти заново.',
                  style: TextStyle(color: ENetColors.muted, height: 1.45, fontSize: 12),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена')),
            FilledButton(
              onPressed: () {
                if (key.currentState?.validate() == true) {
                  Navigator.pop(dialogContext, typed.trim());
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      );
    if (updated == null || !mounted) return;
    try {
      await widget.auth.setApiEndpoint(updated);
      if (!mounted) return;
      setState(() {
        _message = 'Адрес сохранён. Для нового сервера нужен отдельный вход.';
        _reachable = null;
      });
      await _load();
    } catch (error) {
      if (mounted) setState(() => _message = error.toString()
        .replaceFirst('FormatException: ', '').replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 22,
      blur: 18,
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Row(children: [
          Icon(Icons.hub_outlined, color: ENetColors.cyan, size: 19),
          SizedBox(width: 10),
          Text('ПОДКЛЮЧЕНИЕ К API',
            style: TextStyle(color: ENetColors.text, fontWeight: FontWeight.w800,
              fontSize: 11, letterSpacing: 1.3)),
        ]),
        const SizedBox(height: 10),
        Text(_endpoint ?? 'Загрузка адреса...',
          maxLines: 2, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: ENetColors.muted, fontSize: 13)),
        if (_reachable != null) ...[
          const SizedBox(height: 8),
          Row(children: [
            Icon(_reachable! ? Icons.check_circle_outline : Icons.error_outline,
              color: _reachable! ? ENetColors.mint : ENetColors.danger, size: 16),
            const SizedBox(width: 6),
            Expanded(child: Text(_reachable! ? 'Сервер и база данных доступны' :
              'Нет ответа от сервера',
              style: const TextStyle(color: ENetColors.muted, fontSize: 12))),
          ]),
        ],
        if (_message != null) ...[
          const SizedBox(height: 8),
          Text(_message!, style: const TextStyle(color: ENetColors.muted,
            fontSize: 12, height: 1.4)),
        ],
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          OutlinedButton.icon(
            onPressed: widget.auth.busy ? null : _edit,
            icon: const Icon(Icons.edit_rounded, size: 17),
            label: const Text('Изменить адрес'),
          ),
          TextButton.icon(
            onPressed: _checking ? null : _verify,
            icon: _checking
              ? const SizedBox(width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.refresh_rounded, size: 17),
            label: const Text('Проверить'),
          ),
        ]),
      ]),
    );
  }
}
