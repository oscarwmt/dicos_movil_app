// lib/models/product_model.dart

class Product {
  final int id;
  final String name;
  final double price;
  final String imageUrl;
  final String category;
  final String description;

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.description,
  });

  factory Product.fromJson(Map<String, dynamic> json, String baseUrl,
      {int? templateId}) {
    final categoryInfo = json['categ_id'];
    String categoryValue = 'Sin Categoría';
    if (categoryInfo is List && categoryInfo.length > 1) {
      categoryValue = categoryInfo[1];
    }

    final descriptionValue = json['description_sale'];
    String descriptionText = '';
    if (descriptionValue is String) {
      descriptionText = descriptionValue;
    }

    // Usamos el templateId para la imagen, si está disponible, si no, usamos el id de la variante
    final imageId = templateId ?? json['id'];

    return Product(
      id: json['id'] ?? 0,
      name: json['name'] is String ? json['name'] : 'Sin Nombre',
      price: (json['list_price'] ?? 0.0).toDouble(),
      // CORRECCIÓN: La URL de la imagen en variantes apunta a la plantilla (product.template)
      imageUrl: json['image_1920'] is String
          ? '$baseUrl/web/image/product.template/$imageId/image_1920'
          : '',
      category: categoryValue,
      description: descriptionText,
    );
  }
}
