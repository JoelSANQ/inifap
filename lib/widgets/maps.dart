// lib/widgets/maps.dart
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_cancellable_tile_provider/flutter_map_cancellable_tile_provider.dart';
import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/Stations.dart';
import '../data/lat_and_long_cords.dart';

// ⚠️ Ajusta esta ruta a donde tengas los helpers reales.
// Debe exportar: addFavoriteStation, removeFavoriteStation, favoritesVersion, kFavPrefsKey
import '../services/station_service.dart';
import 'favorite_stations.dart'
    show addFavoriteStation, removeFavoriteStation, favoritesVersion, kFavPrefsKey;
import 'warning_dialog.dart';

// ================== TOKENS DE DISEÑO (marca INIFAP) ==================
const Color _kGuinda = Color.fromARGB(255, 97, 18, 50);
const Color _kGuindaDeep = Color(0xFF3D0A20);
const Color _kGold = Color(0xFFE6A700);
const Color _kBg = Color(0xFFF4F1F2);
const Color _kStroke = Color(0xFFE3DDDF);
const Color _kText = Color(0xFF1A1416);
const Color _kTextMuted = Color(0xFF5C5257); // ~7:1 sobre blanco

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

class _OSMMapState extends State<OSMMap> {
  late final MapController _map;
  // Cancela las peticiones de tiles que quedan fuera de vista al hacer zoom/pan
  // rápido, en vez de dejarlas en cola bloqueando las peticiones nuevas.
  final _tileProvider = CancellableNetworkTileProvider();

  // ✅ favoritos cacheados para pintar marcadores y validar máximo 3
  Set<String> _favIds = {};

  void _favListener() {
    _loadFavIds();
  }

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
  void _zoomIn() => _map.move(_map.center, _map.zoom + 1);
  void _zoomOut() => _map.move(_map.center, _map.zoom - 1);

  // ====== MARCADORES ======
  List<Marker> get _markers {
    final List<Marker> out = [];
    for (final Station st in StationService.instance.stations) {
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
      await showWarningDialog(
        context,
        message: 'Solo puedes seleccionar 3 estaciones en el mapa.',
      );
      return;
    }

    await addFavoriteStation(st);
    await _loadFavIds();
  }

  void _showStationPopup(Station st, LatLng ll) {
    final alreadyFav = _isFav(st);
    final atLimit = _favIds.length >= 3;

    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.45),
      builder: (dialogContext) => _StationPopupCard(
        stationName: st.name,
        latitude: ll.latitude,
        longitude: ll.longitude,
        favoriteCount: _favIds.length,
        isFavorite: alreadyFav,
        atLimit: atLimit,
        onClose: () => Navigator.pop(dialogContext),
        onToggleFavorite: () async {
          Navigator.pop(dialogContext);

          await _toggleFavoriteFromMap(st);

          if (!mounted) return;
          final nowFav = _isFav(st);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              backgroundColor: _kGuindaDeep,
              content: Text(
                nowFav
                    ? '“${st.name}” agregada a favoritos (${_favIds.length}/3)'
                    : '“${st.name}” quitada de favoritos (${_favIds.length}/3)',
              ),
            ),
          );
        },
      ),
    );
  }

  // ====== CAPA BASE (Carto Light — único estilo usado en la app) ======
  TileLayer get _baseTileLayer => TileLayer(
        urlTemplate:
            'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
        subdomains: const ['a', 'b', 'c', 'd'],
        userAgentPackageName: 'com.example.app',
        tileProvider: _tileProvider,
        keepBuffer: 4,
        panBuffer: 2,
      );

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
              _baseTileLayer,
              MarkerLayer(markers: _markers),
              const RichAttributionWidget(
                attributions: [TextSourceAttribution('© OpenStreetMap contributors')],
              ),
            ],
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta emergente al seleccionar una estación en el mapa.
class _StationPopupCard extends StatelessWidget {
  const _StationPopupCard({
    required this.stationName,
    required this.latitude,
    required this.longitude,
    required this.favoriteCount,
    required this.isFavorite,
    required this.atLimit,
    required this.onClose,
    required this.onToggleFavorite,
  });

  final String stationName;
  final double latitude;
  final double longitude;
  final int favoriteCount;
  final bool isFavorite;
  final bool atLimit;
  final VoidCallback onClose;
  final VoidCallback onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    // No se puede agregar si ya se llegó al límite de 3, salvo que ya sea favorita.
    final canToggle = isFavorite || !atLimit;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.20),
              blurRadius: 28,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 12, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _kGuinda.withOpacity(0.10),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.location_on_rounded, color: _kGuinda, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Text(
                        stationName,
                        style: const TextStyle(
                          color: _kText,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded),
                    color: _kTextMuted,
                    tooltip: 'Cerrar',
                    splashRadius: 20,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: _kBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _CoordItem(label: 'Latitud', value: latitude.toStringAsFixed(6)),
                    ),
                    Container(width: 1, height: 32, color: _kStroke),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _CoordItem(label: 'Longitud', value: longitude.toStringAsFixed(6)),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  const Icon(Icons.favorite_rounded, size: 15, color: _kGold),
                  const SizedBox(width: 6),
                  const Text(
                    'Favoritos en el mapa',
                    style: TextStyle(fontSize: 12.5, color: _kTextMuted, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Text(
                    '$favoriteCount/3',
                    style: const TextStyle(fontSize: 12.5, color: _kText, fontWeight: FontWeight.w800),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: favoriteCount / 3,
                  minHeight: 6,
                  backgroundColor: _kStroke,
                  valueColor: const AlwaysStoppedAnimation<Color>(_kGold),
                ),
              ),
              if (atLimit && !isFavorite) ...[
                const SizedBox(height: 8),
                const Text(
                  'Límite alcanzado. Quita una estación favorita para agregar esta.',
                  style: TextStyle(fontSize: 12, color: _kTextMuted, height: 1.3),
                ),
              ],
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: isFavorite
                    ? OutlinedButton.icon(
                        onPressed: onToggleFavorite,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _kGuindaDeep,
                          side: const BorderSide(color: _kGuinda),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.favorite_rounded, size: 18),
                        label: const Text('Quitar de favoritos', style: TextStyle(fontWeight: FontWeight.w700)),
                      )
                    : FilledButton.icon(
                        onPressed: canToggle ? onToggleFavorite : null,
                        style: FilledButton.styleFrom(
                          backgroundColor: _kGuinda,
                          disabledBackgroundColor: _kStroke,
                          disabledForegroundColor: _kTextMuted,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.favorite_border_rounded, size: 18),
                        label: const Text('Agregar a favoritos', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Par etiqueta/valor para las coordenadas dentro de la tarjeta.
class _CoordItem extends StatelessWidget {
  const _CoordItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 11.5, color: _kTextMuted, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            color: _kText,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
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

