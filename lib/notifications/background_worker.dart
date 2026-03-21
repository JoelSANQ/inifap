import 'package:workmanager/workmanager.dart';
import 'rain_check_worker.dart'; // ✅ para reutilizar kRainCheckTaskName y lógica de precipitación cero

// ✅ Entry point del isolate de background (COMPARTIDO por todas las tareas)
@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    // ──────────────────────────────────────────────
    // 🔔 AMBAS TAREAS (comparten la misma lógica)
    // ──────────────────────────────────────────────
    if (task == 'checkRainTask' || task == kRainCheckTaskName) {
      await handleExtremeWeatherCheck();
      return true;
    }

    return true;
  });
}
