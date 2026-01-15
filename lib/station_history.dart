// lib/station_history.dart
// ====== HISTÓRICO con tema burdeos + último día + métricas del DÍA + tabla con scroll ======

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb
import 'package:http/http.dart' as http;
import 'data/Stations.dart';
import 'bin/generate_offline.dart';
import 'indice.dart';
/// ====== PALETA ======
const kBurgundy = Color.fromARGB(255, 102, 6, 6);      // principal
const kBurgundyDark = Color.fromARGB(255, 97, 18, 50);  // cards oscuras
const kOnBurgundy = Colors.white;         // texto sobre oscuro
const kOnBurgundyMuted = Color(0xFFF3E8ED);
const kStroke = Color(0xFFE5E5E5);
const kWarmAccent = Color(0xFFE6A700);    // acento cálido (barras, iconos)

/// ====== CONFIG API ======
const String _kUpstream = 'http://zacatecas.inifap.gob.mx/apiApp2.php';
const String _kProxyBase = 'http://localhost:8080';

String _buildHistoryUrl({
  required int idEst,
  required int month,
  required int year,
}) {
  final mm = month.toString().padLeft(2, '0');
  final upstream =
      '$_kUpstream?r=10&month=$mm&year=$year&id_est_given=$idEst';

  // ✅ Web → usa proxy para evitar CORS
  if (kIsWeb) {
    return '$_kProxyBase/$upstream';
  }

  // ✅ Android / iOS / Desktop → va directo al upstream
  return upstream;
}

/// ====== MODELO ======
class HistoricalDay {
  final DateTime date;
  final double? tMax, tMin, tMed, pre, humMax, humMin, humMed, rad, velMed, velMax, eto;
  final String? dirViento;
  final String? station;

  HistoricalDay({
    required this.date,
    this.tMax,
    this.tMin,
    this.tMed,
    this.pre,
    this.humMax,
    this.humMin,
    this.humMed,
    this.rad,
    this.velMed,
    this.velMax,
    this.dirViento,
    this.eto,
    this.station,
  });
}

/// --- parsing robusto para "25,132.2", "35,6", "35.6"
double? _toDoubleSmart(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  var s = v.toString().trim();
  if (s.isEmpty) return null;
  if (s.contains('.') && s.contains(',')) {
    s = s.replaceAll(',', ''); // coma como millares
    return double.tryParse(s);
  }
  if (s.contains(',') && !s.contains('.')) {
    s = s.replaceAll(',', '.'); // coma decimal
    return double.tryParse(s);
  }
  return double.tryParse(s);
}

DateTime _parseFechaDDMMYYYY(String s) {
  final p = s.split('-');
  return DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
}

/// Parser para r=10
(List<HistoricalDay>, String?) _parseR10(String body) {
  dynamic root;
  try {
    root = jsonDecode(body);
  } catch (_) {
    return (<HistoricalDay>[], null);
  }

  if (root is List) {
    final list = <HistoricalDay>[];
    String? estName;
    for (final e in root) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e as Map);

      final fechaStr = (m['Fecha'] ?? m['fecha'])?.toString();
      if (fechaStr == null) continue;
      final date = _parseFechaDDMMYYYY(fechaStr);
      estName ??= (m['Est'] ?? m['est'] ?? m['estacion'] ?? m['Estación'])?.toString();

      list.add(HistoricalDay(
        date: date,
        station: estName,
        tMax: _toDoubleSmart(m['TempMax']),
        tMin: _toDoubleSmart(m['TempMin']),
        tMed: _toDoubleSmart(m['TempMed']),
        pre: _toDoubleSmart(m['Pre']),
        humMax: _toDoubleSmart(m['HumRMax']),
        humMin: _toDoubleSmart(m['HumRMin']),
        humMed: _toDoubleSmart(m['HumRMed']),
        rad: _toDoubleSmart(m['Rad']),
        velMed: _toDoubleSmart(m['VelMed']),
        velMax: _toDoubleSmart(m['VelMax']),
        dirViento: (m['DirViento'] ?? m['Dir'] ?? m['Viento'])?.toString(),
        eto: _toDoubleSmart(m['Eto']),
      ));
    }
    list.sort((a, b) => a.date.compareTo(b.date));
    return (list, estName);
  }

  if (root is Map) {
    final obj = Map<String, dynamic>.from(root);
    final datos = obj['Datos'] ?? obj['datos'] ?? obj['data'];
    final estName = (obj['Est'] ?? obj['est'] ?? obj['estacion'])?.toString();
    final list = <HistoricalDay>[];
    if (datos is List) {
      for (final e in datos) {
        if (e is! Map) continue;
        final m = Map<String, dynamic>.from(e as Map);
        final fechaStr = (m['Fecha'] ?? m['fecha'])?.toString();
        if (fechaStr == null) continue;
        final date = _parseFechaDDMMYYYY(fechaStr);
        list.add(HistoricalDay(
          date: date,
          station: estName,
          tMax: _toDoubleSmart(m['TempMax']),
          tMin: _toDoubleSmart(m['TempMin']),
          tMed: _toDoubleSmart(m['TempMed']),
          pre: _toDoubleSmart(m['Pre']),
          humMax: _toDoubleSmart(m['HumRMax']),
          humMin: _toDoubleSmart(m['HumRMin']),
          humMed: _toDoubleSmart(m['HumRMed']),
          rad: _toDoubleSmart(m['Rad']),
          velMed: _toDoubleSmart(m['VelMed']),
          velMax: _toDoubleSmart(m['VelMax']),
          dirViento: (m['DirViento'] ?? m['Dir'] ?? m['Viento'])?.toString(),
          eto: _toDoubleSmart(m['Eto']),
        ));
      }
      list.sort((a, b) => a.date.compareTo(b.date));
      return (list, estName);
    }
  }
  return (<HistoricalDay>[], null);
}

/// ====== PAGE ======
class StationHistoryPage extends StatefulWidget {
  final Station? station;        // estación desde WeatherProxy
  final DateTime? initialMonth;  // opcional
  const StationHistoryPage({super.key, this.station, this.initialMonth});

  @override
  State<StationHistoryPage> createState() => _StationHistoryPageState();
}

class _StationHistoryPageState extends State<StationHistoryPage> {
  bool _loading = false;
  String? _error;
  List<HistoricalDay> _days = const [];
  String? _stationNameApi;

  late DateTime _cursor; // mes visible (día 1)
  int _selectedIndex = -1;

  // autoscroll de chips al final
  final ScrollController _chipCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = widget.initialMonth ?? DateTime.now();
    _cursor = DateTime(now.year, now.month);
    _fetch();
  }

  @override
  void dispose() {
    _chipCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final st = widget.station;
    if (st == null) {
      setState(() => _error = 'No hay estación seleccionada.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      // 1️⃣ ONLINE primero
      final url = _buildHistoryUrl(
        idEst: st.id,
        month: _cursor.month,
        year: _cursor.year,
      );
      final res = await http.get(Uri.parse(url), headers: const {'Accept': 'application/json'});
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode} ${res.reasonPhrase}');
      }
      final (list, estName) = _parseR10(res.body);

      _applyNewData(list, estName ?? st.name);
    } catch (e) {
      // 2️⃣ OFFLINE fallback → offline_data.json → history.[idEst].[yyyy-mm]
      try {
        final root = await OfflineDataService.instance.loadOfflineRoot();
        if (root == null) {
          throw Exception('No hay archivo offline guardado.');
        }

        final history = root['history'] as Map<String, dynamic>?;
        if (history == null) {
          throw Exception('Sin sección history en offline_data.json');
        }

        final stKey = st.id.toString();
        final stMap = history[stKey] as Map<String, dynamic>?;
        if (stMap == null) {
          throw Exception('Sin histórico offline para estación $stKey');
        }

        final mm = _cursor.month.toString().padLeft(2, '0');
        final y = _cursor.year.toString();
        final monKey = '$y-$mm';

        final monthData = stMap[monKey];
        if (monthData == null) {
          throw Exception('Sin datos offline para $stKey en $monKey');
        }

        // monthData es la respuesta r=10 que guardaste (lista u objeto con Datos)
        final body = jsonEncode(monthData);
        final (list, estName) = _parseR10(body);

        if (list.isEmpty) {
          throw Exception('Lista offline vacía para $stKey en $monKey');
        }

        _applyNewData(list, estName ?? st.name);

        // (opcional) si quisieras marcar que son datos offline podrías tocar _error o un Snackbar
        // pero el layout actual muestra _Error solo si _error != null
      } catch (e2) {
        setState(() => _error = 'Error al cargar datos: $e\nOffline: $e2');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _applyNewData(List<HistoricalDay> list, String estName) {
    // === Selección: hoy si existe; si no, el ÚLTIMO día ===
    int sel = -1;
    if (list.isNotEmpty) {
      final today = DateTime.now();
      for (int i = 0; i < list.length; i++) {
        final d = list[i].date;
        if (d.year == today.year &&
            d.month == today.month &&
            d.day == today.day) {
          sel = i;
          break;
        }
      }
      if (sel == -1) sel = list.length - 1; // último
    }

    setState(() {
      _days = list;
      _stationNameApi = estName;
      _selectedIndex = sel;
      _error = null;
    });

    // desplazar los chips hacia el final para ver el último
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_chipCtrl.hasClients) {
        _chipCtrl.animateTo(
          _chipCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _prevMonth() {
    setState(() { _cursor = DateTime(_cursor.year, _cursor.month - 1); });
    _fetch();
  }

  void _nextMonth() {
    setState(() { _cursor = DateTime(_cursor.year, _cursor.month + 1); });
    _fetch();
  }

  double _sum(Iterable<double?> xs) =>
      xs.whereType<double>().fold(0.0, (a, b) => a + b);

  double? _avg(Iterable<double?> xs) {
    final v = xs.whereType<double>().toList();
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a + b) / v.length;
  }

  @override
  Widget build(BuildContext context) {
    final stName = _stationNameApi ?? widget.station?.name ?? 'Estación';
    final theme = Theme.of(context);

    final selected = (_selectedIndex >= 0 && _selectedIndex < _days.length)
        ? _days[_selectedIndex]
        : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBurgundy,
        foregroundColor: kOnBurgundy,
        title: Text('$stName — Histórico'),
        actions: [
          IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        color: kBurgundy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Selector de mes
            Row(
              children: [
                IconButton(
                    onPressed: _prevMonth,
                    icon: const Icon(Icons.chevron_left)),
                Text('${_monthName(_cursor.month)} ${_cursor.year}',
                    style: theme.textTheme.titleMedium),
                IconButton(
                    onPressed: _nextMonth,
                    icon: const Icon(Icons.chevron_right)),
                const Spacer(),
                if (_loading)
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: kBurgundy)),
              ],
            ),
            const SizedBox(height: 8),

            if (_error != null)
              const _Error(msg: 'Ocurrió un problema al cargar los datos.')
            else if (_days.isEmpty && !_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('Sin datos para este mes.')),
              )
            else ...[
              // Chips de días
              SizedBox(
                height: 48,
                child: ListView.separated(
                  controller: _chipCtrl,
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _days.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final d = _days[i].date;
                    final label = d.day.toString().padLeft(2, '0');
                    final isSel = i == _selectedIndex;
                    return ChoiceChip(
                      label: Text(label),
                      selected: isSel,
                      onSelected: (_) => setState(() => _selectedIndex = i),
                      selectedColor: kBurgundy,
                      backgroundColor: kWarmAccent,
                      labelStyle: TextStyle(
                        color: isSel ? kOnBurgundy : Colors.black87,
                        fontWeight:
                            isSel ? FontWeight.w600 : FontWeight.w500,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                            color: isSel ? kBurgundy : kStroke),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // ===== MÉTRICAS DEL DÍA SELECCIONADO =====
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _DayMetricCard(
                    title: 'Precipitación',
                    value: selected?.pre,
                    unit: ' mm',
                    icon: Icons.water_drop_outlined,
                  ),
                  _DayMetricCard(
                    title: 'T. máx',
                    value: selected?.tMax,
                    unit: ' °C',
                    icon: Icons.thermostat_outlined,
                  ),
                  _DayMetricCard(
                    title: 'T. mín',
                    value: selected?.tMin,
                    unit: ' °C',
                    icon: Icons.ac_unit_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Gráfica
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _MonthChart(
                  days: _days,
                  selectedIndex: _selectedIndex,
                  lineColor: kBurgundy,
                  barColor: kWarmAccent,
                ),
              ),
              
// 👇 AQUÍ AGREGAMOS EL ÍNDICE
              const ChartLegend(),
              
              const SizedBox(height: 16),
              

              // Ficha del día
              if (selected != null) _DayDetailCard(day: selected),

              const SizedBox(height: 16),

              // Tabla
              _DayTable(days: _days),
            ],
          ],
        ),
      ),
    );
  }

  String _monthName(int m) {
    const months = [
      '',
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre'
    ];
    return months[m];
  }
}

/// ====== UI widgets ======

class _DayMetricCard extends StatelessWidget {
  final String title;
  final double? value;
  final String unit;
  final IconData? icon;

  const _DayMetricCard({
    required this.title,
    required this.value,
    required this.unit,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    String fmt(double? x) =>
        x == null ? '—' : '${x.toStringAsFixed(1)}$unit';

    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: kBurgundyDark,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
                color: Colors.black12,
                blurRadius: 8,
                offset: Offset(0, 3))
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (icon != null) ...[
              Icon(icon, color: kWarmAccent, size: 22),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: const TextStyle(
                        color: kOnBurgundyMuted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                      )),
                  const SizedBox(height: 6),
                  Text(fmt(value),
                      style: const TextStyle(
                        color: kOnBurgundy,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayDetailCard extends StatelessWidget {
  final HistoricalDay day;
  const _DayDetailCard({required this.day});

  @override
  Widget build(BuildContext context) {
    String fmt(double? x, [String s = '']) =>
        x == null ? '—' : '${x.toStringAsFixed(1)}$s';
    final dd = day.date.day.toString().padLeft(2, '0');
    final mm = day.date.month.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kBurgundyDark,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
              color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detalle del $dd-$mm-${day.date.year}',
              style: const TextStyle(
                  color: kOnBurgundy,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Wrap(
            spacing: 18,
            runSpacing: 10,
            children: [
              _kv('T. máx', fmt(day.tMax, ' °C')),
              _kv('T. mín', fmt(day.tMin, ' °C')),
              _kv('T. med', fmt(day.tMed, ' °C')),
              _kv('Precip', fmt(day.pre, ' mm')),
              _kv('Humedad', fmt(day.humMed, ' %')),
              _kv('Viento med', fmt(day.velMed)),
              _kv('Dir. viento', day.dirViento ?? '—'),
              _kv('ETo', fmt(day.eto)),
              _kv('Rad', fmt(day.rad)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) {
    return SizedBox(
      width: 160,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(k,
              style: const TextStyle(
                  color: kOnBurgundyMuted,
                  fontWeight: FontWeight.w600)),
          const SizedBox(width: 8),
          Text(v, style: const TextStyle(color: kOnBurgundy)),
        ],
      ),
    );
  }
}

// ====== TABLA con scroll horizontal ======
class _DayTable extends StatelessWidget {
  final List<HistoricalDay> days;
  const _DayTable({required this.days});

  @override
  Widget build(BuildContext context) {
    String fmt(double? x) => x == null ? '—' : x.toStringAsFixed(1);

    final table = DataTable(
      headingTextStyle: const TextStyle(fontWeight: FontWeight.w700),
      headingRowHeight: 44,
      dataRowMinHeight: 40,
      dataRowMaxHeight: 44,
      columnSpacing: 14, // compacto
      columns: const [
        DataColumn(label: Text('Fecha')),
        DataColumn(label: Text('Tmax'), numeric: true),
        DataColumn(label: Text('Tmin'), numeric: true),
        DataColumn(label: Text('Tmed'), numeric: true),
        DataColumn(label: Text('Pre'), numeric: true),
        DataColumn(label: Text('Hum%'), numeric: true),
        DataColumn(label: Text('Vvmed'), numeric: true),
        DataColumn(label: Text('ETo'), numeric: true),
      ],
      rows: days.map((d) {
        final dd = d.date.day.toString().padLeft(2, '0');
        final mm = d.date.month.toString().padLeft(2, '0');
        return DataRow(cells: [
          DataCell(Text('$dd-$mm-${d.date.year}')),
          DataCell(Text(fmt(d.tMax))),
          DataCell(Text(fmt(d.tMin))),
          DataCell(Text(fmt(d.tMed))),
          DataCell(Text(fmt(d.pre))),
          DataCell(Text(fmt(d.humMed))),
          DataCell(Text(fmt(d.velMed))),
          DataCell(Text(fmt(d.eto))),
        ]);
      }).toList(),
    );

    // Scroll horizontal para ver todo sin redimensionar
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            // ocupa al menos el ancho visible (ajusta si cambias padding externo)
            minWidth: MediaQuery.of(context).size.width - 32,
          ),
          child: table,
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String msg;
  const _Error({required this.msg});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        children: const [
          Icon(Icons.error_outline, color: Color(0xFFD32F2F)),
          SizedBox(width: 10),
          Expanded(child: Text('Ocurrió un problema al cargar los datos.')),
        ],
      ),
    );
  }
}

/// ================= GRÁFICA =================

class _MonthChart extends StatelessWidget {
  final List<HistoricalDay> days;
  final int selectedIndex;
  final Color lineColor;
  final Color barColor;

  const _MonthChart({
    required this.days,
    required this.selectedIndex,
    required this.lineColor,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _MonthChartPainter(
        days: days,
        selectedIndex: selectedIndex,
        lineColor: lineColor,
        barColor: barColor,
        textStyle: Theme.of(context).textTheme.bodySmall!,
      ),
    );
  }
}

class _MonthChartPainter extends CustomPainter {
  final List<HistoricalDay> days;
  final int selectedIndex;
  final Color lineColor;
  final Color barColor;
  final TextStyle textStyle;

  _MonthChartPainter({
    required this.days,
    required this.selectedIndex,
    required this.lineColor,
    required this.barColor,
    required this.textStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (days.isEmpty) return;

    final padding = 28.0;
    final chartW = size.width - padding * 2;
    final chartH = size.height - padding * 2;
    final origin = Offset(padding, padding);

    final ts = days.map((d) => d.tMax ?? 0).toList();
    final ps = days.map((d) => d.pre ?? 0).toList();

    final maxT = (ts.isEmpty ? 0 : ts.reduce((a, b) => a > b ? a : b));
    final minT = (ts.isEmpty ? 0 : ts.reduce((a, b) => a < b ? a : b));
    final maxP = (ps.isEmpty ? 0 : ps.reduce((a, b) => a > b ? a : b));

    final tRange = (maxT - minT).clamp(5, 999).toDouble();
    final pRange = (maxP == 0 ? 1 : maxP);

    // grid
    final axisPaint = Paint()
      ..color = const Color(0xFFE0E0E0)
      ..strokeWidth = 1;
    canvas.drawRect(
      Rect.fromLTWH(origin.dx, origin.dy, chartW, chartH),
      Paint()
        ..color = Colors.transparent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    for (int i = 0; i <= 4; i++) {
      final y = origin.dy + chartH * i / 4;
      canvas.drawLine(
        Offset(origin.dx, y),
        Offset(origin.dx + chartW, y),
        axisPaint,
      );
    }

    // escala x
    final stepX = chartW / (days.length - 1).clamp(1, 999);

    // línea temperatura
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;

    Path tempPath = Path();
    for (int i = 0; i < days.length; i++) {
      final tx = origin.dx + stepX * i;
      final ty = origin.dy + chartH - ((ts[i] - minT) / tRange) * chartH;
      if (i == 0) {
        tempPath.moveTo(tx, ty);
      } else {
        tempPath.lineTo(tx, ty);
      }
    }
    canvas.drawPath(tempPath, linePaint);

    // barras precipitación
    final barPaint = Paint()..color = barColor.withOpacity(.75);
    final barW = (stepX * .6).clamp(2, 20);
    for (int i = 0; i < days.length; i++) {
      final bx = origin.dx + stepX * i - barW / 2;
      final bh = chartH * ((pRange == 0 ? 0 : ps[i] / pRange));
      final by = origin.dy + chartH - bh;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(bx, by, barW.toDouble(), bh),
          const Radius.circular(3),
        ),
        barPaint,
      );
    }

    // selección
    if (selectedIndex >= 0 && selectedIndex < days.length) {
      final sx = origin.dx + stepX * selectedIndex;
      final sy =
          origin.dy + chartH - ((ts[selectedIndex] - minT) / tRange) * chartH;

      final highlight = Paint()
        ..color = Colors.black26
        ..strokeWidth = 1.2;
      canvas.drawLine(
        Offset(sx, origin.dy),
        Offset(sx, origin.dy + chartH),
        highlight,
      );

      final dot = Paint()..color = lineColor;
      canvas.drawCircle(Offset(sx, sy), 4, dot);

      final tp = TextPainter(
        text: TextSpan(
          text: days[selectedIndex].date.day.toString().padLeft(2, '0'),
          style: textStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
        canvas,
        Offset(sx - tp.width / 2, origin.dy + chartH + 6),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MonthChartPainter old) {
    return old.days != days ||
        old.selectedIndex != selectedIndex ||
        old.lineColor != lineColor ||
        old.barColor != barColor;
  }
}
