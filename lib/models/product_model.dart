// lib/models/product_model.dart

class Product {
  final int id;
  final String name;
  final String internalReference; // AÑADIDO
  final double price;
  final String imageUrl;
  final String category;
  final String description;

  Product({
    required this.id,
    required this.name,
    required this.internalReference, // AÑADIDO
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.description,
  });

  factory Product.fromJson(Map<String, dynamic> json, {int? templateId}) {
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

    final imageId = templateId ?? json['id'];

    return Product(
      id: json['id'] ?? 0,
      name: json['name'] is String ? json['name'] : 'Sin Nombre',
      // AÑADIDO: Lectura segura de la referencia interna
      internalReference:
          json['default_code'] is String ? json['default_code'] : '',
      price: (json['list_price'] ?? 0.0).toDouble(),
      imageUrl:
          'https://www.dicos.cl/web/image/product.template/$imageId/image_512',
      category: categoryValue,
      description: descriptionText,
    );
  }
}
