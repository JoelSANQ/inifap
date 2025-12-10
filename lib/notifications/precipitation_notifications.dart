// precipitation_notifications.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // kIsWeb
import 'permission_handler.dart';        // para mostrarNotificacionSimple()

/// ============================================================================
/// 🟦 SISTEMA DE NOTIFICACIONES DE LLUVIA
/// ============================================================================

double? _ultimaLluviaNotificada;

/// Checa la lluvia actual y muestra notificación en móvil
/// o SnackBar en web.
void checarLluviaWebYMovil({
  required BuildContext context,
  required double? lluviaActualMm,
}) {
  // DEBUG
  // ignore: avoid_print
  print('💧 checarLluviaWebYMovil -> lluviaActualMm = $lluviaActualMm');

  // 1) Si no hay valor, salimos
  if (lluviaActualMm == null) {
    print('💧 No hay valor de lluvia, no mostramos nada');
    return;
  }

  // 2) Evitar spamear la misma notificación
  if (_ultimaLluviaNotificada == lluviaActualMm) {
    print('🔁 Mismo valor de lluvia que antes, no repetimos notificación');
    return;
  }
  _ultimaLluviaNotificada = lluviaActualMm;

  // 3) Construimos título y cuerpo
  late final String titulo;
  late final String cuerpo;

  if (lluviaActualMm > 0.0) {
    titulo = '🌧️ Está lloviendo ahora';
    cuerpo = 'Intensidad actual: ${lluviaActualMm.toStringAsFixed(1)} mm.';
  } else if (lluviaActualMm == 0.0) {
    titulo = 'No hay lluvia';
    cuerpo =
        'El valor de lluvia actual es: ${lluviaActualMm.toStringAsFixed(1)} mm.';
  } else {
    // por si algún día llega un valor negativo
    titulo = '☀️ No está lloviendo';
    cuerpo =
        'La lluvia actual es de ${lluviaActualMm.toStringAsFixed(1)} mm.';
  }

  // 4) Según la plataforma, mostramos SnackBar (web) o notificación local (móvil)
  if (kIsWeb) {
    print('🌐 Mostrando SnackBar en Web');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          cuerpo,
          style: const TextStyle(fontSize: 16),
        ),
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  } else {
    print('📱 Mostrando notificación local en móvil');
    mostrarNotificacionSimple(titulo: titulo, cuerpo: cuerpo);
  }
}
