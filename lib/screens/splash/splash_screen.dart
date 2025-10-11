import 'package:flutter/material.dart';
// CORRECCIÓN 1: Se cambió la ruta de importación a la correcta.
import '../login/login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Simula una carga o verificación de sesión.
    await Future.delayed(const Duration(seconds: 3));

    // Verificar si el widget sigue "vivo" antes de navegar.
    if (!mounted) return;

    // Navega a la pantalla de autenticación, reemplazando el splash.
    // CORRECCIÓN 2: Se cambió AuthScreen() por LoginScreen().
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (ctx) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Aquí podrías poner el logo de tu empresa
            CircularProgressIndicator(),
            SizedBox(height: 20),
            Text('Iniciando Aplicación de Vendedores...'),
          ],
        ),
      ),
    );
  }
}
