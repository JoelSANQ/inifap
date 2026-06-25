import 'dart:convert';
import '../bin/generate_offline.dart';
import '../data/Stations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StationService {
  static final StationService instance = StationService._();
  StationService._();

  List<Station> _stations = kStations; // Fallback inicial
  List<Station> get stations => _stations;

  /// Carga la lista de estaciones (r=all)
  /// 1. Primero intenta de SharedPreferences (cache)
  /// 2. Luego intenta del API en background para actualizar
  Future<void> loadStations() async {
    // 1️⃣ Cargar del Caché
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString('stations_cache_r_all');
    if (cached != null) {
      _stations = _parseStations(cached);
    }

    // 2️⃣ Refrescar en Background
    _refreshFromNetwork();
  }

  Future<void> _refreshFromNetwork() async {
    try {
      const url = 'https://zacatecas.inifap.gob.mx/apiApp2.php?r=all';
      // Usamos el cliente compartido para mayor velocidad
      final res = await OfflineDataService.sharedClient.get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));
      
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is List && decoded.isNotEmpty) {
          _stations = _parseStations(res.body);
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('stations_cache_r_all', res.body);
        }
      }
    } catch (e) {
      // Ignorar errores en background, ya tenemos el cache o el fallback
    }
  }

  List<Station> _parseStations(String body) {
    try {
      final List<dynamic> data = jsonDecode(body);
      return data.map((json) {
        return Station(
          int.tryParse(json['IdEstacion']?.toString() ?? '0') ?? 0,
          json['NombreEstacion']?.toString() ?? 'Desconocida',
        );
      }).toList();
    } catch (_) {
      return kStations;
    }
  }

  /// Realiza un pre-fetch de las estaciones favoritas
  Future<void> prefetchFavorites(List<int> favoriteIds) async {
    if (favoriteIds.isEmpty) return;
    
    // Solo pre-fetchear las primeras 5 favoritas para no saturar
    final targets = favoriteIds.take(5);
    
    for (final id in targets) {
      _prefetchStation(id);
    }
  }

  Future<void> _prefetchStation(int idEst) async {
    try {
      final now = DateTime.now();
      final dd = now.day.toString().padLeft(2, '0');
      final mm = now.month.toString().padLeft(2, '0');
      final yyyy = now.year.toString();
      
      final url = 'https://zacatecas.inifap.gob.mx/apiApp2.php?r=5&day=$dd&month=$mm&year=$yyyy&id_est_given=$idEst';
      
      // Fetch silencioso
      final res = await OfflineDataService.sharedClient.get(Uri.parse(url))
          .timeout(const Duration(seconds: 5));
      
      if (res.statusCode == 200) {
        // Guardar en el cache offline
        await OfflineDataService.instance.saveRealtimeJsonForStation(idEst, res.body);
      }
    } catch (_) {}
  }
}
