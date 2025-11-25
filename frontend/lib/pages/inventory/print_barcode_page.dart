import 'dart:async';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../models/product.dart';
import '../../services/inventory_service.dart';
import '../../providers/providers.dart';
import 'package:barcode_widget/barcode_widget.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../../utils/barcode_utils.dart';

class PrintBarcodePage extends StatefulWidget {
  const PrintBarcodePage({super.key});

  @override
  State<PrintBarcodePage> createState() => _PrintBarcodePageState();
}

class _PrintBarcodePageState extends State<PrintBarcodePage>
    with WidgetsBindingObserver {
  ProductResponse? productResponse;
  String? errorMessage;
  int currentPage = 1;
  final int itemsPerPage =
      10; // Load 10 products per page for better performance

  // Caching and filtering
  List<Product> _allProductsCache = [];
  List<Product> _allFilteredProducts = [];
  List<Product> _filteredProducts = [];
  Timer? _searchDebounceTimer;
  bool _isFilterActive = false;

  String selectedStatus = 'All';
  final TextEditingController _searchController = TextEditingController();

  // Selection state
  Set<String> selectedProductCodes = {};
  bool selectAll = false;

  // Pagination state for single product barcode/QR generation
  int _barcodeQuantity = 1;
  String _selectedPaperSize = 'A4';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchAllProductsOnInit(); // Fetch all products once on page load
    _setupSearchListener();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchDebounceTimer?.cancel(); // Cancel timer on dispose
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh data when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _refreshProducts();
    }
  }

  // Fetch all products once when page loads
  Future<void> _fetchAllProductsOnInit() async {
    try {
      print('🚀 Initial load: Fetching all products');
      setState(() {
        errorMessage = null;
      });

      // Get provider instance
      final provider = Provider.of<InventoryProvider>(context, listen: false);

      // Check if products are already cached in provider
      if (provider.products.isNotEmpty) {
        print(
          '💾 Using cached products from provider: ${provider.products.length} products',
        );
        _allProductsCache = List.from(provider.products);
        _applyFiltersClientSide();
        return;
      }

      // Clear existing cache to prevent duplicates
      _allProductsCache.clear();
      _allFilteredProducts.clear();
      _filteredProducts.clear();

      // Fetch all products from all pages
      List<Product> allProducts = [];
      int currentFetchPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        try {
          print('📡 Fetching page $currentFetchPage');
          final response = await InventoryService.getProducts(
            page: currentFetchPage,
            limit: 50, // Use larger page size for efficiency
          );

          allProducts.addAll(response.data);
          print(
            '📦 Page $currentFetchPage: ${response.data.length} products (total: ${allProducts.length})',
          );

          // Check if there are more pages
          if (response.meta.currentPage >= response.meta.lastPage) {
            hasMorePages = false;
          } else {
            currentFetchPage++;
          }
        } catch (e) {
          print('❌ Error fetching page $currentFetchPage: $e');
          hasMorePages = false; // Stop fetching on error
        }
      }

      _allProductsCache = allProducts;
      print('💾 Cached ${_allProductsCache.length} total products');

      // Update provider cache
      provider.setProducts(allProducts);

      // Apply initial filters (which will be no filters, showing all products)
      _applyFiltersClientSide();
    } catch (e) {
      print('❌ Critical error in _fetchAllProductsOnInit: $e');
      if (!mounted) return;
      setState(() {
        errorMessage = 'Failed to load products. Please refresh the page.';
      });
    }
  }

  void _setupSearchListener() {
    _searchController.addListener(() {
      // Cancel previous timer
      _searchDebounceTimer?.cancel();

      // Set new timer for debounced search (500ms delay)
      _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        print('🔍 Search triggered: "${_searchController.text}"');
        setState(() {
          currentPage = 1; // Reset to first page when search changes
        });
        // Apply filters when search changes
        _applyFilters();
      });
    });
  }

  // Client-side only filter application
  void _applyFilters() {
    print('🎯 _applyFilters called - performing client-side filtering only');
    _applyFiltersClientSide();
  }

  // Pure client-side filtering method
  void _applyFiltersClientSide() {
    try {
      final searchText = _searchController.text.toLowerCase().trim();
      final hasSearch = searchText.isNotEmpty;
      final hasStatusFilter = selectedStatus != 'All';

      print(
        '🎯 Client-side filtering - search: "$searchText", status: "$selectedStatus"',
      );
      print('🎯 hasSearch: $hasSearch, hasStatusFilter: $hasStatusFilter');

      if (!mounted) return;
      setState(() {
        _isFilterActive = hasSearch || hasStatusFilter;
      });

      // Apply filters to cached products (no API calls)
      _filterCachedProducts(searchText);

      print('🔄 _isFilterActive: $_isFilterActive');
      print('📦 _allProductsCache.length: ${_allProductsCache.length}');
      print('🎯 _allFilteredProducts.length: ${_allFilteredProducts.length}');
      print('👀 _filteredProducts.length: ${_filteredProducts.length}');
    } catch (e) {
      print('❌ Error in _applyFiltersClientSide: $e');
      if (!mounted) return;
      setState(() {
        errorMessage = 'Search error: Please try a different search term';
      });
    }
  }

  // Filter cached products without any API calls
  void _filterCachedProducts(String searchText) {
    try {
      // Apply filters to cached products with enhanced error handling
      _allFilteredProducts = _allProductsCache.where((product) {
        try {
          // Status filter
          if (selectedStatus != 'All' && product.status != selectedStatus) {
            return false;
          }

          // Search filter
          if (searchText.isEmpty) {
            return true;
          }

          // Search in multiple fields with better null safety and error handling
          final productTitle = product.title.toLowerCase();
          final productDesignCode = product.designCode.toLowerCase();
          final productBarcode = product.barcode.toLowerCase();
          final vendorName = product.vendor.name?.toLowerCase() ?? '';
          final subCategoryId = product.subCategoryId.toLowerCase();

          return productTitle.contains(searchText) ||
              productDesignCode.contains(searchText) ||
              productBarcode.contains(searchText) ||
              vendorName.contains(searchText) ||
              subCategoryId.contains(searchText);
        } catch (e) {
          // If there's any error during filtering, exclude this product
          print('⚠️ Error filtering product ${product.id}: $e');
          return false;
        }
      }).toList();

      print(
        '🔍 After filtering: ${_allFilteredProducts.length} products match criteria',
      );
      print('📝 Search text: "$searchText", Status filter: "$selectedStatus"');

      // Update selection state: keep only products that are still in filtered results
      final filteredProductCodes = _allFilteredProducts
          .map((p) => p.designCode)
          .toSet();
      selectedProductCodes.retainAll(filteredProductCodes);

      // Apply local pagination to filtered results
      _paginateFilteredProducts();

      if (!mounted) return;
      setState(() {
        errorMessage = null;
      });
    } catch (e) {
      print('❌ Critical error in _filterCachedProducts: $e');
      if (!mounted) return;
      setState(() {
        errorMessage =
            'Search failed. Please try again with a simpler search term.';
        // Fallback: show empty results instead of crashing
        _filteredProducts = [];
        _allFilteredProducts = [];
      });
    }
  }

  // Apply local pagination to filtered products
  void _paginateFilteredProducts() {
    try {
      // Handle empty results case
      if (_allFilteredProducts.isEmpty) {
        if (!mounted) return;
        setState(() {
          _filteredProducts = [];
          // Update productResponse meta for pagination controls
          productResponse = ProductResponse(
            data: [],
            links: Links(),
            meta: Meta(
              currentPage: 1,
              lastPage: 1,
              links: [],
              path: "/products",
              perPage: itemsPerPage,
              total: 0,
            ),
          );
        });
        return;
      }

      final startIndex = (currentPage - 1) * itemsPerPage;
      final endIndex = startIndex + itemsPerPage;

      // Ensure startIndex is not greater than the list length
      if (startIndex >= _allFilteredProducts.length) {
        // Reset to page 1 if current page is out of bounds
        if (!mounted) return;
        setState(() {
          currentPage = 1;
        });
        _paginateFilteredProducts(); // Recursive call with corrected page
        return;
      }

      if (!mounted) return;
      setState(() {
        _filteredProducts = _allFilteredProducts.sublist(
          startIndex,
          endIndex > _allFilteredProducts.length
              ? _allFilteredProducts.length
              : endIndex,
        );

        // Update productResponse meta for pagination controls
        final totalPages = (_allFilteredProducts.length / itemsPerPage).ceil();
        print('📄 Pagination calculation:');
        print(
          '   📊 _allFilteredProducts.length: ${_allFilteredProducts.length}',
        );
        print('   📝 itemsPerPage: $itemsPerPage');
        print('   🔢 totalPages: $totalPages');
        print('   📍 currentPage: $currentPage');

        productResponse = ProductResponse(
          data: _filteredProducts,
          links: Links(), // Empty links for local pagination
          meta: Meta(
            currentPage: currentPage,
            lastPage: totalPages,
            links: [], // Empty links array for local pagination
            path: "/products", // Default path
            perPage: itemsPerPage,
            total: _allFilteredProducts.length,
          ),
        );

        // Update selectAll state based on current filtered products
        selectAll =
            _filteredProducts.isNotEmpty &&
            selectedProductCodes.length == _filteredProducts.length &&
            _filteredProducts.every(
              (product) => selectedProductCodes.contains(product.designCode),
            );
      });
    } catch (e) {
      print('❌ Error in _paginateFilteredProducts: $e');
      if (!mounted) return;
      setState(() {
        _filteredProducts = [];
        currentPage = 1;
      });
    }
  }

  // Handle page changes for both filtered and normal pagination
  Future<void> _changePage(int newPage) async {
    if (!mounted) return;
    setState(() {
      currentPage = newPage;
    });

    // Always use client-side pagination when we have cached products
    if (_allProductsCache.isNotEmpty) {
      _paginateFilteredProducts();
    }
  }

  Future<void> _refreshProducts() async {
    print('🔄 Refreshing products data...');
    await _fetchAllProductsOnInit();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Products refreshed successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void toggleSelectAll(bool? value) {
    if (_filteredProducts.isEmpty) return;

    if (!mounted) return;
    setState(() {
      if (value == true) {
        // Limit selection to maximum 10 products
        final productsToSelect = _filteredProducts.take(10);
        selectedProductCodes = productsToSelect
            .map((product) => product.designCode)
            .toSet();

        // Show warning if there are more than 10 products
        if (_filteredProducts.length > 10) {
          Future.microtask(() {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Maximum 10 products can be selected for barcode generation. Only first 10 products were selected.',
                  ),
                  backgroundColor: Colors.orange,
                  duration: Duration(seconds: 3),
                ),
              );
            }
          });
        }

        selectAll = selectedProductCodes.length == _filteredProducts.length;
      } else {
        selectedProductCodes.clear();
        selectAll = false;
      }
    });
  }

  void toggleProductSelection(String productCode, bool? value) {
    if (!mounted) return;
    setState(() {
      if (value == true) {
        // Check if adding this product would exceed the limit
        if (selectedProductCodes.length >= 10) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Maximum 10 products can be selected for barcode generation.',
              ),
              backgroundColor: Colors.orange,
            ),
          );
          return;
        }
        selectedProductCodes.add(productCode);
      } else {
        selectedProductCodes.remove(productCode);
      }

      // Update selectAll based on current filtered products
      selectAll =
          _filteredProducts.isNotEmpty &&
          selectedProductCodes.length == _filteredProducts.length &&
          _filteredProducts.every(
            (product) => selectedProductCodes.contains(product.designCode),
          );
    });
  }

  List<Product> getSelectedProducts() {
    if (productResponse == null) return [];
    return productResponse!.data
        .where((product) => selectedProductCodes.contains(product.designCode))
        .toList();
  }

  void generateAndPrintBarcode() {
    final selectedProducts = getSelectedProducts();
    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least one product to generate barcode',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Always show quantity and paper size selection first
    _showBarcodeQuantitySelectionDialog(selectedProducts);
  }

  void _showMultiProductBarcodeDialog(
    List<Product> selectedProducts,
    int quantity,
    String paperSize,
  ) {
    // Calculate dialog dimensions based on number of products
    final int itemsPerRow = 3;
    final int numberOfRows = (selectedProducts.length / itemsPerRow).ceil();
    final double rowHeight = 120; // Approximate height per barcode row
    final double headerHeight = 40; // Header text + spacing
    final double footerHeight = 40; // Footer text + spacing
    final double totalContentHeight =
        headerHeight + (numberOfRows * rowHeight) + footerHeight;
    final double dialogHeight = totalContentHeight.clamp(
      300,
      600,
    ); // Min 300, Max 600
    final double dialogWidth =
        680; // Fixed width to fit 3 barcodes (3 * 200 + margins)

    // Show barcode generation dialog with clean white design
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Text(
            'Barcode Preview',
            style: TextStyle(
              color: const Color(0xFF0D1845),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        color: const Color(0xFF0D1845),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${selectedProducts.length} product(s) selected • $quantity copy(ies) each • Paper: $paperSize',
                          style: const TextStyle(
                            color: Color(0xFF0D1845),
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Total barcodes to generate: ${selectedProducts.length * quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D1845),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: _buildBarcodeRows(selectedProducts),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'Barcodes will be generated for ${selectedProducts.length} product(s) with $quantity copy(ies) each',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _generateBarcodePDF(
                    selectedProducts,
                    quantity,
                    paperSize,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Barcodes generated successfully for ${selectedProducts.length} product(s) with $quantity copy(ies) each!',
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to generate barcodes: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D1845),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'Generate Barcodes',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        );
      },
    );
  }

  List<Widget> _buildBarcodeRows(List<Product> products) {
    List<Widget> rows = [];
    const int itemsPerRow = 3;

    for (int i = 0; i < products.length; i += itemsPerRow) {
      final endIndex = (i + itemsPerRow < products.length)
          ? i + itemsPerRow
          : products.length;
      final rowProducts = products.sublist(i, endIndex);

      rows.add(
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: rowProducts.map((product) {
              return Container(
                width: 200, // Fixed width instead of Expanded
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Text(
                      product.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF17A2B8),
                        fontSize: 11,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    BarcodeWidget(
                      // Use numeric-only EAN-13 barcode for printing/visualization
                      barcode: Barcode.ean13(),
                      data: getNumericBarcode(product),
                      width: 160,
                      height: 50,
                      drawText: true,
                      style: TextStyle(fontSize: 8, color: Colors.black),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Code: ${product.barcode}',
                      style: TextStyle(
                        fontSize: 8,
                        color: Color(0xFF6C757D),
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      );
    }

    return rows;
  }

  List<Widget> _buildQRCodeRows(List<Product> products) {
    List<Widget> rows = [];
    const int itemsPerRow = 3;

    for (int i = 0; i < products.length; i += itemsPerRow) {
      final endIndex = (i + itemsPerRow < products.length)
          ? i + itemsPerRow
          : products.length;
      final rowProducts = products.sublist(i, endIndex);

      rows.add(
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: rowProducts.map((product) {
              return Container(
                width: 180, // Fixed width for QR codes
                margin: const EdgeInsets.symmetric(horizontal: 4),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Column(
                  children: [
                    Text(
                      product.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF17A2B8),
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),
                    QrImageView(
                      data: _generateProductQRData(product),
                      size: 100,
                      backgroundColor: Colors.white,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Code: ${product.designCode}',
                      style: TextStyle(
                        fontSize: 8,
                        color: Color(0xFF6C757D),
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      );
    }

    return rows;
  }

  void generateQRCode() {
    final selectedProducts = getSelectedProducts();
    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please select at least one product to generate QR code',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Always show quantity and paper size selection first
    _showQRQuantitySelectionDialog(selectedProducts);
  }

  void _showQRQuantitySelectionDialog(List<Product> selectedProducts) {
    int dialogQuantity = _barcodeQuantity; // Local state for dialog
    final TextEditingController quantityController = TextEditingController(
      text: dialogQuantity.toString(),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: Row(
                children: [
                  Icon(Icons.qr_code, color: Color(0xFF0D1845), size: 24),
                  SizedBox(width: 12),
                  Text(
                    'Configure QR Code Generation',
                    style: TextStyle(
                      color: Color(0xFF0D1845),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Container(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Color(0xFFDEE2E6)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.inventory,
                            color: Color(0xFF6C757D),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${selectedProducts.length} product(s) selected',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF343A40),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Quantity per Product (1-1000):',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF343A40),
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      keyboardType: TextInputType.number,
                      controller: quantityController,
                      style: TextStyle(color: Color(0xFF343A40)),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Color(0xFF0D1845)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Enter quantity',
                        hintStyle: TextStyle(color: Color(0xFF6C757D)),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isEmpty) {
                          dialogQuantity = 1;
                        } else {
                          final quantity = int.tryParse(value);
                          if (quantity != null) {
                            dialogQuantity = quantity.clamp(1, 1000);
                          }
                        }
                        setDialogState(() {});
                      },
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Color(0xFFBBDEFB)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFF1976D2),
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Total QR codes to generate: ${selectedProducts.length * dialogQuantity}',
                              style: TextStyle(
                                color: Color(0xFF1976D2),
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    quantityController.dispose();
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Color(0xFF6C757D),
                  ),
                  child: Text('Cancel', style: TextStyle(fontSize: 14)),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _barcodeQuantity = dialogQuantity;
                    });
                    quantityController.dispose();
                    Navigator.of(context).pop();
                    _showMultiProductQRDialog(
                      selectedProducts,
                      dialogQuantity,
                      _selectedPaperSize,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0D1845),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    'Generate QR Codes',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showMultiProductQRDialog(
    List<Product> selectedProducts,
    int quantity,
    String paperSize,
  ) {
    // Calculate dialog dimensions based on number of products
    final int itemsPerRow = 3;
    final int numberOfRows = (selectedProducts.length / itemsPerRow).ceil();
    final double rowHeight = 140; // Approximate height per QR code row
    final double headerHeight = 40; // Header text + spacing
    final double footerHeight = 40; // Footer text + spacing
    final double totalContentHeight =
        headerHeight + (numberOfRows * rowHeight) + footerHeight;
    final double dialogHeight = totalContentHeight.clamp(
      300,
      600,
    ); // Min 300, Max 600
    final double dialogWidth =
        620; // Fixed width to fit 3 QR codes (3 * 180 + margins)

    // Show QR code generation dialog with clean white design
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Text(
            'QR Codes Preview',
            style: TextStyle(
              color: const Color(0xFF0D1845),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          content: SizedBox(
            width: dialogWidth,
            height: dialogHeight,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: const Color(0xFF0D1845),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${selectedProducts.length} product(s) selected • $quantity copy(ies) each • Paper: $paperSize',
                          style: const TextStyle(
                            color: Color(0xFF0D1845),
                            fontWeight: FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Total QR codes to generate: ${selectedProducts.length * quantity}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D1845),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Colors.grey.shade200),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          children: _buildQRCodeRows(selectedProducts),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    'QR codes will be generated for ${selectedProducts.length} product(s) with $quantity copy(ies) each',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
              ),
              child: const Text('Cancel', style: TextStyle(fontSize: 14)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.of(context).pop();
                try {
                  await _generateQRCodePDF(
                    selectedProducts,
                    quantity,
                    paperSize,
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'QR codes generated successfully for ${selectedProducts.length} product(s) with $quantity copy(ies) each!',
                        ),
                        backgroundColor: Colors.green,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Failed to generate QR codes: $e'),
                        backgroundColor: Colors.red,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0D1845),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 10,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: const Text(
                'Generate QR Codes',
                style: TextStyle(fontSize: 14),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showBarcodeQuantitySelectionDialog(List<Product> selectedProducts) {
    int dialogQuantity = _barcodeQuantity; // Local state for dialog
    final TextEditingController quantityController = TextEditingController(
      text: dialogQuantity.toString(),
    );

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: Row(
                children: [
                  Icon(
                    Icons.qr_code_scanner,
                    color: Color(0xFF0D1845),
                    size: 24,
                  ),
                  SizedBox(width: 12),
                  Text(
                    'Configure Barcode Generation',
                    style: TextStyle(
                      color: Color(0xFF0D1845),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Container(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Color(0xFFDEE2E6)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.inventory,
                            color: Color(0xFF6C757D),
                            size: 20,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${selectedProducts.length} product(s) selected',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF343A40),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: 20),
                    Text(
                      'Quantity per Product (1-1000):',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF343A40),
                        fontSize: 14,
                      ),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      keyboardType: TextInputType.number,
                      controller: quantityController,
                      style: TextStyle(color: Color(0xFF343A40)),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: BorderSide(color: Color(0xFF0D1845)),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Enter quantity',
                        hintStyle: TextStyle(color: Color(0xFF6C757D)),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (value) {
                        if (value.isEmpty) {
                          dialogQuantity = 1;
                        } else {
                          final quantity = int.tryParse(value);
                          if (quantity != null) {
                            dialogQuantity = quantity.clamp(1, 1000);
                          }
                        }
                        setDialogState(() {});
                      },
                    ),
                    SizedBox(height: 16),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Color(0xFFBBDEFB)),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Color(0xFF1976D2),
                            size: 16,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Total barcodes to generate: ${selectedProducts.length * dialogQuantity}',
                              style: TextStyle(
                                color: Color(0xFF1976D2),
                                fontWeight: FontWeight.w500,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    quantityController.dispose();
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: Color(0xFF6C757D),
                  ),
                  child: Text('Cancel', style: TextStyle(fontSize: 14)),
                ),
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _barcodeQuantity = dialogQuantity;
                    });
                    quantityController.dispose();
                    Navigator.of(context).pop();
                    _showMultiProductBarcodeDialog(
                      selectedProducts,
                      dialogQuantity,
                      _selectedPaperSize,
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0D1845),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  child: Text(
                    'Generate Barcodes',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _generateProductQRData(Product product) {
    final qrData = {
      'product_id': product.id,
      'title': product.title,
      'design_code': product.designCode,
      'barcode': product.barcode,
      'sale_price': product.salePrice,
      'buying_price': product.buyingPrice ?? 0,
      'opening_stock_quantity': product.openingStockQuantity,
      'vendor': {
        'id': product.vendorId,
        'name': product.vendor.name ?? 'Vendor ${product.vendorId}',
      },
      'category': product.subCategoryId,
      'images': product.imagePaths ?? [],
      'qr_code_data': product.qrCodeData,
      'status': product.status,
      'created_at': product.createdAt,
    };

    return jsonEncode(qrData);
  }

  /// Returns a numeric-only EAN-13 barcode string for [product].
  ///
  /// Strategy:
  /// 1. Try to extract digits from `product.barcode`.
  /// 2. If there are digits, build a 12-digit base (pad or trim) and append EAN-13 check digit.
  /// 3. If no digits are found, fall back to using product.id to form the base.
  // Numeric EAN-13 generation moved to shared util `lib/utils/barcode_utils.dart`

  Widget _buildSelectedProductsSummary() {
    final selectedProducts = getSelectedProducts();

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: Column(
        children: [
          Icon(Icons.check_circle, color: Colors.green, size: 18),
          const SizedBox(height: 4),
          Text(
            '${selectedProducts.length}',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Selected',
            style: TextStyle(
              fontSize: 10,
              color: Colors.white.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _headerStyle() {
    return const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Color(0xFF0D1845),
    );
  }

  TextStyle _cellStyle() {
    return const TextStyle(fontSize: 12, color: Color(0xFF6C757D));
  }

  Future<void> _generateBarcodePDF(
    List<Product> products,
    int quantity,
    String paperSize,
  ) async {
    final pdf = pw.Document();

    // Barcode sticker size: 2x1 inches (50.8mm x 25.4mm)
    const double stickerWidthMM = 50.8;
    const double stickerHeightMM = 25.4;

    // Convert mm to points (1 mm = 2.83465 points)
    const double mmToPoints = 2.83465;
    final double stickerWidth = stickerWidthMM * mmToPoints;
    final double stickerHeight = stickerHeightMM * mmToPoints;

    // Create custom page format for sticker
    final pageFormat = PdfPageFormat(stickerWidth, stickerHeight);

    // Generate one sticker per page for each product copy
    for (var product in products) {
      for (int i = 0; i < quantity; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.Container(
                width: stickerWidth,
                height: stickerHeight,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    // Top: Product Name
                    pw.Container(
                      height: stickerHeight * 0.20,
                      child: pw.Center(
                        child: pw.Text(
                          product.title,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                          maxLines: 2,
                          overflow: pw.TextOverflow.clip,
                        ),
                      ),
                    ),
                    // Middle: Barcode
                    pw.Container(
                      width: stickerWidth * 0.85,
                      height: stickerHeight * 0.40,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.ean13(),
                        data: getNumericBarcode(product),
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    // Below: Price
                    pw.Text(
                      'Rs. ${product.salePrice}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 1),
                    // Bottom: Store Name
                    pw.Text(
                      'Dhanpuri by Get Going',
                      style: pw.TextStyle(
                        fontSize: 6,
                        fontWeight: pw.FontWeight.normal,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }
    }

    // Save PDF to file
    final bytes = await pdf.save();

    // Use printing package to share/save the PDF
    await Printing.sharePdf(bytes: bytes, filename: 'barcode_stickers.pdf');
  }

  Future<void> _generateQRCodePDF(
    List<Product> products,
    int quantity,
    String paperSize,
  ) async {
    final pdf = pw.Document();

    // QR code sticker size: 2cm x 2cm (0.8in x 0.8in)
    const double stickerWidthCM = 2.0;
    const double stickerHeightCM = 2.0;

    // Convert cm to points (1 cm = 28.3465 points)
    const double cmToPoints = 28.3465;
    final double stickerWidth = stickerWidthCM * cmToPoints;
    final double stickerHeight = stickerHeightCM * cmToPoints;

    // Create custom page format for sticker
    final pageFormat = PdfPageFormat(stickerWidth, stickerHeight);

    // Generate one sticker per page for each product copy
    for (var product in products) {
      for (int i = 0; i < quantity; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.Container(
                width: stickerWidth,
                height: stickerHeight,
                child: pw.Center(
                  child: pw.BarcodeWidget(
                    barcode: pw.Barcode.qrCode(),
                    data: product.barcode,
                    width: stickerWidth * 0.95,
                    height: stickerHeight * 0.95,
                  ),
                ),
              );
            },
          ),
        );
      }
    }

    // Save PDF to file
    final bytes = await pdf.save();

    // Use printing package to share/save the PDF
    await Printing.sharePdf(bytes: bytes, filename: 'qr_stickers.pdf');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Print Barcode'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshProducts,
            tooltip: 'Refresh Products',
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, const Color(0xFFF8F9FA)],
          ),
        ),
        child: Column(
          children: [
            // Header with Summary Cards
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF0D1845).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              margin: const EdgeInsets.fromLTRB(24, 8, 24, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.qr_code_scanner,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Print Barcode',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Generate barcodes and QR codes for your products',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: generateAndPrintBarcode,
                        icon: const Icon(Icons.qr_code_scanner, size: 14),
                        label: const Text('Generate & Print Barcode'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0D1845),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Summary Cards
                  Row(
                    children: [
                      _buildSummaryCard(
                        'Total Products',
                        _allProductsCache.length.toString(),
                        Icons.inventory,
                        Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: _buildSelectedProductsSummary()),
                      const SizedBox(width: 12),
                      _buildSummaryCard(
                        'Filtered Products',
                        _filteredProducts.length.toString(),
                        Icons.filter_list,
                        Colors.orange,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search and Table
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Search and Filters Bar
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Flexible(
                                flex: 1,
                                child: SizedBox(
                                  height: 36,
                                  child: TextField(
                                    controller: _searchController,
                                    style: const TextStyle(fontSize: 13),
                                    decoration: InputDecoration(
                                      hintText: 'Search products...',
                                      hintStyle: const TextStyle(fontSize: 12),
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        size: 16,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                height: 36,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(6),
                                  color: Colors.white,
                                ),
                                child: DropdownButton<String>(
                                  value: selectedStatus,
                                  underline: const SizedBox(),
                                  items: ['All', 'Active', 'Inactive']
                                      .map(
                                        (status) => DropdownMenuItem<String>(
                                          value: status,
                                          child: Text(
                                            status,
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (value) {
                                    if (value != null) {
                                      if (!mounted) return;
                                      setState(() {
                                        selectedStatus = value;
                                      });
                                      _applyFilters();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 32,
                                child: ElevatedButton.icon(
                                  onPressed: generateQRCode,
                                  icon: const Icon(Icons.qr_code, size: 14),
                                  label: const Text(
                                    'Generate QR',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.purple,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Selection Controls
                          Row(
                            children: [
                              Checkbox(
                                value: selectAll,
                                onChanged: _filteredProducts.length > 10
                                    ? null // Disable if more than 10 products available
                                    : (value) => toggleSelectAll(value),
                                activeColor: const Color(0xFF0D1845),
                              ),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Select All',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        color: _filteredProducts.length > 10
                                            ? Colors.grey
                                            : const Color(0xFF343A40),
                                      ),
                                    ),
                                    if (_filteredProducts.length > 10)
                                      Text(
                                        'Limited to 10 products max',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.orange,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: selectedProductCodes.length >= 10
                                      ? const Color(0xFFFFF3CD)
                                      : const Color(0xFFE3F2FD),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      selectedProductCodes.length >= 10
                                          ? Icons.warning
                                          : Icons.check_circle,
                                      color: selectedProductCodes.length >= 10
                                          ? const Color(0xFF856404)
                                          : const Color(0xFF1976D2),
                                      size: 10,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${getSelectedProducts().length}/10 product(s) selected',
                                      style: TextStyle(
                                        color: selectedProductCodes.length >= 10
                                            ? const Color(0xFF856404)
                                            : const Color(0xFF1976D2),
                                        fontWeight: FontWeight.w500,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Select Column - Fixed width
                          SizedBox(
                            width: 60,
                            child: Text('Select', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          // Product Code Column
                          Expanded(
                            flex: 2,
                            child: Text('Product Code', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          // Product Name Column
                          Expanded(
                            flex: 3,
                            child: Text('Product Name', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          // Category Column
                          Expanded(
                            flex: 2,
                            child: Text('Category', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          // Vendor Column
                          Expanded(
                            flex: 2,
                            child: Text('Vendor', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          // Price Column - Centered
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: Text('Price (PKR)', style: _headerStyle()),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Qty Column - Centered
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: Text('Qty', style: _headerStyle()),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Body
                    Expanded(
                      child: errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    errorMessage!,
                                    style: const TextStyle(color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _fetchAllProductsOnInit,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _filteredProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inventory_2_outlined,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _isFilterActive
                                        ? 'No products match your filters'
                                        : 'No products found',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  if (_isFilterActive) ...[
                                    const SizedBox(height: 8),
                                    TextButton(
                                      onPressed: () {
                                        if (!mounted) return;
                                        setState(() {
                                          _searchController.clear();
                                          selectedStatus = 'All';
                                          _isFilterActive = false;
                                        });
                                        _applyFilters();
                                      },
                                      child: const Text('Clear Filters'),
                                    ),
                                  ],
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredProducts.length,
                              itemBuilder: (context, index) {
                                final product = _filteredProducts[index];
                                final quantity =
                                    int.tryParse(
                                      product.openingStockQuantity,
                                    ) ??
                                    0;
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: index % 2 == 0
                                        ? Colors.white
                                        : Colors.grey[50],
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Select Column - Fixed width
                                      SizedBox(
                                        width: 60,
                                        child: Checkbox(
                                          value: selectedProductCodes.contains(
                                            product.designCode,
                                          ),
                                          onChanged:
                                              selectedProductCodes.length >=
                                                      10 &&
                                                  !selectedProductCodes
                                                      .contains(
                                                        product.designCode,
                                                      )
                                              ? null // Disable if limit reached and this item isn't selected
                                              : (value) =>
                                                    toggleProductSelection(
                                                      product.designCode,
                                                      value,
                                                    ),
                                          activeColor: const Color(0xFF0D1845),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Product Code Column
                                      Expanded(
                                        flex: 2,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 4,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFF8F9FA),
                                            borderRadius: BorderRadius.circular(
                                              3,
                                            ),
                                          ),
                                          child: Text(
                                            product.designCode,
                                            style: const TextStyle(
                                              fontFamily: 'monospace',
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0D1845),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Product Name Column
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              product.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF343A40),
                                                fontSize: 12,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            Text(
                                              'Code: ${product.designCode}',
                                              style: const TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF6C757D),
                                                fontFamily: 'monospace',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Category Column
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            Expanded(
                                              child: Text(
                                                'Category ${product.subCategoryId}',
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF495057),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Vendor Column
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          product.vendor.name ??
                                              'Vendor ${product.vendorId}',
                                          style: _cellStyle(),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Price Column - Centered
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Text(
                                            'PKR ${product.salePrice}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF28A745),
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Qty Column - Centered
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: quantity < 50
                                                  ? const Color(0xFFFFF3CD)
                                                  : const Color(0xFFD4EDDA),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              quantity.toString(),
                                              style: TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: quantity < 50
                                                    ? const Color(0xFF856404)
                                                    : const Color(0xFF155724),
                                                fontSize: 11,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Enhanced Pagination
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Previous button
                  ElevatedButton.icon(
                    onPressed: currentPage > 1
                        ? () => _changePage(currentPage - 1)
                        : null,
                    icon: Icon(Icons.chevron_left, size: 14),
                    label: Text('Previous', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: currentPage > 1
                          ? const Color(0xFF0D1845)
                          : const Color(0xFF6C757D),
                      elevation: 0,
                      side: const BorderSide(color: Color(0xFFDEE2E6)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Page numbers
                  ..._buildPageButtons(),

                  const SizedBox(width: 8),

                  // Next button
                  ElevatedButton.icon(
                    onPressed:
                        (productResponse?.meta != null &&
                            currentPage < productResponse!.meta.lastPage)
                        ? () => _changePage(currentPage + 1)
                        : null,
                    icon: Icon(Icons.chevron_right, size: 14),
                    label: Text('Next', style: TextStyle(fontSize: 11)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          (productResponse?.meta != null &&
                              currentPage < productResponse!.meta.lastPage)
                          ? const Color(0xFF0D1845)
                          : Colors.grey.shade300,
                      foregroundColor:
                          (productResponse?.meta != null &&
                              currentPage < productResponse!.meta.lastPage)
                          ? Colors.white
                          : Colors.grey.shade600,
                      elevation:
                          (productResponse?.meta != null &&
                              currentPage < productResponse!.meta.lastPage)
                          ? 2
                          : 0,
                      side:
                          (productResponse?.meta != null &&
                              currentPage < productResponse!.meta.lastPage)
                          ? null
                          : const BorderSide(color: Color(0xFFDEE2E6)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(5),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                    ),
                  ),

                  // Page info
                  if (productResponse != null) ...[
                    const SizedBox(width: 16),
                    Builder(
                      builder: (context) {
                        final meta = productResponse!.meta;
                        return Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFFF8F9FA),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Page $currentPage of ${meta.lastPage} (${meta.total} total)',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF6C757D),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Color _getCategoryColor(String category) {
    switch (category) {
      case 'Computers':
        return Color(0xFF17A2B8);
      case 'Electronics':
        return Color(0xFF28A745);
      case 'Shoe':
        return Color(0xFFDC3545);
      default:
        return Color(0xFF6C757D);
    }
  }

  List<Widget> _buildPageButtons() {
    if (productResponse?.meta == null) {
      return [];
    }

    final meta = productResponse!.meta;
    final totalPages = meta.lastPage;
    final current = meta.currentPage;

    // Show max 5 page buttons centered around current page
    const maxButtons = 5;
    final halfRange = maxButtons ~/ 2; // 2

    // Calculate desired start and end
    int startPage = (current - halfRange).clamp(1, totalPages);
    int endPage = (startPage + maxButtons - 1).clamp(1, totalPages);

    // If endPage exceeds totalPages, adjust startPage
    if (endPage > totalPages) {
      endPage = totalPages;
      startPage = (endPage - maxButtons + 1).clamp(1, totalPages);
    }

    List<Widget> buttons = [];

    for (int i = startPage; i <= endPage; i++) {
      buttons.add(
        Container(
          margin: EdgeInsets.symmetric(horizontal: 1),
          child: ElevatedButton(
            onPressed: i == current ? null : () => _changePage(i),
            style: ElevatedButton.styleFrom(
              backgroundColor: i == current
                  ? const Color(0xFF0D1845)
                  : Colors.white,
              foregroundColor: i == current
                  ? Colors.white
                  : const Color(0xFF6C757D),
              elevation: i == current ? 2 : 0,
              side: i == current
                  ? null
                  : const BorderSide(color: Color(0xFFDEE2E6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(28, 28),
            ),
            child: Text(
              i.toString(),
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
            ),
          ),
        ),
      );
    }

    return buttons;
  }
}
