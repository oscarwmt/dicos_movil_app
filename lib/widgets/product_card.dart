// lib/widgets/product_card.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../screens/product_detail/product_detail_screen.dart';

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({super.key, required this.product});

  void _showSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Usamos listen: false porque solo necesitamos llamar a un método (addItem)
    final cart = Provider.of<CartProvider>(context, listen: false);

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () {
          // Navegación a la pantalla de detalle del producto
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => ProductDetailScreen(product: product),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Imagen del Producto (Placeholder)
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius:
                      const BorderRadius.vertical(top: Radius.circular(16)),
                  color: Colors.grey[100],
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.shopping_bag_outlined, // Ícono de producto genérico
                  size: 50,
                  color: Colors.grey,
                ),
              ),
            ),

            // Detalles del Producto
            Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Nombre del Producto
                  Text(
                    product.name,
                    style: const TextStyle(
                      // FUENTE MÁS CHICA y negrita normal
                      fontWeight: FontWeight.w500,
                      fontSize: 10,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  // Precio
                  Text(
                    '\$${product.price.toStringAsFixed(2)}',
                    style: TextStyle(
                      // FUENTE MÁS CHICA y sin negrita
                      fontSize: 12,
                      fontWeight: FontWeight.normal,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Botón de Añadir al Carrito
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        cart.addItem(product, quantity: 1);
                        _showSnackbar(context, '¡${product.name} añadido!');
                      },
                      icon: const Icon(Icons.add_shopping_cart, size: 18),
                      label: const Text('Añadir'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
