import 'package:flutter/material.dart';
import '../../../core/theme/enet_theme.dart';
import '../../auth/application/auth_controller.dart';

class ProfileEditButton extends StatelessWidget {
  const ProfileEditButton({super.key, required this.auth});
  final AuthController auth;

  Future<void> _edit(BuildContext context) async {
    final formKey = GlobalKey<FormState>();
    var name = auth.user?.name ?? '';
    final updated = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Изменить имя профиля'),
        content: SizedBox(
          width: 380,
          child: Form(
            key: formKey,
            child: TextFormField(
              initialValue: name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              maxLength: 80,
              decoration: const InputDecoration(labelText: 'Имя в eNet ID'),
              onChanged: (value) => name = value,
              validator: (value) {
                final trimmed = value?.trim() ?? '';
                if (trimmed.length < 2) return 'Минимум 2 символа';
                if (trimmed.length > 80) return 'Не больше 80 символов';
                if (RegExp(r'[\x00-\x1f\x7f]').hasMatch(trimmed)) return 'Недопустимые символы';
                return null;
              },
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (formKey.currentState?.validate() == true) {
                Navigator.pop(dialogContext, name.trim());
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (updated == null || !context.mounted) return;
    try {
      await auth.updateName(updated);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Имя профиля обновлено')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      }
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: auth.busy ? null : () => _edit(context),
    icon: const Icon(Icons.edit_outlined, color: ENetColors.cyan),
    label: const Text('Изменить имя'),
  );
}
