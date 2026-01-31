// lib/widgets/maps.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/Stations.dart';
import '../data/lat_and_long_cords.dart';

// ⚠️ Ajusta esta ruta a donde tengas los helpers reales.
// Debe exportar: addFavoriteStation, removeFavoriteStation, favoritesVersion, kFavPrefsKey
import 'package:clima/widgets/favorite_stations.dart'
    show addFavoriteStation, removeFavoriteStation, favoritesVersion, kFavPrefsKey;

/// Mapa OSM con favoritos sincronizados con SharedPreferences:
/// - Visual: marcador dorado si es favorito
/// - Popup: Agregar / Quitar
/// - Regla: EN EL MAPA solo puedes tener EXACTAMENTE 3 (máximo 3)
class OSMMap extends StatefulWidget {
  const OSMMap({
    super.key,
    this.initialCenter = const LatLng(23.216944, -103.036111),
    this.initialZoom = 9.0,
  });

  final LatLng initialCenter;
  final double initialZoom;

  @override
  State<OSMMap> createState() => _OSMMapState();
}

enum _BaseMap { cartoLight, osm, esriStreet, cartoDark, esriSatellite, esriTopo }

class _OSMMapState extends State<OSMMap> {
  late final MapController _map;
  _BaseMap _currentBase = _BaseMap.cartoLight;

  // ✅ favoritos cacheados para pintar marcadores y validar máximo 3
  Set<String> _favIds = {};

  late final VoidCallback _favListener = () {
    _loadFavIds();
  };

  @override
  void initState() {
    super.initState();
    _map = MapController();

    _loadFavIds();
    favoritesVersion.addListener(_favListener);
  }

  @override
  void dispose() {
    favoritesVersion.removeListener(_favListener);
    super.dispose();
  }

  Future<void> _loadFavIds() async {
    final sp = await SharedPreferences.getInstance();
    final ids = sp.getStringList(kFavPrefsKey) ?? [];
    if (!mounted) return;
    setState(() => _favIds = ids.toSet());
  }

  bool _isFav(Station st) => _favIds.contains(st.id.toString());

  // Controles
  void _recenter() => _map.move(widget.initialCenter, widget.initialZoom);
  void _zoomIn() => _map.move(_map.center, _map.zoom + 1);
  void _zoomOut() => _map.move(_map.center, _map.zoom - 1);

  // ====== MARCADORES ======
  List<Marker> get _markers {
    final List<Marker> out = [];
    for (final Station st in kStations) {
      final LatLng? ll = kStationCoords[st.id];
      if (ll == null) continue;

      final fav = _isFav(st);

      out.add(
        Marker(
          point: ll,
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () => _showStationPopup(st, ll),
            child: Icon(
              Icons.location_on,
              color: fav ? const Color.fromARGB(255, 238, 204, 131) : Colors.red,
              size: 36,
            ),
          ),
        ),
      );
    }
    return out;
  }

  Future<void> _toggleFavoriteFromMap(Station st) async {
    final alreadyFav = _isFav(st);

    // ✅ si ya es favorito: siempre permitimos quitar
    if (alreadyFav) {
      await removeFavoriteStation(st);
      await _loadFavIds();
      return;
    }

    // ✅ si NO es favorito: SOLO permitir si aún no hay 3
    if (_favIds.length >= 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solo puedes seleccionar 3 estaciones en el mapa.')),
      );
      return;
    }

    await addFavoriteStation(st);
    await _loadFavIds();
  }

  void _showStationPopup(Station st, LatLng ll) {
    final alreadyFav = _isFav(st);

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(st.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Lat: ${ll.latitude.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 19, fontFamily: 'monospace'),
            ),
            Text(
              'Lon: ${ll.longitude.toStringAsFixed(6)}',
              style: const TextStyle(fontSize: 19),
            ),
            const SizedBox(height: 10),
            Text(
              'Favoritos: ${_favIds.length}/3',
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ],
        ),
        actions: [
          TextButton.icon(
            icon: Icon(alreadyFav ? Icons.favorite : Icons.favorite_border),
            label: Text(alreadyFav ? 'Quitar de favoritos' : 'Agregar a favoritos'),
            onPressed: () async {
              Navigator.pop(context);

              await _toggleFavoriteFromMap(st);

              if (!mounted) return;
              // feedback
              final nowFav = _isFav(st);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    nowFav
                        ? '“${st.name}” agregada. (${_favIds.length}/3)'
                        : '“${st.name}” quitada. (${_favIds.length}/3)',
                  ),
                ),
              );
            },
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // ====== CAPAS BASE ======
  TileLayer _tileFor(_BaseMap type) {
    switch (type) {
      case _BaseMap.osm:
        return TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'com.example.app',
        );
      case _BaseMap.cartoLight:
        return TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.app',
        );
      case _BaseMap.cartoDark:
        return TileLayer(
          urlTemplate:
              'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
          subdomains: const ['a', 'b', 'c', 'd'],
          userAgentPackageName: 'com.example.app',
        );
      case _BaseMap.esriStreet:
        return TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Street_Map/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.example.app',
        );
      case _BaseMap.esriSatellite:
        return TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.example.app',
        );
      case _BaseMap.esriTopo:
        return TileLayer(
          urlTemplate:
              'https://server.arcgisonline.com/ArcGIS/rest/services/World_Topo_Map/MapServer/tile/{z}/{y}/{x}',
          userAgentPackageName: 'com.example.app',
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _map,
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: widget.initialZoom,
            ),
            children: [
              _tileFor(_currentBase),
              MarkerLayer(markers: _markers),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
              ),
            ],
          ),

          Positioned(
            right: 8,
            top: 8,
            child: _MapStyleSelector(
              current: _currentBase,
              onChanged: (v) => setState(() => _currentBase = v),
            ),
          ),

          Positioned(
            right: 8,
            bottom: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniRoundButton(icon: Icons.add, tooltip: 'Acercar', onPressed: _zoomIn),
                const SizedBox(height: 6),
                _MiniRoundButton(icon: Icons.remove, tooltip: 'Alejar', onPressed: _zoomOut),
                const SizedBox(height: 6),
                _MiniRoundButton(icon: Icons.my_location, tooltip: 'Recentrar', onPressed: _recenter),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Botón circular mini (36x36)
class _MiniRoundButton extends StatelessWidget {
  const _MiniRoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        shape: const CircleBorder(),
        elevation: 3,
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: 36,
            height: 36,
            child: Center(child: Icon(icon, size: 18, color: Colors.black87)),
          ),
        ),
      ),
    );
  }
}

/// Dropdown compacto para cambiar la capa base
class _MapStyleSelector extends StatelessWidget {
  const _MapStyleSelector({required this.current, required this.onChanged});

  final _BaseMap current;
  final ValueChanged<_BaseMap> onChanged;

  String _label(_BaseMap b) {
    switch (b) {
      case _BaseMap.cartoLight: return 'Carto Light';
      case _BaseMap.osm: return 'OSM';
      case _BaseMap.esriStreet: return 'Esri Street';
      case _BaseMap.cartoDark: return 'Carto Dark';
      case _BaseMap.esriSatellite: return 'Esri Sat';
      case _BaseMap.esriTopo: return 'Esri Topo';
    }
  }

  @override
  Widget build(BuildContext context) {
    // ✅ SOLO Carto Light (como lo tenías)
    const allowed = [_BaseMap.cartoLight];

    final _BaseMap safeValue =
        allowed.contains(current) ? current : allowed.first;

    return Material(
      color: Colors.white,
      elevation: 3,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: DropdownButton<_BaseMap?>(
          value: safeValue,
          underline: const SizedBox.shrink(),
          style: const TextStyle(fontSize: 12, color: Colors.black87),
          onChanged: (v) { if (v != null) onChanged(v); },
          items: allowed.map((b) {
            return DropdownMenuItem<_BaseMap?>(
              value: b,
              child: Text(_label(b)),
            );
          }).toList(),
        ),
      ),
    );
  }
}
