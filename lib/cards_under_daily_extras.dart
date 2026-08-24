// lib/daily_extras.dart
// WIDGET DE DATOS EXTRA DIARIOS (Viento, Radiación, Humedad, Lluvia)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb
import 'data/Stations.dart';
import 'bin/generate_offline.dart';

const String _kUpstream = 'https://zacatecas.inifap.gob.mx/apiApp2.php';
const String _kProxyBase = 'http://localhost:8080';

// ================== TOKENS DE DISEÑO (marca INIFAP) ==================
const Color _kCardTop = Color.fromARGB(255, 97, 18, 50);
const Color _kCardBottom = Color(0xFF3D0A20);
const Color _kGold = Color(0xFFE6A700);

/// Construye la URL con r, fecha y estación
/// ✅ Web  -> usa PROXY (evita CORS)
/// ✅ NoWeb -> usa UPSTREAM directo (Android/iOS/Desktop)
String _buildDailyUrl({
  required int r,
  required int idEst,
  required DateTime day,
}) {
  final dd = day.day.toString().padLeft(2, '0');
  final mm = day.month.toString().padLeft(2, '0');
  final yyyy = day.year.toString();
  final upstream =
      '$_kUpstream?r=$r&day=$dd&month=$mm&year=$yyyy&id_est_given=$idEst';

  if (kIsWeb) {
    return '$_kProxyBase/$upstream';
  }
  return upstream;
}

/// Desglose de estadísticas (Máximo/Mínimo/Promedio, etc.) de una tarjeta.
class _StatBreakdown extends StatelessWidget {
  final List<MapEntry<String, String>>? entries;
  const _StatBreakdown(this.entries);

  @override
  Widget build(BuildContext context) {
    final items = entries;
    if (items == null || items.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (int i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(color: Colors.white.withOpacity(0.12), height: 1, thickness: 0.6),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 7),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    items[i].key,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.72),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    items[i].value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mini tarjeta para un valor actual + desglose de estadísticas.
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? time;
  final List<MapEntry<String, String>>? resumen;
  final List<double>? series;
  final Widget? customVisual;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    this.time,
    this.resumen,
    this.series,
    this.customVisual,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_kCardTop, _kCardBottom],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _kCardTop.withOpacity(0.28),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 30,
                height: 30,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kGold.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: _kGold, size: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: _kGold,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Flexible(
                child: Text(
                  value,
                  softWrap: true,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
                ),
              ),
              if (time != null) ...[
                const SizedBox(width: 6),
                Text(
                  time!,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.65),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          if (customVisual != null) ...[
            const SizedBox(height: 10),
            SizedBox(height: 44, child: customVisual),
          ] else if (series != null && series!.length > 1) ...[
            const SizedBox(height: 10),
            SizedBox(height: 44, child: _MiniChart(values: series!)),
          ],
          _StatBreakdown(resumen),
        ],
      ),
    );
  }
}

/// Mini-gráfica de tendencia del día (línea con relleno).
class _MiniChart extends StatelessWidget {
  final List<double> values;
  const _MiniChart({required this.values});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.infinite,
      painter: _MiniChartPainter(values: values),
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  final List<double> values;
  _MiniChartPainter({required this.values});

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final maxV = values.reduce((a, b) => a > b ? a : b);
    final minV = values.reduce((a, b) => a < b ? a : b);
    final range = (maxV - minV) == 0 ? 1.0 : (maxV - minV);
    final stepX = size.width / (values.length - 1);

    double yOf(double v) => size.height - ((v - minV) / range) * size.height;

    final linePath = Path();
    for (int i = 0; i < values.length; i++) {
      final x = stepX * i;
      final y = yOf(values[i]);
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    final fillPath = Path.from(linePath)
      ..lineTo(stepX * (values.length - 1), size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_kGold.withOpacity(0.30), _kGold.withOpacity(0.0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    canvas.drawPath(
      linePath,
      Paint()
        ..color = _kGold
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter old) => old.values != values;
}

/// Animación decorativa de la tarjeta de precipitación: lluvia cayendo si hay
/// precipitación ahora mismo, o una nube pasando si no la hay. Usa la misma
/// condición (> 0.0 mm) que ya dispara la notificación de lluvia.
class _PrecipAnimation extends StatefulWidget {
  final bool isRaining;
  const _PrecipAnimation({required this.isRaining});

  @override
  State<_PrecipAnimation> createState() => _PrecipAnimationState();
}

class _PrecipAnimationState extends State<_PrecipAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: widget.isRaining ? 1100 : 8000),
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      if (MediaQuery.of(context).disableAnimations) {
        _ctrl.value = 0;
      } else {
        _ctrl.repeat();
      }
    }
  }

  @override
  void didUpdateWidget(covariant _PrecipAnimation old) {
    super.didUpdateWidget(old);
    if (old.isRaining != widget.isRaining) {
      _ctrl.duration = Duration(milliseconds: widget.isRaining ? 1100 : 8000);
      if (!MediaQuery.of(context).disableAnimations) {
        _ctrl.repeat();
      }
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => widget.isRaining
          ? _RainyCloud(progress: _ctrl.value)
          : _DriftingCloud(progress: _ctrl.value),
    );
  }
}

/// Nube de fondo + nube de frente, superpuestas para dar sensación de
/// profundidad, desplazándose lentamente de un lado a otro.
class _DriftingCloud extends StatelessWidget {
  final double progress;
  const _DriftingCloud({required this.progress});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final x = -34 + progress * (w + 68);
        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: x - 20,
              top: constraints.maxHeight * 0.42,
              child: Icon(Icons.cloud_rounded, size: 30, color: Colors.white.withOpacity(0.18)),
            ),
            Positioned(
              left: x + 2,
              top: constraints.maxHeight * 0.24,
              child: Icon(Icons.cloud_rounded, size: 25, color: Colors.white.withOpacity(0.28)),
            ),
            Positioned(
              left: x + 20,
              top: constraints.maxHeight * 0.42,
              child: Icon(Icons.cloud_rounded, size: 20, color: Colors.white.withOpacity(0.40)),
            ),
          ],
        );
      },
    );
  }
}

/// Nube fija con gotas de lluvia cayendo debajo, en capas para dar profundidad.
class _RainyCloud extends StatelessWidget {
  final double progress;
  const _RainyCloud({required this.progress});

  // (posición horizontal 0-1, desfase de caída 0-1) por gota.
  static const _drops = [
    (0.14, 0.00), (0.30, 0.40), (0.46, 0.75), (0.62, 0.20), (0.78, 0.55),
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        final cloudCenterX = w * 0.5;
        final dropTop = h * 0.5;

        return Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned(
              left: cloudCenterX - 24,
              top: 0,
              child: Icon(Icons.cloud_rounded, size: 28, color: Colors.white.withOpacity(0.85)),
            ),
            Positioned(
              left: cloudCenterX + 2,
              top: -2,
              child: Icon(Icons.cloud_rounded, size: 20, color: Colors.white.withOpacity(0.55)),
            ),
            for (final d in _drops) _drop(w, h, dropTop, d.$1, d.$2),
          ],
        );
      },
    );
  }

  Widget _drop(double w, double h, double top, double xf, double phase) {
    final t = (progress + phase) % 1.0;
    final y = top + t * (h - top);
    final opacity = (1 - t).clamp(0.25, 1.0);
    return Positioned(
      left: xf * w,
      top: y,
      child: Opacity(
        opacity: opacity,
        child: Container(
          width: 2.2,
          height: 8,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.75),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }
}

class DailyExtrasStrip extends StatefulWidget {
  final Station? station;
  final DateTime day;
  const DailyExtrasStrip({super.key, required this.station, required this.day});

  @override
  State<DailyExtrasStrip> createState() => _DailyExtrasStripState();
}

class _DailyExtrasStripState extends State<DailyExtrasStrip> {
  String? _wind;
  String? _rad;
  String? _humNow;

  String? _rainTotal;
  String? _rainMaxInt;
  String? _rainNow;
  double? _rainNowMm;
  String? _rainTime;

  List<MapEntry<String, String>>? _windResumen;
  List<MapEntry<String, String>>? _radResumen;
  List<MapEntry<String, String>>? _humResumen;
  List<MapEntry<String, String>>? _rainResumen;

  List<double>? _windSeries;
  List<double>? _radSeries;
  List<double>? _humSeries;

  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant DailyExtrasStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.station?.id != widget.station?.id ||
        oldWidget.day != widget.day) {
      _fetch();
    }
  }

  Future<void> _fetch() async {
    final st = widget.station;
    if (st == null) return;

    _error = null;

    // Para saber si ya teníamos algo pintado
    final hadDataBefore =
        _wind != null || _rad != null || _humNow != null || _rainNow != null;

    // 1️⃣ OFFLINE FIRST: intentar leer de offline_data.json y pintar al instante
    try {
      final root = await OfflineDataService.instance.loadOfflineRoot();
      if (root != null) {
        final extras = root['daily_extras'] as Map<String, dynamic>?;
        final stationMap = extras?[st.id.toString()] as Map<String, dynamic>?;

        if (stationMap != null) {
          final dd = widget.day.day.toString().padLeft(2, '0');
          final mm = widget.day.month.toString().padLeft(2, '0');
          final yyyy = widget.day.year.toString();
          final dayKey = '$yyyy-$mm-$dd';

          final dayData = stationMap[dayKey] as Map<String, dynamic>?;
          if (dayData != null) {
            final rainBody = jsonEncode(dayData['r6']);
            final humBody = jsonEncode(dayData['r7']);
            final radBody = jsonEncode(dayData['r8']);
            final windBody = jsonEncode(dayData['r9']);

            _applyExtras(
              rainBody: rainBody,
              humBody: humBody,
              radBody: radBody,
              windBody: windBody,
            );

            if (mounted) {
              setState(() {
                _loading = false;
                // Puedes dejar o quitar este mensaje si no lo quieres ver en UI
                _error ??= 'Mostrando datos OFFLINE (última sincronización).';
              });
            }
          }
        }
      }
    } catch (_) {
      // si falla offline, no nos detenemos: pasamos a online
    }

    if (!mounted) return;

    // 2️⃣ ONLINE: refrescar en segundo plano
    setState(() {
      // Solo mostramos spinner si NO tenemos nada (ni antes ni de offline)
      final hasAnyDataNow =
          _wind != null || _rad != null || _humNow != null || _rainNow != null;
      _loading = !(hadDataBefore || hasAnyDataNow);
    });

    try {
      final windUrl = _buildDailyUrl(r: 9, idEst: st.id, day: widget.day);
      final radUrl = _buildDailyUrl(r: 8, idEst: st.id, day: widget.day);
      final rainUrl = _buildDailyUrl(r: 6, idEst: st.id, day: widget.day);
      final humUrl = _buildDailyUrl(r: 7, idEst: st.id, day: widget.day);

      // 🚀 Peticiones en paralelo + timeout
      final responses = await Future.wait([
        OfflineDataService.sharedClient.get(Uri.parse(windUrl)).timeout(const Duration(seconds: 10)),
        OfflineDataService.sharedClient.get(Uri.parse(radUrl)).timeout(const Duration(seconds: 10)),
        OfflineDataService.sharedClient.get(Uri.parse(rainUrl)).timeout(const Duration(seconds: 10)),
        OfflineDataService.sharedClient.get(Uri.parse(humUrl)).timeout(const Duration(seconds: 10)),
      ]);

      final resWind = responses[0];
      final resRad = responses[1];
      final resRain = responses[2];
      final resHum = responses[3];

      _applyExtras(
        rainBody: resRain.body,
        humBody: resHum.body,
        radBody: resRad.body,
        windBody: resWind.body,
      );

      // ✅ Guardar en offline
      await OfflineDataService.instance.saveDailyExtrasForStation(
        st.id,
        widget.day,
        {
          'r6': jsonDecode(resRain.body),
          'r7': jsonDecode(resHum.body),
          'r8': jsonDecode(resRad.body),
          'r9': jsonDecode(resWind.body),
        },
      );

      if (mounted) {
        setState(() {
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        // Solo mostramos error si no tenemos absolutamente nada que mostrar
        final hasAnyData =
            _wind != null || _rad != null || _humNow != null || _rainNow != null;
        if (!hasAnyData) {
          setState(() {
            _error = 'Error extras online: $e';
          });
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// Aplica el cálculo de viento/rad/humedad/lluvia a partir de los JSON (online u offline)
  void _applyExtras({
    required String rainBody,
    required String humBody,
    required String radBody,
    required String windBody,
  }) {
    _wind = _pickClosest(windBody, key: 'VelViento', unit: ' km/h');
    _rad = _pickClosest(radBody, key: 'Rad', unit: ' W/m²');
    _humNow = _pickClosest(humBody, key: 'Humedad', unit: ' %');

    final rain = _parseRain(rainBody);

    _rainTotal =
        rain.totalMm != null ? '${rain.totalMm!.toStringAsFixed(1)} mm' : '—';
    _rainMaxInt = rain.maxIntervalMm != null
        ? '${rain.maxIntervalMm!.toStringAsFixed(1)} mm'
        : '—';
    _rainNowMm = rain.closestValMm;
    _rainNow = rain.closestValMm != null
        ? '${rain.closestValMm!.toStringAsFixed(1)} mm'
        : '—';
    _rainTime = rain.closestTime != null
        ? '${rain.closestTime!.hour.toString().padLeft(2, '0')}:${rain.closestTime!.minute.toString().padLeft(2, '0')}'
        : '--:--';
    _rainResumen = [
      MapEntry('Total acumulada', _rainTotal ?? '—'),
      MapEntry('Máx. intervalo', _rainMaxInt ?? '—'),
      MapEntry('Promedio', '${_num(rain.avgMm)} mm'),
    ];

    final windStats = _dailyStats(windBody, key: 'VelViento');
    if (windStats != null) {
      _windResumen = [
        MapEntry('Máximo', '${_num(windStats.max)} km/h a las ${windStats.tMax ?? "--:--"}'),
        MapEntry('Mínimo', '${_num(windStats.min)} km/h a las ${windStats.tMin ?? "--:--"}'),
        MapEntry('Promedio', '${_num(windStats.avg)} km/h'),
      ];
    }

    final radStats = _dailyStats(radBody, key: 'Rad');
    if (radStats != null) {
      final total = _sumKey(radBody, key: 'Rad');
      _radResumen = [
        MapEntry('Total registrada', '${_num(total)} W/m²'),
        MapEntry('Promedio', '${_num(radStats.avg)} W/m²'),
      ];
    }

    final humStats = _dailyStats(humBody, key: 'Humedad');
    if (humStats != null) {
      _humResumen = [
        MapEntry('Máximo', '${_num(humStats.max)}% a las ${humStats.tMax ?? "--:--"}'),
        MapEntry('Mínimo', '${_num(humStats.min)}% a las ${humStats.tMin ?? "--:--"}'),
        MapEntry('Promedio', '${_num(humStats.avg)}%'),
      ];
    }

    // Series horarias para las mini-gráficas de viento/radiación/humedad.
    _windSeries = _series(windBody, key: 'VelViento');
    _radSeries = _series(radBody, key: 'Rad');
    _humSeries = _series(humBody, key: 'Humedad');
  }

  /// Extrae la serie horaria (en orden) de un cuerpo r6-r9 para dibujar mini-gráficas.
  List<double> _series(String body, {required String key}) {
    dynamic root;
    try {
      root = jsonDecode(body);
    } catch (_) {
      return const [];
    }
    if (root is! List || root.isEmpty || root.first is! Map) return const [];
    final lista = (root.first as Map)['Datos'] ?? (root.first as Map)['datos'];
    if (lista is! List) return const [];

    final out = <double>[];
    for (final e in lista) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final vRaw = m[key] ?? m[key.toLowerCase()];
      final v = double.tryParse((vRaw ?? '').toString().replaceAll(',', '.'));
      if (v != null) out.add(v);
    }
    return out;
  }

  String _num(double? v) => v == null ? '—' : v.toStringAsFixed(1);

  String? _pickClosest(String body, {required String key, required String unit}) {
    dynamic root;
    try {
      root = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (root is! List || root.isEmpty || root.first is! Map) return null;
    final map = Map<String, dynamic>.from(root.first as Map);
    final datos = map['Datos'] ?? map['datos'];
    if (datos is! List) return null;

    DateTime now = DateTime.now();
    DateTime? bestT;
    double? bestVal;

    for (final e in datos) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final hora = (m['Hora'] ?? m['hora'])?.toString();
      final vRaw = m[key] ?? m[key.toLowerCase()];

      if (hora == null || vRaw == null) continue;

      final parts = hora.split(':');
      if (parts.length < 2) continue;

      final hh = int.tryParse(parts[0]) ?? 0;
      final mm = int.tryParse(parts[1]) ?? 0;
      final t = DateTime(now.year, now.month, now.day, hh, mm);

      final val = double.tryParse(vRaw.toString().replaceAll(',', '.'));
      if (val == null) continue;

      if (bestT == null ||
          (t.difference(now)).inMinutes.abs() <
              (bestT.difference(now)).inMinutes.abs()) {
        bestT = t;
        bestVal = val;
      }
    }

    if (bestVal == null) return null;
    return '${bestVal.toStringAsFixed(1)}$unit';
  }

  _DayStats? _dailyStats(String body, {required String key}) {
    dynamic root;
    try {
      root = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (root is! List || root.isEmpty || root.first is! Map) return null;
    final obj = Map<String, dynamic>.from(root.first as Map);
    final lista = obj['Datos'] ?? obj['datos'];
    if (lista is! List) return null;

    double? min, max;
    double sum = 0.0;
    int count = 0;
    String? tMin, tMax;

    for (final e in lista) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final vRaw = m[key] ?? m[key.toLowerCase()];
      final hora = (m['Hora'] ?? m['hora'])?.toString();
      final v = double.tryParse((vRaw ?? '').toString().replaceAll(',', '.'));
      if (v == null) continue;

      if (min == null || v < min) {
        min = v;
        tMin = _fmtHora(hora);
      }
      if (max == null || v > max) {
        max = v;
        tMax = _fmtHora(hora);
      }
      sum += v;
      count++;
    }

    if (count == 0) return null;
    final avg = sum / count;
    return _DayStats(min: min, max: max, avg: avg, tMin: tMin, tMax: tMax);
  }

  double? _sumKey(String body, {required String key}) {
    dynamic root;
    try {
      root = jsonDecode(body);
    } catch (_) {
      return null;
    }
    if (root is! List || root.isEmpty || root.first is! Map) return null;
    final lista =
        (root.first as Map)['Datos'] ?? (root.first as Map)['datos'];
    if (lista is! List) return null;

    double sum = 0.0;
    int n = 0;
    for (final e in lista) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final vRaw = m[key] ?? m[key.toLowerCase()];
      final v = double.tryParse((vRaw ?? '').toString().replaceAll(',', '.'));
      if (v == null) continue;
      sum += v;
      n++;
    }
    return n == 0 ? null : sum;
  }

  String? _fmtHora(String? hhmm) {
    if (hhmm == null || !hhmm.contains(':')) return null;
    final p = hhmm.split(':');
    return '${p[0].padLeft(2, '0')}:${p[1].padLeft(2, '0')}';
  }

  _RainSummary _parseRain(String body) {
    dynamic root;
    try {
      root = jsonDecode(body);
    } catch (_) {
      return const _RainSummary();
    }
    if (root is! List || root.isEmpty || root.first is! Map) {
      return const _RainSummary();
    }

    final obj = Map<String, dynamic>.from(root.first as Map);
    final v = obj['Datos'] ?? obj['datos'];
    if (v is! List) return const _RainSummary();

    double total = 0.0;
    double maxInt = 0.0;
    DateTime now = DateTime.now();
    DateTime? closestT;
    double? closestVal;

    for (final e in v) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);
      final hhmm = (m['Hora'] ?? m['hora'])?.toString();
      final pre = (m['Pre'] ??
        m['pre'] ??
        m['Prec'] ??
        m['prec'] ??
        m['Lluvia'] ??
        m['lluvia'] ??
        m['rain']) 
    ?.toString();

      final val =
          double.tryParse((pre ?? '').toString().replaceAll(',', '.')) ?? 0.0;

      total += val;
      if (val > maxInt) maxInt = val;

      if (hhmm != null && hhmm.contains(':')) {
        final p = hhmm.split(':');
        final h = int.tryParse(p[0]) ?? 0;
        final mnt = int.tryParse(p[1]) ?? 0;
        final t = DateTime(now.year, now.month, now.day, h, mnt);
        if (closestT == null ||
            (t.difference(now)).inMinutes.abs() <
                (closestT.difference(now)).inMinutes.abs()) {
          closestT = t;
          closestVal = val;
        }
      }
    }

    return _RainSummary(
      totalMm: v.isEmpty ? null : total,
      maxIntervalMm: v.isEmpty ? null : maxInt,
      avgMm: v.isEmpty ? null : total / v.length,
      closestValMm: closestVal,
      closestTime: closestT,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.station == null) return const SizedBox.shrink();

    if (_loading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    if (_error != null &&
        _wind == null &&
        _rad == null &&
        _humNow == null &&
        _rainNow == null) {
      // Solo mostramos texto de error si no hay nada que mostrar
      return Text(
        'Extras: $_error',
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      );
    }

    return Column(
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.air,
                  label: 'Viento (ahora)',
                  value: _wind ?? '—',
                  resumen: _windResumen,
                  series: _windSeries,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  icon: Icons.wb_sunny_outlined,
                  label: 'Radiación (ahora)',
                  value: _rad ?? '—',
                  resumen: _radResumen,
                  series: _radSeries,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.water_drop,
                  label: 'Precipitación (hoy)',
                  value: _rainNow ?? '—',
                  time: _rainTime,
                  resumen: _rainResumen,
                  customVisual: _PrecipAnimation(isRaining: (_rainNowMm ?? 0) > 0.0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  icon: Icons.invert_colors,
                  label: 'Humedad (ahora)',
                  value: _humNow ?? '—',
                  resumen: _humResumen,
                  series: _humSeries,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Estructura de salida de lluvia
class _RainSummary {
  final double? totalMm;
  final double? maxIntervalMm;
  final double? avgMm;
  final double? closestValMm;
  final DateTime? closestTime;
  const _RainSummary({
    this.totalMm,
    this.maxIntervalMm,
    this.avgMm,
    this.closestValMm,
    this.closestTime,
  });
}

class _DayStats {
  final double? min;
  final double? max;
  final double? avg;
  final String? tMin;
  final String? tMax;

  _DayStats({this.min, this.max, this.avg, this.tMin, this.tMax});
}
