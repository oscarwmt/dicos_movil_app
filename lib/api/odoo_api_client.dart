// lib/api/odoo_api_client.dart

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import '../models/customer_model.dart';

// Enum para manejar los perfiles de Odoo internamente
enum SalesRole { vendedor, verTodasLasVentas, administradorVentas, invitado }

class OdooApiClient {
  // --- SINGLETON PATTERN ---
  static final OdooApiClient _instance = OdooApiClient._internal();
  factory OdooApiClient() => _instance;
  OdooApiClient._internal();
  // -------------------------

  final String _baseUrl = "https://dicos-v1.odoo.com";
  final String _dbName = "dicos-v1";
  // ELIMINADA la propiedad _password que generaba advertencia.

  int? _userId;
  String? _sessionId;
  String _currentPassword = "";
  String _userName = "Invitado";
  final String _userEmail = "";
  String _deliveryAddress = "Av. Principal #123, Santiago";
  int? _partnerId;

  SalesRole _userRole = SalesRole.invitado;

  String get userName => _userName;
  String get deliveryAddress => _deliveryAddress;
  String get userEmail => _userEmail;
  bool get isAuthenticated => _userId != null && _sessionId != null;
  SalesRole get userRole => _userRole;

  // Método auxiliar para obtener la dirección principal
  Future<void> _fetchPartnerDetails() async {
    if (_partnerId == null || _userId == null) return;

    final url = Uri.parse('$_baseUrl/jsonrpc');

    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 3,
      "params": {
        "service": "object",
        "method": "execute_kw",
        "args": [
          _dbName,
          _userId,
          _currentPassword,
          'res.partner',
          'read',
          [
            [_partnerId]
          ],
          {
            "fields": ["street", "city"],
          }
        ],
        "session_id": _sessionId
      }
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      final responseBody = json.decode(response.body);
      final result = responseBody['result'];

      if (result is List && result.isNotEmpty) {
        final partnerData = result.first;
        final street = partnerData['street'] ?? '';
        final city = partnerData['city'] ?? '';

        String address = street.trim();
        if (city.isNotEmpty) {
          if (address.isNotEmpty) {
            address += ", ";
          }
          address += city;
        }

        if (address.isNotEmpty) {
          _deliveryAddress = address;
        }
      }
    } catch (e) {
      // Si falla, se mantiene la dirección por defecto.
    }
  }

  // 1. Método para manejar la autenticación
  Future<void> authenticate(
      {required String login, required String password}) async {
    final url = Uri.parse('$_baseUrl/web/session/authenticate');

    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "params": {
        "db": _dbName,
        "login": login,
        "password": password // Usa el password recibido
      }
    };

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      final responseBody = json.decode(response.body);

      if (responseBody['error'] != null) {
        final errorMessageDetail = responseBody['error']['data']['message'] ??
            'Error desconocido al autenticar.';
        throw Exception('Autenticación Fallida: $errorMessageDetail');
      }

      final result = responseBody['result'];

      final String? setCookie = response.headers['set-cookie'];
      String? extractedSessionId;
      if (setCookie != null) {
        final match = RegExp(r'session_id=([^;]+)').firstMatch(setCookie);
        if (match != null) {
          extractedSessionId = match.group(1);
        }
      }

      final int? receivedUid = result?['uid'] as int?;

      if (receivedUid != null && extractedSessionId != null) {
        _userId = receivedUid;
        _sessionId = extractedSessionId;
        _partnerId = result?['partner_id'] as int?;
        _currentPassword = password; // Guardamos la contraseña para execute_kw

        _userName = result?['name'] ?? "Usuario";
        _userRole = SalesRole.vendedor;

        await _fetchPartnerDetails();
      } else {
        throw Exception(
            'Respuesta de autenticación incompleta o inválida (Falta UID o Session ID en las cookies).');
      }
    } catch (e) {
      _userId = null;
      _sessionId = null;
      throw Exception(
          'Fallo de conexión o autenticación. Verifique las credenciales.');
    }
  }

  // 2. Método para obtener productos (Estable)
  Future<List<Product>> fetchProducts() async {
    if (!isAuthenticated) {
      if (_userName == "Invitado") {
        return Future.value([]);
      }
      throw Exception('No autenticado. Llama a authenticate() primero.');
    }

    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'product.template';
    const String method = 'search_read';

    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 1,
      "params": {
        "service": "object",
        "method": "execute_kw",
        "args": [
          _dbName,
          _userId,
          _currentPassword,
          model,
          method,
          [
            // Filtro activo = true
            [
              ["active", "=", true]
            ]
          ],
          {
            "fields": ["id", "name", "list_price", "image_1920"],
            "limit": 50
          }
        ],
        "session_id": _sessionId
      }
    };

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 15));

      final responseBody = json.decode(response.body);

      if (responseBody['error'] != null) {
        throw Exception(
            'Error en la API de Odoo: ${responseBody['error']['data']['message']}');
      }

      final result = responseBody['result'];

      if (result is bool && result == false) {
        return [];
      }

      final List<dynamic> productJsonList = result as List<dynamic>;

      return productJsonList
          .map((json) => Product.fromJson(json, _baseUrl))
          .toList();
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception(
            'Tiempo de espera agotado. La conexión es inestable o la respuesta es muy grande.');
      }
      throw Exception(
          'Error de conexión o datos en la consulta de productos: $e');
    }
  }

  // 3. Método para obtener clientes (res.partner) - ¡Método requerido!
  Future<List<Customer>> fetchCustomers() async {
    if (!isAuthenticated) {
      throw Exception('Acceso no autorizado.');
    }

    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'res.partner';
    const String method = 'search_read';

    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 5,
      "params": {
        "service": "object",
        "method": "execute_kw",
        "args": [
          _dbName,
          _userId,
          _currentPassword,
          model,
          method,
          [
            [
              [
                "customer_rank",
                ">",
                0
              ] // Filtro: Solo contactos marcados como clientes
            ]
          ],
          {
            "fields": ["id", "name", "email", "phone"],
            "limit": 100,
            "order": "name asc",
          }
        ],
        "session_id": _sessionId
      }
    };

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 15));

      final responseBody = json.decode(response.body);
      if (responseBody['error'] != null) {
        throw Exception(
            'Error al cargar clientes: ${responseBody['error']['data']['message']}');
      }
      final result = responseBody['result'];
      if (result is bool && result == false) return [];

      final List<dynamic> customerJsonList = result as List<dynamic>;
      return customerJsonList.map((json) => Customer.fromJson(json)).toList();
    } catch (e) {
      throw Exception('Error de conexión al cargar clientes: $e');
    }
  }

  // 4. Método FINAL: Crear Pedido de Venta (sale.order)
  Future<int> createSaleOrder(List<CartItem> cartItems,
      {int? customerPartnerId}) async {
    if (_partnerId == null) {
      throw Exception(
          'Error de Pedido: No se pudo obtener el Partner ID del vendedor.');
    }

    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'sale.order';
    const String method = 'create';

    final clientPartnerId = customerPartnerId ?? _partnerId;

    final List<List<dynamic>> orderLines = cartItems.map((item) {
      return [
        0,
        0,
        {
          'product_id': item.product.id,
          'product_uom_qty': item.quantity,
          'price_unit': item.product.price,
        }
      ];
    }).toList();

    final Map<String, dynamic> orderValues = {
      'partner_id': clientPartnerId,
      'user_id': _userId,
      'order_line': orderLines,
      'validity_date': DateTime.now()
          .add(const Duration(days: 7))
          .toIso8601String()
          .substring(0, 10),
      'pricelist_id': 1,
    };

    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 2,
      "params": {
        "service": "object",
        "method": "execute_kw",
        "args": [
          _dbName,
          _userId,
          _currentPassword,
          model,
          method,
          [orderValues],
        ],
        "session_id": _sessionId
      }
    };

    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: json.encode(payload),
          )
          .timeout(const Duration(seconds: 20));

      final responseBody = json.decode(response.body);

      if (responseBody['error'] != null) {
        throw Exception(
            'Error en Odoo al crear pedido: ${responseBody['error']['data']['message']}');
      }

      final int orderId = responseBody['result'] as int;
      return orderId;
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception(
            'Tiempo de espera agotado al crear el pedido. La conexión es lenta.');
      }
      throw Exception('Error de conexión al crear pedido: $e');
    }
  }
}
