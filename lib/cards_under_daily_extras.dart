// lib/daily_extras.dart
// WIDGET DE DATOS EXTRA DIARIOS (Viento, Radiación, Humedad, Lluvia)
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'data/Stations.dart';

const String _kUpstream = 'http://zacatecas.inifap.gob.mx/apiApp2.php';

/// Construye la URL del PROXY con r, fecha y estación
String _buildDailyUrl({required int r, required int idEst, required DateTime day}) {
  final dd = day.day.toString().padLeft(2, '0');
  final mm = day.month.toString().padLeft(2, '0');
  final yyyy = day.year.toString();
  final upstream = '$_kUpstream?r=$r&day=$dd&month=$mm&year=$yyyy&id_est_given=$idEst';
  // tu proxy local
  return 'http://localhost:8080/$upstream';
}

/// Mini tarjeta para un valor actual
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value; // texto final, ya con unidades si aplica

  const _MiniStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        // color fondo boton
        color: Color.fromARGB(255, 97, 18, 50), // #611232
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color.fromARGB(255, 165, 127, 44), size: 22), // #A57F2C
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: Color.fromARGB(255, 165, 127, 44), // #A57F2C
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color.fromRGBO(241, 116, 116, 1), // valores en rojo
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
  String? _wind;      // Ej: "15.9 km/h"   (r=9, VelViento)
  String? _rad;       // Ej: "320 W/m²"    (r=8, Rad)
  String? _humNow;    // Ej: "48.3 %"      (r=7, Humedad)
  // --- lluvia (r=6) ---
  String? _rainTotal;   // total del día
  String? _rainMaxInt;  // máximo intervalo
  String? _rainNow;     // valor actual
  String? _rainTime;    // hora del valor actual

  String? _error;
  bool _loading = false;

  @override
  void didUpdateWidget(covariant DailyExtrasStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.station?.id != widget.station?.id ||
        oldWidget.day.day != widget.day.day ||
        oldWidget.day.month != widget.day.month ||
        oldWidget.day.year != widget.day.year) {
      _fetch();
    }
  }

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    final st = widget.station;
    if (st == null) return;

    setState(() {
      _loading = true;
      _error = null;
      _wind = null;
      _rad = null;
      _humNow = null;
      _rainTotal = null;
      _rainMaxInt = null;
      _rainNow = null;
      _rainTime = null;
    });

    try {
      // r=9: velocidad de viento (campo VelViento)
      final windUrl = _buildDailyUrl(r: 9, idEst: st.id, day: widget.day);
      // r=8: radiación (campo Rad)
      final radUrl  = _buildDailyUrl(r: 8, idEst: st.id, day: widget.day);
      // r=6: precipitación
      final rainUrl = _buildDailyUrl(r: 6, idEst: st.id, day: widget.day);
      // r=7: humedad (campo Humedad)
      final humUrl  = _buildDailyUrl(r: 7, idEst: st.id, day: widget.day);

      final resWind = await http.get(Uri.parse(windUrl), headers: const {'Accept': 'application/json'});
      final resRad  = await http.get(Uri.parse(radUrl ), headers: const {'Accept': 'application/json'});
      final resRain = await http.get(Uri.parse(rainUrl), headers: const {'Accept': 'application/json'});
      final resHum  = await http.get(Uri.parse(humUrl ), headers: const {'Accept': 'application/json'});

      if (resWind.statusCode != 200) throw Exception('HTTP wind ${resWind.statusCode}');
      if (resRad.statusCode  != 200) throw Exception('HTTP rad ${resRad.statusCode}');
      if (resRain.statusCode != 200) throw Exception('HTTP rain ${resRain.statusCode}');
      if (resHum.statusCode  != 200) throw Exception('HTTP hum ${resHum.statusCode}');

      _wind = _pickClosest(resWind.body, key: 'VelViento', unit: ' km/h');
      _rad  = _pickClosest(resRad.body , key: 'Rad'      , unit: ' W/m²');
      _humNow = _pickClosest(resHum.body, key: 'Humedad', unit: ' %');

      // ---- lluvia: total / max intervalo / valor actual+hora ----
      final rain = _parseRain(resRain.body);
      _rainTotal = rain.totalMm != null ? '${rain.totalMm!.toStringAsFixed(1)} mm' : '—';
      _rainMaxInt = rain.maxIntervalMm != null ? '${rain.maxIntervalMm!.toStringAsFixed(1)} mm' : '—';
      if (rain.closestValMm != null) {
        _rainNow = '${rain.closestValMm!.toStringAsFixed(1)} mm';
        _rainTime = rain.closestTime != null
            ? '${rain.closestTime!.hour.toString().padLeft(2, '0')}:${rain.closestTime!.minute.toString().padLeft(2, '0')}'
            : '--:--';
      } else {
        _rainNow = '—';
        _rainTime = '--:--';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Busca el valor más cercano a la hora actual dentro de "Datos" [{Hora, <key>}]
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

      // parse hora tipo "15:30"
      final parts = hora.split(':');
      if (parts.length < 2) continue;
      final hh = int.tryParse(parts[0]) ?? 0;
      final mm = int.tryParse(parts[1]) ?? 0;
      final t = DateTime(now.year, now.month, now.day, hh, mm);

      final val = double.tryParse(vRaw.toString().replaceAll(',', '.'));
      if (val == null) continue;

      if (bestT == null ||
          (t.difference(now)).inMinutes.abs() < (bestT!.difference(now)).inMinutes.abs()) {
        bestT = t;
        bestVal = val;
      }
    }

    if (bestVal == null) return null;
    // formatea con 1 decimal
    return '${bestVal!.toStringAsFixed(1)}$unit';
  }

  // ======== LLUVIA (parser r=6) ========
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
    final fecha = (obj['Fecha'] ?? obj['fecha'])?.toString();

    List datos = [];
    final v = obj['Datos'] ?? obj['datos'] ?? obj['data'];
    if (v is List) datos = v;

    double total = 0.0;
    double maxInt = 0.0;

    DateTime now = DateTime.now();
    DateTime anchor = now;
    if (fecha != null && RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(fecha)) {
      final p = fecha.split('-'); // dd-mm-yyyy
      anchor = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]), now.hour, now.minute);
    }

    DateTime? closestT;
    double? closestVal;

    for (final e in datos) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e);

      final hhmm = (m['Hora'] ?? m['hora'] ?? m['time'])?.toString();
      final pre  = (m['Pre']  ?? m['pre']  ?? m['lluvia'])?.toString();
      final val = double.tryParse((pre ?? '').toString().replaceAll(',', '.')) ?? 0.0;

      total += val;
      if (val > maxInt) maxInt = val;

      DateTime? t;
      if (hhmm != null && hhmm.contains(':')) {
        final p = hhmm.split(':');
        final h = int.tryParse(p[0]) ?? 0;
        final mnt = int.tryParse(p[1]) ?? 0;
        t = DateTime(anchor.year, anchor.month, anchor.day, h, mnt);
      }

      if (t != null) {
        if (closestT == null ||
            (t.difference(anchor)).inMinutes.abs() < (closestT!.difference(anchor)).inMinutes.abs()) {
          closestT = t;
          closestVal = val;
        }
      }
    }

    return _RainSummary(
      totalMm: datos.isEmpty ? null : total,
      maxIntervalMm: datos.isEmpty ? null : maxInt,
      closestValMm: closestVal,
      closestTime: closestT,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.station == null) return const SizedBox.shrink();

    if (_loading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Extras: $_error',
            style: const TextStyle(color: Colors.white70, fontSize: 12)),
      );
    }

    // Construye el string de lluvia en una línea compacta
    final rainText = (_rainTotal == null && _rainMaxInt == null && _rainNow == null)
        ? '—'
        : ' ${_rainNow ?? "—"} ${_rainTime != null ? "" : ""}';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _MiniStat(
                icon: Icons.air,
                label: 'Viento (ahora)',
                value: _wind ?? '—',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _MiniStat(
                icon: Icons.wb_sunny_outlined,
                label: 'Radiación (ahora)',
                value: _rad ?? '—',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _MiniStat(
                    icon: Icons.water_drop, // lluvia
                    label: 'Precipitacion (hoy)',
                    value: rainText,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MiniStat(
                    icon: Icons.opacity, // humedad
                    label: 'Humedad (ahora)',
                    value: _humNow ?? '—',
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
