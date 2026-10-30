import 'package:flutter/material.dart';
import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/brand_logo.dart';
import '../application/auth_controller.dart';

enum _AuthMode { signIn, signUp, reset }

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key, required this.auth});
  final AuthController auth;
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  _AuthMode mode = _AuthMode.signIn;
  final formKey = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  final confirm = TextEditingController();
  final name = TextEditingController();
  bool passwordVisible = false;
  String? notice;

  @override
  void dispose() {
    email.dispose(); password.dispose(); confirm.dispose(); name.dispose();
    super.dispose();
  }
  void change(_AuthMode next) {
    setState(() { mode = next; notice = null; formKey.currentState?.reset(); });
  }
  String? checkEmail(String? value) {
    if (value == null || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) return 'Введите корректный email';
    return null;
  }
  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    if (mode == _AuthMode.reset) {
      await widget.auth.requestPasswordReset(email.text);
      if (mounted) setState(() => notice = 'Демо-режим: письмо не отправляется. Подключим это после выбора сервера авторизации.');
      return;
    }
    if (mode == _AuthMode.signUp) {
      await widget.auth.signUp(name.text, email.text, password.text);
    } else {
      await widget.auth.signIn(email.text, password.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final compact = width < 890;
    return Scaffold(body: AmbientBackground(child: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1180),
      child: Padding(padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 34, vertical: 18), child: Row(children: [
        if (!compact) Expanded(child: _IdentityPanel()),
        if (!compact) const SizedBox(width: 44),
        Flexible(flex: 1, fit: FlexFit.loose, child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: SingleChildScrollView(child: _authCard(compact)))),
      ])),
    )))));
  }

  Widget _authCard(bool compact) {
    final isLogin = mode == _AuthMode.signIn;
    final reset = mode == _AuthMode.reset;
    return Container(
      padding: EdgeInsets.all(compact ? 24 : 32),
      decoration: BoxDecoration(
        color: const Color(0xDF0B1626),
        border: Border.all(color: ENetColors.border),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: ENetColors.blue.withValues(alpha: .1), blurRadius: 44, spreadRadius: 5)],
      ),
      child: Form(key: formKey, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        if (compact) ...[const BrandLogo(size: 42), const SizedBox(height: 30)],
        const Text('ENET ID · ДЕМО-РЕЖИМ', style: TextStyle(color: ENetColors.cyan, letterSpacing: 2, fontSize: 10, fontWeight: FontWeight.w800)),
        const SizedBox(height: 11),
        Text(reset ? 'Восстановление' : isLogin ? 'С возвращением!' : 'Создать аккаунт', style: const TextStyle(fontSize: 27, color: ENetColors.text, fontWeight: FontWeight.w800, letterSpacing: -.8)),
        const SizedBox(height: 7),
        Text(reset ? 'Введите email. Позже сюда подключим настоящую отправку письма.' : isLogin ? 'Твоё пространство eNet начинается здесь.' : 'Присоединяйся к eNet и настрой личное пространство.'),
        const SizedBox(height: 24),
        if (!reset) ...[
          SegmentedButton<_AuthMode>(
            segments: const [ButtonSegment(value: _AuthMode.signIn, label: Text('Вход')), ButtonSegment(value: _AuthMode.signUp, label: Text('Регистрация'))],
            selected: {mode},
            onSelectionChanged: (selection) => change(selection.first),
            style: ButtonStyle(
              visualDensity: VisualDensity.comfortable,
              backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? ENetColors.surfaceRaised : ENetColors.background),
            ),
          ),
          const SizedBox(height: 22),
        ],
        if (mode == _AuthMode.signUp) ...[
          TextFormField(controller: name, decoration: const InputDecoration(labelText: 'Как тебя называть', prefixIcon: Icon(Icons.person_outline_rounded)),
            validator: (v) => (v == null || v.trim().length < 2) ? 'Минимум два символа' : null),
          const SizedBox(height: 13),
        ],
        TextFormField(controller: email, keyboardType: TextInputType.emailAddress, textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(labelText: 'Электронная почта', prefixIcon: Icon(Icons.alternate_email_rounded)), validator: checkEmail),
        if (!reset) ...[
          const SizedBox(height: 13),
          TextFormField(controller: password, obscureText: !passwordVisible,
            decoration: InputDecoration(labelText: 'Пароль', prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(onPressed: () => setState(() => passwordVisible = !passwordVisible),
                icon: Icon(passwordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined))),
            validator: (v) => (v == null || v.length < 8) ? 'Минимум восемь символов' : null),
          if (mode == _AuthMode.signUp) ...[
            const SizedBox(height: 13),
            TextFormField(controller: confirm, obscureText: !passwordVisible,
              decoration: const InputDecoration(labelText: 'Повтори пароль', prefixIcon: Icon(Icons.verified_user_outlined)),
              validator: (v) => (v != password.text) ? 'Пароли не совпадают' : null),
          ],
        ],
        if (isLogin) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => change(_AuthMode.reset), child: const Text('Забыли пароль?'))),
        const SizedBox(height: 15),
        FilledButton(onPressed: widget.auth.busy ? null : submit,
          child: widget.auth.busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
            : Text(reset ? 'Продолжить' : isLogin ? 'Войти в eNet  →' : 'Создать профиль  →')),
        if (reset) ...[const SizedBox(height: 12), TextButton(onPressed: () => change(_AuthMode.signIn), child: const Text('← Вернуться ко входу'))],
        if (notice != null) ...[const SizedBox(height: 15), Text(notice!, style: const TextStyle(color: ENetColors.cyan, fontSize: 12))],
        const SizedBox(height: 22),
        const Divider(color: ENetColors.border),
        const SizedBox(height: 11),
        const Text('Это прототип: аккаунты не создаются, пароли не сохраняются и никуда не отправляются.', textAlign: TextAlign.center,
          style: TextStyle(color: ENetColors.muted, fontSize: 11, height: 1.6)),
      ])),
    );
  }
}

class _IdentityPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(horizontal: 20), child: Column(
    crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center,
    children: [
      const BrandLogo(size: 70),
      const SizedBox(height: 70),
      const Text('ТВОЁ ПРОСТРАНСТВО', style: TextStyle(fontSize: 12, letterSpacing: 3, color: ENetColors.cyan, fontWeight: FontWeight.w700)),
      const SizedBox(height: 18),
      const Text('Создано для\nновых идей.', style: TextStyle(fontSize: 54, letterSpacing: -2, height: 1.05, fontWeight: FontWeight.w800, color: ENetColors.text)),
      const SizedBox(height: 17),
      const Text('Единая основа для будущих возможностей eNet.\nБез лишнего. Всё важное впереди.', style: TextStyle(fontSize: 15, height: 1.8, color: ENetColors.muted)),
      const SizedBox(height: 46),
      Wrap(spacing: 10, runSpacing: 10, children: const [
        _Pill(icon: Icons.auto_awesome_rounded, label: 'Продуманный дизайн'),
        _Pill(icon: Icons.layers_rounded, label: 'Единая платформа'),
      ]),
    ],
  ));
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});
  final IconData icon;
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 10),
    decoration: BoxDecoration(color: ENetColors.surface.withValues(alpha: .8), border: Border.all(color: ENetColors.border), borderRadius: BorderRadius.circular(25)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, color: ENetColors.cyan, size: 17), const SizedBox(width: 7), Text(label, style: const TextStyle(fontSize: 11, color: ENetColors.text))]),
  );
}
