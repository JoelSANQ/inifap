// lib/widgets/shimmer.dart
//
// Primitivas de "esqueleto" reutilizables (mismo patrón que ya probó
// report.dart): un barrido de brillo sobre bloques del tamaño del
// contenido real, para que no haya salto cuando llegan los datos.
import 'package:flutter/material.dart';

const Color kShimmerBase = Color(0xFFE9E3E5);
const Color kShimmerHighlight = Color(0xFFF7F3F4);

/// Envuelve [child] con un barrido de brillo animado (izquierda→derecha).
/// Respeta "reducir movimiento" del sistema (no anima si está activado).
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!MediaQuery.of(context).disableAnimations && !_started) {
      _started = true;
      _c.repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: const [kShimmerBase, kShimmerHighlight, kShimmerBase],
            stops: [
              (t - 0.3).clamp(0.0, 1.0),
              t.clamp(0.0, 1.0),
              (t + 0.3).clamp(0.0, 1.0),
            ],
          ).createShader(rect),
          child: widget.child,
        );
      },
    );
  }
}

/// Bloque placeholder rectangular con esquinas redondeadas.
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 6,
  });

  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: kShimmerBase,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Cross-fade + deslizamiento entre estados (skeleton, contenido, error...).
/// Mismo patrón que report.dart, reutilizable en cualquier pantalla.
class ContentSwitcher extends StatelessWidget {
  const ContentSwitcher({super.key, required this.child, this.reduceMotion = false});

  final Widget child;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Duration(milliseconds: reduceMotion ? 0 : 280),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [
          ...previous,
          if (current != null) current,
        ],
      ),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: child,
    );
  }
}
