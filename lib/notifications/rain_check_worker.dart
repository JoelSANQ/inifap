// lib/notifications/rain_check_worker.dart
//
// ============================================================================
// 🔔 NOTIFICACIÓN DE CLIMA EXTREMO Y LLUVIA — WorkManager + Local Notifications
// ============================================================================
//
// ▸ Se ejecuta en segundo plano cada ~15 min (mínimo de Android WorkManager).
// ▸ Internamente usa un cooldown propio de 15 minutos para no repetir antes.
// ▸ Dispara notificación por: Temp (<0 o >38), Viento (>23 km/h) o Lluvia (>=1 mm).
// ▸ NO depende de Firebase — solo WorkManager + flutter_local_notifications.
// ============================================================================

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../bin/generate_offline.dart'; // ✅ OfflineDataService.sharedClient

// ─────────────────────────────────────────────
// Constantes
// ─────────────────────────────────────────────
const String kRainCheckTaskName = 'climaExtremoCheck';
const String kRainCheckTaskTag = 'weatherAlertTag';

/// Endpoint que devuelve TODAS las estaciones con su valor `rainMm`.
const String _kApiAllStations =
    'https://zacatecas.inifap.gob.mx/apiApp2.php?r=all';

// ─────────────────────────────────────────────
// Plugin de notificaciones locales (propio del
// isolate de background — no comparte con main)
// ─────────────────────────────────────────────
final FlutterLocalNotificationsPlugin _localNotifications =
    FlutterLocalNotificationsPlugin();

bool _notifInitialized = false;

/// Canal Android exclusivo para alertas de clima extremo.
const String _channelId = 'extreme_weather_channel';
const String _channelName = 'Alertas de Clima';
const String _channelDesc =
    'Notifica temperaturas extremas o vientos fuertes en favoritos';

/// Inicializa el plugin de notificaciones locales dentro del isolate de
/// background. Es seguro llamarlo varias veces.
Future<void> _initNotifications() async {
  if (_notifInitialized) return;

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(android: androidInit);

  await _localNotifications.initialize(initSettings);

  // Crear canal en Android (requiere API 26+).
  final androidPlugin =
      _localNotifications.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
  await androidPlugin?.createNotificationChannel(
    const AndroidNotificationChannel(
      _channelId,
      _channelName,
      description: _channelDesc,
      importance: Importance.high,
    ),
  );

  _notifInitialized = true;
}

/// Muestra una notificación local inmediata.
Future<void> _showNotification({
  required int id,
  required String title,
  required String body,
}) async {
  await _localNotifications.show(
    id,
    title,
    body,
    const NotificationDetails(
      android: AndroidNotificationDetails(
        _channelId,
        _channelName,
        channelDescription: _channelDesc,
        importance: Importance.high,
        priority: Priority.high,
        icon: '@mipmap/ic_launcher',
      ),
    ),
  );
}

// ─────────────────────────────────────────────
// 🔧  handleRainZeroCheck  —  Lógica de chequeo
//     de precipitación == 0 (llamada desde el
//     dispatcher compartido en background_worker)
// ─────────────────────────────────────────────

/// Función pública que ejecuta el chequeo de clima extremo.
/// Se llama desde [callbackDispatcher] en `background_worker.dart`.
///
/// Estrategia ONLINE-FIRST con fallback OFFLINE:
///   1) Intenta r=all (todas las estaciones, datos frescos).
///   2) Si no hay red / falla, usa el cache offline (r=5 por estación)
///      guardado en `offline_data.json`. Así las notificaciones siguen
///      evaluándose aunque el dispositivo esté sin internet.
Future<void> handleExtremeWeatherCheck() async {
  try {
    // 1) Iniciar plugin de notificaciones locales
    await _initNotifications();

    // 2) Leer estaciones favoritas de SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final favoriteIds =
        prefs.getStringList('favorite_station_ids') ?? <String>[];

    if (favoriteIds.isEmpty) {
      debugPrint('⚠️ [WeatherCheck] No hay estaciones favoritas — se omite.');
      return;
    }

    // 3) Intentar datos ONLINE (r=all)
    List<dynamic>? stations;
    try {
      final response = await OfflineDataService.sharedClient
          .get(Uri.parse(_kApiAllStations))
          .timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded is List) stations = decoded;
      } else {
        debugPrint('⚠️ [WeatherCheck] API respondió ${response.statusCode}.');
      }
    } catch (e) {
      debugPrint('📴 [WeatherCheck] Sin red ($e) — uso cache offline.');
    }

    if (stations != null) {
      // ── PATH ONLINE: recorrer todas las estaciones del r=all ──
      for (final s in stations) {
        if (s is! Map) continue;
        final id = (s['idEst'] ?? '').toString();
        if (!favoriteIds.contains(id)) continue;

        final tempVal = s['tempC'] ?? s['temp'] ?? s['tc'];
        final temp = double.tryParse((tempVal ?? '—').toString()) ?? 999.0;

        final windVal = s['velViento'] ?? s['viento'] ?? s['vv'];
        final wind = double.tryParse((windVal ?? '0').toString()) ?? 0.0;

        final rainVal =
            s['lluvia'] ?? s['rainMm'] ?? s['precip'] ?? s['pp'] ?? '0';
        final rain = double.tryParse(rainVal.toString()) ?? 0.0;

        final name = (s['nombre'] ?? 'Estación $id').toString();

        await _checkAndNotify(
          prefs: prefs,
          id: id,
          name: name,
          temp: temp,
          wind: wind,
          rain: rain,
        );
      }
    } else {
      // ── PATH OFFLINE: usar cache (r=5 por estación favorita) ──
      for (final id in favoriteIds) {
        final idInt = int.tryParse(id);
        if (idInt == null) continue;

        final json =
            await OfflineDataService.instance.getRealtimeJsonForStation(idInt);
        if (json == null) continue;

        final parsed = _parseOfflineRealtime(json, fallbackId: id);
        if (parsed == null) continue;

        await _checkAndNotify(
          prefs: prefs,
          id: id,
          name: parsed.name,
          temp: parsed.temp,
          wind: parsed.wind, // r=5 no trae viento → 0 (condición se omite)
          rain: parsed.rain,
        );
      }
    }
  } catch (e, stack) {
    debugPrint('❌ [WeatherCheck] Error en tarea background: $e\n$stack');
  }
}

/// Evalúa las 3 condiciones (temp / viento / lluvia) para una estación y
/// dispara notificación si corresponde, respetando el cooldown de 15 min.
Future<void> _checkAndNotify({
  required SharedPreferences prefs,
  required String id,
  required String name,
  required double temp,
  required double wind,
  required double rain,
}) async {
  final now = DateTime.now().millisecondsSinceEpoch;
  final nowDt = DateTime.now();
  final hora =
      '${nowDt.hour.toString().padLeft(2, '0')}:${nowDt.minute.toString().padLeft(2, '0')}';
  const cooldown = 15 * 60 * 1000;

  // --- 🌡️ TEMPERATURA (< 0 o > 38) ---
  if (temp != 999.0 && (temp < 0 || temp > 38)) {
    final key = 'extreme_temp_notif_$id';
    if (now - (prefs.getInt(key) ?? 0) > cooldown) {
      await prefs.setInt(key, now);
      await _showNotification(
        id: id.hashCode + 1,
        title: temp < 0 ? '❄️ Temperatura Helada' : '🔥 Temperatura Muy Caliente',
        body: '$name: ${temp.toStringAsFixed(1)}°C detectada a las $hora',
      );
    }
  }

  // --- 💨 VIENTO (> 23) ---
  if (wind > 23) {
    final key = 'high_wind_notif_$id';
    if (now - (prefs.getInt(key) ?? 0) > cooldown) {
      await prefs.setInt(key, now);
      await _showNotification(
        id: id.hashCode + 2,
        title: '🌬️ Vientos Fuertes',
        body: '$name: ${wind.toStringAsFixed(1)} km/h detectados a las $hora',
      );
    }
  }

  // --- 🌧️ LLUVIA (>= 1.0 mm) ---
  if (rain >= 1.0) {
    final key = 'rain_notif_$id';
    if (now - (prefs.getInt(key) ?? 0) > cooldown) {
      await prefs.setInt(key, now);
      await _showNotification(
        id: id.hashCode + 3,
        title: '🌧️ Está lloviendo',
        body: '$name: Se detectan ${rain.toStringAsFixed(1)} mm a las $hora',
      );
    }
  }
}

/// Datos mínimos extraídos del cache offline (r=5) de una estación.
class _OfflineReading {
  final String name;
  final double temp;
  final double wind;
  final double rain;
  _OfflineReading(this.name, this.temp, this.wind, this.rain);
}

/// Parsea el JSON r=5 guardado offline y devuelve la lectura más reciente
/// (último registro horario con temperatura válida).
///
/// Estructura esperada (igual que en WeatherProxyPage):
///   [ { "Est": "...", "Datos": [ { "Hora": "..", "Temp": "..", "Prec": ".." }, ... ] } ]
_OfflineReading? _parseOfflineRealtime(String json, {required String fallbackId}) {
  try {
    final root = jsonDecode(json);

    Map<String, dynamic>? obj;
    if (root is List && root.isNotEmpty && root.first is Map) {
      obj = Map<String, dynamic>.from(root.first as Map);
    } else if (root is Map) {
      obj = Map<String, dynamic>.from(root);
    }
    if (obj == null) return null;

    final name = (obj['Est'] ??
            obj['est'] ??
            obj['nombre'] ??
            obj['estacion'] ??
            'Estación $fallbackId')
        .toString();

    // Buscar la lista de registros horarios
    List horas = const [];
    for (final k in ['Datos', 'datos', 'data', 'values', 'horas']) {
      final v = obj[k];
      if (v is List) {
        horas = v;
        break;
      }
    }
    if (horas.isEmpty) return null;

    // Recorrer de atrás hacia adelante: tomar el registro más reciente válido
    for (var i = horas.length - 1; i >= 0; i--) {
      final h = horas[i];
      if (h is! Map) continue;
      final mm = Map<String, dynamic>.from(h);

      final tempVal = mm['Temp'] ?? mm['temp'] ?? mm['T'] ?? mm['temperatura'];
      final temp = double.tryParse((tempVal ?? '').toString().replaceAll(',', '.'));
      if (temp == null) continue; // saltar horas vacías

      final rainVal = mm['Prec'] ?? mm['prec'] ?? mm['lluvia'] ?? mm['rain'];
      final rain =
          double.tryParse((rainVal ?? '0').toString().replaceAll(',', '.')) ?? 0.0;

      return _OfflineReading(name, temp, 0.0, rain);
    }
  } catch (_) {}
  return null;
}

// ─────────────────────────────────────────────
// 🚀  Funciones públicas para registrar / cancelar
//     la tarea desde main.dart
// ─────────────────────────────────────────────

/// Inicializa WorkManager con [rainCheckCallbackDispatcher] y registra la
/// tarea periódica.
///
/// **Nota sobre la frecuencia:**
/// Android WorkManager impone un mínimo de 15 minutos para tareas periódicas.
/// Sin embargo, el cooldown interno de 5 minutos asegura que si la tarea se
/// ejecuta antes (en modo debug o por el SO), no se repita la notificación
/// antes de 5 minutos.
Future<void> initRainCheckWorker() async {
  // ⚠️ NO llamamos Workmanager().initialize() aquí porque ya se
  //    inicializó en main.dart con el dispatcher compartido.
  //    Solo registramos la tarea periódica.

  await Workmanager().registerPeriodicTask(
    'rain_zero_periodic', // ID único de la tarea
    kRainCheckTaskName, // Nombre que recibe el dispatcher
    frequency: const Duration(minutes: 15), // mínimo Android = 15 min
    initialDelay: const Duration(seconds: 10), // demora inicial
    constraints: Constraints(
      networkType: NetworkType.not_required, // ✅ corre aunque NO haya internet (usa cache offline)
    ),
    existingWorkPolicy: ExistingWorkPolicy.replace, // reemplaza si ya existe
    tag: kRainCheckTaskTag,
  );

  debugPrint(
    '✅ [RainCheck] Tarea periódica registrada — '
    'chequeo cada ~15 min (cooldown interno: 5 min).',
  );
}

/// Cancela la tarea periódica de chequeo de lluvia.
Future<void> cancelRainCheckWorker() async {
  await Workmanager().cancelByTag(kRainCheckTaskTag);
  debugPrint('🛑 [RainCheck] Tarea periódica cancelada.');
}
