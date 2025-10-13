// lib/models/product_model.dart

class Product {
  final int id;
  final String name;
  final String internalReference;
  final double price;
  final String imageUrl;
  final String? category;
  final String? description;
  final double qtyAvailable;

  Product({
    required this.id,
    required this.name,
    required this.internalReference,
    required this.price,
    required this.imageUrl,
    this.category,
    this.description,
    required this.qtyAvailable,
  });

  factory Product.fromJson(Map<String, dynamic> json, {int? templateId}) {
    final categoryInfo = json['categ_id'];
    String? categoryValue;
    if (categoryInfo is List && categoryInfo.length > 1) {
      categoryValue = categoryInfo[1];
    }

    final descriptionValue = json['description_sale'];
    String? descriptionText;
    if (descriptionValue is String && descriptionValue.isNotEmpty) {
      descriptionText = descriptionValue;
    }

    final imageId = templateId ?? json['id'];

    // ✅ CORREGIDO: Lógica más robusta para leer el stock.
    // Esto verifica si el valor es un número antes de convertirlo.
    // Si es `null` o `false`, lo convierte en 0.0.
    final rawQty = json['qty_available'];
    final finalQty = (rawQty is num) ? rawQty.toDouble() : 0.0;

    return Product(
      id: json['id'] ?? 0,
      name: json['name'] is String ? json['name'] : 'Sin Nombre',
      internalReference:
          json['default_code'] is String ? json['default_code'] : '',
      price: (json['list_price'] ?? 0.0).toDouble(),
      imageUrl:
          'https://www.dicos.cl/web/image/product.template/$imageId/image_512',
      category: categoryValue,
      description: descriptionText,
      qtyAvailable: finalQty, // Usamos la cantidad segura.
    );
  }
}
