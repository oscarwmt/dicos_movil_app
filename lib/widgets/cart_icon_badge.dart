// lib/widgets/cart_icon_badge.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../screens/cart/cart_screen.dart';

class CartIconBadge extends StatelessWidget {
  const CartIconBadge({super.key});

  @override
  Widget build(BuildContext context) {
    // Usamos Consumer para escuchar solo los cambios de CartProvider
    return Consumer<CartProvider>(
      builder: (_, cart, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // 1. Ícono del Carrito (Botón)
            IconButton(
              icon: const Icon(Icons.shopping_cart_outlined),
              onPressed: () {
                // Navegación a la pantalla del carrito
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (ctx) => const CartScreen()),
                );
              },
            ),

            // 2. Badge (Contador)
            if (cart.itemCount > 0)
              Positioned(
                right: 8,
                top: 8,
                child: Container(
                  padding: const EdgeInsets.all(2.0),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10.0),
                    color: Colors.red,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 16,
                    minHeight: 16,
                  ),
                  child: Text(
                    // Muestra la cantidad total de tipos de producto (itemCount)
                    cart.itemCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
          ],
        );
      },
    );
  }
}
