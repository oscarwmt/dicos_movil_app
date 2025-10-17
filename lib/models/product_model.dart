// lib/models/product_model.dart

class Product {
  final int id;
  final int templateId;
  final String name;
  final double price;
  final String internalReference;
  final double stock;
  final String imageUrl;
  final String? salesUnit;
  final int unitsPerPackage;
  final String? categoryName;
  final String? brandName;
  final String? description;

  Product({
    required this.id,
    required this.templateId,
    required this.name,
    required this.price,
    required this.internalReference,
    required this.stock,
    required this.imageUrl,
    this.salesUnit,
    required this.unitsPerPackage,
    this.categoryName,
    this.brandName,
    this.description,
  });

  factory Product.fromJson(Map<String, dynamic> json, {int? templateId}) {
    String? extractName(dynamic field) {
      if (field is List && field.length > 1) {
        return field[1] as String?;
      }
      return null;
    }

    int parseUnitsPerPackage(dynamic value) {
      if (value == null) return 1;
      if (value is int) return value;
      if (value is double) return value.toInt();
      if (value is String) return int.tryParse(value) ?? 1;
      return 1;
    }

    final currentTemplateId = templateId ?? json['id'];

    return Product(
      id: (json['product_variant_id'] is List)
          ? json['product_variant_id'][0]
          : json['id'],
      templateId: currentTemplateId,
      name: json['name'] ?? 'Sin Nombre',
      price: (json['list_price'] ?? 0.0).toDouble(),
      internalReference: json['default_code'] ?? '',
      stock: (json['qty_available'] ?? 0.0).toDouble(),
      imageUrl:
          "https://pruebas-aplicacion.odoo.com/web/image/product.template/$currentTemplateId/image_1024",
      salesUnit: (json['x_studio_unidad_de_venta_nombre'] is List)
          ? json['x_studio_unidad_de_venta_nombre'][1]
          : 'Unidad',
      unitsPerPackage:
          parseUnitsPerPackage(json['x_studio_unidades_por_paquete']),
      categoryName: extractName(json['categ_id']),

      // ✅ CORREGIDO: Usando el nombre de campo correcto
      brandName: extractName(json['x_studio_marca']),

      description:
          json['description_sale'] is String ? json['description_sale'] : null,
    );
  }
}
