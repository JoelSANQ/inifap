import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ para kIsWeb
import 'package:http/http.dart' as http;

// ================== CONFIGURACIÓN DEL PROXY ==================
const String _kUpstream = 'http://zacatecas.inifap.gob.mx/apiApp2.php';

/// ✅ En Web: usa proxy (CORS)
/// ✅ En Android/iOS/desktop: va directo al upstream
String _buildProxyUrl({required int r}) {
  final upstream = '$_kUpstream?r=$r';

  if (kIsWeb) {
    // Proxy local (ajusta host/puerto si usas otro)
    return 'http://localhost:8080/$upstream';
  }

  return upstream;
}

class WeatherDashboard extends StatefulWidget {
  const WeatherDashboard({super.key});

  @override
  State<WeatherDashboard> createState() => _WeatherDashboardState();
}

class _WeatherDashboardState extends State<WeatherDashboard> {
  String? _currentMode; // '1' = Tiempo Real, '3' = Resumen TR, '4' = Avance Mensual
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _rows = [];

  // ================== FETCH GENÉRICO POR MODO ==================
  Future<void> _fetchForMode(int r) async {
    setState(() {
      _currentMode = '$r';
      _loading = true;
      _error = null;
      _rows = [];
    });

    try {
      final url = _buildProxyUrl(r: r);
      final res = await http.get(Uri.parse(url));

      if (res.statusCode != 200) {
        throw Exception('Error HTTP ${res.statusCode}');
      }

      final data = jsonDecode(res.body);
      List<Map<String, dynamic>> rows = [];

      if (data is List && data.isNotEmpty) {
        final first = data.first;

        // Caso 1: estructura con "Datos"/"datos" interna
        if (first is Map &&
            (first.containsKey('Datos') || first.containsKey('datos'))) {
          final root = Map<String, dynamic>.from(first);
          final nested = root['Datos'] ?? root['datos'];
          if (nested is List) {
            for (final item in nested) {
              if (item is Map) {
                rows.add(Map<String, dynamic>.from(item));
              }
            }
          }
        } else {
          // Caso 2: lista plana de objetos
          for (final item in data) {
            if (item is Map) {
              rows.add(Map<String, dynamic>.from(item));
            }
          }
        }
      }

      setState(() {
        _rows = rows;
        if (_rows.isEmpty) {
          _error = 'Sin datos disponibles para este reporte.';
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar datos: $e';
        _rows = [];
      });
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ================== TEXTOS POR MODO ==================
  String _modeTitle() {
    switch (_currentMode) {
      case '1':
        return 'Tiempo Real de las Estaciones';
      case '3':
        return 'Resumen en Tiempo Real de las Estaciones';
      case '4':
        return 'Reporte Mensual de las Estaciones';
      default:
        return '';
    }
  }

  String _modeSubtitle() {
    switch (_currentMode) {
      case '1':
        return 'Los datos corresponden a la hora más reciente reportada por cada estación.';
      case '3':
        return 'Valores desde las 00:00 hr hasta la hora reportada, para cada estación.';
      case '4':
        return 'Valores acumulados y promedios del mes actual para cada estación.';
      default:
        return 'Selecciona un formato para mostrar los datos de las 38 estaciones.';
    }
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;

    // 👇 Ancho de pantalla y tamaño de fuente responsive para el subtítulo
    final double subtitleFontSize = width < 380 ? 11.0 : 13.0;
    final bool isMobile = width < 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;

            // 📌 En pantallas grandes, centramos el contenido y limitamos el ancho
            final double contentMaxWidth = maxWidth > 1100 ? 1100 : maxWidth;

            return Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: contentMaxWidth),
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: isMobile ? 14.0 : 24.0,
                      vertical: isMobile ? 18.0 : 28.0,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título
                        const Center(
                          child: Text(
                            'Reportes de Monitoreo Agroclimático\n'
                            'del Estado de Zacatecas',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Formatos / modos disponibles
                        const Text(
                          'Formatos de Visualización Disponibles',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 👇 SECCIÓN DE BOTONES RESPONSIVA
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            alignment: isMobile
                                ? WrapAlignment.start
                                : WrapAlignment.center,
                            children: [
                              _GreenModeButton(
                                text: 'Tiempo Real',
                                active: _currentMode == '1',
                                onTap: () => _fetchForMode(1),
                              ),
                              _GreenModeButton(
                                text: 'Resumen en Tiempo Real',
                                active: _currentMode == '3',
                                onTap: () => _fetchForMode(3),
                              ),
                              _GreenModeButton(
                                text: 'Avance Mensual',
                                active: _currentMode == '4',
                                onTap: () => _fetchForMode(4),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 18),
                        // Subtítulo
                        Center(
                          child: Text(
                            _modeSubtitle(),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.black45,
                              fontSize: subtitleFontSize, // 👈 tamaño adaptativo
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Contenido: loader / error / tabla
                        if (_loading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(20),
                              child: CircularProgressIndicator(
                                color: Color.fromARGB(255, 97, 18, 50),
                              ),
                            ),
                          )
                        else if (_error != null)
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Text(
                                _error!,
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 14,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        else if (_rows.isNotEmpty && _currentMode != null)
                          _ModeTable(
                            title: _modeTitle(),
                            rows: _rows,
                          )
                        else
                          const SizedBox.shrink(),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

// ================== BOTONES VERDES DE MODO ==================
class _GreenModeButton extends StatelessWidget {
  final String text;
  final bool active;
  final VoidCallback onTap;

  const _GreenModeButton({
    required this.text,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? const Color.fromARGB(255, 97, 18, 50)
        : Colors.grey.shade400;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}

// ================== TABLA GENÉRICA RESPONSIVE ==================
class _ModeTable extends StatelessWidget {
  final String title;
  final List<Map<String, dynamic>> rows;

  const _ModeTable({
    required this.title,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();

    final columns = rows.first.keys.toList();
    final width = MediaQuery.of(context).size.width;

    // Espaciado adaptable: más compacto en pantallas pequeñas
    final bool isNarrow = width < 800;
    final columnSpacing = isNarrow ? 18.0 : 32.0;
    final horizontalMargin = isNarrow ? 8.0 : 14.0;

    // Ancho máximo por celda también se adapta
    final double maxCellWidth = isNarrow ? 140 : 220;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title.isNotEmpty) ...[
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color.fromARGB(221, 0, 0, 0),
            ),
          ),
          const SizedBox(height: 12),
        ],
        // La tabla usa el ancho disponible; si se pasa, se hace scroll horizontal.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(
              const Color.fromARGB(255, 97, 18, 50),
            ),
            headingTextStyle: const TextStyle(
              color: Color.fromARGB(255, 255, 255, 255),
              fontWeight: FontWeight.bold,
            ),
            dataRowColor: WidgetStateProperty.all(Colors.white),
            border: TableBorder.all(color: Colors.black26, width: 0.4),
            columnSpacing: columnSpacing,
            horizontalMargin: horizontalMargin,
            columns: columns
                .map(
                  (c) => DataColumn(
                    label: Text(
                      c,
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                )
                .toList(),
            rows: rows
                .map(
                  (r) => DataRow(
                    cells: columns
                        .map(
                          (c) => DataCell(
                            ConstrainedBox(
                              constraints: BoxConstraints(
                                minWidth: 40,
                                maxWidth: maxCellWidth,
                              ),
                              child: Text(
                                (r[c] ?? '—').toString(),
                                style: const TextStyle(fontSize: 12.5),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                )
                .toList(),
          ),
        ),
      ],
    );
  }
}
