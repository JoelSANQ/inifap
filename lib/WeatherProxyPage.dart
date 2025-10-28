
import 'dart:convert';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'data/Stations.dart';
import 'station_info.dart';
import 'station_history.dart';
import 'daily_extras.dart';
import 'package:clima/widgets/favorite_stations.dart';




void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: WeatherProxyPage(),
  ));
}

/// ====== CONFIG ======
const String _kUpstream = 'http://zacatecas.inifap.gob.mx/apiApp2.php';

String _buildProxyUrl({required int idEst}) {
  final now = DateTime.now();
  final dd = now.day.toString().padLeft(2, '0');
  final mm = now.month.toString().padLeft(2, '0');
  final yyyy = now.year.toString();
  final upstreamWithQuery =
      '$_kUpstream?r=5&day=$dd&month=$mm&year=$yyyy&id_est_given=$idEst';
  return 'http://localhost:8080/$upstreamWithQuery';
}

/// 🎨 Paleta
const Color kGuinda = Color.fromARGB(255, 102, 6, 6); // barra superior
const Color kWhite = Colors.white;
const Color kBlack = Colors.black;
const Color kBlack70 = Colors.black54;

class WeatherProxyPage extends StatefulWidget {
  final Station? station;
  const WeatherProxyPage({super.key, this.station});

  @override
  State<WeatherProxyPage> createState() => _WeatherProxyPageState();
}

class _WeatherProxyPageState extends State<WeatherProxyPage> {
  bool _loading = false;
  String? _error;

  Station? _station;
  _Current? _current;
  List<_Hourly> _hourly = const [];

  final ScrollController _hourCtrl = ScrollController();
  static const double _itemWidth = 64;
  static const double _itemGap   = 18;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _station = widget.station;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_station == null) {
        await _pickStation();
      } else {
        _fetch();
      }
    });
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickStation() async {
    final selected = await showModalBottomSheet<Station>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          builder: (_, controller) => Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 40, height: 5,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Selecciona estación',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  itemCount: kStations.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final st = kStations[i];
                    final isSel = _station?.id == st.id;
                    return ListTile(
                      title: Text(st.name),
                      trailing: isSel ? const Icon(Icons.check, color: kGuinda) : null,
                      onTap: () => Navigator.of(ctx).pop(st),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (selected != null) {
      setState(() {
        _station = selected;
        _hourly = const [];
        _current = null;
        _error = null;
      });
      await _fetch();
    }
  }

  Future<void> _fetch() async {
    final st = _station;
    if (st == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final url = _buildProxyUrl(idEst: st.id);
      final res = await http.get(
        Uri.parse(url),
        headers: const {'Accept': 'application/json'},
      );
      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode} ${res.reasonPhrase}');
      }

      final (curr, hourly) = _parseZacatecasJson(
        res.body,
        fallbackStation: st.name,
      );

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
    final stationName = _current?.station ?? _station?.name;

    return Scaffold(
      backgroundColor: kWhite, // 🔳 fondo general blanco
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ====== TOP BAR GUINDA ======
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: kGuinda,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    TimeOfDay.now().format(context),
                    style: const TextStyle(color: kWhite, fontWeight: FontWeight.w600),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: kWhite,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        alignment: Alignment.centerLeft,
                      ),
                      onPressed: _pickStation,
                      icon: const Icon(Icons.place_outlined, size: 18, color: kWhite),
                      label: Text(
                        stationName ?? 'Elegir estación',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kWhite),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: _fetch,
                    icon: const Icon(Icons.refresh, color: kWhite),
                    tooltip: 'Actualizar',
                  ),
                ],
              ),
            ),

            // ====== CONTENIDO BLANCO ======
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 8),

                    // Ícono + temperatura
                    const Icon(Icons.cloud, color: kBlack, size: 72),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _loading ? '—' : (_current?.tempC?.toStringAsFixed(0) ?? '—') + '°',
                        style: const TextStyle(
                          color: kBlack, fontSize: 72, fontWeight: FontWeight.w700, height: 0.9),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _loading ? 'Cargando…' : (_current?.condition ?? 'Nublado'),
                        style: const TextStyle(color: kBlack, fontSize: 18),
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Max/Min del día
                    Center(
                      child: Text(
                        'Maxima: ${_current?.tMaxC?.toStringAsFixed(0) ?? '—'}°  '
                        'Mininima: ${_current?.tMinC?.toStringAsFixed(0) ?? '—'}°',
                        style: const TextStyle(color: kBlack70, fontSize: 14),
                      ),
                    ),
                    const SizedBox(height: 4),

                    //SELECTOR DE FAVORITOS

                      FavoriteStationsBar(
                        onSelect: (st) {
                          setState(() => _station = st);
                          _fetch();
                        },
                      ),

                    // Estación debajo de Max/Min
                    if (stationName != null)
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_pin, size: 16, color: kBlack70),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                stationName,
                                style: const TextStyle(color: kBlack70, fontSize: 13),
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
                        color: Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              const Text('Hoy', style: TextStyle(color: kBlack, fontSize: 14)),
                              const Spacer(),
                              Text(
                                _current?.dateText ?? _todayString(),
                                style: const TextStyle(color: kBlack, fontSize: 14),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.04),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: const Center(
                              child: Text('Weather Visualization',
                                  style: TextStyle(color: kBlack70, fontSize: 14)),
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
                              ? const Center(child: CircularProgressIndicator())
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

                    const SizedBox(height: 12),
                    DailyExtrasStrip(
                      station: _station,
                      day: DateTime.now(),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),




      /// ====== BOTONES INFERIORES FIJOS ======
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          color: kWhite,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
            TextButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text(
                  'Acerca de nosotros',
                  style: TextStyle(
                    color: Colors.black, // mismo color que antes
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.access_time, color: kBlack),
                tooltip: 'Histórico del mes',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StationHistoryPage(
                        station: _station,
                        initialMonth: DateTime.now(),
                      ),
                    ),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.air, color: kBlack),
                tooltip: 'Más info',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => StationInfoPage(
                        station: _station,
                        current: _current,
                      ),
                    ),
                  );
                },
              ),
            ],
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
          style: const TextStyle(color: kBlack, fontSize: 14),
        ),
        const SizedBox(height: 4),
        Icon(
          h.precipMm != null && (h.precipMm! > 0) ? Icons.thunderstorm : Icons.cloud_queue,
          color: kBlack,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(h.timeLabel, style: const TextStyle(color: kBlack70, fontSize: 11)),
      ],
    );

    if (!highlight) return base;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black26),
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
        color: Colors.black.withOpacity(0.06),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: Text('Error: $error', style: const TextStyle(color: kBlack)),
      ),
    );
  }
}

/// ====== Modelo y parser ======
class _Current {
  final DateTime? time;
  final double? tempC;
  final double? tMaxC;
  final double? tMinC;
  final String? condition;
  final String? dateText;
  final String? station;
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

(_Current, List<_Hourly>) _parseZacatecasJson(
  String body, {
  required String fallbackStation,
}) {
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

  T? pick<T>(Map<String, dynamic> m, List<String> keys) {
    final lowered = <String, dynamic>{for (final e in m.entries) e.key.toLowerCase(): e.value};
    for (final k in keys) {
      final v = lowered[k.toLowerCase()];
      if (v != null) return v as T?;
    }
    return null;
  }

  final fecha   = pick<String>(firstObj, ['fecha', 'date', 'day']);
  final station = pick<String>(firstObj, ['Est', 'est', 'estacion', 'estación', 'station', 'site', 'nombre']) ?? fallbackStation;

  final tMaxRoot = _toDouble(pick(firstObj, ['tmax', 'tMax', 'max', 'tempmax', 'tMaxC']));
  final tMinRoot = _toDouble(pick(firstObj, ['tmin', 'tMin', 'min', 'tempmin', 'tMinC']));

  List horas = [];
  for (final k in ['Datos', 'datos', 'data', 'values', 'horas', 'hourly']) {
    final v = firstObj[k] ?? firstObj[k.toLowerCase()];
    if (v is List) {
      horas = v;
    }
  }

  DateTime? day;
  if (fecha != null && RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(fecha)) {
    final p = fecha.split('-');
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
      final diff = (when.difference(anchor)).inMinutes.abs();
      if (closest == null ||
          diff < (closest!.time!.difference(anchor)).inMinutes.abs()) {
        closest = item;
      }
    }
  }

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

    final iso = DateTime.tryParse(hora);
    if (iso != null) return iso;

    if (hora.contains(':') || RegExp(r'^\d{1,2}$').hasMatch(hora)) {
      final hh = int.parse(hora.split(':').first);
      final mm = hora.contains(':') ? int.parse(hora.split(':')[1]) : 0;

      if (fecha != null && RegExp(r'^\d{2}-\d{2}-\d{4}$').hasMatch(fecha)) {
        final p = fecha.split('-');
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
