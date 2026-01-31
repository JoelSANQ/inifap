// lib/WeatherProxyPage.dart

import 'dart:convert';

import 'package:clima/report.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'About_Me.dart';
import 'data/Stations.dart';
import 'station_history.dart';
import 'cards_under_daily_extras.dart';
import 'package:clima/widgets/favorite_stations.dart';
import 'package:clima/widgets/maps.dart';
import 'bin/generate_offline.dart'; // OfflineDataService

/// ====== CONFIG API ======
const String _kUpstream = 'http://zacatecas.inifap.gob.mx/apiApp2.php';

String _buildProxyUrl({required int idEst}) {
  final now = DateTime.now();
  final dd = now.day.toString().padLeft(2, '0');
  final mm = now.month.toString().padLeft(2, '0');
  final yyyy = now.year.toString();

  final upstreamWithQuery =
      '$_kUpstream?r=5&day=$dd&month=$mm&year=$yyyy&id_est_given=$idEst';

  // 🔹 En Web usamos el proxy local (CORS)
  if (kIsWeb) {
    return 'http://localhost:8080/$upstreamWithQuery';
  }

  // 🔹 En Android/iOS/desktop vamos directo al endpoint real (sin CORS)
  return upstreamWithQuery;
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
  final http.Client _client = http.Client();

  bool _loading = false;
  String? _error;

  Station? _station;
  _Current? _current;
  List<_Hourly> _hourly = const [];

  String? _cacheJson; // caché en memoria del día (puede venir de SP u offline)
  final ScrollController _hourCtrl = ScrollController();
  static const double _itemWidth = 64;
  static const double _itemGap = 18;
  int _currentIndex = 0;

  // ===========================
  // ✅ POPUP "SEGUIR USANDO"
  // (solo se agrega, no cambia tu lógica)
  // ===========================
  bool _offlinePopupShown = false;

  Future<void> _showKeepUsingPopup() async {
    if (!mounted) return;
    if (_offlinePopupShown) return; // evita que se repita muchas veces

    _offlinePopupShown = true;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text('Sin conexión'),
        content: const Text(
          'No hay conexión, pero se muestran los últimos datos guardados.\n\n'
          '¿Deseas seguir usando la aplicación?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(), // ✅ solo cerrar
            child: const Text('Seguir usando'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _boot(); // arranque inmediato con última estación + caché/offline
  }

  Future<void> _boot() async {
    final sp = await SharedPreferences.getInstance();

    // 1) Estación por defecto o última usada
    if (widget.station != null) {
      _station = widget.station;
    } else {
      final lastId = sp.getInt('last_station_id');
      if (lastId != null) {
        _station = kStations.firstWhere(
          (s) => s.id == lastId,
          orElse: () => kStations.first,
        );
      } else {
        _station = kStations.first; // por defecto
      }
    }

    // 2) Mostrar caché de hoy (SharedPreferences) si existe
    _cacheJson = sp.getString('cache_${_station!.id}_${_todayKey()}');
    if (_cacheJson != null) {
      final (c, h) =
          _parseZacatecasJson(_cacheJson!, fallbackStation: _station!.name);
      setState(() {
        _current = c;
        _hourly = h;
        _currentIndex = _indexMasCercano(c.time, h);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    }

    // 2.5) Si NO hay caché del día, intentar leer del archivo offline (offline_data.json)
    if (_cacheJson == null && !kIsWeb) {
      final offlineJson = await OfflineDataService.instance
          .getRealtimeJsonForStation(_station!.id);
      if (offlineJson != null) {
        _cacheJson = offlineJson;
        final (c, h) =
            _parseZacatecasJson(_cacheJson!, fallbackStation: _station!.name);
        setState(() {
          _current = c;
          _hourly = h;
          _currentIndex = _indexMasCercano(c.time, h);
        });
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _scrollToCurrent());
      }
    }

    // 3) Refrescar en background (online) cuando haya conexión
    await _fetch();
  }

  @override
  void dispose() {
    _hourCtrl.dispose();
    _client.close();
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
                width: 40,
                height: 5,
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
                      trailing: isSel
                          ? const Icon(Icons.check, color: kGuinda)
                          : null,
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
      final res = await _client
          .get(Uri.parse(url), headers: const {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 6)); // ⏱️ timeout

      if (res.statusCode != 200) {
        throw Exception('HTTP ${res.statusCode} ${res.reasonPhrase}');
      }

      // Guardar caché (memoria + disco rápido)
      _cacheJson = res.body;
      final sp = await SharedPreferences.getInstance();
      await sp.setString('cache_${st.id}_${_todayKey()}', res.body);
      await sp.setInt('last_station_id', st.id);

      // Guardar también en offline_data.json (realtime)
      if (!kIsWeb) {
        await OfflineDataService.instance
            .saveRealtimeJsonForStation(st.id, res.body);
      }

      final (curr, hourly) =
          _parseZacatecasJson(res.body, fallbackStation: st.name);

      final idx = _indexMasCercano(curr.time, hourly);

      // (aquí podrías enganchar notificaciones de lluvia con hourly[idx])

      setState(() {
        _current = curr;
        _hourly = hourly;
        _currentIndex = idx;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
    } catch (e) {
      // =========== FALLÓ LA API ===========
      if (_cacheJson == null) {
        // No había nada en memoria → intentamos archivo offline
        if (!kIsWeb && _station != null) {
          final offlineJson = await OfflineDataService.instance
              .getRealtimeJsonForStation(_station!.id);

          if (offlineJson != null) {
            _cacheJson = offlineJson;
            final (c, h) = _parseZacatecasJson(
              _cacheJson!,
              fallbackStation: _station!.name,
            );

            if (mounted) {
              setState(() {
                _current = c;
                _hourly = h;
                _currentIndex = _indexMasCercano(c.time, h);
                _error = null;
              });

              WidgetsBinding.instance
                  .addPostFrameCallback((_) => _scrollToCurrent());

              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'No hay conexión. Se muestran datos guardados offline.',
                  ),
                ),
              );
            }

            // Ya resolvimos con offline, no mostramos popup de error.
            return;
          }
        }

        // Aquí ya no hubo ni caché ni offline → popup de sin conexión
        if (mounted) {
          setState(() => _error = e.toString());

          await showDialog(
            context: context,
            builder: (_) => const AlertDialog(
              title: Text('Sin conexión'),
              content: Text(
                'No se pudo conectar a la API y no hay datos guardados para hoy.\n\n'
                'Verifica tu conexión a Internet e inténtalo de nuevo.',
              ),
            ),
          );
        }
      } else {
        // ✅ Sí hay datos en caché/offline: solo avisamos y seguimos mostrando
        if (mounted) {
          // ✅ POPUP "Seguir usando" (no refresca, solo cierra)
          await _showKeepUsingPopup();

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'No hay conexión. Se muestran los últimos datos guardados.',
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  int _indexMasCercano(DateTime? now, List<_Hourly> hs) {
    if (now == null || hs.isEmpty) return 0;
    var best = 0, bestDiff = 1 << 30;
    for (var i = 0; i < hs.length; i++) {
      final t = hs[i].time;
      if (t == null) continue;
      final d = (t.difference(now)).inMinutes.abs();
      if (d < bestDiff) {
        bestDiff = d;
        best = i;
      }
    }
    return best;
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
      backgroundColor: kWhite,
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
                    style: const TextStyle(
                        color: kWhite, fontWeight: FontWeight.w600),
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
                      icon: const Icon(Icons.place_outlined,
                          size: 18, color: kWhite),
                      label: Text(
                        stationName ?? 'Elegir estación',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: kWhite),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      // 🔥 Recargar: intenta sync global + fetch para esta estación
                      if (!kIsWeb) {
                        await OfflineDataService.instance.syncFromNetwork();
                      }
                      await _fetch();
                    },
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
                    const Icon(Icons.thermostat, color: kBlack, size: 72),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        _loading
                            ? '—'
                            : (_current?.tempC?.toStringAsFixed(0) ?? '—') + '°',
                        style: const TextStyle(
                          color: kBlack,
                          fontSize: 72,
                          fontWeight: FontWeight.w700,
                          height: 0.9,
                        ),
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

                    // SELECTOR DE FAVORITOS
                    FavoriteStationsBar(
                      onSelect: (st) async {
                        setState(() => _station = st);
                        await _fetch();
                      },
                    ),

                    // Estación debajo de Max/Min
                    if (stationName != null)
                      Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_pin,
                                size: 16, color: kBlack70),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                stationName,
                                style: const TextStyle(
                                    color: kBlack70, fontSize: 13),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),

                    const SizedBox(height: 16),

                    // ====== Tarjeta central con MAPA ======
                    Container(
                      clipBehavior: Clip.hardEdge,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.black12),
                      ),
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: (_current != null)
                            ? SizedBox(
                                key: const ValueKey('mapReady'),
                                width: double.infinity,
                                height: 300,
                                child: const OSMMap(),
                              )
                            : SizedBox(
                                key: const ValueKey('mapSkeleton'),
                                height: 300,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // ====== Franja de horas scrollable ======
                    SizedBox(
                      height: 110,
                      child: _error != null
                          ? _ErrorStrip(error: _error!)
                          : (_loading && _hourly.isEmpty
                              ? const Center(
                                  child: CircularProgressIndicator(),
                                )
                              : ScrollConfiguration(
                                  behavior: const MaterialScrollBehavior()
                                      .copyWith(
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
                                    itemCount:
                                        _hourly.isNotEmpty ? _hourly.length : 8,
                                    separatorBuilder: (_, __) =>
                                        const SizedBox(width: _itemGap),
                                    itemBuilder: (_, i) {
                                      final h = _hourly.isEmpty
                                          ? _Hourly.placeholder(i)
                                          : _hourly[i];
                                      final isCurrent = i == _currentIndex;
                                      return SizedBox(
                                        width: _itemWidth,
                                        child: _HourTile(
                                          h: h,
                                          highlight: isCurrent,
                                        ),
                                      );
                                    },
                                  ),
                                )),
                    ),
                    const SizedBox(height: 12),

                    // Daily extras
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
              // 🔹 Acerca de nosotros
              IconButton(
                icon: const Icon(Icons.info_outline, color: kBlack),
                tooltip: 'Acerca de nosotros',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AboutUsPage(),
                    ),
                  );
                },
              ),

              // 🔹 Histórico
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

              // 🔹 Reporte
              IconButton(
                icon: const Icon(Icons.note, color: kBlack),
                tooltip: 'Reporte',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => WeatherDashboard(),
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

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month}-${n.day}';
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
        const Icon(
          Icons.thermostat,
          color: kBlack,
          size: 24,
        ),
        const SizedBox(height: 4),
        Text(
          h.timeLabel,
          style: const TextStyle(color: kBlack70, fontSize: 11),
        ),
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
        child: Text(
          'Error: $error',
          style: const TextStyle(color: kBlack),
        ),
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
  _Current({
    this.time,
    this.tempC,
    this.tMaxC,
    this.tMinC,
    this.condition,
    this.dateText,
    this.station,
  });
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
    final base =
        DateTime.now().copyWith(minute: 0).add(Duration(minutes: 15 * i));
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
    firstObj = Map<String, dynamic>.from(root);
  }
  if (firstObj == null) return (_Current(), <_Hourly>[]);

  T? pick<T>(Map<String, dynamic> m, List<String> keys) {
    final lowered = <String, dynamic>{
      for (final e in m.entries) e.key.toLowerCase(): e.value
    };
    for (final k in keys) {
      final v = lowered[k.toLowerCase()];
      if (v != null) return v as T?;
    }
    return null;
  }

  final fecha = pick<String>(firstObj, ['fecha', 'date', 'day']);
  final station = pick<String>(firstObj, [
        'Est',
        'est',
        'estacion',
        'estación',
        'station',
        'site',
        'nombre'
      ]) ??
      fallbackStation;

  final tMaxRoot =
      _toDouble(pick(firstObj, ['tmax', 'tMax', 'max', 'tempmax', 'tMaxC']));
  final tMinRoot =
      _toDouble(pick(firstObj, ['tmin', 'tMin', 'min', 'tempmin', 'tMinC']));

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
    final mm = Map<String, dynamic>.from(h);

    final horaTxt = (mm['Hora'] ??
            mm['hora'] ??
            mm['time'] ??
            mm['Time'] ??
            mm['HORA'])
        ?.toString();
    final when = _parseFlexibleDate(fecha, horaTxt);

    final temp = _toDouble(mm['Temp'] ??
        mm['temp'] ??
        mm['T'] ??
        mm['t'] ??
        mm['temperatura'] ??
        mm['temperature']);

    final rain =
        _toDouble(mm['Prec'] ?? mm['prec'] ?? mm['lluvia'] ?? mm['rain']);

    final item = _Hourly(time: when, tempC: temp, precipMm: rain);
    list.add(item);

    if (when != null) {
      final diff = (when.difference(anchor)).inMinutes.abs();
      if (closest == null ||
          diff < (closest.time!.difference(anchor)).inMinutes.abs()) {
        closest = item;
      }
    }
  }

  double? derivedMax;
  double? derivedMin;
  final temps =
      list.where((e) => e.tempC != null).map((e) => e.tempC!).toList();
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
    condition: (closest?.precipMm != null && (closest!.precipMm! > 0))
        ? 'Precipitations'
        : 'Nublado',
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
        final d = int.parse(p[0]);
        final m = int.parse(p[1]);
        final y = int.parse(p[2]);
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
    '',
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December'
  ];
  return '${months[now.month]}, ${now.day}';
}
