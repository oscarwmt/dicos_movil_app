// lib/api/odoo_api_client.dart

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import '../models/customer_model.dart';

enum SalesRole { vendedor, administradorVentas }

class OdooApiClient {
  static final OdooApiClient _instance = OdooApiClient._internal();
  factory OdooApiClient() => _instance;
  OdooApiClient._internal();

  final String _baseUrl = "https://pruebas-aplicacion.odoo.com";
  final String _dbName = "pruebas-aplicacion";
  int? _userId;
  String? _sessionId;
  String _currentPassword = "";
  String _userName = "Invitado";
  SalesRole _userRole = SalesRole.vendedor;

  String get userName => _userName;
  bool get isAuthenticated => _userId != null && _sessionId != null;
  SalesRole get userRole => _userRole;

  Future<bool> _checkUserGroup(String xmlId) async {
    if (!isAuthenticated) return false;
    final url = Uri.parse('$_baseUrl/jsonrpc');
    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 99,
      "params": {
        "service": "object",
        "method": "execute_kw",
        "args": [
          _dbName,
          _userId,
          _currentPassword,
          'res.users',
          'has_group',
          [xmlId]
        ],
        "kwargs": {},
        "session_id": _sessionId
      }
    };
    try {
      final response = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
      final responseBody = json.decode(response.body);
      if (responseBody['error'] != null) return false;
      return responseBody['result'] as bool;
    } catch (e) {
      return false;
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
        _currentPassword = password;
        _userName = result?['name'] ?? "Usuario";

        bool isSalesAdmin =
            await _checkUserGroup('sales_team.group_sale_manager');
        bool isSystemAdmin = await _checkUserGroup('base.group_system');

        if (isSalesAdmin || isSystemAdmin || _userId == 2) {
          _userRole = SalesRole.administradorVentas;
        } else {
          _userRole = SalesRole.vendedor;
        }
      } else {
        throw Exception('Respuesta de autenticación incompleta.');
      }
    } catch (e) {
      _userId = null;
      _sessionId = null;
      throw Exception('Fallo de conexión o autenticación.');
    }
  }

  Future<List<Customer>> fetchCustomers() async {
    if (!isAuthenticated) {
      throw Exception('Acceso no autorizado.');
    }
    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'res.partner';
    const String method = 'search_read';

    List<dynamic> domain = [
      ['customer_rank', '>', 0]
    ];
    if (_userRole == SalesRole.vendedor) {
      domain.add(['user_id', '=', _userId]);
    }

    final Map<String, dynamic> kwargs = {
      'domain': domain,
      'fields': [
        "id",
        "name",
        "email",
        "phone",
        "property_payment_term_id",
        "x_studio_bloqueado_deuda",
        "credit"
        // TODO: Asegúrate de añadir "property_product_pricelist" si lo vas a usar
      ],
      'limit': 2000,
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
          .post(url,
              headers: {'Content-Type': 'application/json'},
              body: json.encode(payload))
          .timeout(const Duration(seconds: 45));
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

  Future<List<Product>> fetchProducts({
    int limit = 40,
    int offset = 0,
    List<dynamic> domain = const [],
    int? pricelistId,
  }) async {
    if (!isAuthenticated) {
      throw Exception('No autenticado.');
    }
    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'product.template';
    const String method = 'search_read';
    final finalDomain = [
      ['sale_ok', '=', true],
      ...domain
    ];

    final Map<String, dynamic> kwargs = {
      'domain': finalDomain,
      'fields': [
        "id",
        "name",
        "list_price",
        "categ_id",
        "description_sale",
        "default_code",
        "qty_available",
        "x_studio_unidad_de_venta_nombre",
        "x_studio_unidades_por_paquete"
      ],
      'limit': limit,
      'offset': offset,
    };

    if (pricelistId != null) {
      kwargs['context'] = {'pricelist': pricelistId};
    }

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
          final templateId = json['id'];
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
      {required int customerPartnerId, // Cliente principal
      required int shippingAddressId, // <--- ID de la dirección de entrega
      bool isQuotation = false}) async {
    // <--- Indica si debe ser solo cotización

    if (customerPartnerId == 0) {
      throw Exception('Error: No se ha seleccionado un cliente válido.');
    }
    if (shippingAddressId == 0) {
      throw Exception('Error: Debe seleccionar una dirección de entrega.');
    }

    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'sale.order';
    const String method = 'create';

    // 1. CREACIÓN DE LÍNEAS DE PEDIDO (Solo ID de Producto y Cantidad)
    final List<List<dynamic>> orderLines = cartItems.map((item) {
      return [
        0, // Comando 0: CREATE
        0, // ID temporal
        {
          'product_id': item.product.id,
          'product_uom_qty': item.quantity,
          // Odoo calcula el precio (price_unit)
        }
      ];
    }).toList();

    // 2. VALORES DEL ENCABEZADO DEL PEDIDO
    final Map<String, dynamic> orderValues = {
      'partner_id': customerPartnerId,
      'partner_shipping_id': shippingAddressId, // <--- Dirección de envío
      'user_id': _userId,
      'order_line': orderLines,
      'validity_date': DateTime.now()
          .add(const Duration(days: 7))
          .toIso8601String()
          .substring(0, 10),
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

      // 3. CONFIRMACIÓN CONDICIONAL
      if (!isQuotation) {
        // Si el cliente NO está bloqueado, CONFIRMAMOS inmediatamente
        await confirmSaleOrder(orderId);
      }

      return orderId;
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception('Tiempo de espera agotado.');
      }
      throw Exception('Error de conexión al crear pedido: $e');
    }
  }

  Future<void> confirmSaleOrder(int orderId) async {
    if (!isAuthenticated) throw Exception('No autenticado.');
    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'sale.order';
    const String method = 'action_confirm';
    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 12,
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
            [orderId]
          ]
        ],
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
            'Error en Odoo al confirmar el pedido: ${responseBody['error']['data']['message']}');
      }
    } catch (e) {
      throw Exception('Error de conexión al confirmar el pedido: $e');
    }
  }

  // ... (El resto de las funciones auxiliares se mantienen sin cambios) ...

  // ...
  Future<void> reportOutOfStockDemand(
      List<CartItem> items, int partnerId) async {
    if (!isAuthenticated || items.isEmpty) return;
    String description =
        'El cliente solicitó los siguientes productos sin stock:\n';
    for (var item in items) {
      description +=
          '- ${item.product.name} (Ref: ${item.product.internalReference}) - Cantidad solicitada: ${item.quantity}\n';
    }
    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'mail.activity';
    const String method = 'create';
    final Map<String, dynamic> values = {
      'activity_type_id': 4,
      'summary': 'Demanda de Productos sin Stock',
      'note': description,
      'res_model_id': await _getModelId('res.partner'),
      'res_id': partnerId,
      'user_id': _userId,
    };
    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 10,
      "params": {
        "service": "object",
        "method": "execute_kw",
        "args": [
          _dbName,
          _userId,
          _currentPassword,
          model,
          method,
          [values]
        ],
        "session_id": _sessionId
      }
    };
    try {
      final response = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
      final responseBody = json.decode(response.body);
      if (responseBody['error'] != null) {
        // No se lanza excepción
      }
    } catch (e) {
      // No se lanza excepción
    }
  }

  Future<int?> _getModelId(String modelName) async {
    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'ir.model';
    const String method = 'search_read';
    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 11,
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
              ['model', '=', modelName]
            ]
          ],
          {
            'fields': ['id'],
            'limit': 1
          }
        ],
        "session_id": _sessionId
      }
    };
    try {
      final response = await http.post(url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
      final responseBody = json.decode(response.body);
      if (responseBody['error'] != null) return null;
      final result = responseBody['result'];
      if (result is List && result.isNotEmpty) {
        return result.first['id'] as int;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
