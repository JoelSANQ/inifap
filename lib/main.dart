import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // 👈 para kIsWeb

import 'bin/generate_offline.dart';
import 'WeatherProxyPage.dart';

// 👇 nuestras funciones de notificación
import 'notifications/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ===========================
  // Inicializar notificaciones y pedir permisos
  // (solo en plataformas nativas, NO en Web)
  // ===========================
  if (!kIsWeb) {
    await initLocalNotifications();
    await solicitarPermisoNotificaciones();
  }

  // ===========================
  // Tu lógica original de sync
  // ===========================
  await OfflineDataService.instance.syncFromNetwork();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WeatherProxyPage(), // 👈 sigue siendo tu pantalla inicial
    );
  }
}
