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
  const CreateOrderScreen({super.key, required this.customer});

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
    if (loadMore && _isLoadingMore) {
      return;
    }

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
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
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
        title: Text('Pedido para ${widget.customer.name}'),
        actions: [
          Consumer<CartProvider>(
            builder: (ctx, cart, child) => Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart),
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (ctx) => const NewOrderScreen()));
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

  // --- INICIO DE LA MODIFICACIÓN ---
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
                    Navigator.of(context).pop();
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
          const SizedBox(height: 12),
          // Se reemplaza ListTile por un Row más compacto
          Row(
            children: [
              Icon(Icons.payment, color: Colors.grey.shade700, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Plazo de Pago: ',
                style: TextStyle(fontSize: 14, color: Colors.black54),
              ),
              Expanded(
                child: Text(
                  widget.customer.paymentTerm,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text('Info de créditos pendientes (Próximamente)',
              style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
  // --- FIN DE LA MODIFICACIÓN ---

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
