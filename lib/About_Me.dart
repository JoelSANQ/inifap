import 'package:flutter/material.dart';

class AboutUsPage extends StatelessWidget {
  const AboutUsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),

              // ===== LOGO DEL TEC ARRIBA =====
              Center(
                child: Image.asset(
                  'lib/images/logo.jpeg',
                  height: 80,
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 24),

              // ===== TÍTULO: ACERCA DE NOSOTROS =====
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'ACERCA DE NOSOTROS',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                    color: Colors.black87,
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ===== PÁRRAFO PRINCIPAL =====
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Somos un equipo de estudiantes del Tecnológico '
                  'de Software integrado por:',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 15.5,
                  ),
                ),
              ),

              const SizedBox(height: 24),

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

              const SizedBox(height: 18),

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

              const SizedBox(height: 18),

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

              const SizedBox(height: 28),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  'Creamos esta app como parte de nuestro Plan '
                  'de Formación Dual trabajando para el INIFAP en '
                  'un periodo de 4 meses.',
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: Colors.black54,
                    fontSize: 15,
                  ),
                ),
              ),

              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}
