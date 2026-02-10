import 'dart:convert';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;



import 'notification_service.dart';

// ✅ MUY IMPORTANTE: entry-point para background isolate
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
  
    // 2) Inicializa notificaciones locales (tu service)
    await NotificationService.init();

    // 3) Lee favoritos (ajusta a tu key real)
    final prefs = await SharedPreferences.getInstance();
    final favIds = prefs.getStringList('favorite_station_ids') ?? [];

    // Si no hay favoritos, no hacemos nada
    if (favIds.isEmpty) return true;

    // 4) Pegarle a tu API (AJUSTA URL a tu proxy/upstream real)
    // Ejemplo: descarga todo o por estación (depende tu API)
    final url = Uri.parse('http://zacatecas.inifap.gob.mx/apiApp2.php?r=all');
    final res = await http.get(url);

    if (res.statusCode != 200) return true;

    final data = jsonDecode(res.body);

    // 5) Evaluar condición (ejemplo lluvia)
    // ⚠️ Ajusta a la estructura real de tu JSON
    // Imagina data = [{idEst: "101", rainMm: 12.3, nombre: "X"}, ...]

    //valor de lluvia mínimo para notificar (ajusta según tu necesidad)
    const threshold = 1.0;

    for (final s in data) {
      final id = (s['idEst'] ?? '').toString();
      if (!favIds.contains(id)) continue;

      final rainMm = double.tryParse((s['rainMm'] ?? '0').toString()) ?? 0.0;
      if (rainMm >= threshold) {
        final nombre = (s['nombre'] ?? 'Estación $id').toString();

        await NotificationService.showNow(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          title: '🌧️ Lluvia detectada',
          body: '$nombre: ${rainMm.toStringAsFixed(1)} mm (≥ $threshold)',
          payload: '{"stationId":"$id","rainMm":"$rainMm"}',
        );

        // ✅ opcional: break para no spamear muchas notificaciones
        break;
      }
    }

    return true;
  });
}
