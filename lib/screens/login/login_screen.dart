// lib/screens/login/login_screen.dart

import 'package:flutter/material.dart';
import '../../api/odoo_api_client.dart';
import '../home/home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController =
      TextEditingController(text: "oscarwmt@gmail.com");
  final TextEditingController _passwordController =
      TextEditingController(text: "Ticex2021");
  bool _isLoading = false;
  String? _errorMessage;

  final OdooApiClient _apiClient = OdooApiClient();

  // Lógica de inicio de sesión contra la API de Odoo
  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final login = _usernameController.text;
    final password = _passwordController.text;

    try {
      // CORRECCIÓN CLAVE: Pasamos los argumentos requeridos: login y password
      await _apiClient.authenticate(login: login, password: password);

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
              builder: (ctx) => HomeScreen(apiClient: _apiClient)),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage =
              "Error de conexión/credenciales. Detalles: ${e.toString().replaceAll('Exception: ', '')}";
          _isLoading = false;
        });
      }
    }
  }

  // Lógica para ingresar como invitado (pasa una instancia NO autenticada)
  void _loginAsGuest() {
    final guestClient = OdooApiClient();

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (ctx) => HomeScreen(apiClient: guestClient),
        ),
      );
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 120,
                height: 120,
                child: Image.asset('assets/images/dicos.png'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Acceso al Catálogo',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),

              // Campo de Usuario (Email)
              TextField(
                controller: _usernameController,
                decoration: InputDecoration(
                  labelText: 'Correo Electrónico (Odoo)',
                  prefixIcon: const Icon(Icons.email),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),

              // Campo de Contraseña
              TextField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'Contraseña (Odoo)',
                  prefixIcon: const Icon(Icons.lock),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),

              // Mensaje de Error
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: const TextStyle(
                        color: Colors.red, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                ),

              // Botón INICIAR SESIÓN
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 3))
                      : const Text('INICIAR SESIÓN',
                          style: TextStyle(fontSize: 18)),
                ),
              ),
              const SizedBox(height: 12),

              // Botón INGRESAR COMO INVITADO
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _isLoading ? null : _loginAsGuest,
                  child: const Text('INGRESAR COMO INVITADO',
                      style: TextStyle(fontSize: 16, color: Colors.grey)),
                ),
              ),
              const SizedBox(height: 12),

              // Botón CREAR UNA CUENTA (Simulado)
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                          content: Text(
                              'Funcionalidad de Crear Cuenta no implementada aún.')),
                    );
                  },
                  child: const Text('CREAR UNA CUENTA',
                      style: TextStyle(fontSize: 16, color: Colors.blue)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
