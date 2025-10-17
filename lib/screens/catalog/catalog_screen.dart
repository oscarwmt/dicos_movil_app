// lib/screens/catalog/catalog_screen.dart

import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../api/odoo_api_client.dart';
import '../../models/product_model.dart';
import '../../widgets/catalog_product_card.dart';

class CatalogScreen extends StatefulWidget {
  final OdooApiClient apiClient;

  const CatalogScreen({super.key, required this.apiClient});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  final List<Product> _products = [];
  bool _isLoading = true;
  bool _isLoadingMore = false;

  late Future<List<Map<String, dynamic>>> _categoriesFuture;
  List<Map<String, dynamic>> _categories = [];
  List<Map<String, dynamic>> _subCategories = [];
  int? _selectedCategoryId;
  int? _selectedSubCategoryId;

  late Future<List<Map<String, dynamic>>> _brandsFuture;
  List<Map<String, dynamic>> _brands = [];
  int? _selectedBrandId;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = widget.apiClient.fetchCategories();
    _brandsFuture = widget.apiClient.fetchBrands();
    _fetchAndSetProducts();

    _scrollController.addListener(_onScroll);
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchAndSetProducts({bool loadMore = false}) async {
    if (loadMore && _isLoadingMore) {
      return;
    }
    setState(() {
      if (loadMore)
        _isLoadingMore = true;
      else
        _isLoading = true;
    });

    try {
      final domain = _buildDomain();
      final newProducts = await widget.apiClient.fetchCatalogProducts(
        offset: loadMore ? _products.length : 0,
        domain: domain,
      );

      if (mounted) {
        setState(() {
          if (loadMore) {
            _products.addAll(newProducts);
          } else {
            _products.clear();
            _products.addAll(newProducts);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isLoadingMore = false;
        });
      }
    }
  }

  List<dynamic> _buildDomain() {
    final domain = [];
    final query = _searchController.text;
    if (query.isNotEmpty) {
      domain.add(['name', 'ilike', query]);
    }
    final categoryId = _selectedSubCategoryId ?? _selectedCategoryId;
    if (categoryId != null) {
      domain.add(['categ_id', 'child_of', categoryId]);
    }
    if (_selectedBrandId != null) {
      // ✅ CORREGIDO: Usando el nombre de campo correcto
      domain.add(['x_studio_marca', '=', _selectedBrandId]);
    }
    return domain;
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _fetchAndSetProducts(loadMore: true);
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchAndSetProducts();
    });
  }

  Future<void> _fetchSubCategories(int parentId) async {
    try {
      final subCats = await widget.apiClient.fetchSubCategories(parentId);
      if (mounted) {
        setState(() {
          _subCategories = subCats;
        });
      }
    } catch (e) {
      debugPrint('Error fetching subcategories: $e');
    }
  }

  Future<void> _generateAndSharePdf() async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No hay productos para generar el catálogo.'),
          backgroundColor: Colors.orange));
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );

    final List<Uint8List?> imageBytesList = await Future.wait(
      _products.map((p) async {
        try {
          final response = await http.get(Uri.parse(p.imageUrl));
          if (response.statusCode == 200) {
            return response.bodyBytes;
          }
        } catch (e) {
          debugPrint('Error descargando imagen: ${p.imageUrl} -> $e');
        }
        return null;
      }).toList(),
    );

    final Map<String, Map<String, List<Map<String, dynamic>>>> groupedProducts =
        {};
    for (int i = 0; i < _products.length; i++) {
      final product = _products[i];
      final category = product.categoryName ?? 'Sin Categoría';
      final brand = product.brandName ?? 'Sin Marca';

      groupedProducts
          .putIfAbsent(category, () => {})
          .putIfAbsent(brand, () => [])
          .add({
        'product': product,
        'imageBytes': imageBytesList[i],
      });
    }

    final pw.Document pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Catálogo de Productos',
                style:
                    pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.Text(
                'Generado el ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}'),
            pw.Divider(thickness: 1.5),
            pw.SizedBox(height: 10),
          ],
        ),
        build: (pw.Context context) {
          final List<pw.Widget> pdfWidgets = [];

          groupedProducts.forEach((category, brands) {
            pdfWidgets.add(pw.Header(
                level: 1,
                child: pw.Text(category,
                    style: pw.TextStyle(
                        fontSize: 18,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800))));
            pdfWidgets.add(pw.SizedBox(height: 10));

            brands.forEach((brand, productDataList) {
              pdfWidgets.add(pw.Padding(
                padding: const pw.EdgeInsets.only(left: 15.0),
                child: pw.Text(brand,
                    style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        fontStyle: pw.FontStyle.italic)),
              ));
              pdfWidgets.add(pw.SizedBox(height: 10));

              pdfWidgets.add(pw.Padding(
                padding: const pw.EdgeInsets.only(left: 15.0, bottom: 20.0),
                child: pw.TableHelper.fromTextArray(
                  cellAlignment: pw.Alignment.centerLeft,
                  cellStyle: const pw.TextStyle(fontSize: 9),
                  headerStyle: pw.TextStyle(
                      fontWeight: pw.FontWeight.bold, fontSize: 10),
                  headerDecoration:
                      const pw.BoxDecoration(color: PdfColors.grey300),
                  border: pw.TableBorder.all(color: PdfColors.grey, width: 0.5),
                  headers: ['Imagen', 'Código', 'Producto'],
                  data: productDataList.map((data) {
                    final Product p = data['product'];
                    final Uint8List? imageBytes = data['imageBytes'];

                    final imageWidget = imageBytes != null
                        ? pw.Image(pw.MemoryImage(imageBytes),
                            fit: pw.BoxFit.contain, height: 40)
                        : pw.Container(
                            height: 40,
                            width: 40,
                            color: PdfColors.grey200,
                            child: pw.Center(
                                child: pw.Text('S/I',
                                    style: const pw.TextStyle(fontSize: 8))));

                    return [
                      imageWidget,
                      p.internalReference,
                      p.name,
                    ];
                  }).toList(),
                  columnWidths: {
                    0: const pw.FlexColumnWidth(1.2),
                    1: const pw.FlexColumnWidth(1.5),
                    2: const pw.FlexColumnWidth(4),
                  },
                ),
              ));
            });
            pdfWidgets.add(pw.Divider(height: 20));
          });

          return pdfWidgets;
        },
      ),
    );

    Navigator.of(context).pop();

    await Printing.sharePdf(
        bytes: await pdf.save(),
        filename:
            'Catalogo_con_imagenes_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Buscar por nombre o código...',
              prefixIcon: const Icon(Icons.search),
              border:
                  OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _categoriesFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const SizedBox.shrink();
                    }
                    _categories = snapshot.data ?? [];
                    return DropdownButtonFormField<int>(
                      value: _selectedCategoryId,
                      hint: const Text('Categoría'),
                      decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8))),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<int>(
                            value: null, child: Text('Todas')),
                        ..._categories.map((cat) => DropdownMenuItem(
                            value: cat['id'] as int,
                            child: Text(cat['name'],
                                overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (value) {
                        setState(() {
                          _selectedCategoryId = value;
                          _selectedSubCategoryId = null;
                          _subCategories.clear();
                          if (value != null) {
                            _fetchSubCategories(value);
                          }
                          _fetchAndSetProducts();
                        });
                      },
                    );
                  },
                ),
              ),
              if (_subCategories.isNotEmpty) ...[
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: _selectedSubCategoryId,
                    hint: const Text('Subcategoría'),
                    decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8))),
                    isExpanded: true,
                    items: _subCategories
                        .map((cat) => DropdownMenuItem(
                            value: cat['id'] as int,
                            child: Text(cat['name'],
                                overflow: TextOverflow.ellipsis)))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedSubCategoryId = value;
                        _fetchAndSetProducts();
                      });
                    },
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<Map<String, dynamic>>>(
            future: _brandsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }
              _brands = snapshot.data!;
              return DropdownButtonFormField<int>(
                value: _selectedBrandId,
                hint: const Text('Marca'),
                decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8))),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<int>(
                      value: null, child: Text('Todas')),
                  ..._brands.map((brand) => DropdownMenuItem(
                      value: brand['id'] as int,
                      child: Text(brand['name'],
                          overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (value) {
                  setState(() {
                    _selectedBrandId = value;
                    _fetchAndSetProducts();
                  });
                },
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo Comercial'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _generateAndSharePdf,
            tooltip: 'Generar PDF con filtros actuales',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => _fetchAndSetProducts(),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilters(),
          const Divider(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _products.isEmpty
                    ? const Center(
                        child: Text(
                            'No se encontraron productos con el filtro actual.'))
                    : GridView.builder(
                        controller: _scrollController,
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.7,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                        padding: const EdgeInsets.all(10.0),
                        itemCount: _products.length + (_isLoadingMore ? 1 : 0),
                        itemBuilder: (ctx, i) {
                          if (i == _products.length) {
                            return const Center(
                                child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator()));
                          }
                          return CatalogProductCard(product: _products[i]);
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
