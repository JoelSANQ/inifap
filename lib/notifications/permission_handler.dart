import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Plugin global de notificaciones
final FlutterLocalNotificationsPlugin notifications =
    FlutterLocalNotificationsPlugin();

/// Inicializa las notificaciones (SOLO en Android / iOS / desktop, NO web)
Future<void> initLocalNotifications() async {
  if (kIsWeb) return; // En web no hace nada

  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const initSettings = InitializationSettings(
    android: androidInit,
  );

  await notifications.initialize(initSettings);
}

/// Pide el permiso de notificaciones (Android 13+)
Future<void> solicitarPermisoNotificaciones() async {
  if (kIsWeb) return; // En web no pide permisos

  final status = await Permission.notification.request();
  // Solo para debug
  // ignore: avoid_print
  print('Permiso notificación: $status');
}

/// Función utilitaria para mostrar una notificación simple
Future<void> mostrarNotificacionSimple({
  required String titulo,
  required String cuerpo,
}) async {
  if (kIsWeb) return; // En web no hay notificaciones locales

  const androidDetails = AndroidNotificationDetails(
    'canal_principal',     // ID del canal
    'Notificaciones App',  // Nombre del canal
    channelDescription: 'Canal de notificaciones generales',
    importance: Importance.max,
    priority: Priority.high,
  );

  const general = NotificationDetails(android: androidDetails);

  await notifications.show(
    0,        // id de la notificación
    titulo,
    cuerpo,
    general,
  );
}
