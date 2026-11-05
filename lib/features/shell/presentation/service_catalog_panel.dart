import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_repository.dart';

/// A searchable, responsive catalog powered by /v1/services.
class ServiceCatalogPanel extends StatefulWidget {
  const ServiceCatalogPanel({
    super.key,
    required this.auth,
    this.compact = false,
    this.dashboard = false,
    this.onSeeAll,
  });
  final AuthController auth;
  final bool compact;
  final bool dashboard;
  final VoidCallback? onSeeAll;

  @override
  State<ServiceCatalogPanel> createState() => _ServiceCatalogPanelState();
}

class _ServiceCatalogPanelState extends State<ServiceCatalogPanel> {
  bool _loading = true;
  List<EcosystemService> _services = const [];
  String? _error;
  String _query = '';
  bool _onlyFavorites = false;
  bool _savingFavorite = false;
  Set<String> _favoriteIds = {};
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  List<EcosystemService> get _matches {
    final q = _query.trim().toLowerCase();
    final visible = _services.where((service) =>
      (!_onlyFavorites || _favoriteIds.contains(service.id)) &&
      (q.isEmpty || service.name.toLowerCase().contains(q) ||
        service.description.toLowerCase().contains(q))).toList(growable: true);
    visible.sort((a, b) {
      final left = _favoriteIds.contains(a.id);
      final right = _favoriteIds.contains(b.id);
      if (left == right) return 0;
      return left ? -1 : 1;
    });
    return visible;
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await Future.wait<Object>([
        widget.auth.listServices(),
        widget.auth.favoriteServices(),
      ]);
      if (!mounted) return;
      setState(() {
        _services = result[0] as List<EcosystemService>;
        _favoriteIds = Set<String>.from(result[1] as List<String>);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _toggleFavorite(EcosystemService service) async {
    if (_savingFavorite) return;
    setState(() => _savingFavorite = true);
    final next = Set<String>.from(_favoriteIds);
    if (!next.add(service.id)) next.remove(service.id);
    try {
      final saved = await widget.auth.saveFavoriteServices(next.toList());
      if (mounted) setState(() => _favoriteIds = saved.toSet());
    } catch (e) {
      _notify(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _savingFavorite = false);
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    // Never trust the catalog to launch file:// or arbitrary device schemes.
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      _notify('Некорректная ссылка на сервис');
      return;
    }
    try {
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        _notify('Не удалось открыть сервис');
      }
    } catch (_) {
      _notify('Не удалось открыть сервис');
    }
  }

  void _notify(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Widget _buildDashboard(List<EcosystemService> matches) {
    final query = _query.trim().toLowerCase();
    final hasCloud = matches.any((service) =>
      service.id.toLowerCase().contains('cloud') ||
      service.name.toLowerCase().contains('cloud'));
    final hasAi = matches.any((service) =>
      service.id.toLowerCase().contains('ai') ||
      service.name.toLowerCase().contains('ai'));
    final showCloud = !hasCloud &&
      (query.isEmpty || 'enet cloud'.contains(query) || 'облачное хранилище'.contains(query));
    final showAi = !hasAi &&
      (query.isEmpty || 'enet ai'.contains(query) || 'генерация контента'.contains(query));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          const Expanded(child: Text('Сервисы eNet', style: TextStyle(
            color: ENetColors.text,
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -.55,
          ))),
          if (widget.onSeeAll != null)
            TextButton(
              onPressed: widget.onSeeAll,
              style: TextButton.styleFrom(
                foregroundColor: ENetColors.cyan,
                padding: const EdgeInsets.symmetric(horizontal: 5),
                visualDensity: VisualDensity.compact,
              ),
              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                Text('Все сервисы', style: TextStyle(fontFamily: 'Roboto', fontSize: 11.5, fontWeight: FontWeight.w700)),
                Icon(Icons.chevron_right_rounded, size: 17),
              ]),
            ),
        ]),
        const SizedBox(height: 8),
        SizedBox(
          height: 43,
          child: TextField(
            key: const ValueKey('dashboard-service-search'),
            controller: _search,
            onChanged: (value) => setState(() => _query = value),
            style: const TextStyle(color: ENetColors.text, fontSize: 12.5),
            decoration: InputDecoration(
              hintText: 'Поиск сервисов...',
              hintStyle: const TextStyle(color: ENetColors.muted, fontSize: 12),
              prefixIcon: const Icon(Icons.search_rounded, size: 19, color: ENetColors.muted),
              suffixIcon: _query.isEmpty ? null : IconButton(
                tooltip: 'Очистить поиск',
                visualDensity: VisualDensity.compact,
                onPressed: () {
                  _search.clear();
                  setState(() => _query = '');
                },
                icon: const Icon(Icons.close_rounded, size: 17),
              ),
              filled: true,
              fillColor: const Color(0xFF061C1A).withValues(alpha: .92),
              contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 13),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide(color: ENetColors.mint.withValues(alpha: .18)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: BorderSide(color: ENetColors.mint.withValues(alpha: .16)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(13),
                borderSide: const BorderSide(color: ENetColors.cyan, width: 1.1),
              ),
            ),
          ),
        ),
        const SizedBox(height: 11),
        if (_loading && _services.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 14),
            child: LinearProgressIndicator(minHeight: 2),
          )
        else if (_error != null && _services.isEmpty)
          Glass(
            radius: 16,
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.cloud_off_rounded, color: ENetColors.danger, size: 19),
              const SizedBox(width: 9),
              Expanded(child: Text('Не удалось загрузить каталог: $_error',
                style: const TextStyle(color: ENetColors.muted, fontSize: 11))),
              IconButton(onPressed: _load,
                icon: const Icon(Icons.refresh_rounded, color: ENetColors.cyan)),
            ]),
          )
        else ...[
          for (final service in matches) ...[
            _DashboardServiceTile(
              title: service.name,
              description: _dashboardDescription(service),
              icon: _dashboardIcon(service),
              color: _dashboardColor(service),
              active: true,
              popular: service.name.toLowerCase().contains('продайзер') ||
                service.id.toLowerCase().contains('prodayzer'),
              favorite: _favoriteIds.contains(service.id),
              onOpen: () => _open(service.url),
              onFavorite: _savingFavorite ? null : () => _toggleFavorite(service),
            ),
            const SizedBox(height: 9),
          ],
          if (showCloud) ...[
            const _DashboardServiceTile(
              title: 'eNet Cloud',
              description: 'Облачное хранилище для ваших файлов и проектов',
              icon: Icons.cloud_outlined,
              color: Color(0xFF42C8F5),
              active: false,
            ),
            const SizedBox(height: 9),
          ],
          if (showAi) ...[
            const _DashboardServiceTile(
              title: 'eNet AI',
              description: 'Единый доступ к нейросетям для создания текстов, изображений и контента',
              icon: Icons.auto_awesome_rounded,
              color: Color(0xFFB58BFF),
              active: false,
            ),
          ],
          if (matches.isEmpty && !showCloud && !showAi)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('По запросу сервисы не найдены.',
                style: TextStyle(color: ENetColors.muted, fontSize: 11.5)),
            ),
        ],
        if (_error != null && _services.isNotEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Показаны последние загруженные данные.',
              style: TextStyle(color: ENetColors.danger, fontSize: 10.5)),
          ),
      ],
    );
  }

  String _dashboardDescription(EcosystemService service) {
    final id = service.id.toLowerCase();
    final name = service.name.toLowerCase();
    if (id.contains('prodayzer') || name.contains('продайзер')) {
      return 'Генерация объявлений, улучшение фото и помощь в продаже товаров';
    }
    if (id.contains('cloud') || name.contains('cloud')) {
      return 'Облачное хранилище для ваших файлов и проектов';
    }
    if (id.contains('ai') || name.contains('ai')) {
      return 'Единый доступ к нейросетям для создания текстов, изображений и контента';
    }
    return service.description;
  }

  IconData _dashboardIcon(EcosystemService service) {
    final id = service.id.toLowerCase();
    final name = service.name.toLowerCase();
    if (id.contains('prodayzer') || name.contains('продайзер')) {
      return Icons.shopping_bag_outlined;
    }
    if (id.contains('cloud') || name.contains('cloud')) return Icons.cloud_outlined;
    if (id.contains('ai') || name.contains('ai')) return Icons.auto_awesome_rounded;
    return Icons.apps_rounded;
  }

  Color _dashboardColor(EcosystemService service) {
    final id = service.id.toLowerCase();
    final name = service.name.toLowerCase();
    if (id.contains('prodayzer') || name.contains('продайзер')) {
      return const Color(0xFFB58BFF);
    }
    if (id.contains('cloud') || name.contains('cloud')) {
      return const Color(0xFF42C8F5);
    }
    if (id.contains('ai') || name.contains('ai')) {
      return const Color(0xFFB58BFF);
    }
    return ENetColors.cyan;
  }

  Widget _buildCompact(List<EcosystemService> matches) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Row(children: [
        const Expanded(child: Text('Мои сервисы', style: TextStyle(
          color: ENetColors.text,
          fontSize: 17,
          fontWeight: FontWeight.w800,
          letterSpacing: -.35,
        ))),
        if (widget.onSeeAll != null)
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onSeeAll,
              borderRadius: BorderRadius.circular(12),
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 7, vertical: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text('Все сервисы', style: TextStyle(
                    color: ENetColors.cyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  )),
                  SizedBox(width: 2),
                  Icon(Icons.chevron_right_rounded,
                    size: 16, color: ENetColors.cyan),
                ]),
              ),
            ),
          ),
        IconButton(
          tooltip: 'Обновить сервисы',
          onPressed: _loading ? null : _load,
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.refresh_rounded, color: ENetColors.cyan, size: 19),
        ),
      ]),
      const SizedBox(height: 11),
      if (_loading && _services.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 18),
          child: LinearProgressIndicator(),
        )
      else if (_error != null && _services.isEmpty)
        Glass(
          radius: 18,
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            const Icon(Icons.cloud_off_rounded, color: ENetColors.danger),
            const SizedBox(width: 10),
            Expanded(child: Text('Не удалось загрузить сервисы: $_error',
              style: const TextStyle(color: ENetColors.muted, fontSize: 12))),
            IconButton(onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, color: ENetColors.cyan)),
          ]),
        )
      else if (_services.isEmpty)
        const Glass(
          radius: 18,
          padding: EdgeInsets.all(18),
          child: Text('Подключённых сервисов пока нет.',
            style: TextStyle(color: ENetColors.muted, fontSize: 12.5)),
        )
      else if (matches.isEmpty)
        const Glass(
          radius: 18,
          padding: EdgeInsets.all(18),
          child: Text('Сервисы не найдены.',
            style: TextStyle(color: ENetColors.muted, fontSize: 12.5)),
        )
      else
        for (final service in matches) ...[
          _ServiceCard(
            service: service,
            favorite: _favoriteIds.contains(service.id),
            onFavorite: _savingFavorite ? null : () => _toggleFavorite(service),
            open: () => _open(service.url),
            compact: true,
          ),
          const SizedBox(height: 9),
        ],
      if (_error != null && _services.isNotEmpty)
        const Text('Не удалось обновить каталог. Показаны последние данные.',
          style: TextStyle(color: ENetColors.danger, fontSize: 11)),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
    if (widget.dashboard) return _buildDashboard(matches);
    if (widget.compact) return _buildCompact(matches);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('ВАШИ СЕРВИСЫ', style: TextStyle(
            color: ENetColors.muted, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w700)),
          SizedBox(height: 6),
          Text('Приложения eNet', style: TextStyle(
            color: ENetColors.text, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -.7)),
        ])),
        IconButton(
          tooltip: 'Обновить сервисы',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded, color: ENetColors.cyan),
        ),
      ]),
      if (_services.isNotEmpty) ...[
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilterChip(
            key: const ValueKey('favorites-only'),
            selected: _onlyFavorites,
            avatar: Icon(_onlyFavorites ? Icons.star_rounded : Icons.star_border_rounded,
              size: 18, color: ENetColors.cyan),
            label: Text('Избранное (${_favoriteIds.length})'),
            onSelected: (selected) => setState(() => _onlyFavorites = selected),
          ),
        ),
        const SizedBox(height: 13),
      ],
      if (_services.isNotEmpty) ...[
        TextField(
          key: const ValueKey('service-search'),
          controller: _search,
          onChanged: (value) => setState(() => _query = value),
          style: const TextStyle(color: ENetColors.text),
          decoration: InputDecoration(
            labelText: 'Поиск по сервисам',
            hintText: 'Название или описание',
            hintStyle: const TextStyle(color: ENetColors.faint),
            prefixIcon: const Icon(Icons.search_rounded),
            suffixIcon: _query.isEmpty
                ? null
                : IconButton(
                    tooltip: 'Очистить поиск',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () {
                      _search.clear();
                      setState(() => _query = '');
                    },
                  ),
          ),
        ),
        const SizedBox(height: 16),
      ],
      if (_loading && _services.isEmpty)
        const Padding(padding: EdgeInsets.all(22), child: LinearProgressIndicator())
      else if (_error != null && _services.isEmpty)
        Glass(
          radius: 22,
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            const Icon(Icons.cloud_off_outlined, color: ENetColors.danger),
            const SizedBox(width: 12),
            Expanded(child: Text('Не удалось загрузить сервисы: $_error',
              style: const TextStyle(color: ENetColors.muted, fontSize: 13))),
            IconButton(tooltip: 'Повторить', onPressed: _load,
              icon: const Icon(Icons.refresh_rounded, color: ENetColors.cyan)),
          ]),
        )
      else if (_services.isEmpty)
        const Text('Сервисы пока не добавлены.', style: TextStyle(color: ENetColors.muted))
      else if (matches.isEmpty)
        Padding(
          padding: const EdgeInsets.all(18),
          child: Text(
            _onlyFavorites && _query.isEmpty
              ? 'В избранном пока нет сервисов. Добавь их через звёздочку на карточке.'
              : 'По запросу «$_query» сервисы не найдены.',
            style: const TextStyle(color: ENetColors.muted)),
        )
      else
        LayoutBuilder(builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 660;
          final itemWidth = isWide ? (constraints.maxWidth - 14) / 2 : constraints.maxWidth;
          return Wrap(
            spacing: 14, runSpacing: 14,
            children: [
              for (final service in matches)
                SizedBox(width: itemWidth, child: _ServiceCard(
                  service: service,
                  favorite: _favoriteIds.contains(service.id),
                  onFavorite: _savingFavorite ? null : () => _toggleFavorite(service),
                  open: () => _open(service.url))),
            ],
          );
        }),
      if (_error != null && _services.isNotEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text('Не удалось обновить список. Показана последняя загрузка.',
            style: const TextStyle(color: ENetColors.danger, fontSize: 12)),
        ),
    ]);
  }
}

class _ServiceCard extends StatelessWidget {
  const _ServiceCard({
    required this.service,
    required this.favorite,
    required this.onFavorite,
    required this.open,
    this.compact = false,
  });
  final EcosystemService service;
  final bool favorite;
  final VoidCallback? onFavorite;
  final VoidCallback open;
  final bool compact;

  IconData get _serviceIcon {
    final id = service.id.toLowerCase();
    final name = service.name.toLowerCase();
    if (id.contains('prodayzer') || name.contains('продайзер')) {
      return Icons.auto_awesome_rounded;
    }
    if (id.contains('studio') || name.contains('studio')) {
      return Icons.code_rounded;
    }
    if (id == 'enet-id' || name == 'enet id') {
      return Icons.fingerprint_rounded;
    }
    return Icons.apps_rounded;
  }

  Gradient get _serviceGradient {
    final id = service.id.toLowerCase();
    final name = service.name.toLowerCase();
    if (id.contains('studio') || name.contains('studio')) {
      return ENetColors.violetGradient;
    }
    if (id == 'enet-id' || name == 'enet id') {
      return ENetColors.mintGradient;
    }
    return ENetColors.accent;
  }

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return Semantics(
        button: true,
        label: 'Открыть сервис ${service.name}',
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: open,
            borderRadius: BorderRadius.circular(18),
            child: Glass(
              radius: 18,
              blur: 12,
              shadow: false,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
              child: Row(children: [
                Container(
                  width: 43,
                  height: 43,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    gradient: _serviceGradient,
                    boxShadow: [
                      BoxShadow(
                        color: ENetColors.mint.withValues(alpha: .18),
                        blurRadius: 18,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Icon(_serviceIcon, color: ENetColors.onAccent, size: 23),
                ),
                const SizedBox(width: 11),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ENetColors.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      )),
                    const SizedBox(height: 3),
                    Text(service.description, maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: ENetColors.muted, fontSize: 10.5)),
                  ],
                )),
                const SizedBox(width: 5),
                IconButton(
                  tooltip: 'Открыть ${service.name}',
                  visualDensity: VisualDensity.compact,
                  onPressed: open,
                  icon: const Icon(Icons.open_in_new_rounded,
                    color: ENetColors.cyan, size: 18),
                ),
                IconButton(
                  key: ValueKey('favorite-${service.id}'),
                  tooltip: favorite ? 'Убрать из избранного' : 'Добавить в избранное',
                  visualDensity: VisualDensity.compact,
                  onPressed: onFavorite,
                  icon: Icon(
                    favorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: favorite ? ENetColors.mint : ENetColors.muted,
                    size: 19,
                  ),
                ),
              ]),
            ),
          ),
        ),
      );
    }

    return Semantics(
      button: true,
      label: 'Открыть сервис ${service.name}',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: open,
          borderRadius: BorderRadius.circular(26),
          child: Glass(
            radius: 20,
            blur: 12,
            padding: const EdgeInsets.all(17),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(18),
                    gradient: _serviceGradient,
                    boxShadow: [
                      BoxShadow(
                        color: ENetColors.mint.withValues(alpha: .17),
                        blurRadius: 24,
                        offset: const Offset(0, 9),
                      ),
                    ],
                  ),
                  child: Icon(_serviceIcon, color: ENetColors.onAccent, size: 27),
                ),
                const Spacer(),
                IconButton(
                  key: ValueKey('favorite-${service.id}'),
                  tooltip: favorite ? 'Убрать из избранного' : 'Добавить в избранное',
                  onPressed: onFavorite,
                  icon: Icon(
                    favorite ? Icons.star_rounded : Icons.star_border_rounded,
                    color: favorite ? ENetColors.mint : ENetColors.muted,
                    size: 23,
                  ),
                ),
              ]),
              const SizedBox(height: 14),
              Text(service.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ENetColors.text, fontSize: 16.5,
                  fontWeight: FontWeight.w800, letterSpacing: -.45)),
              const SizedBox(height: 7),
              Text(service.description, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: ENetColors.muted, fontSize: 13, height: 1.5)),
              const SizedBox(height: 17),
              Container(height: 1, color: ENetColors.border),
              const SizedBox(height: 13),
              Row(children: [
                const Text('Открыть сервис', style: TextStyle(
                  color: ENetColors.cyan, fontSize: 12.5,
                  fontWeight: FontWeight.w700)),
                const Spacer(),
                Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: ENetColors.mint.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: ENetColors.mint.withValues(alpha: .18)),
                  ),
                  child: const Icon(Icons.arrow_outward_rounded,
                    color: ENetColors.cyan, size: 16),
                ),
              ]),
            ]),
          ),
        ),
      ),
    );
  }
}

class _DashboardServiceTile extends StatelessWidget {
  const _DashboardServiceTile({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.active,
    this.popular = false,
    this.favorite = false,
    this.onOpen,
    this.onFavorite,
  });

  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool active;
  final bool popular;
  final bool favorite;
  final VoidCallback? onOpen;
  final VoidCallback? onFavorite;

  @override
  Widget build(BuildContext context) => Glass(
    radius: 16,
    blur: 11,
    shadow: false,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    tint: color,
    child: Row(children: [
      Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(15),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withValues(alpha: .95), color.withValues(alpha: .48)],
          ),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: .18), blurRadius: 16, offset: const Offset(0, 5)),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 29),
      ),
      const SizedBox(width: 13),
      Expanded(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Flexible(child: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ENetColors.text,
                fontSize: 14, fontWeight: FontWeight.w800))),
            if (popular) ...[
              const SizedBox(width: 7),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF9A6B23).withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFFC85B).withValues(alpha: .22)),
                ),
                child: const Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.local_fire_department_rounded,
                    color: Color(0xFFFFD06D), size: 11),
                  SizedBox(width: 3),
                  Text('Популярный', style: TextStyle(
                    color: Color(0xFFFFD06D), fontSize: 9,
                    fontWeight: FontWeight.w700)),
                ]),
              ),
            ],
          ]),
          const SizedBox(height: 4),
          Text(description, maxLines: 2, overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: ENetColors.muted, fontSize: 10.5, height: 1.3)),
        ],
      )),
      const SizedBox(width: 8),
      if (active)
        FilledButton(
          onPressed: onOpen,
          style: FilledButton.styleFrom(
            backgroundColor: ENetColors.mint,
            foregroundColor: ENetColors.onAccent,
            minimumSize: const Size(88, 36),
            padding: const EdgeInsets.symmetric(horizontal: 11),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            textStyle: const TextStyle(fontFamily: 'Roboto', fontSize: 11, fontWeight: FontWeight.w800),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.open_in_new_rounded, size: 14),
            SizedBox(width: 5),
            Text('Открыть', style: TextStyle(fontFamily: 'Roboto')),
          ]),
        )
      else
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: .06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white.withValues(alpha: .07)),
          ),
          child: const Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.schedule_rounded, size: 13, color: ENetColors.muted),
            SizedBox(width: 5),
            Text('Скоро', style: TextStyle(color: ENetColors.text,
              fontSize: 10.5, fontWeight: FontWeight.w700)),
          ]),
        ),
      if (!active) ...[
        const SizedBox(width: 4),
        const Icon(Icons.star_border_rounded, color: ENetColors.muted, size: 20),
      ],
      if (active) ...[
        const SizedBox(width: 4),
        IconButton(
          tooltip: favorite ? 'Убрать из избранного' : 'Добавить в избранное',
          visualDensity: VisualDensity.compact,
          onPressed: onFavorite,
          icon: Icon(favorite ? Icons.star_rounded : Icons.star_border_rounded,
            color: favorite ? const Color(0xFFFFC85B) : ENetColors.muted, size: 20),
        ),
      ],
    ]),
  );
}
