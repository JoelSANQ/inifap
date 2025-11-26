import 'package:flutter/material.dart';
import 'bin/generate_offline.dart'; 
import 'WeatherProxyPage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //  Intentar sincronizar datos offline al abrir la app
  await OfflineDataService.instance.syncFromNetwork();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: WeatherProxyPage(),  // 👈 pantalla inicial
    );
  }
}
