// lib/widgets/maps.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// Mapa de OpenStreetMap centrado en Zacatecas.
/// Incluye botones pequeños para zoom in, zoom out y recentrar.
/// Se adapta completamente al espacio del contenedor padre (sin bordes).
class OSMMap extends StatefulWidget {
  /// Centro inicial del mapa (Zacatecas)
  final LatLng initialCenter;

  /// Nivel de zoom inicial
  final double initialZoom;

  /// Marcadores iniciales opcionales
  final List<Marker> initialMarkers;

  const OSMMap({
    super.key,
    this.initialCenter = const LatLng(22.76843, -102.58141),
    this.initialZoom = 12.0,
    this.initialMarkers = const [],
  });

  @override
  State<OSMMap> createState() => _OSMMapState();
}

class _OSMMapState extends State<OSMMap> {
  late final MapController _mapController;
  late final List<Marker> _markers;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _markers = [...widget.initialMarkers];
  }

  void _recenter() {
    _mapController.move(widget.initialCenter, widget.initialZoom);
  }

  void _zoomIn() {
    _mapController.move(_mapController.center, _mapController.zoom + 1);
  }

  void _zoomOut() {
    _mapController.move(_mapController.center, _mapController.zoom - 1);
  }

  void _addMarker(LatLng point) {
    setState(() {
      _markers.add(
        Marker(
          point: point,
          width: 40,
          height: 40,
          child: const Icon(Icons.location_on, color: Colors.red, size: 34),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    // El mapa ocupa todo el espacio disponible del contenedor padre
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: widget.initialCenter,
              initialZoom: widget.initialZoom,
              onLongPress: (tapPos, latLng) => _addMarker(latLng),
            ),
            children: [
              // Capa base OSM
              TileLayer(
                urlTemplate:
                    'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.example.app', // cambia con tu id real
                tileProvider: NetworkTileProvider(),
              ),

              // Capa de marcadores
              MarkerLayer(markers: _markers),

              // Atribución OSM
              const RichAttributionWidget(
                attributions: [
                  TextSourceAttribution('© OpenStreetMap contributors'),
                ],
              ),
            ],
          ),

          // Controles pequeños (zoom y centrado)
          Positioned(
            right: 8,
            bottom: 8,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _MiniRoundButton(
                  icon: Icons.add,
                  tooltip: 'Acercar',
                  onPressed: _zoomIn,
                ),
                const SizedBox(height: 6),
                _MiniRoundButton(
                  icon: Icons.remove,
                  tooltip: 'Alejar',
                  onPressed: _zoomOut,
                ),
                const SizedBox(height: 6),
                _MiniRoundButton(
                  icon: Icons.my_location,
                  tooltip: 'Recentrar',
                  onPressed: _recenter,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 🔘 Botón circular pequeño para controles del mapa.
class _MiniRoundButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  const _MiniRoundButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onPressed,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(
            child: Icon(icon, size: 18, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}