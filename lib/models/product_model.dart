// lib/models/product_model.dart

class Product {
  final int id;
  final String name;
  final double price;
  final String internalReference;
  final double stock;
  final int? categoryId;
  final String? category;
  final String? description;
  final String? salesUnit;
  final int unitsPerPackage;

  // Propiedad calculada para la imagen
  String get imageUrl =>
      'https://pruebas-aplicacion.odoo.com/web/image?model=product.template&id=$id&field=image_1920';

  Product({
    required this.id,
    required this.name,
    required this.price,
    required this.internalReference,
    required this.stock,
    this.categoryId,
    this.category,
    this.description,
    this.salesUnit,
    required this.unitsPerPackage,
  });

  factory Product.fromJson(Map<String, dynamic> json, {int? templateId}) {
    // --- Funciones de Conversión Segura (Números) ---
    double parseDouble(dynamic value) {
      if (value is num) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 0;
      return 0;
    }
    // ----------------------------------------------------

    // Lógica para la Categoría
    final categoryData = json['categ_id'];
    int? catId;
    String? catName;
    if (categoryData is List && categoryData.isNotEmpty) {
      catId = categoryData[0] as int;
      catName = categoryData[1]?.toString();
    }

    // --- Lógica de Conversión Segura (Strings) ---

    final rawDescription = json['description_sale'];
    final safeDescription = rawDescription?.toString();

    final rawSalesUnit = json['x_studio_unidad_de_venta_nombre'];
    final safeSalesUnit = rawSalesUnit?.toString();

    final rawInternalRef = json['default_code'];
    final safeInternalRef = rawInternalRef?.toString() ?? '';

    return Product(
      id: templateId ?? json['id'] as int,
      name: json['name'] as String,
      price: parseDouble(json['list_price']),
      stock: parseDouble(json['qty_available']),
      unitsPerPackage: parseInt(json['x_studio_unidades_por_paquete']),
      category: catName,
      description: safeDescription,
      salesUnit: safeSalesUnit,
      internalReference: safeInternalRef,
      categoryId: catId,
    );
  }
}
