import 'package:flutter/material.dart';

class ChartLegend extends StatelessWidget {
  const ChartLegend({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Ítem para Temperatura
          _LegendItem(
            color: const Color.fromARGB(255, 102, 6, 6), // kBurgundy
            label: 'Temp. Máxima (°C)',
            isLine: true,
          ),
          const SizedBox(width: 20),
          // Ítem para Precipitación
          _LegendItem(
            color: const Color(0xFFE6A700), // kWarmAccent
            label: 'Precipitación (mm)',
            isLine: false,
          ),
        ],
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool isLine;

  const _LegendItem({
    required this.color,
    required this.label,
    required this.isLine,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 16,
          height: isLine ? 3 : 12, // Línea delgada o cuadro para barras
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}