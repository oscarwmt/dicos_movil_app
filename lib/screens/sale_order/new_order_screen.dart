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
  final String shippingAddressName;
  final String shippingAddressStreet;

  const NewOrderScreen({
    super.key,
    required this.isQuotation,
    required this.customer,
    required this.shippingAddressId,
    required this.shippingAddressName,
    required this.shippingAddressStreet,
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

    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
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

  Future<void> _handleQuantityDecrement(
      BuildContext context, CartProvider cart, CartItem item) async {
    if (item.quantity > 1) {
      cart.removeSingleItem(item.product.id);
    } else {
      final shouldDelete = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('¿Eliminar producto?'),
          content: Text('¿Quieres eliminar "${item.product.name}" del pedido?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child:
                  const Text('Eliminar', style: TextStyle(color: Colors.red)),
            ),
          ],
        ),
      );

      if (shouldDelete == true) {
        cart.removeItem(item.product.id);
      }
    }
  }

  Widget _buildPriceAndQuantityControls(
      BuildContext context, CartItem item, NumberFormat formatter) {
    final double itemTotalNeto = item.product.price * item.quantity;
    final CartProvider cart = Provider.of<CartProvider>(context, listen: false);

    final bool hasStock = item.product.stock > 0;

    return SizedBox(
      width: 125,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (hasStock)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  formatter.format(itemTotalNeto),
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: Colors.green),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const Text('+ IMPUESTOS',
                    style: TextStyle(
                        fontSize: 8, color: Colors.black54, height: 1.0)),
              ],
            ),
          SizedBox(height: hasStock ? 5 : 0),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(
                  item.quantity > 1
                      ? Icons.remove_circle_outline
                      : Icons.delete_outline,
                  color: item.quantity > 1 ? Colors.orange : Colors.red,
                  size: 20,
                ),
                onPressed: () => _handleQuantityDecrement(context, cart, item),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  item.quantity.toString(),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: Colors.green, size: 20),
                onPressed: () => cart.addItem(item.product),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = Provider.of<CartProvider>(context);
    final totalNetoEstimado = cart.totalAmount;
    final totalImpuestosEstimado = totalNetoEstimado * 0.19;
    final totalFinalEstimado = totalNetoEstimado + totalImpuestosEstimado;

    final NumberFormat currencyFormatter = NumberFormat.currency(
        locale: 'es', symbol: '\$', decimalDigits: 0, customPattern: '\$#,##0');

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
                Text(
                  customer.name,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Dirección de Entrega:',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.black54),
                ),
                Text(
                  shippingAddressName,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
                Text(
                  shippingAddressStreet.isNotEmpty
                      ? shippingAddressStreet
                      : 'Sin calle especificada.',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: cart.items.length,
              itemBuilder: (ctx, i) {
                final CartItem item = cart.items[i];
                final String safeSalesUnit = item.product.salesUnit ?? 'Unidad';
                final Color borderColor = item.product.stock <= 0
                    ? Colors.red.shade400
                    : Colors.grey.shade300;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: borderColor, width: 1.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.only(
                        left: 12, right: 8, top: 10, bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.product.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),

                              if (item.product.stock <= 0)
                                const Text(
                                  'SIN STOCK (PARA DEMANDA)',
                                  style: TextStyle(
                                    color: Colors.red,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),

                              // ✅ SOLUCIÓN: Interpolación innecesaria eliminada
                              Text(
                                '(${item.product.unitsPerPackage} por $safeSalesUnit)',
                                style: const TextStyle(
                                    fontSize: 12, color: Colors.grey),
                              ),

                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                        _buildPriceAndQuantityControls(
                            context, item, currencyFormatter),
                      ],
                    ),
                  ),
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
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Neto Estimado:',
                        style: TextStyle(fontSize: 16)),
                    Text(currencyFormatter.format(totalNetoEstimado),
                        style: const TextStyle(fontSize: 16)),
                  ],
                ),
                const SizedBox(height: 5),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Impuestos (Estimado):',
                        style: TextStyle(fontSize: 16)),
                    Text(currencyFormatter.format(totalImpuestosEstimado),
                        style: const TextStyle(fontSize: 16)),
                  ],
                ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Final:',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(
                      currencyFormatter.format(totalFinalEstimado),
                      style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.green),
                    ),
                  ],
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
