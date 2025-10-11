// lib/models/customer_model.dart

class Customer {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String paymentTerm; // AÑADIDO: Propiedad para el plazo de pago

  // Constructor principal
  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.paymentTerm, // AÑADIDO: al constructor
  });

  // Constructor por defecto
  static Customer get defaultCustomer {
    return Customer(
      id: 0,
      name: 'Seleccionar Cliente',
      email: '',
      phone: '',
      paymentTerm: 'No definido', // AÑADIDO: valor por defecto
    );
  }

  // Fábrica para crear un Cliente desde un JSON de Odoo
  factory Customer.fromJson(Map<String, dynamic> json) {
    final paymentTermInfo = json['property_payment_term_id'];
    String paymentTermValue = 'No definido';
    // Un campo Many2one en Odoo devuelve [id, 'Nombre'] o 'false' si está vacío
    if (paymentTermInfo is List && paymentTermInfo.length > 1) {
      paymentTermValue = paymentTermInfo[1];
    }

    return Customer(
      id: json['id'] ?? 0,
      name: json['name'] is String ? json['name'] : 'Sin Nombre',
      email: json['email'] is String ? json['email'] : 'Sin email',
      phone: json['phone'] is String ? json['phone'] : 'Sin teléfono',
      paymentTerm: paymentTermValue, // AÑADIDO: Se asigna el valor
    );
  }
}
