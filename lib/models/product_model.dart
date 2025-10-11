// lib/models/product_model.dart

class Product {
  final int id;
  final String name;
  final double price;
  final String imageUrl;
  final String? description;
  final String categoryName;
  // NUEVOS: Campos de inventario
  final double qtyAvailable; // Cantidad a mano (física)
  final double
      qtyForecast; // Cantidad pronosticada (a mano + pedidos de compra - pedidos de venta)

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    this.description,
    required this.categoryName,
    required this.qtyAvailable,
    required this.qtyForecast,
  });

  factory Product.fromJson(Map<String, dynamic> json, String baseUrl) {
    final int productId = json['id'] ?? 0;

    final bool hasImage =
        json['image_1920'] != null && json['image_1920'] != false;

    final String imagePath = (productId != 0 && hasImage)
        ? '$baseUrl/web/image?model=product.template&id=$productId&field=image_1920'
        : '';

    // Lógica de Categoría (Simple y estable)
    const String category = 'Productos';

    return Product(
      id: productId,
      name: json['name'] ?? 'Nombre no disponible',
      price: (json['list_price'] ?? 0.0).toDouble(),
      imageUrl: imagePath,
      description: null,
      categoryName: category,
      // Mapeo de inventario
      qtyAvailable: (json['qty_available'] ?? 0.0).toDouble(),
      qtyForecast: (json['virtual_available'] ?? 0.0).toDouble(),
    );
  }
}
