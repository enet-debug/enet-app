import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/ambient_background.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../core/widgets/glass.dart';
import '../../../core/widgets/glass_controls.dart';
import '../../../core/widgets/pressable.dart';
import '../../../core/widgets/premium_button.dart';
import '../../../core/widgets/reveal.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_repository.dart';
import 'account_security_panel.dart';
import 'service_catalog_panel.dart';
import 'device_sessions_panel.dart';
import 'profile_edit_button.dart';
import '../../auth/presentation/api_connection_panel.dart';
import 'dashboard_status.dart';
import 'notifications_panel.dart';
import 'tasks_panel.dart';
import 'workspace_visuals.dart';

class _Dest {
  const _Dest(this.index, this.icon, this.activeIcon, this.label);
  final int index;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const _eyebrow = TextStyle(color: ENetColors.muted, fontSize: 11, letterSpacing: 1.8, fontWeight: FontWeight.w700);

class ENetShell extends StatefulWidget {
  const ENetShell({super.key, required this.auth});
  final AuthController auth;

  @override
  State<ENetShell> createState() => _ENetShellState();
}

class _ENetShellState extends State<ENetShell> {
  int index = 0;
  int? _unreadCount;
  int _unreadRequest = 0;
  bool effects = true;
  bool _effectsTouched = false;
  final SharedPreferencesAsync _prefs = SharedPreferencesAsync();

  @override
  void initState() {
    super.initState();
    _restoreMotionPreference();
    _refreshUnreadCount();
  }

  Future<void> _restoreMotionPreference() async {
    try {
      final saved = await _prefs.getBool('enet.reduce_motion_effects');
      if (mounted && !_effectsTouched && saved != null) {
        setState(() => effects = saved);
      }
    } catch (_) {
      // App still works if the desktop preference store is unavailable.
    }
  }

  void _setEffects(bool enabled) {
    setState(() { effects = enabled; _effectsTouched = true; });
    _prefs.setBool('enet.reduce_motion_effects', enabled).ignore();
  }

  static const desktopItems = [
    _Dest(0, Icons.home_outlined, Icons.home_rounded, 'Главная'),
    _Dest(1, Icons.apps_outlined, Icons.apps_rounded, 'Сервисы'),
    _Dest(7, Icons.checklist_outlined, Icons.checklist_rounded, 'Задачи'),
    _Dest(9, Icons.folder_outlined, Icons.folder_rounded, 'Файлы'),
    _Dest(10, Icons.inventory_2_outlined, Icons.inventory_2_rounded, 'Проекты'),
    _Dest(11, Icons.bar_chart_outlined, Icons.bar_chart_rounded, 'Аналитика'),
    _Dest(3, Icons.fingerprint_rounded, Icons.fingerprint_rounded, 'eNet ID'),
    _Dest(4, Icons.shield_outlined, Icons.shield_rounded, 'Безопасность'),
    _Dest(6, Icons.settings_outlined, Icons.settings_rounded, 'Настройки'),
  ];

  static const mobileItems = [
    _Dest(0, Icons.home_outlined, Icons.home_rounded, 'Главная'),
    _Dest(1, Icons.search_rounded, Icons.search_rounded, 'Сервисы'),
    _Dest(-2, Icons.add_rounded, Icons.add_rounded, 'Создать'),
    _Dest(2, Icons.notifications_none_rounded, Icons.notifications_rounded, 'Уведомления'),
    _Dest(3, Icons.person_outline_rounded, Icons.person_rounded, 'Профиль'),
  ];

  static const moreItems = [
    _Dest(7, Icons.checklist_outlined, Icons.checklist_rounded, 'Задачи'),
    _Dest(2, Icons.notifications_none_rounded, Icons.notifications_rounded, 'Уведомления'),
    _Dest(5, Icons.devices_outlined, Icons.devices_rounded, 'Устройства'),
    _Dest(4, Icons.shield_outlined, Icons.shield_rounded, 'Безопасность'),
    _Dest(6, Icons.tune_rounded, Icons.tune_rounded, 'Настройки'),
    _Dest(8, Icons.info_outline_rounded, Icons.info_rounded, 'О приложении'),
  ];

  AuthUser get user => widget.auth.user!;

  Future<void> _refreshUnreadCount() async {
    final currentRequest = ++_unreadRequest;
    try {
      final feed = await widget.auth.listNotifications();
      if (mounted && currentRequest == _unreadRequest) {
        setState(() => _unreadCount = feed.unreadCount);
      }
    } catch (_) {
      // No notification badge when the server has not confirmed the count.
      if (mounted && currentRequest == _unreadRequest) {
        setState(() => _unreadCount = null);
      }
    }
  }

  void go(int next) {
    if (next == index) return;
    final previous = index;
    setState(() => index = next);
    if (previous == 2 || next == 2) _refreshUnreadCount();
  }

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 820;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      body: AmbientBackground(
        animated: effects,
        child: SafeArea(
          bottom: false,
          // Reserve an actual dock for mobile navigation instead of letting
          // it float over content, buttons and profile fields.
          child: compact
              ? Column(children: [
                  Expanded(child: _content(compact)),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      16, 8, 16, math.max(bottomInset, 10.0) + 6,
                    ),
                    child: _tabBar(),
                  ),
                ])
              : Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xD0071714),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: ENetColors.cyan.withValues(alpha: .22),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ENetColors.mint.withValues(alpha: .08),
                          blurRadius: 42,
                          spreadRadius: 1,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Column(children: [
                      SizedBox(
                        height: 45,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 17),
                          child: Row(children: [
                            const BrandLogo(size: 22, showName: false),
                            const SizedBox(width: 9),
                            const Text('eNet APP', style: TextStyle(
                              color: ENetColors.text,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            )),
                            const Expanded(
                              child: Center(child: Text('eNet APP',
                                style: TextStyle(
                                  color: ENetColors.muted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: .3,
                                ))),
                            ),
                            IconButton(
                              tooltip: (_unreadCount ?? 0) > 0
                                ? 'Уведомления: $_unreadCount непрочитанных'
                                : 'Открыть уведомления',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => go(2),
                              icon: Badge(
                                isLabelVisible: (_unreadCount ?? 0) > 0,
                                backgroundColor: ENetColors.mint,
                                textColor: ENetColors.onAccent,
                                label: Text(_unreadCount == null ? '' :
                                  _unreadCount! > 99 ? '99+' : '$_unreadCount'),
                                child: const Icon(Icons.notifications_none_rounded,
                                  color: ENetColors.cyan, size: 18),
                              ),
                            ),
                            const Text('v0.8.0', style: TextStyle(
                              color: ENetColors.faint,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            )),
                            const SizedBox(width: 14),
                            const _WindowDot(color: Color(0xFF39D98A)),
                            const SizedBox(width: 6),
                            const _WindowDot(color: Color(0xFFFFC84A)),
                            const SizedBox(width: 6),
                            const _WindowDot(color: Color(0xFFFF6B68)),
                          ]),
                        ),
                      ),
                      Expanded(child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8),
                            child: SizedBox(width: 200, child: _sidebar()),
                          ),
                          Container(width: 1, color: ENetColors.border),
                          Expanded(child: _content(compact)),
                        ],
                      )),
                    ]),
                  ),
                ),
        ),
      ),
    );
  }

  // ───────────────────────── Навигация ─────────────────────────

  Widget _sidebar() {
    const itemHeight = 40.0;
    const gap = 4.0;
    return Glass(
      radius: 19,
      blur: 14,
      padding: const EdgeInsets.fromLTRB(15, 20, 15, 15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(
          padding: EdgeInsets.only(left: 5),
          child: FittedBox(
            alignment: Alignment.centerLeft,
            fit: BoxFit.scaleDown,
            child: Row(children: [
              BrandLogo(size: 38),
              SizedBox(width: 5),
              Text('APP', style: TextStyle(
                color: ENetColors.text, fontSize: 11,
                fontWeight: FontWeight.w800, letterSpacing: 1.1)),
            ]),
          ),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 8, top: 2, bottom: 25),
          child: Text('v0.8.0', style: TextStyle(
            color: ENetColors.faint, fontSize: 10, letterSpacing: .7)),
        ),
        SizedBox(
          height: desktopItems.length * (itemHeight + gap),
          child: Stack(children: [
            if (desktopItems.any((item) => item.index == index))
              AnimatedPositioned(
                duration: ENetMotion.medium,
                curve: ENetMotion.curve,
                top: desktopItems.indexWhere((item) => item.index == index) * (itemHeight + gap),
                left: 0, right: 0, height: itemHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: ENetColors.mint.withValues(alpha: .18),
                    border: Border.all(color: ENetColors.mint.withValues(alpha: .34)),
                  ),
                ),
              ),
            for (var i = 0; i < desktopItems.length; i++)
              Positioned(
                top: i * (itemHeight + gap),
                left: 0, right: 0, height: itemHeight,
                child: _sideItem(i),
              ),
          ]),
        ),
        const Spacer(),
        Pressable(
          key: const ValueKey('desktop-nav-more'),
          onTap: _showMoreMenu,
          haptic: false,
          builder: (context, hovered) => Container(
            padding: const EdgeInsets.all(11),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(15),
              gradient: const LinearGradient(
                colors: [Color(0xFF07463B), Color(0xFF092720)]),
              border: Border.all(color: ENetColors.mint.withValues(
                alpha: hovered ? .65 : .28)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.cloud_outlined, color: ENetColors.cyan, size: 22),
                  SizedBox(width: 8),
                  Expanded(child: Text('Облако eNet', style: TextStyle(
                    color: ENetColors.text, fontSize: 12,
                    fontWeight: FontWeight.w700))),
                  Icon(Icons.more_horiz_rounded, color: ENetColors.muted, size: 18),
                ]),
                const SizedBox(height: 7),
                const Text('Подключение планируется', style: TextStyle(
                  color: ENetColors.muted, fontSize: 10)),
                const SizedBox(height: 9),
                Container(height: 4, decoration: BoxDecoration(
                  color: ENetColors.cyan.withValues(alpha: .16),
                  borderRadius: BorderRadius.circular(8))),
              ]),
          ),
        ),
      ]),
    );
  }

  Widget _sideItem(int i) {
    final destination = desktopItems[i];
    final selected = index == destination.index;
    return Pressable(
      key: ValueKey('desktop-nav-${destination.index}'),
      onTap: () => go(destination.index),
      pressedScale: .98,
      haptic: false,
      builder: (context, hovered) => AnimatedContainer(
        duration: ENetMotion.quick,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(13),
          color: Colors.white.withValues(alpha: hovered && !selected ? .045 : 0),
        ),
        child: Row(children: [
          _TintedIcon(selected ? destination.activeIcon : destination.icon,
            selected: selected, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(
            destination.label,
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: selected ? ENetColors.text : ENetColors.muted,
              fontSize: 13,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
          )),
          if (destination.index == 2 && (_unreadCount ?? 0) > 0)
            _UnreadChip(count: _unreadCount!),
        ]),
      ),
    );
  }

  Future<void> _showMoreMenu() async {
    final selected = await showDialog<int>(
      context: context,
      builder: (dialogContext) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Glass(
            radius: 22,
            blur: 18,
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(12, 4, 12, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text('ДОПОЛНИТЕЛЬНЫЕ РАЗДЕЛЫ', style: _eyebrow),
                ),
              ),
              for (final destination in moreItems)
                ListTile(
                  key: ValueKey('more-nav-${destination.index}'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: Icon(destination.icon, color: ENetColors.cyan),
                  title: Text(destination.label,
                    style: const TextStyle(color: ENetColors.text, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.chevron_right_rounded, color: ENetColors.faint),
                  onTap: () => Navigator.of(dialogContext).pop(destination.index),
                ),
            ]),
          ),
        ),
      ),
    );
    if (selected != null && mounted) go(selected);
  }

  Future<void> _showCreateMenu() async {
    final selected = await showModalBottomSheet<int>(
      context: context, backgroundColor: ENetColors.surface,
      showDragHandle: true,
      builder: (ctx) => SafeArea(child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 26),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Align(alignment: Alignment.centerLeft,
            child: Text('Быстрые действия',
              style: TextStyle(color: ENetColors.text,
                fontSize: 18, fontWeight: FontWeight.w800))),
          ListTile(
            leading: const Icon(Icons.shopping_bag_outlined, color: ENetColors.violet),
            title: const Text('Создать объявление'),
            subtitle: const Text('Открыть Продайзер через каталог'),
            onTap: () => Navigator.of(ctx).pop(1),
          ),
          ListTile(
            leading: const Icon(Icons.checklist_rounded, color: ENetColors.cyan),
            title: const Text('Новая задача'),
            onTap: () => Navigator.of(ctx).pop(7),
          ),
        ]),
      )),
    );
    if (selected != null && mounted) go(selected);
  }

  Widget _tabBar() => Glass(
    radius: 23, blur: 14, strength: .9,
    padding: const EdgeInsets.all(5),
    child: SizedBox(height: 58, child: Row(children: [
      for (final destination in mobileItems)
        Expanded(child: Pressable(
          key: ValueKey(destination.index == -2
            ? 'mobile-action-create' : 'mobile-nav-${destination.index}'),
          onTap: destination.index == -2
            ? _showCreateMenu : () => go(destination.index),
          haptic: false,
          builder: (context, hovered) => Center(
            child: destination.index == -2
              ? Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: ENetColors.mint,
                    boxShadow: [BoxShadow(
                      color: ENetColors.mint.withValues(alpha: .35),
                      blurRadius: 17, spreadRadius: 1)],
                  ),
                  child: const Icon(Icons.add_rounded,
                    color: ENetColors.onAccent, size: 29),
                )
              : Container(
                  width: 46, height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(15),
                    color: destination.index == index
                      ? ENetColors.mint.withValues(alpha: .16)
                      : Colors.transparent,
                  ),
                  child: _TintedIcon(
                    destination.index == index
                      ? destination.activeIcon : destination.icon,
                    selected: destination.index == index, size: 23),
                ),
          ),
        )),
    ])),
  );

  // ───────────────────────── Контент ─────────────────────────

  Widget _content(bool compact) {
    final pad = compact ? 16.0 : 24.0;
    return Column(children: [
      if (compact)
        Padding(
          padding: EdgeInsets.fromLTRB(pad, 10, pad, 0),
          child: _topBar(compact),
        ),
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, compact ? 13 : 20, pad, 24),
          child: LayoutBuilder(builder: (context, constraints) {
            final width = math.min(constraints.maxWidth, 1260.0);
            return Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: width,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 320),
                  switchInCurve: Curves.easeOut,
                  switchOutCurve: Curves.easeIn,
                  transitionBuilder: (child, animation) =>
                    FadeTransition(opacity: animation, child: child),
                  layoutBuilder: (current, previous) => Stack(
                    fit: StackFit.passthrough,
                    alignment: Alignment.topCenter,
                    children: [...previous, if (current != null) current],
                  ),
                  child: _page(compact),
                ),
              ),
            );
          }),
        ),
      ),
    ]);
  }

  Widget _topBar(bool compact) {
    return Row(children: [
      const BrandLogo(size: 32),
      const SizedBox(width: 6),
      const Text('APP', style: TextStyle(
        color: ENetColors.text, fontSize: 12, fontWeight: FontWeight.w800,
        letterSpacing: 1.1,
      )),
      const Spacer(),
      IconButton(
        key: const ValueKey('mobile-nav-more'),
        tooltip: 'Дополнительные разделы',
        onPressed: _showMoreMenu,
        icon: const Icon(Icons.more_horiz_rounded, color: ENetColors.cyan),
      ),
      IconButton(
        tooltip: (_unreadCount ?? 0) > 0
          ? 'Уведомления: $_unreadCount непрочитанных'
          : 'Открыть уведомления',
        onPressed: () => go(2),
        icon: Badge(
          isLabelVisible: (_unreadCount ?? 0) > 0,
          backgroundColor: ENetColors.mint,
          textColor: ENetColors.onAccent,
          label: Text(_unreadCount == null ? '' :
            _unreadCount! > 99 ? '99+' : '$_unreadCount'),
          child: const Icon(Icons.notifications_none_rounded,
            color: ENetColors.cyan, size: 22),
        ),
      ),
      const SizedBox(width: 8),
      Pressable(onTap: () => go(3),
        builder: (context, _) => ENetAvatar(name: user.name, size: 36)),
    ]);
  }

  Widget _page(bool compact) {
    switch (index) {
      case 1:
        return _services();
      case 2:
        return _notifications();
      case 3:
        return _profile(compact);
      case 4:
        return _security();
      case 5:
        return _devices();
      case 6:
        return _settings();
      case 7:
        return _tasks();
      case 8:
        return _about();
      case 9:
        return _comingSoon('Файлы', 'eNet Cloud ещё не подключён.',
          Icons.cloud_outlined, 'Смотреть сервисы', () => go(1));
      case 10:
        return _comingSoon('Проекты', 'Рабочая область в разработке.',
          Icons.folder_open_rounded, 'Перейти к задачам', () => go(7));
      case 11:
        return _comingSoon('Аналитика',
          'Показатели появятся после подключения источников данных.',
          Icons.bar_chart_rounded, 'Управление сеансами', () => go(5));
      default:
        return _home(compact);
    }
  }

  Widget _comingSoon(String title, String subtitle, IconData icon,
      String action, VoidCallback onAction) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      _PageTitle(title, subtitle),
      const SizedBox(height: 24),
      Glass(radius: 18, padding: const EdgeInsets.all(24),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: ENetColors.cyan, size: 34),
          const SizedBox(height: 16),
          Text('$title · скоро', style: const TextStyle(color: ENetColors.text,
            fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(subtitle, style: const TextStyle(color: ENetColors.muted)),
          const SizedBox(height: 14),
          TextButton.icon(onPressed: onAction,
            icon: const Icon(Icons.arrow_forward_rounded), label: Text(action)),
        ])),
    ]);

  // ───────────────────────── Главная ─────────────────────────

  Widget _home(bool compact) => LayoutBuilder(builder: (context, constraints) {
    final split = !compact && constraints.maxWidth >= 710;
    final railWidth = constraints.maxWidth >= 1050 ? 265.0 : 235.0;

    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact)
          MobileWelcomeScene(name: user.name, onOpenProfile: () => go(3))
        else ...[
          const Text('Добро пожаловать в eNet',
            style: TextStyle(color: ENetColors.text, fontSize: 26,
              fontWeight: FontWeight.w800, letterSpacing: -.8)),
          const SizedBox(height: 4),
          const Text('Ваша единая платформа для работы, автоматизации и ИИ',
            style: TextStyle(color: ENetColors.muted, fontSize: 12)),
        ],
        SizedBox(height: compact ? 10 : 15),
        _hero(compact),
      ],
    );

    final shortcuts = _shortcutStrip(compact);
    final catalog = ServiceCatalogPanel(
      auth: widget.auth,
      dashboard: true,
      onSeeAll: () => go(1),
    );

    final rail = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _accountSummaryCard(),
        const SizedBox(height: 11),
        _balancePreviewCard(),
        const SizedBox(height: 11),
        DashboardStatus(auth: widget.auth),
        const SizedBox(height: 11),
        _quickActionsCard(),
        const SizedBox(height: 11),
        DashboardSessionsSnapshot(auth: widget.auth, onManage: () => go(5)),
      ],
    );

    final central = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        intro,
        const SizedBox(height: 12),
        shortcuts,
        const SizedBox(height: 17),
        catalog,
      ],
    );

    if (split) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: central),
          const SizedBox(width: 18),
          SizedBox(width: railWidth, child: rail),
        ],
      );
    }

    // The phone reference has a focused landing view; the complete catalog
    // lives under "Сервисы" instead of pushing the quick-access card away.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        intro,
        const SizedBox(height: 17),
        shortcuts,
        const SizedBox(height: 17),
        _mobileQuickAccess(),
      ],
    );
  });

  Widget _shortcutStrip(bool compact) {
    final shortcuts = compact
      ? <(IconData, String, Color, VoidCallback)>[
          (Icons.grid_view_rounded, 'Сервисы', ENetColors.cyan, () => go(1)),
          (Icons.notifications_none_rounded, 'Уведомления', ENetColors.cyan, () => go(2)),
          (Icons.check_box_outlined, 'Задачи', ENetColors.cyan, () => go(7)),
          (Icons.folder_outlined, 'Файлы', ENetColors.cyan, () => go(1)),
        ]
      : <(IconData, String, Color, VoidCallback)>[
          (Icons.shopping_bag_outlined, 'Продайзер', ENetColors.violet, () => go(1)),
          (Icons.auto_awesome_rounded, 'eNet AI', const Color(0xFF48BFFB), () => go(1)),
          (Icons.cloud_outlined, 'eNet Cloud', const Color(0xFF4DDFF0), () => go(1)),
          (Icons.folder_outlined, 'Проекты', ENetColors.mint, () => go(7)),
          (Icons.bar_chart_rounded, 'Аналитика', const Color(0xFFFFC75B), () => go(5)),
        ];
    return LayoutBuilder(builder: (context, constraints) {
      final gap = compact ? 7.0 : 8.0;
      final width = (constraints.maxWidth - gap * (shortcuts.length - 1)) / shortcuts.length;
      return Row(children: [
        for (var i = 0; i < shortcuts.length; i++) ...[
          if (i > 0) SizedBox(width: gap),
          SizedBox(width: width, child: _HomeShortcut(data: _HomeShortcutData(
            icon: shortcuts[i].$1, title: shortcuts[i].$2,
            subtitle: shortcuts[i].$2, color: shortcuts[i].$3,
            onTap: shortcuts[i].$4))),
        ],
      ]);
    });
  }

  Widget _mobileQuickAccess() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Text('Быстрый доступ', style: TextStyle(
        color: ENetColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
      const SizedBox(height: 10),
      Pressable(onTap: () => go(1), haptic: false,
        builder: (context, hovered) => Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            gradient: const LinearGradient(colors: [
              Color(0xFF123A38), Color(0xFF071D20)]),
            border: Border.all(color: ENetColors.mint.withValues(
              alpha: hovered ? .63 : .24)),
          ),
          child: Row(children: [
            Container(width: 50, height: 50,
              decoration: BoxDecoration(
                gradient: ENetColors.violetGradient,
                borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.shopping_bag_outlined, color: Colors.white)),
            const SizedBox(width: 12),
            const Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Продайзер', style: TextStyle(color: ENetColors.text,
                  fontSize: 15, fontWeight: FontWeight.w800)),
                SizedBox(height: 4),
                Text('Создание объявлений с помощью ИИ',
                  style: TextStyle(color: ENetColors.muted, fontSize: 11)),
              ])),
            const Icon(Icons.chevron_right_rounded, color: ENetColors.cyan),
          ]),
        )),
    ],
  );

  Widget _balancePreviewCard() => Glass(
    radius: 17, blur: 12,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 13),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Баланс', style: TextStyle(color: ENetColors.text,
        fontSize: 12, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      const Text('Нет данных', style: TextStyle(color: ENetColors.text,
        fontSize: 22, fontWeight: FontWeight.w800)),
      const SizedBox(height: 4),
      const Text('Оплата ещё не подключена к eNet ID',
        style: TextStyle(color: ENetColors.muted, fontSize: 10)),
    ]),
  );

  Widget _accountSummaryCard() => Pressable(
    onTap: () => go(3),
    haptic: false,
    builder: (context, hovered) => Glass(
      radius: 17,
      blur: 12,
      padding: const EdgeInsets.all(13),
      child: Row(children: [
        ENetAvatar(name: user.name, size: 48),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ENetColors.text,
                fontSize: 14, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ENetColors.muted, fontSize: 10.5)),
            const SizedBox(height: 5),
            const Text('eNet ID · Аккаунт',
              style: TextStyle(color: ENetColors.cyan, fontSize: 9.5,
                fontWeight: FontWeight.w700)),
          ],
        )),
        const Icon(Icons.chevron_right_rounded, color: ENetColors.cyan, size: 20),
      ]),
    ),
  );

  Widget _quickActionsCard() => Glass(
    radius: 18,
    blur: 12,
    padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Row(children: [
        Icon(Icons.bolt_rounded, color: ENetColors.cyan, size: 19),
        SizedBox(width: 7),
        Expanded(child: Text('Быстрые действия',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: ENetColors.text, fontSize: 12, fontWeight: FontWeight.w800))),
      ]),
      const SizedBox(height: 7),
      _QuickAction(
        icon: Icons.shopping_bag_outlined,
        label: 'Создать объявление',
        onTap: () => go(1),
      ),
      _QuickAction(
        icon: Icons.checklist_rounded,
        label: 'Новая задача',
        onTap: () => go(7),
      ),
      _QuickAction(
        icon: Icons.devices_rounded,
        label: 'Файлы и облако',
        onTap: () => go(9),
      ),
    ]),
  );

  Widget _services() => Column(
    key: const ValueKey('services'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _PageTitle('Сервисы', 'Приложения, подключённые к экосистеме eNet.'),
      const SizedBox(height: 22),
      ServiceCatalogPanel(auth: widget.auth),
    ],
  );

  Widget _tasks() => Column(
    key: const ValueKey('tasks'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      TasksPanel(auth: widget.auth),
    ],
  );

  Widget _security() => Column(
    key: const ValueKey('security'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _PageTitle('Безопасность', 'Защита аккаунта и управление доступом.'),
      const SizedBox(height: 22),
      AccountSecurityPanel(auth: widget.auth),
    ],
  );

  Widget _devices() => Column(
    key: const ValueKey('devices'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _PageTitle('Устройства', 'Активные сеансы твоего eNet ID.'),
      const SizedBox(height: 22),
      DeviceSessionsPanel(auth: widget.auth),
    ],
  );

  Widget _notifications() => NotificationsPanel(
    key: const ValueKey('notifications'),
    auth: widget.auth,
    onUnreadCountChanged: (count) {
      _unreadRequest++;
      if (mounted && count != _unreadCount) setState(() => _unreadCount = count);
    },
  );

  // ───────────────────────── Главная карточка ─────────────────────────

  Widget _hero(bool compact) {
    // Mobile follows the reference's quiet ID card. The luminous ribbon and
    // tilted eNet mark belong only to the wide desktop hero.
    if (compact) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => go(3),
          borderRadius: BorderRadius.circular(19),
          child: Container(
            key: const ValueKey('workspace-hero'),
            width: double.infinity,
            height: 104,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              gradient: const LinearGradient(
                begin: Alignment.topLeft, end: Alignment.bottomRight,
                colors: [Color(0xFF0B423A), Color(0xFF072A2A), Color(0xFF051B1B)],
              ),
              border: Border.all(color: ENetColors.mint.withValues(alpha: .39)),
              boxShadow: [
                BoxShadow(color: ENetColors.mint.withValues(alpha: .12),
                  blurRadius: 20, offset: const Offset(0, 5)),
              ],
            ),
            child: Row(children: [
              Container(
                width: 58, height: 58,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF04A884), Color(0xFF076251)],
                  ),
                  border: Border.all(
                    color: ENetColors.cyan.withValues(alpha: .25)),
                ),
                child: const Icon(Icons.fingerprint_rounded,
                  color: ENetColors.cyan, size: 35),
              ),
              const SizedBox(width: 13),
              const Expanded(child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('eNet ID', style: TextStyle(
                    color: ENetColors.text, fontSize: 19,
                    fontWeight: FontWeight.w800)),
                  SizedBox(height: 4),
                  Text('Единый аккаунт eNet', style: TextStyle(
                    color: ENetColors.muted, fontSize: 11.5)),
                ],
              )),
              const Icon(Icons.chevron_right_rounded,
                color: ENetColors.cyan, size: 22),
            ]),
          ),
        ),
      );
    }
    const height = 162.0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => go(3),
        borderRadius: BorderRadius.circular(19),
        child: Container(
          key: const ValueKey('workspace-hero'),
          height: height,
          width: double.infinity,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color(0xFF063B32),
                Color(0xFF052A25),
                Color(0xFF061C1A),
              ],
            ),
            border: Border.all(color: ENetColors.mint.withValues(alpha: .38)),
            boxShadow: [
              BoxShadow(
                color: ENetColors.mint.withValues(alpha: .12),
                blurRadius: 25,
                offset: const Offset(0, 9),
              ),
            ],
          ),
          child: Stack(children: [
            const Positioned.fill(child: HeroRibbonArtwork()),
            Positioned(
              right: compact ? -12 : 18,
              top: compact ? 7 : 8,
              child: Transform.rotate(
                angle: -.16,
                child: Container(
                  width: compact ? 70 : 155,
                  height: compact ? 90 : 116,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(compact ? 17 : 23),
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF102B29), Color(0xFF041514)],
                    ),
                    border: Border.all(color: ENetColors.cyan.withValues(alpha: .48)),
                    boxShadow: [
                      BoxShadow(
                        color: ENetColors.mint.withValues(alpha: .22),
                        blurRadius: 25,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Stack(children: [
                    Positioned.fill(child: DecoratedBox(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(compact ? 17 : 23),
                        gradient: RadialGradient(
                          center: const Alignment(.2, -.3),
                          radius: 1.1,
                          colors: [
                            ENetColors.cyan.withValues(alpha: .24),
                            Colors.transparent,
                          ],
                        ),
                      ),
                    )),
                    Center(child: BrandLogo(
                      size: compact ? 42 : 79,
                      showName: false,
                    )),

                  ]),
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 13 : 16,
                vertical: compact ? 11 : 15,
              ),
              child: Row(children: [
                Container(
                  width: compact ? 46 : 55,
                  height: compact ? 46 : 55,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(compact ? 15 : 22),
                    gradient: const LinearGradient(
                      colors: [Color(0xFF00DDA3), Color(0xFF007F62)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: ENetColors.mint.withValues(alpha: .24),
                        blurRadius: 22,
                        offset: const Offset(0, 7),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.fingerprint_rounded,
                    color: const Color(0xFF03231B),
                    size: compact ? 28 : 31,
                  ),
                ),
                SizedBox(width: compact ? 12 : 22),
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: compact ? 60 : 230),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('eNet ID',
                          style: TextStyle(
                            color: ENetColors.text,
                            fontSize: compact ? 17 : 23,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -.7,
                          )),
                        SizedBox(height: compact ? 4 : 8),
                        SizedBox(
                          width: compact ? 190 : 340,
                          child: Text(
                            compact
                              ? 'Единый доступ ко всем сервисам eNet'
                              : 'Ваш единый аккаунт для всех сервисов eNet',
                            maxLines: compact ? 2 : 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: const Color(0xFFD2F8E9),
                              fontSize: compact ? 10 : 12,
                              height: 1.3,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ),
    );
  }

  Future<void> _copyEnetId() async {
    try {
      await Clipboard.setData(ClipboardData(text: user.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('eNet ID скопирован')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось скопировать eNet ID')),
      );
    }
  }

  Widget _profile(bool compact) {
    final info = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -.8, color: ENetColors.text)),
      const SizedBox(height: 6),
      Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontSize: 15, color: ENetColors.muted)),
      const SizedBox(height: 14),
      const _DemoBadge(label: 'ENET ID · АКТИВЕН'),
    ]);
    return Column(key: const ValueKey('profile'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Reveal(child: _PageTitle('Профиль', 'Твой ENET ID и данные аккаунта.')),
      const SizedBox(height: 28),
      Reveal(
        delay: const Duration(milliseconds: 100),
        child: Glass(
          radius: 30,
          padding: EdgeInsets.all(compact ? 24 : 32),
          child: SizedBox(
            width: double.infinity,
            child: Flex(
              direction: compact ? Axis.vertical : Axis.horizontal,
              crossAxisAlignment: compact ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                ENetAvatar(name: user.name, size: 92),
                SizedBox(width: 26, height: compact ? 20 : 0),
                if (compact) info else Flexible(child: info),
              ],
            ),
          ),
        ),
      ),
      const SizedBox(height: 18),
      Reveal(
        delay: const Duration(milliseconds: 140),
        child: Glass(
          radius: 22,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          child: Row(children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: ENetColors.mint.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: ENetColors.mint.withValues(alpha: .25)),
              ),
              child: const Icon(Icons.fingerprint_rounded, color: ENetColors.cyan),
            ),
            const SizedBox(width: 13),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('ENET ID', style: _eyebrow),
                const SizedBox(height: 5),
                const Text('Постоянный идентификатор аккаунта',
                  style: TextStyle(color: ENetColors.muted, fontSize: 11.5)),
                const SizedBox(height: 7),
                SelectableText(user.id, style: const TextStyle(
                  color: ENetColors.text,
                  fontFamily: 'monospace',
                  fontSize: 12,
                  height: 1.45,
                  letterSpacing: .15,
                )),
              ],
            )),
            const SizedBox(width: 6),
            IconButton(
              tooltip: 'Скопировать eNet ID',
              onPressed: _copyEnetId,
              icon: const Icon(Icons.copy_rounded, color: ENetColors.cyan, size: 20),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 24),
      Reveal(
        delay: const Duration(milliseconds: 180),
        child: _Group(
          header: 'АККАУНТ',
          footer: 'Профиль загружен с сервера eNet ID.',
          children: [
            _RowTile(icon: Icons.person_rounded, gradient: ENetColors.violetGradient, title: 'Имя', value: user.name),
            _RowTile(icon: Icons.alternate_email_rounded, gradient: ENetColors.accent, title: 'Электронная почта', value: user.email),
            const _RowTile(icon: Icons.shield_rounded, gradient: ENetColors.mintGradient, title: 'Статус', value: 'Активный аккаунт'),
          ],
        ),
      ),
      ProfileEditButton(auth: widget.auth),
      const SizedBox(height: 24),
      Reveal(
        delay: const Duration(milliseconds: 260),
        child: SecondaryButton(
          label: 'Выйти из профиля',
          icon: Icons.logout_rounded,
          destructive: true,
          onPressed: widget.auth.busy ? null : widget.auth.signOut,
        ),
      ),
    ]);
  }

  Widget _about() => Column(
    key: const ValueKey('about'),
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _PageTitle('О приложении', 'eNet APP — единая экосистема цифровых сервисов.'),
      const SizedBox(height: 22),
      const Center(child: BrandLogo(size: 74)),
      const SizedBox(height: 12),
      const Center(child: Text('eNet APP · 0.8.0',
        style: TextStyle(color: ENetColors.text, fontSize: 17,
          fontWeight: FontWeight.w800))),
      const SizedBox(height: 6),
      const Center(child: Text('Windows · Linux · iOS',
        style: TextStyle(color: ENetColors.muted, fontSize: 12))),
      const SizedBox(height: 24),
      ApiConnectionPanel(auth: widget.auth),
    ],
  );

  // ───────────────────────── Настройки ─────────────────────────

  Widget _settings() {
    return Column(key: const ValueKey('settings'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Reveal(child: _PageTitle('Настройки', 'Оформление и параметры приложения.')),
      const SizedBox(height: 28),
      Reveal(
        delay: const Duration(milliseconds: 100),
        child: _Group(
          header: 'ОФОРМЛЕНИЕ',
          footer: 'Плавная анимация фона. Отключается автоматически, если в системе включено уменьшение движения.',
          children: [
            _RowTile(
              icon: Icons.auto_awesome_rounded,
              gradient: ENetColors.violetGradient,
              title: 'Динамический фон',
              subtitle: 'Анимированное свечение и орбиты',
              trailing: GlassToggle(value: effects, onChanged: _setEffects),
              onTap: () => _setEffects(!effects),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      ApiConnectionPanel(auth: widget.auth),
      const Reveal(
        delay: Duration(milliseconds: 180),
        child: _Group(
          header: 'О ПРИЛОЖЕНИИ',
          footer: 'Другие настройки появятся вместе с новыми функциями eNet.',
          children: [
            _RowTile(icon: Icons.info_rounded, gradient: ENetColors.mintGradient, title: 'Версия', value: '0.8.0 (10)'),
          ],
        ),
      ),
    ]);
  }
}

class _WindowDot extends StatelessWidget {
  const _WindowDot({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 9,
    height: 9,
    decoration: BoxDecoration(
      color: color,
      shape: BoxShape.circle,
      boxShadow: [
        BoxShadow(color: color.withValues(alpha: .45), blurRadius: 8),
      ],
    ),
  );
}

class _HomeShortcutData {
  const _HomeShortcutData({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
}

class _HomeShortcut extends StatelessWidget {
  const _HomeShortcut({required this.data});
  final _HomeShortcutData data;
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 820;
    return Tooltip(
      message: data.subtitle,
      child: Pressable(
        onTap: data.onTap, pressedScale: .97, haptic: false,
        builder: (context, hovered) => AnimatedContainer(
          duration: ENetMotion.quick,
          height: compact ? 85 : 105,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: compact
                ? [
                    const Color(0xFF122C2F),
                    hovered ? const Color(0xFF0C403C) : const Color(0xFF071B1D),
                  ]
                : [
                    data.color.withValues(alpha: hovered ? .47 : .32),
                    const Color(0xFF051B1B),
                  ],
            ),
            border: Border.all(color: compact
              ? ENetColors.cyan.withValues(alpha: hovered ? .58 : .25)
              : data.color.withValues(alpha: hovered ? .68 : .4)),
            boxShadow: [BoxShadow(
              color: data.color.withValues(alpha: .09),
              blurRadius: 12, offset: const Offset(0, 3),
            )],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(data.icon,
              color: compact ? const Color(0xFFCBFFF1) : data.color,
              size: compact ? 26 : 33),
            const SizedBox(height: 7),
            Text(data.title, maxLines: 1, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: ENetColors.text,
                fontSize: compact ? 9.5 : 12,
                fontWeight: FontWeight.w800)),
          ]),
        ),
      ),
    );
  }
}

class _UnreadChip extends StatelessWidget {
  const _UnreadChip({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: ENetColors.mint.withValues(alpha: .16),
      border: Border.all(color: ENetColors.mint.withValues(alpha: .3)),
      borderRadius: BorderRadius.circular(100),
    ),
    child: Text(count > 99 ? '99+' : '$count',
      style: const TextStyle(color: ENetColors.cyan,
        fontSize: 10, fontWeight: FontWeight.w800)),
  );
}

class _TintedIcon extends StatelessWidget {
  const _TintedIcon(this.icon, {required this.selected, required this.size});
  final IconData icon;
  final bool selected;
  final double size;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<Color?>(
        tween: ColorTween(end: selected ? ENetColors.cyan : ENetColors.muted),
        duration: ENetMotion.medium,
        builder: (context, color, _) => Icon(icon, size: size, color: color),
      );
}

class _DemoBadge extends StatelessWidget {
  const _DemoBadge({this.label = 'ENET ID'});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: ENetColors.cyan.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: ENetColors.cyan.withValues(alpha: .25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 6, height: 6, decoration: const BoxDecoration(shape: BoxShape.circle, color: ENetColors.cyan)),
          const SizedBox(width: 7),
          Text(label, style: const TextStyle(fontSize: 10.5, letterSpacing: 1.3, fontWeight: FontWeight.w800, color: ENetColors.cyan)),
        ]),
      );
}

class _PageTitle extends StatelessWidget {
  const _PageTitle(this.title, this.subtitle);
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: TextStyle(
        fontSize: compact ? 30 : 38,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        color: ENetColors.text,
        height: 1.08,
      )),
      const SizedBox(height: 8),
      Text(subtitle, style: TextStyle(
        fontSize: compact ? 14 : 15,
        color: ENetColors.muted,
        height: 1.4,
      )),
    ]);
  }
}

/// Сгруппированный список в стиле «Настроек» iOS.
class _Group extends StatelessWidget {
  const _Group({this.header, this.footer, required this.children});
  final String? header;
  final String? footer;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (header != null) Padding(padding: const EdgeInsets.only(left: 8, bottom: 12), child: Text(header!, style: _eyebrow)),
      Glass(
        radius: 26,
        child: Column(children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const Divider(indent: 66),
            children[i],
          ],
        ]),
      ),
      if (footer != null)
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
          child: Text(footer!, style: const TextStyle(fontSize: 12.5, color: ENetColors.faint, height: 1.5)),
        ),
    ]);
  }
}

class _RowTile extends StatelessWidget {
  const _RowTile({
    required this.icon,
    required this.gradient,
    required this.title,
    this.subtitle,
    this.value,
    this.trailing,
    this.onTap,
  });

  final IconData icon;
  final Gradient gradient;
  final String title;
  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(11), gradient: gradient),
          child: Icon(icon, size: 20, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: ENetColors.text, fontSize: 15.5, fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: const TextStyle(color: ENetColors.muted, fontSize: 13)),
            ],
          ]),
        ),
        if (value != null)
          Flexible(
            child: Padding(
              padding: const EdgeInsets.only(left: 12),
              child: Text(value!, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: ENetColors.muted, fontSize: 14.5)),
            ),
          ),
        if (trailing != null) trailing!,
      ]),
    );
    if (onTap == null) return row;
    return Pressable(onTap: onTap, pressedScale: .99, builder: (context, _) => row);
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(11),
      child: SizedBox(
        height: 36,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Row(children: [
            Icon(icon, color: ENetColors.cyan, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text(label, maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: ENetColors.text,
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
              ))),
            const Icon(Icons.chevron_right_rounded,
              color: ENetColors.faint, size: 17),
          ]),
        ),
      ),
    ),
  );
}
