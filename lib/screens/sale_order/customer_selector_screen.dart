// lib/screens/sale_order/customer_selector_screen.dart

import 'package:flutter/material.dart';
import '../../api/odoo_api_client.dart';
import '../../models/customer_model.dart';

class CustomerSelectorScreen extends StatefulWidget {
  const CustomerSelectorScreen({super.key});

  @override
  State<CustomerSelectorScreen> createState() => _CustomerSelectorScreenState();
}

class _CustomerSelectorScreenState extends State<CustomerSelectorScreen> {
  final OdooApiClient _apiClient = OdooApiClient();
  late Future<List<Customer>> _customersFuture;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _customersFuture = _apiClient.fetchCustomers();
  }

  // Filtro de clientes basado en la búsqueda
  Future<List<Customer>> _filterCustomers(String searchTerm) async {
    final allCustomers = await _customersFuture;
    if (searchTerm.isEmpty) return allCustomers;

    final lowerCaseSearch = searchTerm.toLowerCase();
    return allCustomers.where((customer) {
      return customer.name.toLowerCase().contains(lowerCaseSearch) ||
          customer.email.toLowerCase().contains(lowerCaseSearch) ||
          customer.phone.contains(searchTerm);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seleccionar Cliente'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              onChanged: (value) {
                setState(() {
                  // Esto fuerza la reconstrucción del FutureBuilder para aplicar el filtro
                });
              },
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, email o teléfono...',
                prefixIcon: const Icon(Icons.search),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Customer>>(
        future: _filterCustomers(_searchController.text),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
                child: Text(
                    'Error al cargar clientes: ${snapshot.error.toString()}'));
          }
          if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return const Center(child: Text('No se encontraron clientes.'));
          }

          final customers = snapshot.data!;
          return ListView.builder(
            itemCount: customers.length,
            itemBuilder: (ctx, i) {
              final customer = customers[i];
              return ListTile(
                leading: const Icon(Icons.person_pin),
                title: Text(customer.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${customer.email} | ${customer.phone}'),
                onTap: () {
                  // Retorna el cliente seleccionado a la pantalla anterior
                  Navigator.of(context).pop(customer);
                },
              );
            },
          );
        },
      ),
    );
  }
}
