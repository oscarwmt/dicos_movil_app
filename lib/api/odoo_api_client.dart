// lib/api/odoo_api_client.dart

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import '../models/customer_model.dart';

enum SalesRole { vendedor, verTodasLasVentas, administradorVentas, invitado }

class OdooApiClient {
  static final OdooApiClient _instance = OdooApiClient._internal();
  factory OdooApiClient() => _instance;
  OdooApiClient._internal();

  final String _baseUrl = "https://dicos-v1.odoo.com";
  final String _dbName = "dicos-v1";
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

  Future<Map<String, dynamic>> fetchUserDetails() async {
    if (!isAuthenticated) {
      throw Exception('No autenticado.');
    }
    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'res.users';
    const String method = 'search_read';
    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 4,
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
              ["id", "=", _userId]
            ]
          ],
          {
            "fields": ["name", "sale_team_id"],
            "limit": 1
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
      if (responseBody['error'] != null) {
        throw Exception(
            'Error en Odoo: ${responseBody['error']['data']['message']}');
      }
      final result = responseBody['result'];
      if (result is List && result.isNotEmpty) {
        return result.first as Map<String, dynamic>;
      } else {
        throw Exception('No se encontraron datos para el usuario: $_userId');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

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
      // Intencionalmente vacío
    }
  }

  Future<void> authenticate(
      {required String login, required String password}) async {
    final url = Uri.parse('$_baseUrl/web/session/authenticate');
    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "params": {"db": _dbName, "login": login, "password": password}
    };
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );
      final responseBody = json.decode(response.body);
      if (responseBody['error'] != null) {
        final errorMessageDetail =
            responseBody['error']['data']['message'] ?? 'Error desconocido.';
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
        _currentPassword = password;
        _userName = result?['name'] ?? "Usuario";
        _userRole = SalesRole.vendedor;
        await _fetchPartnerDetails();
      } else {
        throw Exception('Respuesta de autenticación incompleta.');
      }
    } catch (e) {
      _userId = null;
      _sessionId = null;
      throw Exception('Fallo de conexión o autenticación.');
    }
  }

  Future<List<Product>> fetchProducts({
    int limit = 40,
    int offset = 0,
    int? categoryId,
    String? searchQuery,
  }) async {
    if (!isAuthenticated) {
      throw Exception('No autenticado.');
    }
    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'product.product';
    const String method = 'search_read';

    final List<dynamic> domain = [
      ['sale_ok', '=', true]
    ];
    if (categoryId != null) {
      domain.add(['categ_id', 'child_of', categoryId]);
    }
    if (searchQuery != null && searchQuery.isNotEmpty) {
      domain.add(['name', 'ilike', searchQuery]);
    }

    final Map<String, dynamic> kwargs = {
      'domain': domain,
      'fields': [
        "id",
        "name",
        "list_price",
        "categ_id",
        "description_sale",
        "product_tmpl_id",
        "default_code",
        "qty_available"
      ],
      'limit': limit,
      'offset': offset,
    };
    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 1,
      "params": {
        "service": "object",
        "method": "execute_kw",
        "args": [_dbName, _userId, _currentPassword, model, method, [], kwargs],
        "session_id": _sessionId
      }
    };
    try {
      final response = await http
          .post(url,
              headers: {'Content-Type': 'application/json'},
              body: json.encode(payload))
          .timeout(const Duration(seconds: 30));
      final responseBody = json.decode(response.body);
      if (responseBody['error'] != null) {
        throw Exception(
            'Error en la API de Odoo: ${responseBody['error']['data']['message']}');
      }
      final result = responseBody['result'];
      if (result is List) {
        return result.map((json) {
          final templateId = json['product_tmpl_id'] is List
              ? json['product_tmpl_id'][0]
              : json['id'];
          return Product.fromJson(json, templateId: templateId);
        }).toList();
      }
      return [];
    } catch (e) {
      throw Exception('Error de conexión en la consulta de productos: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCategories() async {
    if (!isAuthenticated) {
      throw Exception('No autenticado.');
    }
    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'product.category';
    const String method = 'search_read';
    final Map<String, dynamic> kwargs = {
      'domain': [
        ['parent_id', '=', false]
      ],
      'fields': ['id', 'name'],
      'order': 'name asc',
    };
    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 7,
      "params": {
        "service": "object",
        "method": "execute_kw",
        "args": [_dbName, _userId, _currentPassword, model, method, [], kwargs],
        "session_id": _sessionId
      }
    };
    try {
      final response = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
      final responseBody = json.decode(response.body);
      if (responseBody['error'] != null) {
        throw Exception(
            'Error al cargar categorías: ${responseBody['error']['data']['message']}');
      }
      final result = responseBody['result'];
      if (result is List) {
        return List<Map<String, dynamic>>.from(result);
      }
      return [];
    } catch (e) {
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> fetchSubCategories(int parentId) async {
    if (!isAuthenticated) {
      throw Exception('No autenticado.');
    }
    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'product.category';
    const String method = 'search_read';
    final Map<String, dynamic> kwargs = {
      'domain': [
        ['parent_id', '=', parentId]
      ],
      'fields': ['id', 'name'],
      'order': 'name asc',
    };
    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 8,
      "params": {
        "service": "object",
        "method": "execute_kw",
        "args": [_dbName, _userId, _currentPassword, model, method, [], kwargs],
        "session_id": _sessionId
      }
    };
    try {
      final response = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
      final responseBody = json.decode(response.body);
      if (responseBody['error'] != null) {
        throw Exception(
            'Error al cargar subcategorías: ${responseBody['error']['data']['message']}');
      }
      final result = responseBody['result'];
      if (result is List) {
        return List<Map<String, dynamic>>.from(result);
      }
      return [];
    } catch (e) {
      throw Exception('Error de conexión al cargar subcategorías: $e');
    }
  }

  Future<List<Customer>> fetchCustomers() async {
    if (!isAuthenticated) {
      throw Exception('Acceso no autorizado.');
    }
    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'res.partner';
    const String method = 'search_read';
    final Map<String, dynamic> kwargs = {
      'domain': [
        ['customer_rank', '>', 0],
        ['user_id', '=', _userId],
      ],
      // ✅ CAMBIO: Pedimos tu campo personalizado 'x_studio_bloqueado_deuda'.
      'fields': [
        "id",
        "name",
        "email",
        "phone",
        "property_payment_term_id",
        "x_studio_bloqueado_deuda"
      ],
      'limit': 200,
      'order': "name asc",
    };
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
          [],
          kwargs,
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
            'Error al cargar clientes: ${responseBody['error']['data']['message']}');
      }
      final result = responseBody['result'];
      if (result is List) {
        final List<dynamic> customerJsonList = result;
        return customerJsonList.map((json) => Customer.fromJson(json)).toList();
      } else {
        return [];
      }
    } catch (e) {
      throw Exception('Error de conexión al cargar clientes: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchCustomerAddresses(
      int partnerId) async {
    if (!isAuthenticated) {
      throw Exception('Acceso no autorizado.');
    }
    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'res.partner';
    const String method = 'search_read';
    final Map<String, dynamic> kwargs = {
      'domain': [
        ['parent_id', '=', partnerId],
        ['type', '=', 'delivery'],
      ],
      'fields': ['id', 'name', 'street', 'city'],
    };
    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 6,
      "params": {
        "service": "object",
        "method": "execute_kw",
        "args": [_dbName, _userId, _currentPassword, model, method, [], kwargs],
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
      if (responseBody['error'] != null) {
        throw Exception(
            'Error al cargar direcciones: ${responseBody['error']['data']['message']}');
      }
      final result = responseBody['result'];
      if (result is List) {
        return List<Map<String, dynamic>>.from(result);
      } else {
        return [];
      }
    } catch (e) {
      throw Exception('Error de conexión al cargar direcciones: $e');
    }
  }

  Future<int> createSaleOrder(List<CartItem> cartItems,
      {int? customerPartnerId}) async {
    if (customerPartnerId == null) {
      throw Exception(
          'Error de Pedido: No se ha seleccionado un cliente o dirección de entrega.');
    }
    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'sale.order';
    const String method = 'create';
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
      'partner_id': customerPartnerId,
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
        throw Exception('Tiempo de espera agotado al crear el pedido.');
      }
      throw Exception('Error de conexión al crear pedido: $e');
    }
  }

  Future<Map<String, dynamic>> fetchPartnerFinancials(int partnerId) async {
    if (!isAuthenticated) {
      throw Exception('No autenticado.');
    }
    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'res.partner';
    const String method = 'read';

    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 9,
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
            [partnerId]
          ],
          {
            "fields": ["credit", "debit"],
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
      if (responseBody['error'] != null) {
        throw Exception(
            'Error al cargar datos financieros: ${responseBody['error']['data']['message']}');
      }
      final result = responseBody['result'];
      if (result is List && result.isNotEmpty) {
        return result.first as Map<String, dynamic>;
      } else {
        throw Exception('No se encontraron datos financieros para el cliente.');
      }
    } catch (e) {
      throw Exception('Error de conexión al cargar datos financieros: $e');
    }
  }
}
