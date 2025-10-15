// lib/screens/sale_order/new_order_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../api/odoo_api_client.dart';
import '../../models/cart_item_model.dart';
import '../../models/customer_model.dart';
import '../../providers/cart_provider.dart';

class NewOrderScreen extends StatelessWidget {
  final bool isQuotation;
  final Customer customer;
  final int shippingAddressId;

  const NewOrderScreen({
    super.key,
    required this.isQuotation,
    required this.customer,
    required this.shippingAddressId,
  });

  Future<void> _handleSaveOrder(BuildContext context, CartProvider cart) async {
    if (cart.totalUniqueItems == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('El carrito está vacío.'),
          backgroundColor: Colors.orange));
      return;
    }

    final OdooApiClient apiClient = OdooApiClient();
    ScaffoldMessenger.of(context).hideCurrentSnackBar();

    // Capturar el Navigator y el ScaffoldMessenger antes del async gap
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      // Mostrar indicador de carga
      showDialog(
        context: context,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
        barrierDismissible: false,
      );

      final int orderId = await apiClient.createSaleOrder(
        cart.items,
        customerPartnerId: customer.id,
        shippingAddressId: shippingAddressId,
        isQuotation: isQuotation,
      );

      final outOfStockItems =
          cart.items.where((item) => item.product.stock <= 0).toList();
      if (outOfStockItems.isNotEmpty) {
        await apiClient.reportOutOfStockDemand(outOfStockItems, customer.id);
      }

      // Limpiar el carrito y cerrar el modal.
      cart.clear();
      if (navigator.canPop()) {
        navigator.pop();
      }
      navigator.popUntil((route) => route.isFirst);

      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text(
            '¡${isQuotation ? "Cotización" : "Pedido"} $orderId creado y ${isQuotation ? "pendiente de aprobación" : "CONFIRMADO"}!'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ));
    } catch (e) {
      if (navigator.canPop()) {
        navigator.pop();
      }
      scaffoldMessenger.showSnackBar(SnackBar(
        content: Text('Error al grabar el pedido: $e'),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 5),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final totalAmount = cart.totalAmount;
    final priceFormatter =
        NumberFormat.currency(locale: 'es_CL', symbol: '\$', decimalDigits: 0);
    final buttonText = isQuotation ? 'Crear Cotización' : 'Confirmar Pedido';

    return Scaffold(
      appBar: AppBar(
        title: Text('${isQuotation ? "Revisar Cotización" : "Revisar Pedido"}'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            color: const Color(0xFFECEFF1),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cliente:',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                // ✅ CORRECCIÓN DE ADVERTENCIA: Usamos el valor directamente
                Text(
                  customer.name,
                  style: const TextStyle(fontSize: 16),
                ),
                Text(
                  'Dirección ID: $shippingAddressId',
                  style: const TextStyle(fontSize: 14, color: Colors.grey),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: cart.items.length,
              itemBuilder: (ctx, i) {
                final CartItem item = cart.items[i];
                return ListTile(
                  title: Text(item.product.name),
                  subtitle: Text(
                      '${priceFormatter.format(item.product.price)} x ${item.quantity}'),
                  trailing: Text(priceFormatter
                      .format(item.product.price * item.quantity)),
                );
              },
            ),
          ),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                    color: Colors.grey.withAlpha((255 * 0.2).round()),
                    spreadRadius: 2,
                    blurRadius: 5)
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Estimado:',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  priceFormatter.format(totalAmount),
                  style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.green),
                ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(10),
        child: ElevatedButton.icon(
          onPressed: () => _handleSaveOrder(context, cart),
          icon: Icon(isQuotation ? Icons.drafts : Icons.check_circle_outline),
          label: Text(buttonText),
          style: ElevatedButton.styleFrom(
            backgroundColor: isQuotation ? Colors.orange : Colors.green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 15),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      ),
    );
  }
}
