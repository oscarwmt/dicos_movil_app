// lib/screens/product_detail/product_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';

class ProductDetailScreen extends StatelessWidget {
  final Product product;

  const ProductDetailScreen({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final priceFormatter =
        NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);

    // Asignación segura de valores para evitar errores de nulidad
    final String safeCategory = product.category ?? 'SIN CATEGORÍA';
    final String safeSalesUnit =
        product.salesUnit ?? 'Unidad'; // Soluciona error en línea ~67
    final String safeDescription =
        product.description ?? ''; // Soluciona error en líneas ~92-94

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
                    // ✅ CORRECCIÓN 1: Se usa safeCategory para evitar el error de toUpperCase()
                    safeCategory.toUpperCase(),
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
                  Row(
                    children: [
                      Icon(Icons.inventory_2_outlined,
                          color: Colors.grey.shade700, size: 18),
                      const SizedBox(width: 8),
                      // ✅ CORRECCIÓN 2: Se usa safeSalesUnit para evitar error de nulidad
                      Text('Unidades por $safeSalesUnit:',
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 8),
                      Text('${product.unitsPerPackage}',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    '${priceFormatter.format(product.price)} + IVA',
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
                    // ✅ CORRECCIÓN 3: Se usa safeDescription, que ya está garantizada como String no nula
                    safeDescription.isEmpty
                        ? 'Este producto no tiene descripción.'
                        : safeDescription,
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
          cart.addItem(product, quantity: 1);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${product.name} agregado al carrito.'),
              duration: const Duration(seconds: 2),
              action: SnackBarAction(
                label: 'DESHACER',
                onPressed: () {
                  //cart.removeSingleItem(product.id,
                  //    isInStock: product.stock > 0);
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
