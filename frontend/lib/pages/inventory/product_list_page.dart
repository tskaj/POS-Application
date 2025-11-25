import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../../services/inventory_service.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf_pkg;
import '../../models/product.dart';
import '../../models/sub_category.dart';
import '../../models/vendor.dart' as vendor;
import '../../utils/barcode_utils.dart';
import '../../providers/providers.dart';
import 'product_details_page.dart';
import 'edit_product_page.dart';

class ProductListPage extends StatefulWidget {
  const ProductListPage({super.key});

  @override
  State<ProductListPage> createState() => _ProductListPageState();
}

class _ProductListPageState extends State<ProductListPage>
    with WidgetsBindingObserver, RouteAware {
  ProductResponse? productResponse;
  List<Product> _filteredProducts = [];
  List<Product> _allFilteredProducts =
      []; // Store all filtered products for local pagination
  List<Product> _allProductsCache =
      []; // Cache for all products to avoid refetching
  bool isLoading = false; // Start with false to show UI immediately
  String? errorMessage;
  int currentPage = 1;
  final int itemsPerPage = 17;
  Timer? _searchDebounceTimer; // Add debounce timer for search
  bool _isFilterActive = false; // Track if any filter is currently active

  // Search and filter controllers
  final TextEditingController _searchController = TextEditingController();
  String? selectedVendor;

  // Selection state
  Set<int> selectedProductIds = {};
  bool selectAll = false;

  // Sub categories and vendors for dropdowns
  List<SubCategory> _subCategories = [];
  List<vendor.Vendor> _vendors = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchAllProductsOnInit(); // Fetch all products once on page load
    _fetchSubCategories();
    _fetchVendors();
    _setupSearchListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to RouteObserver
    final modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute) {
      final routeObserver = context
          .findAncestorStateOfType<State<StatefulWidget>>()
          ?.context
          .findAncestorWidgetOfExactType<MaterialApp>()
          ?.navigatorObservers
          ?.whereType<RouteObserver<PageRoute<dynamic>>>()
          .firstOrNull;

      if (routeObserver != null) {
        routeObserver.subscribe(this, modalRoute);
      }
    }
  }

  @override
  void dispose() {
    // Unsubscribe from RouteObserver
    final modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute) {
      final routeObserver = context
          .findAncestorStateOfType<State<StatefulWidget>>()
          ?.context
          .findAncestorWidgetOfExactType<MaterialApp>()
          ?.navigatorObservers
          ?.whereType<RouteObserver<PageRoute<dynamic>>>()
          .firstOrNull;

      if (routeObserver != null) {
        routeObserver.unsubscribe(this);
      }
    }

    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _searchDebounceTimer?.cancel(); // Cancel timer on dispose
    super.dispose();
  }

  // RouteAware callbacks
  @override
  void didPush() {
    // Called when the current route has been pushed
    print('📍 ProductListPage: didPush - refreshing products');
    _refreshProducts();
  }

  @override
  void didPopNext() {
    // Called when the top route has been popped off, and the current route shows up
    print('📍 ProductListPage: didPopNext - refreshing products');
    _refreshProducts();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Refresh data when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _refreshProducts();
    }
  }

  Future<void> _fetchSubCategories() async {
    try {
      final response = await InventoryService.getSubCategories(limit: 1000);
      setState(() {
        _subCategories = response.data;
      });
    } catch (e) {
      print('Error fetching sub categories: $e');
      // Don't show error to user, just use empty list
      setState(() {
        _subCategories = [];
      });
    }
  }

  Future<void> _fetchVendors() async {
    try {
      final response = await InventoryService.getVendors(limit: 1000);
      setState(() {
        _vendors = response.data;
      });
      print('📦 Fetched ${_vendors.length} vendors');

      // Populate vendor data for cached products if they exist
      if (_allProductsCache.isNotEmpty) {
        _populateVendorDataForProducts();
      }
    } catch (e) {
      print('Error fetching vendors: $e');
      // Don't show error to user, just use empty list
      setState(() {
        _vendors = [];
      });
    }
  }

  // Populate vendor data for products by matching vendor IDs
  void _populateVendorDataForProducts() {
    if (_vendors.isEmpty || _allProductsCache.isEmpty) {
      print('⚠️ Cannot populate vendor data: vendors or products not loaded');
      return;
    }

    print('🔗 Populating vendor data for ${_allProductsCache.length} products');

    // Create a map for faster vendor lookup
    final vendorMap = {for (var vendor in _vendors) vendor.id: vendor};

    // Update products with vendor data
    for (int i = 0; i < _allProductsCache.length; i++) {
      final product = _allProductsCache[i];
      final vendorId = int.tryParse(product.vendorId);

      if (vendorId != null && vendorMap.containsKey(vendorId)) {
        final vendor = vendorMap[vendorId]!;
        // Create a new product with populated vendor data
        _allProductsCache[i] = Product(
          id: product.id,
          title: product.title,
          designCode: product.designCode,
          imagePath: product.imagePath,
          subCategoryId: product.subCategoryId,
          salePrice: product.salePrice,
          openingStockQuantity: product.openingStockQuantity,
          inStockQuantity: product.inStockQuantity,
          vendorId: product.vendorId,
          vendor: ProductVendor(
            id: vendor.id,
            name: vendor.fullName, // Use fullName from Vendor model
            email: null, // Vendor model doesn't have email
            phone: null, // Vendor model doesn't have phone
            address: vendor.address,
            status: vendor.status,
            createdAt: vendor.createdAt,
            updatedAt: vendor.updatedAt,
          ),
          barcode: product.barcode,
          status: product.status,
          createdAt: product.createdAt,
          updatedAt: product.updatedAt,
        );
      } else {
        print(
          '⚠️ No vendor found for product "${product.title}" with vendorId: ${product.vendorId}',
        );
      }
    }

    print('✅ Vendor data populated for products');

    // Re-apply current filters to update the display
    _applyFiltersClientSide();
  }

  // Get unique vendors for dropdown
  List<String> _getUniqueVendors() {
    final vendors = <String>{};
    for (var vendor in _vendors) {
      if (vendor.fullName != null && vendor.fullName.isNotEmpty) {
        vendors.add(vendor.fullName);
      }
    }
    return ['All', ...vendors.toList()..sort()];
  }

  Future<void> _fetchAllProductsOnInit() async {
    final inventoryProvider = Provider.of<InventoryProvider>(
      context,
      listen: false,
    );

    if (inventoryProvider.products.isNotEmpty) {
      print('📦 Using pre-fetched products from provider');
      setState(() {
        _allProductsCache = inventoryProvider.products;
      });
      _populateVendorDataForProducts();
      _applyFiltersClientSide();
    } else {
      print('🚀 Pre-fetch not available, fetching products');
      try {
        print('🚀 Initial load: Fetching all products');
        setState(() {
          errorMessage = null;
        });

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

        // Update the provider cache
        context.read<InventoryProvider>().setProducts(allProducts);

        // Populate vendor data for all products
        _populateVendorDataForProducts();

        // Apply initial filters (which will be no filters, showing all products)
        _applyFiltersClientSide();
      } catch (e) {
        print('❌ Critical error in _fetchAllProductsOnInit: $e');
        setState(() {
          errorMessage = 'Failed to load products. Please refresh the page.';
          isLoading = false;
        });
      }
    }
  }

  // Force refresh products from server after adding new product
  Future<void> _refreshProductsAfterAdd() async {
    print('🔄 ProductListPage: _refreshProductsAfterAdd() started');
    try {
      print('🔄 Force refreshing products after add');
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Always fetch fresh data from server, ignore provider cache
      List<Product> allProducts = [];
      int currentFetchPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        print('📄 Force fetching page $currentFetchPage after add');
        final response = await InventoryService.getProducts(
          page: currentFetchPage,
          limit: 100,
        );

        allProducts.addAll(response.data);
        hasMorePages = response.meta.currentPage < response.meta.lastPage;
        currentFetchPage++;
      }

      setState(() {
        _allProductsCache = allProducts;
        print(
          '💾 Refreshed cache with ${_allProductsCache.length} total products',
        );
      });

      // Update the provider cache
      context.read<InventoryProvider>().setProducts(allProducts);

      // Populate vendor data for all products
      _populateVendorDataForProducts();

      // Reset to page 1 and apply current filters
      setState(() {
        currentPage = 1;
        isLoading = false; // Stop loading indicator
      });
      _applyFiltersClientSide();

      print('✅ Product list refreshed successfully after add');
    } catch (e) {
      print('❌ Error refreshing products after add: $e');
      setState(() {
        errorMessage = 'Failed to refresh products: $e';
        isLoading = false;
      });
    }
  }

  Future<void> _refreshProducts() async {
    try {
      print('🔄 Background refresh: Refreshing products');
      setState(() {
        errorMessage = null;
      });

      // Clear cache to force fresh data
      _allProductsCache.clear();

      // Fetch fresh data from server
      List<Product> allProducts = [];
      int currentFetchPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        print('📡 Background refresh: Fetching page $currentFetchPage');
        final response = await InventoryService.getProducts(
          page: currentFetchPage,
          limit: 50,
        );

        allProducts.addAll(response.data);
        print(
          '📦 Background refresh: Page $currentFetchPage: ${response.data.length} products (total: ${allProducts.length})',
        );

        if (response.meta.currentPage >= response.meta.lastPage) {
          hasMorePages = false;
        } else {
          currentFetchPage++;
        }
      }

      setState(() {
        _allProductsCache = allProducts;
        print(
          '💾 Background refresh: Cached ${_allProductsCache.length} total products',
        );
      });

      // Update the provider cache
      context.read<InventoryProvider>().setProducts(allProducts);

      // Populate vendor data for all products
      _populateVendorDataForProducts();

      // Re-apply current filters to update the display
      _applyFiltersClientSide();

      print('✅ Background refresh: Product list refreshed successfully');
    } catch (e) {
      print('❌ Background refresh error: $e');
      // Don't show error to user for background refresh, just log it
    }

    print('✅ Background refresh: Product list refreshed successfully');
  }

  void _setupSearchListener() {
    _searchController.addListener(() {
      // Cancel previous timer
      _searchDebounceTimer?.cancel();

      // Set new timer for debounced search (500ms delay)
      _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
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
      final hasVendorFilter = selectedVendor != null && selectedVendor != 'All';

      print(
        '🎯 Client-side filtering - search: "$searchText", vendor: "$selectedVendor"',
      );
      print('📊 hasSearch: $hasSearch, hasVendorFilter: $hasVendorFilter');

      setState(() {
        _isFilterActive = hasSearch || hasVendorFilter;
      });

      // Apply filters to cached products (no API calls)
      _filterCachedProducts(searchText);

      print('🔄 _isFilterActive: $_isFilterActive');
      print('📦 _allProductsCache.length: ${_allProductsCache.length}');
      print('🎯 _allFilteredProducts.length: ${_allFilteredProducts.length}');
      print('👀 _filteredProducts.length: ${_filteredProducts.length}');
    } catch (e) {
      print('❌ Error in _applyFiltersClientSide: $e');
      setState(() {
        errorMessage = 'Search error: Please try a different search term';
        isLoading = false;
        _filteredProducts = [];
      });
    }
  }

  // Filter cached products without any API calls
  void _filterCachedProducts(String searchText) {
    try {
      // Apply filters to cached products with enhanced error handling
      _allFilteredProducts = _allProductsCache.where((product) {
        try {
          // Vendor filter
          if (selectedVendor != null && selectedVendor != 'All') {
            final vendorName = product.vendor.name ?? '';
            if (vendorName != selectedVendor) {
              return false;
            }
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
      print('📝 Search text: "$searchText", Vendor: "$selectedVendor"');

      // Update selection state: keep only products that are still in filtered results
      final filteredProductIds = _allFilteredProducts.map((p) => p.id).toSet();
      selectedProductIds.retainAll(filteredProductIds);

      // Apply local pagination to filtered results
      _paginateFilteredProducts();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('❌ Critical error in _filterCachedProducts: $e');
      setState(() {
        errorMessage =
            'Search failed. Please try again with a simpler search term.';
        isLoading = false;
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
        setState(() {
          currentPage = 1;
        });
        _paginateFilteredProducts(); // Recursive call with corrected page
        return;
      }

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
      });
    } catch (e) {
      print('❌ Error in _paginateFilteredProducts: $e');
      setState(() {
        _filteredProducts = [];
        currentPage = 1;
      });
    }
  }

  // Handle page changes for both filtered and normal pagination
  Future<void> _changePage(int newPage) async {
    setState(() {
      currentPage = newPage;
    });

    // Always use client-side pagination when we have cached products
    if (_allProductsCache.isNotEmpty) {
      _paginateFilteredProducts();
    } else {
      // Fallback to server pagination only if no cached data
      await _fetchProducts(page: newPage);
    }
  }

  Future<void> _fetchProducts({int page = 1}) async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await InventoryService.getProducts(
        page: page,
        limit: itemsPerPage,
      );
      setState(() {
        productResponse = response;
        currentPage = page;
        isLoading = false;
        _filteredProducts = response.data;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> exportToPDF() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D1845)),
                ),
                SizedBox(width: 16),
                Text('Fetching all products...'),
              ],
            ),
          );
        },
      );

      // Always fetch ALL products from database for export
      List<Product> allProductsForExport = [];

      try {
        // Fetch ALL products with unlimited pagination
        int currentPage = 1;
        bool hasMorePages = true;

        while (hasMorePages) {
          final pageResponse = await InventoryService.getProducts(
            page: currentPage,
            limit: 100, // Fetch in chunks of 100
          );

          allProductsForExport.addAll(pageResponse.data);

          // Check if there are more pages
          if (pageResponse.meta.currentPage >= pageResponse.meta.lastPage) {
            hasMorePages = false;
          } else {
            currentPage++;
          }

          // Update loading message
          Navigator.of(context).pop();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                content: Row(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF0D1845),
                      ),
                    ),
                    SizedBox(width: 16),
                    Text('Fetched ${allProductsForExport.length} products...'),
                  ],
                ),
              );
            },
          );
        }

        // Apply filters if any are active
        if (_searchController.text.isNotEmpty || selectedVendor != null) {
          final searchText = _searchController.text.toLowerCase().trim();
          allProductsForExport = allProductsForExport.where((product) {
            // Vendor filter
            if (selectedVendor != null && selectedVendor != 'All') {
              if (product.vendor.name != selectedVendor) {
                return false;
              }
            }

            // Search filter
            if (searchText.isEmpty) {
              return true;
            }

            // Search in multiple fields
            return product.title.toLowerCase().contains(searchText) ||
                product.designCode.toLowerCase().contains(searchText) ||
                product.barcode.toLowerCase().contains(searchText) ||
                product.vendor.name?.toLowerCase().contains(searchText) ==
                    true ||
                product.subCategoryId.toLowerCase().contains(searchText);
          }).toList();
        }
      } catch (e) {
        print('Error fetching all products: $e');
        // Fallback to current data
        allProductsForExport = _filteredProducts.isNotEmpty
            ? _filteredProducts
            : (productResponse?.data ?? []);
      }

      if (allProductsForExport.isEmpty) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No products to export'),
            backgroundColor: Color(0xFFDC3545),
          ),
        );
        return;
      }

      // Update loading message
      Navigator.of(context).pop();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D1845)),
                ),
                SizedBox(width: 16),
                Text(
                  'Generating PDF with ${allProductsForExport.length} products...',
                ),
              ],
            ),
          );
        },
      );

      // Create a new PDF document with landscape orientation for better table fit
      final PdfDocument document = PdfDocument();

      // Set page to landscape for better table visibility
      document.pageSettings.orientation = PdfPageOrientation.landscape;
      document.pageSettings.size = PdfPageSize.a4;

      // Define fonts - adjusted for landscape
      final PdfFont titleFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        18,
        style: PdfFontStyle.bold,
      );
      final PdfFont headerFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        11,
        style: PdfFontStyle.bold,
      );
      final PdfFont regularFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
      final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 9);

      // Colors
      final PdfColor headerColor = PdfColor(
        13,
        24,
        69,
      ); // Product page theme color
      final PdfColor tableHeaderColor = PdfColor(248, 249, 250);

      // Create table with proper settings for pagination
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 6);

      // Use full page width but account for table borders and padding
      final double pageWidth =
          document.pageSettings.size.width -
          15; // Only 15px left margin, 0px right margin
      final double tableWidth =
          pageWidth *
          0.85; // Use 85% to ensure right boundary is clearly visible

      // Balanced column widths for products
      grid.columns[0].width = tableWidth * 0.12; // 12% - Product Code
      grid.columns[1].width = tableWidth * 0.20; // 20% - Product Name
      grid.columns[2].width = tableWidth * 0.15; // 15% - Barcode
      grid.columns[3].width = tableWidth * 0.18; // 18% - Vendor
      grid.columns[4].width = tableWidth * 0.10; // 10% - Price
      grid.columns[5].width = tableWidth * 0.10; // 10% - Quantity

      // Enable automatic page breaking and row splitting
      grid.allowRowBreakingAcrossPages = true;

      // Set grid style with better padding for readability
      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 4, right: 4, top: 4, bottom: 4),
        font: smallFont,
      );

      // Add header row
      final PdfGridRow headerRow = grid.headers.add(1)[0];
      headerRow.cells[0].value = 'Product Code';
      headerRow.cells[1].value = 'Product Name';
      headerRow.cells[2].value = 'Barcode';
      headerRow.cells[3].value = 'Vendor';
      headerRow.cells[4].value = 'Price';
      headerRow.cells[5].value = 'Quantity';

      // Style header row
      for (int i = 0; i < headerRow.cells.count; i++) {
        headerRow.cells[i].style = PdfGridCellStyle(
          backgroundBrush: PdfSolidBrush(tableHeaderColor),
          textBrush: PdfSolidBrush(PdfColor(73, 80, 87)),
          font: headerFont,
          format: PdfStringFormat(
            alignment: PdfTextAlignment.center,
            lineAlignment: PdfVerticalAlignment.middle,
          ),
        );
      }

      // Add all product data rows
      for (var product in allProductsForExport) {
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = product.designCode;
        row.cells[1].value = product.title;
        row.cells[2].value = getNumericBarcode(product);
        row.cells[3].value = product.vendor.name ?? 'N/A';
        row.cells[4].value = 'PKR ${product.salePrice}';
        row.cells[5].value = product.inStockQuantity;

        // Style data cells with better text wrapping
        for (int i = 0; i < row.cells.count; i++) {
          row.cells[i].style = PdfGridCellStyle(
            font: smallFont,
            textBrush: PdfSolidBrush(PdfColor(33, 37, 41)),
            format: PdfStringFormat(
              alignment: i == 4 || i == 5
                  ? PdfTextAlignment.center
                  : PdfTextAlignment.left,
              lineAlignment: PdfVerticalAlignment.top,
              wordWrap: PdfWordWrapType.word,
            ),
          );
        }
      }

      // Set up page template for headers and footers
      final PdfPageTemplateElement headerTemplate = PdfPageTemplateElement(
        Rect.fromLTWH(0, 0, document.pageSettings.size.width, 50),
      );

      // Draw header on template - minimal left margin, full width
      headerTemplate.graphics.drawString(
        'Complete Products Database Export',
        titleFont,
        brush: PdfSolidBrush(headerColor),
        bounds: Rect.fromLTWH(
          15,
          10,
          document.pageSettings.size.width - 15,
          25,
        ),
      );

      headerTemplate.graphics.drawString(
        'Total Products: ${allProductsForExport.length} | Generated: ${DateTime.now().toString().substring(0, 19)} | Filters: ${selectedVendor != 'All' ? 'Vendor=$selectedVendor' : 'All'} ${_searchController.text.isNotEmpty ? ', Search="${_searchController.text}"' : ''}',
        regularFont,
        brush: PdfSolidBrush(PdfColor(108, 117, 125)),
        bounds: Rect.fromLTWH(
          15,
          32,
          document.pageSettings.size.width - 15,
          15,
        ),
      );

      // Add line under header - full width
      headerTemplate.graphics.drawLine(
        PdfPen(PdfColor(200, 200, 200), width: 1),
        Offset(15, 48),
        Offset(document.pageSettings.size.width, 48),
      );

      // Create footer template
      final PdfPageTemplateElement footerTemplate = PdfPageTemplateElement(
        Rect.fromLTWH(
          0,
          document.pageSettings.size.height - 25,
          document.pageSettings.size.width,
          25,
        ),
      );

      // Draw footer - full width
      footerTemplate.graphics.drawString(
        'Page \$PAGE of \$TOTAL | ${allProductsForExport.length} Total Products | Generated from POS System',
        regularFont,
        brush: PdfSolidBrush(PdfColor(108, 117, 125)),
        bounds: Rect.fromLTWH(15, 8, document.pageSettings.size.width - 15, 15),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // Apply templates to document
      document.template.top = headerTemplate;
      document.template.bottom = footerTemplate;

      // Draw the grid with automatic pagination - use full width, minimal left margin
      grid.draw(
        page: document.pages.add(),
        bounds: Rect.fromLTWH(
          15,
          55,
          document.pageSettings.size.width - 15,
          document.pageSettings.size.height - 85,
        ),
        format: PdfLayoutFormat(
          layoutType: PdfLayoutType.paginate,
          breakType: PdfLayoutBreakType.fitPage,
        ),
      );

      // Get page count before disposal
      final int pageCount = document.pages.count;
      print(
        'PDF generated with $pageCount page(s) for ${allProductsForExport.length} products',
      );

      // Save PDF
      final List<int> bytes = await document.save();
      document.dispose();

      // Close loading dialog
      Navigator.of(context).pop();

      // Let user choose save location
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Complete Products Database PDF',
        fileName:
            'complete_products_${DateTime.now().millisecondsSinceEpoch}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Complete Database Exported!\n📊 ${allProductsForExport.length} products across $pageCount pages\n📄 Landscape format for better visibility',
              ),
              backgroundColor: Color(0xFF28A745),
              duration: Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
                onPressed: () async {
                  try {
                    await Process.run('explorer', ['/select,', outputFile]);
                  } catch (e) {
                    print('File saved at: $outputFile');
                  }
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if it's open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Color(0xFFDC3545),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> exportToExcel() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D1845)),
                ),
                SizedBox(width: 16),
                Text('Fetching all products...'),
              ],
            ),
          );
        },
      );

      // Always fetch ALL products from database for export
      List<Product> allProductsForExport = [];

      try {
        // Fetch ALL products with unlimited pagination
        int currentPage = 1;
        bool hasMorePages = true;

        while (hasMorePages) {
          final pageResponse = await InventoryService.getProducts(
            page: currentPage,
            limit: 100, // Fetch in chunks of 100
          );

          allProductsForExport.addAll(pageResponse.data);

          // Check if there are more pages
          if (pageResponse.meta.currentPage >= pageResponse.meta.lastPage) {
            hasMorePages = false;
          } else {
            currentPage++;
          }

          // Update loading message
          Navigator.of(context).pop();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                content: Row(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF0D1845),
                      ),
                    ),
                    SizedBox(width: 16),
                    Text('Fetched ${allProductsForExport.length} products...'),
                  ],
                ),
              );
            },
          );
        }

        // Apply filters if any are active
        if (_searchController.text.isNotEmpty || selectedVendor != null) {
          final searchText = _searchController.text.toLowerCase().trim();
          allProductsForExport = allProductsForExport.where((product) {
            // Vendor filter
            if (selectedVendor != null && selectedVendor != 'All') {
              if (product.vendor.name != selectedVendor) {
                return false;
              }
            }

            // Search filter
            if (searchText.isEmpty) {
              return true;
            }

            // Search in multiple fields
            return product.title.toLowerCase().contains(searchText) ||
                product.designCode.toLowerCase().contains(searchText) ||
                product.barcode.toLowerCase().contains(searchText) ||
                product.vendor.name?.toLowerCase().contains(searchText) ==
                    true ||
                product.subCategoryId.toLowerCase().contains(searchText);
          }).toList();
        }
      } catch (e) {
        print('Error fetching all products: $e');
        // Fallback to current data
        allProductsForExport = _filteredProducts.isNotEmpty
            ? _filteredProducts
            : (productResponse?.data ?? []);
      }

      if (allProductsForExport.isEmpty) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No products to export'),
            backgroundColor: Color(0xFFDC3545),
          ),
        );
        return;
      }

      // Update loading message
      Navigator.of(context).pop();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D1845)),
                ),
                SizedBox(width: 16),
                Text(
                  'Generating Excel with ${allProductsForExport.length} products...',
                ),
              ],
            ),
          );
        },
      );

      // Create Excel document
      final excel_pkg.Excel excel = excel_pkg.Excel.createExcel();
      final excel_pkg.Sheet sheet = excel['Products'];

      // Add header row with styling
      final headerStyle = excel_pkg.CellStyle(
        bold: true,
        fontSize: 12,
        horizontalAlign: excel_pkg.HorizontalAlign.Center,
      );

      sheet.appendRow([
        excel_pkg.TextCellValue('Product Code'),
        excel_pkg.TextCellValue('Product Name'),
        excel_pkg.TextCellValue('Barcode'),
        excel_pkg.TextCellValue('Vendor'),
        excel_pkg.TextCellValue('Price'),
        excel_pkg.TextCellValue('Quantity'),
      ]);

      // Apply header styling
      for (int i = 0; i < 6; i++) {
        sheet
                .cell(
                  excel_pkg.CellIndex.indexByColumnRow(
                    columnIndex: i,
                    rowIndex: 0,
                  ),
                )
                .cellStyle =
            headerStyle;
      }

      // Add all product data rows
      for (var product in allProductsForExport) {
        sheet.appendRow([
          excel_pkg.TextCellValue(product.designCode),
          excel_pkg.TextCellValue(product.title),
          excel_pkg.TextCellValue(getNumericBarcode(product)),
          excel_pkg.TextCellValue(product.vendor.name ?? 'N/A'),
          excel_pkg.TextCellValue('PKR ${product.salePrice}'),
          excel_pkg.TextCellValue(product.inStockQuantity),
        ]);
      }

      // Save Excel file
      final List<int>? bytes = excel.save();
      if (bytes == null) {
        throw Exception('Failed to generate Excel file');
      }

      // Close loading dialog
      Navigator.of(context).pop();

      // Let user choose save location
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Complete Products Database Excel',
        fileName:
            'complete_products_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Complete Database Exported!\n📊 ${allProductsForExport.length} products exported to Excel\n📄 Spreadsheet format for easy data manipulation',
              ),
              backgroundColor: Color(0xFF28A745),
              duration: Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
                onPressed: () async {
                  try {
                    await Process.run('explorer', ['/select,', outputFile]);
                  } catch (e) {
                    print('File saved at: $outputFile');
                  }
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if it's open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Color(0xFFDC3545),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void viewProduct(Product product) async {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProductDetailsPage(
          product: product,
          subCategories: _subCategories,
          vendors: _vendors,
        ),
      ),
    );
  }

  void editProduct(Product product) async {
    // Navigate to edit page
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => EditProductPage(
          product: product,
          onProductUpdated: () {
            // Refresh the products list when product is updated
            _refreshProducts();
          },
        ),
      ),
    );
  }

  void deleteProduct(Product product) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Color(0xFFDC3545)),
              SizedBox(width: 8),
              Text('Delete Product'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${product.title}"?\n\nThis action cannot be undone.',
            style: TextStyle(color: Color(0xFF6C757D)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Color(0xFF6C757D))),
            ),
            ElevatedButton(
              onPressed: () async {
                // Store the page context before popping the dialog
                final pageContext = this.context;
                Navigator.of(context).pop(); // Close dialog first

                // Show loading indicator
                if (mounted) {
                  setState(() => isLoading = true);
                }

                try {
                  await InventoryService.deleteProduct(product.id);

                  // Remove from cache and update UI in real-time
                  if (mounted) {
                    setState(() {
                      _allProductsCache.removeWhere((p) => p.id == product.id);
                    });

                    // Update the provider cache
                    pageContext.read<InventoryProvider>().setProducts(
                      List.from(_allProductsCache),
                    );

                    // Re-apply current filters to update the display
                    _applyFiltersClientSide();

                    // If current page is now empty and we're not on page 1, go to previous page
                    if (_filteredProducts.isEmpty && currentPage > 1) {
                      setState(() {
                        currentPage = currentPage - 1;
                      });
                      _paginateFilteredProducts();
                    }

                    // Show success message using the stored page context
                    if (mounted) {
                      ScaffoldMessenger.of(pageContext).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.check_circle, color: Colors.white),
                              SizedBox(width: 8),
                              Text(
                                'Product "${product.title}" deleted successfully',
                              ),
                            ],
                          ),
                          backgroundColor: Color(0xFF28A745),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                    // Trigger a full refresh from server in background to ensure consistency
                    // (do not await here so the snackbar appears immediately)
                    _refreshProductsAfterAdd();
                  }
                } catch (e) {
                  // Show error message using the stored page context
                  if (mounted) {
                    ScaffoldMessenger.of(pageContext).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.error, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Failed to delete product: ${e.toString()}'),
                          ],
                        ),
                        backgroundColor: Color(0xFFDC3545),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => isLoading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFDC3545),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  void deleteSelectedProducts() {
    final selectedProducts = getSelectedProducts();
    if (selectedProducts.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Color(0xFFDC3545)),
              SizedBox(width: 8),
              Text('Delete Selected Products'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete ${selectedProducts.length} selected product(s)?\n\nThis action cannot be undone.',
            style: TextStyle(color: Color(0xFF6C757D)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Color(0xFF6C757D))),
            ),
            ElevatedButton(
              onPressed: () async {
                // Store the page context before popping the dialog
                final pageContext = this.context;
                Navigator.of(context).pop(); // Close dialog first

                // Show loading indicator
                if (mounted) {
                  setState(() => isLoading = true);
                }

                int successCount = 0;
                int failCount = 0;
                List<String> failedProducts = [];

                try {
                  for (final product in selectedProducts) {
                    try {
                      await InventoryService.deleteProduct(product.id);
                      successCount++;
                    } catch (e) {
                      failCount++;
                      failedProducts.add(product.title);
                      print('Failed to delete product ${product.title}: $e');
                    }
                  }

                  // Remove successfully deleted products from cache
                  if (mounted) {
                    setState(() {
                      for (final product in selectedProducts) {
                        if (!failedProducts.contains(product.title)) {
                          _allProductsCache.removeWhere(
                            (p) => p.id == product.id,
                          );
                        }
                      }
                      selectedProductIds.clear();
                      selectAll = false;
                    });

                    // Update the provider cache
                    pageContext.read<InventoryProvider>().setProducts(
                      List.from(_allProductsCache),
                    );

                    // Re-apply current filters to update the display
                    _applyFiltersClientSide();

                    // If current page is now empty and we're not on page 1, go to previous page
                    if (_filteredProducts.isEmpty && currentPage > 1) {
                      setState(() {
                        currentPage = currentPage - 1;
                      });
                      _paginateFilteredProducts();
                    }

                    // Show success message
                    if (mounted) {
                      String message;
                      if (failCount == 0) {
                        message =
                            '$successCount product(s) deleted successfully';
                      } else {
                        message =
                            '$successCount product(s) deleted successfully, $failCount failed';
                      }

                      ScaffoldMessenger.of(pageContext).showSnackBar(
                        SnackBar(
                          content: Row(
                            children: [
                              Icon(
                                failCount == 0
                                    ? Icons.check_circle
                                    : Icons.warning,
                                color: Colors.white,
                              ),
                              SizedBox(width: 8),
                              Expanded(child: Text(message)),
                            ],
                          ),
                          backgroundColor: failCount == 0
                              ? Color(0xFF28A745)
                              : Color(0xFFFFA726),
                          behavior: SnackBarBehavior.floating,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          duration: const Duration(seconds: 4),
                        ),
                      );
                    }
                  }
                } catch (e) {
                  // Show general error message
                  if (mounted) {
                    ScaffoldMessenger.of(pageContext).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.error, color: Colors.white),
                            SizedBox(width: 8),
                            Text('Failed to delete products: ${e.toString()}'),
                          ],
                        ),
                        backgroundColor: Color(0xFFDC3545),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        duration: const Duration(seconds: 4),
                      ),
                    );
                  }
                } finally {
                  if (mounted) {
                    setState(() => isLoading = false);
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFDC3545),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Delete All'),
            ),
          ],
        );
      },
    );
  }

  void toggleSelectAll(bool? value) {
    // If there are no products at all, nothing to do
    if (_allProductsCache.isEmpty &&
        _allFilteredProducts.isEmpty &&
        _filteredProducts.isEmpty)
      return;

    if (!mounted) return;
    setState(() {
      if (value == true) {
        // Prefer selecting from the full filtered set (across pages) if available,
        // otherwise fall back to the full products cache, and finally the current page.
        final source = _allFilteredProducts.isNotEmpty
            ? _allFilteredProducts
            : (_allProductsCache.isNotEmpty
                  ? _allProductsCache
                  : _filteredProducts);

        selectedProductIds = source.map((product) => product.id).toSet();
        selectAll = true;
      } else {
        selectedProductIds.clear();
        selectAll = false;
      }
    });
  }

  void toggleProductSelection(int productId, bool? value) {
    if (!mounted) return;
    setState(() {
      if (value == true) {
        selectedProductIds.add(productId);
      } else {
        selectedProductIds.remove(productId);
      }

      // Update selectAll based on current filtered products
      selectAll =
          _filteredProducts.isNotEmpty &&
          selectedProductIds.length == _filteredProducts.length &&
          _filteredProducts.every(
            (product) => selectedProductIds.contains(product.id),
          );
    });
  }

  List<Product> getSelectedProducts() {
    return _allProductsCache
        .where((product) => selectedProductIds.contains(product.id))
        .toList();
  }

  String _generateProductQRData(Product product) {
    final qrData = {
      'product_id': product.id,
      'title': product.title,
      'design_code': product.designCode,
      'barcode': getNumericBarcode(product),
      'sale_price': product.salePrice,
      'buying_price': product.buyingPrice ?? 0,
      'opening_stock_quantity': product.openingStockQuantity,
      'in_stock_quantity': product.inStockQuantity,
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

  Future<void> _showPrintDialogForProduct(Product product) async {
    int dialogQuantity = 1;
    final TextEditingController quantityController = TextEditingController(
      text: '1',
    );

    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: Row(
                children: [
                  Icon(Icons.print, color: const Color(0xFF0D1845), size: 24),
                  const SizedBox(width: 12),
                  const Text(
                    'Print Labels',
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFDEE2E6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.inventory,
                            color: Color(0xFF6C757D),
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              product.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF343A40),
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Quantity (1-1000):',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF343A40),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      keyboardType: TextInputType.number,
                      controller: quantityController,
                      style: const TextStyle(color: Color(0xFF343A40)),
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Color(0xFFDEE2E6),
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Color(0xFFDEE2E6),
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(6),
                          borderSide: const BorderSide(
                            color: Color(0xFF0D1845),
                          ),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        hintText: 'Enter quantity',
                        hintStyle: const TextStyle(color: Color(0xFF6C757D)),
                        contentPadding: const EdgeInsets.symmetric(
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
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: const Color(0xFFBBDEFB)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.info_outline,
                            color: Color(0xFF1976D2),
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Total labels to print: ${dialogQuantity}',
                              style: const TextStyle(
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
                    foregroundColor: const Color(0xFF6C757D),
                  ),
                  child: const Text('Cancel', style: TextStyle(fontSize: 14)),
                ),
                ElevatedButton(
                  onPressed: () async {
                    final qty = dialogQuantity;
                    quantityController.dispose();
                    Navigator.of(context).pop();
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Generating barcode stickers...'),
                      ),
                    );
                    try {
                      // Use the same logic as print_barcode_page.dart
                      final pdf = pw.Document();

                      // Barcode sticker size: 2x1 inches (50.8mm x 25.4mm)
                      const double stickerWidthMM = 50.8;
                      const double stickerHeightMM = 25.4;

                      // Convert mm to points (1 mm = 2.83465 points)
                      const double mmToPoints = 2.83465;
                      final double stickerWidth = stickerWidthMM * mmToPoints;
                      final double stickerHeight = stickerHeightMM * mmToPoints;

                      // Create custom page format for sticker
                      final pageFormat = pdf_pkg.PdfPageFormat(
                        stickerWidth,
                        stickerHeight,
                      );

                      // Generate one sticker per page for each copy
                      for (int i = 0; i < qty; i++) {
                        pdf.addPage(
                          pw.Page(
                            pageFormat: pageFormat,
                            margin: pw.EdgeInsets.zero,
                            build: (pw.Context context) {
                              return pw.Container(
                                width: stickerWidth,
                                height: stickerHeight,
                                child: pw.Column(
                                  mainAxisAlignment:
                                      pw.MainAxisAlignment.center,
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

                      // Save PDF to file and use sharePdf like print_barcode_page
                      final bytes = await pdf.save();
                      await Printing.sharePdf(
                        bytes: bytes,
                        filename: 'barcode_stickers.pdf',
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '$qty barcode sticker(s) generated successfully!',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text('Print failed: $e'),
                            backgroundColor: Colors.red,
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
                    'Print Barcode',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () async {
                    final qty = dialogQuantity;
                    quantityController.dispose();
                    Navigator.of(context).pop();
                    if (!mounted) return;
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(
                        content: Text('Generating QR code stickers...'),
                      ),
                    );
                    try {
                      // Use the same logic as print_barcode_page.dart
                      final pdf = pw.Document();

                      // QR code sticker size: 2cm x 2cm
                      const double stickerWidthCM = 2.0;
                      const double stickerHeightCM = 2.0;

                      // Convert cm to points (1 cm = 28.3465 points)
                      const double cmToPoints = 28.3465;
                      final double stickerWidth = stickerWidthCM * cmToPoints;
                      final double stickerHeight = stickerHeightCM * cmToPoints;

                      // Create custom page format for sticker
                      final pageFormat = pdf_pkg.PdfPageFormat(
                        stickerWidth,
                        stickerHeight,
                      );

                      // Generate one sticker per page for each copy
                      for (int i = 0; i < qty; i++) {
                        pdf.addPage(
                          pw.Page(
                            pageFormat: pageFormat,
                            margin: pw.EdgeInsets.zero,
                            build: (pw.Context ctx) {
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

                      // Save PDF to file and use sharePdf like print_barcode_page
                      final bytes = await pdf.save();
                      await Printing.sharePdf(
                        bytes: bytes,
                        filename: 'qr_stickers.pdf',
                      );

                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '$qty QR code sticker(s) generated successfully!',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(this.context).showSnackBar(
                          SnackBar(
                            content: Text('Print failed: $e'),
                            backgroundColor: Colors.red,
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
                  child: const Text('Print QR', style: TextStyle(fontSize: 14)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Products',
            onPressed: () async {
              setState(() => isLoading = true);
              await _refreshProducts();
              setState(() => isLoading = false);
            },
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
              margin: const EdgeInsets.fromLTRB(24, 12, 24, 12),
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
                          Icons.inventory,
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
                              'Products',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Manage your product inventory and details',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
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
                        Icons.inventory_2,
                        Colors.blue,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Selected Products Summary Card
            if (selectedProductIds.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(24, 12, 24, 0),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF1976D2).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFF1976D2),
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${getSelectedProducts().length} product(s) selected',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF1976D2),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'You can perform actions on the selected products',
                            style: TextStyle(
                              color: const Color(0xFF1976D2).withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: deleteSelectedProducts,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: Colors.red.withOpacity(0.3),
                          ),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.delete, color: Colors.red, size: 12),
                            SizedBox(width: 4),
                            Text(
                              'Delete Selected',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: () {
                        setState(() {
                          selectedProductIds.clear();
                          selectAll = false;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFF1976D2).withOpacity(0.3),
                          ),
                        ),
                        child: const Text(
                          'Clear Selection',
                          style: TextStyle(
                            color: Color(0xFF1976D2),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

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
                      padding: const EdgeInsets.all(8),
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
                                child: InkWell(
                                  onTap: _showVendorSelectionDialog,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        selectedVendor == null ||
                                                selectedVendor == 'All'
                                            ? 'Vendor'
                                            : selectedVendor!,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color:
                                              selectedVendor == null ||
                                                  selectedVendor == 'All'
                                              ? Colors.grey
                                              : Colors.black87,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      Icon(
                                        Icons.arrow_drop_down,
                                        size: 16,
                                        color: Colors.grey,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 32,
                                child: ElevatedButton.icon(
                                  onPressed: exportToPDF,
                                  icon: const Icon(
                                    Icons.picture_as_pdf,
                                    size: 14,
                                  ),
                                  label: const Text(
                                    'PDF',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
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
                              const SizedBox(width: 6),
                              SizedBox(
                                height: 32,
                                child: ElevatedButton.icon(
                                  onPressed: exportToExcel,
                                  icon: const Icon(Icons.table_chart, size: 14),
                                  label: const Text(
                                    'Excel',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
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
                          if (_isFilterActive) ...[
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D1845).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.filter_list,
                                    size: 12,
                                    color: Color(0xFF0D1845),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Filters applied',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF0D1845),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _searchController.clear();
                                        selectedVendor = null;
                                        _isFilterActive = false;
                                      });
                                      _applyFilters();
                                    },
                                    child: const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Color(0xFF0D1845),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          // Selection Controls
                          Row(
                            children: [
                              Checkbox(
                                value: selectAll,
                                onChanged: _filteredProducts.isEmpty
                                    ? null
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
                                        color: _filteredProducts.isEmpty
                                            ? Colors.grey
                                            : const Color(0xFF343A40),
                                      ),
                                    ),
                                    if (_filteredProducts.isEmpty)
                                      Text(
                                        'No products to select',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.grey,
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
                                  color: selectedProductIds.isNotEmpty
                                      ? const Color(0xFFE3F2FD)
                                      : const Color(0xFFF8F9FA),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      selectedProductIds.isNotEmpty
                                          ? Icons.check_circle
                                          : Icons.info_outline,
                                      color: selectedProductIds.isNotEmpty
                                          ? const Color(0xFF1976D2)
                                          : const Color(0xFF6C757D),
                                      size: 10,
                                    ),
                                    const SizedBox(width: 3),
                                    Text(
                                      '${getSelectedProducts().length} product(s) selected',
                                      style: TextStyle(
                                        color: selectedProductIds.isNotEmpty
                                            ? const Color(0xFF1976D2)
                                            : const Color(0xFF6C757D),
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
                        vertical: 6,
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
                          // Product Details Column
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Product Details',
                              style: _headerStyle(),
                            ),
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
                              child: Text('Price', style: _headerStyle()),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Stock Column - Centered
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: Text('Stock', style: _headerStyle()),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Actions Column - Fixed width to match body
                          SizedBox(
                            width: 100,
                            child: Text('Actions', style: _headerStyle()),
                          ),
                        ],
                      ),
                    ),

                    // Table Body
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : errorMessage != null
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
                                        setState(() {
                                          _searchController.clear();
                                          selectedVendor = null;
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
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 0,
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
                                          value: selectedProductIds.contains(
                                            product.id,
                                          ),
                                          onChanged: (value) =>
                                              toggleProductSelection(
                                                product.id,
                                                value,
                                              ),
                                          activeColor: const Color(0xFF0D1845),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Product Details Column
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF0D1845),
                                                fontSize: 10,
                                              ),
                                            ),
                                            Text(
                                              'Code: ${product.designCode}',
                                              style: TextStyle(
                                                fontSize: 8,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            Text(
                                              'Barcode: ${getNumericBarcode(product)}',
                                              style: TextStyle(
                                                fontSize: 8,
                                                color: Colors.grey.shade600,
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
                                          product.vendor.name ?? 'N/A',
                                          style: const TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF495057),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Price Column - Centered
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Text(
                                            'Rs. ${product.salePrice}',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF495057),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Stock Column - Centered
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Text(
                                            product.inStockQuantity,
                                            style: const TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF495057),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Actions Column
                                      SizedBox(
                                        width: 100,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.visibility,
                                                color: const Color(0xFF0D1845),
                                                size: 14,
                                              ),
                                              onPressed: () =>
                                                  viewProduct(product),
                                              tooltip: 'View Details',
                                              padding: const EdgeInsets.only(
                                                right: 4,
                                              ),
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                            const SizedBox(width: 2),
                                            IconButton(
                                              icon: Icon(
                                                Icons.edit,
                                                color: Colors.blue,
                                                size: 14,
                                              ),
                                              onPressed: () =>
                                                  editProduct(product),
                                              tooltip: 'Edit',
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                            const SizedBox(width: 2),
                                            IconButton(
                                              icon: Icon(
                                                Icons.print,
                                                color: Colors.grey[800],
                                                size: 14,
                                              ),
                                              onPressed: () =>
                                                  _showPrintDialogForProduct(
                                                    product,
                                                  ),
                                              tooltip: 'Print',
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                            const SizedBox(width: 2),
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                                size: 14,
                                              ),
                                              onPressed: () =>
                                                  deleteProduct(product),
                                              tooltip: 'Delete',
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 4,
                                                  ),
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          ],
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

            // Pagination Controls
            if (_allFilteredProducts.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
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
                          currentPage <
                              (_allFilteredProducts.length / itemsPerPage)
                                  .ceil()
                          ? () => _changePage(currentPage + 1)
                          : null,
                      icon: Icon(Icons.chevron_right, size: 14),
                      label: Text('Next', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor:
                            currentPage <
                                (_allFilteredProducts.length / itemsPerPage)
                                    .ceil()
                            ? const Color(0xFF0D1845)
                            : Colors.grey.shade300,
                        foregroundColor:
                            currentPage <
                                (_allFilteredProducts.length / itemsPerPage)
                                    .ceil()
                            ? Colors.white
                            : Colors.grey.shade600,
                        elevation:
                            currentPage <
                                (_allFilteredProducts.length / itemsPerPage)
                                    .ceil()
                            ? 2
                            : 0,
                        side:
                            currentPage <
                                (_allFilteredProducts.length / itemsPerPage)
                                    .ceil()
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
                    const SizedBox(width: 16),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Page $currentPage of ${(_allFilteredProducts.length / itemsPerPage).ceil()} (${_allFilteredProducts.length} total)',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFF6C757D),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showVendorSelectionDialog() {
    final TextEditingController searchController = TextEditingController();
    List<String> filteredVendors = _getUniqueVendors();
    String? tempSelectedVendor = selectedVendor;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void updateFilteredVendors(String query) {
              if (!mounted) return; // Safety check
              setState(() {
                if (query.isEmpty) {
                  filteredVendors = _getUniqueVendors();
                } else {
                  filteredVendors = _getUniqueVendors()
                      .where(
                        (vendor) =>
                            vendor.toLowerCase().contains(query.toLowerCase()),
                      )
                      .toList();
                }
              });
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              surfaceTintColor: Colors.white,
              title: Row(
                children: [
                  Icon(
                    Icons.business,
                    color: const Color(0xFF0D1845),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Select Vendor',
                    style: TextStyle(
                      color: Color(0xFF0D1845),
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              content: Container(
                width: 400,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                  minHeight: 300,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Search field
                    TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search vendors...',
                        prefixIcon: const Icon(Icons.search),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.grey[50],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onChanged: updateFilteredVendors,
                    ),
                    const SizedBox(height: 16),
                    // Vendors list
                    Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: filteredVendors.length,
                        itemBuilder: (context, index) {
                          final vendor = filteredVendors[index];
                          final isSelected = tempSelectedVendor == vendor;

                          return ListTile(
                            title: Text(
                              vendor,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected
                                    ? const Color(0xFF0D1845)
                                    : Colors.black87,
                              ),
                            ),
                            leading: Radio<String>(
                              value: vendor,
                              groupValue: tempSelectedVendor,
                              onChanged: (value) {
                                if (!mounted) return; // Safety check
                                setState(() {
                                  tempSelectedVendor = value;
                                });
                              },
                              activeColor: const Color(0xFF0D1845),
                            ),
                            onTap: () {
                              if (!mounted) return; // Safety check
                              setState(() {
                                tempSelectedVendor = vendor;
                              });
                            },
                            tileColor: isSelected
                                ? const Color(0xFF0D1845).withOpacity(0.1)
                                : null,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6C757D),
                  ),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(tempSelectedVendor);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D1845),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Apply'),
                ),
              ],
            );
          },
        );
      },
    ).then((result) {
      // Dispose controller after dialog is closed
      searchController.dispose();

      // Apply the selection if changed
      if (result != null && result != selectedVendor) {
        if (mounted) {
          setState(() {
            selectedVendor = result;
          });
          _applyFilters();
        }
      }
    });
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
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
