import 'package:flutter/material.dart';
import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/glass.dart';
import '../application/auth_controller.dart';
import '../domain/auth_repository.dart';

class ApiEndpointPanel extends StatefulWidget {
  const ApiEndpointPanel({super.key, required this.auth});
  final AuthController auth;

  @override
  State<ApiEndpointPanel> createState() => _ApiEndpointPanelState();
}

class _ApiEndpointPanelState extends State<ApiEndpointPanel> {
  bool _busy = false;

  Future<void> _edit() async {
    final controller = TextEditingController(text: widget.auth.apiBaseUrl);
    final formKey = GlobalKey<FormState>();
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Адрес сервера eNet'),
        content: SizedBox(
          width: 420,
          child: Form(
            key: formKey,
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
              TextFormField(
                controller: controller,
                autofocus: true,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                decoration: const InputDecoration(
                  labelText: 'URL API',
                  hintText: 'https://api.example.com',
                  prefixIcon: Icon(Icons.dns_outlined),
                ),
                validator: (value) {
                  try {
                    normalizeApiBaseUrl(value ?? '');
                    return null;
                  } on FormatException catch (error) {
                    return error.message.toString();
                  }
                },
              ),
              const SizedBox(height: 12),
              const Text(
                'Для iPhone и удалённых компьютеров нужен HTTPS. HTTP разрешён только для localhost.',
                style: TextStyle(color: ENetColors.muted, fontSize: 12, height: 1.45),
              ),
            ]),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogContext, normalizeApiBaseUrl(controller.text));
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (value == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.auth.updateApiBaseUrl(value);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Адрес API сохранён. Войдите заново для подключения.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Glass(
    radius: 20,
    blur: 14,
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
    child: Row(children: [
      const Icon(Icons.dns_outlined, color: ENetColors.cyan, size: 20),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('СЕРВЕР ПОДКЛЮЧЕНИЯ', style: TextStyle(
          color: ENetColors.muted, fontSize: 9.5, letterSpacing: 1.4, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(widget.auth.apiBaseUrl, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: ENetColors.text, fontSize: 12)),
      ])),
      const SizedBox(width: 8),
      TextButton(
        onPressed: _busy || widget.auth.busy ? null : _edit,
        child: Text(_busy ? 'Сохранение…' : 'Изменить'),
      ),
    ]),
  );
}
