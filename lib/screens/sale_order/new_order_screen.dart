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

  // Método para manejar la reducción de cantidad y confirmación de eliminación
  Future<void> _handleQuantityDecrement(
      BuildContext context, CartProvider cart, CartItem item) async {
    if (item.quantity > 1) {
      // Si la cantidad es > 1, solo la reducimos
      cart.removeSingleItem(item.product.id);
    } else {
      // Si la cantidad es 1, pedimos confirmación para eliminar
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

  // ✅ Método auxiliar para construir el panel de precio/cantidad (Columna Derecha)
  Widget _buildPriceAndQuantityControls(
      BuildContext context, CartItem item, NumberFormat formatter) {
    // ✅ CORRECCIÓN CLAVE: La variable itemTotalNeto se calcula aquí
    final double itemTotalNeto = item.product.price * item.quantity;
    final CartProvider cart = Provider.of<CartProvider>(context, listen: false);

    final bool hasStock = item.product.stock > 0;

    return SizedBox(
      width: 125, // Aseguramos un ancho fijo para este panel
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // 1. Panel de Precio (Visible solo si hay stock)
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
                // Impuestos
                const Text('+ IMPUESTOS',
                    style: TextStyle(
                        fontSize: 8, color: Colors.black54, height: 1.0)),
              ],
            ),

          // Separador (solo si hay precio arriba)
          SizedBox(height: hasStock ? 5 : 0),

          // 2. Objeto de Cantidad (Visible siempre)
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Botón de decrementar/eliminar
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
              // Cantidad
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  '${item.quantity}',
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.bold),
                ),
              ),
              // Botón de incrementar
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
    // Escucha al carrito para redibujar al cambiar cantidades
    final cart = Provider.of<CartProvider>(context);
    final totalNetoEstimado = cart.totalAmount;
    final totalImpuestosEstimado = totalNetoEstimado * 0.19;
    final totalFinalEstimado = totalNetoEstimado + totalImpuestosEstimado;

    // Formateador con símbolo '$' al inicio
    final NumberFormat currencyFormatter = NumberFormat.currency(
        locale: 'es', symbol: '\$', decimalDigits: 0, customPattern: '\$#,##0');

    final buttonText = isQuotation ? 'Crear Cotización' : 'Confirmar Pedido';

    return Scaffold(
      appBar: AppBar(
        title: Text('${isQuotation ? "Revisar Cotización" : "Revisar Pedido"}'),
      ),
      body: Column(
        children: [
          // Sección de Encabezado (Cliente y Dirección)
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

                // Dirección de entrega
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

          // Listado de Productos
          Expanded(
            child: ListView.builder(
              itemCount: cart.items.length,
              itemBuilder: (ctx, i) {
                final CartItem item = cart.items[i];
                final String safeSalesUnit = item.product.salesUnit ?? 'Unidad';

                // Determinar si hay stock
                final bool hasStock = item.product.stock > 0;

                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: Container(
                    decoration: BoxDecoration(
                      // BORDE CONDICIONAL: Rojo si no hay stock, Gris si hay stock
                      border: Border.all(
                        color: hasStock ? Colors.grey.shade300 : Colors.red,
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.only(
                        left: 12, right: 8, top: 10, bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Columna 1: Nombre y Unidad de Venta (Flexible)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Título del Producto (Siempre visible)
                              Text(
                                item.product.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15),
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),

                              // UNIDAD DE VENTA (Visible solo si hay stock)
                              if (hasStock)
                                Text(
                                  '(${item.product.unitsPerPackage} por ${safeSalesUnit})',
                                  style: const TextStyle(
                                      fontSize: 12, color: Colors.grey),
                                ),

                              // MENSAJE SIN STOCK (Si no hay stock)
                              if (!hasStock)
                                const Text(
                                  '(Producto sin stock/cotización)',
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.red,
                                      fontStyle: FontStyle.italic),
                                ),
                            ],
                          ),
                        ),

                        // Columna 2: Controles de Precio y Cantidad (Fijo)
                        _buildPriceAndQuantityControls(
                            context, item, currencyFormatter),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),

          // Resumen Final: Neto, Impuestos, Total
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
                // 1. Total Neto
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
                // 2. Impuestos (Placeholder)
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
                // 3. Total Final
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
