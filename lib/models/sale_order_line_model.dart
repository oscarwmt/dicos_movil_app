// lib/models/sale_order_line_model.dart

class SaleOrderLine {
  final int id;
  final String productName;
  final double quantity;
  final double priceUnit;
  final double priceSubtotal;
  final String productUOMName;
  final int productTemplateId;
  final String salesUnitName;

  SaleOrderLine({
    required this.id,
    required this.productName,
    required this.quantity,
    required this.priceUnit,
    required this.priceSubtotal,
    required this.productUOMName,
    required this.productTemplateId,
    required this.salesUnitName,
  });

  factory SaleOrderLine.fromJson(Map<String, dynamic> json,
      {String? customSalesUnit}) {
    // Helper para conversión segura
    double parseNum(dynamic value) => (value as num?)?.toDouble() ?? 0.0;

    // Los campos Many2One devuelven [ID, Nombre]
    final productData = json['product_id'] as List<dynamic>?;
    final uomData = json['product_uom_id'] as List<dynamic>?;
    final templateData = json['product_template_id'] as List<dynamic>?;

    return SaleOrderLine(
      id: json['id'] as int,
      productName: productData != null && productData.isNotEmpty
          ? productData[1] as String
          : 'Producto Desconocido',
      quantity: parseNum(json['product_uom_qty']),
      priceUnit: parseNum(json['price_unit']),
      priceSubtotal: parseNum(json['price_subtotal']),
      productUOMName:
          uomData != null && uomData.isNotEmpty ? uomData[1] as String : 'N/A',
      productTemplateId: templateData != null && templateData.isNotEmpty
          ? templateData[0] as int
          : 0,
      salesUnitName: customSalesUnit ?? 'N/A',
    );
  }
}
