// lib/api/odoo_api_client.dart

import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart'; // Importado para formateo de fechas
import '../models/product_model.dart';
import '../models/cart_item_model.dart';
import '../models/customer_model.dart';
import '../models/sale_order_model.dart';
import '../models/sale_order_line_model.dart';

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

  // --- COMIENZO DE TU CÓDIGO ORIGINAL (INTACTO) ---

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
      ],
      'limit': 2000,
      'order': "name asc",
    };

    // Código original sin _executeKw
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

  Future<List<int>> searchPartnerIdsByName(String name) async {
    if (!isAuthenticated || name.isEmpty) return [];
    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'res.partner';
    const String method = 'search_read';

    final Map<String, dynamic> kwargs = {
      'domain': [
        ['complete_name', 'ilike', name],
        ['customer_rank', '>', 0],
      ],
      'fields': ['id'],
      'limit': 50,
    };

    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 93,
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
          .timeout(const Duration(seconds: 15));
      final responseBody = json.decode(response.body);

      if (responseBody['error'] != null) {
        debugPrint(
            'Error searching partners: ${responseBody['error']['data']['message']}');
        return [];
      }

      final result = responseBody['result'];
      if (result is List) {
        return result.map((json) => json['id'] as int).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Connection error during partner search: $e');
      return [];
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

    final List<String> fields = [
      "id",
      "name",
      "list_price",
      "categ_id",
      "description_sale",
      "default_code",
      "qty_available",
      "x_studio_unidad_de_venta_nombre",
      "x_studio_unidades_por_paquete",
      "product_variant_id"
    ];

    final Map<String, dynamic> kwargs = {
      'domain': finalDomain,
      'fields': fields,
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

  Future<List<Product>> fetchCatalogProducts({
    int limit = 40,
    int offset = 0,
    List<dynamic> domain = const [],
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

    final List<String> fields = [
      "id",
      "name",
      "list_price",
      "categ_id",
      "description_sale",
      "default_code",
      "qty_available",
      "x_studio_unidad_de_venta_nombre",
      "x_studio_unidades_por_paquete",
      "product_variant_id",
      "x_studio_marca", // Campo de texto de marca
    ];

    final Map<String, dynamic> kwargs = {
      'domain': finalDomain,
      'fields': fields,
      'limit': limit,
      'offset': offset,
    };

    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 16,
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
            'Error en la API de Odoo (Catálogo): ${responseBody['error']['data']['message']}');
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
      throw Exception(
          'Error de conexión en la consulta de productos del catálogo: $e');
    }
  }

  // ✅ CORRECCIÓN DEFINITIVA: Obtener nombres únicos de marca usando read_group
  Future<List<String>> fetchDistinctBrandNames() async {
    if (!isAuthenticated) {
      throw Exception('No autenticado.');
    }
    const String model = 'product.template'; // Buscamos dentro de los productos
    const String method = 'read_group';

    final Map<String, dynamic> kwargs = {
      'domain': [
        ['sale_ok', '=', true],
        ['x_studio_marca', '!=', false], // Solo productos con marca definida
        ['x_studio_marca', '!=', ''] // Solo productos con marca no vacía
      ],
      'fields': ['x_studio_marca'], // El campo a leer
      'groupby': ['x_studio_marca'], // Agrupar por este campo
      'lazy': false, // Obtener todos los grupos
    };

    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 15, // ID de llamada
      "params": {
        "service": "object",
        "method": "execute_kw",
        "args": [_dbName, _userId, _currentPassword, model, method, [], kwargs],
        "session_id": _sessionId
      }
    };

    try {
      final response = await http.post(Uri.parse('$_baseUrl/jsonrpc'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
      final responseBody = json.decode(response.body);

      if (responseBody['error'] != null) {
        throw Exception(
            'Error al cargar marcas: ${responseBody['error']['data']['message']}');
      }

      final result = responseBody['result'];
      if (result is List) {
        return result
            .map((group) => group['x_studio_marca'])
            .where((brandName) => brandName is String && brandName.isNotEmpty)
            .map((brandName) => brandName as String)
            .toSet() // Usar Set para eliminar duplicados si read_group no lo hace
            .toList()
          ..sort(); // Ordenar
      }
      return [];
    } catch (e) {
      if (e.toString().contains("Invalid field 'x_studio_marca'")) {
        throw Exception(
            "El campo 'x_studio_marca' no existe en 'product.template'. Verifica el nombre técnico.");
      }
      throw Exception('Error al cargar nombres de marcas: $e');
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
      {required int customerPartnerId,
      required int shippingAddressId,
      bool isQuotation = false}) async {
    if (customerPartnerId == 0) {
      throw Exception('Error: No se ha seleccionado un cliente válido.');
    }

    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'sale.order';
    const String method = 'create';

    final List<List<dynamic>> orderLines = cartItems
        .map((item) {
          if (!isQuotation && item.product.stock <= 0) return null;
          return [
            0,
            0,
            {
              'product_id': item.product.id,
              'product_uom_qty': item.quantity,
            }
          ];
        })
        .whereType<List<dynamic>>()
        .toList();

    if (!isQuotation && orderLines.isEmpty && cartItems.isNotEmpty) {
      throw Exception(
          'No se puede crear un Pedido Confirmado solo con productos sin stock.');
    }

    final Map<String, dynamic> orderValues = {
      'partner_id': customerPartnerId,
      'partner_shipping_id': shippingAddressId,
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

      if (!isQuotation && orderLines.isNotEmpty) {
        await confirmSaleOrder(orderId);
      }

      final outOfStockItems =
          cartItems.where((item) => item.product.stock <= 0).toList();
      if (outOfStockItems.isNotEmpty) {
        reportOutOfStockDemand(outOfStockItems, customerPartnerId);
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

  Future<String> fetchProductsTemplateDetails(int templateId) async {
    if (!isAuthenticated || templateId == 0) return 'N/A';
    final url = Uri.parse('$_baseUrl/jsonrpc');
    const String model = 'product.template';
    const String method = 'read';

    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 92,
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
            [templateId]
          ],
          {
            "fields": ["x_studio_unidad_de_venta_nombre"],
          },
        ],
        "session_id": _sessionId
      }
    };
    try {
      final response = await http
          .post(url,
              headers: {'Content-Type': 'application/json'},
              body: json.encode(payload))
          .timeout(const Duration(seconds: 15));
      final responseBody = json.decode(response.body);

      if (responseBody['error'] != null) {
        debugPrint(
            'Error al obtener unidad de venta: ${responseBody['error']['data']['message']}');
        return 'N/A';
      }

      final result = responseBody['result'];
      if (result is List && result.isNotEmpty) {
        final dynamic rawValue =
            result.first['x_studio_unidad_de_venta_nombre'];

        if (rawValue is List && rawValue.length > 1 && rawValue[1] is String) {
          return rawValue[1].toString();
        }
        return rawValue?.toString() ?? 'N/A';
      }
      return 'N/A';
    } catch (e) {
      debugPrint('Fallo de conexión al obtener unidad de venta: $e');
      return 'N/A';
    }
  }

  Future<void> reportOutOfStockDemand(
      List<CartItem> items, int partnerId) async {
    if (!isAuthenticated || items.isEmpty) return;
    const String model = 'x_demanda_de_producto_';
    const String method = 'create';
    final List<Map<String, dynamic>> recordsToCreate = [];
    for (var item in items) {
      final int productId = item.product.id;
      recordsToCreate.add({
        'x_name': 'Demanda App: ${item.product.name} (Vendedor: $_userName)',
        'x_studio_cliente': partnerId,
        'x_studio_producto_1': productId,
        'x_studio_cantidad_solicitada': item.quantity,
        'x_studio_vendedor': _userId,
      });
    }
    if (recordsToCreate.isEmpty) return;

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
          [recordsToCreate]
        ],
        "session_id": _sessionId
      }
    };
    try {
      final response = await http.post(Uri.parse('$_baseUrl/jsonrpc'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(payload));
      final responseBody = json.decode(response.body);
      if (responseBody['error'] != null) {
        debugPrint(
            'Error al crear registro de demanda en Odoo. El modelo $model debe existir: ${responseBody['error']['data']['message']}');
      } else {
        debugPrint(
            'Demanda de productos registrada en el modelo $model para análisis.');
      }
    } catch (e) {
      debugPrint('Fallo de conexión al registrar demanda: $e');
    }
  }

  Future<List<SaleOrder>> fetchSaleOrders({
    required List<dynamic> domain,
    String orderBy = "date_order desc",
  }) async {
    if (!isAuthenticated) throw Exception('Acceso no autorizado.');
    const String model = 'sale.order';
    const String method = 'search_read';
    final List<dynamic> finalDomain = [
      ['user_id', '=', _userId],
      ...domain
    ];
    final Map<String, dynamic> kwargs = {
      'domain': finalDomain,
      'fields': [
        "id",
        "name",
        "partner_id",
        "date_order",
        "amount_untaxed",
        "amount_tax",
        "amount_total",
        "state",
        "partner_shipping_id"
      ],
      'limit': 500,
      'order': orderBy,
    };

    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 90,
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
          .post(Uri.parse('$_baseUrl/jsonrpc'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(payload))
          .timeout(const Duration(seconds: 30));
      final responseBody = json.decode(response.body);

      if (responseBody['error'] != null) {
        throw Exception(
            'Error al cargar ventas: ${responseBody['error']['data']['message']}');
      }

      final result = responseBody['result'];
      if (result is List) {
        return result
            .map((json) => SaleOrder.fromJson(json as Map<String, dynamic>))
            .toList();
      }
      return [];
    } catch (e) {
      throw Exception('Error de conexión al cargar el listado de ventas: $e');
    }
  }

  Future<List<SaleOrderLine>> fetchSaleOrderLines(int orderId) async {
    if (!isAuthenticated) throw Exception('Acceso no autorizado.');
    const String model = 'sale.order.line';
    const String method = 'search_read';
    final Map<String, dynamic> kwargs = {
      'domain': [
        ['order_id', '=', orderId]
      ],
      'fields': [
        "id",
        "product_id",
        "product_uom_qty",
        "price_unit",
        "price_subtotal",
        "product_uom_id", // ✅ CORRECCIÓN: Este es el nombre correcto
        "product_template_id",
      ],
      'limit': 100,
    };

    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": 91,
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
          .post(Uri.parse('$_baseUrl/jsonrpc'),
              headers: {'Content-Type': 'application/json'},
              body: json.encode(payload))
          .timeout(const Duration(seconds: 30));
      final responseBody = json.decode(response.body);

      if (responseBody['error'] != null) {
        throw Exception(
            'Error al cargar líneas de pedido: ${responseBody['error']['data']['message']}');
      }

      final List<dynamic> results = responseBody['result'] ?? [];
      final List<SaleOrderLine> finalLines = [];
      for (var json in results) {
        final Map<String, dynamic> lineJson = json as Map<String, dynamic>;
        final templateData = lineJson['product_template_id'] as List<dynamic>?;
        final templateId = (templateData != null &&
                templateData.isNotEmpty &&
                templateData[0] is int)
            ? templateData[0] as int
            : 0;
        String salesUnit = 'N/A';
        if (templateId != 0) {
          salesUnit = await fetchProductsTemplateDetails(templateId);
        }
        finalLines
            .add(SaleOrderLine.fromJson(lineJson, customSalesUnit: salesUnit));
      }
      return finalLines;
    } catch (e) {
      throw Exception('Error de conexión al cargar el detalle del pedido: $e');
    }
  }

  // --- NUEVAS FUNCIONES PARA EL MÓDULO CRM (AÑADIDAS AL FINAL) ---

  // (Función auxiliar _executeKwCrm movida al final)

  Future<List<Map<String, dynamic>>> fetchActivities({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    if (!isAuthenticated) throw Exception('No autenticado.');
    final DateFormat formatter = DateFormat('yyyy-MM-dd');
    final String start = formatter.format(startDate);
    final String end = formatter.format(endDate);
    const String model = 'mail.activity';
    const String method = 'search_read';
    final List<dynamic> domain = [
      ['user_id', '=', _userId],
      ['date_deadline', '>=', start],
      ['date_deadline', '<=', end],
    ];
    final Map<String, dynamic> kwargs = {
      'domain': domain,
      'fields': [
        'id',
        'summary',
        'note',
        'date_deadline',
        'res_model',
        'res_id',
        'res_name',
        'activity_type_id',
        'state',
        'x_studio_checkin_datetime',
        'x_studio_checkout_datetime',
        'x_studio_checkin_lat',
        'x_studio_checkin_lon',
        'x_studio_visit_duration',
      ],
      'order': 'date_deadline asc',
    };
    final result = await _executeKwCrm(model, method, kwargs: kwargs, id: 20);
    if (result is List) {
      return List<Map<String, dynamic>>.from(result);
    }
    return [];
  }

  Future<void> markActivityCheckIn({
    required int activityId,
    required DateTime checkInTime,
    required double latitude,
    required double longitude,
  }) async {
    const String model = 'mail.activity';
    const String method = 'write';
    final String formattedTime =
        DateFormat("yyyy-MM-dd HH:mm:ss").format(checkInTime.toUtc());
    final List<dynamic> args = [
      [activityId],
      {
        'x_studio_checkin_datetime': formattedTime,
        'x_studio_checkin_lat': latitude,
        'x_studio_checkin_lon': longitude,
      }
    ];
    await _executeKwCrm(model, method, args: args, id: 21);
  }

  Future<void> markActivityCheckOut({
    required int activityId,
    required DateTime checkOutTime,
  }) async {
    const String model = 'mail.activity';
    const String method = 'write';
    final String formattedTime =
        DateFormat("yyyy-MM-dd HH:mm:ss").format(checkOutTime.toUtc());
    final List<dynamic> args = [
      [activityId],
      {'x_studio_checkout_datetime': formattedTime}
    ];
    await _executeKwCrm(model, method, args: args, id: 22);
    await markActivityDone(
        activityId: activityId, feedback: 'Visita finalizada desde app móvil.');
  }

  Future<void> markActivityDone(
      {required int activityId, String? feedback}) async {
    const String model = 'mail.activity';
    const String method = 'action_feedback';
    List<dynamic> args = [
      [activityId]
    ];
    Map<String, dynamic> kwargs = {};
    if (feedback != null && feedback.isNotEmpty) {
      kwargs['feedback'] = feedback;
    }
    await _executeKwCrm(model, method, args: args, kwargs: kwargs, id: 23);
  }

  // --- Función Auxiliar Genérica (SOLO PARA LAS FUNCIONES DE CRM) ---
  Future<dynamic> _executeKwCrm(String model, String method,
      {List<dynamic>? args,
      Map<String, dynamic>? kwargs,
      required int id}) async {
    if (!isAuthenticated) throw Exception('No autenticado.');

    final url = Uri.parse('$_baseUrl/jsonrpc');
    final List<dynamic> finalArgs = args ?? [];
    final Map<String, dynamic> finalKwargs = kwargs ?? {};

    final payload = {
      "jsonrpc": "2.0",
      "method": "call",
      "id": id,
      "params": {
        "service": "object",
        "method": "execute_kw",
        "args": [
          _dbName,
          _userId,
          _currentPassword,
          model,
          method,
          finalArgs,
          finalKwargs
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
          .timeout(const Duration(seconds: 60));

      Map<String, dynamic> responseBody;
      try {
        responseBody = json.decode(response.body);
      } catch (e) {
        throw Exception('Error al decodificar la respuesta del servidor.');
      }

      if (responseBody['error'] != null) {
        final errorData = responseBody['error']['data'];
        final errorMessage =
            errorData['message'] ?? 'Error desconocido desde Odoo.';
        throw Exception('Error en API ($model/$method): $errorMessage');
      }
      return responseBody['result'];
    } catch (e) {
      if (e is TimeoutException) {
        throw Exception(
            'Error de conexión en ($model/$method): Tiempo de espera agotado.');
      }
      rethrow;
    }
  }
} // Fin de la clase OdooApiClient
