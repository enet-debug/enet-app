import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/enet_theme.dart';
import '../../../core/widgets/glass.dart';

/// The navigation/search surface from the supplied eNet 0.7 archive.
/// Results are real destinations or discovered services, never demo entries.
class ENetSearchAction {
  const ENetSearchAction({
    required this.title,
    required this.icon,
    required this.onSelected,
    this.subtitle = '',
    this.keywords = '',
  });

  final String title;
  final String subtitle;
  final String keywords;
  final IconData icon;
  final VoidCallback onSelected;
}

/// Keyboard-accessible search: Ctrl+K / Cmd+K on desktop, search icon on mobile.
Future<void> showENetSearchPalette(
  BuildContext context, {
  required List<ENetSearchAction> actions,
  Future<List<ENetSearchAction>> Function()? loadServices,
}) => showGeneralDialog<void>(
  context: context,
  barrierDismissible: true,
  barrierLabel: 'Закрыть поиск',
  barrierColor: const Color(0xAA02080A),
  transitionDuration: const Duration(milliseconds: 220),
  pageBuilder: (context, animation, secondaryAnimation) =>
    _Palette(actions: actions, loadServices: loadServices),
  transitionBuilder: (context, animation, secondaryAnimation, child) =>
    FadeTransition(
      opacity: animation,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, -.025), end: Offset.zero)
          .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
);

class _Palette extends StatefulWidget {
  const _Palette({required this.actions, this.loadServices});
  final List<ENetSearchAction> actions;
  final Future<List<ENetSearchAction>> Function()? loadServices;

  @override
  State<_Palette> createState() => _PaletteState();
}

class _PaletteState extends State<_Palette> {
  final TextEditingController _query = TextEditingController();
  final ScrollController _scroll = ScrollController();
  List<ENetSearchAction> _services = const [];
  int _selected = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final extra = await widget.loadServices?.call() ?? const <ENetSearchAction>[];
      if (mounted) setState(() => _services = extra);
    } catch (_) {
      // Navigation stays available if the API catalog is offline.
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _scroll.dispose();
    super.dispose();
  }

  List<ENetSearchAction> get _results {
    final needle = _query.text.trim().toLowerCase();
    final actions = [...widget.actions, ..._services];
    if (needle.isEmpty) return actions;
    return actions.where((action) =>
      action.title.toLowerCase().contains(needle) ||
      action.subtitle.toLowerCase().contains(needle) ||
      action.keywords.toLowerCase().contains(needle)).toList();
  }

  void _move(int delta) {
    final count = _results.length;
    if (count == 0) return;
    setState(() => _selected = (_selected + delta + count) % count);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      final start = _selected * 58.0;
      final end = start + 58.0;
      if (start < position.pixels) {
        _scroll.jumpTo(start.clamp(position.minScrollExtent, position.maxScrollExtent));
      } else if (end > position.pixels + position.viewportDimension) {
        _scroll.jumpTo((end - position.viewportDimension)
          .clamp(position.minScrollExtent, position.maxScrollExtent));
      }
    });
  }

  void _run(ENetSearchAction action) {
    Navigator.of(context).pop();
    action.onSelected();
  }

  void _submit() {
    final results = _results;
    if (results.isNotEmpty) _run(results[math.min(_selected, results.length - 1)]);
  }

  @override
  Widget build(BuildContext context) {
    final results = _results;
    return Material(
      type: MaterialType.transparency,
      child: SafeArea(
        child: Align(
          alignment: const Alignment(0, -.52),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 580),
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.arrowDown): () => _move(1),
                  const SingleActivator(LogicalKeyboardKey.arrowUp): () => _move(-1),
                  const SingleActivator(LogicalKeyboardKey.escape):
                    () => Navigator.of(context).pop(),
                },
                child: Glass(
                  radius: 26,
                  blur: 30,
                  strength: 1.3,
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 18),
                      child: Row(children: [
                        const Icon(Icons.search_rounded, color: ENetColors.cyan),
                        const SizedBox(width: 12),
                        Expanded(child: TextField(
                          key: const ValueKey('enet-search-input'),
                          controller: _query,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          style: const TextStyle(color: ENetColors.text, fontSize: 16),
                          onChanged: (_) => setState(() => _selected = 0),
                          onSubmitted: (_) => _submit(),
                          decoration: const InputDecoration(
                            hintText: 'Найти раздел или сервис',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(vertical: 18),
                          ),
                        )),
                        IconButton(
                          tooltip: 'Закрыть поиск',
                          icon: const Icon(Icons.close_rounded,
                            color: ENetColors.muted, size: 20),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ]),
                    ),
                    const Divider(height: 1),
                    if (results.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32),
                        child: Text('Ничего не найдено',
                          style: TextStyle(color: ENetColors.muted, fontSize: 14)),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 348),
                        child: ListView.builder(
                          controller: _scroll,
                          itemExtent: 58,
                          shrinkWrap: true,
                          padding: const EdgeInsets.all(8),
                          itemCount: results.length,
                          itemBuilder: (context, i) {
                            final item = results[i];
                            return Material(
                              color: i == _selected
                                ? ENetColors.mint.withValues(alpha: .13)
                                : Colors.transparent,
                              borderRadius: BorderRadius.circular(13),
                              child: ListTile(
                                dense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                                leading: Icon(item.icon, color: ENetColors.cyan),
                                title: Text(item.title, style: const TextStyle(
                                  color: ENetColors.text, fontWeight: FontWeight.w600)),
                                subtitle: item.subtitle.isEmpty ? null :
                                  Text(item.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: ENetColors.muted, fontSize: 11)),
                                onTap: () => _run(item),
                              ),
                            );
                          },
                        ),
                      ),
                    const Padding(
                      padding: EdgeInsets.all(10),
                      child: Text('↑ ↓ выбор  •  Enter открыть  •  Esc закрыть',
                        style: TextStyle(color: ENetColors.faint, fontSize: 11)),
                    ),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
