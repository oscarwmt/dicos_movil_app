// lib/models/customer_model.dart

class Customer {
  final int id;
  final String name;
  final String email;
  final String phone;

  Customer({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
  });

  // Método fábrica para crear un Cliente desde un JSON de Odoo
  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: json['id'] as int,
      name: json['name'] as String? ?? 'Cliente Desconocido',
      email: json['email'] as String? ?? 'No disponible',
      phone: json['phone'] as String? ?? 'No disponible',
    );
  }

  // Cliente por defecto cuando no se ha seleccionado ninguno
  static Customer get defaultCustomer => Customer(
        id: 0,
        name: 'Seleccionar Cliente',
        email: 'N/A',
        phone: 'N/A',
      );
}
