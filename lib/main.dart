import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 👈 para kIsWeb

import 'bin/generate_offline.dart';
import 'WeatherProxyPage.dart';
import 'notifications/notification_service.dart';
import 'notifications/background_worker.dart'; // ✅ Workmanager (original)
import 'notifications/rain_check_worker.dart'; // ✅ Precipitación cero
// 👇 funciones de notificación
import 'notifications/permission_handler.dart';
// ✅ FCM (Firebase Cloud Messaging)
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'package:workmanager/workmanager.dart'; // ✅ Workmanager


// ✅ Handler para mensajes en segundo plano (FCM)
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ AGREGADO: inicializa notificaciones locales en background isolate
  await NotificationService.init();

  // ✅ AGREGADO: title/body desde notification o data
  final title =
      message.notification?.title ?? message.data['title'] ?? 'Clima INIFAP';
  final body =
      message.notification?.body ?? message.data['body'] ?? 'Nueva alerta.';

  // ✅ AGREGADO: mostrar notificación inmediata
  await NotificationService.showNow(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: title,
    body: body,
    payload: message.data.isNotEmpty ? message.data.toString() : null,
  );
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ La app arranca INMEDIATO: pintamos la UI antes de tocar
  // Firebase/red/notificaciones, para que un colgón ahí nunca
  // deje la pantalla en negro.
  runApp(const MyApp());

  // El resto se inicializa en background, cada paso aislado:
  // si uno falla o se cuelga, los demás igual se ejecutan.
  _initBackground();
}

/// Corre cada paso de arranque por separado con try/catch + timeout,
/// del más confiable al más propenso a fallar (red/Google al final),
/// para que un solo paso roto nunca bloquee ni tumbe los demás.
Future<void> _initBackground() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
  } catch (e) {
    debugPrint('⚠️ Firebase.initializeApp falló: $e');
  }

  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    debugPrint('⚠️ onBackgroundMessage falló: $e');
  }

  if (kIsWeb) return;

  try {
    await initLocalNotifications();
  } catch (e) {
    debugPrint('⚠️ initLocalNotifications falló: $e');
  }

  try {
    await solicitarPermisoNotificaciones();
  } catch (e) {
    debugPrint('⚠️ solicitarPermisoNotificaciones falló: $e');
  }

  try {
    await NotificationService.init();
  } catch (e) {
    debugPrint('⚠️ NotificationService.init falló: $e');
  }

  try {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      final title =
          message.notification?.title ?? message.data['title'] ?? 'Clima INIFAP';
      final body =
          message.notification?.body ?? message.data['body'] ?? 'Nueva alerta.';

      await NotificationService.showNow(
        id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        title: title,
        body: body,
        payload: message.data.isNotEmpty ? message.data.toString() : null,
      );
    });
  } catch (e) {
    debugPrint('⚠️ onMessage.listen falló: $e');
  }

  // Lanzamos el sync en SEGUNDO PLANO, sin esperar a nada más.
  OfflineDataService.instance.syncFromNetwork();

  // ⬇️ Lo más propenso a colgarse (Workmanager nativo, y sobre todo
  // getToken() que pega a servidores de Google) va al final, con
  // timeout, para que nunca detenga lo de arriba.
  try {
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, // ✅ Producción (cambiar a true solo para depurar)
    ).timeout(const Duration(seconds: 10));

    // ✅ Tarea periódica única: chequeo clima extremo cada ~15 min
    await initRainCheckWorker();
  } catch (e) {
    debugPrint('⚠️ Workmanager/initRainCheckWorker falló: $e');
  }

  try {
    final token = await FirebaseMessaging.instance
        .getToken()
        .timeout(const Duration(seconds: 10));
    debugPrint('🔥 FCM Token: $token');
  } catch (e) {
    debugPrint('⚠️ getToken falló: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WeatherProxyPage(key: ValueKey('main_page')),
    );
  }
}
