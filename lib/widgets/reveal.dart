import 'package:flutter/material.dart';

/// Entrada escalonada: fade + deslizamiento hacia arriba.
///
/// Comparte un solo [AnimationController] entre todos los hijos; cada uno
/// arranca según su [index]. Si el sistema pide reducir movimiento, el
/// controlador debe entregarse ya en 1.0 (ver [RevealController]).
class Reveal extends StatelessWidget {
  const Reveal({
    super.key,
    required this.anim,
    required this.index,
    required this.child,
    this.offsetY = 14,
    this.step = 0.07,
  });

  final Animation<double> anim;
  final int index;
  final Widget child;
  final double offsetY;
  final double step;

  @override
  Widget build(BuildContext context) {
    final start = (index * step).clamp(0.0, 0.6);
    final curved = CurvedAnimation(
      parent: anim,
      curve: Interval(
        start,
        (start + 0.4).clamp(0.0, 1.0),
        curve: Curves.easeOutCubic,
      ),
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (_, c) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, offsetY * (1 - curved.value)),
          child: c,
        ),
      ),
      child: child,
    );
  }
}

/// Mixin para el controlador de entrada de una pantalla.
///
/// Llamar [startReveal] desde `didChangeDependencies`: respeta
/// `MediaQuery.disableAnimations` y sólo arranca una vez.
mixin RevealController<T extends StatefulWidget>
    on State<T>, SingleTickerProviderStateMixin<T> {
  late final AnimationController revealAnim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool _revealStarted = false;

  void startReveal() {
    if (_revealStarted) return;
    _revealStarted = true;
    if (MediaQuery.of(context).disableAnimations) {
      revealAnim.value = 1;
    } else {
      revealAnim.forward();
    }
  }

  @override
  void dispose() {
    revealAnim.dispose();
    super.dispose();
  }
}
