// lib/station_history.dart
// ====== HISTÓRICO con tema burdeos + último día + métricas del DÍA + tabla con scroll ======

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ kIsWeb
import 'package:connectivity_plus/connectivity_plus.dart';
import 'dart:async';
import 'bin/generate_offline.dart'; // OfflineDataService
import 'data/Stations.dart';
import 'indice.dart';
import 'widgets/shimmer.dart';
/// ====== PALETA ======
const kBurgundy = Color.fromARGB(255, 97, 18, 50);      // principal
const kBurgundyDark = Color(0xFF3D0A20);                 // cards oscuras
const kOnBurgundy = Colors.white;         // texto sobre oscuro
const kOnBurgundyMuted = Color(0xFFF3E8ED);
const kStroke = Color(0xFFE5E5E5);
const kWarmAccent = Color(0xFFE6A700);    // acento cálido (barras, iconos)
const kTextMuted = Color(0xFF5C5257);     // texto secundario sobre fondo claro
const kBurgundySoft = Color(0xFFF3E8ED);  // fondo suave para badges/insignias

/// ====== CONFIG API ======
const String _kUpstream = 'https://zacatecas.inifap.gob.mx/apiApp2.php';
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
      final m = Map<String, dynamic>.from(e );
      

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
        final m = Map<String, dynamic>.from(e);
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
  
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  bool _isOffline = false;
  // Evita que el aviso "sin conexión" parpadee con caídas de señal
  // momentáneas (cambio de torre, túnel corto, etc.).
  Timer? _offlineDebounce;
  static const Duration _offlineDebounceDelay = Duration(seconds: 3);

  // autoscroll de chips al final
  final ScrollController _chipCtrl = ScrollController();

  @override
  void initState() {
    super.initState();
    final now = widget.initialMonth ?? DateTime.now();
    _cursor = DateTime(now.year, now.month);

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((results) {
      final hasConn = !results.contains(ConnectivityResult.none);

      if (hasConn) {
        _offlineDebounce?.cancel();
        if (_isOffline) {
          debugPrint('🌐 Historial: Red recuperada. Actualizando...');
          _fetch();
        }
        if (!mounted) return;
        setState(() => _isOffline = false);
        return;
      }

      _offlineDebounce?.cancel();
      _offlineDebounce = Timer(_offlineDebounceDelay, () {
        if (!mounted) return;
        setState(() => _isOffline = true);
      });
    });

    _fetch();
  }

  @override
  void dispose() {
    _connectivitySubscription?.cancel();
    _offlineDebounce?.cancel();
    _chipCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    final st = widget.station;
    if (st == null) {
      setState(() => _error = 'No hay estación seleccionada.');
      return;
    }
    setState(() {
      _error = null;
      // ⚠️ Solo si la lista está vacía mostramos el spinner principal
      if (_days.isEmpty) _loading = true;
    });

    // ─────────────────────────────────────────
    // 1️⃣ OFFLINE FIRST: mostrar datos guardados al instante
    // ─────────────────────────────────────────
    try {
      final root = await OfflineDataService.instance.loadOfflineRoot();
      if (root != null) {
        final history = root['history'] as Map<String, dynamic>?;
        final stKey = st.id.toString();
        final stMap = history?[stKey] as Map<String, dynamic>?;
        if (stMap != null) {
          final mm = _cursor.month.toString().padLeft(2, '0');
          final y = _cursor.year.toString();
          final monKey = '$y-$mm';
          final monthData = stMap[monKey];
          if (monthData != null) {
            final body = jsonEncode(monthData);
            final (list, estName) = _parseR10(body);
            if (list.isNotEmpty) {
              _applyNewData(list, estName ?? st.name);
            }
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
      final url = _buildHistoryUrl(
        idEst: st.id,
        month: _cursor.month,
        year: _cursor.year,
      );
      final res = await OfflineDataService.sharedClient.get(Uri.parse(url), headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 8));
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode} ${res.reasonPhrase}');
      }
      final (list, estName) = _parseR10(res.body);
      _applyNewData(list, estName ?? st.name);

      // ✅ Guardar en offline
      await OfflineDataService.instance.saveHistoryForStation(
        st.id, _cursor.month, _cursor.year, res.body,
      );
    } catch (e) {
      // Solo mostramos error si no hay datos offline
      if (_days.isEmpty) {
        setState(() => _error = 'Error al cargar datos: $e');
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sin conexión. Mostrando datos guardados.')),
          );
        }
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

  @override
  Widget build(BuildContext context) {
    final stName = _stationNameApi ?? widget.station?.name ?? 'Estación';

    final selected = (_selectedIndex >= 0 && _selectedIndex < _days.length)
        ? _days[_selectedIndex]
        : null;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kBurgundy,
        foregroundColor: kOnBurgundy,
        title: Text(
          '$stName — Histórico',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
        actions: [
          IconButton(onPressed: _fetch, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetch,
        color: kBurgundy,
        child: Column(
          children: [
            // 🛰️ BANNER DE ESTADO (Aparece solo si no hay 4G/WiFi)
            if (_isOffline)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6),
                color: Colors.orange.shade800,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.signal_wifi_off, color: Colors.white, size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Sin conexión - Esperando 4G / WiFi...',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
          children: [
            // Eyebrow de sección
            Row(
              children: [
                Container(width: 22, height: 3, color: kWarmAccent),
                const SizedBox(width: 8),
                const Text(
                  'PERÍODO',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: kTextMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Selector de mes
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: kStroke),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  _MonthNavButton(icon: Icons.chevron_left, onPressed: _prevMonth),
                  Expanded(
                    child: Center(
                      child: Text(
                        '${_monthName(_cursor.month)} ${_cursor.year}',
                        style: const TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: kBurgundy,
                        ),
                      ),
                    ),
                  ),
                  _MonthNavButton(icon: Icons.chevron_right, onPressed: _nextMonth),
                  if (_loading) ...[
                    const SizedBox(width: 4),
                    const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: kBurgundy)),
                    const SizedBox(width: 10),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 16),

            if (_error != null)
              const _Error(msg: 'Ocurrió un problema al cargar los datos.')
            else if (_loading && _days.isEmpty)
              const _HistorySkeleton()
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
                      backgroundColor: kWarmAccent.withOpacity(0.16),
                      checkmarkColor: kOnBurgundy,
                      labelStyle: TextStyle(
                        color: isSel ? kOnBurgundy : kBurgundy,
                        fontWeight:
                            isSel ? FontWeight.w700 : FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: isSel ? kBurgundy : kWarmAccent.withOpacity(0.55),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),

              // Eyebrow de sección
              Row(
                children: [
                  Container(width: 22, height: 3, color: kWarmAccent),
                  const SizedBox(width: 8),
                  const Text(
                    'MÉTRICAS DEL DÍA',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: kTextMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: _DayMetricCard(
                      title: 'Precipitación',
                      value: selected?.pre,
                      unit: ' mm',
                      icon: Icons.water_drop_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DayMetricCard(
                      title: 'T. máx',
                      value: selected?.tMax,
                      unit: ' °C',
                      icon: Icons.thermostat_outlined,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _DayMetricCard(
                      title: 'T. mín',
                      value: selected?.tMin,
                      unit: ' °C',
                      icon: Icons.ac_unit_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Eyebrow de sección
              Row(
                children: [
                  Container(width: 22, height: 3, color: kWarmAccent),
                  const SizedBox(width: 8),
                  const Text(
                    'TENDENCIA MENSUAL',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.2,
                      color: kTextMuted,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Gráfica
              Container(
                padding: const EdgeInsets.fromLTRB(12, 16, 12, 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kStroke),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, 3)),
                  ],
                ),
                child: Column(
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: _MonthChart(
                        days: _days,
                        selectedIndex: _selectedIndex,
                        lineColor: kBurgundy,
                        barColor: kWarmAccent,
                      ),
                    ),
                    const ChartLegend(key: ValueKey('history_legend')),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Ficha del día
              if (selected != null) _DayDetailCard(day: selected),

              const SizedBox(height: 16),

              // Tabla
              _DayTable(days: _days),
            ],
          ],
        ),
      ),
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

/// Botón circular del selector de mes (< / >), con área táctil de 40x40.
class _MonthNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  const _MonthNavButton({required this.icon, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: kBurgundySoft,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Icon(icon, color: kBurgundy, size: 22),
        ),
      ),
    );
  }
}

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

    return Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBurgundyDark, kBurgundy],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: kBurgundy.withOpacity(0.22),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null)
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: kWarmAccent.withOpacity(0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: kWarmAccent, size: 16),
            ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kOnBurgundyMuted,
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            fmt(value),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: kOnBurgundy,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailEntry {
  final IconData icon;
  final String label;
  final String value;
  const _DetailEntry(this.icon, this.label, this.value);
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

    final entries = <_DetailEntry>[
      _DetailEntry(Icons.thermostat_outlined, 'T. máx', fmt(day.tMax, ' °C')),
      _DetailEntry(Icons.ac_unit_outlined, 'T. mín', fmt(day.tMin, ' °C')),
      _DetailEntry(Icons.thermostat, 'T. med', fmt(day.tMed, ' °C')),
      _DetailEntry(Icons.water_drop_outlined, 'Precip', fmt(day.pre, ' mm')),
      _DetailEntry(Icons.water_outlined, 'Humedad', fmt(day.humMed, ' %')),
      _DetailEntry(Icons.air, 'Viento med', fmt(day.velMed)),
      _DetailEntry(Icons.explore_outlined, 'Dir. viento', day.dirViento ?? '—'),
      _DetailEntry(Icons.eco_outlined, 'ETo', fmt(day.eto)),
      _DetailEntry(Icons.wb_sunny_outlined, 'Rad', fmt(day.rad)),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [kBurgundyDark, kBurgundy],
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: kBurgundy.withOpacity(0.22),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kWarmAccent.withOpacity(0.18),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.event_note_rounded, color: kWarmAccent, size: 17),
              ),
              const SizedBox(width: 10),
              Text('Detalle del $dd-$mm-${day.date.year}',
                  style: const TextStyle(
                      color: kOnBurgundy,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 14),
          Table(
            columnWidths: const {
              0: FlexColumnWidth(1.2),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1.2),
              3: FlexColumnWidth(1),
            },
            border: TableBorder(
              horizontalInside: BorderSide(color: Colors.white.withOpacity(0.10)),
            ),
            children: [
              for (int i = 0; i < entries.length; i += 2)
                TableRow(children: [
                  _label(entries[i].icon, entries[i].label),
                  _value(entries[i].value),
                  if (i + 1 < entries.length)
                    _label(entries[i + 1].icon, entries[i + 1].label)
                  else
                    const SizedBox.shrink(),
                  if (i + 1 < entries.length)
                    _value(entries[i + 1].value)
                  else
                    const SizedBox.shrink(),
                ]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _label(IconData icon, String k) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: kWarmAccent),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                k,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: kOnBurgundyMuted,
                  fontWeight: FontWeight.w600,
                  fontSize: 12.5,
                ),
              ),
            ),
          ],
        ),
      );

  Widget _value(String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Text(
          v,
          style: const TextStyle(
            color: kOnBurgundy,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      );
}

// ====== TABLA con scroll horizontal ======
class _DayTable extends StatelessWidget {
  final List<HistoricalDay> days;
  const _DayTable({required this.days});

  @override
  Widget build(BuildContext context) {
    String fmt(double? x) => x == null ? '—' : x.toStringAsFixed(1);

    const stripeColor = Color(0xFFFAF7F8);
    const cellStyle = TextStyle(fontSize: 13, color: Color(0xFF1A1416));

    final table = DataTable(
      headingRowColor: WidgetStateProperty.all(kBurgundy),
      headingTextStyle: const TextStyle(
        fontWeight: FontWeight.w700,
        color: Colors.white,
        fontSize: 13,
      ),
      dividerThickness: 0.5,
      columnSpacing: 18,
      horizontalMargin: 16,
      dataRowMinHeight: 44,
      dataRowMaxHeight: 56,
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
      rows: [
        for (int i = 0; i < days.length; i++)
          DataRow(
            // Zebra: facilita seguir la fila en tablas anchas.
            color: WidgetStateProperty.all(i.isEven ? Colors.white : stripeColor),
            cells: [
              DataCell(Text(
                '${days[i].date.day.toString().padLeft(2, '0')}-'
                '${days[i].date.month.toString().padLeft(2, '0')}-'
                '${days[i].date.year}',
                style: cellStyle,
              )),
              DataCell(Text(fmt(days[i].tMax), style: cellStyle)),
              DataCell(Text(fmt(days[i].tMin), style: cellStyle)),
              DataCell(Text(fmt(days[i].tMed), style: cellStyle)),
              DataCell(Text(fmt(days[i].pre), style: cellStyle)),
              DataCell(Text(fmt(days[i].humMed), style: cellStyle)),
              DataCell(Text(fmt(days[i].velMed), style: cellStyle)),
              DataCell(Text(fmt(days[i].eto), style: cellStyle)),
            ],
          ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Historial del mes',
                style: TextStyle(
                  color: kBurgundy,
                  fontSize: 15.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: kBurgundySoft,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${days.length} días',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: kBurgundy,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        const Row(
          children: [
            Icon(Icons.swipe_left_outlined, size: 14, color: kTextMuted),
            SizedBox(width: 6),
            Text(
              'Desliza la tabla para ver todas las columnas',
              style: TextStyle(fontSize: 12, color: kTextMuted),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kStroke),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          // Scroll horizontal para ver todo sin redimensionar
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
        ),
      ],
    );
  }
}

/// Placeholder de toda la sección (chips + métricas + tabla) mientras
/// llega la primera respuesta del mes. Ocupa el mismo espacio que el
/// contenido real → no hay salto al llegar los datos.
class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chips de días
          SizedBox(
            height: 48,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const NeverScrollableScrollPhysics(),
              child: Row(
                children: [
                  for (int i = 0; i < 10; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    const ShimmerBox(width: 40, height: 40, borderRadius: 12),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          const ShimmerBox(width: 150, height: 12),
          const SizedBox(height: 10),
          // Tarjetas de métricas del día
          Row(
            children: [
              for (int i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(width: 10),
                const Expanded(
                  child: ShimmerBox(width: double.infinity, height: 92, borderRadius: 16),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          const ShimmerBox(width: 150, height: 12),
          const SizedBox(height: 10),
          // Tabla de historial
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kStroke),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                Container(height: 56, color: kBurgundy),
                for (int i = 0; i < 5; i++)
                  Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: i.isEven ? Colors.white : const Color(0xFFFAF7F8),
                      border: const Border(
                        top: BorderSide(color: kStroke, width: 0.5),
                      ),
                    ),
                    child: const Row(
                      children: [
                        ShimmerBox(width: 60, height: 12),
                        Spacer(),
                        ShimmerBox(width: 100, height: 12),
                      ],
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

    const paddingLeft = 34.0;
    const paddingRight = 10.0;
    const paddingTop = 14.0;
    const paddingBottom = 22.0;
    final chartW = size.width - paddingLeft - paddingRight;
    final chartH = size.height - paddingTop - paddingBottom;
    final origin = Offset(paddingLeft, paddingTop);

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

    final axisLabelStyle = textStyle.copyWith(
      fontSize: 10,
      color: const Color(0xFF8A8386),
    );

    for (int i = 0; i <= 4; i++) {
      final y = origin.dy + chartH * i / 4;
      canvas.drawLine(
        Offset(origin.dx, y),
        Offset(origin.dx + chartW, y),
        axisPaint,
      );
    }

    // referencia de escala: T. máx y T. mín del mes en el eje Y
    void paintYLabel(String text, double y) {
      final tp = TextPainter(
        text: TextSpan(text: text, style: axisLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(origin.dx - tp.width - 6, y - tp.height / 2));
    }

    paintYLabel('${maxT.toStringAsFixed(0)}°', origin.dy);
    paintYLabel('${minT.toStringAsFixed(0)}°', origin.dy + chartH);

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

    // referencia de fechas: primer y último día del rango visible
    void paintDayTick(int i) {
      if (i == selectedIndex) return; // el día seleccionado ya se resalta abajo
      final tx = origin.dx + stepX * i;
      final tp = TextPainter(
        text: TextSpan(
          text: days[i].date.day.toString().padLeft(2, '0'),
          style: axisLabelStyle,
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(tx - tp.width / 2, origin.dy + chartH + 6));
    }

    // solo el último día: el primero chocaría con la etiqueta de T. mín del eje Y
    if (days.length > 1) paintDayTick(days.length - 1);

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
          style: textStyle.copyWith(color: lineColor, fontWeight: FontWeight.w700),
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
