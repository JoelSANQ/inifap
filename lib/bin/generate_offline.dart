import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../data/Stations.dart';

const String _kUpstream = 'http://zacatecas.inifap.gob.mx/apiApp2.php';

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

  Map<String, dynamic>? _cachedRoot;

  /// Ruta completa del archivo offline en el almacenamiento interno.
  Future<File> _getOfflineFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/offline_data.json');
  }

  /// Carga el JSON offline desde disco (si existe) y lo deja en memoria.
  Future<Map<String, dynamic>?> loadOfflineRoot() async {
    if (_cachedRoot != null) return _cachedRoot;

    final file = await _getOfflineFile();
    if (!await file.exists()) return null;

    final contents = await file.readAsString();
    _cachedRoot = jsonDecode(contents) as Map<String, dynamic>;
    return _cachedRoot;
  }

  /// Guardar root en disco y cache
  Future<void> _saveOfflineRoot(Map<String, dynamic> root) async {
    final file = await _getOfflineFile();
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(root),
    );
    _cachedRoot = root;
  }

  Future<dynamic> _getJson(String url) async {
    final res = await http.get(Uri.parse(url));
    if (res.statusCode != 200) {
      throw Exception('HTTP ${res.statusCode} en $url');
    }
    return jsonDecode(res.body);
  }

  /// 🔥 Llamar esto al abrir la app para intentar sincronizar datos
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

      for (final st in kStations) {
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
      for (final st in kStations) {
        final idStr = st.id.toString();
        try {
          final rain = await _getJson(
              _buildDailyUrl(r: 6, idEst: st.id, day: now));
          final hum = await _getJson(
              _buildDailyUrl(r: 7, idEst: st.id, day: now));
          final rad = await _getJson(
              _buildDailyUrl(r: 8, idEst: st.id, day: now));
          final wind = await _getJson(
              _buildDailyUrl(r: 9, idEst: st.id, day: now));

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

      final root = <String, dynamic>{
        'generated_at': DateTime.now().toIso8601String(),
        'reports': {
          'r1': r1,
          'r3': r3,
          'r4': r4,
        },
        'history': history,
        'daily_extras': dailyExtras,
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
}
