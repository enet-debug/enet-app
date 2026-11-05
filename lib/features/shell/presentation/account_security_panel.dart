import 'package:flutter/material.dart';
import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../auth/application/auth_controller.dart';

class AccountSecurityPanel extends StatefulWidget {
  const AccountSecurityPanel({super.key, required this.auth});
  final AuthController auth;

  @override
  State<AccountSecurityPanel> createState() => _AccountSecurityPanelState();
}

class _AccountSecurityPanelState extends State<AccountSecurityPanel> {
  bool _busy = false;
  bool _checking = true;
  bool? _online;

  @override
  void initState() {
    super.initState();
    _check();
  }

  Future<void> _check() async {
    setState(() => _checking = true);
    final online = await widget.auth.checkServer();
    if (!mounted) return;
    setState(() { _online = online; _checking = false; });
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changePassword() async {
    final values = await showDialog<List<String>>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (values == null || !mounted) return;
    setState(() => _busy = true);
    try {
      await widget.auth.changePassword(values[0], values[1]);
      _notify('Пароль изменён. Другие сеансы завершены.');
    } catch (e) {
      _notify(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _closeOtherSessions() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Завершить другие сеансы?'),
        content: const Text(
          'Другие устройства выйдут из eNet ID. Текущий сеанс останется активным.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Завершить'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      final count = await widget.auth.revokeOtherSessions();
      _notify('Завершено других сеансов: $count');
    } catch (e) {
      _notify(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Glass(
      radius: 28,
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Text('ENET ID И БЕЗОПАСНОСТЬ',
            style: TextStyle(color: ENetColors.muted, fontSize: 11,
                letterSpacing: 1.8, fontWeight: FontWeight.w700)),
        const SizedBox(height: 20),
        Row(children: [
          Icon(_online == true ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
              color: _online == true ? ENetColors.mint : ENetColors.faint),
          const SizedBox(width: 12),
          Expanded(child: Text(
            _checking ? 'Проверка подключения к API…' :
                _online == true ? 'eNet API отвечает' : 'Нет подключения к eNet API',
            style: const TextStyle(color: ENetColors.text, fontSize: 14),
          )),
          IconButton(
            tooltip: 'Проверить API',
            onPressed: _checking ? null : _check,
            icon: const Icon(Icons.refresh_rounded, color: ENetColors.cyan),
          ),
        ]),
        const Divider(height: 30),
        OutlinedButton.icon(
          onPressed: _busy || widget.auth.busy ? null : _changePassword,
          icon: const Icon(Icons.password_rounded),
          label: const Text('Изменить пароль'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _busy || widget.auth.busy ? null : _closeOtherSessions,
          icon: const Icon(Icons.phonelink_erase_rounded),
          label: const Text('Завершить сеансы на других устройствах'),
        ),
        const SizedBox(height: 12),
        const Text(
          'Смена пароля завершает остальные сеансы. Текущий вход сохраняется.',
          style: TextStyle(color: ENetColors.muted, fontSize: 12, height: 1.4),
        ),
      ]),
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirm = TextEditingController();

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _submit() {
    if (_form.currentState?.validate() != true) return;
    Navigator.pop(context, [_current.text, _next.text]);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Смена пароля eNet ID'),
      content: SizedBox(
        width: 380,
        child: Form(
          key: _form,
          child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: _current,
              autofocus: true,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Текущий пароль'),
              validator: (text) => text == null || text.isEmpty ? 'Укажите текущий пароль' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Новый пароль'),
              validator: (text) =>
                  text == null || text.length < 12 ? 'Минимум 12 символов' :
                  text.length > 128 ? 'Не больше 128 символов' :
                  text == _current.text ? 'Новый пароль должен отличаться' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirm,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Повторите новый пароль'),
              validator: (text) => text != _next.text ? 'Пароли не совпадают' : null,
            ),
          ])),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Отмена')),
        FilledButton(onPressed: _submit, child: const Text('Сохранить')),
      ],
    );
  }
}
