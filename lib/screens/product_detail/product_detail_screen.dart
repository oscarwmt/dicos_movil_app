// lib/screens/product_detail/product_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(product.name),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 300,
              color: Colors.grey[200],
              child: product.imageUrl.isNotEmpty
                  ? Image.network(
                      product.imageUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return const Icon(Icons.image_not_supported,
                            size: 80, color: Colors.grey);
                      },
                    )
                  : const Icon(Icons.image, size: 80, color: Colors.grey),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    product.category.toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.name,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '\$${product.price.toStringAsFixed(0)}',
                    style: const TextStyle(
                        fontSize: 28,
                        color: Colors.green,
                        fontWeight: FontWeight.w500),
                  ),
                  const SizedBox(height: 20),
                  const Divider(),
                  const SizedBox(height: 12),
                  const Text(
                    'Descripción',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    product.description.isEmpty
                        ? 'Este producto no tiene descripción.'
                        : product.description,
                    style: const TextStyle(fontSize: 16, height: 1.5),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // CORRECCIÓN: Se añade el nombre del parámetro 'quantity'.
          cart.addItem(product, quantity: 1);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product.name} agregado al carrito.'),
              duration: const Duration(seconds: 2),
              action: SnackBarAction(
                label: 'DESHACER',
                onPressed: () {
                  cart.removeSingleItem(product.id);
                },
              ),
            ),
          );
        },
        label: const Text('Agregar al Carrito'),
        icon: const Icon(Icons.add_shopping_cart),
      ),
    );
  }
}
