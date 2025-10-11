// lib/screens/splash/splash_screen.dart

import 'package:flutter/material.dart';
import '../auth/auth_screen.dart'; // Asegúrate que la ruta sea correcta

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToAuth();
  }

  Future<void> _navigateToAuth() async {
    // Simula un tiempo de carga (ej: verificar sesión, cargar datos, etc.)
    await Future.delayed(const Duration(seconds: 3));

    // CORRECCIÓN: Verificar si el widget sigue montado antes de usar el context.
    if (!mounted) return;

    // Ahora es seguro usar el context para la navegación.
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (ctx) => const AuthScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Cargando...'),
          ],
        ),
      ),
    );
  }
}
