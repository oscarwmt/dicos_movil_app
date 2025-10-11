// main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/splash/splash_screen.dart'; // Importamos el Splash Screen
import 'providers/cart_provider.dart';

void main() {
  runApp(
    ChangeNotifierProvider(
      create: (context) => CartProvider(),
      child: const DicosMovilApp(),
    ),
  );
}

class DicosMovilApp extends StatelessWidget {
  const DicosMovilApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DICOS Móvil',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.green,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      // LANZAMOS EL SPLASH SCREEN
      home: const SplashScreen(),
    );
  }
}
