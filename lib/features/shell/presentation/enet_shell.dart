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
    _Dest(2, Icons.notifications_none_rounded, Icons.notifications_rounded, 'Уведомления'),
    _Dest(3, Icons.fingerprint_rounded, Icons.fingerprint_rounded, 'eNet ID'),
    _Dest(5, Icons.devices_outlined, Icons.devices_rounded, 'Устройства'),
    _Dest(4, Icons.shield_outlined, Icons.shield_rounded, 'Безопасность'),
    _Dest(6, Icons.tune_rounded, Icons.tune_rounded, 'Настройки'),
  ];

  static const mobileItems = [
    _Dest(0, Icons.home_outlined, Icons.home_rounded, 'Главная'),
    _Dest(1, Icons.apps_outlined, Icons.apps_rounded, 'Сервисы'),
    _Dest(2, Icons.notifications_none_rounded, Icons.notifications_rounded, 'Уведомл.'),
    _Dest(3, Icons.account_circle_outlined, Icons.account_circle_rounded, 'Профиль'),
    _Dest(-1, Icons.more_horiz_rounded, Icons.more_horiz_rounded, 'Ещё'),
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
                  padding: const EdgeInsets.all(12),
                  child: Container(
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: const Color(0xE8071714),
                      borderRadius: BorderRadius.circular(26),
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
                        height: 38,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 15),
                          child: Row(children: [
                            const BrandLogo(size: 22, showName: false),
                            const SizedBox(width: 9),
                            const Text('eNet APP', style: TextStyle(
                              color: ENetColors.text,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w800,
                            )),
                            const Spacer(),
                            const Text('v0.8.0', style: TextStyle(
                              color: ENetColors.faint,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            )),
                            const SizedBox(width: 15),
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
                            padding: const EdgeInsets.all(11),
                            child: SizedBox(width: 206, child: _sidebar()),
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
    const itemHeight = 43.0;
    const gap = 4.0;
    return Glass(
      radius: 24,
      blur: 16,
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(padding: EdgeInsets.only(left: 8), child: BrandLogo(size: 46)),
        const SizedBox(height: 12),
        const Padding(
          padding: EdgeInsets.only(left: 10, bottom: 22),
          child: Text('ЕДИНАЯ ЭКОСИСТЕМА',
            style: TextStyle(color: ENetColors.cyan, fontSize: 9.5,
              fontWeight: FontWeight.w800, letterSpacing: 1.8)),
        ),
        const Padding(
          padding: EdgeInsets.only(left: 10, bottom: 10),
          child: Text('НАВИГАЦИЯ', style: _eyebrow),
        ),
        SizedBox(
          height: desktopItems.length * (itemHeight + gap),
          child: Stack(children: [
            AnimatedPositioned(
              duration: ENetMotion.medium,
              curve: ENetMotion.curve,
              top: desktopItems.indexWhere((item) => item.index == index) * (itemHeight + gap),
              left: 0, right: 0, height: itemHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(13),
                  color: ENetColors.mint.withValues(alpha: .13),
                  border: Border.all(color: ENetColors.mint.withValues(alpha: .22)),
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
        const Divider(height: 22),
        Pressable(
          onTap: () => go(3),
          builder: (context, hovered) => AnimatedContainer(
            duration: ENetMotion.quick,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: hovered ? .08 : .035),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: Colors.white.withValues(alpha: .07)),
            ),
            child: Row(children: [
              ENetAvatar(name: user.name, size: 38),
              const SizedBox(width: 10),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ENetColors.text, fontSize: 13,
                      fontWeight: FontWeight.w700)),
                  const SizedBox(height: 3),
                  Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: ENetColors.muted, fontSize: 10.5)),
                ],
              )),
              const Icon(Icons.chevron_right_rounded, color: ENetColors.faint, size: 19),
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
              for (final destination in desktopItems.where((item) => item.index >= 4))
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

  Widget _tabBar() {
    return Glass(
      radius: 23, blur: 14, strength: .9,
      padding: const EdgeInsets.all(5),
      child: SizedBox(
        height: 58,
        child: LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth / mobileItems.length;
          final found = mobileItems.indexWhere((item) => item.index == index);
          final active = found < 0 ? mobileItems.length - 1 : found;
          return Stack(children: [
            AnimatedPositioned(
              duration: ENetMotion.medium,
              curve: ENetMotion.curve,
              left: active * w, top: 0, bottom: 0, width: w,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    color: ENetColors.mint.withValues(alpha: .12),
                    border: Border.all(color: ENetColors.mint.withValues(alpha: .18)),
                  ),
                ),
              ),
            ),
            Row(children: [
              for (var i = 0; i < mobileItems.length; i++)
                SizedBox(
                  width: w,
                  child: Pressable(
                    key: ValueKey(mobileItems[i].index < 0
                      ? 'mobile-nav-more'
                      : 'mobile-nav-${mobileItems[i].index}'),
                    onTap: mobileItems[i].index < 0
                      ? _showMoreMenu
                      : () => go(mobileItems[i].index),
                    pressedScale: .94,
                    haptic: false,
                    builder: (context, _) {
                      final destination = mobileItems[i];
                      final selected = i == active;
                      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        _TintedIcon(selected ? destination.activeIcon : destination.icon,
                          selected: selected, size: 22),
                        const SizedBox(height: 3),
                        Text(destination.label, maxLines: 1, overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                            color: selected ? ENetColors.text : ENetColors.muted,
                          )),
                      ]);
                    },
                  ),
                ),
            ]),
          ]);
        }),
      ),
    );
  }

  // ───────────────────────── Контент ─────────────────────────

  Widget _content(bool compact) {
    final pad = compact ? 16.0 : 25.0;
    return Column(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(pad, compact ? 10 : 12, pad, 0),
        child: _topBar(compact),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, compact ? 13 : 12, pad, 24),
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
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
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
      if (compact) const BrandLogo(size: 36)
      else const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('eNet APP', style: TextStyle(
          color: ENetColors.text, fontWeight: FontWeight.w800, fontSize: 13)),
        SizedBox(height: 3),
        Text('Единая экосистема для цифровых сервисов', style: TextStyle(
          color: ENetColors.faint, fontSize: 10.5)),
      ]),
      const Spacer(),
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
      const _DemoBadge(label: 'v0.8.0'),
      if (compact) ...[
        const SizedBox(width: 12),
        Pressable(onTap: () => go(3), builder: (context, _) => ENetAvatar(name: user.name, size: 38)),
      ],
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
      default:
        return _home(compact);
    }
  }

  // ───────────────────────── Главная ─────────────────────────

  Widget _home(bool compact) => LayoutBuilder(builder: (context, constraints) {
    final split = !compact && constraints.maxWidth >= 885;

    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (compact)
          MobileWelcomeScene(
            name: user.name,
            onOpenProfile: () => go(3),
          )
        else ...[
          const Text(
            'ВАША ЦИФРОВАЯ ЭКОСИСТЕМА',
            style: TextStyle(
              color: ENetColors.cyan,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.7,
            ),
          ),
          const SizedBox(height: 7),
          const Text(
            'Рабочее пространство eNet',
            style: TextStyle(
              color: ENetColors.text,
              fontSize: 25,
              fontWeight: FontWeight.w800,
              letterSpacing: -.8,
            ),
          ),
          const SizedBox(height: 5),
          const Text(
            'Сервисы, аккаунт и инструменты в одном месте.',
            style: TextStyle(
              color: ENetColors.muted,
              fontSize: 12.5,
            ),
          ),
        ],
        SizedBox(height: compact ? 12 : 17),
        _hero(compact),
      ],
    );

    final shortcuts = _shortcutStrip();
    final catalog = ServiceCatalogPanel(
      auth: widget.auth,
      compact: true,
      onSeeAll: () => go(1),
    );
    final rail = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _accountSummaryCard(),
        const SizedBox(height: 10),
        WorkspaceTaskSnapshot(
          auth: widget.auth,
          onOpenTasks: () => go(7),
        ),
        const SizedBox(height: 10),
        DashboardStatus(
          auth: widget.auth,
          openAccount: () => go(3),
          openSettings: () => go(4),
        ),
        const SizedBox(height: 10),
        _quickActionsCard(),
      ],
    );

    final central = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        intro,
        const SizedBox(height: 16),
        shortcuts,
        const SizedBox(height: 17),
        catalog,
        const SizedBox(height: 20),
        _featureHighlights(),
      ],
    );

    if (split) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: central),
          const SizedBox(width: 14),
          SizedBox(width: 255, child: rail),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        intro,
        const SizedBox(height: 15),
        shortcuts,
        const SizedBox(height: 18),
        catalog,
        const SizedBox(height: 15),
        _accountSummaryCard(),
        const SizedBox(height: 11),
        WorkspaceTaskSnapshot(
          auth: widget.auth,
          onOpenTasks: () => go(7),
        ),
        const SizedBox(height: 12),
        DashboardStatus(
          auth: widget.auth,
          openAccount: () => go(3),
          openSettings: () => go(4),
        ),
        const SizedBox(height: 11),
        _quickActionsCard(),
        const SizedBox(height: 19),
        _featureHighlights(),
      ],
    );
  });

  Widget _shortcutStrip() {
    final compact = MediaQuery.sizeOf(context).width < 820;
    final items = <_HomeShortcutData>[
      _HomeShortcutData(
        icon: Icons.apps_rounded,
        title: 'Сервисы',
        subtitle: 'Каталог',
        color: ENetColors.violet,
        onTap: () => go(1),
      ),
      _HomeShortcutData(
        icon: Icons.fingerprint_rounded,
        title: 'eNet ID',
        subtitle: 'Аккаунт',
        color: ENetColors.mint,
        onTap: () => go(3),
      ),
      _HomeShortcutData(
        icon: Icons.checklist_rounded,
        title: 'Задачи',
        subtitle: 'Планирование',
        color: ENetColors.cyan,
        onTap: () => go(7),
      ),
      _HomeShortcutData(
        icon: Icons.devices_rounded,
        title: 'Устройства',
        subtitle: 'Сеансы',
        color: ENetColors.blue,
        onTap: () => go(5),
      ),
      _HomeShortcutData(
        icon: Icons.notifications_active_outlined,
        title: 'События',
        subtitle: 'Уведомления',
        color: ENetColors.cyan,
        onTap: () => go(2),
      ),
    ];
    final visible = compact ? items.take(4).toList() : items;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(compact ? 'БЫСТРЫЙ ДОСТУП' : 'ВАШИ ИНСТРУМЕНТЫ', style: _eyebrow),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < visible.length; i++) ...[
              if (i > 0) const SizedBox(width: 9),
              Expanded(child: _HomeShortcut(data: visible[i])),
            ],
          ],
        ),
      ],
    );
  }

  Widget _featureHighlights() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const Padding(
        padding: EdgeInsets.only(left: 2, bottom: 11),
        child: Text('ВОЗМОЖНОСТИ eNet', style: _eyebrow),
      ),
      LayoutBuilder(builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760
            ? 6
            : constraints.maxWidth >= 530 ? 3 : 2;
        const gap = 10.0;
        final itemWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        final cards = <_FeatureCardData>[
          _FeatureCardData(
            icon: Icons.fingerprint_rounded,
            title: 'eNet ID',
            subtitle: 'Единый аккаунт',
            color: ENetColors.cyan,
            onTap: () => go(3),
          ),
          _FeatureCardData(
            icon: Icons.shield_outlined,
            title: 'Безопасность',
            subtitle: 'Пароль и доступ',
            color: ENetColors.blue,
            onTap: () => go(4),
          ),
          _FeatureCardData(
            icon: Icons.devices_rounded,
            title: 'Устройства',
            subtitle: 'Активные сеансы',
            color: ENetColors.mint,
            onTap: () => go(5),
          ),
          _FeatureCardData(
            icon: Icons.checklist_rounded,
            title: 'Задачи',
            subtitle: 'Планирование дел',
            color: ENetColors.cyan,
            onTap: () => go(7),
          ),
          _FeatureCardData(
            icon: Icons.notifications_active_outlined,
            title: 'Уведомления',
            subtitle: 'События аккаунта',
            color: ENetColors.violet,
            onTap: () => go(2),
          ),
          _FeatureCardData(
            icon: Icons.apps_rounded,
            title: 'Сервисы',
            subtitle: 'Приложения eNet',
            color: ENetColors.blue,
            onTap: () => go(1),
          ),
        ];
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final card in cards)
              SizedBox(width: itemWidth, child: _FeatureCard(data: card)),
          ],
        );
      }),
    ],
  );

  Widget _accountSummaryCard() => Pressable(
    onTap: () => go(3),
    haptic: false,
    builder: (context, hovered) => Glass(
      radius: 20, blur: 12,
      padding: const EdgeInsets.all(13),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          ENetAvatar(name: user.name, size: 40),
          const SizedBox(width: 11),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ENetColors.text,
                  fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: ENetColors.muted, fontSize: 10.5)),
            ],
          )),
          const Icon(Icons.chevron_right_rounded, color: ENetColors.faint),
        ]),
        const SizedBox(height: 15),
        Container(height: 1, color: ENetColors.border),
        const SizedBox(height: 12),
        Row(children: [
          const Icon(Icons.fingerprint_rounded, color: ENetColors.cyan, size: 19),
          const SizedBox(width: 8),
          const Expanded(child: Text('eNet ID аккаунта',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: ENetColors.muted, fontSize: 12))),
          IconButton(
            tooltip: 'Скопировать eNet ID',
            onPressed: _copyEnetId,
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_rounded, color: ENetColors.cyan, size: 18),
          ),
        ]),
      ]),
    ),
  );

  Widget _quickActionsCard() => Glass(
    radius: 20,
    blur: 12,
    padding: const EdgeInsets.fromLTRB(15, 13, 15, 7),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('БЫСТРЫЕ ДЕЙСТВИЯ', style: _eyebrow),
      const SizedBox(height: 7),
      _QuickAction(
        icon: Icons.add_task_rounded,
        label: 'Создать задачу',
        onTap: () => go(7),
      ),
      _QuickAction(
        icon: Icons.apps_rounded,
        label: 'Открыть сервисы',
        onTap: () => go(1),
      ),
      _QuickAction(
        icon: Icons.devices_rounded,
        label: 'Управлять устройствами',
        onTap: () => go(5),
      ),
      _QuickAction(
        icon: Icons.notifications_none_rounded,
        label: 'Уведомления',
        onTap: () => go(2),
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
    if (compact) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => go(3),
          borderRadius: BorderRadius.circular(19),
          child: Container(
            key: const ValueKey('workspace-hero'),
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(19),
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [Color(0xFF075C48), Color(0xFF07352C), Color(0xFF071F1B)],
              ),
              border: Border.all(color: ENetColors.mint.withValues(alpha: .42)),
            ),
            child: Row(children: [
              Container(
                width: 51, height: 51,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: ENetColors.accent,
                  boxShadow: [
                    BoxShadow(color: ENetColors.mint.withValues(alpha: .22),
                      blurRadius: 17),
                  ],
                ),
                child: const Icon(Icons.fingerprint_rounded,
                  color: ENetColors.onAccent, size: 29),
              ),
              const SizedBox(width: 13),
              const Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('eNet ID', style: TextStyle(
                    color: ENetColors.text, fontSize: 19,
                    fontWeight: FontWeight.w800, letterSpacing: -.5,
                  )),
                  SizedBox(height: 4),
                  Text('Единый аккаунт eNet', style: TextStyle(
                    color: Color(0xFFC1E8D9), fontSize: 11.5,
                  )),
                ],
              )),
              const Icon(Icons.chevron_right_rounded,
                color: ENetColors.cyan, size: 21),
            ]),
          ),
        ),
      );
    }

    return LayoutBuilder(builder: (context, constraints) {
    final showVisual = !compact && constraints.maxWidth >= 600;
    return Container(
      key: const ValueKey('workspace-hero'),
      width: double.infinity,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(23),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF07533F),
            Color(0xFF07352B),
            Color(0xFF071C19),
          ],
        ),
        border: Border.all(color: ENetColors.mint.withValues(alpha: .36)),
        boxShadow: [
          BoxShadow(
            color: ENetColors.mint.withValues(alpha: .15),
            blurRadius: 34,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(children: [
        if (showVisual) ...[
          const Positioned.fill(child: WorkspaceLightTrails()),
          const Positioned.fill(child: _HeroOrbits()),
          const Positioned(
            right: -8,
            top: -30,
            bottom: -30,
            child: Center(
              child: SizedBox(
                width: 188,
                height: 188,
                child: FittedBox(child: _HeroBrandMark()),
              ),
            ),
          ),
        ],
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 15 : 18,
            vertical: compact ? 14 : 16,
          ),
          child: Row(
            children: [
              Container(
                width: compact ? 48 : 54,
                height: compact ? 48 : 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: ENetColors.accent,
                  boxShadow: [
                    BoxShadow(
                      color: ENetColors.mint.withValues(alpha: .28),
                      blurRadius: 22,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  color: ENetColors.onAccent,
                  size: 30,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: showVisual ? 420 : 720,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('eNet ID · ЕДИНЫЙ АККАУНТ',
                        style: TextStyle(
                          color: ENetColors.cyan,
                          fontSize: 9.5,
                          letterSpacing: 1.1,
                          fontWeight: FontWeight.w800,
                        )),
                      const SizedBox(height: 8),
                      Text('Добро пожаловать в eNet',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: ENetColors.text,
                          fontSize: compact ? 20 : 25,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -.8,
                          height: 1.12,
                        )),
                      const SizedBox(height: 7),
                      Text(
                        'Единая платформа для работы, автоматизации и цифровых сервисов.',
                        maxLines: compact ? 3 : 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFFC5F0DF),
                          fontSize: 12,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 11),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: .16),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: ENetColors.cyan.withValues(alpha: .22),
                          ),
                        ),
                        child: const Text('ЕДИНЫЙ ВХОД В СЕРВИСЫ eNet',
                          style: TextStyle(
                            color: ENetColors.cyan,
                            fontSize: 9,
                            letterSpacing: .8,
                            fontWeight: FontWeight.w700,
                          )),
                      ),
                    ],
                  ),
                ),
              ),
              if (showVisual) const SizedBox(width: 140),
            ],
          ),
        ),
      ]),
    );
    });
  }

  // ───────────────────────── Профиль ─────────────────────────

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
        onTap: data.onTap,
        pressedScale: .97,
        haptic: false,
        builder: (context, hovered) => AnimatedContainer(
          duration: ENetMotion.quick,
          height: compact ? 86 : 93,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                data.color.withValues(alpha: hovered ? .37 : .28),
                const Color(0xFF071D1B),
              ],
            ),
            border: Border.all(
              color: data.color.withValues(alpha: hovered ? .65 : .34),
            ),
            boxShadow: [
              BoxShadow(
                color: data.color.withValues(alpha: hovered ? .16 : .07),
                blurRadius: 17,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 4 : 9,
            vertical: compact ? 9 : 11,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(data.icon, color: data.color, size: compact ? 25 : 29),
              const SizedBox(height: 9),
              Text(
                data.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: ENetColors.text,
                  fontSize: compact ? 10 : 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureCardData {
  const _FeatureCardData({
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

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.data});
  final _FeatureCardData data;

  @override
  Widget build(BuildContext context) => Pressable(
    onTap: data.onTap,
    pressedScale: .985,
    haptic: false,
    builder: (context, hovered) => Glass(
      radius: 18,
      blur: 11,
      shadow: false,
      padding: const EdgeInsets.all(13),
      tint: data.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: data.color.withValues(alpha: .14),
              border: Border.all(color: data.color.withValues(alpha: .32)),
            ),
            child: Icon(data.icon, color: data.color, size: 20),
          ),
          const SizedBox(height: 11),
          Text(data.title, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ENetColors.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            )),
          const SizedBox(height: 4),
          Text(data.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: ENetColors.muted,
              fontSize: 10,
            )),
        ],
      ),
    ),
  );
}

// ═════════════════════════ Вспомогательные виджеты ═════════════════════════

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

/// Фирменный знак в центре орбитальной композиции приветственного блока.
class _HeroBrandMark extends StatelessWidget {
  const _HeroBrandMark();

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: SizedBox(
      width: 220,
      height: 220,
      child: Stack(alignment: Alignment.center, children: [
        Container(
          width: 194, height: 194,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: ENetColors.cyan.withValues(alpha: .12)),
          ),
        ),
        Transform.rotate(
          angle: -.48,
          child: Container(
            width: 208, height: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: ENetColors.cyan.withValues(alpha: .24)),
            ),
          ),
        ),
        Transform.rotate(
          angle: .62,
          child: Container(
            width: 166, height: 64,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: Colors.white.withValues(alpha: .12)),
            ),
          ),
        ),
        Container(
          width: 116, height: 116,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const RadialGradient(
              colors: [Color(0xFF245B43), Color(0xFF0B2119)],
            ),
            border: Border.all(color: ENetColors.mint.withValues(alpha: .34)),
            boxShadow: [BoxShadow(
              color: ENetColors.mint.withValues(alpha: .20),
              blurRadius: 34, spreadRadius: 1,
            )],
          ),
          child: const Center(child: BrandLogo(size: 64, showName: false)),
        ),
        Positioned(top: 34, right: 38, child: _orbitalDot(ENetColors.cyan, 6)),
        Positioned(bottom: 36, left: 28, child: _orbitalDot(ENetColors.mint, 4)),
      ]),
    ),
  );

  Widget _orbitalDot(Color color, double size) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: color,
      boxShadow: [BoxShadow(color: color.withValues(alpha: .65), blurRadius: 16)],
    ),
  );
}

/// Анимированные орбиты на карточке-приветствии.
class _HeroOrbits extends StatefulWidget {
  const _HeroOrbits();

  @override
  State<_HeroOrbits> createState() => _HeroOrbitsState();
}

class _HeroOrbitsState extends State<_HeroOrbits> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(seconds: 30));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, _) => CustomPaint(painter: _OrbitsPainter(_controller.value), size: Size.infinite),
        ),
      ),
    );
  }
}

class _OrbitsPainter extends CustomPainter {
  const _OrbitsPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width * .86, size.height * .42);
    final r = math.min(size.height * .8, 260.0);

    canvas.drawCircle(
      center,
      r * 1.5,
      Paint()
        ..shader = RadialGradient(colors: [ENetColors.cyan.withValues(alpha: .26), ENetColors.cyan.withValues(alpha: 0)])
            .createShader(Rect.fromCircle(center: center, radius: r * 1.5)),
    );

    const radii = [.55, .8, 1.05];
    for (var i = 0; i < radii.length; i++) {
      canvas.drawCircle(
        center,
        r * radii[i],
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = Colors.white.withValues(alpha: .14 - i * .03),
      );
    }

    const speeds = [1, -1, 2];
    const phases = [.1, .55, .8];
    for (var i = 0; i < radii.length; i++) {
      final a = (t * speeds[i] + phases[i]) * math.pi * 2;
      final p = center + Offset(math.cos(a), math.sin(a)) * (r * radii[i]);
      canvas.drawCircle(
        p,
        8,
        Paint()
          ..color = ENetColors.cyan.withValues(alpha: .3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
      );
      canvas.drawCircle(p, 2.8, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitsPainter oldDelegate) => oldDelegate.t != t;
}
