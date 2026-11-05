import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_repository.dart';

/// A searchable, responsive catalog powered by /v1/services.
class ServiceCatalogPanel extends StatefulWidget {
  const ServiceCatalogPanel({super.key, required this.auth});
  final AuthController auth;

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

  @override
  Widget build(BuildContext context) {
    final matches = _matches;
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
  });
  final EcosystemService service;
  final bool favorite;
  final VoidCallback? onFavorite;
  final VoidCallback open;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: 'Открыть сервис ${service.name}',
    child: Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: open,
        borderRadius: BorderRadius.circular(26),
        child: Glass(
          radius: 26,
          blur: 20,
          padding: const EdgeInsets.all(22),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Container(
                width: 52, height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(17),
                  gradient: ENetColors.accent,
                  boxShadow: [BoxShadow(
                    color: ENetColors.mint.withValues(alpha: .19),
                    blurRadius: 26, offset: const Offset(0, 10))],
                ),
                child: const Icon(Icons.dashboard_customize_rounded,
                  color: ENetColors.onAccent, size: 27),
              ),
              const Spacer(),
              IconButton(
                key: ValueKey('favorite-${service.id}'),
                tooltip: favorite ? 'Убрать из избранного' : 'Добавить в избранное',
                onPressed: onFavorite,
                icon: Icon(favorite ? Icons.star_rounded : Icons.star_border_rounded,
                  color: favorite ? ENetColors.mint : ENetColors.muted, size: 24),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.north_east_rounded, color: ENetColors.cyan, size: 21),
            ]),
            const SizedBox(height: 20),
            Text(service.name, maxLines: 1, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ENetColors.text, fontSize: 20,
                fontWeight: FontWeight.w800, letterSpacing: -.4)),
            const SizedBox(height: 8),
            Text(service.description, maxLines: 3, overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: ENetColors.muted, fontSize: 13,
                height: 1.5)),
            const SizedBox(height: 18),
            const Row(children: [
              Text('Открыть сервис', style: TextStyle(
                color: ENetColors.cyan, fontSize: 12.5, fontWeight: FontWeight.w700)),
              SizedBox(width: 6),
              Icon(Icons.arrow_forward_rounded, color: ENetColors.cyan, size: 16),
            ]),
          ]),
        ),
      ),
    ),
  );
}
