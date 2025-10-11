// lib/screens/home/home_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../api/odoo_api_client.dart';
import '../../models/product_model.dart';
import '../../models/customer_model.dart'; // Importamos el modelo de cliente
import '../../providers/cart_provider.dart';
import '../../screens/sale_order/new_order_screen.dart'; // Corregida la ruta si es necesario
import '../../widgets/product_card.dart';

class HomeScreen extends StatefulWidget {
  final OdooApiClient apiClient;
  final Customer customer; // AÑADIDO: Recibimos el cliente seleccionado

  const HomeScreen({
    super.key,
    required this.apiClient,
    required this.customer, // AÑADIDO: Hacemos el cliente requerido
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Product>> _productsFuture;

  @override
  void initState() {
    super.initState();
    _productsFuture = widget.apiClient.fetchProducts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        // MODIFICADO: Mostramos el nombre del cliente en el título
        title: Text('Pedido para: ${widget.customer.name}'),
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
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
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
      body: FutureBuilder<List<Product>>(
        future: _productsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text('Error al cargar productos: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No se encontraron productos.'));
          }

          final products = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(10.0),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 2 / 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: products.length,
            itemBuilder: (ctx, i) => ProductCard(product: products[i]),
          );
        },
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
