// lib/models/sale_order_model.dart

class SaleOrder {
  final int id;
  final String name;
  final String customerName;
  final double amountTotal;
  final double amountUntaxed;
  final double amountTax;
  final String state;
  final DateTime dateOrder;
  final String shippingAddressName;
  final String shippingAddressIdName;

  SaleOrder({
    required this.id,
    required this.name,
    required this.customerName,
    required this.amountTotal,
    required this.amountUntaxed,
    required this.amountTax,
    required this.state,
    required this.dateOrder,
    required this.shippingAddressName,
    required this.shippingAddressIdName,
  });

  factory SaleOrder.fromJson(Map<String, dynamic> json) {
    // Helper para conversión segura
    double parseNum(dynamic value) => (value as num?)?.toDouble() ?? 0.0;

    final partnerData = json['partner_id'] as List<dynamic>?;
    final shippingData = json['partner_shipping_id'] as List<dynamic>?;

    final String dateString = json['date_order'] ?? '';
    final String stateString = json['state'] ?? 'N/A';

    // Extracción de nombres
    String partnerName = partnerData != null && partnerData.isNotEmpty
        ? partnerData[1] as String
        : 'N/A';
    String addressName = 'N/A';
    if (shippingData != null &&
        shippingData.isNotEmpty &&
        shippingData.length > 1) {
      addressName = shippingData[1] as String? ?? 'N/A';
    }

    // ✅ CORRECCIÓN CLAVE: Se eliminan las llaves de la interpolación de addressName
    String fullTitle = '$partnerName / $addressName';

    return SaleOrder(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'N/A',
      customerName: partnerName,
      amountTotal: parseNum(json['amount_total']),
      amountUntaxed: parseNum(json['amount_untaxed']),
      amountTax: parseNum(json['amount_tax']),
      state: stateString,
      dateOrder: DateTime.tryParse(dateString) ?? DateTime.now(),
      shippingAddressName: addressName,
      shippingAddressIdName: fullTitle,
    );
  }
}
