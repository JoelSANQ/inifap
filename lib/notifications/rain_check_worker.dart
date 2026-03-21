// lib/notifications/rain_check_worker.dart
//
// ============================================================================
// 🔔 NOTIFICACIÓN DE PRECIPITACIÓN CERO — WorkManager + Local Notifications
// ============================================================================
//
// ▸ Se ejecuta en segundo plano cada ~15 min (mínimo de Android WorkManager).
// ▸ Internamente usa un cooldown propio de 5 minutos para no repetir antes.
// ▸ Dispara notificación cuando la precipitación de una estación favorita == 0.
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
const String kRainCheckTaskName = 'precipitacionCeroCheck';
const String kRainCheckTaskTag = 'rainZeroTag';

/// Endpoint que devuelve TODAS las estaciones con su valor `rainMm`.
const String _kApiAllStations =
    'http://zacatecas.inifap.gob.mx/apiApp2.php?r=all';

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

    // 3) Pedir datos al API
    final response = await OfflineDataService.sharedClient
        .get(Uri.parse(_kApiAllStations))
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      debugPrint(
          '⚠️ [WeatherCheck] API respondió ${response.statusCode} — se omite.');
      return;
    }

    final List<dynamic> stations = jsonDecode(response.body);

    for (final s in stations) {
      final id = (s['idEst'] ?? '').toString();
      if (!favoriteIds.contains(id)) continue;

      // --- 🔍 EXTRACCIÓN DE DATOS ---
      final tempVal = s['tempC'] ?? s['temp'] ?? s['tc'];
      final temp = double.tryParse((tempVal ?? '—').toString()) ?? 999.0;

      final windVal = s['velViento'] ?? s['viento'] ?? s['vv'];
      final wind = double.tryParse((windVal ?? '0').toString()) ?? 0.0;

      final name = (s['nombre'] ?? 'Estación $id').toString();
      final now = DateTime.now().millisecondsSinceEpoch;
      final nowDt = DateTime.now();
      final hora = '${nowDt.hour.toString().padLeft(2, '0')}:${nowDt.minute.toString().padLeft(2, '0')}';

      // --- 🌡️ CONDICIÓN TEMPERATURA (< 0 o > 38) ---
      if (temp != 999.0 && (temp < 0 || temp > 38)) {
        final lastKeyT = 'extreme_temp_notif_$id';
        final lastT = prefs.getInt(lastKeyT) ?? 0;
        const cooldownT = 15 * 60 * 1000;

        if (now - lastT > cooldownT) {
          await prefs.setInt(lastKeyT, now);
          await _showNotification(
            id: id.hashCode + 1,
            title: temp < 0 ? '❄️ Temperatura Helada' : '🔥 Temperatura Muy Caliente',
            body: '$name: ${temp.toStringAsFixed(1)}°C detectada a las $hora',
          );
        }
      }

      // --- 💨 CONDICIÓN VIENTO (> 23) ---
      if (wind > 23) {
        final lastKeyW = 'high_wind_notif_$id';
        final lastW = prefs.getInt(lastKeyW) ?? 0;
        const cooldownW = 15 * 60 * 1000;

        if (now - lastW > cooldownW) {
          await prefs.setInt(lastKeyW, now);
          await _showNotification(
            id: id.hashCode + 2,
            title: '🌬️ Vientos Fuertes',
            body: '$name: ${wind.toStringAsFixed(1)} km/h detectados a las $hora',
          );
        }
      }
    }
  } catch (e, stack) {
    debugPrint('❌ [WeatherCheck] Error en tarea background: $e\n$stack');
  }
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
      networkType: NetworkType.connected, // solo con internet
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
