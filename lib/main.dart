import 'package:flutter/material.dart';
import 'WeatherProxypage.dart'; 

void main() {
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false,
    home: WeatherProxyPage(), // 👈 el usuario seleccionará la estación
  ));
}