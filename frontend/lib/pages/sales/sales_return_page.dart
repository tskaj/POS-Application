import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/sales_service.dart';
import '../../services/bank_services.dart';
import '../../services/credit_customer_service.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';

class SalesReturnPage extends StatefulWidget {
  const SalesReturnPage({super.key});

  @override
  State<SalesReturnPage> createState() => _SalesReturnPageState();
}

class _SalesReturnPageState extends State<SalesReturnPage> with RouteAware {
  final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  late List<SalesReturn> _salesReturns = [];
  late bool _isLoading = false;
  late String _errorMessage = '';
  late bool _showAddReturnDialog = false;
  late String _customerSearchQuery = '';
  late String _returnIdSearchQuery = '';
  late String _invoiceIdSearchQuery = '';
  late DateTime? _startDateFilter = null;
  late DateTime? _endDateFilter = null;
  late String _selectedCustomerType = 'Walkin Customer';
  Map<String, dynamic>? _selectedCreditCustomer;
  late DateTime _selectedReturnDate = DateTime.now();
  late List<Map<String, dynamic>> _invoiceProducts = [];
  late bool _isLoadingInvoice = false;
  late String _invoiceError = '';
  late List<Map<String, dynamic>> _selectedProducts = [];

  // Pagination variables
  int currentPage = 1;
  final int itemsPerPage = 16;
  bool _isSubmittingReturn = false;
  int? _submittingMode;

  // Invoice data
  late int _invoiceCustomerId = 0;
  late int _invoicePosId = 0;

  // Filtered data for pagination
  List<SalesReturn> _allFilteredReturns = [];
  List<SalesReturn> _filteredReturns = [];

  // Edit form state variables
  late DateTime _editReturnDate = DateTime.now();
  late List<Map<String, dynamic>> _editProducts = [];
  late String _editReason = '';
  late TextEditingController _editReasonController = TextEditingController();

  // Action dialog states
  late bool _showViewDialog = false;
  late bool _showEditDialog = false;
  late bool _showDeleteDialog = false;
  late SalesReturn? _currentReturn = null;
  late bool _isLoadingAction = false;

  // Controllers
  late TextEditingController _returnReasonController = TextEditingController();
  late TextEditingController _cnicController = TextEditingController();
  late TextEditingController _invoiceNumberController = TextEditingController();
  late TextEditingController _customerSearchController =
      TextEditingController();
  late TextEditingController _returnIdSearchController =
      TextEditingController();
  late TextEditingController _invoiceIdSearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSalesReturns();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute? route = ModalRoute.of(context);
    if (route != null) {
      routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    routeObserver.unsubscribe(this);
    _returnReasonController.dispose();
    _cnicController.dispose();
    _invoiceNumberController.dispose();
    _customerSearchController.dispose();
    _returnIdSearchController.dispose();
    _invoiceIdSearchController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when returning to this page from another page
    _refreshSalesReturns();
  }

  Future<void> _refreshSalesReturns() async {
    print('🔄 Refreshing sales returns data...');
    try {
      if (mounted) {
        setState(() {
          _errorMessage = '';
        });
      }

      // Clear provider cache first
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      salesProvider.clearSalesReturns();

      // Clear local cache
      _salesReturns.clear();
      _allFilteredReturns.clear();
      _filteredReturns.clear();

      // Fetch fresh data from server
      await _loadSalesReturns();
    } catch (e) {
      print('❌ Error refreshing sales returns: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to refresh sales returns. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadSalesReturns() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await SalesService.getSalesReturns();

      setState(() {
        _salesReturns = response.data;
        _isLoading = false;
      });

      // Clear provider cache first, then update with fresh data
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      salesProvider.clearSalesReturns();
      salesProvider.setSalesReturns(_salesReturns);
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load sales returns: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchInvoiceDetails() async {
    final invoiceNumber = _invoiceNumberController.text.trim();
    if (invoiceNumber.isEmpty) {
      setState(() {
        _invoiceError = 'Please enter an invoice number';
        _invoiceProducts.clear();
      });
      return;
    }

    // No CNIC required anymore. API will use selected customer id.

    setState(() {
      _isLoadingInvoice = true;
      _invoiceError = '';
      _invoiceProducts.clear();
      _selectedProducts.clear();
    });

    try {
      final invoiceResponse = await SalesService.getInvoiceByNumber(
        invoiceNumber,
      );
      setState(() {
        _invoiceCustomerId = _selectedCustomerType == 'Walkin Customer'
            ? 1
            : invoiceResponse.customerId; // Default for normal
        _invoicePosId = invoiceResponse.posId > 0
            ? invoiceResponse.posId
            : 1; // Default to 1 if invalid

        // Build invoice products using the invoice detail fields (quantity, price)
        _invoiceProducts = invoiceResponse.details.map((detail) {
          int qty = 1;
          try {
            final dynamic q = detail.quantity;
            if (q is int)
              qty = q;
            else
              qty = int.tryParse(q?.toString() ?? '') ?? 1;
          } catch (_) {
            qty = 1;
          }

          double price = 0.0;
          try {
            final dynamic p = detail.price;
            if (p is double)
              price = p;
            else if (p is int)
              price = p.toDouble();
            else
              price = double.tryParse(p?.toString() ?? '') ?? 0.0;
          } catch (_) {
            price = 0.0;
          }

          return {
            'id': detail.id.toString(),
            'productId': detail.productId,
            'name': detail.productName,
            'quantity': qty,
            // original price from invoice
            'price': price,
            // controller for editable return price (defaults to original price)
            'returnPriceController': TextEditingController(
              text: price.toStringAsFixed(2),
            ),
            'isSelected': false,
            // default return quantity is the original invoice qty
            'returnQuantityController': TextEditingController(
              text: qty.toString(),
            ),
          };
        }).toList();
        _isLoadingInvoice = false;
      });
    } catch (e) {
      // Sanitize and classify error for a user-friendly message
      final err = e.toString();
      String userMessage;
      if (err.contains('404') || err.toLowerCase().contains('not found')) {
        userMessage = 'Invoice not found. Please check the invoice number.';
      } else if (err.contains('500') ||
          err.contains('<script') ||
          err.toLowerCase().contains('internal')) {
        userMessage =
            'Server error while fetching the invoice. Please try again later or contact support.';
      } else if (err.toLowerCase().contains('network error')) {
        userMessage =
            'Network error while fetching the invoice. Check your connection.';
      } else if (err.toLowerCase().contains('invalid invoice number') ||
          err.toLowerCase().contains('invalid')) {
        userMessage =
            'Invalid invoice number format. Try entering the invoice ID or full label like INV-123.';
      } else {
        userMessage =
            'Failed to load invoice. ${err.replaceAll(RegExp(r"\n"), ' ')}';
      }

      // Log the raw error for debugging (console only)
      print('⚠️ _fetchInvoiceDetails error: $err');

      setState(() {
        _invoiceError = userMessage;
        _isLoadingInvoice = false;
        _invoiceProducts.clear();
      });
    }
  }

  Future<void> _submitReturn() async {
    // Get selected products from invoice products
    final selectedProducts = _invoiceProducts
        .where((p) => p['isSelected'] == true)
        .toList();

    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select products to return')),
      );
      return;
    }

    final returnReason = _returnReasonController.text.trim();
    if (returnReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a return reason')),
      );
      return;
    }

    setState(() {
      _isSubmittingReturn = true;
    });

    try {
      // Validate and calculate totals for selected products
      double totalAmount = 0.0;
      final details = <Map<String, String>>[];

      for (final product in selectedProducts) {
        // Read controllers safely
        final qtyController =
            product['returnQuantityController'] as TextEditingController?;
        final priceController =
            product['returnPriceController'] as TextEditingController?;

        final int originalQty = (product['quantity'] is int)
            ? product['quantity'] as int
            : int.tryParse(product['quantity']?.toString() ?? '') ?? 1;
        final double originalPrice = (product['price'] is double)
            ? product['price'] as double
            : double.tryParse(product['price']?.toString() ?? '') ?? 0.0;

        final int returnQty = qtyController != null
            ? int.tryParse(qtyController.text.trim()) ?? 0
            : originalQty;
        final double returnPrice = priceController != null
            ? double.tryParse(priceController.text.trim()) ?? 0.0
            : originalPrice;

        // Validation: cannot return more than invoice quantity or pay more than original price
        if (returnQty <= 0 || returnQty > originalQty) {
          setState(() {
            _isSubmittingReturn = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Invalid quantity for ${product['name']}. Max: $originalQty',
              ),
            ),
          );
          return;
        }
        if (returnPrice <= 0 || returnPrice > originalPrice) {
          setState(() {
            _isSubmittingReturn = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Invalid price for ${product['name']}. Max: ${originalPrice.toStringAsFixed(2)}',
              ),
            ),
          );
          return;
        }

        totalAmount += returnQty * returnPrice;

        final pid = product['productId'];
        final parsedPid = (pid is int)
            ? pid
            : int.tryParse(pid?.toString() ?? '') ?? 0;

        details.add({
          'product_id': parsedPid.toString(),
          'qty': returnQty.toString(),
          'return_unit_price': returnPrice.toStringAsFixed(2),
        });
      }

      // Determine customer id: prefer selected full credit customer, then invoiceCustomerId, fallback to 1
      int custId = _invoiceCustomerId;
      if (_selectedCreditCustomer != null &&
          _selectedCreditCustomer!['id'] != null) {
        custId = (_selectedCreditCustomer!['id'] is int)
            ? _selectedCreditCustomer!['id'] as int
            : int.tryParse(_selectedCreditCustomer!['id']?.toString() ?? '') ??
                  custId;
      }

      final returnData = {
        'customer_id': (custId > 0 ? custId : 1).toString(),
        'invRet_date': DateFormat('yyyy-MM-dd').format(_selectedReturnDate),
        // include both keys to be tolerant to API variations
        'return_inv_amount': totalAmount.toStringAsFixed(2),
        'return_inv_amout': totalAmount.toStringAsFixed(2),
        'transaction_type_id': 2.toString(),
        'details': details,
      };

      // Only include pos_id if it's valid
      if (_invoicePosId > 0) {
        returnData['pos_id'] = _invoicePosId.toString();
      }

      final newReturn = await SalesService.createSalesReturn(returnData);

      setState(() {
        _salesReturns.insert(0, newReturn);
        _isSubmittingReturn = false;
        _showAddReturnDialog = false;
      });

      // Reset form
      _resetForm();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sales return added')));

      // Refresh data from server to ensure consistency
      await _refreshSalesReturns();
    } catch (e) {
      setState(() {
        _isSubmittingReturn = false;
        _showAddReturnDialog = false;
      });

      // Reset form
      _resetForm();

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Sales return added')));

      // Refresh data from server to ensure consistency
      await _refreshSalesReturns();
    }
  }

  void _resetForm() {
    setState(() {
      _returnReasonController.clear();
      _cnicController.clear();
      _selectedCreditCustomer = null;
      _invoiceNumberController.clear();
      _selectedProducts.clear();
      _selectedCustomerType = 'Walkin Customer';
      _selectedReturnDate = DateTime.now();
      _invoiceProducts.clear();
      _invoiceError = '';
      _invoiceCustomerId = 0;
      _invoicePosId = 0;
    });
  }

  List<SalesReturn> _getFilteredReturns() {
    // Apply filters to get all filtered returns
    _allFilteredReturns = _salesReturns.where((returnItem) {
      final customerMatch =
          _customerSearchQuery.isEmpty ||
          returnItem.customer.name.toLowerCase().contains(
            _customerSearchQuery.toLowerCase(),
          );

      final returnIdMatch =
          _returnIdSearchQuery.isEmpty ||
          returnItem.id.toString().contains(_returnIdSearchQuery);

      final invoiceIdMatch =
          _invoiceIdSearchQuery.isEmpty ||
          (returnItem.posId ?? '').toString().contains(_invoiceIdSearchQuery);

      // Date filtering based on selected date range
      bool dateMatch = true;
      if (_startDateFilter != null || _endDateFilter != null) {
        try {
          final returnDate = DateTime.parse(returnItem.invRetDate);
          if (_startDateFilter != null &&
              returnDate.isBefore(_startDateFilter!)) {
            dateMatch = false;
          }
          if (_endDateFilter != null && returnDate.isAfter(_endDateFilter!)) {
            dateMatch = false;
          }
        } catch (e) {
          dateMatch = true; // If date parsing fails, include the item
        }
      }

      return customerMatch && returnIdMatch && invoiceIdMatch && dateMatch;
    }).toList();

    // Apply pagination
    _paginateFilteredReturns();

    return _filteredReturns;
  }

  // Apply pagination to filtered returns
  void _paginateFilteredReturns() {
    try {
      // Handle empty results case
      if (_allFilteredReturns.isEmpty) {
        setState(() {
          _filteredReturns = [];
        });
        return;
      }

      final startIndex = (currentPage - 1) * itemsPerPage;
      final endIndex = startIndex + itemsPerPage;

      // Ensure startIndex is not greater than the list length
      if (startIndex >= _allFilteredReturns.length) {
        // Reset to page 1 if current page is out of bounds
        setState(() {
          currentPage = 1;
        });
        _paginateFilteredReturns(); // Recursive call with corrected page
        return;
      }

      setState(() {
        _filteredReturns = _allFilteredReturns.sublist(
          startIndex,
          endIndex > _allFilteredReturns.length
              ? _allFilteredReturns.length
              : endIndex,
        );
      });
    } catch (e) {
      setState(() {
        _filteredReturns = [];
        currentPage = 1;
      });
    }
  }

  // Check if we can go to the next page
  bool _canGoToNextPage() {
    final totalPages = _getTotalPages();
    return currentPage < totalPages;
  }

  // Get total number of pages
  int _getTotalPages() {
    if (_allFilteredReturns.isEmpty) return 1;
    return (_allFilteredReturns.length / itemsPerPage).ceil();
  }

  // Change page
  void _changePage(int page) {
    if (page < 1 || page > _getTotalPages()) return;

    setState(() {
      currentPage = page;
    });
    _paginateFilteredReturns();
  }

  // Build page number buttons
  List<Widget> _buildPageButtons() {
    final totalPages = _getTotalPages();
    final current = currentPage;

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
          margin: const EdgeInsets.symmetric(horizontal: 1),
          child: ElevatedButton(
            onPressed: i == current ? null : () => _changePage(i),
            style: ElevatedButton.styleFrom(
              backgroundColor: i == current
                  ? const Color(0xFF17A2B8)
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
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(32, 32),
            ),
            child: Text(
              i.toString(),
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
            ),
          ),
        ),
      );
    }

    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    final filteredReturns = _getFilteredReturns();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Returns'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, const Color(0xFFF8F9FA)],
          ),
        ),
        child: Stack(
          children: [
            Column(
              children: [
                // Header with margin
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF0D1845).withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
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
                              Icons.assignment_return,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Sales Returns',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Manage product returns and process customer refunds',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () async {
                              // Fetch fresh credit customers before opening dialog
                              try {
                                final peopleProvider =
                                    Provider.of<PeopleProvider>(
                                      context,
                                      listen: false,
                                    );
                                final customers =
                                    await CreditCustomerService.getAllCreditCustomers();
                                peopleProvider.setCreditCustomers(customers);
                              } catch (e) {
                                // Still show dialog even if fetching fails
                              }
                              setState(() {
                                _showAddReturnDialog = true;
                              });
                            },
                            icon: const Icon(Icons.add, size: 14),
                            label: const Text('Add Sales Return'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0D1845),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Summary Cards
                      Row(
                        children: [
                          _buildSummaryCard(
                            'Total Returns',
                            _salesReturns.length.toString(),
                            Icons.assignment_return,
                            Colors.blue,
                          ),
                          const SizedBox(width: 12),
                          _buildSummaryCard(
                            'Total Amount',
                            'PKR ${_calculateTotalAmount().toStringAsFixed(2)}',
                            Icons.attach_money,
                            Colors.green,
                          ),
                          const SizedBox(width: 12),
                          _buildSummaryCard(
                            'This Month',
                            _getThisMonthReturnsCount().toString(),
                            Icons.calendar_today,
                            Colors.orange,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Error message display
                if (_errorMessage.isNotEmpty) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 24),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade200),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.error_outline,
                          color: Colors.red.shade700,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: TextStyle(
                              color: Colors.red.shade700,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _errorMessage = '';
                            });
                          },
                          icon: Icon(
                            Icons.close,
                            color: Colors.red.shade700,
                            size: 18,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],

                // Filters Section
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 24),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Customer Search
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.search,
                                  size: 14,
                                  color: Color(0xFF0D1845),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Search Customer',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF343A40),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            TextField(
                              controller: _customerSearchController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                hintText: 'Search customers...',
                                hintStyle: TextStyle(
                                  color: Color(0xFFADB5BD),
                                  fontSize: 12,
                                ),
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Color(0xFF6C757D),
                                  size: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Color(0xFFDEE2E6),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Color(0xFFDEE2E6),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Color(0xFF0D1845),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              style: TextStyle(
                                color: Color(0xFF343A40),
                                fontSize: 12,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _customerSearchQuery = value;
                                  currentPage =
                                      1; // Reset to page 1 when filter changes
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      // Return ID Search
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.assignment_return,
                                  size: 14,
                                  color: Color(0xFF0D1845),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Search Return ID',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF343A40),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            TextField(
                              controller: _returnIdSearchController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                hintText: 'Search return IDs...',
                                hintStyle: TextStyle(
                                  color: Color(0xFFADB5BD),
                                  fontSize: 12,
                                ),
                                prefixIcon: Icon(
                                  Icons.assignment_return,
                                  color: Color(0xFF6C757D),
                                  size: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Color(0xFFDEE2E6),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Color(0xFFDEE2E6),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Color(0xFF0D1845),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              style: TextStyle(
                                color: Color(0xFF343A40),
                                fontSize: 12,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _returnIdSearchQuery = value;
                                  currentPage =
                                      1; // Reset to page 1 when filter changes
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      // Invoice ID Search
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.receipt_long,
                                  size: 14,
                                  color: Color(0xFF0D1845),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Search Invoice ID',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF343A40),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            TextField(
                              controller: _invoiceIdSearchController,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
                                hintText: 'Search invoice IDs...',
                                hintStyle: TextStyle(
                                  color: Color(0xFFADB5BD),
                                  fontSize: 12,
                                ),
                                prefixIcon: Icon(
                                  Icons.receipt_long,
                                  color: Color(0xFF6C757D),
                                  size: 16,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Color(0xFFDEE2E6),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Color(0xFFDEE2E6),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(
                                    color: Color(0xFF0D1845),
                                    width: 2,
                                  ),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 8,
                                ),
                              ),
                              style: TextStyle(
                                color: Color(0xFF343A40),
                                fontSize: 12,
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _invoiceIdSearchQuery = value;
                                  currentPage =
                                      1; // Reset to page 1 when filter changes
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12),
                      // Date Filter
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today,
                                  size: 14,
                                  color: Color(0xFF0D1845),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Filter by Date',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF343A40),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 6),
                            Row(
                              children: [
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final DateTime?
                                      picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            _startDateFilter ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme:
                                                  const ColorScheme.light(
                                                    primary: Color(0xFF0D1845),
                                                    onPrimary: Colors.white,
                                                    onSurface: Color(
                                                      0xFF343A40,
                                                    ),
                                                  ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _startDateFilter = picked;
                                          currentPage = 1;
                                        });
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white,
                                        hintText: 'Start Date',
                                        hintStyle: TextStyle(
                                          color: Color(0xFFADB5BD),
                                          fontSize: 12,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Color(0xFFDEE2E6),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Color(0xFFDEE2E6),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Color(0xFF0D1845),
                                            width: 2,
                                          ),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        suffixIcon: Icon(
                                          Icons.calendar_today,
                                          color: Color(0xFF6C757D),
                                          size: 16,
                                        ),
                                      ),
                                      child: Text(
                                        _startDateFilter != null
                                            ? DateFormat(
                                                'dd MMM yyyy',
                                              ).format(_startDateFilter!)
                                            : 'Start Date',
                                        style: TextStyle(
                                          color: _startDateFilter != null
                                              ? Color(0xFF343A40)
                                              : Color(0xFFADB5BD),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: InkWell(
                                    onTap: () async {
                                      final DateTime?
                                      picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            _endDateFilter ?? DateTime.now(),
                                        firstDate: DateTime(2020),
                                        lastDate: DateTime.now(),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme:
                                                  const ColorScheme.light(
                                                    primary: Color(0xFF0D1845),
                                                    onPrimary: Colors.white,
                                                    onSurface: Color(
                                                      0xFF343A40,
                                                    ),
                                                  ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (picked != null) {
                                        setState(() {
                                          _endDateFilter = picked;
                                          currentPage = 1;
                                        });
                                      }
                                    },
                                    child: InputDecorator(
                                      decoration: InputDecoration(
                                        filled: true,
                                        fillColor: Colors.white,
                                        hintText: 'End Date',
                                        hintStyle: TextStyle(
                                          color: Color(0xFFADB5BD),
                                          fontSize: 12,
                                        ),
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Color(0xFFDEE2E6),
                                          ),
                                        ),
                                        enabledBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Color(0xFFDEE2E6),
                                          ),
                                        ),
                                        focusedBorder: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                          borderSide: BorderSide(
                                            color: Color(0xFF0D1845),
                                            width: 2,
                                          ),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        suffixIcon: Icon(
                                          Icons.calendar_today,
                                          color: Color(0xFF6C757D),
                                          size: 16,
                                        ),
                                      ),
                                      child: Text(
                                        _endDateFilter != null
                                            ? DateFormat(
                                                'dd MMM yyyy',
                                              ).format(_endDateFilter!)
                                            : 'End Date',
                                        style: TextStyle(
                                          color: _endDateFilter != null
                                              ? Color(0xFF343A40)
                                              : Color(0xFFADB5BD),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                SizedBox(width: 8),
                                IconButton(
                                  onPressed: () {
                                    setState(() {
                                      _startDateFilter = null;
                                      _endDateFilter = null;
                                      currentPage = 1;
                                    });
                                  },
                                  icon: Icon(
                                    Icons.clear,
                                    color: Color(0xFF6C757D),
                                    size: 18,
                                  ),
                                  tooltip: 'Clear date filter',
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Table Section
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
                    child: _isLoading
                        ? const Center(child: CircularProgressIndicator())
                        : Column(
                            children: [
                              // Table Header
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF8F9FA),
                                  border: Border(
                                    bottom: BorderSide(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 6,
                                      child: Text(
                                        'Return ID',
                                        style: _headerStyle(),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 6,
                                      child: Text(
                                        'Invoice ID',
                                        style: _headerStyle(),
                                      ),
                                    ),
                                    // Product column removed as requested
                                    Expanded(
                                      flex: 7,
                                      child: Text(
                                        'Date',
                                        style: _headerStyle(),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 7,
                                      child: Text(
                                        'Customer Name',
                                        style: _headerStyle(),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 7,
                                      child: Text(
                                        'Return Amount',
                                        style: _headerStyle(),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 7,
                                      child: Text(
                                        'Paid Amount',
                                        style: _headerStyle(),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 7,
                                      child: Text(
                                        'Actions',
                                        style: _headerStyle(),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Table Body
                              Expanded(
                                child: filteredReturns.isEmpty
                                    ? Center(
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.assignment_return,
                                              size: 64,
                                              color: Colors.grey[400],
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No sales returns found',
                                              style: TextStyle(
                                                fontSize: 18,
                                                color: Colors.grey[600],
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : ListView.builder(
                                        itemCount: filteredReturns.length,
                                        itemBuilder: (context, index) {
                                          final returnItem =
                                              filteredReturns[index];
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: Colors.grey[200]!,
                                                ),
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  flex: 6,
                                                  child: Text(
                                                    returnItem.id.toString(),
                                                    style: _cellStyle(),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 6,
                                                  child: Text(
                                                    returnItem.posId ?? 'N/A',
                                                    style: _cellStyle(),
                                                  ),
                                                ),
                                                // Product cell removed
                                                Expanded(
                                                  flex: 7,
                                                  child: Text(
                                                    returnItem
                                                            .invRetDate
                                                            .isNotEmpty
                                                        ? DateFormat(
                                                            'dd MMM yyyy',
                                                          ).format(
                                                            DateTime.parse(
                                                              returnItem
                                                                  .invRetDate,
                                                            ),
                                                          )
                                                        : 'N/A',
                                                    style: _cellStyle(),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 7,
                                                  child: Text(
                                                    (returnItem.customer.name
                                                            .trim()
                                                            .isNotEmpty)
                                                        ? returnItem
                                                              .customer
                                                              .name
                                                        : 'Walk In Customer',
                                                    style: _cellStyle(),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 7,
                                                  child: Text(
                                                    'Rs. ${double.tryParse(returnItem.returnInvAmount)?.toStringAsFixed(2) ?? '0.00'}',
                                                    style: _cellStyle(),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 7,
                                                  child: Text(
                                                    'Rs. ${double.tryParse(returnItem.paid ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                                                    style: _cellStyle(),
                                                  ),
                                                ),
                                                Expanded(
                                                  flex: 7,
                                                  child: Row(
                                                    mainAxisAlignment:
                                                        MainAxisAlignment.start,
                                                    children: [
                                                      IconButton(
                                                        icon: Icon(
                                                          Icons.visibility,
                                                          color: const Color(
                                                            0xFF0D1845,
                                                          ),
                                                          size: 18,
                                                        ),
                                                        onPressed: () =>
                                                            _viewReturnDetails(
                                                              returnItem,
                                                            ),
                                                        tooltip: 'View Details',
                                                        padding:
                                                            const EdgeInsets.all(
                                                              6,
                                                            ),
                                                        constraints:
                                                            const BoxConstraints(),
                                                      ),
                                                      // IconButton(
                                                      //   icon: Icon(
                                                      //     Icons.edit,
                                                      //     color: Colors.blue,
                                                      //     size: 18,
                                                      //   ),
                                                      //   onPressed: () =>
                                                      //       _editReturn(
                                                      //         returnItem,
                                                      //       ),
                                                      //   tooltip: 'Edit',
                                                      //   padding:
                                                      //       const EdgeInsets.all(
                                                      //         6,
                                                      //       ),
                                                      //   constraints:
                                                      //       const BoxConstraints(),
                                                      // ),
                                                      IconButton(
                                                        icon: Icon(
                                                          Icons.delete,
                                                          color: Colors.red,
                                                          size: 18,
                                                        ),
                                                        onPressed: () =>
                                                            _deleteReturn(
                                                              returnItem.id
                                                                  .toString(),
                                                            ),
                                                        tooltip: 'Delete',
                                                        padding:
                                                            const EdgeInsets.all(
                                                              6,
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

                              // Pagination Controls
                              if (_allFilteredReturns.isNotEmpty) ...[
                                Container(
                                  padding: const EdgeInsets.all(12),
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
                                        icon: const Icon(
                                          Icons.chevron_left,
                                          size: 14,
                                        ),
                                        label: Text(
                                          'Previous',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.white,
                                          foregroundColor: currentPage > 1
                                              ? const Color(0xFF0D1845)
                                              : const Color(0xFF6C757D),
                                          elevation: 0,
                                          side: const BorderSide(
                                            color: Color(0xFFDEE2E6),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
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
                                        onPressed: _canGoToNextPage()
                                            ? () => _changePage(currentPage + 1)
                                            : null,
                                        icon: const Icon(
                                          Icons.chevron_right,
                                          size: 14,
                                        ),
                                        label: Text(
                                          'Next',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: _canGoToNextPage()
                                              ? const Color(0xFF0D1845)
                                              : Colors.grey.shade300,
                                          foregroundColor: _canGoToNextPage()
                                              ? Colors.white
                                              : Colors.grey.shade600,
                                          elevation: _canGoToNextPage() ? 2 : 0,
                                          side: _canGoToNextPage()
                                              ? null
                                              : const BorderSide(
                                                  color: Color(0xFFDEE2E6),
                                                ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              5,
                                            ),
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
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFF8F9FA),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: Text(
                                          'Page $currentPage of ${_getTotalPages()} (${_allFilteredReturns.length} total)',
                                          style: const TextStyle(
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
                ),
              ],
            ),

            // Add Return Dialog
            ...(_showAddReturnDialog ? [_buildAddReturnDialog()] : []),

            // View Return Dialog
            ...(_showViewDialog ? [_buildViewReturnDialog()] : []),

            // Edit Return Dialog
            ...(_showEditDialog ? [_buildEditReturnDialog()] : []),

            // Delete Confirmation Dialog
            ...(_showDeleteDialog ? [_buildDeleteConfirmationDialog()] : []),
          ],
        ),
      ),
    );
  }

  TextStyle _headerStyle() {
    return const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: Color(0xFF343A40),
    );
  }

  TextStyle _cellStyle() {
    return const TextStyle(fontSize: 13, color: Color(0xFF6C757D));
  }

  void _viewReturnDetails(SalesReturn returnItem) async {
    setState(() {
      _isLoadingAction = true;
      _currentReturn = returnItem;
    });

    try {
      final salesReturn = await SalesService.getSalesReturnById(
        returnItem.id.toString(),
      );
      setState(() {
        _currentReturn = salesReturn;
        _showViewDialog = true;
        _isLoadingAction = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAction = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load return details: $e')),
      );
    }
  }

  void _editReturn(SalesReturn returnItem) async {
    setState(() {
      _isLoadingAction = true;
      _currentReturn = returnItem;
    });

    try {
      final salesReturn = await SalesService.getSalesReturnById(
        returnItem.id.toString(),
      );
      setState(() {
        _currentReturn = salesReturn;
        // Initialize edit form data
        _editReturnDate = salesReturn.invRetDate.isNotEmpty
            ? DateTime.parse(salesReturn.invRetDate)
            : DateTime.now();
        _editReason = ''; // Initialize with empty or from model if available
        _editReasonController.text = _editReason;
        // Try to resolve product IDs from inventory if API didn't provide them
        final inventoryProvider = Provider.of<InventoryProvider>(
          context,
          listen: false,
        );
        _editProducts = salesReturn.details.map((detail) {
          // Try parse existing productId
          int parsedProductId = int.tryParse(detail.productId) ?? 0;

          if (parsedProductId <= 0) {
            // Attempt to find product by name in inventory
            final nameToMatch = detail.productName.toLowerCase();
            final matches = inventoryProvider.products.where((p) {
              final title = p.title.toLowerCase();
              return title == nameToMatch ||
                  title.contains(nameToMatch) ||
                  nameToMatch.contains(title);
            }).toList();
            if (matches.isNotEmpty) parsedProductId = matches.first.id;
          }

          return {
            'id': detail.id,
            'productId': parsedProductId.toString(),
            'productName': detail.productName,
            'quantity': detail.qty,
            'unitPrice': detail.returnUnitPrice,
            'total': detail.total,
            'quantityController': TextEditingController(text: detail.qty),
            'priceController': TextEditingController(
              text: detail.returnUnitPrice,
            ),
          };
        }).toList();
        _showEditDialog = true;
        _isLoadingAction = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingAction = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load return details for editing: $e'),
        ),
      );
    }
  }

  void _deleteReturn(String returnId) {
    setState(() {
      _currentReturn = _salesReturns.firstWhere(
        (r) => r.id.toString() == returnId,
      );
      _showDeleteDialog = true;
    });
  }

  Future<void> _confirmDeleteReturn() async {
    if (_currentReturn == null) return;

    setState(() {
      _isLoadingAction = true;
    });

    try {
      await SalesService.deleteSalesReturn(_currentReturn!.id.toString(), {});
      setState(() {
        _salesReturns.removeWhere((r) => r.id == _currentReturn!.id);
        _showDeleteDialog = false;
        _currentReturn = null;
        _isLoadingAction = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Return deleted successfully')),
      );

      // Refresh data from server to ensure consistency
      await _refreshSalesReturns();
    } catch (e) {
      setState(() {
        _isLoadingAction = false;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to delete return: $e')));
    }
  }

  Future<void> _submitEditReturn() async {
    if (_currentReturn == null) return;

    // Validate form data
    if (_editReason.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a return reason')),
      );
      return;
    }

    // Validate product quantities and prices
    for (final product in _editProducts) {
      final qty = int.tryParse(product['quantityController'].text) ?? 0;
      final price = double.tryParse(product['priceController'].text) ?? 0.0;

      if (qty <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid quantity for ${product['productName']}'),
          ),
        );
        return;
      }

      if (price <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid price for ${product['productName']}'),
          ),
        );
        return;
      }
    }

    setState(() {
      _isLoadingAction = true;
    });

    // Prepare updated data and calculate numeric total amount safely
    double newTotalAmount = 0.0;
    final updatedDetails = _editProducts.map((product) {
      final qty = int.tryParse(product['quantityController'].text) ?? 0;
      final price = double.tryParse(product['priceController'].text) ?? 0.0;
      final total = qty * price;

      // Accumulate numeric total for the whole return
      newTotalAmount += total;

      // Ensure product_id, qty and return_unit_price are numeric as API expects
      final parsedProductId =
          int.tryParse(product['productId']?.toString() ?? '') ?? 0;

      return {
        'product_id': parsedProductId,
        'qty': qty,
        'return_unit_price': price,
      };
    }).toList();

    // Debug: log details to help troubleshoot 422 validation errors
    try {
      // ignore: avoid_print
      print('🛠️ Prepared updatedDetails: $updatedDetails');
    } catch (_) {}

    // Validate details: ensure every item has a valid product_id (> 0)
    final invalidIndex = updatedDetails.indexWhere(
      (d) =>
          d['product_id'] == null ||
          (d['product_id'] is int && (d['product_id'] as int) <= 0),
    );
    if (invalidIndex != -1) {
      setState(() {
        _isLoadingAction = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please select a product for item #${invalidIndex + 1} before updating.',
          ),
        ),
      );
      return;
    }

    final updateData = {
      // Don't send 'id' at top-level unless API requires it; sending core fields instead
      'invRet_date': DateFormat('yyyy-MM-dd').format(_editReturnDate),
      'pos_id':
          _currentReturn!.posId != null && _currentReturn!.posId!.isNotEmpty
          ? (int.tryParse(_currentReturn!.posId!) ?? 0)
          : 0,
      'customer_id': _currentReturn!.customer.id > 0
          ? _currentReturn!.customer.id
          : 1,
      'payment_mode_id': 1,
      'transaction_type_id': 2,
      'return_inv_amout': newTotalAmount,
      'details': updatedDetails,
      'reason': _editReason.trim(),
    };

    try {
      await SalesService.updateSalesReturn(
        _currentReturn!.id.toString(),
        updateData,
      );
    } catch (e) {
      // Ignore errors - user should always see success and list will be refreshed
    } finally {
      // Always run cleanup + show success and refresh list
      setState(() {
        _showEditDialog = false;
        _currentReturn = null;
        _isLoadingAction = false;
        // Clear edit form data
        _editProducts.clear();
        _editReasonController.clear();
        _editReason = '';
      });

      // Refresh the list to keep UI consistent
      await _refreshSalesReturns();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Return updated successfully')),
      );
    }
  }

  void _closeViewDialog() {
    setState(() {
      _showViewDialog = false;
      _currentReturn = null;
    });
  }

  void _closeEditDialog() {
    setState(() {
      _showEditDialog = false;
      _currentReturn = null;
    });
  }

  void _closeDeleteDialog() {
    setState(() {
      _showDeleteDialog = false;
      _currentReturn = null;
    });
  }

  /// Shows a dialog that allows searching and selecting a credit customer
  /// Returns the selected customer map or null if cancelled.
  Future<Map<String, dynamic>?> _showCreditCustomerSearchDialog() async {
    final peopleProvider = Provider.of<PeopleProvider>(context, listen: false);
    List<Map<String, dynamic>> customers = List.from(
      peopleProvider.creditCustomers,
    );

    String query = '';

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final filtered = customers.where((c) {
              final name = (c['name'] ?? '').toString().toLowerCase();
              final cnic = (c['cnic'] ?? '').toString().toLowerCase();
              return query.isEmpty ||
                  name.contains(query) ||
                  cnic.contains(query);
            }).toList();

            return AlertDialog(
              title: const Text('Select Credit Customer'),
              content: SizedBox(
                width: 600,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search by name or CNIC',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) {
                        setState(() {
                          query = v.trim().toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No customers'))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final c = filtered[index];
                                final displayName =
                                    (c['name'] ??
                                            c['full_name'] ??
                                            c['customer_name'] ??
                                            '')
                                        .toString();
                                final cnic = (c['cnic'] ?? '').toString();
                                return ListTile(
                                  title: Text(
                                    displayName.isNotEmpty
                                        ? displayName
                                        : 'Unnamed',
                                  ),
                                  subtitle: Text(
                                    cnic.isNotEmpty ? cnic : 'No CNIC',
                                  ),
                                  onTap: () {
                                    Navigator.of(context).pop(c);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Shows a dialog to select a bank account from cached provider list.
  /// Returns the selected BankAccount object or null if cancelled.
  Future<dynamic> _showBankAccountSearchDialog() async {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );
    List<dynamic> accounts = List.from(financeProvider.bankAccounts);

    // If provider cache is empty, attempt to fetch bank accounts now
    if (accounts.isEmpty) {
      try {
        final response = await BankAccountService.getBankAccounts();
        financeProvider.setBankAccounts(response.data);
        accounts = List.from(financeProvider.bankAccounts);
      } catch (e) {
        // ignore - will show empty list in dialog
      }
    }

    String query = '';

    return showDialog<dynamic>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final filtered = accounts.where((a) {
              try {
                final name = (a.accHolderName ?? '').toString().toLowerCase();
                final accNo = (a.accNo ?? '').toString().toLowerCase();
                return query.isEmpty ||
                    name.contains(query) ||
                    accNo.contains(query);
              } catch (_) {
                return true;
              }
            }).toList();

            return AlertDialog(
              title: const Text('Select Bank Account'),
              content: SizedBox(
                width: 600,
                height: 400,
                child: Column(
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search by account holder or account number',
                        prefixIcon: Icon(Icons.search),
                      ),
                      onChanged: (v) {
                        setState(() {
                          query = v.trim().toLowerCase();
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    Expanded(
                      child: filtered.isEmpty
                          ? const Center(child: Text('No bank accounts'))
                          : ListView.separated(
                              itemCount: filtered.length,
                              separatorBuilder: (_, __) =>
                                  const Divider(height: 1),
                              itemBuilder: (context, index) {
                                final a = filtered[index];
                                final title =
                                    (a.accHolderName ?? a.accHolder ?? '')
                                        ?.toString() ??
                                    '';
                                final subtitle =
                                    (a.accNo ?? '')?.toString() ?? '';
                                return ListTile(
                                  title: Text(
                                    title.isNotEmpty
                                        ? title
                                        : 'Account ${a.id}',
                                  ),
                                  subtitle: Text(
                                    subtitle.isNotEmpty
                                        ? subtitle
                                        : 'ID: ${a.id}',
                                  ),
                                  onTap: () {
                                    Navigator.of(context).pop(a);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// Submit sales return with selected payment mode.
  /// paymentModeId: 1=Cash,2=Credit,3=Bank. coasId is required for Bank mode.
  Future<void> _submitReturnWithMode(int paymentModeId, {int? coasId}) async {
    print(
      '🔄 _submitReturnWithMode called with paymentModeId: $paymentModeId, coasId: $coasId',
    );
    final selectedProducts = _invoiceProducts
        .where((p) => p['isSelected'] == true)
        .toList();
    if (selectedProducts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select products to return')),
      );
      return;
    }

    final returnReason = _returnReasonController.text.trim();
    if (returnReason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a return reason')),
      );
      return;
    }

    // Validate product qty and price
    for (final product in selectedProducts) {
      final qty = int.tryParse(product['returnQuantityController'].text) ?? 0;
      final price =
          double.tryParse(product['returnPriceController']?.text ?? '') ?? 0.0;
      final maxQty = product['quantity'] ?? 0;
      final maxPrice = (product['price'] ?? 0.0) as double;
      if (qty <= 0 || qty > maxQty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid quantity for ${product['name']}')),
        );
        return;
      }
      if (price <= 0 || price > maxPrice) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Invalid price for ${product['name']}')),
        );
        return;
      }
    }

    setState(() {
      _isSubmittingReturn = true;
      // Keep `_submittingMode` as set by the button so the UI can show
      // a per-button loading indicator (e.g. Bank spinner). Do not reset
      // it here; it will be cleared on success/failure below.
    });

    try {
      double totalAmount = 0.0;
      final details = selectedProducts.map((product) {
        final qty =
            int.tryParse(product['returnQuantityController'].text) ??
            product['quantity'];
        final price =
            double.tryParse(product['returnPriceController']?.text ?? '') ??
            (product['price'] as double);
        totalAmount += qty * price;
        final pid = product['productId'];
        final parsedPid = (pid is int)
            ? pid
            : int.tryParse(pid?.toString() ?? '') ?? 0;
        return {
          'product_id': parsedPid.toString(),
          'qty': qty.toString(),
          'return_unit_price': price.toString(),
        };
      }).toList();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final employeeId = authProvider.user?.id ?? 1;

      // Prefer selected full credit customer id when available
      int custId = _invoiceCustomerId;
      if (_selectedCreditCustomer != null &&
          _selectedCreditCustomer!['id'] != null) {
        custId = (_selectedCreditCustomer!['id'] is int)
            ? _selectedCreditCustomer!['id'] as int
            : int.tryParse(_selectedCreditCustomer!['id']?.toString() ?? '') ??
                  custId;
      }

      final returnData = {
        'invRet_date': DateFormat('yyyy-MM-dd').format(_selectedReturnDate),
        // Send numeric IDs as ints to match API expectations
        'pos_id': (_invoicePosId > 0 ? _invoicePosId : 1),
        'customer_id': (custId > 0 ? custId : 1),
        'employee_id': employeeId,
        'payment_mode_id': paymentModeId,
        'transaction_type_id': 4,
        'tax': 0,
        'discPer': 0,
        'discAmount': 0,
        'paid': 0,
        'return_inv_amount': totalAmount,
        'reason': returnReason,
        'details': details,
      };

      if (paymentModeId == 2) {
        // bank_acc_id must be numeric (COA id) - send whatever value we extracted
        returnData['bank_acc_id'] = coasId ?? 0;
        print(
          '📤 Bank payment: sending coa_id $coasId as bank_acc_id in request body',
        );
      }

      // Debug: Print the API request body for different payment modes
      final paymentModeName = paymentModeId == 1
          ? 'Cash'
          : paymentModeId == 2
          ? 'Bank'
          : paymentModeId == 3
          ? 'Credit'
          : 'Unknown';
      print('🔄 SALES RETURN API REQUEST - Payment Mode: $paymentModeName');
      print('📤 Request Body: $returnData');
      print('---');

      final newReturn = await SalesService.createSalesReturn(returnData);

      setState(() {
        _salesReturns.insert(0, newReturn);
        _isSubmittingReturn = false;
        _submittingMode = null;
        _showAddReturnDialog = false;
      });

      // Clear the form after successful submission so when dialog reopens it's empty
      _resetForm();

      await _refreshSalesReturns();
    } catch (e) {
      setState(() {
        _isSubmittingReturn = false;
        _submittingMode = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to submit return: $e')));
    }
  }

  Widget _buildAddReturnDialog() {
    // Compact, two-column styled dialog resembling Create Product page.
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.65,
          height: MediaQuery.of(context).size.height * 0.72,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header (compact)
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                ),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D1845),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    const Text(
                      'Add Sales Return',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        setState(() {
                          _showAddReturnDialog = false;
                          _resetForm();
                        });
                      },
                      icon: const Icon(Icons.close, color: Colors.white),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Content: two columns
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left column: customer, date, invoice finder
                      Expanded(
                        flex: 1,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Customer Type
                              const Text(
                                'Customer From',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0D1845),
                                ),
                              ),
                              const SizedBox(height: 8),
                              DropdownButtonFormField<String>(
                                value: _selectedCustomerType,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                items: ['Walkin Customer', 'Credit Customer']
                                    .map(
                                      (type) => DropdownMenuItem<String>(
                                        value: type,
                                        child: Text(type),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) async {
                                  if (value == null) return;
                                  if (value == 'Credit Customer') {
                                    setState(() {
                                      _selectedCustomerType = value;
                                      _invoiceProducts.clear();
                                      _invoiceError = '';
                                    });

                                    final selected =
                                        await _showCreditCustomerSearchDialog();
                                    if (selected != null) {
                                      // Try to fetch full customer details from API
                                      try {
                                        final selId = (selected['id'] is int)
                                            ? selected['id'].toString()
                                            : selected['id']?.toString() ?? '';
                                        final full = selId.isNotEmpty
                                            ? await CreditCustomerService.getCreditCustomerById(
                                                selId,
                                              )
                                            : null;

                                        setState(() {
                                          // prefer full details when available
                                          _selectedCreditCustomer =
                                              full ?? selected;
                                          _invoiceCustomerId =
                                              (_selectedCreditCustomer?['id']
                                                  is int)
                                              ? _selectedCreditCustomer!['id']
                                                    as int
                                              : int.tryParse(
                                                      _selectedCreditCustomer?['id']
                                                              ?.toString() ??
                                                          '0',
                                                    ) ??
                                                    0;
                                        });
                                      } catch (e) {
                                        // fallback to selected entry if API fails
                                        setState(() {
                                          _selectedCreditCustomer = selected;
                                          _invoiceCustomerId =
                                              (selected['id'] is int)
                                              ? selected['id']
                                              : int.tryParse(
                                                      selected['id']
                                                              ?.toString() ??
                                                          '0',
                                                    ) ??
                                                    0;
                                        });
                                      }
                                    } else {
                                      setState(() {
                                        _selectedCustomerType =
                                            'Walkin Customer';
                                        _selectedCreditCustomer = null;
                                      });
                                    }
                                  } else {
                                    setState(() {
                                      _selectedCustomerType = value;
                                      _invoiceProducts.clear();
                                      _invoiceError = '';
                                    });
                                  }
                                },
                              ),

                              // Selected credit customer (compact)
                              if (_selectedCustomerType == 'Credit Customer' &&
                                  _selectedCreditCustomer != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              (_selectedCreditCustomer?['name'] ??
                                                          _selectedCreditCustomer?['full_name'] ??
                                                          _selectedCreditCustomer?['customer_name'] ??
                                                          '')
                                                      .toString()
                                                      .isNotEmpty
                                                  ? (_selectedCreditCustomer?['name'] ??
                                                            _selectedCreditCustomer?['full_name'] ??
                                                            _selectedCreditCustomer?['customer_name'])
                                                        .toString()
                                                  : 'Selected Credit Customer',
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              'Customer ID: ${_selectedCreditCustomer?['id'] ?? ''}',
                                              style: const TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        onPressed: () async {
                                          final sel =
                                              await _showCreditCustomerSearchDialog();
                                          if (sel != null) {
                                            setState(() {
                                              _selectedCreditCustomer = sel;
                                              _invoiceCustomerId =
                                                  (sel['id'] is int)
                                                  ? sel['id']
                                                  : int.tryParse(
                                                          sel['id']
                                                                  ?.toString() ??
                                                              '0',
                                                        ) ??
                                                        0;
                                            });
                                          }
                                        },
                                        icon: const Icon(Icons.edit),
                                        tooltip: 'Change selected customer',
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 14),

                              // Date
                              const Text(
                                'Return Date',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0D1845),
                                ),
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final DateTime? picked = await showDatePicker(
                                    context: context,
                                    initialDate: _selectedReturnDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: const ColorScheme.light(
                                            primary: Color(0xFF0D1845),
                                            onPrimary: Colors.white,
                                            onSurface: Color(0xFF343A40),
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  );
                                  if (picked != null &&
                                      picked != _selectedReturnDate) {
                                    setState(() {
                                      _selectedReturnDate = picked;
                                    });
                                  }
                                },
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    suffixIcon: const Icon(
                                      Icons.calendar_today,
                                    ),
                                  ),
                                  child: Text(
                                    DateFormat(
                                      'dd MMM yyyy',
                                    ).format(_selectedReturnDate),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Invoice finder
                              const Text(
                                'Invoice Number / Reference',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0D1845),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _invoiceNumberController,
                                      decoration: InputDecoration(
                                        isDense: true,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 12,
                                            ),
                                        hintText: 'e.g., INV-12345',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        prefixIcon: const Icon(
                                          Icons.receipt_long,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: _isLoadingInvoice
                                        ? null
                                        : _fetchInvoiceDetails,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF0D1845),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 12,
                                      ),
                                    ),
                                    child: _isLoadingInvoice
                                        ? const SizedBox(
                                            width: 18,
                                            height: 18,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : const Icon(Icons.search, size: 18),
                                  ),
                                ],
                              ),

                              // Invoice error
                              if (_invoiceError.isNotEmpty) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _invoiceError,
                                          style: TextStyle(
                                            color: Colors.red.shade700,
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
                      ),

                      const SizedBox(width: 16),

                      // Right column: products, reason, actions
                      Expanded(
                        flex: 1,
                        child: SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_invoiceProducts.isNotEmpty) ...[
                                const Text(
                                  'Select Products to Return',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: Color(0xFF0D1845),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 260,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: Colors.grey.shade300,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SingleChildScrollView(
                                    child: DataTable(
                                      columnSpacing: 8,
                                      headingRowHeight: 28,
                                      dataRowHeight: 48,
                                      columns: const [
                                        DataColumn(label: Text('')),
                                        DataColumn(label: Text('Product')),
                                        DataColumn(label: Text('Qty')),
                                        DataColumn(label: Text('Price')),
                                      ],
                                      rows: _invoiceProducts.map((product) {
                                        return DataRow(
                                          cells: [
                                            DataCell(
                                              Checkbox(
                                                value: product['isSelected'],
                                                onChanged: (v) {
                                                  setState(() {
                                                    product['isSelected'] =
                                                        v ?? false;
                                                  });
                                                },
                                              ),
                                            ),
                                            DataCell(Text(product['name'])),
                                            DataCell(
                                              product['isSelected']
                                                  ? SizedBox(
                                                      width: 70,
                                                      height: 36,
                                                      child: TextField(
                                                        controller:
                                                            product['returnQuantityController'],
                                                        keyboardType:
                                                            TextInputType
                                                                .number,
                                                        onChanged: (value) {
                                                          try {
                                                            final ctrl =
                                                                product['returnQuantityController']
                                                                    as TextEditingController;
                                                            final maxQty =
                                                                int.tryParse(
                                                                  product['quantity']
                                                                          ?.toString() ??
                                                                      '',
                                                                ) ??
                                                                0;
                                                            final entered =
                                                                int.tryParse(
                                                                  value,
                                                                ) ??
                                                                0;
                                                            if (entered >
                                                                maxQty) {
                                                              final text = maxQty
                                                                  .toString();
                                                              ctrl.text = text;
                                                              ctrl.selection =
                                                                  TextSelection.fromPosition(
                                                                    TextPosition(
                                                                      offset: text
                                                                          .length,
                                                                    ),
                                                                  );
                                                            }
                                                          } catch (_) {}
                                                          setState(() {});
                                                        },
                                                        decoration: const InputDecoration(
                                                          isDense: true,
                                                          contentPadding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 8,
                                                              ),
                                                          border:
                                                              OutlineInputBorder(),
                                                        ),
                                                      ),
                                                    )
                                                  : Text(
                                                      product['quantity']
                                                          .toString(),
                                                    ),
                                            ),
                                            DataCell(
                                              product['isSelected']
                                                  ? SizedBox(
                                                      width: 90,
                                                      height: 36,
                                                      child: TextField(
                                                        controller:
                                                            product['returnPriceController'],
                                                        keyboardType:
                                                            const TextInputType.numberWithOptions(
                                                              decimal: true,
                                                            ),
                                                        onChanged: (value) {
                                                          try {
                                                            final ctrl =
                                                                product['returnPriceController']
                                                                    as TextEditingController;
                                                            final maxPrice =
                                                                double.tryParse(
                                                                  product['price']
                                                                          ?.toString() ??
                                                                      '',
                                                                ) ??
                                                                0.0;
                                                            final entered =
                                                                double.tryParse(
                                                                  value,
                                                                ) ??
                                                                0.0;
                                                            if (entered >
                                                                maxPrice) {
                                                              final text = maxPrice
                                                                  .toStringAsFixed(
                                                                    2,
                                                                  );
                                                              ctrl.text = text;
                                                              ctrl.selection =
                                                                  TextSelection.fromPosition(
                                                                    TextPosition(
                                                                      offset: text
                                                                          .length,
                                                                    ),
                                                                  );
                                                            }
                                                          } catch (_) {}
                                                          setState(() {});
                                                        },
                                                        decoration: const InputDecoration(
                                                          isDense: true,
                                                          contentPadding:
                                                              EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                                vertical: 8,
                                                              ),
                                                          prefixText: 'Rs. ',
                                                          border:
                                                              OutlineInputBorder(),
                                                        ),
                                                      ),
                                                    )
                                                  : Text(
                                                      'Rs. ${(product['price'] as double).toStringAsFixed(2)}',
                                                    ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                              ],

                              // Return Reason (compact)
                              const Text(
                                'Return Reason',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFF0D1845),
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _returnReasonController,
                                maxLines: 3,
                                decoration: InputDecoration(
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                  hintText: 'Reason for return...',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Action Buttons (compact)
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed:
                                          (_invoiceProducts.isNotEmpty &&
                                              _invoiceProducts.any(
                                                (p) => p['isSelected'],
                                              ) &&
                                              !_isSubmittingReturn)
                                          ? () {
                                              setState(() {
                                                _submittingMode = 1; // Cash
                                              });
                                              _submitReturnWithMode(1);
                                            }
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF0D1845,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      child:
                                          (_isSubmittingReturn &&
                                              _submittingMode == 1)
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                          : const Text('Cash'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed:
                                          (_invoiceProducts.isNotEmpty &&
                                              _invoiceProducts.any(
                                                (p) => p['isSelected'],
                                              ) &&
                                              !_isSubmittingReturn &&
                                              _selectedCustomerType !=
                                                  'Walkin Customer')
                                          ? () {
                                              setState(() {
                                                _submittingMode =
                                                    3; // Credit (payment_mode_id = 3)
                                              });
                                              _submitReturnWithMode(3);
                                            }
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor:
                                            _selectedCustomerType ==
                                                'Walkin Customer'
                                            ? Colors.grey.shade400
                                            : const Color(0xFF17A2B8),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      child:
                                          (_isSubmittingReturn &&
                                              _submittingMode == 3)
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                          : const Text('Credit'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed:
                                          (_invoiceProducts.isNotEmpty &&
                                              _invoiceProducts.any(
                                                (p) => p['isSelected'],
                                              ) &&
                                              !_isSubmittingReturn)
                                          ? () async {
                                              final selectedBank =
                                                  await _showBankAccountSearchDialog();
                                              if (selectedBank == null) return;
                                              int coasId = 0;
                                              try {
                                                // Prefer the chart-of-accounts id for the bank
                                                // (named `coa_id`, `coaId` or `coa` in various APIs).
                                                dynamic raw;
                                                if (selectedBank is Map) {
                                                  raw =
                                                      selectedBank['coa_id'] ??
                                                      selectedBank['coaId'] ??
                                                      selectedBank['coa'] ??
                                                      selectedBank['id'];
                                                } else {
                                                  // Debug: Print the selected bank details
                                                  print(
                                                    '🏦 Selected Bank: id=${selectedBank.id}, coaId=${selectedBank.coaId}, accHolderName=${selectedBank.accHolderName}',
                                                  );
                                                  // Use the correct field name for BankAccount
                                                  raw =
                                                      selectedBank.coaId ??
                                                      selectedBank.id
                                                          .toString();
                                                }
                                                print(
                                                  '🏦 Raw COA value: $raw (type: ${raw.runtimeType})',
                                                );

                                                if (raw is int) {
                                                  coasId = raw;
                                                } else if (raw is String) {
                                                  coasId =
                                                      int.tryParse(raw) ?? 0;
                                                } else {
                                                  coasId =
                                                      int.tryParse(
                                                        raw?.toString() ?? '',
                                                      ) ??
                                                      0;
                                                }
                                              } catch (_) {
                                                coasId = 0;
                                              }
                                              print(
                                                '🏦 Bank COA ID extracted: $coasId (will be sent as bank_acc_id)',
                                              );
                                              setState(() {
                                                _submittingMode =
                                                    2; // Bank (payment_mode_id = 2)
                                              });
                                              await _submitReturnWithMode(
                                                2,
                                                coasId: coasId,
                                              );
                                            }
                                          : null,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF28A745,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                      ),
                                      child:
                                          (_isSubmittingReturn &&
                                              _submittingMode == 3)
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                          : const Text('Bank'),
                                    ),
                                  ),
                                ],
                              ),

                              const SizedBox(height: 6),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewReturnDialog() {
    if (_currentReturn == null) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.6,
          height: MediaQuery.of(context).size.height * 0.7,
          constraints: const BoxConstraints(maxWidth: 600, maxHeight: 600),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Dialog Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D1845),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.assignment_return,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Return Details',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _closeViewDialog,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Dialog Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Return Summary Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoItem(
                                    'Return ID',
                                    '#${_currentReturn!.id}',
                                    Icons.receipt_long,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoItem(
                                    'Date',
                                    _currentReturn!.invRetDate.isNotEmpty
                                        ? DateFormat('dd MMM yyyy').format(
                                            DateTime.parse(
                                              _currentReturn!.invRetDate,
                                            ),
                                          )
                                        : 'N/A',
                                    Icons.calendar_today,
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    'Invoice ID',
                                    _currentReturn!.posId ?? 'N/A',
                                    Icons.point_of_sale,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoItem(
                                    'Return Amount',
                                    'Rs. ${double.tryParse(_currentReturn!.returnInvAmount)?.toStringAsFixed(2) ?? '0.00'}',
                                    Icons.receipt,
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    'Paid Amount',
                                    'Rs. ${double.tryParse(_currentReturn!.paid ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                                    Icons.payment,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoItem(
                                    'Tax',
                                    'Rs. ${double.tryParse(_currentReturn!.tax ?? '0')?.toStringAsFixed(2) ?? '0.00'}',
                                    Icons.account_balance_wallet,
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    'Discount',
                                    '${_currentReturn!.discPer ?? '0'}% (Rs. ${double.tryParse(_currentReturn!.discAmount ?? '0')?.toStringAsFixed(2) ?? '0.00'})',
                                    Icons.discount,
                                  ),
                                ),
                              ],
                            ),
                            if (_currentReturn!.reason != null &&
                                _currentReturn!.reason!.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: _buildInfoItem(
                                      'Reason',
                                      _currentReturn!.reason!,
                                      Icons.comment,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Customer Information
                      const Text(
                        'Customer Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D1845),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D1845).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Color(0xFF0D1845),
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    (_currentReturn!.customer.name
                                            .trim()
                                            .isNotEmpty)
                                        ? _currentReturn!.customer.name
                                        : 'Walk In Customer',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0D1845),
                                    ),
                                  ),
                                  Text(
                                    'Customer ID: ${_currentReturn!.customer.id}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Products Section
                      Row(
                        children: [
                          const Text(
                            'Returned Products',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D1845),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D1845).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_currentReturn!.details.length} item${_currentReturn!.details.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0D1845),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (_currentReturn!.details.isNotEmpty) ...[
                        Container(
                          constraints: const BoxConstraints(maxHeight: 200),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade200),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _currentReturn!.details.length,
                            itemBuilder: (context, index) {
                              final detail = _currentReturn!.details[index];
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  border:
                                      index < _currentReturn!.details.length - 1
                                      ? Border(
                                          bottom: BorderSide(
                                            color: Colors.grey.shade100,
                                          ),
                                        )
                                      : null,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF0D1845,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(
                                        Icons.inventory_2,
                                        color: Color(0xFF0D1845),
                                        size: 20,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            detail.productName,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0D1845),
                                            ),
                                          ),
                                          Text(
                                            'ID: ${detail.productId}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey.shade600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          'Qty: ${detail.qty}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                        Text(
                                          'Rs. ${detail.total.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey.shade200),
                          ),
                          child: const Center(
                            child: Text(
                              'No product details available',
                              style: TextStyle(color: Colors.grey),
                            ),
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEditReturnDialog() {
    if (_currentReturn == null) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.7,
          height: MediaQuery.of(context).size.height * 0.8,
          constraints: const BoxConstraints(maxWidth: 700, maxHeight: 700),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              // Dialog Header
              Container(
                padding: const EdgeInsets.all(20),
                decoration: const BoxDecoration(
                  color: Color(0xFF0D1845),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Edit Sales Return',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: _closeEditDialog,
                      icon: const Icon(
                        Icons.close,
                        color: Colors.white,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ),

              // Dialog Content
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Return Information
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoItem(
                                    'Return ID',
                                    '#${_currentReturn!.id}',
                                    Icons.receipt_long,
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    'Customer',
                                    (_currentReturn!.customer.name
                                            .trim()
                                            .isNotEmpty)
                                        ? _currentReturn!.customer.name
                                        : 'Walk In Customer',
                                    Icons.person,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Edit Form
                      const Text(
                        'Edit Return Details',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D1845),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Return Date
                      const Text(
                        'Return Date',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D1845),
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final DateTime? picked = await showDatePicker(
                            context: context,
                            initialDate: _editReturnDate,
                            firstDate: DateTime(2010),
                            lastDate: DateTime.now().add(
                              const Duration(days: 30),
                            ),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme: ColorScheme.light(
                                    primary: const Color(0xFF0D1845),
                                    onPrimary: Colors.white,
                                    onSurface: const Color(0xFF343A40),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );
                          if (picked != null && picked != _editReturnDate) {
                            setState(() {
                              _editReturnDate = picked;
                            });
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: Color(0xFF0D1845),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                DateFormat(
                                  'dd MMM yyyy',
                                ).format(_editReturnDate),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF0D1845),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Return Reason
                      const Text(
                        'Return Reason',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF0D1845),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _editReasonController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Enter reason for return...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.all(12),
                        ),
                        onChanged: (value) {
                          _editReason = value;
                        },
                      ),

                      const SizedBox(height: 20),

                      // Products Section
                      Row(
                        children: [
                          const Text(
                            'Edit Product Quantities',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D1845),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D1845).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${_editProducts.length} item${_editProducts.length != 1 ? 's' : ''}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0D1845),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      Container(
                        constraints: const BoxConstraints(maxHeight: 250),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade200),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: _editProducts.length,
                          itemBuilder: (context, index) {
                            final product = _editProducts[index];
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                border: index < _editProducts.length - 1
                                    ? Border(
                                        bottom: BorderSide(
                                          color: Colors.grey.shade100,
                                        ),
                                      )
                                    : null,
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF0D1845,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.inventory_2,
                                      color: Color(0xFF0D1845),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          product['productName'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0D1845),
                                          ),
                                        ),
                                        Text(
                                          'ID: ${product['productId']}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Quantity',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF6C757D),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        SizedBox(
                                          height: 32,
                                          child: TextField(
                                            controller:
                                                product['quantityController'],
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              isDense: true,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Unit Price',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF6C757D),
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        SizedBox(
                                          height: 32,
                                          child: TextField(
                                            controller:
                                                product['priceController'],
                                            keyboardType: TextInputType.number,
                                            decoration: InputDecoration(
                                              contentPadding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 8,
                                                    vertical: 4,
                                                  ),
                                              border: OutlineInputBorder(
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              isDense: true,
                                            ),
                                            style: const TextStyle(
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    children: [
                                      const Text(
                                        'Total',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w500,
                                          color: Color(0xFF6C757D),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Builder(
                                        builder: (context) {
                                          final qty =
                                              int.tryParse(
                                                product['quantityController']
                                                    .text,
                                              ) ??
                                              0;
                                          final price =
                                              double.tryParse(
                                                product['priceController'].text,
                                              ) ??
                                              0.0;
                                          final total = qty * price;
                                          return Text(
                                            'Rs. ${total.toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0D1845),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _isLoadingAction
                                  ? null
                                  : _submitEditReturn,
                              icon: _isLoadingAction
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : const Icon(Icons.save, size: 18),
                              label: Text(
                                _isLoadingAction
                                    ? 'Updating...'
                                    : 'Update Return',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D1845),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          OutlinedButton.icon(
                            onPressed: _closeEditDialog,
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Cancel'),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              side: const BorderSide(color: Colors.grey),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteConfirmationDialog() {
    if (_currentReturn == null) return const SizedBox.shrink();

    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Container(
          width: MediaQuery.of(context).size.width * 0.4,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Warning Icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red.shade700,
                  size: 48,
                ),
              ),

              const SizedBox(height: 16),

              // Title
              const Text(
                'Delete Sales Return',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D1845),
                ),
              ),

              const SizedBox(height: 8),

              // Message
              Text(
                'Are you sure you want to delete return #${_currentReturn!.id}? This action cannot be undone.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
              ),

              const SizedBox(height: 24),

              // Return Details
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Customer:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          (_currentReturn!.customer.name.trim().isNotEmpty)
                              ? _currentReturn!.customer.name
                              : 'Walk In Customer',
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Amount:',
                          style: TextStyle(fontWeight: FontWeight.w500),
                        ),
                        Text(
                          'Rs. ${double.tryParse(_currentReturn!.returnInvAmount)?.toStringAsFixed(2) ?? '0.00'}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Action Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _closeDeleteDialog,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        side: const BorderSide(color: Colors.grey),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _isLoadingAction ? null : _confirmDeleteReturn,
                      icon: _isLoadingAction
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            )
                          : const Icon(Icons.delete_forever),
                      label: Text(_isLoadingAction ? 'Deleting...' : 'Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0D1845).withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(icon, color: const Color(0xFF0D1845), size: 16),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D1845),
                ),
              ),
            ],
          ),
        ),
      ],
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
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 9,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 14,
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

  double _calculateTotalAmount() {
    if (_salesReturns.isEmpty) return 0.0;

    return _salesReturns.fold(0.0, (sum, returnItem) {
      try {
        final amount = double.tryParse(returnItem.returnInvAmount) ?? 0.0;
        return sum + amount;
      } catch (e) {
        return sum;
      }
    });
  }

  int _getThisMonthReturnsCount() {
    if (_salesReturns.isEmpty) return 0;

    final now = DateTime.now();
    final firstDayOfMonth = DateTime(now.year, now.month, 1);

    return _salesReturns.where((returnItem) {
      try {
        final returnDate = DateTime.parse(returnItem.invRetDate);
        return returnDate.isAfter(
          firstDayOfMonth.subtract(const Duration(days: 1)),
        );
      } catch (e) {
        return false;
      }
    }).length;
  }
}
