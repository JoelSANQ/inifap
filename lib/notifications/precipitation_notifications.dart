import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'notification_service.dart';       // 👈 nuestro servicio
                                          
/// ============================================================================
/// 🟦 SISTEMA DE NOTIFICACIONES DE LLUVIA
/// ============================================================================

double? _ultimaLluviaNotificada;

void checarLluviaWebYMovil({
  required BuildContext context,
  required double? lluviaActualMm,
}) {

  // 1) Si no hay valor, salimos
  if (lluviaActualMm == null) {
    debugPrint('💧 No hay valor de lluvia, no mostramos nada');
    return;
  }

  // 2) Evitar spamear
  if (_ultimaLluviaNotificada == lluviaActualMm) {
    debugPrint('🔁 Mismo valor de lluvia que antes, no repetimos notificación');
    return;
  }
  _ultimaLluviaNotificada = lluviaActualMm;

  // 3) Construimos título y cuerpo
  late final String titulo;
  late final String cuerpo;

  if (lluviaActualMm > 0.0) {
    titulo = '🌧️ Está lloviendo ahora';
    cuerpo = 'Intensidad actual: ${lluviaActualMm.toStringAsFixed(1)} mm.';
  } else {
    titulo = '☀️ Sin lluvia';
    cuerpo = 'Actualmente no se detecta precipitación.';
  }

  // 4) Mostrar notificación
  _mostrarNotificacion(
    title: titulo,
    body: cuerpo,
  );
}

/// ============================================================================
/// 🔔 NOTIFICACIÓN PROGRAMADA (FUNCIONA EN BACKGROUND)
/// ============================================================================

Future<void> _mostrarNotificacion({
  required String title,
  required String body,
}) async {

  // 🌐 Web no soporta notificaciones locales
  if (kIsWeb) {
    debugPrint('⚠️ Web: notificaciones locales no soportadas');
    return;
  }

  // ⏰ Se programa 5 segundos después
  final fecha = DateTime.now().add(
    const Duration(seconds: 5),
  );

  await NotificationService.showScheduled(
    title: title,
    body: body,
    date: fecha,
  );
}