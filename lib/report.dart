import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // ✅ para kIsWeb
import 'package:http/http.dart' as http;

// ================== CONFIGURACIÓN DEL PROXY ==================
const String _kUpstream = 'http://zacatecas.inifap.gob.mx/apiApp2.php';

String _buildProxyUrl({required int r}) {
  final upstream = '$_kUpstream?r=$r';
  if (kIsWeb) {
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
  // 👇 Controlador para la barra de scroll de los botones
  final ScrollController _buttonScrollController = ScrollController();

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
      case '1': return 'Tiempo Real de las Estaciones';
      case '3': return 'Resumen en Tiempo Real de las Estaciones';
      case '4': return 'Reporte Mensual de las Estaciones';
      default: return '';
    }
  }

  String _modeSubtitle() {
    switch (_currentMode) {
      case '1': 
        return '\nDesliza y toca el botón para ver datos. Los datos corresponden a la hora más reciente reportada por cada estación.';
      case '3': 
        return '\nDesliza y toca el botón para ver datos. Valores desde las 00:00 hr hasta la hora reportada, para cada estación.';
      case '4': 
        return '\nDesliza y toca el botón para ver datos. Valores acumulados y promedios del mes actual para cada estación.';
      default: 
        return 'Selecciona un formato para mostrar los datos de las 38 estaciones.';
    }
  }

  // ================== UI ==================
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final width = size.width;

    // Adaptabilidad de fuentes
    final double titleFontSize = (width * 0.05).clamp(16.0, 20.0);
    final double sectionHeaderFontSize = (width * 0.045).clamp(14.0, 17.0);
    final double subtitleFontSize = (width * 0.035).clamp(11.0, 13.0);
    final bool isMobile = width < 600;

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final maxWidth = constraints.maxWidth;
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
                        Center(
                          child: Text(
                            'Reportes de Monitoreo Agroclimático\ndel Estado de Zacatecas',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: titleFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Formatos de Visualización
                        Center(
                          child: Text(
                            'Formatos de Visualización Disponibles',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: sectionHeaderFontSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // 👇 SECCIÓN DE BOTONES CON BARRA DE SCROLL
                        Theme(
                          data: Theme.of(context).copyWith(
                            scrollbarTheme: ScrollbarThemeData(
                              thumbColor: WidgetStateProperty.all(const Color.fromARGB(255, 97, 18, 50).withOpacity(0.5)),
                            )
                          ),
                          child: Scrollbar(
                            controller: _buttonScrollController,
                            thumbVisibility: true,
                            trackVisibility: true,
                            child: SingleChildScrollView(
                              controller: _buttonScrollController,
                              scrollDirection: Axis.horizontal,
                              padding: const EdgeInsets.only(bottom: 15, top: 8), 
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.start,
                                children: [
                                  _GreenModeButton(
                                    text: 'Tiempo Real',
                                    active: _currentMode == '1',
                                    onTap: () => _fetchForMode(1),
                                  ),
                                  const SizedBox(width: 10),
                                  _GreenModeButton(
                                    text: 'Resumen en Tiempo Real',
                                    active: _currentMode == '3',
                                    onTap: () => _fetchForMode(3),
                                  ),
                                  const SizedBox(width: 10),
                                  _GreenModeButton(
                                    text: 'Avance Mensual',
                                    active: _currentMode == '4',
                                    onTap: () => _fetchForMode(4),
                                  ),
                                ],
                              ),
                            ),
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
                              fontSize: subtitleFontSize,
                              height: 1.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Contenido
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
                                style: const TextStyle(color: Colors.redAccent, fontSize: 14),
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
    final double width = MediaQuery.of(context).size.width;

    // Ajuste dinámico de escala
    final double dynamicFontSize = (width * 0.032).clamp(9.5, 13.0);
    final double horizontalPadding = (width * 0.02).clamp(6.0, 14.0);
    final double verticalPadding = (width * 0.012).clamp(4.0, 8.0);

    final bg = active
        ? const Color.fromARGB(255, 97, 18, 50)
        : Colors.grey.shade400;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding, 
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: dynamicFontSize,
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

  const _ModeTable({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) return const SizedBox.shrink();
    final columns = rows.first.keys.toList();
    final width = MediaQuery.of(context).size.width;

    final bool isNarrow = width < 800;
    final columnSpacing = isNarrow ? 18.0 : 32.0;
    final horizontalMargin = isNarrow ? 8.0 : 14.0;
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
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(const Color.fromARGB(255, 97, 18, 50)),
            headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            dataRowColor: WidgetStateProperty.all(Colors.white),
            border: TableBorder.all(color: Colors.black26, width: 0.4),
            columnSpacing: columnSpacing,
            horizontalMargin: horizontalMargin,
            columns: columns
                .map((c) => DataColumn(label: Text(c, style: const TextStyle(fontSize: 13))))
                .toList(),
            rows: rows
                .map((r) => DataRow(
                  cells: columns.map((c) => DataCell(
                    ConstrainedBox(
                      constraints: BoxConstraints(minWidth: 40, maxWidth: maxCellWidth),
                      child: Text(
                        (r[c] ?? '—').toString(),
                        style: const TextStyle(fontSize: 12.5),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )).toList(),
                ))
                .toList(),
          ),
        ),
      ],
    );
  }
}