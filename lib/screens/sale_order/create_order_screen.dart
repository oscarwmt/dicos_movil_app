// lib/screens/sale_order/create_order_screen.dart

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

  const CreateOrderScreen({super.key, required this.customer});

  @override
  State<CreateOrderScreen> createState() => _CreateOrderScreenState();
}

class _CreateOrderScreenState extends State<CreateOrderScreen> {
  final OdooApiClient _apiClient = OdooApiClient();
  final ScrollController _scrollController = ScrollController();

  // Se inicializan aquí para que existan desde el principio
  late Future<List<Map<String, dynamic>>> _addressesFuture;
  late Future<List<Map<String, dynamic>>> _categoriesFuture;

  List<Product> _allProducts = [];
  List<Product> _filteredProducts = [];
  List<Map<String, dynamic>>? _categories;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  int? _selectedAddressId;
  int? _selectedCategoryId;
  final TextEditingController _searchController = TextEditingController();

  // --- INICIO DE LA CORRECCIÓN ---
  @override
  void initState() {
    super.initState();

    // 1. Asignamos los Futures de forma síncrona e inmediata.
    // Esto garantiza que no habrá un LateInitializationError.
    _addressesFuture = _apiClient.fetchCustomerAddresses(widget.customer.id);
    _categoriesFuture = _apiClient.fetchCategories();

    // 2. Cargamos la lista de productos de forma asíncrona.
    _loadInitialProducts();

    // 3. Añadimos los listeners.
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_filterProducts);
  }

  Future<void> _loadInitialProducts() async {
    // No es necesario llamar a setState aquí porque _isLoading ya es true por defecto
    try {
      final products = await _apiClient.fetchProducts(limit: 40);
      if (mounted) {
        setState(() {
          _allProducts = products;
          _filteredProducts = products;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar productos: $e')));
      }
    }
  }
  // --- FIN DE LA CORRECCIÓN ---

  Future<void> _loadMoreProducts() async {
    if (_isLoadingMore) return;
    setState(() {
      _isLoadingMore = true;
    });

    try {
      final newProducts = await _apiClient.fetchProducts(
          offset: _allProducts.length, limit: 40);
      if (mounted) {
        setState(() {
          _allProducts.addAll(newProducts);
          _filterProducts(); // Re-aplicar filtros
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingMore = false);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _loadMoreProducts();
    }
  }

  void _filterProducts() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredProducts = _allProducts.where((product) {
        final categoryName = _selectedCategoryId != null
            ? _getCategoryName(_selectedCategoryId!)
            : null;
        final matchesCategory =
            categoryName == null || product.category == categoryName;
        final matchesSearch =
            query.isEmpty || product.name.toLowerCase().contains(query);
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  String? _getCategoryName(int id) {
    if (_categories == null) {
      return null;
    }
    final category =
        _categories!.firstWhere((cat) => cat['id'] == id, orElse: () => {});
    return category.isNotEmpty ? category['name'] : null;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pedido para ${widget.customer.name}'),
        actions: [
          Consumer<CartProvider>(
            builder: (ctx, cart, child) => Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                          builder: (ctx) => const NewOrderScreen()),
                    );
                  },
                ),
                if (cart.items.isNotEmpty)
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
                      child: Text(
                        cart.items.length.toString(),
                        style:
                            const TextStyle(color: Colors.white, fontSize: 10),
                        textAlign: TextAlign.center,
                      ),
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
    );
  }

  Widget _buildOrderHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
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
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cambiar')),
            ],
          ),
          const Divider(),
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
              if (addresses.isEmpty) {
                return const Text('Cliente sin direcciones de entrega.');
              }
              return DropdownButtonFormField<int>(
                initialValue: _selectedAddressId,
                hint: const Text('Seleccione dirección de entrega...'),
                isExpanded: true,
                items: addresses.map((addr) {
                  return DropdownMenuItem(
                      value: addr['id'] as int,
                      child: Text('${addr['name']} (${addr['street'] ?? ''})',
                          overflow: TextOverflow.ellipsis));
                }).toList(),
                onChanged: (value) {
                  setState(() {
                    _selectedAddressId = value;
                  });
                },
              );
            },
          ),
          const SizedBox(height: 10),
          ListTile(
            leading: Icon(Icons.payment, color: Colors.grey.shade700),
            title: const Text('Plazo de Pago'),
            subtitle: Text(widget.customer.paymentTerm,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            contentPadding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  Widget _buildProductCatalog() {
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
                      } // Placeholder para mantener altura
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
                          setState(() {
                            _selectedCategoryId = value;
                            _filterProducts();
                          });
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
                : _filteredProducts.isEmpty
                    ? const Center(
                        child: Text(
                            'No se encontraron productos con el filtro actual.'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(10.0),
                        itemCount:
                            _filteredProducts.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == _filteredProducts.length) {
                            return const Center(
                                child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator()));
                          }
                          return ProductCard(product: _filteredProducts[i]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
