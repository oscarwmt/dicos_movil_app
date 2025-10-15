// lib/screens/sale_order/create_order_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/odoo_api_client.dart';
import '../../models/customer_model.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/product_card.dart';
import 'new_order_screen.dart';

class CreateOrderScreen extends StatefulWidget {
  final Customer customer;
  final bool isQuotation;

  const CreateOrderScreen({
    super.key,
    required this.customer,
    required this.isQuotation,
  });

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final OdooApiClient _apiClient = OdooApiClient();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  late Future<List<Map<String, dynamic>>> _addressesFuture;
  late Future<List<Map<String, dynamic>>> _categoriesFuture;
  List<Product> _products = [];
  List<Map<String, dynamic>>? _categories;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  int? _selectedAddressId;

  // ✅ NUEVOS CAMPOS DE ESTADO PARA LOS DATOS REQUERIDOS EN NewOrderScreen
  String _selectedAddressName = '';
  String _selectedAddressStreet = '';

  int? _selectedCategoryId;

  @override
  void initState() {
    super.initState();
    _addressesFuture = _apiClient.fetchCustomerAddresses(widget.customer.id);
    _categoriesFuture = _apiClient.fetchCategories();
    _fetchAndSetProducts();

    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _fetchAndSetProducts({bool loadMore = false}) async {
    if (loadMore && _isLoadingMore) return;

    if (loadMore) {
      setState(() {
        _isLoadingMore = true;
      });
    } else {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final domain = _buildDomain();
      final newProducts = await _apiClient.fetchProducts(
        offset: loadMore ? _products.length : 0,
        domain: domain,
      );

      if (mounted) {
        setState(() {
          if (loadMore) {
            _products.addAll(newProducts);
          } else {
            _products = newProducts;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  List<dynamic> _buildDomain() {
    final domain = [];
    final query = _searchController.text;
    if (query.isNotEmpty) {
      domain.add(['name', 'ilike', query]);
    }
    if (_selectedCategoryId != null) {
      domain.add(['categ_id', 'child_of', _selectedCategoryId]);
    }
    return domain;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _fetchAndSetProducts(loadMore: true);
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchAndSetProducts();
    });
  }

  Future<bool> _onWillPop() async {
    final cart = Provider.of<CartProvider>(context, listen: false);
    if (cart.totalUniqueItems == 0) return true;

    final currentContext = context;
    final shouldPop = await showDialog<bool>(
      context: currentContext,
      builder: (context) => AlertDialog(
        title: const Text('¿Descartar Pedido?'),
        content:
            const Text('Si sales ahora, los productos agregados se perderán.'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancelar')),
          TextButton(
            onPressed: () {
              cart.clear();
              Navigator.of(context).pop(true);
            },
            child: const Text('Descartar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.isQuotation ? 'Nueva Cotización' : 'Nuevo Pedido';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final bool shouldPop = await _onWillPop();
        if (shouldPop) {
          navigator.pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('$title para ${widget.customer.name}'),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => _fetchAndSetProducts(),
            ),
            Consumer<CartProvider>(
              builder: (ctx, cart, child) => Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart),
                    onPressed: () {
                      // 🚨 VALIDACIÓN DE DIRECCIÓN
                      if (_selectedAddressId == null ||
                          _selectedAddressId == 0) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'Debe seleccionar o asignar una dirección de entrega.'),
                            backgroundColor: Colors.orange));
                        return;
                      }

                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (ctx) => NewOrderScreen(
                          isQuotation: widget.isQuotation,
                          customer: widget.customer,
                          shippingAddressId: _selectedAddressId!,
                          // ✅ CORRECCIÓN CLAVE: Pasamos los nuevos argumentos requeridos
                          shippingAddressName: _selectedAddressName,
                          shippingAddressStreet: _selectedAddressStreet,
                        ),
                      ));
                    },
                  ),
                  if (cart.totalUniqueItems > 0)
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(10)),
                        constraints:
                            const BoxConstraints(minWidth: 16, minHeight: 16),
                        child: Text(cart.totalUniqueItems.toString(),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 10),
                            textAlign: TextAlign.center),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            _buildOrderHeader(),
            _buildProductCatalog(),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                  child: Text(widget.customer.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis)),
              TextButton(
                  onPressed: () {
                    Navigator.of(context).maybePop();
                  },
                  child: const Text('Cambiar')),
            ],
          ),
          const Divider(height: 16),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _addressesFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const LinearProgressIndicator();
              }
              if (snapshot.hasError) {
                return Text('Error: ${snapshot.error}',
                    style: const TextStyle(color: Colors.red));
              }

              final addresses = snapshot.data ?? [];
              final int mainPartnerId = widget.customer.id;

              // 🚨 FUNCIÓN PARA ENCONTRAR UN ADDRESS EN LA LISTA
              Map<String, dynamic> findAddress(int? id) {
                return addresses.firstWhere((addr) => addr['id'] == id,
                    orElse: () => {
                          'id': mainPartnerId,
                          'name': widget.customer.name,
                          'street': 'Dirección Principal (ID: $mainPartnerId)',
                        });
              }

              // ✅ LÓGICA DE ASIGNACIÓN INICIAL Y FALLBACK
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;

                if (addresses.isEmpty) {
                  // Caso 1: No hay direcciones secundarias, usar principal
                  if (_selectedAddressId == null ||
                      _selectedAddressId != mainPartnerId) {
                    setState(() {
                      _selectedAddressId = mainPartnerId;
                      _selectedAddressName = widget.customer.name;
                      _selectedAddressStreet = 'Dirección Principal';
                    });
                  }
                } else if (_selectedAddressId == null) {
                  // Caso 2: Hay direcciones secundarias y nada seleccionado, usar la primera
                  final firstAddr = findAddress(addresses.first['id'] as int);
                  setState(() {
                    _selectedAddressId = firstAddr['id'] as int;
                    _selectedAddressName = firstAddr['name'] ?? '';
                    _selectedAddressStreet = firstAddr['street'] ?? '';
                  });
                }
              });

              if (addresses.isEmpty) {
                return const Text('Usando dirección principal del cliente.',
                    style: TextStyle(
                        fontStyle: FontStyle.italic, color: Colors.blue));
              }

              // Preseleccionar el ID actual o el primer ID disponible
              final int initialId =
                  _selectedAddressId ?? addresses.first['id'] as int;

              return DropdownButtonFormField<int>(
                initialValue: initialId,
                hint: const Text('Seleccione dirección de entrega...'),
                isExpanded: true,
                items: addresses.map((addr) {
                  return DropdownMenuItem(
                      value: addr['id'] as int,
                      child: Text('${addr['name']} (${addr['street'] ?? ''})',
                          overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (value) {
                  final newSelection = findAddress(value);
                  setState(() {
                    _selectedAddressId = value;
                    _selectedAddressName = newSelection['name'] ?? '';
                    _selectedAddressStreet = newSelection['street'] ?? '';
                  });
                },
              );
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(Icons.payment, color: Colors.grey.shade700, size: 20),
              const SizedBox(width: 8),
              const Text('Plazo de Pago: ',
                  style: TextStyle(fontSize: 14, color: Colors.black54)),
              Expanded(
                child: Text(widget.customer.paymentTerm,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProductCatalog() {
    // ... (resto del método se mantiene sin cambios)
    return Expanded(
      child: Column(
        children: [
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                        labelText: 'Buscar producto...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8))),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _categoriesFuture,
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const SizedBox(height: 58);
                      }
                      _categories = snapshot.data!;
                      return DropdownButtonFormField<int>(
                        initialValue: _selectedCategoryId,
                        hint: const Text('Categoría'),
                        decoration: InputDecoration(
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8))),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<int>(
                              value: null, child: Text('Todas')),
                          ..._categories!.map((cat) {
                            return DropdownMenuItem(
                                value: cat['id'] as int,
                                child: Text(cat['name'],
                                    overflow: TextOverflow.ellipsis));
                          }),
                        ],
                        onChanged: (value) {
                          _selectedCategoryId = value;
                          _fetchAndSetProducts();
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(
                        child: Text(
                            'No se encontraron productos con el filtro actual.'))
                    : GridView.builder(
                        controller: _scrollController,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2 / 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        padding: const EdgeInsets.all(10.0),
                        itemCount: _products.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == _products.length) {
                            return const Center(
                                child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator()));
                          }
                          return ProductCard(product: _products[i]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
