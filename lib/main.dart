// lib/main.dart

import 'package:dicos_movil_app/providers/cart_provider.dart';
import 'package:dicos_movil_app/screens/splash/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

void main() {
  // Asegura que los bindings de Flutter estén inicializados.
  WidgetsFlutterBinding.ensureInitialized();

  runApp(const DicosMovilApp());
}

class DicosMovilApp extends StatelessWidget {
  const DicosMovilApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Usamos MultiProvider para poder agregar más providers en el futuro fácilmente.
    return MultiProvider(
      providers: [
        // Aquí inicializamos el CartProvider para que esté disponible en toda la app.
        ChangeNotifierProvider(
          create: (ctx) => CartProvider(),
        ),
      ],
      child: MaterialApp(
        title: 'DICOS Vendedores App',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          primarySwatch: Colors.deepPurple,
          visualDensity: VisualDensity.adaptivePlatformDensity,
        ),
        // La pantalla de inicio de la aplicación es el SplashScreen.
        home: const SplashScreen(),
      ),
    );
  }
}
