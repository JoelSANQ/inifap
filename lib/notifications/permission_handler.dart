import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

// ✅ IMPORTA tu NotificationService
import 'notification_service.dart';

/// ✅ Inicializa notificaciones locales (sin cambiar tu main.dart)
Future<void> initLocalNotifications() async {
  if (kIsWeb) return;
  await NotificationService.init();
}

/// Pide el permiso de notificaciones (Android 13+)
Future<void> solicitarPermisoNotificaciones() async {
  if (kIsWeb) return;

  final status = await Permission.notification.request();
  // ignore: avoid_print
  print('Permiso notificación: $status');
}
