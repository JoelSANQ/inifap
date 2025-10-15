// lib/daily_extras.dart
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
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white24),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                const SizedBox(height: 2),
                Text(value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600)),
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
  String? _wind; // Ej: "15.9 km/h"
  String? _rad;  // Ej: "320 W/m²"
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
    });

    try {
      // r=9: velocidad de viento (campo VelViento)
      final windUrl = _buildDailyUrl(r: 9, idEst: st.id, day: widget.day);
      // r=8: radiación (campo Rad)
      final radUrl  = _buildDailyUrl(r: 8, idEst: st.id, day: widget.day);

      final resWind = await http.get(Uri.parse(windUrl), headers: const {'Accept': 'application/json'});
      final resRad  = await http.get(Uri.parse(radUrl ), headers: const {'Accept': 'application/json'});

      if (resWind.statusCode != 200) {
        throw Exception('HTTP wind ${resWind.statusCode}');
      }
      if (resRad.statusCode != 200) {
        throw Exception('HTTP rad ${resRad.statusCode}');
      }

      _wind = _pickClosest(resWind.body, key: 'VelViento', unit: ' km/h');
      _rad  = _pickClosest(resRad.body , key: 'Rad'      , unit: ' W/m²');
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

    return Row(
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
    );
  }
}
