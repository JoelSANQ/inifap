// lib/About_Me.dart
// ====== ACERCA DE NOSOTROS — hero guinda + tarjetas de equipo ======

import 'package:flutter/material.dart';

/// ====== TOKENS ======
const Color _kGuinda = Color.fromARGB(255, 102, 6, 6);
const Color _kGuindaDeep = Color(0xFF3D0404);
const Color _kGold = Color(0xFFE6A700);

const double _kMaxContentWidth = 560;
const double _kRadius = 18;

/// Paleta dependiente del tema (evita hardcodear por widget).
class _Palette {
  const _Palette({
    required this.bg,
    required this.surface,
    required this.stroke,
    required this.text,
    required this.textMuted,
    required this.accentSoft,
  });

  final Color bg;
  final Color surface;
  final Color stroke;
  final Color text;
  final Color textMuted;
  final Color accentSoft;

  factory _Palette.of(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return dark
        ? const _Palette(
            bg: Color(0xFF141013),
            surface: Color(0xFF1F1A1D),
            stroke: Color(0xFF3A3236),
            text: Color(0xFFF5EFF1),
            textMuted: Color(0xFFC9BFC3), // ~7:1 sobre surface oscura
            accentSoft: Color(0xFF2C1F23),
          )
        : const _Palette(
            bg: Color(0xFFF7F4F5),
            surface: Colors.white,
            stroke: Color(0xFFE5E0E2),
            text: Color(0xFF1A1416),
            textMuted: Color(0xFF5C5257), // ~7:1 sobre blanco
            accentSoft: Color(0xFFF3E8ED),
          );
  }
}

class _Member {
  const _Member(this.name, this.initials);
  final String name;
  final String initials;
}

const List<_Member> _kTeam = [
  _Member('Joel del Jesús Sánchez Quintal', 'JS'),
  _Member('Manuel Alejandro Cano Lara', 'MC'),
  _Member('Gerardo Góngora Vargas', 'GG'),
];

class AboutUsPage extends StatefulWidget {
  const AboutUsPage({super.key});

  @override
  State<AboutUsPage> createState() => _AboutUsPageState();
}

class _AboutUsPageState extends State<AboutUsPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Respeta "reducir movimiento" del sistema.
    if (MediaQuery.of(context).disableAnimations) {
      _anim.value = 1;
    } else if (!_started) {
      _started = true;
      _anim.forward();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    final gutter = MediaQuery.of(context).size.width >= 600 ? 32.0 : 20.0;

    return Scaffold(
      backgroundColor: p.bg,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _HeroBar(anim: _anim),
          SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _kMaxContentWidth),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(gutter, 24, gutter, 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Reveal(
                        anim: _anim,
                        index: 0,
                        child: _Intro(p: p),
                      ),
                      const SizedBox(height: 20),
                      _Reveal(
                        anim: _anim,
                        index: 1,
                        child: const _FactChips(),
                      ),
                      const SizedBox(height: 32),
                      _Reveal(
                        anim: _anim,
                        index: 2,
                        child: _SectionLabel(text: 'El equipo', p: p),
                      ),
                      const SizedBox(height: 12),
                      for (int i = 0; i < _kTeam.length; i++) ...[
                        _Reveal(
                          anim: _anim,
                          index: 3 + i,
                          child: _MemberCard(member: _kTeam[i], p: p),
                        ),
                        if (i != _kTeam.length - 1) const SizedBox(height: 10),
                      ],
                      const SizedBox(height: 32),
                      _Reveal(
                        anim: _anim,
                        index: 6,
                        child: const _ProjectCard(),
                      ),
                      const SizedBox(height: 28),
                      _Reveal(
                        anim: _anim,
                        index: 7,
                        child: _Footer(p: p),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Insets para que nada quede bajo la barra de gestos.
          SliverToBoxAdapter(
            child: SizedBox(
              height: 24 + MediaQuery.of(context).padding.bottom,
            ),
          ),
        ],
      ),
    );
  }
}

/// ====== HERO ======
class _HeroBar extends StatelessWidget {
  const _HeroBar({required this.anim});
  final Animation<double> anim;

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 248,
      backgroundColor: _kGuinda,
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 2,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Regresar',
        onPressed: () => Navigator.of(context).maybePop(),
      ),
      title: const Text(
        'Acerca de nosotros',
        style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_kGuinda, _kGuindaDeep],
            ),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Acento cálido decorativo.
              Positioned(
                right: -60,
                top: -40,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _kGold.withOpacity(0.10),
                  ),
                ),
              ),
              SafeArea(
                bottom: false,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: FadeTransition(
                      opacity: anim,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 22,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.22),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Image.asset(
                          'lib/images/logo.jpeg',
                          height: 72,
                          fit: BoxFit.contain,
                          semanticLabel: 'Logotipo Tecnológico de Software',
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ====== INTRO ======
class _Intro extends StatelessWidget {
  const _Intro({required this.p});
  final _Palette p;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(width: 22, height: 3, color: _kGold),
            const SizedBox(width: 8),
            Text(
              'TECNOLÓGICO DE SOFTWARE',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.4,
                color: p.textMuted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Acerca de nosotros',
          style: TextStyle(
            fontSize: 28,
            height: 1.15,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
            color: p.text,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Somos un equipo de estudiantes que diseñó y desarrolló esta '
          'aplicación de monitoreo climático para el INIFAP.',
          style: TextStyle(
            fontSize: 15.5,
            height: 1.55,
            color: p.textMuted,
          ),
        ),
      ],
    );
  }
}

/// ====== CHIPS DE DATOS ======
class _FactChips extends StatelessWidget {
  const _FactChips();

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: const [
        _Chip(icon: Icons.apartment_outlined, label: ''),
        _Chip(icon: Icons.school_outlined, label: ''),
        _Chip(icon: Icons.schedule_outlined, label: ''),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = _Palette.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fg = dark ? const Color(0xFFEBC7C7) : _kGuinda;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: p.accentSoft,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fg.withOpacity(0.20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decorativo: el texto de al lado ya comunica el dato.
          ExcludeSemantics(child: Icon(icon, size: 16, color: fg)),
          const SizedBox(width: 6),
          Text(
            label,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

/// ====== ETIQUETA DE SECCIÓN ======
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, required this.p});
  final String text;
  final _Palette p;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.2,
          color: p.text,
        ),
      ),
    );
  }
}

/// ====== TARJETA DE INTEGRANTE ======
class _MemberCard extends StatelessWidget {
  const _MemberCard({required this.member, required this.p});
  final _Member member;
  final _Palette p;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 72), // > 48dp táctil
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: p.stroke),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(
              Theme.of(context).brightness == Brightness.dark ? 0.30 : 0.05,
            ),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_kGuinda, _kGuindaDeep],
              ),
            ),
            child: ExcludeSemantics(
              child: Text(
                member.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              member.name,
              style: TextStyle(
                fontSize: 15.5,
                height: 1.3,
                fontWeight: FontWeight.w600,
                color: p.text,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ====== TARJETA DEL PROYECTO ======
class _ProjectCard extends StatelessWidget {
  const _ProjectCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_kRadius + 4),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kGuinda, _kGuindaDeep],
        ),
        boxShadow: [
          BoxShadow(
            color: _kGuinda.withOpacity(0.28),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const ExcludeSemantics(
                  child: Icon(Icons.eco_outlined, size: 20, color: _kGold),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'El proyecto',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text(
            'Creamos esta app como parte de nuestro Plan de Formación Dual, '
            'trabajando para el INIFAP',
            style: TextStyle(
              color: Color(0xFFF3E8ED),
              fontSize: 15,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}

/// ====== PIE ======
class _Footer extends StatelessWidget {
  const _Footer({required this.p});
  final _Palette p;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(color: p.stroke, height: 1),
        const SizedBox(height: 16),
        Text(
          'Tecnológico de Software · ${DateTime.now().year}',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12.5, color: p.textMuted),
        ),
      ],
    );
  }
}

/// ====== ANIMACIÓN DE ENTRADA ESCALONADA ======
class _Reveal extends StatelessWidget {
  const _Reveal({
    required this.anim,
    required this.index,
    required this.child,
  });

  final Animation<double> anim;
  final int index;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final start = (index * 0.07).clamp(0.0, 0.6);
    final curved = CurvedAnimation(
      parent: anim,
      curve: Interval(start, (start + 0.4).clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: curved,
      builder: (_, c) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, 14 * (1 - curved.value)),
          child: c,
        ),
      ),
      child: child,
    );
  }
}
