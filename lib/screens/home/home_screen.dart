// lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:dicos_movil_app/api/odoo_api_client.dart';
import 'package:dicos_movil_app/models/product_model.dart';
import 'package:dicos_movil_app/widgets/product_card.dart';
import 'package:dicos_movil_app/widgets/cart_icon_badge.dart';
import 'package:dicos_movil_app/widgets/category_tile.dart';
//import 'dart:collection';

class HomeScreen extends StatefulWidget {
  final OdooApiClient apiClient;

  const HomeScreen({super.key, required this.apiClient});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Future<List<Product>>? _productsFuture;

  List<Product> _products = [];
  String _selectedCategory = 'Todos';
  String _searchTerm = '';

  @override
  void initState() {
    super.initState();
    _initializeProducts();
  }

  void _initializeProducts() {
    setState(() {
      _productsFuture = _authenticateAndFetch();
    });
  }

  Future<List<Product>> _authenticateAndFetch() async {
    if (!widget.apiClient.isAuthenticated) {
      return Future.value([]);
    }

    final fetchedProducts = await widget.apiClient.fetchProducts();

    if (mounted) {
      setState(() {
        _products = fetchedProducts;
      });
    }

    return fetchedProducts;
  }

  Future<void> _refreshProducts() async {
    setState(() {
      _productsFuture = _authenticateAndFetch();
      _products = [];
      _selectedCategory = 'Todos';
      _searchTerm = '';
    });
  }

  List<String> get uniqueCategories {
    final categories = _products.map((p) => p.categoryName).toSet();
    final uniqueList = <String>{};
    uniqueList.add('Todos');
    uniqueList.addAll(
        categories.where((name) => name.isNotEmpty && name != 'Sin categoría'));
    return uniqueList.toList();
  }

  List<Product> get filteredProducts {
    var list = _products;

    if (_searchTerm.isNotEmpty) {
      list = list
          .where(
              (p) => p.name.toLowerCase().contains(_searchTerm.toLowerCase()))
          .toList();
    }

    if (_selectedCategory != 'Todos') {
      list = list.where((p) => p.categoryName == _selectedCategory).toList();
    }

    return list;
  }

  Widget _buildUserHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hola, ${widget.apiClient.userName.split(' ').first}',
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined,
                        size: 16, color: Colors.green[700]),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        widget.apiClient.deliveryAddress,
                        style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon:
                const Icon(Icons.account_circle, size: 36, color: Colors.green),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text(
                        'Perfil de ${widget.apiClient.userName} (${widget.apiClient.userEmail})')),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        onChanged: (value) {
          setState(() {
            _searchTerm = value;
            _selectedCategory = 'Todos';
          });
        },
        decoration: InputDecoration(
          hintText: 'Buscar productos...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.grey[100],
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildCategoryCarousel() {
    return Container(
      height: 100,
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: uniqueCategories.length,
        itemBuilder: (context, index) {
          final category = uniqueCategories[index];
          final isSelected = category == _selectedCategory;
          return CategoryTile(
            categoryName: category,
            isSelected: isSelected,
            onTap: () {
              setState(() {
                _selectedCategory = category;
                _searchTerm = '';
              });
            },
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Catálogo (${_products.length} productos)',
            style: const TextStyle(fontSize: 18)),
        centerTitle: true,
        elevation: 0,
        actions: const [
          CartIconBadge(),
        ],
      ),
      body: Column(
        children: [
          _buildUserHeader(),
          _buildSearchBar(),
          if (widget.apiClient.isAuthenticated) _buildCategoryCarousel(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshProducts,
              child: FutureBuilder<List<Product>>(
                future: _productsFuture,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting ||
                      _productsFuture == null) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError) {
                    final String errorMessage = snapshot.error
                        .toString()
                        .replaceFirst('Exception: ', '');
                    return Center(child: Text('¡Error! $errorMessage'));
                  }

                  if (snapshot.hasData || _products.isNotEmpty) {
                    final displayProducts = filteredProducts;

                    if (displayProducts.isEmpty) {
                      return Center(
                        child: Text(
                          widget.apiClient.isAuthenticated
                              ? (_searchTerm.isNotEmpty
                                  ? 'No se encontraron resultados para "$_searchTerm".'
                                  : 'No se encontraron productos.')
                              : 'Inicia sesión para ver el catálogo.',
                          style: const TextStyle(fontSize: 16),
                        ),
                      );
                    }

                    return GridView.builder(
                      padding: const EdgeInsets.all(12.0),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 12.0,
                        mainAxisSpacing: 12.0,
                        childAspectRatio: 0.7,
                      ),
                      itemCount: displayProducts.length,
                      itemBuilder: (context, index) {
                        return ProductCard(product: displayProducts[index]);
                      },
                    );
                  }

                  return const Center(child: Text('Iniciando...'));
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
