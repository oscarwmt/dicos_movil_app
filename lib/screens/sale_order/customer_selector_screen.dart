// lib/screens/sale_order/customer_selector_screen.dart

import 'package:flutter/material.dart';
import '../../api/odoo_api_client.dart';
import '../../models/customer_model.dart';
// ✅ CAMBIO 1: Importamos la nueva y correcta pantalla HomeScreen
import '../home/home_screen.dart';

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
    _customersFuture = _apiClient.fetchCustomers();
    _customersFuture.then((customers) {
      setState(() {
        _allCustomers = customers;
        _filteredCustomers = customers;
      });
    });
    _searchController.addListener(_filterCustomers);
  }

  void _filterCustomers() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      _filteredCustomers = _allCustomers.where((customer) {
        return customer.name.toLowerCase().contains(query);
      }).toList();
    });
  }

  // ✅ CAMBIO 2: La función ahora navega a HomeScreen y le pasa los parámetros necesarios.
  void _selectCustomer(Customer customer) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (ctx) => HomeScreen(
          apiClient: _apiClient, // Pasamos la instancia de la API
          customer: customer, // Pasamos el cliente seleccionado
        ),
      ),
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
                        leading: const Icon(Icons.person),
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
