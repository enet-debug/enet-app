import 'dart:math' as math;
import 'package:flutter/material.dart';
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

class _Dest {
  const _Dest(this.icon, this.activeIcon, this.label);
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

const _weekdays = ['понедельник', 'вторник', 'среда', 'четверг', 'пятница', 'суббота', 'воскресенье'];
const _months = [
  'января', 'февраля', 'марта', 'апреля', 'мая', 'июня',
  'июля', 'августа', 'сентября', 'октября', 'ноября', 'декабря',
];

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

  static const items = [
    _Dest(Icons.home_outlined, Icons.home_rounded, 'Главная'),
    _Dest(Icons.notifications_none_rounded, Icons.notifications_rounded, 'Уведомления'),
    _Dest(Icons.account_circle_outlined, Icons.account_circle_rounded, 'Профиль'),
    _Dest(Icons.tune_rounded, Icons.tune_rounded, 'Настройки'),
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
    if (previous == 1 || next == 1) _refreshUnreadCount();
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 5) return 'Доброй ночи';
    if (h < 12) return 'Доброе утро';
    if (h < 18) return 'Добрый день';
    return 'Добрый вечер';
  }

  String _dateLabel() {
    final n = DateTime.now();
    return '${_weekdays[n.weekday - 1]}, ${n.day} ${_months[n.month - 1]}'.toUpperCase();
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
          child: Stack(children: [
            Positioned.fill(
              child: compact
                  ? _content(compact)
                  : Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(width: 270, child: _sidebar()),
                    ),
                    Expanded(child: _content(compact)),
                  ]),
            ),
            if (compact)
              Positioned(
                left: 16,
                right: 16,
                bottom: math.max(bottomInset, 10.0) + 6,
                child: _tabBar(),
              ),
          ]),
        ),
      ),
    );
  }

  // ───────────────────────── Навигация ─────────────────────────

  Widget _sidebar() {
    const itemHeight = 46.0;
    const gap = 4.0;
    return Glass(
      radius: 30,
      padding: const EdgeInsets.fromLTRB(14, 22, 14, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Padding(padding: EdgeInsets.only(left: 8), child: BrandLogo(size: 40)),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.only(left: 10, bottom: 26),
          child: Text('DEVELOPER WORKSPACE',
              style: TextStyle(color: ENetColors.cyan.withValues(alpha: .85),
                fontSize: 9.5, fontWeight: FontWeight.w800, letterSpacing: 2.0)),
        ),
        const Padding(padding: EdgeInsets.only(left: 10, bottom: 12),
          child: Text('НАВИГАЦИЯ', style: _eyebrow)),
        SizedBox(
          height: items.length * (itemHeight + gap),
          child: Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 480),
              curve: Curves.easeOutQuart,
              top: index * (itemHeight + gap),
              left: 0,
              right: 0,
              height: itemHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  gradient: LinearGradient(colors: [
                    ENetColors.mint.withValues(alpha: .20),
                    ENetColors.blue.withValues(alpha: .06),
                  ]),
                  border: Border.all(color: ENetColors.cyan.withValues(alpha: .28)),
                  boxShadow: [BoxShadow(color: ENetColors.blue.withValues(alpha: .20), blurRadius: 20)],
                ),
              ),
            ),
            for (var i = 0; i < items.length; i++)
              Positioned(
                top: i * (itemHeight + gap),
                left: 0,
                right: 0,
                height: itemHeight,
                child: _sideItem(i),
              ),
          ]),
        ),
        const Spacer(),
        Pressable(
          onTap: () => go(2),
          builder: (context, hovered) => AnimatedContainer(
            duration: ENetMotion.quick,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: hovered ? .10 : .05),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: .08)),
            ),
            child: Row(children: [
              ENetAvatar(name: user.name, size: 38),
              const SizedBox(width: 11),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(user.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ENetColors.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(user.email, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: ENetColors.muted, fontSize: 11.5)),
                ]),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  Widget _sideItem(int i) {
    final selected = index == i;
    return Pressable(
      onTap: () => go(i),
      pressedScale: .97,
      builder: (context, hovered) => AnimatedContainer(
        duration: ENetMotion.quick,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          color: Colors.white.withValues(alpha: hovered && !selected ? .06 : 0),
        ),
        child: Row(children: [
          _TintedIcon(selected ? items[i].activeIcon : items[i].icon, selected: selected, size: 22),
          const SizedBox(width: 13),
          Flexible(
            fit: FlexFit.loose,
            child: AnimatedDefaultTextStyle(
              duration: ENetMotion.medium,
              style: TextStyle(
                color: selected ? ENetColors.text : ENetColors.muted,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              child: Text(items[i].label,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ),
          if (i == 1 && (_unreadCount ?? 0) > 0) ...[
            const Spacer(),
            _UnreadChip(count: _unreadCount!),
          ],
        ]),
      ),
    );
  }

  Widget _tabBar() {
    return Glass(
      radius: 32,
      blur: 34,
      strength: 1.3,
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        height: 58,
        child: LayoutBuilder(builder: (context, constraints) {
          final w = constraints.maxWidth / items.length;
          return Stack(children: [
            AnimatedPositioned(
              duration: const Duration(milliseconds: 480),
              curve: Curves.easeOutQuart,
              left: index * w,
              top: 0,
              bottom: 0,
              width: w,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [ENetColors.mint.withValues(alpha: .23), ENetColors.mint.withValues(alpha: .07)],
                    ),
                    border: Border.all(color: ENetColors.mint.withValues(alpha: .22)),
                  ),
                ),
              ),
            ),
            Row(children: [
              for (var i = 0; i < items.length; i++)
                SizedBox(
                  width: w,
                  child: Pressable(
                    onTap: () => go(i),
                    pressedScale: .9,
                    builder: (context, _) {
                      final selected = index == i;
                      return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                        AnimatedScale(
                          scale: selected ? 1.1 : 1,
                          duration: ENetMotion.medium,
                          curve: Curves.easeOutBack,
                          child: _TintedIcon(selected ? items[i].activeIcon : items[i].icon, selected: selected, size: 24),
                        ),
                        const SizedBox(height: 3),
                        AnimatedDefaultTextStyle(
                          duration: ENetMotion.medium,
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w600,
                            color: selected ? ENetColors.text : ENetColors.muted,
                          ),
                          child: Text(items[i].label, maxLines: 1),
                        ),
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
    final pad = compact ? 18.0 : 38.0;
    return Column(children: [
      Padding(
        padding: EdgeInsets.fromLTRB(pad, compact ? 12 : 20, pad, 0),
        child: _topBar(compact),
      ),
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(pad, 20, pad, compact ? 130 : 48),
          child: LayoutBuilder(builder: (context, constraints) {
            final width = math.min(constraints.maxWidth, 1050.0);
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
        Text('eNet / WORKSPACE', style: TextStyle(
          color: ENetColors.text, fontWeight: FontWeight.w800, fontSize: 12.5)),
        SizedBox(height: 3),
        Text('Единое пространство', style: TextStyle(
          color: ENetColors.faint, fontSize: 11)),
      ]),
      const Spacer(),
      IconButton(
        tooltip: (_unreadCount ?? 0) > 0
          ? 'Уведомления: $_unreadCount непрочитанных'
          : 'Открыть уведомления',
        onPressed: () => go(1),
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
      const _DemoBadge(),
      if (compact) ...[
        const SizedBox(width: 12),
        Pressable(onTap: () => go(2), builder: (context, _) => ENetAvatar(name: user.name, size: 38)),
      ],
    ]);
  }

  Widget _page(bool compact) {
    switch (index) {
      case 1:
        return _notifications();
      case 2:
        return _profile(compact);
      case 3:
        return _settings();
      default:
        return _home(compact);
    }
  }

  // ───────────────────────── Главная ─────────────────────────

  Widget _home(bool compact) {
    final titleSize = compact ? 36.0 : 48.0;
    return Column(key: const ValueKey('home'), crossAxisAlignment: CrossAxisAlignment.start, children: [
      Reveal(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_dateLabel(), style: _eyebrow),
          const SizedBox(height: 10),
          ShaderMask(
            blendMode: BlendMode.srcIn,
            shaderCallback: (rect) => const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFB4F8D7)],
            ).createShader(rect),
            child: Text(
              '${_greeting()},\n${user.name}',
              style: TextStyle(fontSize: titleSize, fontWeight: FontWeight.w800, letterSpacing: -titleSize * .035, height: 1.05, color: Colors.white),
            ),
          ),
        ]),
      ),
      const SizedBox(height: 8),
      const Text('Все твои инструменты в одном пространстве.',
          style: TextStyle(color: ENetColors.muted, fontSize: 14.5)),
      const SizedBox(height: 26),
      Reveal(delay: const Duration(milliseconds: 120), child: _hero(compact)),
      const SizedBox(height: 28),
      DashboardStatus(auth: widget.auth, openAccount: () => go(2), openSettings: () => go(3)),
      const SizedBox(height: 34),
      ServiceCatalogPanel(auth: widget.auth),
      const SizedBox(height: 30),
      const Reveal(delay: Duration(milliseconds: 200), child: Text('ПРОСТРАНСТВО', style: _eyebrow)),
      const SizedBox(height: 16),
      LayoutBuilder(builder: (context, constraints) {
        final tiles = [
          _FeatureTile(
            icon: Icons.person_rounded,
            gradient: ENetColors.violetGradient,
            heading: 'Профиль',
            body: 'Персональное пространство и данные аккаунта.',
            onTap: () => go(2),
          ),
          _FeatureTile(
            icon: Icons.tune_rounded,
            gradient: ENetColors.mintGradient,
            heading: 'Настройки',
            body: 'Управление оформлением и параметрами.',
            onTap: () => go(3),
          ),
          _FeatureTile(
            icon: Icons.notifications_active_outlined,
            gradient: ENetColors.amberGradient,
            heading: 'Уведомления',
            body: 'История входов и сообщения аккаунта.',
            onTap: () => go(1),
          ),
        ];
        final delays = [220, 280, 340];
        if (constraints.maxWidth < 700) {
          return Column(children: [
            for (var i = 0; i < tiles.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Reveal(delay: Duration(milliseconds: delays[i]), child: tiles[i]),
              ),
          ]);
        }
        return IntrinsicHeight(
          child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            for (var i = 0; i < tiles.length; i++)
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i == tiles.length - 1 ? 0 : 14),
                  child: Reveal(delay: Duration(milliseconds: delays[i]), child: tiles[i]),
                ),
              ),
          ]),
        );
      }),
    ]);
  }

  Widget _hero(bool compact) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF174B37), Color(0xFF102B23), Color(0xFF081713)],
          stops: [0, .52, 1],
        ),
        border: Border.all(color: ENetColors.mint.withValues(alpha: .30)),
        boxShadow: [
          BoxShadow(color: ENetColors.mint.withValues(alpha: .10),
            blurRadius: 54, offset: const Offset(0, 18)),
        ],
      ),
      child: Stack(children: [
        const Positioned.fill(child: _HeroOrbits()),
        Padding(
          padding: EdgeInsets.all(compact ? 26 : 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: ENetColors.mint.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(100),
                  border: Border.all(color: ENetColors.mint.withValues(alpha: .27)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.bolt_rounded, color: ENetColors.cyan, size: 14),
                  SizedBox(width: 6),
                  Text('ENET • DEVELOPER PLATFORM',
                    style: TextStyle(color: ENetColors.cyan, fontSize: 10,
                      letterSpacing: 1.4, fontWeight: FontWeight.w800)),
                ]),
              ),
              const SizedBox(height: 25),
              Text('Одна платформа.\\nВсе твои сервисы.',
                style: TextStyle(color: ENetColors.text,
                  fontSize: compact ? 29 : 39, fontWeight: FontWeight.w800,
                  letterSpacing: -1.3, height: 1.12)),
              const SizedBox(height: 12),
              const Text('eNet ID, рабочие инструменты и приложения.\\nБыстрый доступ без лишних переходов.',
                style: TextStyle(color: Color(0xFFB5DBCA), fontSize: 14.5, height: 1.6)),
              if (!compact) ...[
                const SizedBox(height: 25),
                Wrap(spacing: 9, runSpacing: 9, children: const [
                  _HeroTag(icon: Icons.verified_user_outlined, label: 'eNet ID'),
                  _HeroTag(icon: Icons.extension_outlined, label: 'Сервисы'),
                  _HeroTag(icon: Icons.security_outlined, label: 'Безопасность'),
                ]),
              ],
              SizedBox(height: compact ? 16 : 26),
              PrimaryButton(
                label: 'Управление аккаунтом',
                icon: Icons.arrow_forward_rounded,
                expand: false,
                onPressed: () => go(2),
              ),
            ]),
          ),
        ),
      ]),
    );
  }

  // ───────────────────────── Уведомления ─────────────────────────

  Widget _notifications() => NotificationsPanel(
    key: const ValueKey('notifications'),
    auth: widget.auth,
    onUnreadCountChanged: (count) {
      _unreadRequest++;
      if (mounted && count != _unreadCount) setState(() => _unreadCount = count);
    },
  );

  // ───────────────────────── Профиль ─────────────────────────

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
      const SizedBox(height: 24),
      AccountSecurityPanel(auth: widget.auth),
      const SizedBox(height: 24),
      DeviceSessionsPanel(auth: widget.auth),
      const SizedBox(height: 24),
      const Reveal(
        delay: Duration(milliseconds: 180),
        child: _Group(
          header: 'О ПРИЛОЖЕНИИ',
          footer: 'Другие настройки появятся вместе с новыми функциями eNet.',
          children: [
            _RowTile(icon: Icons.info_rounded, gradient: ENetColors.amberGradient, title: 'Версия', value: '0.7.1 (8)'),
          ],
        ),
      ),
    ]);
  }
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

class _HeroTag extends StatelessWidget {
  const _HeroTag({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFF0A1F17).withValues(alpha: .62),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ENetColors.mint.withValues(alpha: .18)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, color: ENetColors.cyan, size: 15),
      const SizedBox(width: 7),
      Text(label, style: const TextStyle(color: ENetColors.text,
        fontSize: 11.5, fontWeight: FontWeight.w600)),
    ]),
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
  Widget build(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 40, fontWeight: FontWeight.w800, letterSpacing: -1.5, color: ENetColors.text, height: 1.05)),
        const SizedBox(height: 8),
        Text(subtitle, style: const TextStyle(fontSize: 16, color: ENetColors.muted, height: 1.4)),
      ]);
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

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.icon,
    required this.gradient,
    required this.heading,
    required this.body,
    required this.onTap,
  });

  final IconData icon;
  final Gradient gradient;
  final String heading;
  final String body;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: .975,
      builder: (context, hovered) => AnimatedSlide(
        duration: ENetMotion.medium,
        curve: Curves.easeOutCubic,
        offset: Offset(0, hovered ? -.02 : 0),
        child: Glass(
          radius: 26,
          strength: hovered ? 1.5 : 1,
          padding: const EdgeInsets.all(22),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 150),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: gradient,
                    boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .3), blurRadius: 16, offset: const Offset(0, 6))],
                  ),
                  child: Icon(icon, color: Colors.white, size: 25),
                ),
                const Spacer(),
                  AnimatedSlide(
                    duration: ENetMotion.quick,
                    offset: Offset(hovered ? .2 : 0, 0),
                    child: const Icon(Icons.arrow_forward_rounded, size: 20, color: ENetColors.muted),
                  ),
              ]),
              const SizedBox(height: 20),
              Text(heading, style: const TextStyle(fontSize: 17, color: ENetColors.text, fontWeight: FontWeight.w700, letterSpacing: -.3)),
              const SizedBox(height: 7),
              Text(body, style: const TextStyle(fontSize: 13.5, color: ENetColors.muted, height: 1.5)),
            ]),
          ),
        ),
      ),
    );
  }
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
