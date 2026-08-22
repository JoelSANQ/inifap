// bin/generate_offline.dart
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../services/station_service.dart';



const String _kUpstream = 'https://zacatecas.inifap.gob.mx/apiApp2.php';

// ─────────────────────────────────────────────
// 🩹 PARCHE TEMPORAL: el WAF (SafeLine) del servidor del INIFAP bloquea
// con 403 cualquier cliente que no tenga huella de navegador real —
// confirmado que hasta curl y Postman caen, pero Chrome/Edge normal sí
// pasa. Un cron en GitHub Actions (ver .github/workflows/scrape-inifap.yml
// y scripts/scrape.js) visita la API cada 15 min con Puppeteer (Chrome
// real automatizado) y publica el resultado en data/latest.json de este
// mismo repo. Cuando el dominio nos da 403, en vez de pelear con el WAF
// desde el celular, leemos ese espejo público.
//
// Cubre lo que usa la pantalla principal: reportes r=1,3,4 y tiempo
// real r=5 por estación. Lo que NO está en el espejo (r=6-10, r=all)
// simplemente deja pasar el 403 original — la app ya sabe caer a su
// caché offline en esos casos.
//
// Quitar este parche por completo en cuanto INIFAP confirme que el WAF
// ya no bloquea a la app.
// ─────────────────────────────────────────────
const String _kDomain = 'zacatecas.inifap.gob.mx';
const String _kMirrorUrl =
    'https://raw.githubusercontent.com/JoelSANQ/inifap/notifications/data/latest.json';

/// Cliente HTTP que cae al espejo de GitHub (ver nota del parche arriba)
/// cuando el dominio real responde 403.
class _WafFallbackClient extends http.BaseClient {
  final http.Client _primary = http.Client();
  final http.Client _mirrorClient = http.Client();
  Map<String, dynamic>? _mirrorCache;
  Future<Map<String, dynamic>?>? _mirrorFetch;

  Future<Map<String, dynamic>?> _getMirror() {
    if (_mirrorCache != null) return Future.value(_mirrorCache);
    return _mirrorFetch ??= () async {
      try {
        final res = await _mirrorClient
            .get(Uri.parse(_kMirrorUrl))
            .timeout(const Duration(seconds: 15));
        if (res.statusCode != 200) return null;
        _mirrorCache = jsonDecode(res.body) as Map<String, dynamic>;
        return _mirrorCache;
      } catch (_) {
        return null;
      }
    }();
  }

  /// Busca en el espejo el pedazo que corresponde a este request
  /// (según los mismos parámetros `r` / `id_est_given` que usó la app),
  /// o null si ese endpoint no está cubierto por el espejo.
  dynamic _lookupInMirror(Map<String, dynamic> mirror, Uri url) {
    final r = url.queryParameters['r'];
    if (r == '1' || r == '3' || r == '4') {
      final reports = mirror['reports'];
      if (reports is Map) return reports['r$r'];
      return null;
    }
    if (r == '5') {
      final idEst = url.queryParameters['id_est_given'];
      final realtime = mirror['realtime'];
      if (idEst != null && realtime is Map) return realtime[idEst];
      return null;
    }
    return null; // r=6,7,8,9,10,all: no cubierto por el espejo todavía.
  }

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.host != _kDomain) {
      return _primary.send(request);
    }

    http.StreamedResponse primaryRes;
    try {
      primaryRes = await _primary.send(request);
      if (primaryRes.statusCode != 403) return primaryRes;
    } catch (_) {
      // Sin conexión o timeout: probamos el espejo también.
      primaryRes = http.StreamedResponse(
        const Stream<List<int>>.empty(),
        403,
        request: request,
      );
    }

    final mirror = await _getMirror();
    final match = mirror == null ? null : _lookupInMirror(mirror, request.url);
    if (match == null) {
      return primaryRes; // No cubierto por el espejo: deja pasar el 403 original.
    }

    final bytes = utf8.encode(jsonEncode(match));
    return http.StreamedResponse(
      Stream<List<int>>.value(bytes),
      200,
      request: request,
      headers: const {'content-type': 'application/json'},
    );
  }

  @override
  void close() {
    _primary.close();
    _mirrorClient.close();
    super.close();
  }
}

// Si sigues usando proxy en Web, no pasa nada, esto es solo para app móvil
String _buildUrlR(int r) {
  final upstream = '$_kUpstream?r=$r';
  return upstream; // en móvil puedes ir directo
}

String _buildHistoryUrl({
  required int idEst,
  required int month,
  required int year,
}) {
  final mm = month.toString().padLeft(2, '0');
  final upstream =
      '$_kUpstream?r=10&month=$mm&year=$year&id_est_given=$idEst';
  return upstream;
}

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
  return upstream;
}

class OfflineDataService {
  OfflineDataService._internal();

  static final OfflineDataService instance = OfflineDataService._internal();

  static final http.Client sharedClient = _WafFallbackClient();

  Map<String, dynamic>? _cachedRoot;

  /// Ruta completa del archivo offline en el almacenamiento interno.
  Future<File> _getOfflineFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/offline_data.json');
  }

  /// Carga el JSON offline desde disco (Mobile/Desktop) o SharedPreferences (Web).
  Future<Map<String, dynamic>?> loadOfflineRoot() async {
    if (_cachedRoot != null) return _cachedRoot;

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString('offline_data_json');
      if (jsonStr == null) return null;
      try {
        _cachedRoot = jsonDecode(jsonStr) as Map<String, dynamic>;
        return _cachedRoot;
      } catch (_) {
        return null;
      }
    } else {
      final file = await _getOfflineFile();
      if (!await file.exists()) return null;
      final contents = await file.readAsString();
      try {
        _cachedRoot = jsonDecode(contents) as Map<String, dynamic>;
        return _cachedRoot;
      } catch (_) {
        return null;
      }
    }
  }

  /// Guardar root en disco y cache
  Future<void> _saveOfflineRoot(Map<String, dynamic> root) async {
    _cachedRoot = root;
    final jsonStr = const JsonEncoder.withIndent('  ').convert(root);

    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('offline_data_json', jsonStr);
    } else {
      final file = await _getOfflineFile();
      await file.writeAsString(jsonStr);
    }
  }

  Future<dynamic> _getJson(String url) async {
    // 🐢 Throttle: evita ráfagas que el WAF del servidor marca como "too fast".
    await Future.delayed(const Duration(milliseconds: 300));
    final res = await sharedClient
        .get(Uri.parse(url))
        .timeout(const Duration(seconds: 15)); // ⏱️ evita colgado sin red
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} en $url');
    }
    return jsonDecode(res.body);
  }

  /// 🔥 Llamar esto al abrir la app o al refrescar para intentar sincronizar datos
  Future<void> syncFromNetwork() async {
    try {
      final now = DateTime.now();
      final yyyy = now.year;
      final mm = now.month.toString().padLeft(2, '0');
      final dd = now.day.toString().padLeft(2, '0');

      final monthKey = '$yyyy-$mm';
      final dayKey = '$yyyy-$mm-$dd';

      // 1) Reportes (WeatherDashboard: r=1,3,4)
      final r1 = await _getJson(_buildUrlR(1));
      final r3 = await _getJson(_buildUrlR(3));
      final r4 = await _getJson(_buildUrlR(4));

      // 2) Histórico por estación (r=10) mes actual
      final Map<String, dynamic> history = {};

      for (final st in StationService.instance.stations) {
        final url = _buildHistoryUrl(
          idEst: st.id,
          month: now.month,
          year: now.year,
        );
        try {
          final json = await _getJson(url);
          final idStr = st.id.toString();
          history[idStr] ??= {};
          history[idStr][monthKey] = json;
        } catch (_) {
          // si una estación falla, ignoramos y seguimos
        }
      }

      // 3) Daily extras (r=6 lluvia, 7 hum, 8 rad, 9 viento) para HOY
      final Map<String, dynamic> dailyExtras = {};
      for (final st in StationService.instance.stations) {
        final idStr = st.id.toString();
        try {
          final rain =
              await _getJson(_buildDailyUrl(r: 6, idEst: st.id, day: now));
          final hum =
              await _getJson(_buildDailyUrl(r: 7, idEst: st.id, day: now));
          final rad =
              await _getJson(_buildDailyUrl(r: 8, idEst: st.id, day: now));
          final wind =
              await _getJson(_buildDailyUrl(r: 9, idEst: st.id, day: now));

          dailyExtras[idStr] ??= {};
          dailyExtras[idStr][dayKey] = {
            'r6': rain,
            'r7': hum,
            'r8': rad,
            'r9': wind,
          };
        } catch (_) {
          // ignoramos errores individuales
        }
      }

      // 4) Tiempo real r=5 por estación para HOY
      final Map<String, dynamic> realtime = {};
      for (final st in StationService.instance.stations) {
        final idStr = st.id.toString();
        try {
          final rt =
              await _getJson(_buildDailyUrl(r: 5, idEst: st.id, day: now));
          realtime[idStr] = rt;
        } catch (_) {
          // si falla esa estación, seguimos con las demás
        }
      }

      final root = <String, dynamic>{
        'generated_at': DateTime.now().toIso8601String(),
        'reports': {
          'r1': r1,
          'r3': r3,
          'r4': r4,
        },
        'history': history,
        'daily_extras': dailyExtras,
        // 🔹 Nuevo bloque para tiempo real
        'realtime': realtime,
      };

      await _saveOfflineRoot(root);
      // ignore: avoid_print
      print('✅ OfflineDataService: sincronización completada.');
    } catch (e) {
      // ignore: avoid_print
      print('⚠️ OfflineDataService: error en syncFromNetwork: $e');
      // No lanzamos error, para no tronar la app si no hay internet.
    }
  }

  /// Lee del archivo offline el JSON de tiempo real (r=5) para una estación.
  ///
  /// Devuelve un String con el JSON (lista/objeto), o null si no hay datos.
  Future<String?> getRealtimeJsonForStation(int idEst) async {
    final root = await loadOfflineRoot();
    if (root == null) return null;

    final realtime = root['realtime'];
    if (realtime is! Map) return null;

    final idStr = idEst.toString();
    final data = realtime[idStr];
    if (data == null) return null;

    return jsonEncode(data);
  }

  /// Actualiza el bloque `realtime` para una estación con un body JSON nuevo.
  ///
  /// Esto te permite, desde `_fetch()` en `WeatherProxyPage`,
  /// guardar lo último que bajaste sin esperar al siguiente `syncFromNetwork`.
  Future<void> saveRealtimeJsonForStation(int idEst, String body) async {
    Map<String, dynamic> root =
        await loadOfflineRoot() ?? <String, dynamic>{};

    // Aseguramos estructura mínima si el archivo estaba vacío o no existía
    root['generated_at'] ??= DateTime.now().toIso8601String();
    root['reports'] ??= {};
    root['history'] ??= {};
    root['daily_extras'] ??= {};

    final realtime = (root['realtime'] is Map<String, dynamic>)
        ? root['realtime'] as Map<String, dynamic>
        : <String, dynamic>{};

    final decoded = jsonDecode(body);
    final idStr = idEst.toString();
    realtime[idStr] = decoded;

    root['realtime'] = realtime;

    await _saveOfflineRoot(root);
  }

  /// Guarda el histórico (r=10) de una estación para un mes específico.
  /// Se llama desde station_history.dart después de un fetch online exitoso.
  Future<void> saveHistoryForStation(int idEst, int month, int year, String body) async {
    Map<String, dynamic> root = await loadOfflineRoot() ?? <String, dynamic>{};
    root['generated_at'] ??= DateTime.now().toIso8601String();
    root['reports'] ??= {};
    root['history'] ??= {};
    root['daily_extras'] ??= {};
    root['realtime'] ??= {};

    final history = (root['history'] is Map<String, dynamic>)
        ? root['history'] as Map<String, dynamic>
        : <String, dynamic>{};

    final idStr = idEst.toString();
    history[idStr] ??= <String, dynamic>{};

    final mm = month.toString().padLeft(2, '0');
    final monKey = '$year-$mm';
    history[idStr][monKey] = jsonDecode(body);

    root['history'] = history;
    await _saveOfflineRoot(root);
  }

  /// Guarda datos de reporte (r=1, r=3, r=4) para acceso offline.
  /// Se llama desde report.dart después de un fetch online exitoso.
  Future<void> saveReportData(int r, String body) async {
    Map<String, dynamic> root = await loadOfflineRoot() ?? <String, dynamic>{};
    root['generated_at'] ??= DateTime.now().toIso8601String();
    root['reports'] ??= {};
    root['history'] ??= {};
    root['daily_extras'] ??= {};
    root['realtime'] ??= {};

    final reports = (root['reports'] is Map<String, dynamic>)
        ? root['reports'] as Map<String, dynamic>
        : <String, dynamic>{};

    reports['r$r'] = jsonDecode(body);

    root['reports'] = reports;
    await _saveOfflineRoot(root);
  }

  /// Guarda los daily extras (r6, r7, r8, r9) de una estación para un día.
  /// Se llama desde cards_under_daily_extras.dart después de fetch online exitoso.
  Future<void> saveDailyExtrasForStation(int idEst, DateTime day, Map<String, dynamic> extras) async {
    Map<String, dynamic> root = await loadOfflineRoot() ?? <String, dynamic>{};
    root['generated_at'] ??= DateTime.now().toIso8601String();
    root['reports'] ??= {};
    root['history'] ??= {};
    root['daily_extras'] ??= {};
    root['realtime'] ??= {};

    final dailyExtras = (root['daily_extras'] is Map<String, dynamic>)
        ? root['daily_extras'] as Map<String, dynamic>
        : <String, dynamic>{};

    final idStr = idEst.toString();
    dailyExtras[idStr] ??= <String, dynamic>{};

    final dd = day.day.toString().padLeft(2, '0');
    final mm = day.month.toString().padLeft(2, '0');
    final yyyy = day.year.toString();
    final dayKey = '$yyyy-$mm-$dd';

    dailyExtras[idStr][dayKey] = extras;

    root['daily_extras'] = dailyExtras;
    await _saveOfflineRoot(root);
  }
}
