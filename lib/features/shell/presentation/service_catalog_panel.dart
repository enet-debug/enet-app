import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/glass.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/domain/auth_repository.dart';

/// The catalog is loaded from eNet API, not hardcoded into the desktop UI.
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
      final result = await widget.auth.listServices();
      if (!mounted) return;
      setState(() { _services = result; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _open(String url) async {
    final uri = Uri.tryParse(url);
    // The API catalog must not open arbitrary local files or custom schemes.
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
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        const Text(
          'СЕРВИСЫ ENET',
          style: TextStyle(color: ENetColors.muted, fontSize: 11, letterSpacing: 1.8, fontWeight: FontWeight.w700),
        ),
        const Spacer(),
        IconButton(
          tooltip: 'Обновить сервисы',
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh_rounded, color: ENetColors.cyan),
        ),
      ]),
      const SizedBox(height: 12),
      if (_loading)
        const Padding(padding: EdgeInsets.all(22), child: LinearProgressIndicator())
      else if (_error != null)
        Glass(
          radius: 22,
          padding: const EdgeInsets.all(18),
          child: Row(children: [
            const Icon(Icons.cloud_off_outlined, color: ENetColors.danger),
            const SizedBox(width: 12),
            Expanded(child: Text('Не удалось загрузить сервисы: $_error',
                style: const TextStyle(color: ENetColors.muted, fontSize: 13))),
            IconButton(tooltip: 'Повторить', onPressed: _load, icon: const Icon(Icons.refresh)),
          ]),
        )
      else if (_services.isEmpty)
        const Text('Сервисы пока не добавлены.', style: TextStyle(color: ENetColors.muted))
      else
        for (final service in _services)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Glass(
              radius: 24,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
              child: Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    gradient: ENetColors.accent,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(Icons.apps_rounded, color: ENetColors.onAccent, size: 27),
                ),
                const SizedBox(width: 16),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(service.name, style: const TextStyle(
                    color: ENetColors.text, fontSize: 17, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 5),
                  Text(service.description, style: const TextStyle(
                    color: ENetColors.muted, fontSize: 13)),
                ])),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Открыть ${service.name}',
                  onPressed: () => _open(service.url),
                  icon: const Icon(Icons.open_in_new_rounded, color: ENetColors.cyan),
                ),
              ]),
            ),
          ),
    ]);
  }
}
