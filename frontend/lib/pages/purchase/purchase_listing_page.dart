import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'create_purchase_page.dart';
import '../../services/purchases_service.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:printing/printing.dart';

class PurchaseListingPage extends StatefulWidget {
  const PurchaseListingPage({super.key});

  @override
  State<PurchaseListingPage> createState() => _PurchaseListingPageState();
}

class _PurchaseListingPageState extends State<PurchaseListingPage>
    with WidgetsBindingObserver, RouteAware {
  // API data
  List<Purchase> _filteredPurchases = [];
  List<Purchase> _allFilteredPurchases =
      []; // Store all filtered purchases for local pagination
  bool _isLoading = true;
  String? _errorMessage;
  int currentPage = 1;
  final int itemsPerPage = 14;

  // Filter states
  String _selectedStatus = 'All';
  String _selectedPaymentStatus = 'All';
  String _selectedTimeFilter = 'All'; // All, Day, Month, Year
  final TextEditingController _searchController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;

  // Checkbox selection
  Set<String> _selectedPurchaseIds = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchAllPurchasesOnInit();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Subscribe to RouteObserver if available in MaterialApp.navigatorObservers
    final modalRoute = ModalRoute.of(context);
    if (modalRoute is PageRoute) {
      final observers = context
          .findAncestorStateOfType<State<StatefulWidget>>()
          ?.context
          .findAncestorWidgetOfExactType<MaterialApp>()
          ?.navigatorObservers;

      final routeObserver =
          observers != null &&
              observers
                  .whereType<RouteObserver<PageRoute<dynamic>>>()
                  .isNotEmpty
          ? observers.whereType<RouteObserver<PageRoute<dynamic>>>().first
          : null;

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
      final observers = context
          .findAncestorStateOfType<State<StatefulWidget>>()
          ?.context
          .findAncestorWidgetOfExactType<MaterialApp>()
          ?.navigatorObservers;

      final routeObserver =
          observers != null &&
              observers
                  .whereType<RouteObserver<PageRoute<dynamic>>>()
                  .isNotEmpty
          ? observers.whereType<RouteObserver<PageRoute<dynamic>>>().first
          : null;

      if (routeObserver != null) {
        routeObserver.unsubscribe(this);
      }
    }

    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  // RouteAware callbacks
  @override
  void didPush() {
    // Called when the current route has been pushed
    print('📍 PurchaseListingPage: didPush - refreshing purchases');
    _fetchAllPurchasesOnInit(forceRefresh: true);
  }

  @override
  void didPopNext() {
    // Called when the top route has been popped off, and the current route shows up
    print('📍 PurchaseListingPage: didPopNext - refreshing purchases');
    _fetchAllPurchasesOnInit(forceRefresh: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _fetchAllPurchasesOnInit(forceRefresh: true);
    }
  }

  void _onSearchChanged(String query) {
    // Apply filters immediately (no debounce for now)
    _applyFiltersClientSide();
  }

  // Fetch all purchases once when page loads
  Future<void> _fetchAllPurchasesOnInit({bool forceRefresh = false}) async {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );

    // Check if purchases are already cached (skip if forceRefresh is true)
    if (!forceRefresh && purchaseProvider.purchases.isNotEmpty) {
      print(
        '💾 Using cached purchases: ${purchaseProvider.purchases.length} items',
      );
      _applyFiltersClientSide();
      return;
    }

    try {
      print('🚀 Initial load: Fetching all purchases');
      setState(() {
        _errorMessage = null;
        _isLoading = true;
      });

      // Fetch all purchases from all pages
      List<Purchase> allPurchases = [];
      int currentFetchPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        try {
          print('📡 Fetching page $currentFetchPage');
          final response = await PurchaseService.getPurchases(
            page: currentFetchPage,
            perPage: 50, // Use larger page size for efficiency
          );

          allPurchases.addAll(response.data);
          print(
            '📦 Page $currentFetchPage: ${response.data.length} purchases (total: ${allPurchases.length})',
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

      // Sort purchases by created_at descending (newest first)
      // If created_at is same or invalid, fallback to purInvId descending
      allPurchases.sort((a, b) {
        try {
          if (a.createdAt.isNotEmpty && b.createdAt.isNotEmpty) {
            final dateA = DateTime.parse(a.createdAt);
            final dateB = DateTime.parse(b.createdAt);
            final comparison = dateB.compareTo(dateA);
            if (comparison != 0) return comparison;
          }
        } catch (e) {
          // If date parsing fails, fall through to ID comparison
        }
        // Fallback to ID comparison — use defensive parsing to avoid FormatException
        final idB = int.tryParse(b.purInvId.toString()) ?? 0;
        final idA = int.tryParse(a.purInvId.toString()) ?? 0;
        return idB - idA;
      });

      // Cache purchases in provider
      purchaseProvider.setPurchases(allPurchases);
      print(
        '💾 Cached ${allPurchases.length} total purchases (sorted newest first)',
      );

      // Apply initial filters (which will be no filters, showing all purchases)
      _applyFiltersClientSide();
    } catch (e) {
      print('❌ Critical error in _fetchAllPurchasesOnInit: $e');
      setState(() {
        _errorMessage = 'Failed to load purchases. Please refresh the page.';
        _isLoading = false;
      });
    }
  }

  // Client-side only filter application
  void _applyFiltersClientSide() {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );

    try {
      print(
        '🎯 Client-side filtering - status: "$_selectedStatus", payment: "$_selectedPaymentStatus"',
      );

      // Apply filters to cached purchases (no API calls)
      _filterCachedPurchases();

      print(
        '📦 purchaseProvider.purchases.length: ${purchaseProvider.purchases.length}',
      );
      print('🎯 _allFilteredPurchases.length: ${_allFilteredPurchases.length}');
      print('👀 _filteredPurchases.length: ${_filteredPurchases.length}');
    } catch (e) {
      print('❌ Error in _applyFiltersClientSide: $e');
      setState(() {
        _errorMessage = 'Search error: Please try a different search term';
        _isLoading = false;
        _filteredPurchases = [];
      });
    }
  }

  // Filter cached purchases without any API calls
  void _filterCachedPurchases() {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );

    try {
      final searchQuery = _searchController.text.toLowerCase().trim();

      // Apply filters to cached purchases
      _allFilteredPurchases = purchaseProvider.purchases.where((purchase) {
        try {
          // SEARCH filtering
          bool searchMatch = true;
          if (searchQuery.isNotEmpty) {
            final purId = purchase.purInvId.toString();
            final vendor = purchase.vendorName.toLowerCase();
            final barcode = purchase.purInvBarcode.toLowerCase();
            final venInvNo = purchase.venInvNo.toLowerCase();

            searchMatch =
                purId.contains(searchQuery) ||
                vendor.contains(searchQuery) ||
                barcode.contains(searchQuery) ||
                venInvNo.contains(searchQuery);
          }

          if (!searchMatch) return false;

          // Status filter (derived from payment status)
          final derivedStatus = purchase.paymentStatus.toLowerCase() == 'paid'
              ? 'Completed'
              : 'Pending';
          if (_selectedStatus != 'All' && derivedStatus != _selectedStatus) {
            return false;
          }

          // Payment status filter - support Paid/Unpaid/Partial
          if (_selectedPaymentStatus != 'All') {
            final pStatus = purchase.paymentStatus.toLowerCase();
            final sel = _selectedPaymentStatus.toLowerCase();
            if (sel == 'paid' && pStatus != 'paid') return false;
            if (sel == 'unpaid' && pStatus != 'unpaid') return false;
            if (sel == 'partial' && pStatus != 'partial') return false;
          }

          // Date filtering: if explicit date range selected use it,
          // otherwise fall back to the time filter (Day/Month/Year/All).
          bool dateMatch = true;
          if (purchase.purDate.isEmpty) {
            // if we have any date filters, exclude records without date
            if (_fromDate != null ||
                _toDate != null ||
                _selectedTimeFilter != 'All') {
              return false;
            }
          } else {
            try {
              final purDate = DateTime.parse(purchase.purDate);

              if (_fromDate != null || _toDate != null) {
                if (_fromDate != null && purDate.isBefore(_fromDate!)) {
                  dateMatch = false;
                }
                if (_toDate != null) {
                  final toEnd = DateTime(
                    _toDate!.year,
                    _toDate!.month,
                    _toDate!.day,
                    23,
                    59,
                    59,
                  );
                  if (purDate.isAfter(toEnd)) {
                    dateMatch = false;
                  }
                }
              } else {
                final now = DateTime.now();
                if (_selectedTimeFilter == 'Day') {
                  dateMatch =
                      purDate.year == now.year &&
                      purDate.month == now.month &&
                      purDate.day == now.day;
                } else if (_selectedTimeFilter == 'Month') {
                  dateMatch =
                      purDate.year == now.year && purDate.month == now.month;
                } else if (_selectedTimeFilter == 'Year') {
                  dateMatch = purDate.year == now.year;
                }
              }
            } catch (e) {
              // If date parsing fails, exclude this purchase when date filtering applies
              if (_fromDate != null ||
                  _toDate != null ||
                  _selectedTimeFilter != 'All')
                return false;
            }
          }

          if (!dateMatch) return false;

          return true;
        } catch (e) {
          // If there's any error during filtering, exclude this purchase
          print('⚠️ Error filtering purchase ${purchase.purInvId}: $e');
          return false;
        }
      }).toList();

      print(
        '🔍 After filtering: ${_allFilteredPurchases.length} purchases match criteria',
      );
      print(
        '📝 Status filter: "$_selectedStatus", Payment filter: "$_selectedPaymentStatus"',
      );

      // Apply local pagination to filtered results
      _paginateFilteredPurchases();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Critical error in _filterCachedPurchases: $e');
      setState(() {
        _errorMessage =
            'Search failed. Please try again with a simpler search term.';
        _isLoading = false;
        // Fallback: show empty results instead of crashing
        _filteredPurchases = [];
        _allFilteredPurchases = [];
      });
    }
  }

  // Apply local pagination to filtered purchases
  void _paginateFilteredPurchases() {
    try {
      // Handle empty results case
      if (_allFilteredPurchases.isEmpty) {
        setState(() {
          _filteredPurchases = [];
        });
        return;
      }

      final startIndex = (currentPage - 1) * itemsPerPage;
      final endIndex = startIndex + itemsPerPage;

      // Ensure startIndex is not greater than the list length
      if (startIndex >= _allFilteredPurchases.length) {
        // Reset to page 1 if current page is out of bounds
        setState(() {
          currentPage = 1;
        });
        _paginateFilteredPurchases(); // Recursive call with corrected page
        return;
      }

      setState(() {
        _filteredPurchases = _allFilteredPurchases.sublist(
          startIndex,
          endIndex > _allFilteredPurchases.length
              ? _allFilteredPurchases.length
              : endIndex,
        );
      });
    } catch (e) {
      print('❌ Error in _paginateFilteredPurchases: $e');
      setState(() {
        _filteredPurchases = [];
        currentPage = 1;
      });
    }
  }

  // Handle page changes for both filtered and normal pagination
  Future<void> _changePage(int newPage) async {
    setState(() {
      currentPage = newPage;
    });

    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );

    // Always use client-side pagination when we have cached purchases
    if (purchaseProvider.purchases.isNotEmpty) {
      _paginateFilteredPurchases();
    } else {
      // Fallback to server pagination only if no cached data
      await _fetchPurchases(page: newPage);
    }
  }

  Future<void> _fetchPurchases({int page = 1}) async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final response = await PurchaseService.getPurchases(
        page: page,
        perPage: itemsPerPage,
      );
      setState(() {
        _filteredPurchases = response.data;
        currentPage = page;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  // View purchase details
  Future<void> _viewPurchaseDetails(String purchaseId) async {
    // Show dialog immediately with loading state
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const _LoadingPurchaseDialog();
      },
    );

    try {
      final purchase = await PurchaseService.getPurchaseById(purchaseId);

      // Close loading dialog and show details dialog
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showPurchaseDetailsDialog(purchase);
      }
    } catch (e) {
      // Close loading dialog and show error
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load purchase details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Show purchase details dialog
  void _showPurchaseDetailsDialog(Purchase purchase) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.9,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D1845), Color(0xFF1a2980)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF0D1845).withOpacity(0.3),
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.receipt_long,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Purchase Details',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            SizedBox(height: 4),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                'Invoice: ${purchase.purInvBarcode}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.white,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Colors.white, size: 24),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Status Badge
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color:
                                    purchase.paymentStatus.toLowerCase() ==
                                        'paid'
                                    ? Color(0xFF28A745).withOpacity(0.1)
                                    : Color(0xFFDC3545).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      purchase.paymentStatus.toLowerCase() ==
                                          'paid'
                                      ? Color(0xFF28A745)
                                      : Color(0xFFDC3545),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    purchase.paymentStatus.toLowerCase() ==
                                            'paid'
                                        ? Icons.check_circle
                                        : Icons.pending,
                                    color:
                                        purchase.paymentStatus.toLowerCase() ==
                                            'paid'
                                        ? Color(0xFF28A745)
                                        : Color(0xFFDC3545),
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    purchase.paymentStatus.toUpperCase(),
                                    style: TextStyle(
                                      color:
                                          purchase.paymentStatus
                                                  .toLowerCase() ==
                                              'paid'
                                          ? Color(0xFF28A745)
                                          : Color(0xFFDC3545),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Spacer(),
                            Text(
                              'ID: ${purchase.purInvId}',
                              style: TextStyle(
                                color: Color(0xFF6C757D),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Purchase Information Card
                        _buildInfoCard(
                          'Purchase Information',
                          Icons.shopping_bag,
                          Color(0xFF2196F3),
                          [
                            _buildModernDetailRow(
                              'Purchase Date',
                              purchase.purDate.isNotEmpty
                                  ? DateFormat(
                                      'dd MMM yyyy',
                                    ).format(DateTime.parse(purchase.purDate))
                                  : 'N/A',
                              Icons.calendar_today,
                            ),
                            _buildModernDetailRow(
                              'Vendor',
                              purchase.vendorName,
                              Icons.business,
                            ),
                            _buildModernDetailRow(
                              'Vendor Invoice',
                              purchase.venInvNo,
                              Icons.receipt,
                            ),
                            _buildModernDetailRow(
                              'Vendor Inv. Date',
                              purchase.venInvDate.isNotEmpty
                                  ? DateFormat('dd MMM yyyy').format(
                                      DateTime.parse(purchase.venInvDate),
                                    )
                                  : 'N/A',
                              Icons.event,
                            ),
                            _buildModernDetailRow(
                              'Reference',
                              purchase.venInvRef,
                              Icons.bookmark,
                            ),
                            if (purchase.description.isNotEmpty)
                              _buildModernDetailRow(
                                'Notes',
                                purchase.description,
                                Icons.description,
                              ),
                            _buildModernDetailRow(
                              'Created',
                              purchase.createdAt.isNotEmpty
                                  ? DateFormat(
                                      'dd MMM yyyy, hh:mm a',
                                    ).format(DateTime.parse(purchase.createdAt))
                                  : 'N/A',
                              Icons.access_time,
                            ),
                          ],
                        ),

                        const SizedBox(height: 20),

                        // Financial Summary Card
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Color(0xFFF8F9FA), Colors.white],
                            ),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Color(0xFFDEE2E6)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF28A745).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.account_balance_wallet,
                                      color: Color(0xFF28A745),
                                      size: 20,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Financial Summary',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF0D1845),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 16),
                              _buildFinancialRow(
                                'Discount Percent',
                                '${purchase.discountPercent}%',
                                Color(0xFFFFA726),
                              ),
                              SizedBox(height: 12),
                              _buildFinancialRow(
                                'Discount Amount',
                                'Rs. ${double.tryParse(purchase.discountAmt)?.toStringAsFixed(2) ?? '0.00'}',
                                Color(0xFFDC3545),
                              ),
                              SizedBox(height: 12),
                              _buildFinancialRow(
                                'Tax Amount',
                                'Rs. ${double.tryParse(purchase.taxAmt)?.toStringAsFixed(2) ?? '0.00'}',
                                Color(0xFF17A2B8),
                              ),
                              SizedBox(height: 12),
                              _buildFinancialRow(
                                'Shipping Amount',
                                'Rs. ${double.tryParse(purchase.shippingAmt)?.toStringAsFixed(2) ?? '0.00'}',
                                Color(0xFF6C757D),
                              ),
                              SizedBox(height: 12),
                              Divider(thickness: 1.5),
                              SizedBox(height: 12),
                              _buildFinancialRow(
                                'Total Amount',
                                'Rs. ${double.tryParse(purchase.invAmount)?.toStringAsFixed(2) ?? '0.00'}',
                                Color(0xFF28A745),
                                isTotal: true,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Purchase Items
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Color(0xFF17A2B8).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(
                                Icons.inventory_2,
                                color: Color(0xFF17A2B8),
                                size: 20,
                              ),
                            ),
                            SizedBox(width: 12),
                            Text(
                              'Purchase Items',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D1845),
                              ),
                            ),
                            Spacer(),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFF17A2B8).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${purchase.purDetails.length} items',
                                style: TextStyle(
                                  color: Color(0xFF17A2B8),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Color(0xFFDEE2E6)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 8,
                                offset: Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              // Table Header
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Color(0xFFF8F9FA),
                                  borderRadius: const BorderRadius.only(
                                    topLeft: Radius.circular(12),
                                    topRight: Radius.circular(12),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        'Product',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF343A40),
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Qty',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF343A40),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Unit Price',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF343A40),
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Disc. (%)',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF343A40),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Disc. Amt',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF343A40),
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 2,
                                      child: Text(
                                        'Amount',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                          color: Color(0xFF343A40),
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Items
                              ...purchase.purDetails.asMap().entries.map((
                                entry,
                              ) {
                                final index = entry.key;
                                final detail = entry.value;
                                final isEven = index % 2 == 0;

                                return Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: isEven
                                        ? Colors.white
                                        : Color(0xFFF8F9FA),
                                    border: Border(
                                      bottom:
                                          index < purchase.purDetails.length - 1
                                          ? BorderSide(color: Color(0xFFDEE2E6))
                                          : BorderSide.none,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: Color(
                                                  0xFF17A2B8,
                                                ).withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  '${index + 1}',
                                                  style: TextStyle(
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFF17A2B8),
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 10),
                                            Expanded(
                                              child: Text(
                                                detail.productName,
                                                style: TextStyle(
                                                  fontSize: 13,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          detail.quantity,
                                          style: TextStyle(fontSize: 13),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Rs. ${double.tryParse(detail.unitPrice)?.toStringAsFixed(2) ?? '0.00'}',
                                          style: TextStyle(fontSize: 13),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Container(
                                          padding: EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: detail.discPer != '0.00'
                                                ? Color(
                                                    0xFFFFA726,
                                                  ).withOpacity(0.1)
                                                : Colors.transparent,
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Text(
                                            '${detail.discPer}%',
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: detail.discPer != '0.00'
                                                  ? Color(0xFFFFA726)
                                                  : Color(0xFF6C757D),
                                              fontWeight:
                                                  detail.discPer != '0.00'
                                                  ? FontWeight.w600
                                                  : FontWeight.normal,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Rs. ${double.tryParse(detail.discAmount)?.toStringAsFixed(2) ?? '0.00'}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: detail.discAmount != '0.00'
                                                ? Color(0xFFDC3545)
                                                : Color(0xFF6C757D),
                                            fontWeight:
                                                detail.discAmount != '0.00'
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Rs. ${double.tryParse(detail.amount)?.toStringAsFixed(2) ?? '0.00'}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF28A745),
                                          ),
                                          textAlign: TextAlign.right,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _generatePurchaseInvoice(purchase),
                        icon: Icon(Icons.receipt_long, size: 18),
                        label: const Text('Print Invoice'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF28A745),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.check, size: 18),
                        label: const Text('Close'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Color(0xFF0D1845),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Generate purchase invoice PDF
  Future<void> _generatePurchaseInvoice(Purchase purchase) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Generating PDF...'),
              ],
            ),
          );
        },
      );

      // Create PDF document with custom page size (80mm width, flexible height)
      // 80mm = 226.77 points (80mm / 25.4mm per inch * 72 points per inch)
      const double pageWidthInPoints = 226.77; // Exactly 80mm
      const double initialPageHeightInPoints =
          1000; // Will be resized to fit content
      const double receiptWidthPx =
          pageWidthInPoints; // Drawing width matches page width
      const double leftMarginPx = 10.0; // No left margin
      const double rightMarginPx = 10.0; // Right margin for spacing

      final PdfDocument document = PdfDocument();

      // Set custom page size using PdfSection
      final PdfSection section = document.sections!.add();
      section.pageSettings.size = Size(
        pageWidthInPoints,
        initialPageHeightInPoints,
      );
      // Remove all page margins to eliminate white space
      section.pageSettings.margins.all = 0;
      final PdfPage page = section.pages.add();
      final PdfGraphics graphics = page.graphics;

      // Fonts - optimized sizes for narrow printable width
      final PdfFont regularFont = PdfStandardFont(PdfFontFamily.helvetica, 6);
      final PdfFont boldFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        7,
        style: PdfFontStyle.bold,
      );
      final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 5.5);

      final double printableWidth =
          receiptWidthPx - leftMarginPx - rightMarginPx;
      double yPos = 6.0; // Minimal top margin

      // Header - compact spacing for narrow width
      graphics.drawString(
        'PURCHASE INVOICE',
        boldFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 12),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
      yPos += 10;

      graphics.drawString(
        'Dhanpuri By Get Going',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.top,
        ),
      );
      yPos += 8;

      graphics.drawString(
        'Civil line road opposite MCB Bank Jhelum',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.top,
        ),
      );
      yPos += 8;

      graphics.drawString(
        'Phone # 0544 276590',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.top,
        ),
      );
      yPos += 10;

      // Separator line
      graphics.drawLine(
        PdfPen(PdfColor(0, 0, 0), width: 0.5),
        Offset(leftMarginPx, yPos),
        Offset(receiptWidthPx - rightMarginPx, yPos),
      );
      yPos += 6;

      // Purchase Info - tight spacing for narrow width
      graphics.drawString(
        'PUR-${purchase.purInvId}',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
      );
      yPos += 8;

      graphics.drawString(
        'Date: ${DateFormat('dd/MM/yy').format(DateTime.parse(purchase.purDate))} ${DateFormat('HH:mm').format(DateTime.now())}',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
      );
      yPos += 8;

      // Vendor info - tight spacing
      graphics.drawString(
        'Vendor: ${purchase.vendorName}',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
      );
      yPos += 8;

      if (purchase.venInvNo.isNotEmpty) {
        graphics.drawString(
          'Ven Inv: ${purchase.venInvNo}',
          regularFont,
          bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
        );
        yPos += 8;
      }

      if (purchase.venInvRef.isNotEmpty) {
        graphics.drawString(
          'Ref: ${purchase.venInvRef}',
          regularFont,
          bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
        );
        yPos += 8;
      }

      // Separator line
      graphics.drawLine(
        PdfPen(PdfColor(0, 0, 0), width: 0.5),
        Offset(leftMarginPx, yPos),
        Offset(receiptWidthPx - rightMarginPx, yPos),
      );
      yPos += 6;

      // Items Header - optimized column widths for narrow printable area
      final double itemWidth = printableWidth * 0.45; // Item name
      final double qtyWidth = printableWidth * 0.15; // Quantity
      final double priceWidth = printableWidth * 0.20; // Price
      final double totalWidth = printableWidth * 0.20; // Total

      final double colItemX = leftMarginPx;
      final double colQtyX = colItemX + itemWidth;
      final double colPriceX = colQtyX + qtyWidth;
      final double colTotalX = colPriceX + priceWidth;

      graphics.drawString(
        'Item',
        boldFont,
        bounds: Rect.fromLTWH(colItemX, yPos, itemWidth, 10),
      );
      graphics.drawString(
        'Qty',
        boldFont,
        bounds: Rect.fromLTWH(colQtyX, yPos, qtyWidth, 10),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
      graphics.drawString(
        'Price',
        boldFont,
        bounds: Rect.fromLTWH(colPriceX, yPos, priceWidth, 10),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
      graphics.drawString(
        'Total',
        boldFont,
        bounds: Rect.fromLTWH(colTotalX, yPos, totalWidth, 10),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
      yPos += 8;

      // Separator
      graphics.drawLine(
        PdfPen(PdfColor(0, 0, 0), width: 0.5),
        Offset(leftMarginPx, yPos),
        Offset(receiptWidthPx - rightMarginPx, yPos),
      );
      yPos += 5;

      // Items list - very tight spacing for narrow width
      const double itemHeight = 9.0; // Reduced for narrow width
      const double extraLineHeight = 6.0; // For discount lines
      double subtotal = 0;

      for (var item in purchase.purDetails) {
        final String name = item.productName;
        final int qty = int.tryParse(item.quantity) ?? 0;
        final double price = double.tryParse(item.unitPrice) ?? 0;
        final double itemTotal = qty * price;
        // Calculate item-level discount (same as Create Purchase)
        final double itemDiscountPercent = double.tryParse(item.discPer) ?? 0;
        final double itemDiscountAmount =
            (price * qty * itemDiscountPercent / 100);
        subtotal += (itemTotal - itemDiscountAmount);

        graphics.drawString(
          name,
          regularFont,
          bounds: Rect.fromLTWH(colItemX, yPos, itemWidth, 10),
        );
        graphics.drawString(
          qty.toString(),
          regularFont,
          bounds: Rect.fromLTWH(colQtyX, yPos, qtyWidth, 10),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
        graphics.drawString(
          price.toStringAsFixed(2),
          regularFont,
          bounds: Rect.fromLTWH(colPriceX, yPos, priceWidth, 10),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        graphics.drawString(
          itemTotal.toStringAsFixed(2),
          regularFont,
          bounds: Rect.fromLTWH(colTotalX, yPos, totalWidth, 10),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        yPos += itemHeight;

        // Show product-level discount if present
        final double discountPercent = double.tryParse(item.discPer) ?? 0;
        final double discountAmount = double.tryParse(item.discAmount) ?? 0;
        if (discountAmount > 0 || discountPercent > 0) {
          final String discountText = discountPercent > 0
              ? '- Discount: ${discountPercent.toStringAsFixed(0)}% (Rs ${discountAmount.toStringAsFixed(2)})'
              : '- Discount: Rs ${discountAmount.toStringAsFixed(2)}';

          final double bulletIndent = 3.0;
          graphics.drawString(
            discountText,
            smallFont,
            bounds: Rect.fromLTWH(
              colItemX + bulletIndent,
              yPos,
              itemWidth + qtyWidth + priceWidth - bulletIndent,
              7,
            ),
          );
          graphics.drawString(
            '- Rs ${discountAmount.toStringAsFixed(2)}',
            smallFont,
            bounds: Rect.fromLTWH(colTotalX, yPos, totalWidth, 7),
            format: PdfStringFormat(alignment: PdfTextAlignment.right),
          );
          yPos += extraLineHeight;
        }
      }

      yPos += 3; // Minimal spacing

      // Separator line
      graphics.drawLine(
        PdfPen(PdfColor(0, 0, 0), width: 0.5),
        Offset(leftMarginPx, yPos),
        Offset(receiptWidthPx - rightMarginPx, yPos),
      );
      yPos += 6;

      // Totals Section - tight spacing for narrow width
      final double totalsLabelWidth = printableWidth * 0.50;
      final double totalsValueWidth = printableWidth - totalsLabelWidth;

      // Declare variables for calculations - recalculate like Create Purchase
      double discountPercent = double.tryParse(purchase.discountPercent) ?? 0;
      double taxPercent = double.tryParse(purchase.taxPercent) ?? 0;
      double shippingAmount = double.tryParse(purchase.shippingAmt) ?? 0;

      // Subtotal
      graphics.drawString(
        'Subtotal:',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, totalsLabelWidth, 10),
      );
      graphics.drawString(
        'Rs ${subtotal.toStringAsFixed(2)}',
        regularFont,
        bounds: Rect.fromLTWH(
          leftMarginPx + totalsLabelWidth,
          yPos,
          totalsValueWidth,
          10,
        ),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
      yPos += 8;

      // Discount - use stored value to align with API
      if (discountPercent > 0) {
        final String discountLabel =
            'Discount (${discountPercent.toStringAsFixed(0)}%):';
        double discountAmount = double.tryParse(purchase.discountAmt) ?? 0;
        graphics.drawString(
          discountLabel,
          regularFont,
          bounds: Rect.fromLTWH(leftMarginPx, yPos, totalsLabelWidth, 10),
        );
        graphics.drawString(
          '- Rs ${discountAmount.toStringAsFixed(2)}',
          regularFont,
          bounds: Rect.fromLTWH(
            leftMarginPx + totalsLabelWidth,
            yPos,
            totalsValueWidth,
            10,
          ),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        yPos += 8;
      }

      // Tax - use stored value to align with API (tax on amount after discount)
      if (taxPercent > 0) {
        double taxAmount = double.tryParse(purchase.taxAmt) ?? 0;

        graphics.drawString(
          'Tax (${taxPercent.toStringAsFixed(0)}%):',
          regularFont,
          bounds: Rect.fromLTWH(leftMarginPx, yPos, totalsLabelWidth, 10),
        );
        graphics.drawString(
          'Rs ${taxAmount.toStringAsFixed(2)}',
          regularFont,
          bounds: Rect.fromLTWH(
            leftMarginPx + totalsLabelWidth,
            yPos,
            totalsValueWidth,
            10,
          ),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        yPos += 8;
      }

      // Shipping
      if (shippingAmount > 0) {
        graphics.drawString(
          'Shipping:',
          regularFont,
          bounds: Rect.fromLTWH(leftMarginPx, yPos, totalsLabelWidth, 10),
        );
        graphics.drawString(
          'Rs ${shippingAmount.toStringAsFixed(2)}',
          regularFont,
          bounds: Rect.fromLTWH(
            leftMarginPx + totalsLabelWidth,
            yPos,
            totalsValueWidth,
            10,
          ),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        yPos += 8;
      }

      // Separator
      graphics.drawLine(
        PdfPen(PdfColor(0, 0, 0), width: 1.0),
        Offset(leftMarginPx, yPos),
        Offset(receiptWidthPx - rightMarginPx, yPos),
      );
      yPos += 6;

      // Grand Total - use stored value to align with API
      double total = double.tryParse(purchase.invAmount) ?? 0;

      graphics.drawString(
        'TOTAL:',
        boldFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, totalsLabelWidth, 10),
      );
      graphics.drawString(
        'Rs ${total.toStringAsFixed(2)}',
        boldFont,
        bounds: Rect.fromLTWH(
          leftMarginPx + totalsLabelWidth,
          yPos,
          totalsValueWidth,
          10,
        ),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
      yPos += 10;

      // Notes
      if (purchase.description.isNotEmpty) {
        graphics.drawString(
          'Notes: ${purchase.description}',
          smallFont,
          bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 20),
        );
        yPos += 16;
      }

      // Payment Info - tight spacing
      graphics.drawString(
        'Status: ${purchase.paymentStatus.toUpperCase()}',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
      );
      yPos += 8;

      // Separator
      graphics.drawLine(
        PdfPen(PdfColor(0, 0, 0), width: 0.5),
        Offset(leftMarginPx, yPos),
        Offset(receiptWidthPx - rightMarginPx, yPos),
      );
      yPos += 6;

      // Footer - tight spacing
      graphics.drawString(
        'Thank you!',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.top,
        ),
      );
      yPos += 8;

      graphics.drawString(
        'Dhanpuri by Get Going Pos System',
        smallFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 8),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.top,
        ),
      );

      // Add minimal bottom margin (3 points) and resize page to fit content exactly
      yPos += 3; // Minimal bottom margin after last text

      // Resize page to actual content height (80mm width, auto height)
      section.pageSettings.size = Size(pageWidthInPoints, yPos);

      // Save PDF
      final List<int> bytes = await document.save();
      document.dispose();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Save and share the PDF directly (80mm thermal receipt, flexible height)
      // No print dialog - directly saves like barcode printing
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename:
            'purchase_invoice_${purchase.purInvId}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Invoice saved successfully')),
              ],
            ),
            backgroundColor: Color(0xFF28A745),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Failed to generate invoice: $e')),
              ],
            ),
            backgroundColor: Color(0xFFDC3545),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    }
  }

  // Helper method for modern info cards
  Widget _buildInfoCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Color(0xFFDEE2E6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0D1845),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  // Helper method for modern detail rows
  Widget _buildModernDetailRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Color(0xFF6C757D)),
          SizedBox(width: 10),
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Color(0xFF6C757D),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? 'N/A' : value,
              style: TextStyle(
                color: Color(0xFF343A40),
                fontSize: 13,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper method for financial rows
  Widget _buildFinancialRow(
    String label,
    String value,
    Color color, {
    bool isTotal = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isTotal ? 16 : 14,
            fontWeight: isTotal ? FontWeight.bold : FontWeight.w500,
            color: isTotal ? color : Color(0xFF6C757D),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isTotal ? 18 : 14,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  // Delete purchase
  Future<void> _deletePurchase(
    String purchaseId,
    String purchaseBarcode,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.red, size: 28),
              const SizedBox(width: 12),
              Text('Delete Purchase'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete purchase "$purchaseBarcode"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        await PurchaseService.deletePurchase(purchaseId);

        final purchaseProvider = Provider.of<PurchaseProvider>(
          context,
          listen: false,
        );

        // Remove from local cache
        List<Purchase> updatedPurchases = List.from(purchaseProvider.purchases);
        updatedPurchases.removeWhere(
          (purchase) => purchase.purInvId.toString() == purchaseId,
        );
        purchaseProvider.setPurchases(updatedPurchases);

        // Re-apply filters to update the display
        _applyFiltersClientSide();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to delete purchase: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  int _getTotalPages() {
    if (_allFilteredPurchases.isEmpty) return 1;
    return (_allFilteredPurchases.length / itemsPerPage).ceil();
  }

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
          margin: EdgeInsets.symmetric(horizontal: 1),
          child: ElevatedButton(
            onPressed: i == current ? null : () => _changePage(i),
            style: ElevatedButton.styleFrom(
              backgroundColor: i == current ? Color(0xFF17A2B8) : Colors.white,
              foregroundColor: i == current ? Colors.white : Color(0xFF6C757D),
              elevation: i == current ? 2 : 0,
              side: i == current ? null : BorderSide(color: Color(0xFFDEE2E6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size(32, 32),
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

  Color _getPaymentStatusColor(String paymentStatus) {
    switch (paymentStatus.toLowerCase()) {
      case 'paid':
        return const Color(0xFF28A745); // Green
      case 'unpaid':
        return const Color(0xFFDC3545); // Red
      case 'partial':
        return const Color(0xFFFFA726); // Orange
      default:
        return const Color(0xFF6C757D); // Gray
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Listing'),
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
        child: Column(
          children: [
            // Header with Summary Cards
            Container(
              padding: const EdgeInsets.all(8),
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
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.shopping_bag,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Purchase Management',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Track and manage all purchase transactions',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreatePurchasePage(),
                            ),
                          );

                          // If purchase was created successfully, force refresh to show new purchase at top
                          if (result == true) {
                            setState(() {
                              currentPage = 1; // Reset to first page
                              _isLoading = true;
                            });
                            await _fetchAllPurchasesOnInit(forceRefresh: true);
                          }
                        },
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Purchase'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D1845),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        onPressed: exportToPDF,
                        icon: const Icon(Icons.picture_as_pdf, size: 14),
                        label: Text(
                          _selectedPurchaseIds.isEmpty
                              ? 'Export PDF'
                              : 'Export PDF (${_selectedPurchaseIds.length})',
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF28A745),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Summary Cards
                  Row(
                    children: [
                      _buildSummaryCard(
                        'Total Purchases',
                        '${Provider.of<PurchaseProvider>(context).purchases.length}',
                        Icons.shopping_bag,
                        const Color(0xFF2196F3),
                      ),
                      const SizedBox(width: 8),
                      _buildSummaryCard(
                        'Total Amount',
                        'Rs. ${_getTotalPurchaseAmount().toStringAsFixed(2)}',
                        Icons.attach_money,
                        const Color(0xFF4CAF50),
                      ),
                      const SizedBox(width: 8),
                      _buildSummaryCard(
                        'Paid Amount',
                        'Rs. ${_getTotalPaidAmount().toStringAsFixed(2)}',
                        Icons.check_circle,
                        const Color(0xFF8BC34A),
                      ),
                      const SizedBox(width: 8),
                      _buildSummaryCard(
                        'Due Amount',
                        'Rs. ${_getTotalDueAmount().toStringAsFixed(2)}',
                        Icons.pending,
                        const Color(0xFFFF9800),
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
                    // Compact Filters Row (mirrors invoices page)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[200]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Time Filter
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Color(0xFF0D1845),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Time Period',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF343A40),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6),
                                Container(
                                  height: 36,
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedTimeFilter,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Color(0xFFDEE2E6),
                                        ),
                                      ),
                                    ),
                                    items: ['All', 'Day', 'Month', 'Year']
                                        .map(
                                          (filter) => DropdownMenuItem(
                                            value: filter,
                                            child: Text(
                                              filter,
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value != null && mounted) {
                                        setState(
                                          () => _selectedTimeFilter = value,
                                        );
                                        _applyFiltersClientSide();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 12),

                          // Payment Status Filter
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.payment,
                                      size: 16,
                                      color: Color(0xFF0D1845),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Payment Status',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF343A40),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6),
                                Container(
                                  height: 36,
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedPaymentStatus,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Color(0xFFDEE2E6),
                                        ),
                                      ),
                                    ),
                                    items: ['All', 'Paid', 'Unpaid', 'Partial']
                                        .map(
                                          (filter) => DropdownMenuItem(
                                            value: filter,
                                            child: Text(
                                              filter,
                                              style: TextStyle(fontSize: 13),
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value != null && mounted) {
                                        setState(
                                          () => _selectedPaymentStatus = value,
                                        );
                                        _applyFiltersClientSide();
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),

                          SizedBox(width: 12),

                          // Date Range Filter
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.date_range,
                                      size: 16,
                                      color: Color(0xFF0D1845),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Date Range',
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
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate:
                                                _fromDate ?? DateTime.now(),
                                            firstDate: DateTime(2000),
                                            lastDate: DateTime(2100),
                                          );
                                          if (picked != null && mounted) {
                                            setState(() {
                                              _fromDate = picked;
                                              currentPage = 1;
                                            });
                                            _applyFiltersClientSide();
                                          }
                                        },
                                        child: InputDecorator(
                                          decoration: InputDecoration(
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: Color(0xFFDEE2E6),
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            _fromDate != null
                                                ? DateFormat(
                                                    'dd MMM yyyy',
                                                  ).format(_fromDate!)
                                                : 'From',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: InkWell(
                                        onTap: () async {
                                          final picked = await showDatePicker(
                                            context: context,
                                            initialDate:
                                                _toDate ?? DateTime.now(),
                                            firstDate: DateTime(2000),
                                            lastDate: DateTime(2100),
                                          );
                                          if (picked != null && mounted) {
                                            setState(() {
                                              _toDate = picked;
                                              currentPage = 1;
                                            });
                                            _applyFiltersClientSide();
                                          }
                                        },
                                        child: InputDecorator(
                                          decoration: InputDecoration(
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 12,
                                                  vertical: 8,
                                                ),
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              borderSide: BorderSide(
                                                color: Color(0xFFDEE2E6),
                                              ),
                                            ),
                                          ),
                                          child: Text(
                                            _toDate != null
                                                ? DateFormat(
                                                    'dd MMM yyyy',
                                                  ).format(_toDate!)
                                                : 'To',
                                            style: TextStyle(fontSize: 13),
                                          ),
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: 6),
                                    SizedBox(
                                      height: 36,
                                      child: IconButton(
                                        onPressed: () {
                                          if (mounted) {
                                            setState(() {
                                              _fromDate = null;
                                              _toDate = null;
                                              currentPage = 1;
                                            });
                                          }
                                          _applyFiltersClientSide();
                                        },
                                        icon: Icon(
                                          Icons.clear,
                                          size: 18,
                                          color: Color(0xFF6C757D),
                                        ),
                                        tooltip: 'Clear date range',
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          SizedBox(width: 12),

                          // Search
                          Expanded(
                            flex: 3,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.search,
                                      size: 16,
                                      color: Color(0xFF0D1845),
                                    ),
                                    SizedBox(width: 6),
                                    Text(
                                      'Search Purchases',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF343A40),
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 6),
                                Container(
                                  height: 36,
                                  child: TextField(
                                    controller: _searchController,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.white,
                                      hintText:
                                          'Search by invoice, vendor, reference...',
                                      hintStyle: TextStyle(
                                        color: Color(0xFFADB5BD),
                                        fontSize: 13,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: Color(0xFF6C757D),
                                        size: 18,
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        borderSide: BorderSide(
                                          color: Color(0xFFDEE2E6),
                                        ),
                                      ),
                                    ),
                                    onChanged: _onSearchChanged,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
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
                          SizedBox(
                            width: 40,
                            child: Checkbox(
                              value: _selectAll,
                              onChanged: (value) {
                                setState(() {
                                  _selectAll = value ?? false;
                                  if (_selectAll) {
                                    // Select all purchases from _allFilteredPurchases (all pages)
                                    _selectedPurchaseIds = _allFilteredPurchases
                                        .map((p) => p.purInvId.toString())
                                        .toSet();
                                  } else {
                                    _selectedPurchaseIds.clear();
                                  }
                                });
                              },
                              activeColor: const Color(0xFF0D1845),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Text('Vendor Name', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Invoice Number',
                              style: _headerStyle(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Reference Number',
                              style: _headerStyle(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text('Date', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text('Total Amount', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text('Paid Amount', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text('Due Amount', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Payment Status',
                              style: _headerStyle(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text('Actions', style: _headerStyle()),
                          ),
                        ],
                      ),
                    ),

                    // Table Body
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _fetchAllPurchasesOnInit,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _filteredPurchases.isEmpty
                          ? const Center(
                              child: Text(
                                'No purchases found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredPurchases.length,
                              itemBuilder: (context, index) {
                                final purchase = _filteredPurchases[index];

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
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
                                      SizedBox(
                                        width: 40,
                                        child: Checkbox(
                                          value: _selectedPurchaseIds.contains(
                                            purchase.purInvId.toString(),
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedPurchaseIds.add(
                                                  purchase.purInvId.toString(),
                                                );
                                              } else {
                                                _selectedPurchaseIds.remove(
                                                  purchase.purInvId.toString(),
                                                );
                                                _selectAll = false;
                                              }
                                            });
                                          },
                                          activeColor: const Color(0xFF0D1845),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          purchase.vendorName.isNotEmpty
                                              ? purchase.vendorName
                                              : 'N/A',
                                          style: _cellStyle(),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          purchase.purInvId.toString(),
                                          style: _cellStyle(),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          purchase.purInvBarcode.isNotEmpty
                                              ? purchase.purInvBarcode
                                              : 'N/A',
                                          style: _cellStyle(),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          purchase.purDate.isNotEmpty
                                              ? DateFormat(
                                                  'dd MMM yyyy',
                                                ).format(
                                                  DateTime.parse(
                                                    purchase.purDate,
                                                  ),
                                                )
                                              : 'N/A',
                                          style: _cellStyle(),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Rs. ${double.tryParse(purchase.invAmount)?.toStringAsFixed(2) ?? '0.00'}',
                                          style: _cellStyle(),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          purchase.paymentStatus
                                                      .toLowerCase() ==
                                                  'paid'
                                              ? 'Rs. ${double.tryParse(purchase.invAmount)?.toStringAsFixed(2) ?? '0.00'}'
                                              : 'Rs. 0.00',
                                          style: _cellStyle(),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          purchase.paymentStatus
                                                      .toLowerCase() ==
                                                  'paid'
                                              ? 'Rs. 0.00'
                                              : 'Rs. ${double.tryParse(purchase.invAmount)?.toStringAsFixed(2) ?? '0.00'}',
                                          style: _cellStyle(),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            width: 100,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _getPaymentStatusColor(
                                                purchase.paymentStatus,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              purchase.paymentStatus,
                                              style: TextStyle(
                                                color: _getPaymentStatusColor(
                                                  purchase.paymentStatus,
                                                ),
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.visibility,
                                                color: const Color(0xFF0D1845),
                                                size: 18,
                                              ),
                                              onPressed: () {
                                                _viewPurchaseDetails(
                                                  purchase.purInvId.toString(),
                                                );
                                              },
                                              tooltip: 'View Details',
                                              padding: const EdgeInsets.all(6),
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                            // IconButton(
                                            //   icon: Icon(
                                            //     Icons.edit,
                                            //     color: Colors.blue,
                                            //     size: 18,
                                            //   ),
                                            //   onPressed: () {
                                            //     _editPurchase(
                                            //       purchase.purInvId.toString(),
                                            //     );
                                            //   },
                                            //   tooltip: 'Edit',
                                            //   padding: const EdgeInsets.all(6),
                                            //   constraints:
                                            //       const BoxConstraints(),
                                            // ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                                size: 18,
                                              ),
                                              onPressed: () {
                                                _deletePurchase(
                                                  purchase.purInvId.toString(),
                                                  purchase.purInvBarcode,
                                                );
                                              },
                                              tooltip: 'Delete',
                                              padding: const EdgeInsets.all(6),
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
            if (_filteredPurchases.isNotEmpty) ...[
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
                      onPressed: currentPage < _getTotalPages()
                          ? () => _changePage(currentPage + 1)
                          : null,
                      icon: Icon(Icons.chevron_right, size: 14),
                      label: Text('Next', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentPage < _getTotalPages()
                            ? const Color(0xFF0D1845)
                            : Colors.grey.shade300,
                        foregroundColor: currentPage < _getTotalPages()
                            ? Colors.white
                            : Colors.grey.shade600,
                        elevation: currentPage < _getTotalPages() ? 2 : 0,
                        side: currentPage < _getTotalPages()
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
                        'Page $currentPage of ${_getTotalPages()} (${_allFilteredPurchases.length} total)',
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

  Future<void> exportToPDF() async {
    try {
      // Check if any purchases are selected
      if (_selectedPurchaseIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one purchase to export'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Generating PDF...'),
              ],
            ),
          );
        },
      );

      // Get selected purchases for export
      final purchaseProvider = Provider.of<PurchaseProvider>(
        context,
        listen: false,
      );
      final allPurchases = purchaseProvider.purchases
          .where((p) => _selectedPurchaseIds.contains(p.purInvId.toString()))
          .toList();

      // Create PDF document
      final PdfDocument document = PdfDocument();
      document.pageSettings.orientation = PdfPageOrientation.landscape;
      document.pageSettings.margins.all = 20;

      // Create page template for header and footer
      final PdfPageTemplateElement headerTemplate = PdfPageTemplateElement(
        Rect.fromLTWH(0, 0, document.pageSettings.size.width, 50),
      );

      // Add header
      headerTemplate.graphics.drawString(
        'Purchases Report (${allPurchases.length} selected)',
        PdfStandardFont(PdfFontFamily.helvetica, 18, style: PdfFontStyle.bold),
        bounds: Rect.fromLTWH(0, 15, document.pageSettings.size.width, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // Add footer
      final PdfPageTemplateElement footerTemplate = PdfPageTemplateElement(
        Rect.fromLTWH(0, 0, document.pageSettings.size.width, 30),
      );

      footerTemplate.graphics.drawString(
        'Generated on ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}',
        PdfStandardFont(PdfFontFamily.helvetica, 8),
        bounds: Rect.fromLTWH(0, 10, document.pageSettings.size.width, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      document.template.top = headerTemplate;
      document.template.bottom = footerTemplate;

      // Create page
      final PdfPage page = document.pages.add();
      final PdfGrid grid = PdfGrid();

      // Define columns
      grid.columns.add(count: 7);
      grid.headers.add(1);

      // Set column widths
      grid.columns[0].width = 80; // Purchase #
      grid.columns[1].width = 120; // Vendor
      grid.columns[2].width = 80; // Date
      grid.columns[3].width = 100; // Vendor Invoice
      grid.columns[4].width = 80; // Total Amount
      grid.columns[5].width = 80; // Payment Status
      grid.columns[6].width = 100; // Reference

      // Set header style
      final PdfGridRow header = grid.headers[0];
      header.cells[0].value = 'Purchase #';
      header.cells[1].value = 'Vendor';
      header.cells[2].value = 'Date';
      header.cells[3].value = 'Vendor Invoice';
      header.cells[4].value = 'Total Amount';
      header.cells[5].value = 'Payment Status';
      header.cells[6].value = 'Reference';

      // Style headers
      for (int i = 0; i < header.cells.count; i++) {
        header.cells[i].style.font = PdfStandardFont(
          PdfFontFamily.helvetica,
          10,
          style: PdfFontStyle.bold,
        );
        header.cells[i].style.backgroundBrush = PdfSolidBrush(
          PdfColor(0, 123, 255),
        );
        header.cells[i].style.textBrush = PdfBrushes.white;
        header.cells[i].style.stringFormat = PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        );
      }

      // Add data rows
      for (final purchase in allPurchases) {
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = 'PUR-${purchase.purInvId}';
        row.cells[1].value = purchase.vendorName;
        row.cells[2].value = purchase.purDate.isNotEmpty
            ? DateFormat('dd/MM/yyyy').format(DateTime.parse(purchase.purDate))
            : '';
        row.cells[3].value = purchase.venInvNo;
        row.cells[4].value = purchase.invAmount.isNotEmpty
            ? double.tryParse(purchase.invAmount)?.toStringAsFixed(2) ?? '0.00'
            : '0.00';
        row.cells[5].value = purchase.paymentStatus.toUpperCase();
        row.cells[6].value = purchase.venInvRef;

        // Style data cells
        for (int i = 0; i < row.cells.count; i++) {
          row.cells[i].style.font = PdfStandardFont(PdfFontFamily.helvetica, 8);
          row.cells[i].style.stringFormat = PdfStringFormat(
            alignment: PdfTextAlignment.center,
            lineAlignment: PdfVerticalAlignment.middle,
          );
        }
      }

      // Draw grid on page
      grid.draw(
        page: page,
        bounds: Rect.fromLTWH(
          0,
          0,
          page.getClientSize().width,
          page.getClientSize().height,
        ),
      );

      // Save PDF
      final List<int> bytes = await document.save();
      document.dispose();

      // Let user choose save location
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF Report',
        fileName:
            'purchases_report_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFile != null) {
        final File file = File(outputFile);
        await file.writeAsBytes(bytes);

        // Close loading dialog
        Navigator.of(context).pop();

        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF exported successfully to $outputFile'),
            backgroundColor: Colors.green,
            action: SnackBarAction(
              label: 'Open',
              onPressed: () async {
                try {
                  await Process.run('start', [outputFile], runInShell: true);
                } catch (e) {
                  // Ignore if opening fails
                }
              },
            ),
          ),
        );
      } else {
        // Close loading dialog
        Navigator.of(context).pop();
      }
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to export PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  double _getTotalPurchaseAmount() {
    return _allFilteredPurchases.fold(
      0.0,
      (sum, purchase) => sum + (double.tryParse(purchase.invAmount) ?? 0.0),
    );
  }

  double _getTotalPaidAmount() {
    return _allFilteredPurchases.fold(
      0.0,
      (sum, purchase) =>
          sum +
          (purchase.paymentStatus.toLowerCase() == 'paid'
              ? (double.tryParse(purchase.invAmount) ?? 0.0)
              : 0.0),
    );
  }

  double _getTotalDueAmount() {
    return _allFilteredPurchases.fold(
      0.0,
      (sum, purchase) =>
          sum +
          (purchase.paymentStatus.toLowerCase() == 'paid'
              ? 0.0
              : (double.tryParse(purchase.invAmount) ?? 0.0)),
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
}

// Loading dialog widget
class _LoadingPurchaseDialog extends StatelessWidget {
  const _LoadingPurchaseDialog();

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Loading purchase details...',
              style: TextStyle(
                fontSize: 16,
                color: Color(0xFF0D1845),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
