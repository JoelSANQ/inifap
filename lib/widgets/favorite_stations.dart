import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/Stations.dart'; // ajusta la ruta si es distinta

class FavoriteStationsBar extends StatefulWidget {
  final void Function(Station station) onSelect;
  const FavoriteStationsBar({super.key, required this.onSelect});

  @override
  State<FavoriteStationsBar> createState() => _FavoriteStationsBarState();
}

class _FavoriteStationsBarState extends State<FavoriteStationsBar> {
  static const _prefsKey = 'favorite_station_ids';
  List<Station> _favorites = [];

  // ✅ guardamos el callback para poder quitarlo en dispose
  late final VoidCallback _favListener = () {
    _loadFavs();
  };

  @override
  void initState() {
    super.initState();
    _loadFavs();
    // 👇 suscríbete a cambios globales de favoritos (con callback estable)
    favoritesVersion.addListener(_favListener);
  }

  @override
  void dispose() {
    favoritesVersion.removeListener(_favListener);
    super.dispose();
  }

  Future<void> _loadFavs() async {
    final sp = await SharedPreferences.getInstance();
    final ids = sp.getStringList(_prefsKey) ?? [];
    final mapById = {for (final s in kStations) s.id.toString(): s};
    final restored = [
      for (final id in ids)
        if (mapById[id] != null) mapById[id]!,
    ];
    if (mounted) {
      setState(() => _favorites = restored);
    }
  }

  Future<void> _saveFavs() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(
      _prefsKey,
      _favorites.map((s) => s.id.toString()).toList(),
    );
    // 👇 notifica a quien escuche (incluida esta barra si otro cambió la lista)
    favoritesVersion.value++;
  }

  // ✅ MULTI-SELECCIÓN + regla: mínimo 3 para "activar notificaciones"
  void _addFavoriteFlow() async {
    final result = await showModalBottomSheet<List<Station>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _MultiSelectStationsSheet(
        initialSelectedIds: _favorites.map((e) => e.id).toSet(),
      ),
    );

    // canceló
    if (result == null) return;

    // ✅ regla: mínimo 3
    if (result.length > 3) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selecciona mínimo 3 estaciones para activar notificaciones.'),
        ),
      );
      return;
    }

    // ✅ Guardar la lista completa (reemplaza favoritos por lo seleccionado)
    setState(() => _favorites = result);
    await _saveFavs();

    // 👇 siguiente paso (cuando lo conectemos a FCM):
    // if (_favorites.length >= 3) { habilitarNotificaciones(); }
  }

  void _removeFavorite(Station s) async {
    setState(() => _favorites.removeWhere((f) => f.id == s.id));
    await _saveFavs();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      // 👇 sin color de fondo, totalmente transparente
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          // Botón "Añadir"
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ActionChip(
              label: const Text(
                'Añadir',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
              avatar: const Icon(Icons.add, color: Colors.white),
              backgroundColor: const Color.fromARGB(255, 238, 204, 131),
              onPressed: _addFavoriteFlow,
            ),
          ),

          // Chips de estaciones favoritas
          for (final st in _favorites)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: InputChip(
                label: Text(
                  st.name,
                  style: const TextStyle(color: Colors.white),
                ),
                backgroundColor: const Color(0xFF611232),
                onPressed: () => widget.onSelect(st),
                onDeleted: () => _removeFavorite(st),
                deleteIconColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}

/// BottomSheet con multi-selección de estaciones
class _MultiSelectStationsSheet extends StatefulWidget {
  final Set<int> initialSelectedIds;

  const _MultiSelectStationsSheet({
    required this.initialSelectedIds,
  });

  @override
  State<_MultiSelectStationsSheet> createState() => _MultiSelectStationsSheetState();
}

class _MultiSelectStationsSheetState extends State<_MultiSelectStationsSheet> {
  late Set<int> _selectedIds;

  @override
  void initState() {
    super.initState();
    _selectedIds = {...widget.initialSelectedIds};
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      builder: (_, controller) => Column(
        children: [
          const SizedBox(height: 10),
          Container(
            width: 40,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Añadir estación a favoritos',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),

          // contador y regla mínimo 3
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text('Seleccionadas: ${_selectedIds.length}'),
                const Spacer(),
                const Text('Mínimo 3', style: TextStyle(color: Colors.black54)),
              ],
            ),
          ),

          const SizedBox(height: 6),

          Expanded(
            child: ListView.separated(
              controller: controller,
              itemCount: kStations.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final st = kStations[i];
                final checked = _selectedIds.contains(st.id);

                return CheckboxListTile(
                  value: checked,
                  title: Text(st.name),
                  controlAffinity: ListTileControlAffinity.trailing,
                  onChanged: (v) {
                    setState(() {
                      if (v == true) {
                        _selectedIds.add(st.id);
                      } else {
                        _selectedIds.remove(st.id);
                      }
                    });
                  },
                );
              },
            ),
          ),

          // barra inferior con botones
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(null),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        // Armamos lista de estaciones seleccionadas
                        final mapById = {for (final s in kStations) s.id: s};
                        final selectedStations = _selectedIds
                            .where((id) => mapById[id] != null)
                            .map((id) => mapById[id]!)
                            .toList();

                        Navigator.of(context).pop(selectedStations);
                      },
                      child: const Text('Guardar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---- helpers públicos reutilizables (para que el mapa use la misma lógica) ----
const String kFavPrefsKey = 'favorite_station_ids';

/// Notificador global de “versión” de favoritos.
/// Cada vez que cambie la lista, incrementa su valor.
final ValueNotifier<int> favoritesVersion = ValueNotifier<int>(0);

Future<void> addFavoriteStation(Station station) async {
  final sp = await SharedPreferences.getInstance();
  final ids = sp.getStringList(kFavPrefsKey) ?? [];
  final idStr = station.id.toString();
  if (!ids.contains(idStr)) {
    ids.add(idStr);
    await sp.setStringList(kFavPrefsKey, ids);
    favoritesVersion.value++; // 🔔 avisa a todos los escuchas
  }
}

Future<void> removeFavoriteStation(Station station) async {
  final sp = await SharedPreferences.getInstance();
  final ids = sp.getStringList(kFavPrefsKey) ?? [];
  final idStr = station.id.toString();
  if (ids.remove(idStr)) {
    await sp.setStringList(kFavPrefsKey, ids);
    favoritesVersion.value++; // 🔔 avisa a todos los escuchas
  }
}

/// ✅ util: validar mínimo de favoritos (para notificaciones)
Future<bool> hasMinFavoritesForNotifications({int min = 3}) async {
  final sp = await SharedPreferences.getInstance();
  final ids = sp.getStringList(kFavPrefsKey) ?? [];
  return ids.length >= min;
}
