// lib/daily_extras.dart
// WIDGET DE DATOS EXTRA DIARIOS (Viento, Radiación, Humedad, Lluvia)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb
import 'package:http/http.dart' as http;
import 'data/Stations.dart';
import 'bin/generate_offline.dart';
import 'notifications/precipitation_notifications.dart';

const String _kUpstream = 'http://zacatecas.inifap.gob.mx/apiApp2.php';
const String _kProxyBase = 'http://localhost:8080';

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

/// Barra de "Resumen registrado"
class _ResumenBar extends StatelessWidget {
  final String? text;
  const _ResumenBar(this.text);

  @override
  Widget build(BuildContext context) {
    if (text == null || text!.trim().isEmpty) return const SizedBox.shrink();

    // 🔹 Divide el texto por "•" para mostrarlos en líneas verticales (columna)
    final parts = text!
        .split('•')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 79, 14, 41),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white24, width: 0.6),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (int i = 0; i < parts.length; i++) ...[
            if (i > 0) const SizedBox(height: 2),
            Text(
              parts[i],
              softWrap: true,
              maxLines: null,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12.5,
                height: 1.15,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Mini tarjeta para un valor actual + barra de resumen
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? resumen;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    this.resumen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 97, 18, 50),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                icon,
                color: const Color(0xFFE6A700),
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: Color(0xFFE6A700),
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      value,
                      softWrap: true,
                      maxLines: null,
                      overflow: TextOverflow.visible,
                      style: const TextStyle(
                        color: Color.fromRGBO(241, 116, 116, 1),
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _ResumenBar(resumen),
        ],
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
  String? _rainTime;

  String? _windResumen;
  String? _radResumen;
  String? _humResumen;
  String? _rainResumen;

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
        http.get(Uri.parse(windUrl)).timeout(const Duration(seconds: 6)),
        http.get(Uri.parse(radUrl)).timeout(const Duration(seconds: 6)),
        http.get(Uri.parse(rainUrl)).timeout(const Duration(seconds: 6)),
        http.get(Uri.parse(humUrl)).timeout(const Duration(seconds: 6)),
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

      if (mounted) {
        setState(() {
          _error = null; // online ok, limpiamos mensaje de offline si quieres
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

    // 🔔 Notificación / SnackBar según plataforma
    checarLluviaWebYMovil(
      context: context,
      lluviaActualMm: rain.closestValMm,
    );

    _rainTotal =
        rain.totalMm != null ? '${rain.totalMm!.toStringAsFixed(1)} mm' : '—';
    _rainMaxInt = rain.maxIntervalMm != null
        ? '${rain.maxIntervalMm!.toStringAsFixed(1)} mm'
        : '—';
    _rainNow = rain.closestValMm != null
        ? '${rain.closestValMm!.toStringAsFixed(1)} mm'
        : '—';
    _rainTime = rain.closestTime != null
        ? '${rain.closestTime!.hour.toString().padLeft(2, '0')}:${rain.closestTime!.minute.toString().padLeft(2, '0')}'
        : '--:--';
    _rainResumen =
        'Total acumulada: ${_rainTotal ?? "—"} • Máx. intervalo: ${_rainMaxInt ?? "—"}';

    final windStats = _dailyStats(windBody, key: 'VelViento');
    if (windStats != null) {
      _windResumen =
          'Máximo: ${_num(windStats.max)} km/h a las ${windStats.tMax ?? "--:--"} • '
          'Mínimo: ${_num(windStats.min)} km/h a las ${windStats.tMin ?? "--:--"} • '
          'Promedio: ${_num(windStats.avg)} km/h';
    }

    final radStats = _dailyStats(radBody, key: 'Rad');
    if (radStats != null) {
      final total = _sumKey(radBody, key: 'Rad');
      _radResumen =
          'Total registrada: ${_num(total)} W/m² • Promedio: ${_num(radStats.avg)} W/m²';
    }

    final humStats = _dailyStats(humBody, key: 'Humedad');
    if (humStats != null) {
      _humResumen =
          'Máximo: ${_num(humStats.max)}% a las ${humStats.tMax ?? "--:--"} • '
          'Mínimo: ${_num(humStats.min)}% a las ${humStats.tMin ?? "--:--"} • '
          'Promedio: ${_num(humStats.avg)}%';
    }
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

    final rainText = (_rainNow == null) ? '—' : '$_rainNow ${_rainTime ?? ""}';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                icon: Icons.air,
                label: 'Viento (ahora)',
                value: _wind ?? '—',
                resumen: _windResumen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniStat(
                icon: Icons.wb_sunny_outlined,
                label: 'Radiación (ahora)',
                value: _rad ?? '—',
                resumen: _radResumen,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                icon: Icons.water_drop,
                label: 'Precipitación (hoy)',
                value: rainText,
                resumen: _rainResumen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniStat(
                icon: Icons.opacity,
                label: 'Humedad (ahora)',
                value: _humNow ?? '—',
                resumen: _humResumen,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// Estructura de salida de lluvia
class _RainSummary {
  final double? totalMm;
  final double? maxIntervalMm;
  final double? closestValMm;
  final DateTime? closestTime;
  const _RainSummary({
    this.totalMm,
    this.maxIntervalMm,
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
