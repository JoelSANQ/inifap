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

  @override
  void initState() {
    super.initState();
    _loadFavs();
  }

  Future<void> _loadFavs() async {
    final sp = await SharedPreferences.getInstance();
    final ids = sp.getStringList(_prefsKey) ?? [];
    final mapById = {for (final s in kStations) s.id.toString(): s};
    final restored = [
      for (final id in ids) if (mapById[id] != null) mapById[id]!,
    ];
    setState(() => _favorites = restored);
  }

  Future<void> _saveFavs() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setStringList(
      _prefsKey,
      _favorites.map((s) => s.id.toString()).toList(),
    );
  }

  void _addFavoriteFlow() async {
    final selected = await showModalBottomSheet<Station>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 40, height: 5,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 8),
            const Text('Añadir estación a favoritos',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                controller: controller,
                itemCount: kStations.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final st = kStations[i];
                  final already = _favorites.any((f) => f.id == st.id);
                  return ListTile(
                    title: Text(st.name),
                    trailing: already
                        ? const Icon(Icons.check, color: Colors.green)
                        : null,
                    onTap: () => Navigator.of(ctx).pop(st),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );

    if (selected != null &&
        !_favorites.any((f) => f.id == selected.id)) {
      setState(() => _favorites.add(selected));
      _saveFavs();
    }
  }

  void _removeFavorite(Station s) {
    setState(() => _favorites.removeWhere((f) => f.id == s.id));
    _saveFavs();
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
            backgroundColor: const Color(0xFF611232),// tono más claro o distinto
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
