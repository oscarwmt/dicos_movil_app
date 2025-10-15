// lib/models/customer_model.dart

class Customer {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String paymentTerm;
  final bool isBlocked;
  final double credit;
  final int? pricelistId;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.paymentTerm,
    required this.isBlocked,
    required this.credit,
    this.pricelistId,
  });

  static Customer get defaultCustomer {
    return Customer(
      id: 0,
      name: 'Seleccionar Cliente',
      email: '',
      phone: '',
      paymentTerm: 'No definido',
      isBlocked: false,
      credit: 0.0,
      pricelistId: null,
    );
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    final paymentTermInfo = json['property_payment_term_id'];
    String paymentTermValue = 'No definido';
    if (paymentTermInfo is List && paymentTermInfo.length > 1) {
      paymentTermValue = paymentTermInfo[1];
    }

    final pricelistInfo = json['property_product_pricelist'];
    int? pricelistIdValue;
    if (pricelistInfo is List && pricelistInfo.isNotEmpty) {
      pricelistIdValue = pricelistInfo[0];
    }

    return Customer(
      id: json['id'] ?? 0,
      name: json['name'] is String ? json['name'] : 'Sin Nombre',
      email: json['email'] is String ? json['email'] : 'Sin email',
      phone: json['phone'] is String ? json['phone'] : 'Sin teléfono',
      paymentTerm: paymentTermValue,
      isBlocked: json['x_studio_bloqueado_deuda'] as bool? ?? false,
      credit: (json['credit'] as num? ?? 0.0).toDouble(),
      pricelistId: pricelistIdValue,
    );
  }
}
