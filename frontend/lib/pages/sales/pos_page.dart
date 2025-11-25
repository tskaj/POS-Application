import 'package:flutter/material.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../providers/providers.dart';
import '../../utils/barcode_utils.dart';
import '../../widgets/pos_navbar.dart';
import '../../widgets/pos_order_list.dart';
import '../../widgets/pos_payment_methods.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../models/sub_category.dart';
import '../../services/inventory_service.dart';
import '../../services/sales_service.dart';
import '../../services/services.dart';
import 'barcode_scanner_page.dart';
import 'hardware_barcode_scanner_page.dart';

class PosPage extends StatefulWidget {
  final Invoice? invoiceToEdit;
  final bool openCustomTab;
  final VoidCallback? onBackToDashboard;
  final Function(String)? onNavigateToContent;

  const PosPage({
    super.key,
    this.invoiceToEdit,
    this.openCustomTab = false,
    this.onBackToDashboard,
    this.onNavigateToContent,
  });

  @override
  State<PosPage> createState() => _PosPageState();
}

class _PosPageState extends State<PosPage>
    with AutomaticKeepAliveClientMixin, RouteAware {
  String selectedCategoryId = 'all'; // Selected category from bottom section
  String selectedSubCategoryId =
      'all'; // Selected subcategory from left sidebar
  String searchQuery = '';
  List<Map<String, Object>> orderItems = [];
  Map<String, dynamic>? selectedCustomer;
  Map<String, dynamic>? selectedSalesman;
  double currentTotal = 0.0;
  double currentTax = 0.0;
  double currentDiscount = 0.0;
  double currentRoundOff = 0.0;
  double currentAdvance = 0.0;
  String? currentDueDate;
  String orderDescription = '';
  bool _isCustomTabActive = false;

  // Data from inventory pages
  List<Category> categories = [];
  List<SubCategory> subCategories = [];
  List<Product> products = [];
  List<Map<String, dynamic>> salesmen = [];
  bool isLoadingCategories = false;
  bool isLoadingSubCategories = false;
  bool isLoadingProducts = false;
  bool isLoadingSalesmen = false;

  // Performance optimizations - optimized for better performance
  List<Product> _filteredProducts = [];
  Timer? _searchDebounceTimer;

  // Pagination for products - reduced for better performance
  static const int _productsPerPage = 15; // Reduced for better performance
  int _currentPage = 0;
  bool _isLoadingMore = false;
  bool _hasMoreProducts = true;
  final ScrollController _productsScrollController = ScrollController();

  // Sequential loading states
  bool _isInitializing = true;
  String _loadingMessage = 'Loading products...';

  // View mode: 'grid' or 'table'
  String _viewMode = 'grid';
  // Highlight state for recently added product
  int? _lastAddedProductId;
  Timer? _highlightTimer;

  // Automatic barcode scanning state
  String _barcodeBuffer = '';
  Timer? _barcodeTimer;
  // Persistent focus node so RawKeyboardListener can receive input from hardware scanners
  final FocusNode _keyboardFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _isCustomTabActive = widget.openCustomTab;
    // Listen to focus changes so we can show a small UI indicator
    _keyboardFocusNode.addListener(() {
      if (mounted) setState(() {});
    });
    // Start the sequential initialization after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _initializeDataSequentially();
      // Request focus so RawKeyboardListener receives keyboard / scanner events
      try {
        _keyboardFocusNode.requestFocus();
      } catch (_) {}
    });

    // Attach scroll listener for lazy loading
    _productsScrollController.addListener(_onProductsScroll);
  }

  @override
  void didPushNext() {
    // Called when a new route is pushed on top of this one. Persist current
    // products to global provider so other pages see decremented stock.
    super.didPushNext();
    try {
      final inventoryProvider = Provider.of<InventoryProvider>(
        context,
        listen: false,
      );
      inventoryProvider.setProducts(products);
    } catch (_) {}
  }

  @override
  void didPop() {
    // When this route is popped ensure latest product state is written back
    // to the shared InventoryProvider.
    super.didPop();
    try {
      final inventoryProvider = Provider.of<InventoryProvider>(
        context,
        listen: false,
      );
      inventoryProvider.setProducts(products);
    } catch (_) {}
  }

  RouteObserver<PageRoute<dynamic>>? _routeObserver;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute) {
      final app = context.findAncestorWidgetOfExactType<MaterialApp>();
      if (app != null) {
        final observers = app.navigatorObservers ?? <NavigatorObserver>[];
        for (final obs in observers) {
          if (obs is RouteObserver<PageRoute<dynamic>>) {
            _routeObserver = obs;
            break;
          }
        }
        _routeObserver?.subscribe(this, modalRoute);
      }
    }
  }

  @override
  void didUpdateWidget(PosPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset state when switching from editing mode to normal POS mode
    if (oldWidget.invoiceToEdit != null && widget.invoiceToEdit == null) {
      setState(() {
        orderItems = [];
        selectedCustomer = null;
        selectedSalesman = null;
        currentTotal = 0.0;
        currentTax = 0.0;
        currentDiscount = 0.0;
        currentRoundOff = 0.0;
        orderDescription = '';
        _isInitializing = true;
      });
      // Reinitialize data for fresh POS session
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _initializeDataSequentially();
      });
      // Ensure keyboard focus returns when the page is shown again
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _keyboardFocusNode.requestFocus();
        } catch (_) {}
      });
    }
    // Load invoice data when switching to editing mode
    else if (oldWidget.invoiceToEdit == null && widget.invoiceToEdit != null) {
      setState(() {
        _isInitializing = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadInvoiceForEditing(widget.invoiceToEdit!);
        setState(() {
          _isInitializing = false;
        });
        // Ensure scanner RawKeyboardListener has focus when entering edit mode
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _keyboardFocusNode.requestFocus();
          } catch (_) {}
        });
      });
    }
  }

  Future<void> _initializeDataSequentially() async {
    try {
      // Reset order state if not editing an invoice
      if (widget.invoiceToEdit == null) {
        setState(() {
          orderItems = [];
          selectedCustomer = null;
          selectedSalesman = null;
          currentTotal = 0.0;
          currentTax = 0.0;
          currentDiscount = 0.0;
          currentRoundOff = 0.0;
          orderDescription = '';
        });
      }

      // Step 1: Load products first (most important for POS)
      setState(() {
        _loadingMessage = 'Loading products...';
      });
      await _fetchProducts();

      // Step 2: Load categories
      setState(() {
        _loadingMessage = 'Loading categories...';
      });
      await _fetchCategories();

      // Step 3: Load subcategories
      setState(() {
        _loadingMessage = 'Loading subcategories...';
      });
      await _fetchSubCategories();

      print('✅ POS: Initialization complete');
      print('📊 POS: Loaded ${categories.length} categories');
      print('📊 POS: Loaded ${subCategories.length} subcategories');

      // Step 4: Load salesmen
      setState(() {
        _loadingMessage = 'Loading salesmen...';
      });
      await _fetchSalesmen();

      // Step 5: Load invoice data if editing
      if (widget.invoiceToEdit != null) {
        setState(() {
          _loadingMessage = 'Loading invoice data...';
        });
        await _loadInvoiceForEditing(widget.invoiceToEdit!);
      }

      // Mark initialization complete
      setState(() {
        _isInitializing = false;
      });
    } catch (e) {
      print('Error during sequential initialization: $e');
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _loadInvoiceForEditing(Invoice invoice) async {
    try {
      // If this POS was opened specifically to edit a bridals/custom order,
      // fetch the bridals detail endpoint which preserves extras and bridals fields.
      if (widget.openCustomTab) {
        final resp = await ApiService.get(
          '${SalesService.invoicesEndpoint}/pos-bridals/${invoice.invId}',
        );
        if (resp.containsKey('data')) {
          final data = resp['data'] as Map<String, dynamic>;

          // Parse raw details so we keep extras and bridals-specific fields
          final detailsRaw = (data['details'] as List<dynamic>?) ?? [];
          final items = detailsRaw.map<Map<String, Object>>((detail) {
            final productIdRaw = detail['product_id']?.toString() ?? '';
            final id = int.tryParse(productIdRaw) ?? 0;
            final price =
                double.tryParse(detail['price']?.toString() ?? '') ?? 0.0;
            final qty = int.tryParse(detail['quantity']?.toString() ?? '') ?? 1;
            final extras = detail['extras'];
            return {
              'id': id,
              'product_id_raw': productIdRaw,
              'name': detail['product_name']?.toString() ?? '',
              'price': price,
              'quantity': qty,
              'image': detail['image']?.toString() ?? '',
              'design_code': detail['design_code']?.toString() ?? '',
              if (extras != null) 'extras': extras,
              'isCustom': true,
            };
          }).toList();

          // Customer
          Map<String, dynamic>? customer;
          if (data.containsKey('customer') && data['customer'] is Map) {
            final c = data['customer'] as Map<String, dynamic>;
            customer = {'id': c['id'], 'name': c['name']};
          } else if ((data['customer_name'] ?? '').toString().isNotEmpty) {
            customer = {'name': data['customer_name']?.toString() ?? ''};
          }

          // Salesman
          Map<String, dynamic>? invoiceSalesman;
          final invoiceSalesmanName = (data['employee'] is Map)
              ? (data['employee']['name']?.toString() ?? '')
              : (data['salesman_name']?.toString() ?? '');
          if (invoiceSalesmanName.isNotEmpty) {
            for (final s in salesmen) {
              final sName = (s['name'] ?? '').toString().trim();
              if (sName.toLowerCase() == invoiceSalesmanName.toLowerCase()) {
                invoiceSalesman = s;
                break;
              }
            }
            invoiceSalesman ??= {'id': null, 'name': invoiceSalesmanName};
          }

          setState(() {
            orderItems = items;
            selectedCustomer = customer;
            selectedSalesman = invoiceSalesman;
            currentAdvance =
                double.tryParse(data['paid']?.toString() ?? '') ?? 0.0;
            currentDueDate = data['due_date']?.toString();
            orderDescription = data['description']?.toString() ?? '';
          });
          // After state is updated, ensure the keyboard focus node is active
          WidgetsBinding.instance.addPostFrameCallback((_) {
            try {
              _keyboardFocusNode.requestFocus();
            } catch (_) {}
          });
        } else {
          throw Exception('Bridal data not found in response');
        }
      } else {
        // Regular invoice path
        final invoiceDetail = await SalesService.getInvoiceById(invoice.invId);

        // Convert invoice details to order items
        final orderItemsFromInvoice = invoiceDetail.details.map((detail) {
          return <String, Object>{
            'id': int.tryParse(detail.productId) ?? 0,
            'name': detail.productName,
            'price': double.tryParse(detail.price) ?? 0.0,
            'quantity': int.tryParse(detail.quantity) ?? 1,
            'image': '', // No image in invoice details
            'design_code': '', // No design code in invoice details
          };
        }).toList();

        // Set customer if available
        Map<String, dynamic>? customer;
        if (invoice.isCreditCustomer && invoice.customerName.isNotEmpty) {
          customer = {'name': invoice.customerName};
        }

        // Try to find the salesman record we loaded earlier (match by name)
        Map<String, dynamic>? invoiceSalesman;
        final invoiceSalesmanName = (invoice.salesmanName ?? '')
            .toString()
            .trim();
        if (invoiceSalesmanName.isNotEmpty) {
          for (final s in salesmen) {
            final sName = (s['name'] ?? '').toString().trim();
            if (sName.toLowerCase() == invoiceSalesmanName.toLowerCase()) {
              invoiceSalesman = s;
              break;
            }
          }
          // Fallback: if we couldn't find a matching salesman in the list,
          // still set the selectedSalesman to show the name from the invoice.
          invoiceSalesman ??= {'id': null, 'name': invoiceSalesmanName};
        }

        setState(() {
          orderItems = orderItemsFromInvoice;
          selectedCustomer = customer;
          selectedSalesman = invoiceSalesman;
        });
        // After loading regular invoice details, request keyboard focus so
        // the scanner stays ready in edit mode.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          try {
            _keyboardFocusNode.requestFocus();
          } catch (_) {}
        });
      }
    } catch (e) {
      print('Error loading invoice for editing: $e');
      // Show error but continue with empty order
    }
  }

  Future<void> _fetchCategories() async {
    setState(() {
      isLoadingCategories = true;
    });

    try {
      final response = await InventoryService.getCategories(limit: 1000);
      setState(() {
        categories = response.data;
        isLoadingCategories = false;
      });
      // Update provider cache
      final inventoryProvider = Provider.of<InventoryProvider>(
        context,
        listen: false,
      );
      inventoryProvider.setCategories(categories);
    } catch (e) {
      setState(() {
        isLoadingCategories = false;
      });
      print('Error fetching categories: $e');
    }
  }

  Future<void> _fetchSubCategories() async {
    setState(() {
      isLoadingSubCategories = true;
    });

    try {
      final response = await InventoryService.getSubCategories(limit: 1000);
      setState(() {
        subCategories = response.data;
        isLoadingSubCategories = false;
      });
      // Update provider cache
      final inventoryProvider = Provider.of<InventoryProvider>(
        context,
        listen: false,
      );
      inventoryProvider.setSubCategories(subCategories);
    } catch (e) {
      setState(() {
        isLoadingSubCategories = false;
      });
      print('Error fetching subcategories: $e');
    }
  }

  Future<void> _fetchSalesmen() async {
    setState(() {
      isLoadingSalesmen = true;
    });

    try {
      // Fetch employees with attendance data from the API
      final response = await ApiService.get('/attendances/all');

      if (response['success'] == true || response['status'] == true) {
        final employees = response['data'] as List<dynamic>;

        // Filter only salesmen (role = 'Salesman')
        final salesmenList = employees
            .where((emp) {
              final role = emp['role']?.toString().toLowerCase() ?? '';
              return role == 'salesman';
            })
            .map((emp) {
              return {
                'id': emp['id'],
                'name': emp['employee_name'] ?? '',
                'email': emp['email'] ?? '',
              };
            })
            .toList();

        setState(() {
          salesmen = salesmenList;
          isLoadingSalesmen = false;
        });

        print('✅ Loaded ${salesmen.length} salesmen');
      }
    } catch (e) {
      setState(() {
        isLoadingSalesmen = false;
      });
      print('Error fetching salesmen: $e');
    }
  }

  Future<void> _fetchProducts({bool loadMore = false}) async {
    // Always fetch fresh products from API when POS page opens (don't use cache)
    // This ensures we have the latest product data when starting a POS session
    final inventoryProvider = Provider.of<InventoryProvider>(
      context,
      listen: false,
    );

    if (loadMore && (_isLoadingMore || !_hasMoreProducts)) return;

    setState(() {
      if (loadMore) {
        _isLoadingMore = true;
      } else {
        isLoadingProducts = true;
        _currentPage = 0;
        _hasMoreProducts = true;
      }
    });

    try {
      final page = loadMore ? _currentPage + 1 : 1;
      final response = await InventoryService.getProducts(
        limit: _productsPerPage,
        page: page,
      );

      setState(() {
        if (loadMore) {
          products.addAll(response.data);
          _currentPage = page;
          _hasMoreProducts = response.data.length == _productsPerPage;
          _isLoadingMore = false;
        } else {
          products = response.data;
          _currentPage = 1;
          _hasMoreProducts = response.data.length == _productsPerPage;
          _updateFilteredProducts();
          isLoadingProducts = false;
        }
      });

      // Update provider cache with all products (only on initial load)
      if (!loadMore) {
        inventoryProvider.setProducts(products);
      }
    } catch (e) {
      setState(() {
        if (loadMore) {
          _isLoadingMore = false;
        } else {
          isLoadingProducts = false;
        }
      });
      print('Error fetching products: $e');
    }
  }

  void _onProductsScroll() {
    if (_productsScrollController.position.pixels >=
        _productsScrollController.position.maxScrollExtent - 200) {
      _fetchProducts(loadMore: true);
    }
  }

  void onCategorySelected(String category) {
    setState(() {
      selectedCategoryId = category;
      selectedSubCategoryId =
          'all'; // Reset subcategory selection when category changes
    });

    _resetAndFilterProducts();
  }

  void onSubCategorySelected(String subCategory) {
    setState(() {
      selectedSubCategoryId = subCategory;
    });
    _resetAndFilterProducts();
  }

  void _resetAndFilterProducts() {
    // Reset pagination when filters change
    _currentPage = 0;
    _hasMoreProducts = true;
    // Clear products and fetch fresh data with new filters
    _fetchProducts(loadMore: false);
  }

  void _updateFilteredProducts() {
    setState(() {
      _filteredProducts = _getFilteredProducts();
    });
  }

  void onSearchChanged(String query) {
    setState(() {
      searchQuery = query;
    });

    // Debounce search to avoid excessive filtering - optimized delay for better performance
    _searchDebounceTimer?.cancel();
    _searchDebounceTimer = Timer(const Duration(milliseconds: 200), () {
      // Reduced from 300ms for better responsiveness
      _updateFilteredProducts();
    });
  }

  void addToOrder(Map<String, dynamic> product) {
    // Enforce stock limits when adding products
    final int productId = product['id'] is int
        ? product['id'] as int
        : int.tryParse(product['id']?.toString() ?? '') ?? 0;

    // Lookup product from loaded products to get accurate stock
    Product? sourceProduct;
    for (final p in products) {
      if (p.id == productId) {
        sourceProduct = p;
        break;
      }
    }

    // Determine available stock (prefer inStockQuantity then openingStockQuantity)
    final int availableStock = sourceProduct != null
        ? (int.tryParse(sourceProduct.inStockQuantity) ??
              int.tryParse(sourceProduct.openingStockQuantity) ??
              0)
        : 0;

    setState(() {
      // Convert price to double to avoid type errors
      final price =
          double.tryParse(product['price']?.toString() ?? '0.0') ?? 0.0;

      final existingIndex = orderItems.indexWhere(
        (item) => item['id'] == productId,
      );

      // If item already in cart, ensure we don't exceed stock when incrementing
      if (existingIndex >= 0) {
        final currentQty =
            ((orderItems[existingIndex]['quantity'] as int?) ?? 1);
        if (availableStock > 0 && currentQty + 1 > availableStock) {
          // Notify user that they've reached stock limit
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Cannot add more than $availableStock for "${orderItems[existingIndex]['name']}" (available stock).',
                ),
                backgroundColor: Colors.orange[800],
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }

        orderItems[existingIndex]['quantity'] = currentQty + 1;
      } else {
        // New item: check stock before adding
        if (availableStock <= 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Product is out of stock.'),
                backgroundColor: Colors.red[700],
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }

        // Create a properly typed order product map
        final orderProduct = <String, Object>{
          'id': productId,
          'name': product['name'] as String,
          'price': price,
          'quantity': 1,
          'image': product['image'] as String? ?? '',
          'design_code': product['design_code'] as String? ?? '',
        };

        orderItems.add(orderProduct);
      }

      // Highlight the recently added product briefly
      try {
        final addedId = productId;
        _highlightTimer?.cancel();
        _lastAddedProductId = addedId;
        _highlightTimer = Timer(const Duration(milliseconds: 800), () {
          if (mounted) {
            setState(() {
              _lastAddedProductId = null;
            });
          }
        });
      } catch (_) {
        // ignore if id parsing fails
      }
    });
  }

  void updateOrderItemQuantity(String itemId, int quantity) {
    final itemIdInt = int.tryParse(itemId) ?? 0;

    // Find product stock
    Product? sourceProduct;
    for (final p in products) {
      if (p.id == itemIdInt) {
        sourceProduct = p;
        break;
      }
    }

    final int availableStock = sourceProduct != null
        ? (int.tryParse(sourceProduct.inStockQuantity) ??
              int.tryParse(sourceProduct.openingStockQuantity) ??
              0)
        : 0;

    setState(() {
      final index = orderItems.indexWhere((item) => item['id'] == itemIdInt);
      if (index >= 0) {
        if (quantity <= 0) {
          orderItems.removeAt(index);
          return;
        }

        if (availableStock > 0 && quantity > availableStock) {
          // Cap to available stock and notify user
          orderItems[index]['quantity'] = availableStock;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Only $availableStock available in stock. Quantity set to available stock.',
                ),
                backgroundColor: Colors.orange[800],
                duration: const Duration(seconds: 2),
              ),
            );
          }
        } else {
          orderItems[index]['quantity'] = quantity;
        }
      }
    });
  }

  void removeOrderItem(String itemId) {
    setState(() {
      final itemIdInt = int.tryParse(itemId) ?? 0;
      orderItems.removeWhere((item) => item['id'] == itemIdInt);
    });
  }

  void selectCustomer(String customerName) {
    setState(() {
      selectedCustomer = {'name': customerName};
    });
  }

  Future<void> _scanBarcode() async {
    final scanType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Choose Scanner Type'),
        content: const Text('Select how you want to scan the barcode:'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop('camera'),
            child: const Text('Camera Scan'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('hardware'),
            child: const Text('Hardware Scanner'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('manual'),
            child: const Text('Manual Input'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );

    if (scanType == null) return;

    Product? scannedProduct;

    if (scanType == 'camera') {
      // Camera-based scanning
      scannedProduct = await Navigator.push<Product>(
        context,
        MaterialPageRoute(builder: (context) => const BarcodeScannerPage()),
      );
    } else if (scanType == 'hardware') {
      // Hardware scanner
      scannedProduct = await Navigator.push<Product>(
        context,
        MaterialPageRoute(builder: (context) => const HardwareBarcodeScanner()),
      );
    } else if (scanType == 'manual') {
      // Manual barcode input
      final TextEditingController barcodeController = TextEditingController();
      final barcode = await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Enter Barcode'),
          content: TextField(
            controller: barcodeController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter barcode or design code',
              border: OutlineInputBorder(),
            ),
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () =>
                  Navigator.of(context).pop(barcodeController.text),
              child: const Text('Search'),
            ),
          ],
        ),
      );
      barcodeController.dispose();

      if (barcode != null && barcode.isNotEmpty) {
        // Normalize input and search for product by barcode/design code (case-insensitive)
        final lookup = barcode.trim();
        final lookupLower = lookup.toLowerCase();
        try {
          scannedProduct = products.firstWhere((product) {
            final pDesign = product.designCode.trim().toLowerCase();
            final pBarcode = product.barcode.trim().toLowerCase();
            final pId = product.id.toString();
            return pDesign == lookupLower ||
                pBarcode == lookupLower ||
                pId == lookup;
          });
        } catch (e) {
          // Product not found
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Product with barcode "$barcode" not found'),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 2),
              ),
            );
          }
          return;
        }
      }
    }

    if (scannedProduct != null) {
      addToOrder({
        'id': scannedProduct.id,
        'name': scannedProduct.title,
        'price': scannedProduct.salePrice,
        'image': scannedProduct.imagePath ?? '',
        'design_code': scannedProduct.designCode,
      });

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added "${scannedProduct.title}" to cart'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _processBarcode(String barcode) {
    if (barcode.isEmpty) return;

    // Normalize scanned value
    final lookup = barcode.trim();
    String digitsOnly(String s) => s.replaceAll(RegExp(r'\D'), '');

    try {
      // More robust lookup: iterate and apply multiple relaxed matches
      Product? scannedProduct;
      final lookupLower = lookup.toLowerCase();
      final lookupDigits = digitsOnly(lookup);

      for (final product in products) {
        final pTitle = product.title.toLowerCase();
        final pDesign = product.designCode.trim().toLowerCase();
        final pBarcodeRaw = product.barcode.trim();
        final pBarcode = pBarcodeRaw.toLowerCase();
        final pBarcodeDigits = digitsOnly(pBarcodeRaw);
        final pId = product.id.toString();
        final pNumeric = getNumericBarcode(product).toLowerCase();

        bool matched = false;

        // Exact or contains matches against title or design
        if (pTitle.isNotEmpty && pTitle.contains(lookupLower)) matched = true;
        if (pDesign.isNotEmpty && pDesign == lookupLower) matched = true;

        // Direct barcode matches
        if (!matched && pBarcode.isNotEmpty) {
          if (pBarcode == lookupLower || pBarcode.contains(lookupLower))
            matched = true;
        }

        // Numeric comparisons
        if (!matched && pBarcodeDigits.isNotEmpty && lookupDigits.isNotEmpty) {
          if (pBarcodeDigits == lookupDigits)
            matched = true;
          else if (pBarcodeDigits.endsWith(lookupDigits) ||
              lookupDigits.endsWith(pBarcodeDigits))
            matched = true;
          else if (pNumeric == lookupDigits || pNumeric.endsWith(lookupDigits))
            matched = true;
        }

        // EAN/numeric derived comparison
        if (!matched && pNumeric.isNotEmpty) {
          if (pNumeric == lookupLower || pNumeric == lookupDigits)
            matched = true;
        }

        // ID match
        if (!matched && pId == lookup) matched = true;

        if (matched) {
          scannedProduct = product;
          break;
        }
      }

      if (scannedProduct != null) {
        addToOrder({
          'id': scannedProduct.id,
          'name': scannedProduct.title,
          'price': scannedProduct.salePrice,
          'image': scannedProduct.imagePath ?? '',
          'design_code': scannedProduct.designCode,
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Scanned: "${scannedProduct.title}" added to cart'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
            ),
          );
        }
        return;
      }

      // If not found, show not found message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product with barcode "$barcode" not found'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      print('Error in _processBarcode lookup: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Product with barcode "$barcode" not found'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  void onPaymentComplete(String method, double amount) {
    // Decrement local product stock immediately so UI reflects the sale
    try {
      setState(() {
        for (final item in List<Map<String, Object>>.from(orderItems)) {
          final itemId = item['id'] is int
              ? item['id'] as int
              : int.tryParse(item['id']?.toString() ?? '') ?? 0;
          final qty = item['quantity'] is int
              ? item['quantity'] as int
              : int.tryParse(item['quantity']?.toString() ?? '') ?? 0;

          if (itemId == 0 || qty <= 0) continue;

          final prodIndex = products.indexWhere((p) => p.id == itemId);
          if (prodIndex >= 0) {
            final p = products[prodIndex];
            final currentInStock =
                int.tryParse(p.inStockQuantity) ??
                int.tryParse(p.openingStockQuantity) ??
                0;
            final newStock = (currentInStock - qty) >= 0
                ? (currentInStock - qty)
                : 0;
            // Product fields are immutable; create a new Product instance with updated inStockQuantity
            final updatedProduct = Product(
              id: p.id,
              title: p.title,
              designCode: p.designCode,
              imagePath: p.imagePath,
              imagePaths: p.imagePaths,
              subCategoryId: p.subCategoryId,
              salePrice: p.salePrice,
              buyingPrice: p.buyingPrice,
              openingStockQuantity: p.openingStockQuantity,
              inStockQuantity: newStock.toString(),
              vendorId: p.vendorId,
              vendor: p.vendor,
              barcode: p.barcode,
              qrCodeData: p.qrCodeData,
              qrCodeImagePath: p.qrCodeImagePath,
              status: p.status,
              createdAt: p.createdAt,
              updatedAt: p.updatedAt,
              sizeId: p.sizeId,
              colorId: p.colorId,
              materialId: p.materialId,
              seasonId: p.seasonId,
              colors: p.colors,
              sizes: p.sizes,
              seasons: p.seasons,
              materials: p.materials,
            );
            products[prodIndex] = updatedProduct;
          }
        }

        // Update provider cache so other parts of the app see the change
        try {
          final inventoryProvider = Provider.of<InventoryProvider>(
            context,
            listen: false,
          );
          inventoryProvider.setProducts(products);
        } catch (_) {
          // ignore if provider not available in this context
        }

        // Refresh filtered list and then clear the order
        _updateFilteredProducts();

        orderItems.clear();
        selectedCustomer = null;
        selectedSalesman = null;
        currentTotal = 0.0;
        currentTax = 0.0;
        currentDiscount = 0.0;
        currentRoundOff = 0.0;
        orderDescription = '';
        // Clear advance and due date after successful payment so the
        // PosOrderList's advance controller is updated via didUpdateWidget
        // and the Advance field appears empty for the next order.
        currentAdvance = 0.0;
        currentDueDate = null;
      });
    } catch (e) {
      // If anything fails, still attempt to clear order (best-effort)
      setState(() {
        orderItems.clear();
        selectedCustomer = null;
        selectedSalesman = null;
        currentTotal = 0.0;
        currentTax = 0.0;
        currentDiscount = 0.0;
        currentRoundOff = 0.0;
        orderDescription = '';
        // Also clear advance and due date in error path to avoid stale values
        currentAdvance = 0.0;
        currentDueDate = null;
      });
      print('Error while decrementing stock after payment: $e');
    }

    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Payment of Rs${amount.toStringAsFixed(2)} via $method completed successfully!',
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  double getSubtotal() {
    return orderItems.fold(0.0, (sum, item) {
      final price = (item['price'] is num)
          ? item['price'] as num
          : double.tryParse(item['price']?.toString() ?? '0.0') ?? 0.0;
      final quantity = (item['quantity'] is num)
          ? item['quantity'] as num
          : int.tryParse(item['quantity']?.toString() ?? '1') ?? 1;
      return sum + (price * quantity);
    });
  }

  @override
  void dispose() {
    _productsScrollController.removeListener(_onProductsScroll);
    _productsScrollController.dispose();
    _keyboardFocusNode.dispose();
    if (_routeObserver != null) {
      _routeObserver?.unsubscribe(this);
      _routeObserver = null;
    }
    _searchDebounceTimer?.cancel();
    _highlightTimer?.cancel();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when a top route has been popped and this route shows up again.
    super.didPopNext();
    if (widget.invoiceToEdit == null) {
      // If opening normally, ensure we clear any leftover invoice editing state
      setState(() {
        orderItems = [];
        selectedCustomer = null;
        selectedSalesman = null;
        currentTotal = 0.0;
        currentTax = 0.0;
        currentDiscount = 0.0;
        currentRoundOff = 0.0;
        orderDescription = '';
        _isInitializing = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _initializeDataSequentially();
      });
    } else {
      // If we are returning to edit mode, load invoice data
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _loadInvoiceForEditing(widget.invoiceToEdit!);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          _keyboardFocusNode.requestFocus();
        } catch (_) {}
      });
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);

    // Show loading screen during initialization
    if (_isInitializing) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1845),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 24),
              Text(
                _loadingMessage,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return RawKeyboardListener(
      focusNode: _keyboardFocusNode,
      onKey: (RawKeyEvent event) {
        if (event is RawKeyDownEvent) {
          final key = event.logicalKey;
          if (key == LogicalKeyboardKey.enter) {
            // Process the barcode when Enter is pressed
            if (_barcodeBuffer.isNotEmpty) {
              _processBarcode(_barcodeBuffer);
              _barcodeBuffer = '';
            }
          } else {
            // Accumulate characters for barcode
            final character = event.character;
            if (character != null && character.isNotEmpty) {
              _barcodeBuffer += character;
              // Reset timer to clear buffer if no input for 500ms
              _barcodeTimer?.cancel();
              _barcodeTimer = Timer(const Duration(milliseconds: 500), () {
                _barcodeBuffer = '';
              });
            }
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1845),
        body: Column(
          children: [
            // Custom POS Navbar
            PosNavbar(
              onBackToDashboard: widget.onBackToDashboard,
              onNavigateToContent: widget.onNavigateToContent,
            ),

            // Main Content
            Expanded(
              child: Row(
                children: [
                  // Left Side - Subcategories Only
                  Container(
                    width: 200, // Made more compact for horizontal layout
                    color: Colors.white,
                    child: Column(
                      children: [
                        // Subcategories Header - Sleek and modern
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal:
                                12, // Reduced padding to match categories
                            vertical:
                                4, // Ultra small vertical padding to match categories
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey[50]!,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(
                                  3,
                                ), // Tiny padding to match categories
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(
                                    6,
                                  ), // Tiny radius to match categories
                                  border: Border.all(color: Colors.grey[100]!),
                                ),
                                child: Icon(
                                  Icons.subdirectory_arrow_right_outlined,
                                  color: Colors.grey[700],
                                  size: 10, // Tiny icon to match categories
                                ),
                              ),
                              const SizedBox(
                                width: 6,
                              ), // Minimal spacing to match categories
                              Text(
                                'Subcategories',
                                style: TextStyle(
                                  color: Colors.grey[800],
                                  fontSize: 12, // Tiny font to match categories
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const Spacer(),
                              Container(
                                width: 2, // Tiny dot to match categories
                                height: 2,
                                decoration: BoxDecoration(
                                  color: Colors.grey[300],
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Subcategories Vertical List
                        Expanded(
                          child: isLoadingSubCategories
                              ? const Center(
                                  child: CircularProgressIndicator(
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF0D1845),
                                    ),
                                  ),
                                )
                              : _buildSubCategoriesVerticalList(),
                        ),
                      ],
                    ),
                  ),

                  // Center - Products Grid with Subcategories at Bottom
                  Expanded(
                    flex: 6,
                    child: Container(
                      color: Colors.white,
                      child: Column(
                        children: [
                          // Products Header with Search
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              border: Border(
                                bottom: BorderSide(color: Colors.grey[200]!),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Welcome Message and Date
                                Consumer<AuthProvider>(
                                  builder: (context, authProvider, child) {
                                    final user = authProvider.user;
                                    final userName = user?.fullName ?? 'User';
                                    final currentDate = DateFormat(
                                      'EEEE, MMMM d, yyyy',
                                    ).format(DateTime.now());

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              'Welcome, $userName',
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF0D1845),
                                              ),
                                            ),
                                            Text(
                                              currentDate,
                                              style: TextStyle(
                                                fontSize: 14,
                                                color: Colors.grey[600],
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 12),

                                // Search Bar with View Toggle (Compact & Elegant)
                                Row(
                                  children: [
                                    Expanded(
                                      child: Container(
                                        height: 40,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey[200]!,
                                            width: 1.5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.04,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: TextField(
                                          onChanged: onSearchChanged,
                                          style: const TextStyle(fontSize: 13),
                                          decoration: InputDecoration(
                                            hintText: 'Search products...',
                                            hintStyle: TextStyle(
                                              color: Colors.grey[400],
                                              fontSize: 13,
                                            ),
                                            prefixIcon: Icon(
                                              Icons.search,
                                              size: 20,
                                              color: Colors.grey[600],
                                            ),
                                            border: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 10,
                                                ),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // Scanner focus indicator (compact)
                                    Tooltip(
                                      message: _keyboardFocusNode.hasFocus
                                          ? 'Scanner active'
                                          : 'Scanner inactive',
                                      child: Container(
                                        width: 10,
                                        height: 10,
                                        decoration: BoxDecoration(
                                          color: _keyboardFocusNode.hasFocus
                                              ? Colors.green
                                              : Colors.red,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  (_keyboardFocusNode.hasFocus
                                                          ? Colors.green
                                                          : Colors.red)
                                                      .withOpacity(0.3),
                                              blurRadius: 4,
                                              spreadRadius: 1,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    // View Mode Toggle (compact)
                                    Container(
                                      height: 40,
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: Colors.grey[50],
                                        border: Border.all(
                                          color: Colors.grey[200]!,
                                          width: 1.5,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.04,
                                            ),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Row(
                                        children: [
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 34,
                                              minHeight: 34,
                                            ),
                                            icon: Icon(
                                              Icons.grid_view,
                                              size: 18,
                                              color: _viewMode == 'grid'
                                                  ? const Color(0xFF0D1845)
                                                  : Colors.grey,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _viewMode = 'grid';
                                              });
                                              // Ensure keyboard focus returns to the POS scanner listener
                                              try {
                                                _keyboardFocusNode
                                                    .requestFocus();
                                              } catch (_) {}
                                            },
                                            tooltip: 'Grid View',
                                          ),
                                          Container(
                                            width: 1,
                                            height: 28,
                                            color: Colors.grey[300],
                                          ),
                                          IconButton(
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(
                                              minWidth: 34,
                                              minHeight: 34,
                                            ),
                                            icon: Icon(
                                              Icons.table_rows,
                                              size: 18,
                                              color: _viewMode == 'table'
                                                  ? const Color(0xFF0D1845)
                                                  : Colors.grey,
                                            ),
                                            onPressed: () {
                                              setState(() {
                                                _viewMode = 'table';
                                              });
                                              // Ensure keyboard focus returns to the POS scanner listener
                                              try {
                                                _keyboardFocusNode
                                                    .requestFocus();
                                              } catch (_) {}
                                            },
                                            tooltip: 'Table View',
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    ElevatedButton.icon(
                                      onPressed: _scanBarcode,
                                      icon: const Icon(Icons.qr_code_scanner),
                                      label: const Text('Scan'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF0D1845,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 16,
                                          vertical: 12,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // Products Grid or Table - optimized for performance
                          Expanded(
                            child: isLoadingProducts
                                ? const Center(
                                    child: CircularProgressIndicator(),
                                  )
                                : _viewMode == 'table'
                                ? _buildProductsTable()
                                : _buildProductsGrid(),
                          ),

                          // Categories Section at Bottom (SafeArea to avoid bottom overflow)
                          SafeArea(
                            bottom: true,
                            child: Container(
                              height:
                                  85, // Increased slightly to prevent 2px overflow
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border(
                                  top: BorderSide(
                                    color: Colors.grey[100]!,
                                    width: 1,
                                  ),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.03),
                                    blurRadius: 8,
                                    offset: Offset(0, -2),
                                  ),
                                ],
                              ),
                              child: Column(
                                children: [
                                  // Categories Header - Ultra minimal
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal:
                                          12, // Minimal horizontal padding
                                      vertical:
                                          4, // Ultra small vertical padding
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      border: Border(
                                        bottom: BorderSide(
                                          color: Colors.grey[50]!,
                                          width: 1,
                                        ),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(
                                            3,
                                          ), // Tiny padding
                                          decoration: BoxDecoration(
                                            color: Colors.grey[50],
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ), // Tiny radius
                                            border: Border.all(
                                              color: Colors.grey[100]!,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.category_outlined,
                                            color: Colors.grey[700],
                                            size: 10, // Tiny icon
                                          ),
                                        ),
                                        const SizedBox(
                                          width: 6,
                                        ), // Minimal spacing
                                        Text(
                                          'Categories',
                                          style: TextStyle(
                                            color: Colors.grey[800],
                                            fontSize: 12, // Tiny font
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                        const Spacer(),
                                        Container(
                                          width: 2, // Tiny dot
                                          height: 2,
                                          decoration: BoxDecoration(
                                            color: Colors.grey[300],
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Categories Horizontal List
                                  Expanded(
                                    child: isLoadingCategories
                                        ? const Center(
                                            child: SizedBox(
                                              width: 16, // Tiny loader
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Color(0xFF0D1845)),
                                              ),
                                            ),
                                          )
                                        : _buildCategoriesList(),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Right Side - Order Details (No Footer)
                  Container(
                    width: 480,
                    color: const Color(0xFFF8F9FA),
                    child: Column(
                      children: [
                        // Order Details (Scrollable)
                        Expanded(
                          child: SingleChildScrollView(
                            physics:
                                const BouncingScrollPhysics(), // Changed for smoother scrolling
                            child: Column(
                              children: [
                                // Order List
                                PosOrderList(
                                  orderItems: orderItems,
                                  onUpdateQuantity: updateOrderItemQuantity,
                                  onRemoveItem: removeOrderItem,
                                  onSelectCustomer: selectCustomer,
                                  salesmen: salesmen,
                                  selectedSalesman: selectedSalesman,
                                  onSelectSalesman: (salesman) {
                                    setState(() {
                                      selectedSalesman = salesman;
                                    });
                                  },
                                  onTotalChanged: (total) {
                                    setState(() {
                                      currentTotal = total;
                                    });
                                  },
                                  onTaxDiscountChanged:
                                      (tax, discount, roundOff) {
                                        setState(() {
                                          currentTax = tax;
                                          currentDiscount = discount;
                                          currentRoundOff = roundOff;
                                        });
                                      },
                                  description: orderDescription,
                                  onDescriptionChanged: (description) {
                                    setState(() {
                                      orderDescription = description;
                                    });
                                  },
                                  advanceAmount: currentAdvance,
                                  onAdvanceChanged: (a) {
                                    setState(() {
                                      currentAdvance = a;
                                    });
                                  },
                                  dueDate: currentDueDate,
                                  onDueDateChanged: (d) {
                                    setState(() {
                                      currentDueDate = d;
                                    });
                                  },
                                  initialActiveTab: widget.openCustomTab
                                      ? 1
                                      : 0,
                                  // When editing an invoice, lock the tab so user
                                  // cannot switch order types while editing.
                                  disableTabSwitching:
                                      widget.invoiceToEdit != null,
                                  onActiveTabChanged: (int idx) {
                                    setState(() {
                                      _isCustomTabActive = idx == 1;
                                    });
                                  },
                                ),

                                // Payment Methods
                                PosPaymentMethods(
                                  // When true, payment UI must only show Credit
                                  // and the outgoing request will force
                                  // payment_mode = 2 for custom orders.
                                  isCustomOrder: _isCustomTabActive,
                                  totalAmount: currentTotal,
                                  taxAmount: currentTax,
                                  discountAmount: currentDiscount,
                                  subtotalAmount: getSubtotal(),
                                  roundOffAmount: currentRoundOff,
                                  onPaymentComplete: onPaymentComplete,
                                  orderItems: orderItems,
                                  selectedCustomer: selectedCustomer,
                                  selectedSalesman: selectedSalesman,
                                  onSelectCreditCustomer: (cust) {
                                    setState(() {
                                      selectedCustomer = cust;
                                    });
                                  },
                                  invoiceToEdit: widget.invoiceToEdit,
                                  description: orderDescription,
                                  initialAdvance: currentAdvance,
                                  dueDate: currentDueDate,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildCategoriesList() {
    if (categories.isEmpty) {
      return const Center(
        child: Text(
          'No categories available',
          style: TextStyle(
            color: Colors.grey,
            fontSize: 9, // Tiny font for empty state
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return Container(
      constraints: const BoxConstraints(
        maxHeight: 42, // Increased to match container height
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: 6,
          vertical: 1,
        ), // Ultra minimal padding
        child: Row(
          children: [
            // "All" category
            _buildCategoryItemForBottom(
              'all',
              'All',
              Icons.grid_view_outlined,
              selectedCategoryId == 'all',
            ),
            // Other categories
            ...categories.map((category) {
              return _buildCategoryItemForBottom(
                category.id.toString(),
                category.title,
                _getCategoryIcon(category.title),
                selectedCategoryId == category.id.toString(),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSubCategoriesVerticalList() {
    // Filter subcategories based on selected category
    List<SubCategory> filteredSubCategories = selectedCategoryId == 'all'
        ? subCategories
        : subCategories
              .where(
                (subCategory) =>
                    subCategory.categoryId.toString() == selectedCategoryId,
              )
              .toList();

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      physics: const BouncingScrollPhysics(),
      itemCount: filteredSubCategories.length + 1, // +1 for "All" subcategory
      itemBuilder: (context, index) {
        if (index == 0) {
          // "All" subcategory
          return _buildSubCategoryItemForVertical(
            'all',
            'All',
            Icons.grid_view_outlined,
            selectedSubCategoryId == 'all',
          );
        } else {
          final subCategory = filteredSubCategories[index - 1];
          return _buildSubCategoryItemForVertical(
            subCategory.id.toString(),
            subCategory.title,
            Icons.subdirectory_arrow_right,
            selectedSubCategoryId == subCategory.id.toString(),
          );
        }
      },
    );
  }

  Widget _buildSubCategoryItemForVertical(
    String subCategoryId,
    String title,
    IconData icon,
    bool isSelected,
  ) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Material(
        elevation: isSelected ? 3 : 1,
        borderRadius: BorderRadius.circular(12),
        shadowColor: isSelected
            ? const Color(0xFF0D1845).withOpacity(0.25)
            : Colors.black.withOpacity(0.08),
        child: InkWell(
          onTap: () => onSubCategorySelected(subCategoryId),
          borderRadius: BorderRadius.circular(12),
          splashColor: const Color(0xFF0D1845).withOpacity(0.1),
          highlightColor: const Color(0xFF0D1845).withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0D1845) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0D1845)
                    : Colors.grey[200]!.withOpacity(0.8),
                width: isSelected ? 2 : 1.5,
              ),
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        const Color(0xFF0D1845),
                        const Color(0xFF1A237E),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [Colors.white, Colors.grey[50]!],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : Colors.grey[100]!.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected
                          ? Colors.white.withOpacity(0.3)
                          : Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 16,
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey[800],
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (isSelected)
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.25),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: Colors.white.withOpacity(0.4),
                        width: 1,
                      ),
                    ),
                    child: const Icon(
                      Icons.check,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryItemForBottom(
    String categoryId,
    String title,
    IconData icon,
    bool isSelected,
  ) {
    return Container(
      width: 75, // Increased width for bigger buttons
      margin: const EdgeInsets.only(right: 4, left: 1), // Slightly more margin
      child: Material(
        elevation: isSelected ? 3 : 1, // Slightly more elevation
        borderRadius: BorderRadius.circular(12), // Slightly bigger radius
        shadowColor: isSelected
            ? const Color(0xFF0D1845).withOpacity(0.25)
            : Colors.black.withOpacity(0.08),
        child: InkWell(
          onTap: () => onCategorySelected(categoryId),
          borderRadius: BorderRadius.circular(12),
          splashColor: const Color(0xFF0D1845).withOpacity(0.1),
          highlightColor: const Color(0xFF0D1845).withOpacity(0.05),
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: 6,
              horizontal: 4,
            ), // More padding
            decoration: BoxDecoration(
              color: isSelected ? const Color(0xFF0D1845) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF0D1845)
                    : Colors.grey[200]!.withOpacity(0.8),
                width: isSelected ? 2 : 1.5,
              ),
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        const Color(0xFF0D1845),
                        const Color(0xFF1A237E),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : LinearGradient(
                      colors: [Colors.white, Colors.grey[50]!],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(4), // More padding for icon
                  decoration: BoxDecoration(
                    color: isSelected
                        ? Colors.white.withOpacity(0.2)
                        : Colors.grey[100]!.withOpacity(0.8),
                    borderRadius: BorderRadius.circular(8), // Bigger radius
                    border: Border.all(
                      color: isSelected
                          ? Colors.white.withOpacity(0.3)
                          : Colors.grey[200]!,
                      width: 1,
                    ),
                  ),
                  child: Icon(
                    icon,
                    size: 12, // Bigger icon
                    color: isSelected ? Colors.white : Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 2), // Slightly more spacing
                Text(
                  title,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.grey[800],
                    fontSize: 9, // Bigger font
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Build responsive products grid
  Widget _buildProductsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate responsive crossAxisCount based on available width
        final width = constraints.maxWidth;
        int crossAxisCount;

        if (width > 1400) {
          crossAxisCount = 7;
        } else if (width > 1200) {
          crossAxisCount = 6;
        } else if (width > 1000) {
          crossAxisCount = 5;
        } else if (width > 800) {
          crossAxisCount = 4;
        } else {
          crossAxisCount = 3;
        }

        // Compute bottom padding dynamically
        final bottomInset = MediaQuery.of(context).viewPadding.bottom;
        final categoriesBarHeight = 85.0;
        final bottomPadding = categoriesBarHeight + bottomInset + 12.0;

        return GridView.builder(
          controller: _productsScrollController,
          padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
          physics: const BouncingScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
            childAspectRatio: 1.2,
          ),
          itemCount: _filteredProducts.length + (_isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == _filteredProducts.length) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              );
            }
            final product = _filteredProducts[index];
            return _buildProductCard(product);
          },
        );
      },
    );
  }

  // Build products table view
  Widget _buildProductsTable() {
    // Compute bottom padding dynamically
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final categoriesBarHeight = 85.0;
    final bottomPadding = categoriesBarHeight + bottomInset + 12.0;

    return SingleChildScrollView(
      controller: _productsScrollController,
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomPadding),
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Table with improved spacing and alignment
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Table Header
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1845),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(8),
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 100,
                        child: _buildTableHeaderText('Product ID'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 2,
                        child: _buildTableHeaderText('Barcode'),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 3,
                        child: _buildTableHeaderText('Product Name'),
                      ),
                      const SizedBox(width: 0),
                      SizedBox(
                        width: 120,
                        child: _buildTableHeaderText(
                          'Price',
                          textAlign: TextAlign.right,
                        ),
                      ),
                      const SizedBox(width: 24),
                      SizedBox(
                        width: 110,
                        child: _buildTableHeaderText(
                          'Stock Qty',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ),
                // Table Body Rows
                ...List.generate(_filteredProducts.length, (index) {
                  final product = _filteredProducts[index];
                  final price = double.tryParse(product.salePrice) ?? 0.0;
                  // Use the actual in-stock quantity (from API) instead of opening stock
                  final stockQty =
                      int.tryParse(product.inStockQuantity) ??
                      int.tryParse(product.openingStockQuantity) ??
                      0;

                  final bool isHighlighted = _lastAddedProductId == product.id;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    decoration: BoxDecoration(
                      color: isHighlighted
                          ? Colors.yellow[50]
                          : (index.isEven ? Colors.white : Colors.grey[50]),
                      border: isHighlighted
                          ? Border.all(color: Colors.orange.shade300, width: 2)
                          : Border(
                              bottom: BorderSide(
                                color: Colors.grey[200]!,
                                width: 0.5,
                              ),
                            ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: InkWell(
                      onTap: () => addToOrder({
                        'id': product.id,
                        'name': product.title,
                        'price': product.salePrice,
                        'design_code': product.designCode,
                      }),
                      hoverColor: const Color(0xFF0D1845).withOpacity(0.05),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 100,
                            child: Text(
                              product.id.toString(),
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text(
                              product.barcode.isNotEmpty
                                  ? getNumericBarcode(product)
                                  : 'N/A',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: Text(
                              product.title,
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF0D1845),
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 0),
                          SizedBox(
                            width: 120,
                            child: Text(
                              'Rs${price.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                              textAlign: TextAlign.right,
                            ),
                          ),
                          const SizedBox(width: 24),
                          SizedBox(
                            width: 110,
                            child: Text(
                              stockQty > 0
                                  ? stockQty.toString()
                                  : 'Out of stock',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: stockQty > 0
                                    ? Colors.green[700]
                                    : Colors.red[700],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),
          // Loading indicator
          if (_isLoadingMore)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
        ],
      ),
    );
  }

  Widget _buildTableHeaderText(
    String text, {
    TextAlign textAlign = TextAlign.left,
  }) {
    return Text(
      text,
      style: const TextStyle(
        color: Colors.white,
        fontWeight: FontWeight.bold,
        fontSize: 13,
        letterSpacing: 0.3,
      ),
      textAlign: textAlign,
    );
  }

  Widget _buildProductCard(Product product) {
    // Pre-compute values to avoid repeated calculations
    final price = double.tryParse(product.salePrice) ?? 0.0;

    // Prefer API-provided in-stock quantity; fall back to opening stock if absent
    final stockQuantity =
        int.tryParse(product.inStockQuantity) ??
        int.tryParse(product.openingStockQuantity) ??
        0;

    return RepaintBoundary(
      // Add RepaintBoundary to prevent unnecessary repaints
      child: Container(
        margin: const EdgeInsets.all(4),
        child: Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(16),
          shadowColor: Colors.black.withOpacity(0.08),
          child: InkWell(
            onTap: () => addToOrder({
              'id': product.id,
              'name': product.title,
              'price': product.salePrice,
              'design_code': product.designCode,
            }),
            borderRadius: BorderRadius.circular(16),
            splashColor: const Color(0xFF0D1845).withOpacity(0.05),
            highlightColor: const Color(0xFF0D1845).withOpacity(0.03),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.all(8), // Reduced padding
              decoration: BoxDecoration(
                color: _lastAddedProductId == product.id
                    ? Colors.yellow[50]
                    : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _lastAddedProductId == product.id
                      ? Colors.orange.shade300
                      : Colors.grey[100]!.withOpacity(0.8),
                  width: _lastAddedProductId == product.id ? 2 : 1,
                ),
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.grey[50]!.withOpacity(0.3)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                boxShadow: _lastAddedProductId == product.id
                    ? [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
              ),
              child: Stack(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Product Name - POS navbar color, left-aligned at top
                      Text(
                        product.title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D1845), // POS navbar color
                          height: 1.2,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.left, // Left-aligned
                      ),

                      const SizedBox(height: 4),

                      // Product Price - Bold
                      Text(
                        'Rs${price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold, // Bold as requested
                          color: Color(0xFF0D1845),
                          height: 1.2,
                        ),
                        textAlign: TextAlign.left,
                      ),

                      // Design Code (if available)
                      if (product.designCode.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey[100]!.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            product.designCode,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey[600],
                              letterSpacing: 0.5,
                            ),
                            textAlign: TextAlign.left,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ],
                  ),

                  // Stock Quantity - Right-aligned at bottom right corner
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: stockQuantity > 0
                            ? Colors.green[600]
                            : Colors.red[400],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        stockQuantity > 0
                            ? stockQuantity.toString()
                            : 'Out of stock',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String categoryName) {
    final name = categoryName.toLowerCase();

    // Map common category names to appropriate icons
    if (name.contains('food') ||
        name.contains('meal') ||
        name.contains('restaurant')) {
      return Icons.restaurant;
    } else if (name.contains('drink') ||
        name.contains('beverage') ||
        name.contains('coffee') ||
        name.contains('tea')) {
      return Icons.local_drink;
    } else if (name.contains('snack') ||
        name.contains('chips') ||
        name.contains('candy')) {
      return Icons.cookie;
    } else if (name.contains('fruit') ||
        name.contains('vegetable') ||
        name.contains('organic')) {
      return Icons.eco;
    } else if (name.contains('bakery') ||
        name.contains('bread') ||
        name.contains('cake')) {
      return Icons.cake;
    } else if (name.contains('dairy') ||
        name.contains('milk') ||
        name.contains('cheese')) {
      return Icons.egg;
    } else if (name.contains('meat') ||
        name.contains('chicken') ||
        name.contains('beef')) {
      return Icons.restaurant_menu;
    } else if (name.contains('frozen') || name.contains('ice cream')) {
      return Icons.ac_unit;
    } else if (name.contains('cleaning') || name.contains('household')) {
      return Icons.cleaning_services;
    } else if (name.contains('personal') ||
        name.contains('care') ||
        name.contains('beauty')) {
      return Icons.spa;
    } else if (name.contains('electronics') || name.contains('gadget')) {
      return Icons.devices;
    } else if (name.contains('clothing') ||
        name.contains('fashion') ||
        name.contains('wear')) {
      return Icons.checkroom;
    } else if (name.contains('book') || name.contains('stationery')) {
      return Icons.menu_book;
    } else if (name.contains('toy') || name.contains('game')) {
      return Icons.toys;
    } else if (name.contains('sport') || name.contains('fitness')) {
      return Icons.sports;
    } else {
      // Default icon for unknown categories
      return Icons.category;
    }
  }

  List<Product> _getFilteredProducts() {
    // Use efficient filtering with early returns and optimized logic
    if (selectedSubCategoryId == 'all' &&
        selectedCategoryId == 'all' &&
        searchQuery.isEmpty) {
      return products;
    }

    // Pre-process search query for better performance
    final query = searchQuery.toLowerCase().trim();
    final hasSearchQuery = query.isNotEmpty;

    // Use more efficient filtering with less allocations and early returns
    final queryDigits = query.replaceAll(RegExp(r'\D'), '');

    return products
        .where((product) {
          // Subcategory filter - check first as it's more specific
          if (selectedSubCategoryId != 'all' &&
              product.subCategoryId != selectedSubCategoryId) {
            return false;
          }

          // Category filter - if no specific subcategory selected, filter by category
          if (selectedSubCategoryId == 'all' && selectedCategoryId != 'all') {
            // Find the subcategory this product belongs to and check if it matches the selected category
            final productSubCategory = subCategories.firstWhere(
              (subCat) => subCat.id.toString() == product.subCategoryId,
              orElse: () => SubCategory(
                id: 0,
                title: '',
                categoryId: 0,
                status: '',
                createdAt: '',
                updatedAt: '',
              ),
            );
            if (productSubCategory.categoryId.toString() !=
                selectedCategoryId) {
              return false;
            }
          }

          // Search filter - only if there's a query
          if (hasSearchQuery) {
            final title = product.title.toLowerCase();
            final designCode = product.designCode.toLowerCase();
            final barcodeRaw = product.barcode.toLowerCase();
            final barcodeDigits = barcodeRaw.replaceAll(RegExp(r'\D'), '');
            final numericBarcode = getNumericBarcode(product).toLowerCase();

            // Match search against product title or design code first
            if (title.contains(query) || designCode.contains(query))
              return true;

            // If query is numeric (digits only), compare against numeric barcode forms
            if (queryDigits.isNotEmpty) {
              if (barcodeDigits.contains(queryDigits) ||
                  numericBarcode.contains(queryDigits))
                return true;
            }

            // Generic substring match against raw barcode or normalized numeric barcode
            if (barcodeRaw.contains(query) || numericBarcode.contains(query))
              return true;

            return false;
          }

          return true;
        })
        .toList(growable: false);
  }
}
