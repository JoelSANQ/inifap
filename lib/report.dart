import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ para kIsWeb
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'bin/generate_offline.dart'; // OfflineDataService
import 'widgets/reveal.dart';

// ================== CONFIGURACIÓN DEL PROXY ==================
const String _kUpstream = 'https://zacatecas.inifap.gob.mx/apiApp2.php';

String _buildProxyUrl({required int r}) {
  final upstream = '$_kUpstream?r=$r';
  if (kIsWeb) {
    return 'http://localhost:8080/$upstream';
  }
  return upstream;
}

// ================== TOKENS DE DISEÑO ==================
const Color _kGuinda = Color.fromARGB(255, 97, 18, 50);
const Color _kGuindaDeep = Color(0xFF3D0A20);
const Color _kGold = Color(0xFFE6A700);
const Color _kBg = Color(0xFFF4F1F2);
const Color _kSurface = Colors.white;
const Color _kStroke = Color(0xFFE3DDDF);
const Color _kText = Color(0xFF1A1416);
const Color _kTextMuted = Color(0xFF5C5257); // 7:1 sobre blanco
const double _kRadius = 16;

/// Definición de cada formato de reporte.
class _Mode {
  const _Mode({
    required this.r,
    required this.label,
    required this.icon,
    required this.title,
    required this.hint,
  });

  final int r;
  final String label;
  final IconData icon;
  final String title;
  final String hint;
}

const List<_Mode> _kModes = [
  _Mode(
    r: 1,
    label: 'Tiempo Real',
    icon: Icons.bolt_outlined,
    title: 'Tiempo Real de las Estaciones',
    hint: 'Datos de la hora más reciente reportada por cada estación.',
  ),
  _Mode(
    r: 3,
    label: 'Resumen TR',
    icon: Icons.summarize_outlined,
    title: 'Resumen en Tiempo Real de las Estaciones',
    hint: 'Valores desde las 00:00 hr hasta la hora reportada, por estación.',
  ),
  _Mode(
    r: 4,
    label: 'Avance Mensual',
    icon: Icons.calendar_month_outlined,
    title: 'Reporte Mensual de las Estaciones',
    hint: 'Acumulados y promedios del mes actual para cada estación.',
  ),
];

class WeatherDashboard extends StatefulWidget {
  const WeatherDashboard({super.key});

  @override
  State<WeatherDashboard> createState() => _WeatherDashboardState();
}

class _WeatherDashboardState extends State<WeatherDashboard>
    with SingleTickerProviderStateMixin, RevealController {
  // Controlador de la fila de formatos (scroll horizontal + barra visible).
  final ScrollController _modeScrollController = ScrollController();

  String?
      _currentMode; // '1' = Tiempo Real, '3' = Resumen TR, '4' = Avance Mensual
  String? _pendingMode; // modo con petición en vuelo (spinner del chip)
  bool _loading = false; // true = no hay nada que mostrar todavía → skeleton
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  /// Id de la última petición: descarta respuestas de toques anteriores.
  int _reqId = 0;

  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;

  @override
  void initState() {
    super.initState();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((results) {
      final hasConn = !results.contains(ConnectivityResult.none);
      if (_isOffline && hasConn && _currentMode != null) {
        // Red recuperada, reintentamos el último reporte solicitado
        _fetchForMode(int.parse(_currentMode!));
      }
      setState(() {
        _isOffline = !hasConn;
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    startReveal(); // entrada escalonada (respeta reducir movimiento)
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _modeScrollController.dispose();
    super.dispose();
  }

  // ================== FETCH GENÉRICO POR MODO ==================
  /// Tiempo mínimo que el skeleton permanece en pantalla. Sin esto, una
  /// respuesta de caché (~50 ms) produce un parpadeo peor que no animar.
  static const Duration _kMinSkeleton = Duration(milliseconds: 450);

  Future<void> _holdSkeleton(DateTime startedAt, bool showsSkeleton) async {
    if (!showsSkeleton) return;
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed < _kMinSkeleton) {
      await Future.delayed(_kMinSkeleton - elapsed);
    }
  }

  Future<void> _fetchForMode(int r) async {
    final id = ++_reqId;
    final switching = _currentMode != '$r';
    final startedAt = DateTime.now();
    final showsSkeleton = switching || _rows.isEmpty;

    setState(() {
      _currentMode = '$r';
      _pendingMode = '$r';
      _error = null;
      // Al cambiar de formato las columnas cambian: soltamos la tabla anterior
      // y mostramos skeleton en vez de datos que ya no corresponden.
      if (switching) _rows = [];
      if (_rows.isEmpty) _loading = true;
    });

    // ─────────────────────────────────────────
    // 1️⃣ OFFLINE FIRST: mostrar datos guardados al instante
    // ─────────────────────────────────────────
    try {
      final root = await OfflineDataService.instance.loadOfflineRoot();
      if (!mounted || id != _reqId) return; // respuesta obsoleta
      if (root != null && root.containsKey('reports')) {
        final reports = root['reports'];
        final modeKey = 'r$r';
        final offlineData = reports[modeKey];

        if (offlineData != null) {
          final rows = _parseReportData(offlineData);
          if (rows.isNotEmpty) {
            await _holdSkeleton(startedAt, showsSkeleton);
            if (!mounted || id != _reqId) return;
            setState(() {
              _rows = rows;
              _loading = false;
              _error = null;
            });
          }
        }
      }
    } catch (_) {
      // Si falla offline, seguimos al online
    }

    // ─────────────────────────────────────────
    // 2️⃣ ONLINE: refrescar en background
    // ─────────────────────────────────────────
    try {
      final url = _buildProxyUrl(r: r);
      final res = await OfflineDataService.sharedClient
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (!mounted || id != _reqId) return;

      if (res.statusCode != 200) {
        throw Exception('Error HTTP ${res.statusCode}');
      }

      final data = jsonDecode(res.body);
      final rows = _parseReportData(data);

      // ✅ Guardar en offline
      await OfflineDataService.instance.saveReportData(r, res.body);
      if (!mounted || id != _reqId) return;

      setState(() {
        _rows = rows;
        if (_rows.isEmpty) {
          _error = 'Sin datos disponibles para este reporte.';
        } else {
          _error = null;
        }
      });
    } catch (e) {
      if (!mounted || id != _reqId) return;
      // Solo mostramos error si no hay datos offline
      if (_rows.isEmpty) {
        setState(() {
          _error = 'Error al cargar datos: $e';
        });
      } else {
        // Hay datos offline, solo avisamos con snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Sin conexión. Mostrando datos guardados.')),
        );
      }
    } finally {
      await _holdSkeleton(startedAt, showsSkeleton && _loading);
      if (mounted && id == _reqId) {
        setState(() {
          _loading = false;
          _pendingMode = null;
        });
      }
    }
  }

  /// Parsea la respuesta del reporte (online u offline) a lista de mapas.
  List<Map<String, dynamic>> _parseReportData(dynamic data) {
    List<Map<String, dynamic>> rows = [];
    if (data is List && data.isNotEmpty) {
      final first = data.first;
      if (first is Map &&
          (first.containsKey('Datos') || first.containsKey('datos'))) {
        final root = Map<String, dynamic>.from(first);
        final nested = root['Datos'] ?? root['datos'];
        if (nested is List) {
          for (final item in nested) {
            if (item is Map) {
              rows.add(Map<String, dynamic>.from(item));
            }
          }
        }
      } else {
        for (final item in data) {
          if (item is Map) {
            rows.add(Map<String, dynamic>.from(item));
          }
        }
      }
    }
    return rows;
  }

  // ================== TEXTOS POR MODO ==================
  _Mode? get _activeMode {
    if (_currentMode == null) return null;
    final r = int.tryParse(_currentMode!);
    for (final m in _kModes) {
      if (m.r == r) return m;
    }
    return null;
  }

  Future<void> _refresh() async {
    final mode = _activeMode;
    if (mode == null) return;
    await _fetchForMode(mode.r);
  }

  /// Contenido según estado. La `key` decide cuándo hay transición.
  Widget _buildContent(_Mode? mode, bool isMobile) {
    if (_loading) {
      return _TableSkeleton(
        key: ValueKey('skeleton-${mode?.r}'),
        isNarrow: isMobile,
      );
    }
    if (_error != null) {
      return _ErrorState(
        key: const ValueKey('error'),
        message: _error!,
        onRetry: mode == null ? null : _refresh,
      );
    }
    if (_rows.isNotEmpty && mode != null) {
      return _ModeTable(
        key: ValueKey('table-${mode.r}-${_rows.length}'),
        title: mode.title,
        rows: _rows,
        isNarrow: isMobile,
      );
    }
    return const _EmptyState(key: ValueKey('empty'));
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final bool isMobile = width < 600;
    final double gutter = isMobile ? 16 : 24;
    final bool reduceMotion = MediaQuery.of(context).disableAnimations;
    final mode = _activeMode;

    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kGuinda,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 2,
        title: const Text(
          'Reportes',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar reporte',
            // Deshabilitado con semántica real cuando no hay reporte activo.
            onPressed: mode == null || _loading ? null : _refresh,
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        child: RefreshIndicator(
          color: _kGuinda,
          onRefresh: _refresh,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final double contentMaxWidth =
                  constraints.maxWidth > 1100 ? 1100 : constraints.maxWidth;

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: contentMaxWidth),
                    child: Padding(
                      // Alineado arriba: sin el hueco vertical del centrado.
                      padding: EdgeInsets.fromLTRB(gutter, 20, gutter, 32),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // El banner entra/sale animado según la conectividad.
                          AnimatedSize(
                            duration:
                                Duration(milliseconds: reduceMotion ? 0 : 240),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            child: _isOffline
                                ? const Column(
                                    children: [
                                      _OfflineBanner(),
                                      SizedBox(height: 16),
                                    ],
                                  )
                                : const SizedBox(width: double.infinity),
                          ),

                          // ===== ENCABEZADO =====
                          Reveal(
                            anim: revealAnim,
                            index: 0,
                            child: const _Header(),
                          ),
                          const SizedBox(height: 24),

                          // ===== SELECTOR DE FORMATO =====
                          Reveal(
                            anim: revealAnim,
                            index: 1,
                            child: Row(
                              children: [
                                Container(width: 22, height: 3, color: _kGold),
                                const SizedBox(width: 8),
                                Semantics(
                                  header: true,
                                  child: const Text(
                                    'FORMATO DE VISUALIZACIÓN',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                      color: _kTextMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 12),
                          // Fila única: scroll horizontal con barra visible para
                          // pantallas donde los 3 formatos no caben.
                          Reveal(
                            anim: revealAnim,
                            index: 2,
                            child: _ModeStrip(
                              controller: _modeScrollController,
                              currentMode: _currentMode,
                              pendingMode: _pendingMode,
                              reduceMotion: reduceMotion,
                              onSelect: _fetchForMode,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // ===== AYUDA CONTEXTUAL =====
                          Reveal(
                            anim: revealAnim,
                            index: 3,
                            child: _ContentSwitcher(
                              reduceMotion: reduceMotion,
                              child: _HintBar(
                                key: ValueKey('hint-${mode?.r ?? 0}'),
                                text: mode?.hint ??
                                    'Selecciona un formato para mostrar los '
                                        'datos de las 38 estaciones.',
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // ===== CONTENIDO (transición suave entre estados) =====
                          Reveal(
                            anim: revealAnim,
                            index: 4,
                            child: _ContentSwitcher(
                              reduceMotion: reduceMotion,
                              child: _buildContent(mode, isMobile),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ================== ENCABEZADO ==================
class _Header extends StatelessWidget {
  const _Header();

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
            color: _kGuinda.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.14),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const ExcludeSemantics(
              child: Icon(Icons.insights_outlined, color: _kGold, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Monitoreo Agroclimático',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.2,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Estado de Zacatecas · 38 estaciones',
                  style: TextStyle(
                    color: Color(0xFFF3E8ED),
                    fontSize: 13.5,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ================== BANNER OFFLINE ==================
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF4E5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE8A33D)),
      ),
      child: Row(
        children: [
          const ExcludeSemantics(
            child: Icon(Icons.wifi_off_rounded,
                color: Color(0xFF8A4B00), size: 18),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Sin conexión · mostrando datos guardados',
              style: TextStyle(
                color: Color(0xFF8A4B00), // ~6.3:1 sobre el fondo ámbar
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ================== FILA DE FORMATOS ==================
class _ModeStrip extends StatefulWidget {
  const _ModeStrip({
    required this.controller,
    required this.currentMode,
    required this.pendingMode,
    required this.reduceMotion,
    required this.onSelect,
  });

  final ScrollController controller;
  final String? currentMode;
  final String? pendingMode;
  final bool reduceMotion;
  final void Function(int r) onSelect;

  @override
  State<_ModeStrip> createState() => _ModeStripState();
}

class _ModeStripState extends State<_ModeStrip> {
  // Una key por chip para poder desplazarlo a la vista al seleccionarlo.
  final List<GlobalKey> _chipKeys =
      List.generate(_kModes.length, (_) => GlobalKey());

  void _select(int i) {
    widget.onSelect(_kModes[i].r);
    final ctx = _chipKeys[i].currentContext;
    if (ctx == null) return;
    // El chip elegido queda visible aunque esté fuera de pantalla.
    Scrollable.ensureVisible(
      ctx,
      alignment: 0.5,
      duration: Duration(milliseconds: widget.reduceMotion ? 0 : 320),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Theme(
      data: Theme.of(context).copyWith(
        scrollbarTheme: ScrollbarThemeData(
          thumbColor: WidgetStateProperty.all(_kGuinda.withOpacity(0.55)),
          trackColor: WidgetStateProperty.all(_kStroke),
          trackBorderColor: WidgetStateProperty.all(Colors.transparent),
          thickness: WidgetStateProperty.all(5),
          radius: const Radius.circular(999),
        ),
      ),
      child: Scrollbar(
        controller: controller,
        thumbVisibility: true,
        trackVisibility: true,
        child: SingleChildScrollView(
          controller: controller,
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          // Espacio para que la barra no toque los chips.
          padding: const EdgeInsets.only(bottom: 14),
          child: Row(
            children: [
              for (int i = 0; i < _kModes.length; i++) ...[
                if (i != 0) const SizedBox(width: 10),
                _ModeChip(
                  key: _chipKeys[i],
                  mode: _kModes[i],
                  active: widget.currentMode == '${_kModes[i].r}',
                  busy: widget.pendingMode == '${_kModes[i].r}',
                  onTap: () => _select(i),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ================== CHIP DE MODO ==================
class _ModeChip extends StatefulWidget {
  const _ModeChip({
    super.key,
    required this.mode,
    required this.active,
    required this.busy,
    required this.onTap,
  });

  final _Mode mode;
  final bool active;
  final bool busy;
  final VoidCallback onTap;

  @override
  State<_ModeChip> createState() => _ModeChipState();
}

class _ModeChipState extends State<_ModeChip> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final mode = widget.mode;
    final active = widget.active;
    final busy = widget.busy;
    // Guinda ↔ blanco en ambos sentidos: ~12.8:1 de contraste.
    final fg = active ? Colors.white : _kGuinda;
    final bg = active ? _kGuinda : _kSurface;

    return Semantics(
      button: true,
      selected: active,
      label: mode.label,
      // El estado de carga se anuncia; el spinner solo es visual.
      hint: busy ? 'Cargando' : null,
      // Escala de pintado: no reflowa el contenido de al lado.
      child: AnimatedScale(
        scale: _pressed ? 0.96 : 1,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: widget.onTap,
            onHighlightChanged: (v) => setState(() => _pressed = v),
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              // Relleno/borde/texto interpolan: sin salto brusco al seleccionar.
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              constraints:
                  const BoxConstraints(minHeight: 48), // táctil Android
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: active ? _kGuinda : _kStroke,
                  width: 1.4,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mismo tamaño en ambos estados → el chip no cambia de ancho.
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: busy
                          ? CircularProgressIndicator(
                              key: const ValueKey('busy'),
                              strokeWidth: 2,
                              color: fg,
                            )
                          : ExcludeSemantics(
                              key: const ValueKey('icon'),
                              child: Icon(mode.icon, size: 18, color: fg),
                            ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ExcludeSemantics(
                    child: AnimatedDefaultTextStyle(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      style: TextStyle(
                        color: fg,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      child: Text(mode.label),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================== AYUDA CONTEXTUAL ==================
class _HintBar extends StatelessWidget {
  const _HintBar({super.key, required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const ExcludeSemantics(
          child: Icon(Icons.info_outline, size: 16, color: _kTextMuted),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: _kTextMuted,
              fontSize: 13,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}

// ================== ESTADOS ==================
class _EmptyState extends StatelessWidget {
  const _EmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      icon: Icons.table_chart_outlined,
      iconColor: _kGuinda,
      title: 'Sin reporte seleccionado',
      body: 'Toca uno de los formatos de arriba para consultar los datos '
          'de las estaciones.',
    );
  }
}

/// Esqueleto de la tabla con barrido shimmer.
/// Ocupa el mismo lugar que la tabla real → no hay salto al llegar los datos.
class _TableSkeleton extends StatefulWidget {
  const _TableSkeleton({super.key, required this.isNarrow});
  final bool isNarrow;

  @override
  State<_TableSkeleton> createState() => _TableSkeletonState();
}

class _TableSkeletonState extends State<_TableSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Sin barrido si el sistema pide reducir movimiento.
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
    const base = Color(0xFFE9E3E5);
    const highlight = Color(0xFFF7F3F4);
    final rowCount = widget.isNarrow ? 6 : 8;

    return Semantics(
      liveRegion: true,
      label: 'Cargando reporte',
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) {
          final t = _c.value;
          return ShaderMask(
            blendMode: BlendMode.srcATop,
            shaderCallback: (rect) => LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: const [base, highlight, base],
              stops: [
                (t - 0.3).clamp(0.0, 1.0),
                t.clamp(0.0, 1.0),
                (t + 0.3).clamp(0.0, 1.0),
              ],
            ).createShader(rect),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonBox(width: 220, height: 18),
                const SizedBox(height: 10),
                const _SkeletonBox(width: 160, height: 12),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: _kSurface,
                    borderRadius: BorderRadius.circular(_kRadius),
                    border: Border.all(color: _kStroke),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      // Encabezado
                      Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        color: base,
                        child: const Row(
                          children: [
                            _SkeletonBox(width: 40, height: 10),
                            SizedBox(width: 20),
                            _SkeletonBox(width: 90, height: 10),
                            SizedBox(width: 20),
                            _SkeletonBox(width: 70, height: 10),
                          ],
                        ),
                      ),
                      for (int i = 0; i < rowCount; i++)
                        Container(
                          height: 48,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color:
                                i.isEven ? _kSurface : const Color(0xFFFAF7F8),
                            border: const Border(
                              top: BorderSide(color: _kStroke, width: 0.5),
                            ),
                          ),
                          child: const Row(
                            children: [
                              _SkeletonBox(width: 44, height: 12),
                              SizedBox(width: 20),
                              _SkeletonBox(width: 120, height: 12),
                              SizedBox(width: 20),
                              _SkeletonBox(width: 60, height: 12),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({required this.width, required this.height});
  final double width;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE9E3E5),
        borderRadius: BorderRadius.circular(6),
      ),
    );
  }
}

/// Cross-fade + deslizamiento entre skeleton, tabla, error y vacío.
class _ContentSwitcher extends StatelessWidget {
  const _ContentSwitcher({required this.child, required this.reduceMotion});

  final Widget child;
  final bool reduceMotion;

  @override
  Widget build(BuildContext context) {
    return AnimatedSize(
      duration: Duration(milliseconds: reduceMotion ? 0 : 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: Duration(milliseconds: reduceMotion ? 0 : 280),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        // Alineado arriba: evita que el saliente empuje al entrante.
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
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({super.key, required this.message, this.onRetry});
  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _StateCard(
      icon: Icons.error_outline,
      iconColor: const Color(0xFFB3261E),
      title: 'No se pudo cargar',
      body: message,
      action: onRetry == null
          ? null
          : FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Reintentar'),
              style: FilledButton.styleFrom(
                backgroundColor: _kGuinda,
                foregroundColor: Colors.white,
                minimumSize: const Size(0, 48),
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
            ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: _kSurface,
        borderRadius: BorderRadius.circular(_kRadius),
        border: Border.all(color: _kStroke),
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: iconColor.withOpacity(0.10),
              shape: BoxShape.circle,
            ),
            child:
                ExcludeSemantics(child: Icon(icon, size: 26, color: iconColor)),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: _kText,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            body,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13.5,
              height: 1.5,
              color: _kTextMuted,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 20),
            action!,
          ],
        ],
      ),
    );
  }
}

// ================== TABLA GENÉRICA RESPONSIVE ==================
class _ModeTable extends StatelessWidget {
  const _ModeTable({
    super.key,
    required this.title,
    required this.rows,
    required this.isNarrow,
  });

  final String title;
  final List<Map<String, dynamic>> rows;
  final bool isNarrow;

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final columns = rows.first.keys.toList();

    final columnSpacing = isNarrow ? 20.0 : 32.0;
    final horizontalMargin = isNarrow ? 12.0 : 16.0;
    final double maxCellWidth = isNarrow ? 140 : 220;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Semantics(
                header: true,
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                    color: _kText,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFF3E8ED),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${rows.length} registros',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _kGuinda,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Row(
          children: [
            ExcludeSemantics(
              child:
                  Icon(Icons.swipe_left_outlined, size: 14, color: _kTextMuted),
            ),
            SizedBox(width: 6),
            Text(
              'Desliza la tabla para ver todas las columnas',
              style: TextStyle(fontSize: 12, color: _kTextMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: _kSurface,
            borderRadius: BorderRadius.circular(_kRadius),
            border: Border.all(color: _kStroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(_kGuinda),
              headingTextStyle: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
              dividerThickness: 0.5,
              columnSpacing: columnSpacing,
              horizontalMargin: horizontalMargin,
              dataRowMinHeight: 44,
              dataRowMaxHeight: 56,
              columns: columns.map((c) => DataColumn(label: Text(c))).toList(),
              rows: [
                for (int i = 0; i < rows.length; i++)
                  DataRow(
                    // Zebra: facilita seguir la fila en tablas anchas.
                    color: WidgetStateProperty.all(
                      i.isEven ? _kSurface : const Color(0xFFFAF7F8),
                    ),
                    cells: columns
                        .map(
                          (c) => DataCell(
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: 40,
                                maxWidth: maxCellWidth,
                              ),
                              child: Text(
                                (rows[i][c] ?? '—').toString(),
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: _kText,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
