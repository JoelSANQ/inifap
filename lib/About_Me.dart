import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 20),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Somos un equipo de estudiantes del Tecnológico '
                    'de Software integrado por:',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 15.5,
                    ),
                  ),
                ),
                const SizedBox(height: 30),

                // ===== INTEGRANTES =====
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.person, size: 30, color: Colors.grey),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Joel del Jesús Sánchez Quintal',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.person, size: 30, color: Colors.grey),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Manuel Alejandro Cano Lara',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 22),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.person, size: 30, color: Colors.grey),
                    SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        'Gerardo Góngora Vargas',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.black54,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 40),

                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20.0),
                  child: Text(
                    'Creamos esta app como parte de nuestro Plan '
                    'de Formación Dual trabajando para el INIFAP en '
                    'un periodo de 4 meses.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.black54,
                      fontSize: 15,
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // ===== LOGO DEL TEC =====
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20.0),
                  child: Image.asset(
                    'lib/images/logo.jpeg',
                    height: 60,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 10),

              ],
            ),
          ),
        ),
      ),
    );
  }
}
