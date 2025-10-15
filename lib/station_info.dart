import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'data/Stations.dart'; // Station(id, name)

class StationInfoPage extends StatefulWidget {
  final Station? station;
  final dynamic current; // opcional, por si traes algo de la pantalla anterior

  const StationInfoPage({super.key, this.station, this.current});

  @override
  State<StationInfoPage> createState() => _StationInfoPageState();
}

class _StationInfoPageState extends State<StationInfoPage> {
  bool _loading = false;
  String? _error;

  String? _dateText;
  String? _stationFromApi;
  List<_RainPoint> _points = const [];

  // --- Slider horizontal ---
  final ScrollController _ctrl = ScrollController();
  static const double _itemWidth = 72;
  static const double _itemGap = 14;
  int _currentIndex = 0;

  // CONFIG
  static const String _kUpstream = 'http://zacatecas.inifap.gob.mx/apiApp2.php';
  static const String _kProxyBase = 'http://localhost:8080';

  String _buildRainUrl(int idEst, {DateTime? date}) {
    final d = date ?? DateTime.now();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yyyy = d.year.toString();
    final upstream =
        '$_kUpstream?r=6&day=$dd&month=$mm&year=$yyyy&id_est_given=$idEst';
    return '$_kProxyBase/$upstream';
  }

  double get _totalDay =>
      _points.fold(0.0, (a, b) => a + (b.preMm.isFinite ? b.preMm : 0.0));
  double get _maxInterval =>
      _points.fold(0.0, (a, b) => a > b.preMm ? a : b.preMm);

  _RainPoint? get _currentPoint =>
      (_points.isNotEmpty && _currentIndex >= 0 && _currentIndex < _points.length)
          ? _points[_currentIndex]
          : null;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final st = widget.station;
    if (st == null) {
      setState(() => _error = 'No se recibió la estación.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url = _buildRainUrl(st.id);
      final res =
          await http.get(Uri.parse(url), headers: const {'Accept': 'application/json'});
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode} ${res.reasonPhrase}');
      }

      final (fecha, est, list) = _parseRainJson(res.body);

      // elegir índice más cercano a la hora actual (anclada a la fecha del dataset)
      int idx = 0;
      if (list.isNotEmpty) {
        final now = DateTime.now();
        DateTime anchor;
        if (fecha != null && RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(fecha)) {
          final p = fecha.split('-'); // dd-mm-yyyy
          anchor = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]),
              now.hour, now.minute);
        } else {
          anchor = now;
        }
        int best = 0;
        var bestDiff = 1 << 30;
        for (int i = 0; i < list.length; i++) {
          final t = list[i].time;
          if (t == null) continue;
          final d = (t.difference(anchor)).inMinutes.abs();
          if (d < bestDiff) {
            bestDiff = d;
            best = i;
          }
        }
        idx = best;
      }

      setState(() {
        _dateText = fecha;
        _stationFromApi = est;
        _points = list;
        _currentIndex = idx;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  void _scrollToCurrent() {
    if (!_ctrl.hasClients || _points.isEmpty) return;
    final offset = _currentIndex * (_itemWidth + _itemGap);
    _ctrl.animateTo(
      offset.toDouble(),
      duration: const Duration(milliseconds: 420),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final stationName =
        _stationFromApi ?? widget.station?.name ?? 'Estación ${widget.station?.id ?? ''}';
    final dateShown = _dateText ?? _todayLabel();

    return Scaffold(
      appBar: AppBar(
        title: Text(stationName),
        actions: [
          IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        child: _error != null
            ? ListView(
                padding: const EdgeInsets.all(16),
                children: [ _ErrorCard(msg: _error!) ],
              )
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text('Fecha: $dateShown', style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 12),

                  // Fila 1: Total / Máx
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: 'Total (día)',
                          value: '${_totalDay.toStringAsFixed(1)} mm',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricTile(
                          label: 'Máx. intervalo',
                          value: '${_maxInterval.toStringAsFixed(1)} mm',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Fila 2: Actual / Hora actual
                  Row(
                    children: [
                      Expanded(
                        child: _MetricTile(
                          label: 'Actual (mm)',
                          value: _currentPoint == null
                              ? '—'
                              : '${_currentPoint!.preMm.toStringAsFixed(1)} mm',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _MetricTile(
                          label: 'Hora actual',
                          value: _currentPoint?.hhmm ?? '--:--',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),

                  if (_loading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (_points.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text('Sin datos para esta fecha.')),
                    )
                  else
                    SizedBox(
                      height: 120,
                      child: ListView.separated(
                        controller: _ctrl,
                        scrollDirection: Axis.horizontal,
                        physics: const BouncingScrollPhysics(),
                        itemCount: _points.length,
                        separatorBuilder: (_, __) => const SizedBox(width: _itemGap),
                        itemBuilder: (_, i) {
                          final p = _points[i];
                          final isCurrent = i == _currentIndex;
                          return SizedBox(
                            width: _itemWidth,
                            child: _RainTile(point: p, highlight: isCurrent),
                          );
                        },
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  // ----- Parser r=6 -----

  (_StringOrNull, _StringOrNull, List<_RainPoint>) _parseRainJson(String body) {
    dynamic root;
    try {
      root = jsonDecode(body);
    } catch (_) {
      return (null, null, <_RainPoint>[]);
    }

    Map<String, dynamic>? obj;
    if (root is List && root.isNotEmpty && root.first is Map) {
      obj = Map<String, dynamic>.from(root.first as Map);
    } else if (root is Map) {
      obj = Map<String, dynamic>.from(root as Map);
    }
    if (obj == null) return (null, null, <_RainPoint>[]);

    String? fecha = (obj['Fecha'] ?? obj['fecha'])?.toString();
    String? est   = (obj['Est'] ?? obj['est'] ?? obj['estacion'])?.toString();

    List datos = [];
    final v = obj['Datos'] ?? obj['datos'] ?? obj['data'];
    if (v is List) datos = v;

    final list = <_RainPoint>[];
    for (final e in datos) {
      if (e is! Map) continue;
      final m = Map<String, dynamic>.from(e as Map);
      final hhmm = (m['Hora'] ?? m['hora'] ?? m['time'])?.toString();
      final pre  = (m['Pre']  ?? m['pre']  ?? m['lluvia'])?.toString();

      final dt = _composeDate(fecha, hhmm);
      final mm = _toDouble(pre) ?? 0.0;
      list.add(_RainPoint(time: dt, preMm: mm));
    }

    return (fecha, est, list);
  }

  DateTime? _composeDate(String? fecha, String? hhmm) {
    try {
      if (hhmm == null) return null;
      if (hhmm.contains(':')) {
        final p = hhmm.split(':');
        final h = int.parse(p[0]);
        final m = int.parse(p[1]);
        if (fecha != null && RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(fecha)) {
          final d = fecha.split('-'); // dd-mm-yyyy
          return DateTime(int.parse(d[2]), int.parse(d[1]), int.parse(d[0]), h, m);
        }
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day, h, m);
      }
    } catch (_) {}
    return null;
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString().replaceAll(',', '.'));
  }

  String _todayLabel() {
    final d = DateTime.now();
    return '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
  }
}

// ---------- modelos / widgets ----------

typedef _StringOrNull = String?;

class _RainPoint {
  final DateTime? time;
  final double preMm;
  _RainPoint({required this.time, required this.preMm});

  String get hhmm {
    if (time == null) return '--:--';
    final h = time!.hour.toString().padLeft(2, '0');
    final m = time!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  const _MetricTile({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF6F6F6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E5E5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.labelMedium),
          const SizedBox(height: 6),
          Text(value, style: Theme.of(context).textTheme.titleLarge),
        ],
      ),
    );
  }
}

class _RainTile extends StatelessWidget {
  final _RainPoint point;
  final bool highlight;
  const _RainTile({required this.point, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final valueStr = point.preMm.toStringAsFixed(1);
    final hasRain = point.preMm > 0;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$valueStr mm', style: const TextStyle(fontSize: 13)),
        const SizedBox(height: 6),
        Icon(hasRain ? Icons.water_drop : Icons.cloud_queue, size: 22),
        const SizedBox(height: 6),
        Text(point.hhmm, style: const TextStyle(fontSize: 11, color: Colors.black54)),
      ],
    );

    if (!highlight) {
      return _card(content, fill: hasRain ? const Color(0xFFE3F2FD) : const Color(0xFFF3F3F3));
    }
    return _card(
      content,
      border: const Color(0xFF90CAF9),
      fill: const Color(0xFFE3F2FD),
    );
  }

  Widget _card(Widget child, {Color? fill, Color? border}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: fill ?? Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border ?? const Color(0xFFE0E0E0)),
      ),
      child: child,
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String msg;
  const _ErrorCard({required this.msg});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF3F3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFCDD2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFD32F2F)),
          const SizedBox(width: 10),
          Expanded(child: Text(msg)),
        ],
      ),
    );
  }
}
