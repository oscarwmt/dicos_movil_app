// lib/models/sale_order_model.dart

class SaleOrder {
  final int id;
  final String name; // Nombre del pedido (ej: SO00123)
  final String customerName;
  final double amountTotal;
  final double amountUntaxed;
  final double amountTax;
  final String state; // Estado del pedido (draft, sale, done, etc.)
  final DateTime dateOrder;

  SaleOrder({
    required this.id,
    required this.name,
    required this.customerName,
    required this.amountTotal,
    required this.amountUntaxed,
    required this.amountTax,
    required this.state,
    required this.dateOrder,
  });

  factory SaleOrder.fromJson(Map<String, dynamic> json) {
    // Los campos Many2One devuelven [ID, Nombre]
    final partnerData = json['partner_id'] as List<dynamic>;

    return SaleOrder(
      id: json['id'] as int,
      name: json['name'] as String,
      customerName: partnerData.isNotEmpty ? partnerData[1] as String : 'N/A',
      amountTotal: (json['amount_total'] as num?)?.toDouble() ?? 0.0,
      amountUntaxed: (json['amount_untaxed'] as num?)?.toDouble() ?? 0.0,
      amountTax: (json['amount_tax'] as num?)?.toDouble() ?? 0.0,
      state: json['state'] as String? ?? 'N/A',
      dateOrder: DateTime.tryParse(json['date_order'] ?? '') ?? DateTime.now(),
    );
  }
}
