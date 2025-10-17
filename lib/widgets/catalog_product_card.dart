// lib/widgets/catalog_product_card.dart

import 'package:flutter/material.dart';
import '../models/product_model.dart';
import '../screens/product_detail/product_detail_screen.dart';

class CatalogProductCard extends StatelessWidget {
  final Product product;

  const CatalogProductCard({
    super.key,
    required this.product,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
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
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ✅ AJUSTE: Más espacio para la imagen (de flex 5 a 7)
            Expanded(
              flex: 7,
              child: Container(
                color: Colors.grey[200],
                child: product.imageUrl.isNotEmpty
                    ? Image.network(
                        product.imageUrl,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.broken_image,
                                color: Colors.grey, size: 40),
                      )
                    : const Icon(Icons.image, size: 60, color: Colors.grey),
              ),
            ),
            // ✅ AJUSTE: Menos espacio para el texto (de flex 6 a 4)
            Expanded(
              flex: 4,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment
                      .center, // Centra el contenido verticalmente
                  children: [
                    Text(
                      product.name,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'COD: ${product.internalReference}',
                      style:
                          const TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    // ✅ SECCIÓN DE PRECIO ELIMINADA
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
