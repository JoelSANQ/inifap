import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Para kIsWeb
import 'permission_handler.dart';    

    // Para mostrarNotificacionSimple()

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
  // DEBUG: ver qué llega
  // ignore: avoid_print
  print('💧 checarLluviaWebYMovil -> lluviaActualMm = $lluviaActualMm');
  if (lluviaActualMm == null) {
    print('💧 No hay valor de lluvia, no mostramos nada');
    return;
  }
  if (_ultimaLluviaNotificada == lluviaActualMm) {
    print('🔁 Mismo valor de lluvia que antes, no repetimos notificación');
    return;
  }

  _ultimaLluviaNotificada = lluviaActualMm;


  late final String titulo;
  late final String cuerpo;

  if (lluviaActualMm > 0.0) {
    titulo = '🌧️ Está lloviendo ahora';
    cuerpo =
        'Intensidad actual: ${lluviaActualMm.toStringAsFixed(1)} mm.';
  } else 
  
  {
    if (lluviaActualMm == 0.0) {
      titulo = 'No hay lluvia';
      cuerpo = 'El valor de lluvia actual es : ${lluviaActualMm.toStringAsFixed(1)} mm.';
    } else
  {
    titulo = '☀️ No está lloviendo';
    cuerpo =
        'La lluvia actual es de ${lluviaActualMm.toStringAsFixed(1)} mm.';
  }


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
    return;
  }
  }
}

/// ============================================================================
/// 🟦 SISTEMA DE NOTIFICACIONES DE LLUVIA
/// ============================================================================