// lib/widgets/cart_icon_badge.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/cart_provider.dart';
import '../screens/cart/cart_screen.dart';

class CartIconBadge extends StatelessWidget {
  const CartIconBadge({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (_, cart, ch) => Badge(
        label: Text(cart.totalUniqueItems.toString()),
        isLabelVisible: cart.totalUniqueItems > 0,
        child: ch!,
      ),
      child: IconButton(
        icon: const Icon(Icons.shopping_cart),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => const CartScreen(),
            ),
          );
        },
      ),
    );
  }
}

// Widget Badge simple para compatibilidad
class Badge extends StatelessWidget {
  const Badge({
    super.key,
    required this.child,
    required this.label,
    this.isLabelVisible = true,
  });

  final Widget child;
  final Widget label;
  final bool isLabelVisible;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        child,
        if (isLabelVisible)
          Positioned(
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.all(2.0),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10.0),
                color: Theme.of(context).colorScheme.secondary,
              ),
              constraints: const BoxConstraints(
                minWidth: 16,
                minHeight: 16,
              ),
              child: DefaultTextStyle(
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                ),
                child: label,
              ),
            ),
          )
      ],
    );
  }
}
