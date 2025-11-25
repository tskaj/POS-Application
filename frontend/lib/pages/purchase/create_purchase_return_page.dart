import 'package:flutter/material.dart';
import '../../utils/unsaved_guard.dart';
import 'package:intl/intl.dart';
import '../../services/inventory_service.dart';
import '../../services/purchases_service.dart';
import '../../models/vendor.dart' as vendor;
import '../../models/product.dart';

class CreatePurchaseReturnPage extends StatefulWidget {
  const CreatePurchaseReturnPage({super.key});

  @override
  State<CreatePurchaseReturnPage> createState() =>
      _CreatePurchaseReturnPageState();
}

class _CreatePurchaseReturnPageState extends State<CreatePurchaseReturnPage> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _orderDiscountController = TextEditingController();
  final _notesController = TextEditingController();

  // Vendor search
  List<vendor.Vendor> _filteredVendors = [];
  final TextEditingController _vendorSearchController = TextEditingController();

  // Product search
  List<Product> _filteredProducts = [];
  final TextEditingController _productSearchController =
      TextEditingController();

  DateTime _selectedDate = DateTime.now();
  int? _selectedVendorId;
  List<vendor.Vendor> vendors = [];
  List<Product> products = [];
  List<PurchaseReturnItem> purchaseReturnItems = [];
  bool isSubmitting = false;
  int _currentPage = 0;

  // Controllers for quantity fields
  List<TextEditingController> quantityControllers = [];
  // Controllers for purchase price fields (one per item)
  List<TextEditingController> purchasePriceControllers = [];

  @override
  void initState() {
    super.initState();
    _fetchVendors();
    // Remove initial product fetch - products will be loaded when vendor is selected

    // Add listeners to update calculations in real-time
    _orderDiscountController.addListener(() => setState(() {}));

    // Register with global unsaved-changes guard so sidebar/navigation
    // can ask this page whether it's safe to navigate away.
    UnsavedChangesGuard().register((ctx) => _confirmLeave());
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _orderDiscountController.dispose();
    _notesController.dispose();
    _vendorSearchController.dispose();
    _productSearchController.dispose();
    for (var controller in quantityControllers) {
      controller.dispose();
    }
    for (var controller in purchasePriceControllers) {
      controller.dispose();
    }
    // Unregister guard when disposing
    UnsavedChangesGuard().unregister();
    super.dispose();
  }

  Future<void> _fetchVendors() async {
    try {
      final vendorResponse = await InventoryService.getVendors();
      setState(() {
        vendors = vendorResponse.data;
      });
    } catch (e) {
      setState(() {
        vendors = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load vendors: $e'),
          backgroundColor: Color(0xFFDC3545),
        ),
      );
    }
  }

  Future<void> _fetchProductsByVendor(int vendorId) async {
    try {
      // Fetch a larger page to include products for the selected vendor
      // (backend paginates results). If API supports vendor filtering, prefer
      // that instead for performance.
      final productResponse = await InventoryService.getProducts(
        page: 1,
        limit: 1000,
      );

      // Product.vendorId is a String in the model; product.vendor.id is an
      // int. Compare against both to be tolerant of API shapes.
      final filteredProducts = productResponse.data.where((product) {
        final prodVendorId = product.vendorId.toString();
        final prodVendorObjId = product.vendor.id;
        return prodVendorId == vendorId.toString() ||
            prodVendorObjId == vendorId;
      }).toList();

      setState(() {
        products = filteredProducts;
      });
    } catch (e) {
      setState(() {
        products = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load products for selected vendor: $e'),
          backgroundColor: Color(0xFFDC3545),
        ),
      );
    }
  }

  void _addPurchaseReturnItem() {
    setState(() {
      purchaseReturnItems.add(PurchaseReturnItem());
      quantityControllers.add(TextEditingController(text: '1'));
      purchasePriceControllers.add(TextEditingController(text: ''));
    });
  }

  void _removePurchaseReturnItem(int index) {
    setState(() {
      purchaseReturnItems.removeAt(index);
      // dispose and remove controllers for this row
      if (index >= 0 && index < quantityControllers.length) {
        quantityControllers[index].dispose();
        quantityControllers.removeAt(index);
      }
      if (index >= 0 && index < purchasePriceControllers.length) {
        purchasePriceControllers[index].dispose();
        purchasePriceControllers.removeAt(index);
      }
    });
  }

  void _updatePurchaseReturnItem(int index, PurchaseReturnItem item) {
    setState(() {
      purchaseReturnItems[index] = item;
    });
  }

  double _calculateGrandTotal() {
    double subtotal = 0;
    for (var item in purchaseReturnItems) {
      subtotal += item.totalCost;
    }

    double orderDiscount = double.tryParse(_orderDiscountController.text) ?? 0;

    // Apply discount first (as percentage) only if subtotal is positive
    double totalAfterDiscount = subtotal;
    if (subtotal >= 0) {
      totalAfterDiscount = subtotal - (subtotal * orderDiscount / 100);
    }

    // No tax for returns
    return totalAfterDiscount;
  }

  double _calculateSubtotal() {
    double subtotal = 0;
    for (var item in purchaseReturnItems) {
      subtotal += item.totalCost;
    }
    return subtotal;
  }

  // Returns true if any form field or selection indicates unsaved changes
  bool _hasUnsavedChanges() {
    if (_referenceController.text.trim().isNotEmpty) return true;
    if (_orderDiscountController.text.trim().isNotEmpty) return true;
    if (_notesController.text.trim().isNotEmpty) return true;
    if (_selectedVendorId != null) return true;
    if (purchaseReturnItems.isNotEmpty) return true;
    return false;
  }

  // Shows confirmation dialog and returns true when user confirms leaving
  Future<bool> _confirmLeave() async {
    if (!_hasUnsavedChanges()) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Are you sure you want to leave?',
            style: TextStyle(color: Colors.black87),
          ),
          content: const Text(
            'Unsaved changes will be lost.',
            style: TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.black87),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF0D1845),
              onPrimary: Colors.white,
              onSurface: Color(0xFF343A40),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Vendor Search Dialog
  void _showVendorSearchDialog() {
    _filteredVendors = List.from(vendors);
    _vendorSearchController.clear();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void filterVendors(String query) {
              setDialogState(() {
                if (query.isEmpty) {
                  _filteredVendors = List.from(vendors);
                } else {
                  _filteredVendors = vendors.where((v) {
                    final name = v.fullName.toLowerCase();
                    final code = v.vendorCode.toLowerCase();
                    final q = query.toLowerCase();
                    return name.contains(q) || code.contains(q);
                  }).toList();
                }
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.5,
                constraints: BoxConstraints(maxHeight: 600, maxWidth: 500),
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xFF0D1845).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.business,
                            color: Color(0xFF0D1845),
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Select Vendor',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _vendorSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name or code...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onChanged: filterVendors,
                    ),
                    SizedBox(height: 16),
                    Flexible(
                      child: _filteredVendors.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No vendors found',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _filteredVendors.length,
                              itemBuilder: (context, index) {
                                final v = _filteredVendors[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Color(
                                      0xFF0D1845,
                                    ).withOpacity(0.1),
                                    child: Icon(
                                      Icons.business,
                                      color: Color(0xFF0D1845),
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    v.fullName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text('Code: ${v.vendorCode}'),
                                  onTap: () {
                                    setState(() {
                                      _selectedVendorId = v.id;
                                      products = [];
                                      purchaseReturnItems = [];
                                    });
                                    _fetchProductsByVendor(v.id);
                                    Navigator.of(dialogContext).pop();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Product Search Dialog for adding items
  void _showProductSearchDialog(int itemIndex) {
    _filteredProducts = List.from(products);
    _productSearchController.clear();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void filterProducts(String query) {
              setDialogState(() {
                if (query.isEmpty) {
                  _filteredProducts = List.from(products);
                } else {
                  _filteredProducts = products.where((p) {
                    final title = p.title.toLowerCase();
                    final code = p.designCode.toLowerCase();
                    final q = query.toLowerCase();
                    return title.contains(q) || code.contains(q);
                  }).toList();
                }
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.5,
                constraints: BoxConstraints(maxHeight: 600, maxWidth: 500),
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xFF0D1845).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.inventory,
                            color: Color(0xFF0D1845),
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Select Product',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _productSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name or code...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onChanged: filterProducts,
                    ),
                    SizedBox(height: 16),
                    Flexible(
                      child: _filteredProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No products found',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _filteredProducts.length,
                              itemBuilder: (context, index) {
                                final p = _filteredProducts[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Color(
                                      0xFF0D1845,
                                    ).withOpacity(0.1),
                                    child: Icon(
                                      Icons.inventory,
                                      color: Color(0xFF0D1845),
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    p.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text('Code: ${p.designCode}'),
                                  onTap: () {
                                    setState(() {
                                      double chosenPrice = 0.0;
                                      purchaseReturnItems[itemIndex] =
                                          purchaseReturnItems[itemIndex]
                                              .copyWith(
                                                productId: p.id,
                                                description: p.title,
                                                purchasePrice: chosenPrice,
                                              );
                                      // Ensure controller exists for this index and update its text
                                      if (purchasePriceControllers.length <=
                                          itemIndex) {
                                        for (
                                          int i =
                                              purchasePriceControllers.length;
                                          i <= itemIndex;
                                          i++
                                        ) {
                                          purchasePriceControllers.add(
                                            TextEditingController(
                                              text: i == itemIndex
                                                  ? (chosenPrice == 0
                                                        ? ''
                                                        : chosenPrice
                                                              .toStringAsFixed(
                                                                2,
                                                              ))
                                                  : '',
                                            ),
                                          );
                                        }
                                      } else {
                                        purchasePriceControllers[itemIndex]
                                            .text = chosenPrice == 0
                                            ? ''
                                            : chosenPrice.toStringAsFixed(2);
                                        purchasePriceControllers[itemIndex]
                                            .selection = TextSelection.fromPosition(
                                          TextPosition(
                                            offset:
                                                purchasePriceControllers[itemIndex]
                                                    .text
                                                    .length,
                                          ),
                                        );
                                      }
                                    });
                                    Navigator.of(dialogContext).pop();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (purchaseReturnItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add at least one product to return'),
          backgroundColor: Color(0xFFDC3545),
        ),
      );
      return;
    }

    // Validate all purchase return items
    for (int i = 0; i < purchaseReturnItems.length; i++) {
      if (purchaseReturnItems[i].productId == null ||
          purchaseReturnItems[i].quantity <= 0 ||
          purchaseReturnItems[i].purchasePrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please complete all product details for item ${i + 1}',
            ),
            backgroundColor: Color(0xFFDC3545),
          ),
        );
        return;
      }
    }

    // Validate stock quantities
    for (int i = 0; i < purchaseReturnItems.length; i++) {
      final item = purchaseReturnItems[i];
      if (item.productId != null) {
        final product = products.firstWhere((p) => p.id == item.productId);
        final maxQty = int.tryParse(product.inStockQuantity) ?? 0;
        if (item.quantity > maxQty) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Quantity for ${product.title} exceeds available stock ($maxQty)',
              ),
              backgroundColor: Color(0xFFDC3545),
            ),
          );
          return;
        }
      }
    }

    setState(() => isSubmitting = true);

    try {
      // Prepare purchase return data for API
      final purchaseReturnData = {
        'vendor_id': _selectedVendorId,
        'return_inv_no': _referenceController.text,
        'return_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'payment_status': 'unpaid',
        'reason': _notesController.text,
        'return_amount': _calculateGrandTotal(),
        'transaction_type_id': 3, // Default transaction type (Purchase Return)
        'payment_mode_id': 1, // Default payment mode (Cash)
        'users_id': 1, // ID of the current logged in user
        'coas_id': 8, // This will remain constant
        'discount_percent':
            (double.tryParse(_orderDiscountController.text) ?? 0).toString(),
        'discount_amt':
            (_calculateSubtotal() >= 0
                    ? (_calculateSubtotal() *
                          ((double.tryParse(_orderDiscountController.text) ??
                                  0) /
                              100))
                    : 0)
                .toString(),
        'details': purchaseReturnItems.map((item) {
          return {
            'product_id': item.productId.toString(),
            'qty': item.quantity.toString(),
            'unit_price': item.purchasePrice.toString(),
            'discPer':
                (item.purchasePrice > 0
                        ? (item.discount / item.purchasePrice * 100)
                        : 0)
                    .toString(),
            'discAmount': (item.discount * item.quantity).toString(),
          };
        }).toList(),
      };

      // Call API to create purchase return
      await PurchaseReturnService.createPurchaseReturn(purchaseReturnData);

      // Navigate back to purchase return listing page with success result
      Navigator.of(context).pop(true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Failed to create purchase return: $e')),
            ],
          ),
          backgroundColor: Color(0xFFDC3545),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  List<PurchaseReturnItem> _getPaginatedItems() {
    int startIndex = _currentPage * 10;
    int endIndex = startIndex + 10;
    if (endIndex > purchaseReturnItems.length) {
      endIndex = purchaseReturnItems.length;
    }
    return purchaseReturnItems.sublist(startIndex, endIndex);
  }

  int _getTotalPages() {
    return (purchaseReturnItems.length / 10).ceil();
  }

  @override
  Widget build(BuildContext context) {
    // Keep purchase price controllers in sync with items
    if (purchasePriceControllers.length < purchaseReturnItems.length) {
      for (
        int i = purchasePriceControllers.length;
        i < purchaseReturnItems.length;
        i++
      ) {
        purchasePriceControllers.add(
          TextEditingController(
            text: purchaseReturnItems[i].purchasePrice == 0
                ? ''
                : purchaseReturnItems[i].purchasePrice.toString(),
          ),
        );
      }
    } else if (purchasePriceControllers.length > purchaseReturnItems.length) {
      for (
        int i = purchasePriceControllers.length - 1;
        i >= purchaseReturnItems.length;
        i--
      ) {
        purchasePriceControllers[i].dispose();
        purchasePriceControllers.removeAt(i);
      }
    }
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () async {
            if (await _confirmLeave()) {
              Navigator.of(context).pop();
            }
          },
          tooltip: 'Back',
        ),
        title: Text('Create Purchase Return Order'),
        backgroundColor: Color(0xFF0D1845),
        foregroundColor: Colors.white,
      ),
      body: WillPopScope(
        onWillPop: () => _confirmLeave(),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Colors.white, Color(0xFFF8F9FA)],
            ),
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Container(
                    padding: const EdgeInsets.all(16),
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
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.assignment_return,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Create Purchase Return Order',
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.3,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Return products from existing purchases',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Form Container
                  Container(
                    padding: const EdgeInsets.all(20),
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
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Basic Information Section
                        _buildSectionHeader('Basic Information', Icons.info),
                        const SizedBox(height: 12),

                        // Row 1: Vendor & Date
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 4,
                                      bottom: 4,
                                    ),
                                    child: Text(
                                      'Vendor *',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: _showVendorSearchDialog,
                                    child: Container(
                                      height: 38,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.business,
                                            color: Color(0xFF0D1845),
                                            size: 16,
                                          ),
                                          SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              _selectedVendorId != null
                                                  ? vendors
                                                        .firstWhere(
                                                          (v) =>
                                                              v.id ==
                                                              _selectedVendorId,
                                                        )
                                                        .fullName
                                                  : 'Select vendor',
                                              style: TextStyle(fontSize: 12),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Icon(
                                            Icons.arrow_drop_down,
                                            size: 16,
                                            color: Colors.grey,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 4,
                                      bottom: 4,
                                    ),
                                    child: Text(
                                      'Date *',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    onTap: () => _selectDate(context),
                                    child: Container(
                                      height: 38,
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.calendar_today,
                                            size: 16,
                                            color: Color(0xFF0D1845),
                                          ),
                                          SizedBox(width: 6),
                                          Expanded(
                                            child: Text(
                                              DateFormat(
                                                'dd MMM yyyy',
                                              ).format(_selectedDate),
                                              style: TextStyle(fontSize: 12),
                                            ),
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
                        const SizedBox(height: 12),

                        // Row 2: Reference & Discount
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      left: 4,
                                      bottom: 4,
                                    ),
                                    child: Text(
                                      'Reference',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  TextFormField(
                                    controller: _referenceController,
                                    decoration: InputDecoration(
                                      hintText: 'PR number',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      hintStyle: TextStyle(fontSize: 12),
                                    ),
                                    style: TextStyle(fontSize: 12),
                                    validator: (value) => value?.isEmpty ?? true
                                        ? 'Required'
                                        : null,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Products Section
                        _buildSectionHeader(
                          'Products to Return',
                          Icons.inventory,
                        ),
                        const SizedBox(height: 24),

                        // Add Product Button
                        Row(
                          children: [
                            ElevatedButton.icon(
                              onPressed: _addPurchaseReturnItem,
                              icon: Icon(Icons.add),
                              label: Text('Add Product'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF0D1845),
                                foregroundColor: Colors.white,
                                padding: EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${purchaseReturnItems.length} products added',
                                    style: TextStyle(
                                      color: Color(0xFF6C757D),
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  if (purchaseReturnItems.any(
                                    (item) =>
                                        item.productId == null ||
                                        item.quantity <= 0 ||
                                        item.purchasePrice <= 0,
                                  ))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4),
                                      child: Text(
                                        '⚠️ Some products are incomplete. Please fill in all required fields.',
                                        style: TextStyle(
                                          color: Color(0xFF856404),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Products Table
                        if (purchaseReturnItems.isNotEmpty) ...[
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                // Table Header
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF0D1845),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(12),
                                      topRight: Radius.circular(12),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.assignment_return,
                                        color: Colors.white,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Return Items',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Table Content
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: DataTable(
                                    headingRowColor: MaterialStateProperty.all(
                                      Color(0xFFF8F9FA),
                                    ),
                                    dataRowColor:
                                        MaterialStateProperty.resolveWith<
                                          Color
                                        >((Set<MaterialState> states) {
                                          if (states.contains(
                                            MaterialState.selected,
                                          )) {
                                            return Color(
                                              0xFF0D1845,
                                            ).withOpacity(0.1);
                                          }
                                          return Colors.white;
                                        }),
                                    columnSpacing: 24.0,
                                    dataRowMinHeight: 60.0,
                                    dataRowMaxHeight: 80.0,
                                    headingRowHeight: 50.0,
                                    columns: const [
                                      DataColumn(
                                        label: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8.0,
                                          ),
                                          child: Text(
                                            'Product',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8.0,
                                          ),
                                          child: Text(
                                            'Qty',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8.0,
                                          ),
                                          child: Text(
                                            'Purchase Price',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8.0,
                                          ),
                                          child: Text(
                                            'Discount (%)',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8.0,
                                          ),
                                          child: Text(
                                            'Discount Amount',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8.0,
                                          ),
                                          child: Text(
                                            'Unit Cost',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8.0,
                                          ),
                                          child: Text(
                                            'Total Cost',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                      DataColumn(
                                        label: Padding(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8.0,
                                          ),
                                          child: Text(
                                            'Actions',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                    rows: _getPaginatedItems().map((item) {
                                      int index = purchaseReturnItems.indexOf(
                                        item,
                                      );
                                      bool isIncomplete =
                                          item.productId == null ||
                                          item.quantity <= 0 ||
                                          item.purchasePrice <= 0;

                                      return DataRow(
                                        color:
                                            MaterialStateProperty.resolveWith<
                                              Color
                                            >((states) {
                                              if (isIncomplete) {
                                                return Color(
                                                  0xFFFFF3CD,
                                                ); // Light yellow for incomplete items
                                              }
                                              if (states.contains(
                                                MaterialState.selected,
                                              )) {
                                                return Color(
                                                  0xFF0D1845,
                                                ).withOpacity(0.1);
                                              }
                                              return Colors.white;
                                            }),
                                        cells: [
                                          DataCell(
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: SizedBox(
                                                width: 180,
                                                child: InkWell(
                                                  onTap:
                                                      _selectedVendorId == null
                                                      ? null
                                                      : () =>
                                                            _showProductSearchDialog(
                                                              index,
                                                            ),
                                                  child: Container(
                                                    padding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 10,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: isIncomplete
                                                          ? Color(0xFFFFF3CD)
                                                          : Colors.white,
                                                      border: Border.all(
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.inventory_2,
                                                          size: 16,
                                                          color: Color(
                                                            0xFF0D1845,
                                                          ),
                                                        ),
                                                        SizedBox(width: 8),
                                                        Expanded(
                                                          child: Text(
                                                            item.productId !=
                                                                    null
                                                                ? products
                                                                      .firstWhere(
                                                                        (p) =>
                                                                            p.id ==
                                                                            item.productId,
                                                                        orElse: () =>
                                                                            products.first,
                                                                      )
                                                                      .title
                                                                : _selectedVendorId ==
                                                                      null
                                                                ? 'Select vendor'
                                                                : 'Select product',
                                                            style: TextStyle(
                                                              fontSize: 12,
                                                              color:
                                                                  item.productId !=
                                                                      null
                                                                  ? Colors
                                                                        .black87
                                                                  : Colors
                                                                        .grey[600],
                                                            ),
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                        ),
                                                        Icon(
                                                          Icons.arrow_drop_down,
                                                          size: 18,
                                                          color: Colors
                                                              .grey
                                                              .shade600,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: SizedBox(
                                                width: 70,
                                                child: TextFormField(
                                                  controller:
                                                      quantityControllers[index],
                                                  decoration: InputDecoration(
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 8,
                                                        ),
                                                    filled: true,
                                                    fillColor: isIncomplete
                                                        ? Color(0xFFFFF3CD)
                                                        : Colors.white,
                                                  ),
                                                  keyboardType:
                                                      TextInputType.number,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                  onChanged: (value) {
                                                    int qty =
                                                        int.tryParse(value) ??
                                                        0;
                                                    if (item.productId !=
                                                        null) {
                                                      final product = products
                                                          .firstWhere(
                                                            (p) =>
                                                                p.id ==
                                                                item.productId,
                                                          );
                                                      final maxQty =
                                                          int.tryParse(
                                                            product
                                                                .inStockQuantity,
                                                          ) ??
                                                          0;
                                                      if (qty > maxQty) {
                                                        qty = maxQty;
                                                        quantityControllers[index]
                                                            .text = qty
                                                            .toString();
                                                        quantityControllers[index]
                                                                .selection =
                                                            TextSelection.fromPosition(
                                                              TextPosition(
                                                                offset:
                                                                    quantityControllers[index]
                                                                        .text
                                                                        .length,
                                                              ),
                                                            );
                                                        ScaffoldMessenger.of(
                                                          context,
                                                        ).showSnackBar(
                                                          SnackBar(
                                                            content: Text(
                                                              'Quantity cannot exceed available stock ($maxQty)',
                                                            ),
                                                            backgroundColor:
                                                                Colors.orange,
                                                          ),
                                                        );
                                                      }
                                                    }
                                                    PurchaseReturnItem
                                                    updatedItem = item.copyWith(
                                                      quantity: qty,
                                                    );
                                                    _updatePurchaseReturnItem(
                                                      index,
                                                      updatedItem,
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: SizedBox(
                                                width: 100,
                                                child: TextFormField(
                                                  controller:
                                                      purchasePriceControllers[index],
                                                  decoration: InputDecoration(
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 8,
                                                        ),
                                                    filled: true,
                                                    fillColor: isIncomplete
                                                        ? Color(0xFFFFF3CD)
                                                        : Colors.white,
                                                    hintText: '0',
                                                  ),
                                                  keyboardType:
                                                      TextInputType.numberWithOptions(
                                                        decimal: true,
                                                      ),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                  onChanged: (value) {
                                                    double price =
                                                        double.tryParse(
                                                          value,
                                                        ) ??
                                                        0;
                                                    PurchaseReturnItem
                                                    updatedItem = item.copyWith(
                                                      purchasePrice: price,
                                                    );
                                                    _updatePurchaseReturnItem(
                                                      index,
                                                      updatedItem,
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: SizedBox(
                                                width: 90,
                                                child: TextFormField(
                                                  initialValue:
                                                      item.discount == 0
                                                      ? ''
                                                      : (item.purchasePrice > 0
                                                            ? (item.discount /
                                                                      item.purchasePrice *
                                                                      100)
                                                                  .toStringAsFixed(
                                                                    2,
                                                                  )
                                                            : '0.00'),
                                                  decoration: InputDecoration(
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    contentPadding:
                                                        EdgeInsets.symmetric(
                                                          horizontal: 12,
                                                          vertical: 8,
                                                        ),
                                                    filled: true,
                                                    fillColor: isIncomplete
                                                        ? Color(0xFFFFF3CD)
                                                        : Colors.white,
                                                    hintText: '0.00',
                                                  ),
                                                  keyboardType:
                                                      TextInputType.numberWithOptions(
                                                        decimal: true,
                                                      ),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                  ),
                                                  onChanged: (value) {
                                                    double percentage =
                                                        double.tryParse(
                                                          value,
                                                        ) ??
                                                        0;
                                                    double discount =
                                                        (percentage / 100) *
                                                        item.purchasePrice;
                                                    PurchaseReturnItem
                                                    updatedItem = item.copyWith(
                                                      discount: discount,
                                                    );
                                                    _updatePurchaseReturnItem(
                                                      index,
                                                      updatedItem,
                                                    );
                                                  },
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: Container(
                                                width: 90,
                                                alignment: Alignment.center,
                                                child: Text(
                                                  'Rs. ${(item.discount * item.quantity).toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFFDC3545),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: Container(
                                                width: 90,
                                                alignment: Alignment.center,
                                                child: Text(
                                                  'Rs. ${item.unitCost.toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF28A745),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: Container(
                                                width: 100,
                                                alignment: Alignment.center,
                                                child: Text(
                                                  'Rs. ${(item.unitCost * item.quantity).toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    color: Color(0xFF343A40),
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Padding(
                                              padding: const EdgeInsets.all(
                                                8.0,
                                              ),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  if (isIncomplete)
                                                    Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Color(
                                                          0xFF856404,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              4,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        'Incomplete',
                                                        style: TextStyle(
                                                          color: Colors.white,
                                                          fontSize: 10,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  SizedBox(width: 8),
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.delete,
                                                      color: Color(0xFFDC3545),
                                                      size: 20,
                                                    ),
                                                    onPressed: () =>
                                                        _removePurchaseReturnItem(
                                                          index,
                                                        ),
                                                    tooltip: 'Remove Product',
                                                    style: IconButton.styleFrom(
                                                      backgroundColor: Color(
                                                        0xFFF8F9FA,
                                                      ),
                                                      padding: EdgeInsets.all(
                                                        8,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),

                                // Pagination
                                if (purchaseReturnItems.length > 10) ...[
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        IconButton(
                                          icon: Icon(Icons.chevron_left),
                                          onPressed: _currentPage > 0
                                              ? () => setState(
                                                  () => _currentPage--,
                                                )
                                              : null,
                                        ),
                                        Text(
                                          'Page ${_currentPage + 1} of ${_getTotalPages()}',
                                          style: TextStyle(
                                            color: Color(0xFF6C757D),
                                          ),
                                        ),
                                        IconButton(
                                          icon: Icon(Icons.chevron_right),
                                          onPressed:
                                              _currentPage <
                                                  _getTotalPages() - 1
                                              ? () => setState(
                                                  () => _currentPage++,
                                                )
                                              : null,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),
                        ],

                        if (purchaseReturnItems.isNotEmpty) ...[
                          const SizedBox(height: 32),
                        ],

                        // Invoice Summary
                        if (purchaseReturnItems.isNotEmpty &&
                            _selectedVendorId != null) ...[
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Order Details (Left Side)
                              Expanded(
                                flex: 1,
                                child: Container(
                                  padding: const EdgeInsets.all(20),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Header
                                      Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Color(
                                                0xFF0D1845,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: const Icon(
                                              Icons.settings,
                                              color: Color(0xFF0D1845),
                                              size: 20,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Text(
                                            'Order Details',
                                            style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF343A40),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),

                                      // Discount
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 4,
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              'Discount %',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          TextFormField(
                                            controller:
                                                _orderDiscountController,
                                            decoration: InputDecoration(
                                              hintText: '0',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                            ),
                                            keyboardType:
                                                TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            style: TextStyle(fontSize: 12),
                                            validator: (value) {
                                              if (value != null &&
                                                  value.isNotEmpty) {
                                                double? discount =
                                                    double.tryParse(value);
                                                if (discount == null) {
                                                  return 'Please enter a valid number';
                                                }
                                                if (discount < 0 ||
                                                    discount > 100) {
                                                  return 'Discount must be between 0 and 100';
                                                }
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 12),

                                      // Notes
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 4,
                                              bottom: 4,
                                            ),
                                            child: Text(
                                              'Return Reason',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                          TextFormField(
                                            controller: _notesController,
                                            decoration: InputDecoration(
                                              hintText: 'Enter return reason',
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              contentPadding:
                                                  EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                              hintStyle: TextStyle(
                                                fontSize: 11,
                                              ),
                                            ),
                                            style: TextStyle(fontSize: 12),
                                            maxLines: 2,
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),

                              // Invoice Summary (Right Side)
                              Expanded(flex: 1, child: _buildInvoiceSummary()),
                            ],
                          ),
                          const SizedBox(height: 32),
                        ],

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: isSubmitting ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF28A745),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: isSubmitting
                                ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text('Create Purchase Return'),
                          ),
                        ),
                      ],
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

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Color(0xFF0D1845), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF343A40),
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceSummary() {
    double subtotal = _calculateSubtotal();
    double orderDiscountPercent =
        double.tryParse(_orderDiscountController.text) ?? 0;

    double orderDiscountAmount = subtotal >= 0
        ? subtotal * (orderDiscountPercent / 100)
        : 0;
    double grandTotal = _calculateGrandTotal();

    return Container(
      padding: const EdgeInsets.all(20),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF0D1845).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.assignment_return,
                  color: Color(0xFF0D1845),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Purchase Return Invoice Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF343A40),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Summary Items
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Subtotal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal (${purchaseReturnItems.length} items)',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6C757D)),
                    ),
                    Text(
                      'Rs. ${subtotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF343A40),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Order Discount
                if (orderDiscountPercent > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order Discount (${orderDiscountPercent.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFDC3545),
                        ),
                      ),
                      Text(
                        '- Rs. ${orderDiscountAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFDC3545),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Divider
                Divider(color: Color(0xFFE9ECEF), thickness: 1),

                // Grand Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Grand Total',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF343A40),
                      ),
                    ),
                    Text(
                      'Rs. ${grandTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D1845),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PurchaseReturnItem {
  int? productId;
  int quantity;
  double purchasePrice;
  double discount;
  double taxPercentage;
  double pendingPayment;
  String description;

  PurchaseReturnItem({
    this.productId,
    this.quantity = 1,
    this.purchasePrice = 0,
    this.discount = 0,
    this.taxPercentage = 0,
    this.pendingPayment = 0,
    this.description = '',
  });

  double get taxAmount {
    double priceAfterDiscount = purchasePrice - discount;
    return priceAfterDiscount * (taxPercentage / 100);
  }

  double get unitCost {
    double priceAfterDiscount = purchasePrice - discount;
    return priceAfterDiscount + taxAmount;
  }

  double get totalCost {
    return unitCost * quantity;
  }

  String get productName {
    // This will be set when product is selected from dropdown
    return description.isNotEmpty ? description : 'Select Product';
  }

  PurchaseReturnItem copyWith({
    int? productId,
    int? quantity,
    double? purchasePrice,
    double? discount,
    double? taxPercentage,
    double? pendingPayment,
    String? description,
  }) {
    return PurchaseReturnItem(
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      discount: discount ?? this.discount,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      pendingPayment: pendingPayment ?? this.pendingPayment,
      description: description ?? this.description,
    );
  }
}
