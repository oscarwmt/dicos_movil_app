// lib/screens/sale_order/customer_selector_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../api/odoo_api_client.dart';
import '../../models/customer_model.dart';
import '../../providers/cart_provider.dart';
import 'create_order_screen.dart';

class CustomerSelectorScreen extends StatefulWidget {
  const CustomerSelectorScreen({super.key});

  @override
  State<CustomerSelectorScreen> createState() => _CustomerSelectorScreenState();
}

class _CustomerSelectorScreenState extends State<CustomerSelectorScreen> {
  final OdooApiClient _apiClient = OdooApiClient();
  late Future<List<Customer>> _customersFuture;
  List<Customer> _filteredCustomers = [];
  List<Customer> _allCustomers = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadCustomers();
    _searchController.addListener(_filterCustomers);
  }

  // --- LÓGICA MODIFICADA PARA PERMITIR RECARGA ---
  void _loadCustomers() {
    _customersFuture = _apiClient.fetchCustomers();
    _customersFuture.then((customers) {
      if (mounted) {
        setState(() {
          _allCustomers = customers;
          _filteredCustomers = customers;
          // Limpia la búsqueda anterior al recargar
          _searchController.clear();
        });
      }
    });
  }

  void _refreshCustomers() {
    setState(() {
      _loadCustomers();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Actualizando lista de clientes...'),
        duration: Duration(seconds: 1),
      ),
    );
  }
  // --- FIN DE LA MODIFICACIÓN ---

  void _filterCustomers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCustomers = _allCustomers.where((customer) {
        return customer.name.toLowerCase().contains(query);
      }).toList();
    });
  }

  void _selectCustomer(Customer customer) {
    final cart = Provider.of<CartProvider>(context, listen: false);
    cart.setCustomer(customer);

    if (customer.isBlocked) {
      _showBlockedCustomerDialog(customer);
    } else {
      _navigateToCreateOrder(customer, isQuotation: false);
    }
  }

  void _navigateToCreateOrder(Customer customer, {required bool isQuotation}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => CreateOrderScreen(
          customer: customer,
          isQuotation: isQuotation,
        ),
      ),
    );
  }

  Future<void> _showBlockedCustomerDialog(Customer customer) async {
    final currencyFormatter =
        NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
    final formattedDebt = currencyFormatter.format(customer.credit);

    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Cliente Bloqueado'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                const Text('Este cliente presenta deuda pendiente.'),
                const SizedBox(height: 10),
                Text(
                  'Deuda actual: $formattedDebt',
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, color: Colors.red),
                ),
                const SizedBox(height: 10),
                const Text(
                    'Puede continuar para generar una cotización, la cual quedará pendiente de aprobación.'),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cerrar'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Continuar a Cotización'),
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToCreateOrder(customer, isQuotation: true);
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paso 1: Seleccionar Cliente'),
        // --- BOTÓN DE ACTUALIZAR RESTAURADO ---
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshCustomers,
            tooltip: 'Actualizar Clientes',
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Buscar cliente por nombre...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
          Expanded(
            child: FutureBuilder<List<Customer>>(
              future: _customersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (_filteredCustomers.isEmpty) {
                  return const Center(
                      child: Text('No se encontraron clientes.'));
                }
                return ListView.builder(
                  itemCount: _filteredCustomers.length,
                  itemBuilder: (ctx, index) {
                    final customer = _filteredCustomers[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      child: ListTile(
                        leading: Icon(
                          customer.isBlocked
                              ? Icons.lock_outline
                              : Icons.person,
                          color: customer.isBlocked
                              ? Colors.red
                              : Theme.of(context).primaryColor,
                        ),
                        title: Text(customer.name),
                        subtitle: Text(customer.email),
                        onTap: () => _selectCustomer(customer),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
