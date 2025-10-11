// lib/screens/sale_order/new_order_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../api/odoo_api_client.dart';
import '../../models/customer_model.dart';
import '../../providers/cart_provider.dart';
import 'customer_selector_screen.dart';

class NewOrderScreen extends StatefulWidget {
  const NewOrderScreen({super.key});

  @override
  State<NewOrderScreen> createState() => _NewOrderScreenState();
}

class _NewOrderScreenState extends State<NewOrderScreen> {
  final OdooApiClient _apiClient = OdooApiClient();
  Customer _selectedCustomer = Customer.defaultCustomer;
  final String _orderDate = DateTime.now().toIso8601String().substring(0, 10);

  // Navegar al selector de clientes
  Future<void> _selectCustomer() async {
    final selected = await Navigator.of(context).push(
      MaterialPageRoute(builder: (ctx) => const CustomerSelectorScreen()),
    );

    if (selected != null && selected is Customer) {
      setState(() {
        _selectedCustomer = selected;
      });
    }
  }

  // Finalizar y crear la Orden de Venta
  Future<void> _finalizeOrder(CartProvider cart) async {
    if (_selectedCustomer.id == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Debe seleccionar un cliente antes de finalizar.')),
      );
      return;
    }

    if (cart.itemCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El carrito está vacío.')),
      );
      return;
    }

    // Guardar referencias al context antes del 'await'
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    try {
      messenger.showSnackBar(
        SnackBar(
            content: Text('Creando pedido para ${_selectedCustomer.name}...'),
            duration: const Duration(seconds: 3)),
      );

      final int orderId = await _apiClient.createSaleOrder(cart.items,
          customerPartnerId: _selectedCustomer.id);

      cart.clear();

      navigator.pop();

      messenger.showSnackBar(
        SnackBar(
          content: Text('¡Pedido Venta #$orderId creado con éxito!'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Fallo: ${e.toString().replaceAll('Exception: ', '')}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 8),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nuevo Pedido DICOS'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // 1. Cabecera y Selector de Cliente
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // CORRECCIÓN: Se quitó 'const' porque usa una variable (_apiClient.userName).
                Text('Vendedor: ${_apiClient.userName}',
                    style: const TextStyle(fontSize: 16, color: Colors.grey)),
                Text('Fecha: $_orderDate',
                    style: const TextStyle(fontSize: 16, color: Colors.grey)),
                const SizedBox(height: 12),

                // Selector de Cliente (Botón)
                ElevatedButton.icon(
                  onPressed: _selectCustomer,
                  icon: Icon(
                      _selectedCustomer.id == 0
                          ? Icons.person_add_alt
                          : Icons.person,
                      size: 24),
                  label: Text(_selectedCustomer.name,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: _selectedCustomer.id == 0
                        ? Colors.red[50]
                        : Colors.green[50],
                    foregroundColor: _selectedCustomer.id == 0
                        ? Colors.red
                        : Colors.green[900],
                    elevation: 1,
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),

          // 2. Sección del Carrito (Lista de Productos)
          Expanded(
            child: cart.itemCount == 0
                ? const Center(child: Text('Añade productos para este pedido.'))
                : ListView.builder(
                    itemCount: cart.itemCount,
                    itemBuilder: (ctx, i) {
                      final item = cart.items[i];
                      return Card(
                          child: ListTile(
                              title: Text(
                                  '${item.quantity}x ${item.product.name}'),
                              subtitle: Text(
                                  '\$${item.product.price.toStringAsFixed(2)}')));
                    },
                  ),
          ),

          // 3. Resumen y Botón de Creación
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Neto:',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('\$${cart.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: cart.itemCount > 0 && _selectedCustomer.id != 0
                        ? () => _finalizeOrder(cart)
                        : null,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      backgroundColor: Colors.deepPurple,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('CREAR ORDEN DE VENTA',
                        style: TextStyle(fontSize: 18)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
