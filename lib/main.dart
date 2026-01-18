import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 👈 para kIsWeb

import 'bin/generate_offline.dart';
import 'WeatherProxyPage.dart';
import 'notifications/notification_service.dart';
// 👇 funciones de notificación
import 'notifications/permission_handler.dart';

///  inicialización para NOTIFICACIONES PROGRAMADAS (zonedSchedule)


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ===========================
  // Inicializar notificaciones
  // ===========================
  if (!kIsWeb) {
    await initLocalNotifications();
    await solicitarPermisoNotificaciones();

    // ✅ AGREGADO: requerido para notificaciones programadas por TIEMPO
    await NotificationService.init();
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
      home: WeatherProxyPage(),
    );
  }
}
