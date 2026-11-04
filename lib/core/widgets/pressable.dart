import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Любой элемент, который «живо» реагирует: уменьшается при нажатии,
/// сообщает о наведении мыши (ПК) и даёт лёгкий тактильный отклик (iPhone).
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.builder,
    this.onTap,
    this.pressedScale = .97,
    this.haptic = true,
  });

  final Widget Function(BuildContext context, bool hovered) builder;
  final VoidCallback? onTap;
  final double pressedScale;
  final bool haptic;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hovered = false;
  bool _pressed = false;

  bool get _enabled => widget.onTap != null;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: _enabled,
      enabled: _enabled,
      child: MouseRegion(
        cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
          onTap: _enabled
              ? () {
                  if (widget.haptic) HapticFeedback.selectionClick();
                  widget.onTap!();
                }
              : null,
          child: AnimatedScale(
            scale: _pressed ? widget.pressedScale : 1,
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOutCubic,
            child: widget.builder(context, _hovered && _enabled),
          ),
        ),
      ),
    );
  }
}
