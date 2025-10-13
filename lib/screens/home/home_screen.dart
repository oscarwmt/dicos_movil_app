// lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../api/odoo_api_client.dart';
import '../../models/product_model.dart';
import '../../models/customer_model.dart';
import '../../providers/cart_provider.dart';
import '../../screens/sale_order/new_order_screen.dart';
import '../../widgets/product_card.dart';

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
  final List<Product> _products = [];

  List<Map<String, dynamic>> _mainCategories = [];
  List<Map<String, dynamic>> _subCategories = [];

  late Future<List<Map<String, dynamic>>> _addressesFuture;
  int? _selectedAddressId;

  // ✅ CORRECCIÓN 1: La variable ahora es nulable para evitar el error 'late'.
  Future<Map<String, dynamic>>? _financialsFuture;

  bool _isLoading = true;
  bool _isLoadingMore = false;
  bool _hasMore = true;
  int _offset = 0;
  final int _limit = 40;

  int? _selectedMainCategoryId;
  String? _selectedMainCategoryName;
  int? _selectedSubCategoryId;

  @override
  void initState() {
    super.initState();
    _addressesFuture =
        widget.apiClient.fetchCustomerAddresses(widget.customer.id);
    _financialsFuture =
        widget.apiClient.fetchPartnerFinancials(widget.customer.id);
    _initializeData();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _fetchMainCategories();
    await _loadProducts(isRefresh: true);
  }

  Future<void> _fetchMainCategories() async {
    try {
      final fetchedCategories = await widget.apiClient.fetchCategories();
      if (mounted) setState(() => _mainCategories = fetchedCategories);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error al cargar categorías: ${e.toString()}")));
    }
  }

  Future<void> _fetchSubCategories(int parentId) async {
    try {
      final fetchedSubCategories =
          await widget.apiClient.fetchSubCategories(parentId);
      if (mounted) setState(() => _subCategories = fetchedSubCategories);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Error al cargar subcategorías: ${e.toString()}")));
    }
  }

  Future<void> _loadProducts({bool isRefresh = false}) async {
    if (isRefresh) {
      setState(() {
        _isLoading = true;
        _products.clear();
        _offset = 0;
        _hasMore = true;
      });
    }

    if (_isLoadingMore) return;

    setState(() => _isLoadingMore = true);

    try {
      final int? categoryToFilter =
          _selectedSubCategoryId ?? _selectedMainCategoryId;

      final newProducts = await widget.apiClient.fetchProducts(
        limit: _limit,
        offset: _offset,
        categoryId: categoryToFilter,
      );

      if (mounted) {
        setState(() {
          if (newProducts.length < _limit) _hasMore = false;
          _products.addAll(newProducts);
          _offset = _products.length;
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200 &&
        _hasMore &&
        !_isLoadingMore) {
      _loadProducts();
    }
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
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cambiar Cliente')),
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
                return Text('Error al cargar direcciones: ${snapshot.error}',
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

          // ✅ CORRECCIÓN 2: El FutureBuilder ahora maneja correctamente el caso nulo.
          FutureBuilder<Map<String, dynamic>>(
            future: _financialsFuture,
            builder: (context, snapshot) {
              // Si el future es nulo, es un error de inicialización
              if (_financialsFuture == null) {
                return const Text('Error al iniciar la carga de saldo.',
                    style: TextStyle(color: Colors.red, fontSize: 12));
              }
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Row(
                  children: [
                    SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2)),
                    SizedBox(width: 8),
                    Text('Cargando saldo...',
                        style: TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                );
              }
              if (snapshot.hasError) {
                return const Text('No se pudo cargar el saldo.',
                    style: TextStyle(color: Colors.red, fontSize: 12));
              }

              final financials = snapshot.data!;
              final credit = (financials['credit'] ?? 0.0).toDouble();
              final debit = (financials['debit'] ?? 0.0).toDouble();
              final balance = credit - debit;

              final currencyFormat = NumberFormat.currency(
                  locale: 'es_CL', symbol: '\$', decimalDigits: 0);
              final balanceText = currencyFormat.format(balance.abs());

              final Color balanceColor =
                  balance < 0 ? Colors.red.shade700 : Colors.green.shade800;
              final String balanceLabel =
                  balance < 0 ? 'Deuda Pendiente:' : 'Saldo a Favor:';

              return Row(
                children: [
                  Icon(Icons.monetization_on_outlined,
                      color: balanceColor, size: 20),
                  const SizedBox(width: 8),
                  Text(balanceLabel,
                      style:
                          const TextStyle(fontSize: 14, color: Colors.black54)),
                  Expanded(
                    child: Text(
                      ' $balanceText',
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: balanceColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMainCategoryFilter() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      color: Colors.white,
      child: DropdownButton<int?>(
        value: _selectedMainCategoryId,
        isExpanded: true,
        hint: const Text('Todas las Categorías',
            style: TextStyle(fontWeight: FontWeight.bold)),
        items: [
          const DropdownMenuItem<int?>(
              value: null, child: Text('Todas las Categorías')),
          ..._mainCategories.map((category) {
            return DropdownMenuItem<int?>(
              value: category['id'] as int?,
              child: Text(category['name'].toString()),
            );
          }).toList(),
        ],
        onChanged: (newValue) {
          setState(() {
            _selectedMainCategoryId = newValue;
            _selectedSubCategoryId = null;
            _subCategories.clear();

            if (newValue == null) {
              _selectedMainCategoryName = null;
            } else {
              final selected =
                  _mainCategories.firstWhere((cat) => cat['id'] == newValue);
              _selectedMainCategoryName = selected['name'].toString();
              _fetchSubCategories(newValue);
            }
            _loadProducts(isRefresh: true);
          });
        },
      ),
    );
  }

  Widget _buildSubCategoryChips() {
    if (_selectedMainCategoryId == null || _subCategories.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8),
      color: Colors.grey[100],
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ActionChip(
              label: Text('Todos ($_selectedMainCategoryName)'),
              backgroundColor: _selectedSubCategoryId == null
                  ? Theme.of(context).primaryColor
                  : Colors.white,
              labelStyle: TextStyle(
                  color: _selectedSubCategoryId == null
                      ? Colors.white
                      : Colors.black),
              onPressed: () {
                setState(() {
                  _selectedSubCategoryId = null;
                  _loadProducts(isRefresh: true);
                });
              },
            ),
            const SizedBox(width: 8),
            ..._subCategories.map((subCat) {
              final bool isSelected = _selectedSubCategoryId == subCat['id'];
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ActionChip(
                  label: Text(subCat['name']),
                  backgroundColor: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.white,
                  labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.black),
                  onPressed: () {
                    setState(() {
                      _selectedSubCategoryId = subCat['id'];
                      _loadProducts(isRefresh: true);
                    });
                  },
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Pedido'),
        actions: [
          Consumer<CartProvider>(
            builder: (ctx, cart, child) => Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.shopping_cart_checkout),
                  onPressed: () {
                    if (cart.itemCount > 0) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (ctx) => const NewOrderScreen()),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('El carrito está vacío.')));
                    }
                  },
                ),
                if (cart.itemCount > 0)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Colors.red,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints:
                          const BoxConstraints(minWidth: 16, minHeight: 16),
                      child: Text(
                        cart.itemCount.toString(),
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
          const Divider(height: 1, color: Colors.grey),
          _buildMainCategoryFilter(),
          _buildSubCategoryChips(),
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
                        itemCount: _products.length + (_hasMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i >= _products.length) {
                            return const Center(
                                child: CircularProgressIndicator());
                          }
                          return ProductCard(product: _products[i]);
                        },
                      ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (ctx) => const NewOrderScreen()),
          );
        },
        label: const Text('Ver Carrito'),
        icon: const Icon(Icons.shopping_cart),
      ),
    );
  }
}
