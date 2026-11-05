import 'package:flutter/material.dart';
import '../theme/enet_theme.dart';
import 'pressable.dart';

/// Сегментированный переключатель со скользящей «таблеткой».
class GlassSegmented extends StatelessWidget {
  const GlassSegmented({super.key, required this.labels, required this.index, required this.onChanged});
  final List<String> labels;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final n = labels.length;
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .06),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: .08)),
      ),
      child: Stack(children: [
        AnimatedAlign(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutQuint,
          alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
          child: FractionallySizedBox(
            widthFactor: 1 / n,
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.white.withValues(alpha: .20), Colors.white.withValues(alpha: .10)],
                ),
                border: Border.all(color: Colors.white.withValues(alpha: .16)),
                boxShadow: const [BoxShadow(color: Color(0x40000000), blurRadius: 12, offset: Offset(0, 4))],
              ),
            ),
          ),
        ),
        Row(children: [
          for (var i = 0; i < n; i++)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(i),
                child: Center(
                  child: AnimatedDefaultTextStyle(
                    duration: ENetMotion.medium,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: i == index ? ENetColors.text : ENetColors.muted,
                    ),
                    child: Text(labels[i]),
                  ),
                ),
              ),
            ),
        ]),
      ]),
    );
  }
}

/// Переключатель в стиле iOS, но в фирменных цветах.
class GlassToggle extends StatelessWidget {
  const GlassToggle({super.key, required this.value, required this.onChanged});
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: Pressable(
        onTap: () => onChanged(!value),
        pressedScale: .94,
        builder: (context, hovered) => AnimatedContainer(
          duration: const Duration(milliseconds: 320),
          curve: Curves.easeOutCubic,
          width: 54,
          height: 32,
          padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: value
                ? ENetColors.accent
                : LinearGradient(colors: [Colors.white.withValues(alpha: .16), Colors.white.withValues(alpha: .16)]),
            boxShadow: [
              BoxShadow(
                color: ENetColors.mint.withValues(alpha: value ? .36 : 0),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 380),
            curve: Curves.easeOutBack,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Container(
              width: 26,
              height: 26,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [BoxShadow(color: Color(0x4D000000), blurRadius: 6, offset: Offset(0, 2))],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
