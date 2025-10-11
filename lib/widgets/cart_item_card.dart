// lib/widgets/cart_item_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/cart_item_model.dart';
import '../providers/cart_provider.dart';

class CartItemCard extends StatelessWidget {
  final CartItem item;

  const CartItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    // Escuchamos el proveedor para llamar a los métodos de manipulación
    final cart = Provider.of<CartProvider>(context, listen: false);

    // Permite deslizar para eliminar
    return Dismissible(
      key: ValueKey(item.product.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        cart.removeItem(item.product.id);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${item.product.name} eliminado del carrito.'),
            duration: const Duration(seconds: 1),
          ),
        );
      },
      // Fondo rojo al deslizar
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
        child: const Icon(Icons.delete, color: Colors.white, size: 30),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 4),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 60,
                // CARGA DE IMAGEN SEGURA (funciona en carrito porque hay pocas)
                child: Image.network(
                  item.product.imageUrl.isEmpty
                      ? 'https://placehold.co/60x60/cccccc/000000?text=IMG'
                      : item.product.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return const Center(
                        child: Icon(Icons.shopping_bag, color: Colors.grey));
                  },
                ),
              ),
            ),
            title: Text(
              item.product.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: Text(
              'Subtotal: \$${(item.product.price * item.quantity).toStringAsFixed(2)}',
              style: TextStyle(color: Colors.grey[700]),
            ),
            trailing: SizedBox(
              width: 120,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Botón de Decremento
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline,
                        color: Colors.red),
                    onPressed: () {
                      cart.removeSingleItem(
                          item.product.id); // Llama al provider
                    },
                  ),
                  // Cantidad
                  Text(
                    '${item.quantity}',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  // Botón de Incremento
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline,
                        color: Colors.green),
                    onPressed: () {
                      cart.addItem(item.product,
                          quantity: 1); // Llama al provider
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
