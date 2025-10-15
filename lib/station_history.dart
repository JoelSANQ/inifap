// lib/station_history.dart
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'data/Stations.dart';

/// ====== CONFIG ======
const String _kUpstream = 'http://zacatecas.inifap.gob.mx/apiApp2.php';
const String _kProxyBase = 'http://localhost:8080';

String _buildHistoryUrl({
  required int idEst,
  required int month,
  required int year,
}) {
  final mm = month.toString().padLeft(2, '0');
  final upstream = '$_kUpstream?r=10&month=$mm&year=$year&id_est_given=$idEst';
  return '$_kProxyBase/$upstream';
}

/// ====== MODEL ======
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

/// Parser para r=10: raíz = LISTA de objetos (cada objeto = día).
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

  @override
  void initState() {
    super.initState();
    final now = widget.initialMonth ?? DateTime.now();
    _cursor = DateTime(now.year, now.month);
    _fetch();
  }

  Future<void> _fetch() async {
    final st = widget.station;
    if (st == null) {
      setState(() => _error = 'No hay estación seleccionada.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
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
      // seleccionar hoy si existe, si no, el primer día
      int sel = -1;
      if (list.isNotEmpty) {
        final today = DateTime.now();
        for (int i = 0; i < list.length; i++) {
          final d = list[i].date;
          if (d.year == today.year && d.month == today.month && d.day == today.day) {
            sel = i; break;
          }
        }
        if (sel == -1) sel = 0;
      }
      setState(() {
        _days = list;
        _stationNameApi = estName ?? st.name;
        _selectedIndex = sel;
      });
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _prevMonth() {
    setState(() { _cursor = DateTime(_cursor.year, _cursor.month - 1); });
    _fetch();
  }

  void _nextMonth() {
    setState(() { _cursor = DateTime(_cursor.year, _cursor.month + 1); });
    _fetch();
  }

  double _sum(Iterable<double?> xs) => xs.whereType<double>().fold(0.0, (a, b) => a + b);
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
        title: Text('$stName — Histórico'),
        actions: [ IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)) ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Selector de mes
            Row(
              children: [
                IconButton(onPressed: _prevMonth, icon: const Icon(Icons.chevron_left)),
                Text('${_monthName(_cursor.month)} ${_cursor.year}',
                    style: theme.textTheme.titleMedium),
                IconButton(onPressed: _nextMonth, icon: const Icon(Icons.chevron_right)),
                const Spacer(),
                if (_loading) const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ),
            const SizedBox(height: 8),

            if (_error != null)
              _Error(msg: _error!)
            else if (_days.isEmpty && !_loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: Center(child: Text('Sin datos para este mes.')),
              )
            else ...[
              // --- NUEVO: Selector de día con chips ---
              SizedBox(
                height: 48,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  itemCount: _days.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) {
                    final d = _days[i].date;
                    final label = d.day.toString().padLeft(2, '0');
                    final selected = i == _selectedIndex;
                    return ChoiceChip(
                      label: Text(label),
                      selected: selected,
                      onSelected: (_) => setState(() => _selectedIndex = i),
                      selectedColor: theme.colorScheme.primary.withOpacity(.15),
                      labelStyle: TextStyle(
                        color: selected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(
                          color: selected
                              ? theme.colorScheme.primary
                              : Colors.grey.shade300,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),

              // Tarjetas de resumen rápidas (mes)
              Wrap(
                spacing: 12, runSpacing: 12,
                children: [
                  _MetricCard(title: 'Precipitación total',
                    value: '${_sum(_days.map((d) => d.pre)).toStringAsFixed(1)} mm'),
                  _MetricCard(title: 'Temp. máx promedio',
                    value: '${(_avg(_days.map((d) => d.tMax)) ?? 0).toStringAsFixed(1)} °C'),
                  _MetricCard(title: 'Temp. mín promedio',
                    value: '${(_avg(_days.map((d) => d.tMin)) ?? 0).toStringAsFixed(1)} °C'),
                ],
              ),
              const SizedBox(height: 16),

              // --- NUEVO: Gráfica mensual (línea TMax + barras Prec) ---
              AspectRatio(
                aspectRatio: 16 / 9,
                child: _MonthChart(
                  days: _days,
                  selectedIndex: _selectedIndex,
                  lineColor: theme.colorScheme.primary,
                  barColor: theme.colorScheme.secondary,
                ),
              ),
              const SizedBox(height: 16),

              // Ficha del día seleccionado
              if (selected != null)
                _DayDetailCard(day: selected),

              const SizedBox(height: 16),

              // Tabla al final
              _DayTable(days: _days),
            ],
          ],
        ),
      ),
    );
  }

  String _monthName(int m) {
    const months = [
      '', 'Enero','Febrero','Marzo','Abril','Mayo','Junio',
      'Julio','Agosto','Septiembre','Octubre','Noviembre','Diciembre'
    ];
    return months[m];
  }
}

/// ====== UI widgets ======

class _MetricCard extends StatelessWidget {
  final String title;
  final String value;
  const _MetricCard({required this.title, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF6F6F6),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E5E5)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
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
    String fmt(double? x, [String s = '']) => x == null ? '—' : '${x.toStringAsFixed(1)}$s';
    final dd = day.date.day.toString().padLeft(2, '0');
    final mm = day.date.month.toString().padLeft(2, '0');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE0E0E0)),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detalle del $dd-$mm-${day.date.year}',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 18, runSpacing: 8,
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
      width: 140,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(k), Text(v)],
      ),
    );
  }
}

// Tabla plana
class _DayTable extends StatelessWidget {
  final List<HistoricalDay> days;
  const _DayTable({required this.days});

  @override
  Widget build(BuildContext context) {
    String fmt(double? x) => x == null ? '—' : x.toStringAsFixed(1);
    return DataTable(
      columns: const [
        DataColumn(label: Text('Fecha')),
        DataColumn(label: Text('Tmax')),
        DataColumn(label: Text('Tmin')),
        DataColumn(label: Text('Tmed')),
        DataColumn(label: Text('Pre')),
        DataColumn(label: Text('Hum%')),
        DataColumn(label: Text('Vvmed')),
        DataColumn(label: Text('ETo')),
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
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFD32F2F)),
          const SizedBox(width: 10),
          Expanded(child: Text(msg)),
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

    // datos
    final ts = days.map((d) => d.tMax ?? 0).toList();
    final ps = days.map((d) => d.pre ?? 0).toList();

    final maxT = (ts.isEmpty ? 0 : ts.reduce((a, b) => a > b ? a : b));
    final minT = (ts.isEmpty ? 0 : ts.reduce((a, b) => a < b ? a : b));
    final maxP = (ps.isEmpty ? 0 : ps.reduce((a, b) => a > b ? a : b));

    final tRange = (maxT - minT).clamp(5, 999).toDouble();
    final pRange = (maxP == 0 ? 1 : maxP);

    // ejes/guides
    final axisPaint = Paint()..color = const Color(0xFFE0E0E0)..strokeWidth = 1;
    canvas.drawRect(Rect.fromLTWH(origin.dx, origin.dy, chartW, chartH), Paint()
      ..color = Colors.transparent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    // grid horizontal (4 líneas)
    for (int i = 0; i <= 4; i++) {
      final y = origin.dy + chartH * i / 4;
      canvas.drawLine(Offset(origin.dx, y), Offset(origin.dx + chartW, y), axisPaint);
    }

    // escala x
    final stepX = chartW / (days.length - 1).clamp(1, 999);
    // línea de temperatura
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;

    Path tempPath = Path();
    for (int i = 0; i < days.length; i++) {
      final tx = origin.dx + stepX * i;
      final ty = origin.dy + chartH - ((ts[i] - minT) / tRange) * chartH;
      if (i == 0) tempPath.moveTo(tx, ty); else tempPath.lineTo(tx, ty);
    }
    canvas.drawPath(tempPath, linePaint);

    // barras de precipitación
    final barPaint = Paint()..color = barColor.withOpacity(.5);
    final barW = (stepX * .6).clamp(2, 20);
    for (int i = 0; i < days.length; i++) {
      final bx = origin.dx + stepX * i - barW / 2;
      final bh = chartH * (ps[i] / pRange);
      final by = origin.dy + chartH - bh;
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(bx, by, barW.toDouble(), bh), const Radius.circular(3)),
        barPaint,
      );
    }

    // selección
    if (selectedIndex >= 0 && selectedIndex < days.length) {
      final sx = origin.dx + stepX * selectedIndex;
      final sy = origin.dy + chartH - ((ts[selectedIndex] - minT) / tRange) * chartH;

      final highlight = Paint()..color = Colors.black26..strokeWidth = 1.2;
      canvas.drawLine(Offset(sx, origin.dy), Offset(sx, origin.dy + chartH), highlight);

      final dot = Paint()..color = lineColor;
      canvas.drawCircle(Offset(sx, sy), 4, dot);

      // etiqueta simple del día
      final tp = TextPainter(
        text: TextSpan(text: days[selectedIndex].date.day.toString().padLeft(2, '0'), style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(sx - tp.width / 2, origin.dy + chartH + 6));
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
