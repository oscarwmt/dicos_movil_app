// lib/widgets/product_card.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../models/product_model.dart';
import '../providers/cart_provider.dart';
import '../screens/product_detail/product_detail_screen.dart';

class ProductCard extends StatelessWidget {
  final Product product;

  const ProductCard({
    super.key,
    required this.product,
  });

  void _onCardTap(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => ProductDetailScreen(product: product),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    final priceFormatter = NumberFormat.currency(
        locale: 'es', symbol: '\$', decimalDigits: 0, customPattern: '\$#,##0');

    final buttonLabel = product.stock > 0 ? 'Agregar' : 'Solicitar';
    final buttonColor =
        product.stock > 0 ? Theme.of(context).primaryColor : Colors.red;

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _onCardTap(context),
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 5,
              child: Container(
                color: Colors.grey[200],
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image, color: Colors.grey),
                      )
                    : const Icon(Icons.image, size: 60, color: Colors.grey),
              ),
            ),
            Expanded(
              flex: 6,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          product.name,
                          style: const TextStyle(fontSize: 12),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          product.salesUnit ?? 'Unidad',
                          style: const TextStyle(
                              fontSize: 11,
                              color: Colors.grey,
                              fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              'COD: ${product.internalReference}',
                              style: const TextStyle(
                                  fontSize: 11, color: Colors.grey),
                            ),
                            RichText(
                              text: TextSpan(
                                style: TextStyle(
                                    fontSize: 14,
                                    color: Theme.of(context).primaryColor,
                                    fontWeight: FontWeight.w600),
                                children: [
                                  TextSpan(
                                      text:
                                          priceFormatter.format(product.price)),
                                  const TextSpan(
                                    text: ' + IVA',
                                    style: TextStyle(
                                        fontSize: 10,
                                        color: Colors.black54,
                                        fontWeight: FontWeight.normal),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Stock: ${product.stock.toInt()}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: product.stock <= 0
                                ? Colors.red.shade700
                                : Colors.grey.shade800,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  backgroundColor: buttonColor,
                  foregroundColor: Colors.white, // ✅ ¡AQUÍ ESTÁ LA CORRECCIÓN!
                ),
                onPressed: () {
                  cart.addItem(product, quantity: 1);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                          '${product.name} ${product.stock <= 0 ? "agregado a informe de demanda" : "agregado al carrito."}'),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
