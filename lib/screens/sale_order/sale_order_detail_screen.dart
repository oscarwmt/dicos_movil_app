// lib/screens/sale_order/sale_order_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/odoo_api_client.dart';
import '../../models/sale_order_line_model.dart';
// import 'sale_order_detail_screen.dart'; // ❌ Eliminamos este import innecesario

class SaleOrderDetailScreen extends StatelessWidget {
  final OdooApiClient apiClient;
  final int orderId;
  final String orderName;
  final String customerName;
  final String shippingAddressName;
  final DateTime dateOrder;

  const SaleOrderDetailScreen({
    super.key,
    required this.apiClient,
    required this.orderId,
    required this.orderName,
    required this.customerName,
    required this.shippingAddressName,
    required this.dateOrder,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormatter = NumberFormat.currency(
        locale: 'es', symbol: '\$', decimalDigits: 0, customPattern: '\$#,##0');
    final dateFormatter = DateFormat('dd-MM-yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(orderName), // Dejamos el nombre del pedido aquí
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ENCABEZADO DEL DETALLE CON CLIENTE, DIRECCIÓN Y FECHA
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Colors.grey[100],
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Cliente: $customerName',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Entrega: $shippingAddressName',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  'Fecha: ${dateFormatter.format(dateOrder)}',
                  style: const TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const Divider(height: 16),
                const Text('Líneas de Producto:',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          Expanded(
            child: FutureBuilder<List<SaleOrderLine>>(
              future: apiClient.fetchSaleOrderLines(orderId),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child:
                          Text('Error al cargar detalle: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('Este pedido no tiene líneas.'));
                }

                final lines = snapshot.data!;

                final totalNeto =
                    lines.fold(0.0, (sum, line) => sum + line.priceSubtotal);

                return Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: lines.length,
                        itemBuilder: (ctx, index) {
                          final line = lines[index];
                          return ListTile(
                            title: Text(line.productName),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    'Cantidad: ${line.quantity.toStringAsFixed(0)} ${line.salesUnitName}',
                                    style: const TextStyle(fontSize: 14)),
                                Text(
                                    'Unitario Neto: ${currencyFormatter.format(line.priceUnit)}',
                                    style: const TextStyle(
                                        fontSize: 13, color: Colors.black54)),
                              ],
                            ),
                            trailing: Text(
                              currencyFormatter.format(line.priceSubtotal),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  fontSize: 16),
                            ),
                          );
                        },
                      ),
                    ),
                    // Resumen Simple
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Neto (Subtotal Líneas):',
                              style: TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                          Text(currencyFormatter.format(totalNeto),
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green)),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
