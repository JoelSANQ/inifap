// lib/widgets/maps.dart 
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../data/Stations.dart';
import 'package:clima/widgets/favorite_stations.dart' show addFavoriteStation;
import '../data/lat_and_long_cords.dart';

/// Mapa OSM con:
/// - Marcadores para TODAS las estaciones de kStations (si tenemos coordenadas)
/// - Botones pequeños (+, −, recentrar)
/// - Selector de capas base
/// - Popups con nombre y link "Tiempo Real"
class OSMMap extends StatefulWidget {
  const OSMMap({
    super.key,
    this.initialCenter = const LatLng(23.216944, -103.036111), // Fresnillo - Col. Emancipación
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

  @override
  void initState() {
    super.initState();
    _map = MapController();
  }

  // Controles
  void _recenter() => _map.move(widget.initialCenter, widget.initialZoom);
  void _zoomIn() => _map.move(_map.center, _map.zoom + 1);
  void _zoomOut() => _map.move(_map.center, _map.zoom - 1);

  // ====== MARCADORES desde kStations usando el diccionario de coordenadas ======
  List<Marker> get _markers {
    final List<Marker> out = [];
    for (final Station st in kStations) {
      final LatLng? ll = kStationCoords[st.id];
      if (ll == null) continue; // si no tenemos coords para ese id, lo saltamos
      out.add(
        Marker(
          point: ll,
          width: 44,
          height: 44,
          child: GestureDetector(
            onTap: () => _showStationPopup(st, ll),
            child: const Icon(Icons.location_on, color: Colors.red, size: 36),
            // Si quieres el icono de viento del HTML:
            // child: Image.network('http://zacatecas.inifap.gob.mx/images/wind.png', width: 28, height: 34),
          ),
        ),
      );
    }
    return out;
  }

  void _showStationPopup(Station st, LatLng ll) {
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
            ],
          ),
        actions: [
          // ⬇️ Integrado: usa la misma función de la barra para guardar en favoritos
          TextButton.icon(
            icon: const Icon(Icons.favorite_border),
            label: const Text('Agregar a favoritos'),
            onPressed: () async {
              Navigator.pop(context);
              await addFavoriteStation(st);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('“${st.name}” agregada a favoritos')),
                );
              }
            },
          ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cerrar')),
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
    // Se adapta 100% al tamaño del contenedor padre
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

          // Selector de estilo (solo 2 opciones: Carto Light y OSM)
          Positioned(
            right: 8,
            top: 8,
            child: _MapStyleSelector(
              current: _currentBase,
              onChanged: (v) => setState(() => _currentBase = v),
            ),
          ),

          // Controles pequeños
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

/// Dropdown compacto para cambiar la capa base (SOLO Carto Light y OSM).
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
    // Solo estas dos opciones quedan visibles en el selector
    const allowed = [_BaseMap.cartoLight, _BaseMap.osm];

    final _BaseMap safeValue =
        allowed.contains(current) ? current : allowed.first;

    return Material(
      color: Colors.white, elevation: 3, borderRadius: BorderRadius.circular(20),
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


