// lib/models/customer_model.dart

class Customer {
  final int id;
  final String name;
  final String email;
  final String paymentTerm;
  final bool isBlocked;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.paymentTerm,
    required this.isBlocked,
  });

  static Customer get defaultCustomer {
    return Customer(
      id: 0,
      name: 'Seleccionar Cliente',
      email: '',
      paymentTerm: '',
      isBlocked: true,
    );
  }

  factory Customer.fromJson(Map<String, dynamic> json) {
    final paymentTermInfo = json['property_payment_term_id'];
    String paymentTermValue = 'Contado';
    if (paymentTermInfo is List && paymentTermInfo.length > 1) {
      paymentTermValue = paymentTermInfo[1];
    }

    return Customer(
      id: json['id'] ?? 0,
      name: json['name'] ?? 'Sin Nombre',
      email: json['email'] ?? 'Sin correo',
      paymentTerm: paymentTermValue,
      // ✅ CORRECCIÓN: Usamos una comparación estricta para máxima seguridad.
      isBlocked: json['x_studio_bloqueado_deuda'] == true,
    );
  }
}
