import 'package:flutter/material.dart';
import '../theme/enet_theme.dart';
import 'pressable.dart';

/// Основная кнопка: градиент, свечение при наведении, плавный индикатор загрузки.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.loading = false,
    this.icon,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool loading;
  final IconData? icon;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    final dimmed = onPressed == null && !loading;
    return Pressable(
      onTap: enabled ? onPressed : null,
      pressedScale: .975,
      builder: (context, hovered) => AnimatedOpacity(
        duration: ENetMotion.quick,
        opacity: dimmed ? .5 : 1,
        child: AnimatedContainer(
          duration: ENetMotion.quick,
          curve: Curves.easeOutCubic,
          width: expand ? double.infinity : null,
          height: 54,
          padding: const EdgeInsets.symmetric(horizontal: 26),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(17),
            gradient: ENetColors.accent,
            boxShadow: [
              BoxShadow(
                color: ENetColors.mint.withValues(alpha: hovered ? .34 : .22),
                blurRadius: hovered ? 36 : 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 240),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: Tween<double>(begin: .85, end: 1).animate(animation), child: child),
            ),
            child: loading
                ? const Center(
                    key: ValueKey('loading'),
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4, color: ENetColors.onAccent),
                    ),
                  )
                : Row(
                    key: const ValueKey('label'),
                    mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(child: AnimatedSwitcher(
                        duration: ENetMotion.quick,
                        child: Text(
                          label,
                          key: ValueKey(label),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: ENetColors.onAccent,
                            fontSize: 16,
                            height: 1.15,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -.2,
                          ),
                        ),
                      )),
                      if (icon != null) ...[
                        const SizedBox(width: 8),
                        AnimatedSlide(
                          duration: ENetMotion.quick,
                          offset: Offset(hovered ? .15 : 0, 0),
                          child: Icon(icon, size: 20, color: ENetColors.onAccent),
                        ),
                      ],
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// Вторичная «стеклянная» кнопка. [destructive] — для выхода/удаления.
class SecondaryButton extends StatelessWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.destructive = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final color = destructive ? ENetColors.danger : ENetColors.text;
    return Pressable(
      onTap: onPressed,
      builder: (context, hovered) => AnimatedOpacity(
        duration: ENetMotion.quick,
        opacity: onPressed == null ? .5 : 1,
        child: AnimatedContainer(
          duration: ENetMotion.quick,
          height: 52,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: color.withValues(alpha: hovered ? .14 : .07),
            border: Border.all(color: color.withValues(alpha: hovered ? .4 : .2)),
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            if (icon != null) ...[Icon(icon, size: 20, color: color), const SizedBox(width: 9)],
            Flexible(child: Text(
              label, maxLines: 2, overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 15.5,
                height: 1.15, fontWeight: FontWeight.w600),
            )),
          ]),
        ),
      ),
    );
  }
}
