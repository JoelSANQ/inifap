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

  // ✅ Inicializar Firebase (necesario para FCM)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // ✅ Registrar handler de FCM en segundo plano
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ===========================
  // Inicializar notificaciones
  // ===========================
  if (!kIsWeb) {
    // ✅ (se deja igual como lo tenías)
    await initLocalNotifications();
    await solicitarPermisoNotificaciones();

    // ✅ WORKMANAGER: Inicializar dispatcher compartido
    await Workmanager().initialize(
      callbackDispatcher,
      isInDebugMode: false, // ✅ Producción (cambiar a true solo para depurar)
    );
    
    // ✅ Tarea periódica #1: chequeo clima extremo cada 15 min
    await Workmanager().registerPeriodicTask(
      'weather_check_periodic',
      'checkRainTask',
      frequency: const Duration(minutes: 15),
      constraints: Constraints(
        networkType: NetworkType.connected,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );
    debugPrint('✅ Workmanager: tarea periódica registrada (clima extremo cada ~15 min)');

    // ✅ Tarea periódica #2: segundo chequeo (misma lógica, redundancia)
    await initRainCheckWorker();

    // ✅ Obtener token FCM (para enviarlo a tu servidor y poder mandar push)
    final token = await FirebaseMessaging.instance.getToken();
    debugPrint('🔥 FCM Token: $token');

    // ✅ AGREGADO: requerido para notificaciones programadas por TIEMPO
    await NotificationService.init();

    // ✅ AGREGADO: listener cuando la app está ABIERTA (foreground)
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

    // Lanzamos el sync en SEGUNDO PLANO
    // SIN bloquear el arranque de la app
    OfflineDataService.instance.syncFromNetwork();
  }

  // ✅ La app arranca INMEDIATO
  runApp(const MyApp());
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
