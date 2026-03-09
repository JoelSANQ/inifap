import 'dart:convert';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

import 'notification_service.dart';

// ✅ Entry point del isolate de background
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // ✅ Solo ejecutar si es nuestra tarea
    if (task != 'checkRainTask') return true;

    await NotificationService.init();

    final prefs = await SharedPreferences.getInstance();
    final selected3 = prefs.getStringList('favorite_station_ids') ?? [];

    // ✅ Si no hay EXACTAMENTE 3 seleccionadas, no hagas nada
    if (selected3.length != 3) return true;
    else { (selected3.length == 2) ? print('⚠️ No hay exactamente 3 estaciones seleccionadas.') : print('✅ 3 estaciones seleccionadas: $selected3');
    }

    // ✅ 1) pedir datos al API (ajusta tu endpoint real)
    final url = Uri.parse('http://zacatecas.inifap.gob.mx/apiApp2.php?r=all');
    final res = await http.get(url);

    if (res.statusCode != 200) return true;

    final data = jsonDecode(res.body);

    // ✅ 2) Condición (ejemplo lluvia)
    const threshold = 0.0;

    for (final s in data) {
      final id = (s['idEst'] ?? '').toString();     // AJUSTA si cambia
      if (!selected3.contains(id)) continue;

      final rainMm = double.tryParse((s['rainMm'] ?? '0').toString()) ?? 0.0; // AJUSTA si cambia
      if (rainMm >= threshold) {
        // ✅ cooldown para no spamear (2 minutos)
        final now = DateTime.now().millisecondsSinceEpoch;
        final lastKey = 'last_rain_alert_$id';
        final last = prefs.getInt(lastKey) ?? 0;
        const cooldownMs = 2 * 60 * 1000; // 2 minutos

        if (now - last < cooldownMs) return true;

        await prefs.setInt(lastKey, now);

        final name = (s['nombre'] ?? 'Estación $id').toString(); // AJUSTA si cambia

        await NotificationService.showNow(
          id: now ~/ 1000,
          title: '🌧️ Alerta de lluvia',
          body: '$name: ${rainMm.toStringAsFixed(1)} mm (≥ $threshold)',
          payload: id,
        );
        break;
      }
    }

    return true;
  });
}
