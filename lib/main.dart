import 'package:flutter/material.dart';
import 'WeatherProxypage.dart'; // 👈 importa tu nueva pantalla

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WeatherProxyPage(), // 👈 aquí llamas la UI nueva
    );
  }
}