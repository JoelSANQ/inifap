import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 👈 para kIsWeb

import 'bin/generate_offline.dart';
import 'WeatherProxyPage.dart';

// 👇 funciones de notificación
import 'notifications/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ===========================
  // Inicializar notificaciones
  // ===========================
  if (!kIsWeb) {
    await initLocalNotifications();
    await solicitarPermisoNotificaciones();

    // ✅ MUY IMPORTANTE:
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
