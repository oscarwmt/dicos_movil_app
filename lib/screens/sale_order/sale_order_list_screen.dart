// lib/screens/sale_order/sale_order_list_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../api/odoo_api_client.dart';
import '../../models/sale_order_model.dart';
import 'sale_order_detail_screen.dart';

// Definición de los criterios de ordenamiento
enum SortCriteria { date, name, customer, amount }

class SaleOrderListScreen extends StatefulWidget {
  final OdooApiClient apiClient;

  const SaleOrderListScreen({super.key, required this.apiClient});

  @override
  State<SaleOrderListScreen> createState() => _SaleOrderListScreenState();
}

class _SaleOrderListScreenState extends State<SaleOrderListScreen> {
  late Future<List<SaleOrder>> _ordersFuture;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _selectedState = 'all'; // Estado de filtro por defecto
  String _currentSearchQuery = '';

  // Estado para el ordenamiento
  SortCriteria _currentSort = SortCriteria.date;
  bool _isAscending = false;

  @override
  void initState() {
    super.initState();
    _ordersFuture = _fetchOrdersWithSearch();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ===============================================
  // LÓGICA DE FILTRADO Y RECARGA
  // ===============================================

  Future<List<SaleOrder>> _fetchOrdersWithSearch() async {
    final domain = _buildBaseDomain();
    final orderBy = _buildOrderByClause();

    if (_currentSearchQuery.isNotEmpty) {
      final query = _currentSearchQuery;

      // 1. Buscamos primero los IDs de cliente que coinciden con el nombre
      final partnerIds = await widget.apiClient.searchPartnerIdsByName(query);

      // 2. Definimos el dominio de búsqueda combinada (N° Orden O Cliente ID)
      if (partnerIds.isNotEmpty) {
        // Si encontramos clientes, aplicamos el filtro OR
        domain.add([
          '|',
          ['name', 'ilike', query], // Busca por N° Orden
          ['partner_id', 'in', partnerIds], // Busca por ID de Cliente
        ]);
      } else {
        // Si NO encontramos IDs de cliente, la búsqueda por nombre de cliente
        // falla, por lo que solo buscamos por N° Orden.
        domain.add(['name', 'ilike', query]);
      }
    }

    // Llamada a la API con el dominio final
    return widget.apiClient.fetchSaleOrders(domain: domain, orderBy: orderBy);
  }

  // Define la cláusula 'order' para la API
  String _buildOrderByClause() {
    String field;
    switch (_currentSort) {
      case SortCriteria.date:
        field = 'date_order';
        break;
      case SortCriteria.name:
        field = 'name';
        break;
      case SortCriteria.customer:
        field = 'partner_id';
        break;
      case SortCriteria.amount:
        field = 'amount_total';
        break;
      // No hay 'default', resolviendo la advertencia 'unreachable_switch_default'
    }

    final direction = _isAscending ? 'asc' : 'desc';

    return '$field $direction';
  }

  // Define el dominio base (filtros de estado)
  List<dynamic> _buildBaseDomain() {
    final domain = [];

    if (_selectedState != 'all') {
      domain.add(['state', '=', _selectedState]);
    }

    return domain;
  }

  Future<void> _refreshOrders() async {
    setState(() {
      _ordersFuture = _fetchOrdersWithSearch();
    });
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_currentSearchQuery != _searchController.text) {
        setState(() {
          _currentSearchQuery = _searchController.text;
          _ordersFuture = _fetchOrdersWithSearch();
        });
      }
    });
  }

  void _onStateChanged(String? newState) {
    if (newState != null) {
      setState(() {
        _selectedState = newState;
        _ordersFuture = _fetchOrdersWithSearch();
      });
    }
  }

  void _onSortSelected(SortCriteria criteria) {
    setState(() {
      if (_currentSort == criteria) {
        _isAscending = !_isAscending;
      } else {
        _currentSort = criteria;
        _isAscending = false;
      }
      _ordersFuture = _fetchOrdersWithSearch();
    });
  }

  // ===============================================
  // WIDGETS AUXILIARES
  // ===============================================

  String _getStateText(String state) {
    switch (state) {
      case 'draft':
      case 'sent':
        return 'Cotización';
      case 'sale':
        return 'Pedido Confirmado';
      default:
        return state;
    }
  }

  Color _getStateColor(String state) {
    switch (state) {
      case 'draft':
      case 'sent':
        return Colors.orange;
      case 'sale':
        return Colors.green;
      case 'cancel':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  IconData _getSortIcon(SortCriteria criteria) {
    if (_currentSort != criteria) return Icons.sort;
    return _isAscending ? Icons.arrow_upward : Icons.arrow_downward;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormatter = DateFormat('dd MMM yyyy');
    final currencyFormatter = NumberFormat.currency(
        locale: 'es', symbol: '\$', decimalDigits: 0, customPattern: '\$#,##0');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Ventas y Cotizaciones'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshOrders,
          ),
          // BOTÓN DE ORDENAMIENTO
          PopupMenuButton<SortCriteria>(
            onSelected: _onSortSelected,
            icon: const Icon(Icons.sort_by_alpha),
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<SortCriteria>>[
              PopupMenuItem<SortCriteria>(
                value: SortCriteria.date,
                child: Row(
                  children: [
                    Icon(_getSortIcon(SortCriteria.date)),
                    const SizedBox(width: 8),
                    const Text('Ordenar por Fecha'),
                  ],
                ),
              ),
              PopupMenuItem<SortCriteria>(
                value: SortCriteria.customer,
                child: Row(
                  children: [
                    Icon(_getSortIcon(SortCriteria.customer)),
                    const SizedBox(width: 8),
                    const Text('Ordenar por Cliente'),
                  ],
                ),
              ),
              PopupMenuItem<SortCriteria>(
                value: SortCriteria.name,
                child: Row(
                  children: [
                    Icon(_getSortIcon(SortCriteria.name)),
                    const SizedBox(width: 8),
                    const Text('Ordenar por N° Orden'),
                  ],
                ),
              ),
              PopupMenuItem<SortCriteria>(
                value: SortCriteria.amount,
                child: Row(
                  children: [
                    Icon(_getSortIcon(SortCriteria.amount)),
                    const SizedBox(width: 8),
                    const Text('Ordenar por Monto Total'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // FILTROS Y BUSCADOR
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              children: [
                // BUSCADOR (CLIENTE/ORDEN)
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Buscar por Cliente o N° Orden...',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                ),
                const SizedBox(height: 8),
                // FILTRO POR ESTADO
                DropdownButtonFormField<String>(
                  decoration: InputDecoration(
                    labelText: 'Filtrar por Estado',
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  initialValue: _selectedState,
                  items: const [
                    DropdownMenuItem(
                        value: 'all', child: Text('Todos los Estados')),
                    DropdownMenuItem(
                        value: 'draft', child: Text('Cotizaciones')),
                    DropdownMenuItem(value: 'sale', child: Text('Confirmados')),
                    DropdownMenuItem(
                        value: 'cancel', child: Text('Cancelados')),
                  ],
                  onChanged: _onStateChanged,
                ),
              ],
            ),
          ),

          // LISTADO DE ÓRDENES
          Expanded(
            child: FutureBuilder<List<SaleOrder>>(
              future: _ordersFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                      child: Text('Error al cargar ventas: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                      child: Text('No se encontraron pedidos.'));
                }

                final orders = snapshot.data!;

                return ListView.builder(
                  itemCount: orders.length,
                  itemBuilder: (ctx, index) {
                    final order = orders[index];
                    return Card(
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 5),
                      child: ListTile(
                        // NÚMERO DE ORDEN Y CLIENTE
                        title: Text(
                          '${order.name} - ${order.customerName}',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 15),
                          overflow: TextOverflow.ellipsis,
                        ),
                        // DIRECCIÓN Y FECHA
                        subtitle: Text(
                            '${order.shippingAddressName} | Fecha: ${dateFormatter.format(order.dateOrder)}'),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              currencyFormatter.format(order.amountTotal),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                  fontSize: 16),
                            ),
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color:
                                    _getStateColor(order.state).withAlpha(40),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                _getStateText(order.state),
                                style: TextStyle(
                                  color: _getStateColor(order.state),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          // Navegación al detalle
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (ctx) => SaleOrderDetailScreen(
                              apiClient: widget.apiClient,
                              orderId: order.id,
                              orderName: order.name,
                              customerName: order.customerName,
                              shippingAddressName: order.shippingAddressName,
                              dateOrder: order.dateOrder,
                            ),
                          ));
                        },
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
