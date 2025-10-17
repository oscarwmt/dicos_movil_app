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

    // Fallback de texto
    final safeCategory = product.categoryName ?? 'Sin categoría';
    final safeSalesUnit = product.salesUnit ?? 'Unidad';

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

                  // ✅ CORRECCIÓN CLAVE: Precio a la izquierda, Unidad y Cantidad a la derecha
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // PRECIO (Izquierda, Fuente Grande)
                      Text(
                        '${priceFormatter.format(product.price)} + IVA',
                        style: const TextStyle(
                            fontSize: 24,
                            color: Colors.green,
                            fontWeight: FontWeight.w500),
                      ),

                      // UNIDAD DE VENTA Y CANTIDAD (Derecha, Compacto)
                      Row(
                        children: [
                          Icon(Icons.inventory_2_outlined,
                              color: Colors.grey.shade700, size: 16),
                          const SizedBox(width: 6),
                          Text('${product.unitsPerPackage}',
                              style: const TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.bold)),
                          Text(
                            ' por $safeSalesUnit',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.black87),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // FIN DE LA CORRECCIÓN CLAVE

                  const SizedBox(height: 20),

                  // Información de Stock
                  Row(
                    children: [
                      Text(
                        'Stock disponible: ${product.stock.toInt()}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: product.stock <= 0
                              ? Colors.red
                              : Colors.green.shade700,
                        ),
                      ),
                    ],
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
                    (product.description ?? '').isEmpty
                        ? 'Este producto no tiene descripción.'
                        : product.description!,
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
