// lib/screens/catalog/catalog_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:flutter/foundation.dart'; // Para kDebugMode

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
  bool _isGeneratingPdf = false;

  late Future<List<Map<String, dynamic>>> _categoriesFuture;
  late Future<List<String>> _brandsFuture; // Tipo String

  List<Map<String, dynamic>> _subCategories = [];
  int? _selectedCategoryId;
  int? _selectedSubCategoryId;
  String? _selectedBrandName; // Tipo String

  @override
  void initState() {
    super.initState();

    // Asignar los futures
    _categoriesFuture = widget.apiClient.fetchCategories().catchError((e) {
      debugPrint("[CatalogScreen initState] Error fetching categories: $e");
      // ✅ CORRECCIÓN: Devolver el tipo correcto en caso de error
      return <Map<String, dynamic>>[];
    });

    // ✅ CORRECCIÓN: Llamar a la función correcta 'fetchDistinctBrandNames'
    _brandsFuture = widget.apiClient.fetchDistinctBrandNames().catchError((e) {
      debugPrint("[CatalogScreen initState] Error fetching brands: $e");
      // ✅ CORRECCIÓN: Devolver el tipo correcto en caso de error
      return <String>[];
    });

    // Llamar a _fetchAndSetProducts DESPUÉS de que initState termine
    // Esto asegura que el 'context' esté disponible
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchAndSetProducts();
    });

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
    // Protección contra llamadas múltiples
    if ((loadMore && _isLoadingMore) ||
        (!loadMore && _isLoading && _products.isNotEmpty)) {
      return;
    }

    // ✅ CORRECCIÓN: No obtener ScaffoldMessenger aquí. Se obtendrá solo si es necesario (en el catch).
    // final scaffoldMessenger = ScaffoldMessenger.of(context); // <--- ESTA LÍNEA CAUSABA EL ERROR

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        _products.clear();
        _isLoading = true;
        _isLoadingMore = false;
      }
    });

    try {
      final domain = _buildDomain();

      final newProducts = await widget.apiClient
          .fetchCatalogProducts(
        offset: loadMore ? _products.length : 0,
        domain: domain,
      )
          .timeout(const Duration(seconds: 45), onTimeout: () {
        throw TimeoutException('La consulta de productos tardó demasiado.');
      });

      if (!mounted) return;

      if (loadMore && newProducts.isEmpty) {
        setState(() {
          _isLoadingMore = false;
        });
      } else {
        setState(() {
          _products.addAll(newProducts);
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print("[_fetchAndSetProducts] ERROR caught: $e");
      }
      if (!mounted) return;

      // ✅ CORRECCIÓN: Obtener ScaffoldMessenger aquí, solo cuando se necesita.
      final scaffoldMessenger = ScaffoldMessenger.of(context);

      if (!loadMore) {
        setState(() {
          _isLoading = false;
        }); // Detener carga principal en error
        scaffoldMessenger.showSnackBar(SnackBar(
            content: Text('Error al cargar productos: $e'),
            backgroundColor: Colors.red));
      } else {
        setState(() {
          _isLoadingMore = false;
        }); // Detener carga inferior en error
      }
    } finally {
      if (mounted && (_isLoading || _isLoadingMore)) {
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
    if (_selectedBrandName != null && _selectedBrandName!.isNotEmpty) {
      domain.add(['x_studio_marca', '=', _selectedBrandName]);
    }
    return domain;
  }

  void _onScroll() {
    if (!_isLoadingMore &&
        _scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent - 200) {
      _fetchAndSetProducts(loadMore: true);
    }
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) {
      _debounce!.cancel();
    }
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _fetchAndSetProducts(loadMore: false);
    });
  }

  Future<void> _fetchSubCategories(int parentId) async {
    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    try {
      final subCats = await widget.apiClient.fetchSubCategories(parentId);
      if (!mounted) return;
      setState(() {
        _subCategories = subCats;
      });
    } catch (e) {
      debugPrint('[_fetchSubCategories] Error: $e');
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(SnackBar(
          content: Text('Error al cargar subcategorías: $e'),
          backgroundColor: Colors.orange));
    }
  }

  Future<List<Uint8List?>> _downloadImagesInBatches(List<Product> products,
      {int batchSize = 20}) async {
    List<Uint8List?> allImageBytes = List.filled(products.length, null);
    for (int i = 0; i < products.length; i += batchSize) {
      int end =
          (i + batchSize > products.length) ? products.length : i + batchSize;
      List<Product> batchProducts = products.sublist(i, end);

      List<Uint8List?> batchImageBytes = await Future.wait(
        batchProducts.map((p) async {
          if (p.imageUrl.isEmpty || !Uri.tryParse(p.imageUrl)!.isAbsolute) {
            debugPrint('URL de imagen inválida o vacía: ${p.imageUrl}');
            return null;
          }
          try {
            final response = await http
                .get(Uri.parse(p.imageUrl))
                .timeout(const Duration(seconds: 15));
            if (response.statusCode == 200) {
              return response.bodyBytes;
            } else {
              debugPrint(
                  'Error descargando imagen ${p.imageUrl}: Status code ${response.statusCode}');
            }
          } catch (e) {
            debugPrint(
                'Error de red/timeout descargando imagen: ${p.imageUrl} -> $e');
          }
          return null;
        }).toList(),
      );

      for (int j = 0; j < batchImageBytes.length; j++) {
        if (i + j < allImageBytes.length) {
          allImageBytes[i + j] = batchImageBytes[j];
        }
      }
      await Future.delayed(const Duration(milliseconds: 200));
    }
    return allImageBytes;
  }

  Future<void> _generateAndSharePdf() async {
    if (_products.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No hay productos para generar el catálogo.'),
          backgroundColor: Colors.orange));
      return;
    }

    if (!mounted) return;
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() {
      _isGeneratingPdf = true;
    });

    scaffoldMessenger.showSnackBar(
      const SnackBar(
        content: Text('Generando PDF... Esto puede tardar unos segundos.'),
        backgroundColor: Colors.blue,
        duration: Duration(seconds: 10),
      ),
    );

    try {
      final ByteData logoData = await rootBundle.load('assets/logo.png');
      final logoImage = pw.MemoryImage(logoData.buffer.asUint8List());

      final imageBytesList = await _downloadImagesInBatches(_products);

      final Map<String, Map<String, Map<String, List<Map<String, dynamic>>>>>
          groupedProducts = {};
      for (int i = 0; i < _products.length; i++) {
        final product = _products[i];
        final category = product.categoryName ?? 'Sin Categoría';
        final subCategory = product.categoryName ?? 'General';
        final brand = product.brandName ?? 'Sin Marca';
        groupedProducts
            .putIfAbsent(category, () => {})
            .putIfAbsent(subCategory, () => {})
            .putIfAbsent(brand, () => [])
            .add({
          'product': product,
          'imageBytes': imageBytesList[i],
        });
      }

      final pdf = pw.Document();

      // Portada
      pdf.addPage(
        pw.Page(
          pageTheme: const pw.PageTheme(pageFormat: PdfPageFormat.a4),
          build: (pw.Context context) => pw.Center(
            child: pw.Column(
              mainAxisAlignment: pw.MainAxisAlignment.center,
              children: [
                pw.SizedBox(
                    height: 150, width: 150, child: pw.Image(logoImage)),
                pw.SizedBox(height: 20),
                pw.Text('Catálogo de Productos',
                    style: pw.TextStyle(
                        fontSize: 32, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 5),
                pw.Text('DICOS',
                    style: const pw.TextStyle(
                        fontSize: 24, color: PdfColors.grey600)),
                pw.SizedBox(height: 50),
                pw.Text(
                    'Generado el ${DateFormat('dd/MM/yyyy').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 12)),
              ],
            ),
          ),
        ),
      );

      // Páginas de Productos
      groupedProducts.forEach((category, subCategories) {
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            header: (context) => pw.Column(children: [
              pw.Header(
                  level: 1,
                  child: pw.Text(category,
                      style: pw.TextStyle(
                          fontSize: 22,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey800))),
              pw.Divider(),
              pw.SizedBox(height: 10),
            ]),
            footer: (context) => pw.Container(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                  'Página ${context.pageNumber} / ${context.pagesCount}',
                  style: const pw.TextStyle(fontSize: 8)),
            ),
            build: (pw.Context context) {
              final List<pw.Widget> widgets = [];
              subCategories.forEach((subCategory, brands) {
                brands.forEach((brand, productDataList) {
                  widgets.add(pw.Padding(
                    padding:
                        const pw.EdgeInsets.only(left: 10.0, bottom: 5, top: 5),
                    child: pw.Text(brand,
                        style: pw.TextStyle(
                            fontSize: 14,
                            fontWeight: pw.FontWeight.bold,
                            fontStyle: pw.FontStyle.italic)),
                  ));

                  const int productsPerPage = 12;
                  for (int i = 0;
                      i < productDataList.length;
                      i += productsPerPage) {
                    int end = (i + productsPerPage > productDataList.length)
                        ? productDataList.length
                        : i + productsPerPage;
                    final chunk = productDataList.sublist(i, end);

                    widgets.add(pw.Padding(
                      padding: const pw.EdgeInsets.only(
                          left: 10.0, top: 5.0, bottom: 15.0),
                      child: pw.TableHelper.fromTextArray(
                        cellAlignment: pw.Alignment.centerLeft,
                        cellPadding: const pw.EdgeInsets.all(4),
                        cellStyle: const pw.TextStyle(fontSize: 9),
                        headerStyle: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 10),
                        headerDecoration:
                            const pw.BoxDecoration(color: PdfColors.grey300),
                        border: pw.TableBorder.all(
                            color: PdfColors.grey, width: 0.5),
                        headers: ['Imagen', 'Código', 'Producto'],
                        data: chunk.map<List<pw.Widget>>((data) {
                          final Product p = data['product'];
                          final Uint8List? imageBytes = data['imageBytes'];

                          final imageWidget = imageBytes != null
                              ? pw.Image(pw.MemoryImage(imageBytes),
                                  fit: pw.BoxFit.contain, height: 40, width: 40)
                              : pw.Container(
                                  height: 40,
                                  width: 40,
                                  color: PdfColors.grey200,
                                  child: pw.Center(
                                      child: pw.Text('S/I',
                                          style: const pw.TextStyle(
                                              fontSize: 8))));

                          return [
                            pw.Container(
                                height: 45,
                                alignment: pw.Alignment.centerLeft,
                                child: imageWidget),
                            pw.Padding(
                                padding:
                                    const pw.EdgeInsets.symmetric(vertical: 2),
                                child: pw.Text(p.internalReference)),
                            pw.Padding(
                                padding:
                                    const pw.EdgeInsets.symmetric(vertical: 2),
                                child: pw.Text(p.name)),
                          ];
                        }).toList(),
                        columnWidths: const {
                          0: pw.FixedColumnWidth(50),
                          1: pw.FixedColumnWidth(70),
                          2: pw.FlexColumnWidth(),
                        },
                      ),
                    ));
                  }
                });
              });
              return widgets;
            },
          ),
        );
      });

      final pdfBytes = await pdf.save();
      if (!mounted) return;
      await Printing.sharePdf(
          bytes: pdfBytes,
          filename:
              'Catalogo_DICOS_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf');
    } catch (e) {
      if (!mounted) return;
      scaffoldMessenger.showSnackBar(SnackBar(
          content: Text('Error al generar PDF: $e'),
          backgroundColor: Colors.red));
    } finally {
      if (mounted) {
        setState(() {
          _isGeneratingPdf = false;
        });
      }
    }
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: FutureBuilder<List<Map<String, dynamic>>>(
                  future: _categoriesFuture,
                  builder: (context, snapshot) {
                    Widget placeholder = DropdownButtonFormField<int>(
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8)),
                        hintText: 'Cargando...',
                      ),
                      items: const [],
                      onChanged: null,
                    );

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return placeholder;
                    }
                    if (snapshot.hasError) {
                      return Text('Error categorías: ${snapshot.error}');
                    }

                    final categories = snapshot.data ?? [];
                    return DropdownButtonFormField<int>(
                      initialValue: _selectedCategoryId,
                      hint: const Text('Categoría'),
                      decoration: InputDecoration(
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8))),
                      isExpanded: true,
                      items: [
                        const DropdownMenuItem<int>(
                            value: null, child: Text('Todas')),
                        ...categories.map((cat) => DropdownMenuItem(
                            value: cat['id'] as int,
                            child: Text(cat['name'],
                                overflow: TextOverflow.ellipsis))),
                      ],
                      onChanged: (value) {
                        debugPrint("[_buildFilters] Category changed: $value");
                        setState(() {
                          _selectedCategoryId = value;
                          _selectedSubCategoryId = null;
                          _subCategories.clear();
                          if (value != null) {
                            _fetchSubCategories(value);
                          }
                          _fetchAndSetProducts(loadMore: false);
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
                    initialValue: _selectedSubCategoryId,
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
                      debugPrint("[_buildFilters] Subcategory changed: $value");
                      setState(() {
                        _selectedSubCategoryId = value;
                        _fetchAndSetProducts(loadMore: false);
                      });
                    },
                  ),
                ),
              ]
            ],
          ),
          const SizedBox(height: 8),
          FutureBuilder<List<String>>(
            future: _brandsFuture,
            builder: (context, snapshot) {
              Widget placeholder = DropdownButtonFormField<String>(
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8)),
                  hintText: 'Cargando Marcas...',
                ),
                items: const [],
                onChanged: null,
              );

              if (snapshot.connectionState == ConnectionState.waiting) {
                return placeholder;
              }
              if (snapshot.hasError) {
                debugPrint(
                    "[_buildFilters] Error in brands FutureBuilder: ${snapshot.error}");
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('Error marcas: ${snapshot.error}',
                      style:
                          TextStyle(color: Colors.red.shade700, fontSize: 12)),
                );
              }
              if (!snapshot.hasData || snapshot.data!.isEmpty) {
                return const SizedBox.shrink();
              }

              final brandNames = snapshot.data!;
              final currentSelectedBrand = _selectedBrandName != null &&
                      brandNames.contains(_selectedBrandName)
                  ? _selectedBrandName
                  : null;

              return DropdownButtonFormField<String>(
                // ✅ CORRECCIÓN: 'value' -> 'initialValue'
                initialValue: currentSelectedBrand,
                hint: const Text('Marca'),
                decoration: InputDecoration(
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8))),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<String>(
                      value: null, child: Text('Todas')),
                  ...brandNames.map((brandName) => DropdownMenuItem<String>(
                      value: brandName,
                      child: Text(brandName, overflow: TextOverflow.ellipsis))),
                ],
                onChanged: (value) {
                  debugPrint("[_buildFilters] Brand changed: $value");
                  setState(() {
                    _selectedBrandName = value;
                    _fetchAndSetProducts(loadMore: false);
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
    debugPrint(
        "[CatalogScreen build] Rebuilding UI. _isLoading: $_isLoading, _products.length: ${_products.length}");
    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo Comercial'),
        actions: [
          if (_isGeneratingPdf)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 3,
                    )),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined),
              onPressed: _generateAndSharePdf,
              tooltip: 'Generar PDF con filtros actuales',
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: (_isGeneratingPdf || _isLoading)
                ? null
                : () => _fetchAndSetProducts(loadMore: false),
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
                            return _isLoadingMore
                                ? const Center(
                                    child: Padding(
                                        padding: EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator()))
                                : Container();
                          }
                          if (i < _products.length) {
                            return CatalogProductCard(product: _products[i]);
                          }
                          return Container();
                        },
                      ),
          ),
        ],
      ),
    );
  }
}
