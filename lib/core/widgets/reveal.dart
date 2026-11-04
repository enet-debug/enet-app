import 'dart:async';
import 'package:flutter/material.dart';

/// Плавное появление: проявление + подъём снизу. Используйте с разными
/// [delay], чтобы элементы появлялись каскадом, как в системных приложениях.
class Reveal extends StatefulWidget {
  const Reveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.offset = 22,
  });

  final Widget child;
  final Duration delay;
  final double offset;

  @override
  State<Reveal> createState() => _RevealState();
}

class _RevealState extends State<Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Curves.easeOutQuart);
  Timer? _timer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) => Opacity(
        opacity: _curve.value.clamp(0.0, 1.0),
        child: Transform.translate(offset: Offset(0, (1 - _curve.value) * widget.offset), child: child),
      ),
    );
  }
}

/// Лёгкое «парение» элемента вверх-вниз (для иконок пустых состояний).
class Floating extends StatefulWidget {
  const Floating({super.key, required this.child, this.amplitude = 6});
  final Widget child;
  final double amplitude;

  @override
  State<Floating> createState() => _FloatingState();
}

class _FloatingState extends State<Floating> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 3200));
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOutSine);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) =>
          Transform.translate(offset: Offset(0, (_curve.value * 2 - 1) * widget.amplitude), child: child),
    );
  }
}
