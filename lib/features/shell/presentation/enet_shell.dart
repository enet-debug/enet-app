import 'package:flutter/material.dart';
import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../auth/application/auth_controller.dart';

class ENetShell extends StatefulWidget {
  const ENetShell({super.key, required this.auth});
  final AuthController auth;
  @override
  State<ENetShell> createState() => _ENetShellState();
}

class _ENetShellState extends State<ENetShell> {
  int currentIndex = 0;
  bool effects = true;
  static const items = [
    (icon: Icons.home_rounded, label: 'Главная'),
    (icon: Icons.notifications_none_rounded, label: 'Уведомления'),
    (icon: Icons.account_circle_outlined, label: 'Профиль'),
    (icon: Icons.tune_rounded, label: 'Настройки'),
  ];

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 760;
    return Scaffold(
      body: effects ? AmbientBackground(child: _layout(compact)) : ColoredBox(color: ENetColors.background, child: _layout(compact)),
      bottomNavigationBar: compact ? NavigationBar(
        backgroundColor: ENetColors.surface,
        indicatorColor: ENetColors.surfaceRaised,
        selectedIndex: currentIndex,
        onDestinationSelected: (index) => setState(() => currentIndex = index),
        destinations: [for (final item in items) NavigationDestination(icon: Icon(item.icon), label: item.label)],
      ) : null,
    );
  }

  Widget _layout(bool compact) => SafeArea(child: Row(children: [
    if (!compact) _sideBar(),
    Expanded(child: Padding(
      padding: EdgeInsets.symmetric(horizontal: compact ? 20 : 34, vertical: compact ? 20 : 26),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(compact),
        const SizedBox(height: 30),
        Expanded(child: SingleChildScrollView(child: AnimatedSwitcher(duration: const Duration(milliseconds: 240), child: _currentPage(compact)))),
      ]),
    )),
  ]));

  Widget _sideBar() => Container(
    width: 241, padding: const EdgeInsets.fromLTRB(17, 28, 17, 22),
    decoration: const BoxDecoration(color: Color(0xEE081321), border: Border(right: BorderSide(color: ENetColors.border))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Padding(padding: EdgeInsets.only(left: 13), child: BrandLogo(size: 43)),
      const SizedBox(height: 53),
      const Padding(padding: EdgeInsets.only(left: 13), child: Text('ПРОСТРАНСТВО', style: TextStyle(fontSize: 10, letterSpacing: 1.7, color: ENetColors.muted, fontWeight: FontWeight.w700))),
      const SizedBox(height: 13),
      for (int i = 0; i < items.length; i++) _navButton(i),
      const Spacer(),
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: ENetColors.surface, borderRadius: BorderRadius.circular(15), border: Border.all(color: ENetColors.border)),
        child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ENET · BASE', style: TextStyle(color: ENetColors.cyan, letterSpacing: 1.7, fontWeight: FontWeight.w700, fontSize: 10)),
          SizedBox(height: 9),
          Text('Фундамент будущего приложения', style: TextStyle(color: ENetColors.text, fontSize: 12, height: 1.5)),
        ]),
      ),
    ]),
  );

  Widget _navButton(int index) => Padding(padding: const EdgeInsets.only(bottom: 7), child: Material(
    color: currentIndex == index ? const Color(0xFF12354B) : Colors.transparent,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => currentIndex = index),
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: currentIndex == index ? Border.all(color: const Color(0xFF286B88)) : null),
        padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 14),
        child: Row(children: [
          Icon(items[index].icon, color: currentIndex == index ? ENetColors.cyan : ENetColors.muted, size: 21),
          const SizedBox(width: 13),
          Text(items[index].label, style: TextStyle(color: currentIndex == index ? ENetColors.text : ENetColors.muted, fontSize: 13, fontWeight: FontWeight.w600)),
        ]),
      ),
    ),
  ));

  Widget _header(bool compact) => Row(children: [
    if (compact) const BrandLogo(size: 37) else const Text('ENET / ЛИЧНОЕ ПРОСТРАНСТВО', style: TextStyle(color: ENetColors.muted, letterSpacing: 1.2, fontSize: 11, fontWeight: FontWeight.w600)),
    const Spacer(),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), border: Border.all(color: ENetColors.border), color: ENetColors.surface),
      child: const Text('ДЕМО', style: TextStyle(fontSize: 10, letterSpacing: 1.1, fontWeight: FontWeight.w800, color: ENetColors.cyan)),
    ),
    const SizedBox(width: 11),
    CircleAvatar(radius: 18, backgroundColor: ENetColors.surfaceRaised, child: Text(widget.auth.user!.name.characters.first.toUpperCase(), style: const TextStyle(color: ENetColors.cyan, fontWeight: FontWeight.w800))),
  ]);

  Widget _currentPage(bool compact) {
    switch (currentIndex) {
      case 1: return _information(key: const ValueKey(1), icon: Icons.notifications_none_rounded, title: 'Уведомления', body: 'Здесь появятся сообщения от eNet, когда мы подключим настоящие сервисы. Сейчас уведомлений нет.');
      case 2: return _profile();
      case 3: return _settings();
      default: return _home(compact);
    }
  }

  Widget _home(bool compact) => Column(key: const ValueKey(0), crossAxisAlignment: CrossAxisAlignment.start, children: [
    Container(
      padding: EdgeInsets.all(compact ? 23 : 36),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFF297193)),
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF0B2F4A), Color(0xFF102441), Color(0xFF071322)]),
        boxShadow: [BoxShadow(color: ENetColors.blue.withValues(alpha: .13), blurRadius: 32)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('ДОБРО ПОЖАЛОВАТЬ В ENET', style: TextStyle(color: ENetColors.cyan, fontSize: 10, letterSpacing: 1.8, fontWeight: FontWeight.w800)),
        const SizedBox(height: 18),
        Text('Привет, ${widget.auth.user!.name}!', style: TextStyle(color: ENetColors.text, fontSize: compact ? 29 : 40, fontWeight: FontWeight.w800, letterSpacing: -1.2)),
        const SizedBox(height: 9),
        const Text('Это начало твоего пространства. Скоро здесь появится всё, что мы создадим для eNet.', style: TextStyle(color: Color(0xFFC3DBEF), fontSize: 14, height: 1.6)),
        const SizedBox(height: 24),
        FilledButton.icon(onPressed: () => setState(() => currentIndex = 2), icon: const Icon(Icons.person_outline_rounded), label: const Text('Мой профиль')),
      ]),
    ),
    const SizedBox(height: 31),
    const Text('ТВОЁ ПРОСТРАНСТВО', style: TextStyle(color: ENetColors.muted, fontSize: 10, letterSpacing: 1.8, fontWeight: FontWeight.w700)),
    const SizedBox(height: 15),
    LayoutBuilder(builder: (context, constraints) {
      final tiles = [
        _FeatureTile(icon: Icons.layers_outlined, heading: 'Новые возможности', body: 'Добавим позже, когда определим направление приложения.', onTap: null),
        _FeatureTile(icon: Icons.person_outline_rounded, heading: 'Профиль', body: 'Персональное пространство и данные аккаунта.', onTap: () => setState(() => currentIndex = 2)),
        _FeatureTile(icon: Icons.tune_rounded, heading: 'Настройки', body: 'Управление оформлением и параметрами.', onTap: () => setState(() => currentIndex = 3)),
      ];
      if (constraints.maxWidth < 770) return Column(children: [for (final t in tiles) Padding(padding: const EdgeInsets.only(bottom: 12), child: t)]);
      return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [for (final t in tiles) Expanded(child: Padding(padding: const EdgeInsets.only(right: 11), child: t))]);
    }),
  ]);

  Widget _information({required Key key, required IconData icon, required String title, required String body}) => Column(key: key, crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text(title, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: ENetColors.text)),
    const SizedBox(height: 25),
    _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 40, color: ENetColors.cyan),
      const SizedBox(height: 21),
      Text(body, style: const TextStyle(color: ENetColors.muted, height: 1.7)),
    ])),
  ]);

  Widget _profile() => Column(key: const ValueKey(2), crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Профиль', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: ENetColors.text)),
    const SizedBox(height: 24),
    _panel(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('ENET ID · ДЕМО', style: TextStyle(color: ENetColors.cyan, fontSize: 11, letterSpacing: 1.7)),
      const SizedBox(height: 17),
      Text(widget.auth.user!.name, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800, color: ENetColors.text)),
      const SizedBox(height: 8),
      Text(widget.auth.user!.email),
      const SizedBox(height: 17),
      const Text('Это временный профиль для проверки интерфейса. После подключения сервера появятся настоящие учётные записи.', style: TextStyle(height: 1.65)),
      const SizedBox(height: 20),
      OutlinedButton.icon(onPressed: widget.auth.busy ? null : widget.auth.signOut, icon: const Icon(Icons.logout_rounded), label: const Text('Выйти из профиля')),
    ])),
  ]);

  Widget _settings() => Column(key: const ValueKey(3), crossAxisAlignment: CrossAxisAlignment.start, children: [
    const Text('Настройки', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: ENetColors.text)),
    const SizedBox(height: 24),
    _panel(Column(children: [
      SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        title: const Text('Динамический фон', style: TextStyle(color: ENetColors.text, fontWeight: FontWeight.w600)),
        subtitle: const Text('Плавная анимация орбит в интерфейсе'),
        value: effects,
        onChanged: (next) => setState(() => effects = next),
      ),
      const Divider(color: ENetColors.border),
      const SizedBox(height: 9),
      const Align(alignment: Alignment.centerLeft, child: Text('Другие настройки появятся вместе с новыми функциями eNet.', style: TextStyle(height: 1.6))),
    ])),
  ]);

  Widget _panel(Widget child) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(26),
    decoration: BoxDecoration(color: ENetColors.surface.withValues(alpha: .93), borderRadius: BorderRadius.circular(20), border: Border.all(color: ENetColors.border)),
    child: child,
  );
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.icon, required this.heading, required this.body, required this.onTap});
  final IconData icon;
  final String heading;
  final String body;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
    color: ENetColors.surface.withValues(alpha: .95),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(19),
        constraints: const BoxConstraints(minHeight: 153),
        decoration: BoxDecoration(border: Border.all(color: ENetColors.border), borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: ENetColors.cyan, size: 27),
          const SizedBox(height: 15),
          Text(heading, style: const TextStyle(fontSize: 15, color: ENetColors.text, fontWeight: FontWeight.w700)),
          const SizedBox(height: 7),
          Text(body, style: const TextStyle(fontSize: 12, height: 1.5)),
        ]),
      ),
    ),
  );
}
