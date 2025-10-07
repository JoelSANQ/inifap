import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// URL de tu proxy
const String kProxyUrl =
    'http://localhost:8080/http://zacatecas.inifap.gob.mx/apiApp2.php?r=5&day=05&month=10&year=2025&id_est_given=18851';

/// 🎨 Colores del fondo (dime tu color y lo pongo aquí)
const Color kBgStart = Color(0xFF8A2BE2); // morado actual
const Color kBgEnd   = Color(0xFF7B68EE); // morado actual

class WeatherProxyPage extends StatefulWidget {
  const WeatherProxyPage({super.key});
  @override
  State<WeatherProxyPage> createState() => _WeatherProxyPageState();
}

class _WeatherProxyPageState extends State<WeatherProxyPage> {
  bool _loading = false;
  String? _error;

  _Current? _current;               // datos de la hora más cercana
  List<_Hourly> _hourly = const []; // serie por hora (o 15 min)

  // ==== Scroll horizontal de horas ====
  final ScrollController _hourCtrl = ScrollController();
  static const double _itemWidth = 64; // ancho de cada tarjeta
  static const double _itemGap   = 18; // separación entre tarjetas
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await http.get(
        Uri.parse(kProxyUrl),
        headers: const {'Accept': 'application/json'},
      );
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode} ${res.reasonPhrase}');
      }

      final (curr, hourly) = _parseZacatecasJson(res.body);

      // Índice del punto más cercano a "curr.time" (anclado a la fecha del dataset)
      int idx = 0;
      if (hourly.isNotEmpty && curr.time != null) {
        int best = 0;
        int bestDiff = 1 << 30;
        for (int i = 0; i < hourly.length; i++) {
          final t = hourly[i].time;
          if (t == null) continue;
          final d = (t.difference(curr.time!)).inMinutes.abs();
          if (d < bestDiff) {
            bestDiff = d;
            best = i;
          }
        }
        idx = best;
      }

      setState(() {
        _current = curr;
        _hourly = hourly;
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
    if (!_hourCtrl.hasClients || _hourly.isEmpty) return;
    final offset = _currentIndex * (_itemWidth + _itemGap);
    _hourCtrl.animateTo(
      offset,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final grad = const LinearGradient(
      colors: [kBgStart, kBgEnd],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );

    return Scaffold(
      backgroundColor: kBgStart,
      body: SafeArea(
        child: Center(
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
            decoration: BoxDecoration(
              gradient: grad,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 18, offset: Offset(0, 10))],
            ),
            width: 380,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Top bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      TimeOfDay.now().format(context),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                    ),
                    IconButton(
                      onPressed: _fetch,
                      icon: const Icon(Icons.refresh, color: Colors.white),
                      tooltip: 'Actualizar',
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Ícono + temperatura
                const Icon(Icons.cloud, color: Colors.white, size: 72),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _loading ? '—' : (_current?.tempC?.toStringAsFixed(0) ?? '—') + '°',
                    style: const TextStyle(
                      color: Colors.white, fontSize: 72, fontWeight: FontWeight.w700, height: 0.9),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    _loading ? 'Cargando…' : (_current?.condition ?? 'Nublado'),
                    style: const TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
                const SizedBox(height: 6),

                // Max/Min del día
                Center(
                  child: Text(
                    'Maxima: ${_current?.tMaxC?.toStringAsFixed(0) ?? '—'}°  '
                    'Mininima: ${_current?.tMinC?.toStringAsFixed(0) ?? '—'}°',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 4),

                // 👇 Estación debajo de Max/Min
                if (_current?.station != null)
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_pin, size: 16, color: Color.fromARGB(179, 0, 0, 0)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            _current!.station!,
                            style: const TextStyle(color: Colors.white70, fontSize: 18),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                const SizedBox(height: 16),

                // Tarjeta central
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          const Text('Hoy', style: TextStyle(color: Colors.white, fontSize: 14)),
                          const Spacer(),
                          Text(
                            _current?.dateText ?? _todayString(),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Center(
                          child: Text('Weather Visualization',
                              style: TextStyle(color: Colors.white70, fontSize: 14)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // ====== Franja de horas scrollable ======
                SizedBox(
                  height: 110,
                  child: _error != null
                      ? _ErrorStrip(error: _error!)
                      : (_loading
                          ? const Center(child: CircularProgressIndicator(color: Colors.white))
                          : ScrollConfiguration(
                              behavior: const MaterialScrollBehavior().copyWith(
                                dragDevices: {
                                  PointerDeviceKind.touch,
                                  PointerDeviceKind.mouse,
                                  PointerDeviceKind.trackpad,
                                  PointerDeviceKind.stylus,
                                },
                              ),
                              child: ListView.separated(
                                controller: _hourCtrl,
                                scrollDirection: Axis.horizontal,
                                physics: const BouncingScrollPhysics(),
                                primary: false,
                                itemCount: _hourly.isNotEmpty ? _hourly.length : 8,
                                separatorBuilder: (_, __) => const SizedBox(width: _itemGap),
                                itemBuilder: (_, i) {
                                  final h = _hourly.isEmpty ? _Hourly.placeholder(i) : _hourly[i];
                                  final isCurrent = i == _currentIndex;
                                  return SizedBox(
                                    width: _itemWidth,
                                    child: _HourTile(h: h, highlight: isCurrent),
                                  );
                                },
                              ),
                            )),
                ),

                const Spacer(),

                // Bottom actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    Icon(Icons.arrow_back, color: Colors.white),
                    Icon(Icons.location_pin, color: Colors.white),
                    Icon(Icons.access_time, color: Colors.white),
                    Icon(Icons.menu, color: Colors.white),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ====== UI widgets ======

class _HourTile extends StatelessWidget {
  final _Hourly h;
  final bool highlight;
  const _HourTile({required this.h, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final base = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          h.tempC != null ? '${h.tempC!.toStringAsFixed(0)}°' : '—°',
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Icon(
          h.precipMm != null && (h.precipMm! > 0) ? Icons.thunderstorm : Icons.cloud_queue,
          color: Colors.white,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(h.timeLabel, style: const TextStyle(color: Colors.white70, fontSize: 11)),
      ],
    );

    if (!highlight) return base;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white30),
      ),
      child: base,
    );
  }
}

class _ErrorStrip extends StatelessWidget {
  final String error;
  const _ErrorStrip({required this.error});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: Text('Error: $error', style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}

/// ====== Modelo y parser ======

class _Current {
  final DateTime? time; // hora más cercana (anclada a la fecha del dataset)
  final double? tempC;
  final double? tMaxC;  // max del día (JSON o derivado)
  final double? tMinC;  // min del día (JSON o derivado)
  final String? condition;
  final String? dateText;
  final String? station; // 👈 Estación

  _Current({this.time, this.tempC, this.tMaxC, this.tMinC, this.condition, this.dateText, this.station});
}

class _Hourly {
  final DateTime? time;
  final double? tempC;
  final double? precipMm;

  _Hourly({this.time, this.tempC, this.precipMm});

  String get timeLabel {
    if (time == null) return '--:--';
    final h = time!.hour.toString().padLeft(2, '0');
    final m = time!.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  factory _Hourly.placeholder(int i) {
    final base = DateTime.now().copyWith(minute: 0).add(Duration(minutes: 15 * i));
    return _Hourly(time: base, tempC: null, precipMm: null);
    }
}

/// Parser tolerante + selección usando ANCLA (fecha del dataset + hora local)
///
/// Devuelve: (actual, listaHoraAHora)
(_Current, List<_Hourly>) _parseZacatecasJson(String body) {
  dynamic root;
  try {
    root = jsonDecode(body);
  } catch (_) {
    return (_Current(), <_Hourly>[]);
  }

  Map<String, dynamic>? firstObj;
  if (root is List && root.isNotEmpty && root.first is Map) {
    firstObj = Map<String, dynamic>.from(root.first as Map);
  } else if (root is Map) {
    firstObj = Map<String, dynamic>.from(root as Map);
  }
  if (firstObj == null) return (_Current(), <_Hourly>[]);

  // Helper case-insensitive
  T? pick<T>(Map<String, dynamic> m, List<String> keys) {
    final lowered = <String, dynamic>{for (final e in m.entries) e.key.toLowerCase(): e.value};
    for (final k in keys) {
      final v = lowered[k.toLowerCase()];
      if (v != null) return v as T?;
    }
    return null;
  }

  final fecha   = pick<String>(firstObj, ['fecha', 'date', 'day']);
  final station = pick<String>(firstObj, ['Est', 'est', 'estacion', 'estación', 'station', 'site', 'nombre']);

  // Max/Min del objeto raíz (si existen)
  final tMaxRoot = _toDouble(pick(firstObj, ['tmax', 'tMax', 'max', 'tempmax', 'tMaxC']));
  final tMinRoot = _toDouble(pick(firstObj, ['tmin', 'tMin', 'min', 'tempmin', 'tMinC']));

  // Encuentra el array de horas (o cuartos de hora)
  List horas = [];
  for (final k in ['Datos', 'datos', 'data', 'values', 'horas', 'hourly']) {
    final v = firstObj[k] ?? firstObj[k.toLowerCase()];
    if (v is List) {
      horas = v;
      break;
    }
  }

  // --- ANCLA: misma fecha del dataset + hora/minuto actuales del dispositivo ---
  DateTime? day;
  if (fecha != null && RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(fecha)) {
    final p = fecha.split('-'); // dd-mm-yyyy
    day = DateTime(int.parse(p[2]), int.parse(p[1]), int.parse(p[0]));
  }
  final now = DateTime.now();
  final anchor = day != null
      ? DateTime(day.year, day.month, day.day, now.hour, now.minute)
      : now;

  _Hourly? closest;
  final list = <_Hourly>[];

  for (final h in horas) {
    if (h is! Map) continue;
    final mm = Map<String, dynamic>.from(h as Map);

    final horaTxt = (mm['Hora'] ?? mm['hora'] ?? mm['time'] ?? mm['Time'] ?? mm['HORA'])?.toString();
    final when = _parseFlexibleDate(fecha, horaTxt);

    final temp = _toDouble(mm['Temp'] ?? mm['temp'] ?? mm['T'] ?? mm['t']
        ?? mm['temperatura'] ?? mm['temperature']);
    final rain = _toDouble(mm['Prec'] ?? mm['prec'] ?? mm['lluvia'] ?? mm['rain']);

    final item = _Hourly(time: when, tempC: temp, precipMm: rain);
    list.add(item);

    if (when != null) {
      final diff = (when.difference(anchor)).inMinutes.abs(); // comparar contra ANCLA
      if (closest == null ||
          diff < (closest!.time!.difference(anchor)).inMinutes.abs()) {
        closest = item;
      }
    }
  }

  // Derivar max/min desde la serie si no vinieron en el objeto raíz
  double? derivedMax;
  double? derivedMin;
  final temps = list.where((e) => e.tempC != null).map((e) => e.tempC!).toList();
  if (temps.isNotEmpty) {
    temps.sort();
    derivedMin = temps.first;
    derivedMax = temps.last;
  }

  final curr = _Current(
    time: closest?.time ?? (list.isNotEmpty ? list.first.time : null),
    tempC: closest?.tempC,
    tMaxC: tMaxRoot ?? derivedMax,
    tMinC: tMinRoot ?? derivedMin,
    condition: (closest?.precipMm != null && (closest!.precipMm! > 0)) ? 'Precipitations' : 'Nublado',
    dateText: fecha,
    station: station,
  );

  return (curr, list);
}

/// ==== Utils ====

DateTime? _parseFlexibleDate(String? fecha, String? hora) {
  try {
    if (hora == null) return null;

    // "2025-06-06 15:00" / "2025-06-06T15:00:00"
    final iso = DateTime.tryParse(hora);
    if (iso != null) return iso;

    // "15:00" | "15" | "00:15"
    if (hora.contains(':') || RegExp(r'^\d{1,2}$').hasMatch(hora)) {
      final hh = int.parse(hora.split(':').first);
      final mm = hora.contains(':') ? int.parse(hora.split(':')[1]) : 0;

      if (fecha != null && RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(fecha)) {
        final p = fecha.split('-'); // dd-mm-yyyy
        final d = int.parse(p[0]), m = int.parse(p[1]), y = int.parse(p[2]);
        return DateTime(y, m, d, hh, mm);
      }
      final now = DateTime.now();
      return DateTime(now.year, now.month, now.day, hh, mm);
    }
  } catch (_) {}
  return null;
}

double? _toDouble(dynamic v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();
  final s = v.toString().replaceAll(',', '.');
  return double.tryParse(s);
}

String _todayString() {
  final now = DateTime.now();
  const months = [
    '', 'January','February','March','April','May','June',
    'July','August','September','October','November','December'
  ];
  return '${months[now.month]}, ${now.day}';
}
