// lib/widgets/product_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../screens/product_detail/product_detail_screen.dart';

class ProductCard extends StatelessWidget {
  final Product product;

  // ✅ CORRECCIÓN 1: Constructor con required this.product
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);

    // ✅ CORRECCIÓN 2: Definición de priceFormatter
    final priceFormatter = NumberFormat('#,##0', 'es_CL');

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => ProductDetailScreen(product: product),
            ),
          );
        },
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Sección de la Imagen: Mantenemos Expanded
            Expanded(
              flex: 2, // Ajustado a 2 para equilibrar el espacio
              child: Container(
                color: Colors.grey[200],
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        fit: BoxFit.contain, // Ajuste para que se vea completa
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, color: Colors.grey),
                      )
                    : const Icon(Icons.image, size: 60, color: Colors.grey),
              ),
            ),

            // Sección de la Información del Producto
            // ❌ AJUSTE DE DISEÑO: ELIMINAMOS Expanded para que ocupe el mínimo espacio
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize:
                    MainAxisSize.min, // Ocupa solo el espacio de sus hijos
                children: [
                  Text(
                    product.name,
                    style: const TextStyle(fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(
                      height: 4), // Espacio mínimo entre nombre y detalles

                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (product.internalReference.isNotEmpty)
                        Text(
                          product.internalReference,
                          style:
                              const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      const Spacer(), // Spacer para separar la referencia del precio
                      RichText(
                        text: TextSpan(
                          style: TextStyle(
                              fontSize: 14,
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w600),
                          children: [
                            TextSpan(
                                text:
                                    '\$${priceFormatter.format(product.price)}'),
                            TextSpan(
                              text: ' + IVA',
                              style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.normal),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Sección del Botón
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: ElevatedButton(
                // ✅ CORRECCIÓN 3: Restaurar la función onPressed
                onPressed: () {
                  cart.addItem(product, quantity: 1);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('${product.name} agregado al carrito.'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: const Text('Agregar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
