// lib/screens/home/home_screen.dart

import 'dart:async';
import 'package:flutter/material.dart'; // Contiene debugPrint
import 'package:provider/provider.dart';
import '../../api/odoo_api_client.dart';
import '../../models/customer_model.dart';
import '../../models/product_model.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/product_card.dart';
// ⚠️ Importar CreateOrderScreen (ya que es la pantalla de destino con los argumentos)
import '../sale_order/create_order_screen.dart';
// import '../sale_order/new_order_screen.dart'; // No se usa directamente aquí

class HomeScreen extends StatefulWidget {
  final OdooApiClient apiClient;
  final Customer customer;

  const HomeScreen({
    super.key,
    required this.apiClient,
    required this.customer,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  // Propiedades de estado existentes
  late Future<List<Map<String, dynamic>>> _categoriesFuture;
  List<Product> _products = [];
  List<Map<String, dynamic>>? _categories;
  List<Map<String, dynamic>> _subCategories = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  int? _selectedCategoryId;
  int? _selectedSubCategoryId;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = widget.apiClient.fetchCategories();
    _fetchAndSetProducts();
    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  // Métodos de lógica del Home Screen
  Future<void> _fetchSubCategories(int parentId) async {
    try {
      final subCats = await widget.apiClient.fetchSubCategories(parentId);
      if (mounted) {
        setState(() {
          _subCategories = subCats;
        });
      }
    } catch (e) {
      if (mounted) {
        // ✅ CORRECCIÓN CLAVE: Reemplazar print() con debugPrint()
        debugPrint('Error fetching subcategories: $e');
      }
    }
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
      final newProducts = await widget.apiClient.fetchProducts(
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
    final categoryId = _selectedSubCategoryId ?? _selectedCategoryId;
    if (categoryId != null) {
      domain.add(['categ_id', 'child_of', categoryId]);
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

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pedido para: ${widget.customer.name}'),
        actions: [
          Consumer<CartProvider>(
            builder: (ctx, cart, child) => Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_checkout),
                  onPressed: () {
                    if (cart.totalUniqueItems > 0) {
                      // Corrección de Navegación (Línea 159)
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (ctx) => CreateOrderScreen(
                            customer: widget.customer,
                            isQuotation: false,
                          ),
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('El carrito está vacío.')));
                    }
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
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        cart.totalUniqueItems.toString(),
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
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(child: Text('No se encontraron productos.'))
                    : GridView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(10.0),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 2 / 3,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
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

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Buscar producto...',
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _categoriesFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const SizedBox.shrink();
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
                        ..._categories!.map((cat) => DropdownMenuItem(
                            value: cat['id'] as int,
                            child: Text(cat['name'],
                                overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                          _selectedSubCategoryId = null;
                          _subCategories = [];
                          if (value != null) {
                            _fetchSubCategories(value);
                          }
                        });
                        _fetchAndSetProducts();
                      },
                    );
                  },
                ),
              ),
              if (_subCategories.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _selectedSubCategoryId,
                    hint: const Text('Subcategoría'),
                    decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8))),
                    isExpanded: true,
                    items: _subCategories
                        .map((cat) => DropdownMenuItem(
                            value: cat['id'] as int,
                            child: Text(cat['name'],
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSubCategoryId = value;
                      });
                      _fetchAndSetProducts();
                    },
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
