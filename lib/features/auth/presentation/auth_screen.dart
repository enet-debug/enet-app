import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/glass_controls.dart';
import '../../../core/widgets/premium_button.dart';
import '../../../core/widgets/reveal.dart';
import '../application/auth_controller.dart';
import 'api_endpoint_panel.dart';

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
  bool noticeIsError = false;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    confirm.dispose();
    name.dispose();
    super.dispose();
  }

  void change(_AuthMode next) {
    if (next == mode) return;
    setState(() {
      mode = next;
      notice = null;
    });
    formKey.currentState?.reset();
  }

  String? checkEmail(String? value) {
    if (value == null || !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value.trim())) {
      return 'Введите корректный email';
    }
    return null;
  }

  Future<void> submit() async {
    if (!formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() { notice = null; noticeIsError = false; });
    try {
      if (mode == _AuthMode.reset) {
        await widget.auth.requestPasswordReset(email.text);
        if (mounted) setState(() => notice = 'Проверьте почту.');
        return;
      }
      if (mode == _AuthMode.signUp) {
        await widget.auth.signUp(name.text, email.text, password.text);
      } else {
        await widget.auth.signIn(email.text, password.text);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          notice = e.toString().replaceFirst('Exception: ', '');
          noticeIsError = true;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 900;
    final card = Reveal(
      delay: const Duration(milliseconds: 140),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 450), child: _authCard(compact)),
    );

    return Scaffold(
      body: AmbientBackground(
        child: SafeArea(
          child: compact
              ? Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      const Reveal(child: BrandLogo(size: 48)),
                      const SizedBox(height: 28),
                      card,
                      const SizedBox(height: 12),
                      ApiEndpointPanel(auth: widget.auth),
                    ]),
                  ),
                )
              : Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1200),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 40),
                      child: Row(children: [
                        const Expanded(child: Reveal(child: _IdentityPanel())),
                        const SizedBox(width: 56),
                        SizedBox(
                          width: 450,
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Column(mainAxisSize: MainAxisSize.min, children: [
                              card,
                              const SizedBox(height: 12),
                              ApiEndpointPanel(auth: widget.auth),
                            ]),
                          ),
                        ),
                      ]),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _collapsible({required bool show, required Widget child}) => AnimatedSize(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutQuart,
        alignment: Alignment.topCenter,
        child: show ? _FadeIn(child: child) : const SizedBox(width: double.infinity),
      );

  Widget _authCard(bool compact) {
    final signIn = mode == _AuthMode.signIn;
    final signUp = mode == _AuthMode.signUp;
    final reset = mode == _AuthMode.reset;
    final busy = widget.auth.busy;

    final title = reset ? 'Восстановление' : signIn ? 'С возвращением!' : 'Создать аккаунт';
    final subtitle = reset
        ? 'Восстановление пароля пока не настроено на сервере.'
        : signIn
            ? 'Твоё пространство eNet начинается здесь.'
            : 'Присоединяйся к eNet и настрой личное пространство.';

    return Glass(
      radius: 32,
      padding: EdgeInsets.all(compact ? 24 : 34),
      child: Form(
        key: formKey,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text(
            'ENET ID',
            style: TextStyle(color: ENetColors.cyan, letterSpacing: 2.4, fontSize: 11, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutQuart,
            alignment: Alignment.topLeft,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 320),
              transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(begin: const Offset(0, .12), end: Offset.zero).animate(animation),
                  child: child,
                ),
              ),
              layoutBuilder: (current, previous) => Stack(
                alignment: Alignment.topLeft,
                children: [...previous, if (current != null) current],
              ),
              child: Column(
                key: ValueKey(mode),
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 32, color: ENetColors.text, fontWeight: FontWeight.w800, letterSpacing: -1.1, height: 1.1),
                  ),
                  const SizedBox(height: 9),
                  Text(subtitle, style: const TextStyle(fontSize: 15, color: ENetColors.muted, height: 1.5)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 26),
          _collapsible(
            show: !reset,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 22),
              child: GlassSegmented(
                labels: const ['Вход', 'Регистрация'],
                index: signUp ? 1 : 0,
                onChanged: (i) => change(i == 0 ? _AuthMode.signIn : _AuthMode.signUp),
              ),
            ),
          ),
          _collapsible(
            show: signUp,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextFormField(
                key: const ValueKey('name'),
                controller: name,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(labelText: 'Как тебя называть', prefixIcon: Icon(Icons.person_outline_rounded)),
                validator: (v) => (v == null || v.trim().length < 2) ? 'Минимум два символа' : null,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextFormField(
              key: const ValueKey('email'),
              controller: email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: reset ? TextInputAction.done : TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              onFieldSubmitted: reset ? (_) => submit() : null,
              decoration: const InputDecoration(labelText: 'Электронная почта', prefixIcon: Icon(Icons.alternate_email_rounded)),
              validator: checkEmail,
            ),
          ),
          _collapsible(
            show: !reset,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextFormField(
                key: const ValueKey('password'),
                controller: password,
                obscureText: !passwordVisible,
                textInputAction: signUp ? TextInputAction.next : TextInputAction.done,
                onFieldSubmitted: signUp ? null : (_) => submit(),
                decoration: InputDecoration(
                  labelText: 'Пароль',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => passwordVisible = !passwordVisible),
                    icon: AnimatedSwitcher(
                      duration: ENetMotion.quick,
                      transitionBuilder: (child, animation) => FadeTransition(
                        opacity: animation,
                        child: ScaleTransition(scale: animation, child: child),
                      ),
                      child: Icon(
                        passwordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        key: ValueKey(passwordVisible),
                      ),
                    ),
                  ),
                ),
                validator: (v) => (v == null || v.length < 12) ? 'Минимум 12 символов' : null,
              ),
            ),
          ),
          _collapsible(
            show: signUp,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TextFormField(
                key: const ValueKey('confirm'),
                controller: confirm,
                obscureText: !passwordVisible,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => submit(),
                decoration: const InputDecoration(labelText: 'Повтори пароль', prefixIcon: Icon(Icons.verified_user_outlined)),
                validator: (v) => (v != password.text) ? 'Пароли не совпадают' : null,
              ),
            ),
          ),
          _collapsible(
            show: signIn,
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton(onPressed: () => change(_AuthMode.reset), child: const Text('Забыли пароль?')),
            ),
          ),
          const SizedBox(height: 10),
          PrimaryButton(
            label: reset ? 'Продолжить' : signIn ? 'Войти' : 'Создать аккаунт',
            icon: Icons.arrow_forward_rounded,
            loading: busy,
            onPressed: busy ? null : submit,
          ),
          _collapsible(
            show: reset,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: TextButton.icon(
                onPressed: () => change(_AuthMode.signIn),
                icon: const Icon(Icons.arrow_back_rounded, size: 18),
                label: const Text('Вернуться ко входу'),
              ),
            ),
          ),
          _collapsible(
            show: notice != null,
            child: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: (noticeIsError ? ENetColors.danger : ENetColors.mint).withValues(alpha: .10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: (noticeIsError ? ENetColors.danger : ENetColors.mint).withValues(alpha: .3)),
                ),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(noticeIsError ? Icons.error_outline_rounded : Icons.check_circle_rounded,
                    color: noticeIsError ? ENetColors.danger : ENetColors.mint, size: 20),
                  const SizedBox(width: 10),
                  Expanded(child: Text(notice ?? '', style: const TextStyle(color: ENetColors.text, fontSize: 13, height: 1.45))),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 14),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.info_outline_rounded, size: 14, color: ENetColors.faint),
            SizedBox(width: 7),
            Flexible(
              child: Text(
                'eNet ID: аккаунты и пароли обрабатываются на сервере.',
                textAlign: TextAlign.center,
                style: TextStyle(color: ENetColors.faint, fontSize: 11.5, height: 1.5),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _FadeIn extends StatelessWidget {
  const _FadeIn({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: 1),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOut,
        builder: (context, value, child) => Opacity(opacity: value, child: child),
        child: child,
      );
}

class _IdentityPanel extends StatelessWidget {
  const _IdentityPanel();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final headline = math.min(66.0, math.max(38.0, constraints.maxWidth / 7));
      return Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
        const BrandLogo(size: 64),
        const SizedBox(height: 72),
        const Text(
          'ТВОЁ ПРОСТРАНСТВО',
          style: TextStyle(fontSize: 12, letterSpacing: 3.2, color: ENetColors.cyan, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        ShaderMask(
          blendMode: BlendMode.srcIn,
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFA9EEFF)],
          ).createShader(rect),
          child: Text(
            'Создано для\nновых идей.',
            style: TextStyle(fontSize: headline, letterSpacing: -headline * .04, height: 1.03, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ),
        const SizedBox(height: 22),
        const Text(
          'Единая основа для будущих возможностей eNet.\nБез лишнего. Всё важное впереди.',
          style: TextStyle(fontSize: 16, height: 1.7, color: ENetColors.muted),
        ),
        const SizedBox(height: 44),
        const Wrap(spacing: 10, runSpacing: 10, children: [
          _Chip(icon: Icons.auto_awesome_rounded, label: 'Продуманный дизайн'),
          _Chip(icon: Icons.layers_rounded, label: 'Единая платформа'),
          _Chip(icon: Icons.bolt_rounded, label: 'Плавные анимации'),
        ]),
      ]);
    });
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Glass(
        radius: 30,
        blur: 18,
        shadow: false,
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: ENetColors.cyan, size: 17),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(fontSize: 12.5, color: ENetColors.text, fontWeight: FontWeight.w500)),
        ]),
      );
}
