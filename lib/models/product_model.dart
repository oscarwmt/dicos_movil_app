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
  // Nota: La URL sigue usando el ID de la plantilla (templateId) para obtener la imagen,
  // ya que la imagen se asocia a la plantilla, no a la variante.
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
    required this.unitsPerPackage,
    this.salesUnit,
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

    // --- LÓGICA DE CORRECCIÓN CLAVE: Usar product_variant_id (product.product) ---
    final rawVariantId = json['product_variant_id'];
    int finalProductId;

    if (rawVariantId is List && rawVariantId.isNotEmpty) {
      // Caso más común: Odoo devuelve [ID_Variante, Nombre_Variante]
      finalProductId = rawVariantId[0] as int;
    } else if (rawVariantId is int) {
      // Caso alternativo: Si Odoo devuelve solo el ID (menos común)
      finalProductId = rawVariantId;
    } else {
      // Fallback: Si no se encontró la variante, usar el ID de la plantilla.
      // Advertencia: Si el templateId es 11270, el error persistirá si Odoo requiere variante.
      finalProductId = templateId ?? json['id'] as int;
    }

    return Product(
      // ✅ USAMOS EL ID DE LA VARIANTE (O EL FALLBACK) PARA EL CARRITO/PEDIDO
      id: finalProductId,
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
