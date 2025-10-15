// lib/screens/cart/cart_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/cart_item_card.dart';
import '../sale_order/new_order_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final totalItems = cart.totalUniqueItems;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tu Carrito'),
        actions: <Widget>[
          if (totalItems > 0)
            IconButton(
              icon: const Icon(Icons.delete_sweep),
              onPressed: () {
                Provider.of<CartProvider>(context, listen: false).clear();
              },
            )
        ],
      ),
      body: Column(
        children: <Widget>[
          Card(
            margin: const EdgeInsets.all(15),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const Text(
                    'Total',
                    style: TextStyle(fontSize: 20),
                  ),
                  const Spacer(),
                  Chip(
                    label: Text(
                      '\$${cart.totalAmount.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Theme.of(context)
                            .primaryTextTheme
                            .titleLarge
                            ?.color,
                      ),
                    ),
                    backgroundColor: Theme.of(context).primaryColor,
                  ),
                  TextButton(
                    onPressed: (totalItems > 0)
                        ? () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (ctx) => const NewOrderScreen(),
                              ),
                            );
                          }
                        : null,
                    child: Text(
                      'ORDENAR AHORA',
                      style: TextStyle(color: Theme.of(context).primaryColor),
                    ),
                  )
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: totalItems,
              itemBuilder: (ctx, i) {
                // Combina ambas listas para la visualización
                final allItems = [
                  ...cart.inStockItems,
                  ...cart.outOfStockItems
                ];
                final item = allItems[i];
                final isInStock = i < cart.inStockItems.length;

                return CartItemCard(
                  key: ValueKey(item.product.id),
                  cartItem: item,
                  isInStock: isInStock,
                );
              },
            ),
          )
        ],
      ),
    );
  }
}
