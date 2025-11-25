import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import '../../services/sales_service.dart';
import '../../services/services.dart' show ApiService;
import '../../widgets/thermal_invoice_widget.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';

class InvoicesPage extends StatefulWidget {
  const InvoicesPage({super.key});

  @override
  State<InvoicesPage> createState() => _InvoicesPageState();
}

class _InvoicesPageState extends State<InvoicesPage> {
  // API data
  List<Invoice> _filteredInvoices = [];
  List<Invoice> _allFilteredInvoices =
      []; // Store all filtered invoices for local pagination
  List<Invoice> _allInvoicesCache =
      []; // Cache for all invoices to avoid refetching
  // "All" tab caches (shows data from /pos/showAllInvoices)
  List<Invoice> _filteredAllTabInvoices = [];
  List<Invoice> _allFilteredAllTabInvoices = [];
  List<Invoice> _allAllInvoicesCache = [];
  bool _isLoadingAllTab = true;
  String? _errorMessageAllTab;
  int currentPageAll = 1;
  // Custom Orders (bridals) caches
  List<Invoice> _filteredCustomInvoices = [];
  List<Invoice> _allFilteredCustomInvoices = [];
  List<Invoice> _allCustomInvoicesCache = [];
  bool _isLoadingCustom = false;
  String? _errorMessageCustom;
  int currentPageCustom = 1;
  bool _isLoading = true;
  String? _errorMessage;
  int currentPage = 1;
  final int itemsPerPage = 19;

  // Filter states
  String _selectedTimeFilter = 'All'; // Day, Month, Year, All
  String _selectedPaymentFilter = 'All'; // All, Paid, Unpaid, Partial
  final TextEditingController _searchController = TextEditingController();
  DateTime? _fromDate;
  DateTime? _toDate;

  // Checkbox selection
  Set<int> _selectedInvoiceIds = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    // Load the new "All" tab by default
    _fetchAllAllInvoicesOnInit();
  }

  Future<void> _generateInvoiceFromDetails(
    InvoiceDetailResponse invoiceDetail,
  ) async {
    // Build printable items and totals similar to POS flow
    final List<Map<String, dynamic>> printableItems = [];
    double itemsTotal = 0.0;
    double totalExtras = 0.0;

    for (final d in invoiceDetail.details) {
      final int qty = int.tryParse(d.quantity) ?? 1;
      double price = double.tryParse(d.price) ?? 0.0;

      // If price missing but subtotal available, derive unit price
      if ((price == 0.0) && (d.subtotal > 0) && qty > 0) {
        price = d.subtotal / qty;
      }

      // Preserve extras on the parent item map so the thermal renderer can
      // render them as indented bullet points beneath the parent product.
      final Map<String, dynamic> parentItem = {
        'name': d.productName,
        'quantity': qty,
        'price': price,
      };

      // Add product-level discount information if available
      try {
        // Use the parsed discount fields from InvoiceDetail
        if (d.discountPercent != null && d.discountPercent! > 0) {
          parentItem['discountPercent'] = d.discountPercent;
        }
        if (d.discountAmount != null && d.discountAmount! > 0) {
          parentItem['discountAmount'] = d.discountAmount;
        }
      } catch (_) {}

      try {
        if (d.extras.isNotEmpty) {
          parentItem['extras'] = d.extras;
          // Still account totals for extras
          for (final e in d.extras) {
            totalExtras +=
                double.tryParse(e['amount']?.toString() ?? '') ?? 0.0;
          }
        }
      } catch (_) {}

      printableItems.add(parentItem);
      itemsTotal += price * qty;
    }

    // Try to extract totals, tax and discount from raw response if available
    final raw = invoiceDetail.rawData;
    final double total =
        double.tryParse(invoiceDetail.invAmount) ?? (itemsTotal + totalExtras);
    double tax = 0.0;
    double discount = 0.0;
    try {
      tax =
          double.tryParse(
            raw['tax']?.toString() ?? raw['tax_amount']?.toString() ?? '',
          ) ??
          0.0;
    } catch (_) {}
    try {
      discount =
          double.tryParse(
            raw['discAmount']?.toString() ??
                raw['disc_amount']?.toString() ??
                '',
          ) ??
          0.0;
    } catch (_) {}

    final double subtotal = (total - tax + discount);

    // Payment method extraction (best-effort)
    String paymentMethod = 'Cash';
    try {
      final pm = raw['payment_mode'];
      if (pm is Map) {
        paymentMethod =
            pm['title']?.toString() ?? pm['name']?.toString() ?? paymentMethod;
      } else if (pm is String) {
        paymentMethod = pm;
      }
    } catch (_) {}

    final String customerName = invoiceDetail.customerName.isNotEmpty
        ? invoiceDetail.customerName
        : 'Walk-in Customer';
    final DateTime invoiceDate =
        DateTime.tryParse(invoiceDetail.invDate) ?? DateTime.now();
    final String salesmanName = raw['employee'] is Map
        ? (raw['employee']['name']?.toString() ?? '')
        : (raw['salesman']?.toString() ?? '');
    final double paidAmount = double.tryParse(invoiceDetail.paidAmount) ?? 0.0;
    final String? dueDate = raw['due_date']?.toString();
    final String? paymentStatus = raw['payment_status']?.toString();

    // Trigger thermal receipt generation (opens print dialog)
    await ThermalInvoiceGenerator.printThermalReceipt(
      context: context,
      invoiceNumber: invoiceDetail.invId,
      invoiceDate: invoiceDate,
      customerName: customerName,
      items: printableItems,
      subtotal: subtotal,
      tax: tax,
      discount: discount,
      total: total,
      paymentMethod: paymentMethod,
      paidAmount: paidAmount,
      salesmanName: salesmanName.isNotEmpty ? salesmanName : null,
      advance: null,
      dueDate: dueDate,
      paymentStatus: paymentStatus,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Invoice printed (INV-${invoiceDetail.invId})'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  // Active tab: 0 = Regular Orders, 1 = Custom Orders
  int _activeTabIndex = 0;

  // Refresh method to force reload data from server

  // Fetch all Custom Orders (bridals) when custom tab is opened
  Future<void> _fetchAllCustomInvoicesOnInit() async {
    try {
      if (mounted) {
        setState(() {
          _errorMessageCustom = null;
          _isLoadingCustom = true;
        });
      }

      // Clear existing cache to force fresh data
      _allCustomInvoicesCache.clear();
      _allFilteredCustomInvoices.clear();
      _filteredCustomInvoices.clear();

      // Fetch all bridals from all pages
      List<Invoice> allInvoices = [];
      int currentFetchPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        try {
          final response = await SalesService.getBridals(
            page: currentFetchPage,
            limit: 50,
          );

          // Debug: log fetched page count
          print(
            '📡 Bridals fetch page $currentFetchPage -> ${response.data.length} items',
          );

          allInvoices.addAll(response.data);

          if (response.meta.currentPage >= response.meta.lastPage) {
            hasMorePages = false;
          } else {
            currentFetchPage++;
          }
        } catch (e) {
          print('❌ Error fetching bridals page $currentFetchPage: $e');
          hasMorePages = false;
        }
      }

      _allCustomInvoicesCache = allInvoices;
      // Sort by invoice date descending (recent first)
      _allCustomInvoicesCache.sort(
        (a, b) =>
            DateTime.parse(b.invDate).compareTo(DateTime.parse(a.invDate)),
      );
      print(
        '💾 Cached ${_allCustomInvoicesCache.length} bridals total (sorted by date descending)',
      );

      // Apply initial filters for custom invoices
      _applyFiltersClientSideCustom();
      if (mounted) {
        setState(() {
          _isLoadingCustom = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessageCustom =
              'Failed to load custom orders. Please refresh the page.';
          _isLoadingCustom = false;
        });
      }
    }
  }

  // Fetch all invoices once when page loads
  Future<void> _fetchAllInvoicesOnInit() async {
    try {
      print(' Initial load: Fetching all invoices');
      if (mounted) {
        setState(() {
          _errorMessage = null;
          _isLoading =
              true; // show loading spinner while fetching regular invoices
        });
      }

      // Clear existing cache to force fresh data
      _allInvoicesCache.clear();
      _allFilteredInvoices.clear();
      _filteredInvoices.clear();

      // Fetch all invoices from all pages
      List<Invoice> allInvoices = [];
      int currentFetchPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        try {
          print('📡 Fetching page $currentFetchPage');
          final response = await SalesService.getInvoices(
            page: currentFetchPage,
            limit: 50, // Use larger page size for efficiency
          );

          allInvoices.addAll(response.data);
          print(
            '📦 Page $currentFetchPage: ${response.data.length} invoices (total: ${allInvoices.length})',
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

      _allInvoicesCache = allInvoices;
      // Sort by invoice date descending (recent first)
      _allInvoicesCache.sort(
        (a, b) =>
            DateTime.parse(b.invDate).compareTo(DateTime.parse(a.invDate)),
      );
      print(
        '💾 Cached ${_allInvoicesCache.length} total invoices (sorted by date descending)',
      );

      // Update provider cache
      final salesProvider = Provider.of<SalesProvider>(context, listen: false);
      salesProvider.setInvoices(_allInvoicesCache);

      // Apply initial filters (which will be no filters, showing all invoices)
      _applyFiltersClientSide();
    } catch (e) {
      print('❌ Critical error in _fetchAllInvoicesOnInit: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load invoices. Please refresh the page.';
          _isLoading = false;
        });
      }
    }
  }

  // Pure client-side filtering method
  void _applyFiltersClientSide() {
    try {
      print(
        '🎯 Client-side filtering - time filter: "$_selectedTimeFilter", payment filter: "$_selectedPaymentFilter"',
      );

      // Apply filters to cached invoices (no API calls)
      _filterCachedInvoices();

      print('📦 _allInvoicesCache.length: ${_allInvoicesCache.length}');
      print('🎯 _allFilteredInvoices.length: ${_allFilteredInvoices.length}');
      print('👀 _filteredInvoices.length: ${_filteredInvoices.length}');
    } catch (e) {
      print('❌ Error in _applyFiltersClientSide: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Search error: Please try a different search term';
          _isLoading = false;
        });
      }
    }
  }

  // Apply filters for custom orders
  void _applyFiltersClientSideCustom() {
    try {
      _filterCachedCustomInvoices();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessageCustom =
              'Search error: Please try a different search term';
          _isLoadingCustom = false;
        });
      }
    }
  }

  // Fetch all invoices for the new "All" tab (from /pos/showAllInvoices)
  Future<void> _fetchAllAllInvoicesOnInit() async {
    try {
      if (mounted) {
        setState(() {
          _errorMessageAllTab = null;
          _isLoadingAllTab = true;
        });
      }

      final response = await ApiService.get('/pos/showAllInvoices');

      List<dynamic> items = [];
      if (response.containsKey('data') && response['data'] is List) {
        items = response['data'] as List<dynamic>;
      }

      final List<Invoice> allInvoices = items
          .map((i) => Invoice.fromJson(Map<String, dynamic>.from(i)))
          .toList();

      // Sort by invoice date descending (recent first)
      allInvoices.sort(
        (a, b) =>
            DateTime.parse(b.invDate).compareTo(DateTime.parse(a.invDate)),
      );

      if (mounted) {
        setState(() {
          _allAllInvoicesCache = allInvoices;
        });
      }

      // Apply filters (initially none) and paginate
      _applyFiltersClientSideAll();
    } catch (e) {
      print('📊 All Invoices Tab Error: $e');
      if (mounted) {
        setState(() {
          // Check if it's a 404 "no records" error
          if (e.toString().contains('404') ||
              e.toString().contains('No POS records found')) {
            _allAllInvoicesCache = [];
            _errorMessageAllTab = null; // Don't show error, just empty state
          } else {
            _errorMessageAllTab = 'Failed to load invoices: $e';
          }
          _isLoadingAllTab = false;
        });
      }
    }
  }

  void _applyFiltersClientSideAll() {
    try {
      _filterCachedAllInvoices();
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessageAllTab =
              'Search error: Please try a different search term';
          _isLoadingAllTab = false;
        });
      }
    }
  }

  void _filterCachedAllInvoices() {
    try {
      final searchQuery = _searchController.text.toLowerCase().trim();

      _allFilteredAllTabInvoices = _allAllInvoicesCache.where((invoice) {
        try {
          bool searchMatch = true;
          if (searchQuery.isNotEmpty) {
            final invoiceIdStr = invoice.invId.toString();
            final customerName = invoice.customerName.toLowerCase();
            final salesmanName = (invoice.salesmanName ?? '').toLowerCase();

            searchMatch =
                invoiceIdStr.contains(searchQuery) ||
                customerName.contains(searchQuery) ||
                salesmanName.contains(searchQuery);
          }

          bool dateMatch = true;
          final invoiceDate = DateTime.parse(invoice.invDate);

          if (_fromDate != null || _toDate != null) {
            if (_fromDate != null && invoiceDate.isBefore(_fromDate!)) {
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
              if (invoiceDate.isAfter(toEnd)) {
                dateMatch = false;
              }
            }
          } else {
            final now = DateTime.now();
            if (_selectedTimeFilter == 'Day') {
              dateMatch =
                  invoiceDate.year == now.year &&
                  invoiceDate.month == now.month &&
                  invoiceDate.day == now.day;
            } else if (_selectedTimeFilter == 'Month') {
              dateMatch =
                  invoiceDate.year == now.year &&
                  invoiceDate.month == now.month;
            } else if (_selectedTimeFilter == 'Year') {
              dateMatch = invoiceDate.year == now.year;
            }
          }

          bool paymentMatch = true;
          if (_selectedPaymentFilter != 'All') {
            if (_selectedPaymentFilter == 'Paid') {
              paymentMatch = invoice.paidAmount >= invoice.invAmount;
            } else if (_selectedPaymentFilter == 'Unpaid') {
              paymentMatch = invoice.paidAmount == 0;
            } else if (_selectedPaymentFilter == 'Partial') {
              paymentMatch =
                  invoice.paidAmount > 0 &&
                  invoice.paidAmount < invoice.invAmount;
            }
          }

          return searchMatch && dateMatch && paymentMatch;
        } catch (e) {
          return false;
        }
      }).toList();

      // Paginate
      if (_allFilteredAllTabInvoices.isEmpty) {
        if (mounted) setState(() => _filteredAllTabInvoices = []);
        return;
      }

      final startIndex = (currentPageAll - 1) * itemsPerPage;
      final endIndex = startIndex + itemsPerPage;

      if (startIndex >= _allFilteredAllTabInvoices.length) {
        if (mounted) setState(() => currentPageAll = 1);
        _filterCachedAllInvoices();
        return;
      }

      if (mounted) {
        setState(() {
          _filteredAllTabInvoices = _allFilteredAllTabInvoices.sublist(
            startIndex,
            endIndex > _allFilteredAllTabInvoices.length
                ? _allFilteredAllTabInvoices.length
                : endIndex,
          );
          _isLoadingAllTab = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _filteredAllTabInvoices = [];
          currentPageAll = 1;
        });
      }
    }
  }

  Future<void> _changePageAll(int newPage) async {
    if (mounted) setState(() => currentPageAll = newPage);
    if (_allAllInvoicesCache.isNotEmpty) {
      _filterCachedAllInvoices();
    }
  }

  int _getTotalPagesAll() {
    if (_allFilteredAllTabInvoices.isEmpty) return 1;
    return (_allFilteredAllTabInvoices.length / itemsPerPage).ceil();
  }

  void _filterCachedCustomInvoices() {
    try {
      final searchQuery = _searchController.text.toLowerCase().trim();

      _allFilteredCustomInvoices = _allCustomInvoicesCache.where((invoice) {
        try {
          bool searchMatch = true;
          if (searchQuery.isNotEmpty) {
            final invoiceIdStr = invoice.invId.toString();
            final customerName = invoice.customerName.toLowerCase();
            final salesmanName = (invoice.salesmanName ?? '').toLowerCase();

            searchMatch =
                invoiceIdStr.contains(searchQuery) ||
                customerName.contains(searchQuery) ||
                salesmanName.contains(searchQuery);
          }

          bool dateMatch = true;
          final invoiceDate = DateTime.parse(invoice.invDate);

          if (_fromDate != null || _toDate != null) {
            if (_fromDate != null && invoiceDate.isBefore(_fromDate!)) {
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
              if (invoiceDate.isAfter(toEnd)) {
                dateMatch = false;
              }
            }
          } else {
            final now = DateTime.now();
            if (_selectedTimeFilter == 'Day') {
              dateMatch =
                  invoiceDate.year == now.year &&
                  invoiceDate.month == now.month &&
                  invoiceDate.day == now.day;
            } else if (_selectedTimeFilter == 'Month') {
              dateMatch =
                  invoiceDate.year == now.year &&
                  invoiceDate.month == now.month;
            } else if (_selectedTimeFilter == 'Year') {
              dateMatch = invoiceDate.year == now.year;
            }
          }

          bool paymentMatch = true;
          if (_selectedPaymentFilter != 'All') {
            if (_selectedPaymentFilter == 'Paid') {
              paymentMatch = invoice.paidAmount >= invoice.invAmount;
            } else if (_selectedPaymentFilter == 'Unpaid') {
              paymentMatch = invoice.paidAmount == 0;
            } else if (_selectedPaymentFilter == 'Partial') {
              paymentMatch =
                  invoice.paidAmount > 0 &&
                  invoice.paidAmount < invoice.invAmount;
            }
          }

          return searchMatch && dateMatch && paymentMatch;
        } catch (e) {
          return false;
        }
      }).toList();

      _paginateFilteredCustomInvoices();

      if (mounted) {
        setState(() {
          _isLoadingCustom = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessageCustom =
              'Search failed. Please try again with a simpler search term.';
          _isLoadingCustom = false;
          _filteredCustomInvoices = [];
          _allFilteredCustomInvoices = [];
        });
      }
    }
  }

  void _paginateFilteredCustomInvoices() {
    try {
      if (_allFilteredCustomInvoices.isEmpty) {
        if (mounted) setState(() => _filteredCustomInvoices = []);
        return;
      }

      final startIndex = (currentPageCustom - 1) * itemsPerPage;
      final endIndex = startIndex + itemsPerPage;

      if (startIndex >= _allFilteredCustomInvoices.length) {
        if (mounted) setState(() => currentPageCustom = 1);
        _paginateFilteredCustomInvoices();
        return;
      }

      if (mounted) {
        setState(() {
          _filteredCustomInvoices = _allFilteredCustomInvoices.sublist(
            startIndex,
            endIndex > _allFilteredCustomInvoices.length
                ? _allFilteredCustomInvoices.length
                : endIndex,
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _filteredCustomInvoices = [];
          currentPageCustom = 1;
        });
      }
    }
  }

  Future<void> _changePageCustom(int newPage) async {
    if (mounted) setState(() => currentPageCustom = newPage);
    if (_allCustomInvoicesCache.isNotEmpty) {
      _paginateFilteredCustomInvoices();
    }
  }

  int _getTotalPagesCustom() {
    if (_allFilteredCustomInvoices.isEmpty) return 1;
    return (_allFilteredCustomInvoices.length / itemsPerPage).ceil();
  }

  // Filter cached invoices without any API calls
  void _filterCachedInvoices() {
    try {
      final searchQuery = _searchController.text.toLowerCase().trim();

      // Apply filters to cached invoices
      _allFilteredInvoices = _allInvoicesCache.where((invoice) {
        try {
          // Search filtering
          bool searchMatch = true;
          if (searchQuery.isNotEmpty) {
            final invoiceIdStr = invoice.invId.toString();
            final customerName = invoice.customerName.toLowerCase();
            final salesmanName = (invoice.salesmanName ?? '').toLowerCase();

            searchMatch =
                invoiceIdStr.contains(searchQuery) ||
                customerName.contains(searchQuery) ||
                salesmanName.contains(searchQuery);
          }

          // Date filtering: if explicit date range selected use it,
          // otherwise fall back to the time filter (Day/Month/Year/All).
          bool dateMatch = true;
          final invoiceDate = DateTime.parse(invoice.invDate);

          if (_fromDate != null || _toDate != null) {
            if (_fromDate != null && invoiceDate.isBefore(_fromDate!)) {
              dateMatch = false;
            }
            if (_toDate != null) {
              // include the whole day for the 'to' date
              final toEnd = DateTime(
                _toDate!.year,
                _toDate!.month,
                _toDate!.day,
                23,
                59,
                59,
              );
              if (invoiceDate.isAfter(toEnd)) {
                dateMatch = false;
              }
            }
          } else {
            final now = DateTime.now();
            if (_selectedTimeFilter == 'Day') {
              dateMatch =
                  invoiceDate.year == now.year &&
                  invoiceDate.month == now.month &&
                  invoiceDate.day == now.day;
            } else if (_selectedTimeFilter == 'Month') {
              dateMatch =
                  invoiceDate.year == now.year &&
                  invoiceDate.month == now.month;
            } else if (_selectedTimeFilter == 'Year') {
              dateMatch = invoiceDate.year == now.year;
            }
          }

          // Payment status filtering based on paid amount
          bool paymentMatch = true;
          if (_selectedPaymentFilter != 'All') {
            if (_selectedPaymentFilter == 'Paid') {
              // Fully paid: paidAmount >= invAmount
              paymentMatch = invoice.paidAmount >= invoice.invAmount;
            } else if (_selectedPaymentFilter == 'Unpaid') {
              // Not paid at all: paidAmount == 0
              paymentMatch = invoice.paidAmount == 0;
            } else if (_selectedPaymentFilter == 'Partial') {
              // Partially paid: 0 < paidAmount < invAmount
              paymentMatch =
                  invoice.paidAmount > 0 &&
                  invoice.paidAmount < invoice.invAmount;
            }
          }

          return searchMatch && dateMatch && paymentMatch;
        } catch (e) {
          print('❌ Error filtering invoice ${invoice.invId}: $e');
          return false; // Skip problematic invoices
        }
      }).toList();

      print(
        '🔍 After filtering: ${_allFilteredInvoices.length} invoices match criteria',
      );

      // Apply local pagination to filtered results
      _paginateFilteredInvoices();

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      print('❌ Critical error in _filterCachedInvoices: $e');
      if (mounted) {
        setState(() {
          _errorMessage =
              'Search failed. Please try again with a simpler search term.';
          _isLoading = false;
          // Fallback: show empty results instead of crashing
          _filteredInvoices = [];
          _allFilteredInvoices = [];
        });
      }
    }
  }

  // Apply local pagination to filtered invoices
  void _paginateFilteredInvoices() {
    try {
      // Handle empty results case
      if (_allFilteredInvoices.isEmpty) {
        if (mounted) {
          setState(() {
            _filteredInvoices = [];
          });
        }
        return;
      }

      final startIndex = (currentPage - 1) * itemsPerPage;
      final endIndex = startIndex + itemsPerPage;

      // Ensure startIndex is not greater than the list length
      if (startIndex >= _allFilteredInvoices.length) {
        // Reset to page 1 if current page is out of bounds
        if (mounted) {
          setState(() {
            currentPage = 1;
          });
        }
        _paginateFilteredInvoices(); // Recursive call with corrected page
        return;
      }

      if (mounted) {
        setState(() {
          _filteredInvoices = _allFilteredInvoices.sublist(
            startIndex,
            endIndex > _allFilteredInvoices.length
                ? _allFilteredInvoices.length
                : endIndex,
          );
        });
      }

      print(
        'Paginated to ${_filteredInvoices.length} items for display (page $currentPage)',
      );
    } catch (e) {
      print('❌ Error in _paginateFilteredInvoices: $e');
      if (mounted) {
        setState(() {
          _filteredInvoices = [];
          currentPage = 1;
        });
      }
    }
  }

  // Handle page changes
  Future<void> _changePage(int newPage) async {
    if (mounted) {
      setState(() {
        currentPage = newPage;
      });
    }

    // Use client-side pagination when we have cached invoices
    if (_allInvoicesCache.isNotEmpty) {
      _paginateFilteredInvoices();
    }
  }

  int _getTotalPages() {
    if (_allFilteredInvoices.isEmpty) return 1;
    return (_allFilteredInvoices.length / itemsPerPage).ceil();
  }

  List<Widget> _buildPageButtons({
    int? current,
    int? totalPages,
    Function(int)? onPageSelected,
  }) {
    final total = totalPages ?? _getTotalPages();
    final currentLocal = current ?? currentPage;
    final onSelect = onPageSelected ?? (int i) => _changePage(i);

    // Show max 5 page buttons centered around current page
    const maxButtons = 5;
    final halfRange = maxButtons ~/ 2; // 2

    // Calculate desired start and end
    int startPage = (currentLocal - halfRange).clamp(1, total);
    int endPage = (startPage + maxButtons - 1).clamp(1, total);

    // If endPage exceeds totalPages, adjust startPage
    if (endPage > total) {
      endPage = total;
      startPage = (endPage - maxButtons + 1).clamp(1, total);
    }

    List<Widget> buttons = [];

    for (int i = startPage; i <= endPage; i++) {
      buttons.add(
        Container(
          margin: EdgeInsets.symmetric(horizontal: 1),
          child: ElevatedButton(
            onPressed: i == currentLocal ? null : () => onSelect(i),
            style: ElevatedButton.styleFrom(
              backgroundColor: i == currentLocal
                  ? Color(0xFF17A2B8)
                  : Colors.white,
              foregroundColor: i == currentLocal
                  ? Colors.white
                  : Color(0xFF6C757D),
              elevation: i == currentLocal ? 2 : 0,
              side: i == currentLocal
                  ? null
                  : BorderSide(color: Color(0xFFDEE2E6)),
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

  void _viewInvoiceDetails(Invoice invoice) async {
    // Show loading dialog and capture its own BuildContext so we always
    // close the correct dialog (prevents popping the underlying page
    // or calling Navigator.pop on a disposed context).
    late BuildContext dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        dialogContext = ctx;
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Loading invoice details...'),
            ],
          ),
        );
      },
    );

    try {
      // If active tab is Custom Orders (2), fetch bridals detail endpoint
      final invoiceDetail = _activeTabIndex == 2
          ? await SalesService.getBridalById(invoice.invId)
          : await SalesService.getInvoiceById(invoice.invId);

      // Close loading dialog and show details dialog
      try {
        Navigator.of(dialogContext).pop(); // Close loading dialog
      } catch (_) {}

      if (mounted) _showInvoiceDetailsDialog(invoiceDetail);
    } catch (e) {
      // Ensure loading dialog closed
      try {
        Navigator.of(dialogContext).pop(); // Close loading dialog
      } catch (_) {}

      if (!mounted) return;

      final raw = e.toString();
      final sanitized = _sanitizeErrorMessage(raw);

      // Build a helpful error dialog. In debug mode show request URL and
      // a truncated raw response so developers can triage without exposing
      // large HTML dumps to normal users.
      final requestUrl = _activeTabIndex == 2
          ? '${ApiService.baseUrl}${SalesService.invoicesEndpoint}/pos-bridals/${invoice.invId}'
          : '${ApiService.baseUrl}${SalesService.invoicesEndpoint}/${invoice.invId}';

      showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text('Failed to load invoice details'),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(sanitized),
                  const SizedBox(height: 12),
                  if (kDebugMode) ...[
                    const Text(
                      'Debug information (visible in debug mode):',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    Text('Request URL:', style: TextStyle(fontSize: 12)),
                    SelectableText(requestUrl, style: TextStyle(fontSize: 12)),
                    const SizedBox(height: 8),
                    Text(
                      'Raw response (truncated):',
                      style: TextStyle(fontSize: 12),
                    ),
                    Container(
                      constraints: BoxConstraints(maxHeight: 260),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          _truncate(raw, 4000),
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    }
  }

  // Remove HTML/script tags from server error responses to avoid showing
  // large debug dumps to end users. Keep messages short and friendly.
  String _sanitizeErrorMessage(String raw) {
    try {
      // Remove script/style blocks
      var s = raw.replaceAll(
        RegExp(r"<script[\s\S]*?<\/script>", caseSensitive: false),
        '',
      );
      s = s.replaceAll(
        RegExp(r"<style[\s\S]*?<\/style>", caseSensitive: false),
        '',
      );
      // Strip remaining HTML tags
      s = s.replaceAll(RegExp(r'<[^>]*>'), '');
      // Trim long messages
      s = s.trim();
      if (s.length > 200) s = s.substring(0, 200) + '...';
      // If message is still empty, return a generic friendly message
      if (s.isEmpty) return 'Server returned an unexpected response.';
      return s;
    } catch (_) {
      return 'Server returned an unexpected response.';
    }
  }

  // Truncate long strings safely for debug display
  String _truncate(String s, int maxLen) {
    try {
      if (s.length <= maxLen) return s;
      return s.substring(0, maxLen) + '\n\n... (truncated)';
    } catch (_) {
      return '... (unable to show debug output)';
    }
  }

  // Clean product names by removing appended numeric IDs or trailing markers
  // Examples handled: "Product Name - 123", "Product Name (123)", "Product Name #123"
  String _cleanProductName(String name) {
    try {
      if (name.isEmpty) return name;
      // Remove trailing patterns that end with digits, optionally wrapped in () or preceded by - or #
      return name.replaceAll(RegExp(r"[\s\-#\(\[]*\d+[\)\]]*$"), '').trim();
    } catch (_) {
      return name;
    }
  }

  void _deleteInvoice(Invoice invoice) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: const Text(
          'Are you sure you want to delete this invoice? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        // Determine which endpoint to call based on active tab
        if (_activeTabIndex == 2) {
          // Custom Orders (bridals)
          if (mounted) {
            setState(() {
              _errorMessageCustom = null;
              _isLoadingCustom = true;
            });
          }

          await SalesService.deleteBridal(invoice.invId);

          // Remove from custom cache immediately for snappy UI
          if (mounted) {
            setState(() {
              _allCustomInvoicesCache.removeWhere(
                (item) => item.invId == invoice.invId,
              );
            });
          }

          // Re-apply filters for custom tab and reload data from server
          _applyFiltersClientSideCustom();
          await _fetchAllCustomInvoicesOnInit();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Custom order deleted successfully'),
              ),
            );
          }
        } else {
          // Regular invoices
          if (mounted) {
            setState(() {
              _errorMessage = null;
              _isLoading = true;
            });
          }

          await SalesService.deleteInvoice(invoice.invId);

          // Remove from regular cache immediately
          if (mounted) {
            setState(() {
              _allInvoicesCache.removeWhere(
                (item) => item.invId == invoice.invId,
              );
            });
          }

          // Re-apply filters and reload from server
          _applyFiltersClientSide();
          await _fetchAllInvoicesOnInit();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Invoice deleted successfully')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete invoice: $e')),
          );
        }
      }
    }
  }

  // Helper method to show invoice details dialog
  void _showInvoiceDetailsDialog(InvoiceDetailResponse invoiceDetail) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: BoxConstraints(maxWidth: 800, maxHeight: 600),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Invoice Details',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              'INV-${invoiceDetail.invId}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Customer Info
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Customer Information',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D1845),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.person,
                                    color: Color(0xFF0D1845),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    invoiceDetail.customerName.isNotEmpty
                                        ? invoiceDetail.customerName
                                        : 'Walk-in Customer',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Normal Customer',
                                      style: TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(
                                    Icons.calendar_today,
                                    color: Color(0xFF0D1845),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    (() {
                                      try {
                                        return DateFormat('dd MMM yyyy').format(
                                          DateTime.parse(invoiceDetail.invDate),
                                        );
                                      } catch (e) {
                                        print(
                                          '❌ Error parsing invoice date: $e',
                                        );
                                        return 'Invalid Date';
                                      }
                                    })(),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                              // Show employee/salesman for bridals if present
                              if ((invoiceDetail.employeeName ?? '')
                                  .isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person_outline,
                                      color: Color(0xFF0D1845),
                                      size: 18,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      invoiceDetail.employeeName ?? '',
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              // Due Date (for custom orders)
                              if ((invoiceDetail.dueDate ?? '').isNotEmpty) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.event,
                                      color: Color(0xFFFF6B6B),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Due Date: ${(() {
                                        try {
                                          return DateFormat('dd MMM yyyy').format(DateTime.parse(invoiceDetail.dueDate!));
                                        } catch (e) {
                                          return invoiceDetail.dueDate;
                                        }
                                      })()}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFFFF6B6B),
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                              // Description (for bridals/custom orders)
                              if ((invoiceDetail.description ?? '').isNotEmpty)
                                const SizedBox(height: 12),
                              if ((invoiceDetail.description ?? '').isNotEmpty)
                                Text(
                                  invoiceDetail.description ?? '',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey.shade800,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Invoice Items
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Invoice Items',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D1845),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ...invoiceDetail.details.map((detail) {
                                return Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey.shade200,
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 40,
                                            height: 40,
                                            decoration: BoxDecoration(
                                              color: const Color(
                                                0xFF0D1845,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(8),
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
                                                  _cleanProductName(
                                                    detail.productName,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                // Show cleaned product name and omit a separate product id line
                                                // The raw product id is still available in details if needed.
                                                // We intentionally do not show 'Product ID' to keep UI concise.
                                              ],
                                            ),
                                          ),
                                          Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Text(
                                                'Qty: ${detail.quantity}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Rs. ${detail.price}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                'Rs. ${detail.subtotal.toStringAsFixed(2)}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                  color: Color(0xFF0D1845),
                                                ),
                                              ),
                                              if (detail.discountPercentRaw !=
                                                  null) ...[
                                                const SizedBox(height: 4),
                                                Text(
                                                  'Product Discount: ${detail.discountPercentRaw}%',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                              if (detail.discountAmountRaw !=
                                                  null) ...[
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Product Discount: Rs. ${detail.discountAmountRaw}',
                                                  style: const TextStyle(
                                                    fontSize: 11,
                                                    color: Colors.red,
                                                    fontWeight: FontWeight.w500,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ],
                                      ),

                                      // Extras / Add-ons (for custom orders)
                                      if (detail.extras.isNotEmpty) ...[
                                        const SizedBox(height: 10),
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          decoration: BoxDecoration(
                                            color: Colors.grey.shade50,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade200,
                                            ),
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: (detail.extras as List)
                                                .map<Widget>((ex) {
                                                  final title =
                                                      (ex['title'] ??
                                                              ex['name'] ??
                                                              'Add-on')
                                                          .toString();
                                                  final amt =
                                                      double.tryParse(
                                                        ex['amount']
                                                                ?.toString() ??
                                                            '',
                                                      ) ??
                                                      0.0;
                                                  return Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          vertical: 4,
                                                        ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            '• $title',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                              color: Colors
                                                                  .grey
                                                                  .shade800,
                                                            ),
                                                          ),
                                                        ),
                                                        Text(
                                                          'Rs ${amt.toStringAsFixed(2)}',
                                                          style: TextStyle(
                                                            fontSize: 13,
                                                            color: Colors
                                                                .grey
                                                                .shade700,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );
                                                })
                                                .toList(),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                );
                              }),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Amount Summary
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Amount:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Rs. ${double.tryParse(invoiceDetail.invAmount)?.toStringAsFixed(2) ?? '0.00'}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Invoice Discount:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.red,
                                    ),
                                  ),
                                  Text(
                                    'Rs. ${double.tryParse(invoiceDetail.rawData['discAmount']?.toString() ?? '')?.toStringAsFixed(2) ?? '0.00'}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.red,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Tax:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Rs. ${double.tryParse(invoiceDetail.rawData['tax']?.toString() ?? '')?.toStringAsFixed(2) ?? '0.00'}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Total Extras:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    'Rs. ${double.tryParse(invoiceDetail.totalExtraAmount ?? '')?.toStringAsFixed(2) ?? '0.00'}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Paid Amount:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green,
                                    ),
                                  ),
                                  Text(
                                    'Rs. ${double.tryParse(invoiceDetail.paidAmount)?.toStringAsFixed(2) ?? '0.00'}',
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Due Amount:',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          (double.tryParse(
                                                        invoiceDetail.invAmount,
                                                      ) ??
                                                      0) -
                                                  (double.tryParse(
                                                        invoiceDetail
                                                            .paidAmount,
                                                      ) ??
                                                      0) >
                                              0
                                          ? Colors.red
                                          : Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    'Rs. ${((double.tryParse(invoiceDetail.invAmount) ?? 0) - (double.tryParse(invoiceDetail.paidAmount) ?? 0)).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          (double.tryParse(
                                                        invoiceDetail.invAmount,
                                                      ) ??
                                                      0) -
                                                  (double.tryParse(
                                                        invoiceDetail
                                                            .paidAmount,
                                                      ) ??
                                                      0) >
                                              0
                                          ? Colors.red
                                          : Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Action Buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () async {
                                // Close details dialog then generate/print the invoice
                                Navigator.of(context).pop();
                                try {
                                  await _generateInvoiceFromDetails(
                                    invoiceDetail,
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          'Failed to generate invoice: $e',
                                        ),
                                        backgroundColor: Colors.red,
                                      ),
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.receipt_long),
                              label: const Text('Generate Invoice'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D1845),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Close'),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
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
        );
      },
    );
  }

  void _onSearchChanged(String query) {
    // Debounce search to avoid too many API calls
    // For now, just apply filters immediately
    if (mounted) {
      setState(() {
        if (_activeTabIndex == 0) {
          currentPageAll = 1;
        } else if (_activeTabIndex == 1) {
          currentPage = 1;
        } else {
          currentPageCustom = 1;
        }
      });
    }
    _applyFiltersForActiveTab();
  }

  // Apply filters for the currently active tab
  void _applyFiltersForActiveTab() {
    if (_activeTabIndex == 0) {
      _applyFiltersClientSideAll();
    } else if (_activeTabIndex == 1) {
      _applyFiltersClientSide();
    } else {
      _applyFiltersClientSideCustom();
    }
  }

  Color _getPaymentModeColor(String paymentMode) {
    switch (paymentMode.toLowerCase()) {
      case 'cash':
        return Colors.green;
      case 'bank':
        return Colors.blue;
      case 'credit':
        return Colors.orange;
      default:
        return Colors.grey;
    }
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

  @override
  Widget build(BuildContext context) {
    // Compute totals from cached invoices for summary cards.
    // Show totals for the currently active tab: All (0), Regular (1), Custom (2).
    final List<Invoice> sourceInvoices = _activeTabIndex == 0
        ? _allAllInvoicesCache
        : (_activeTabIndex == 1 ? _allInvoicesCache : _allCustomInvoicesCache);

    final totalInvoices = sourceInvoices.length;
    double totalAmount = 0.0;
    double totalPaid = 0.0;
    for (var inv in sourceInvoices) {
      totalAmount += inv.invAmount;
      totalPaid += inv.paidAmount;
    }
    final totalDue = totalAmount - totalPaid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoices'),
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
                          Icons.receipt_long,
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
                              'Invoice Management',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Track and manage all invoice transactions',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // PDF Export Button aligned with text
                      ElevatedButton.icon(
                        onPressed: exportToPDF,
                        icon: const Icon(Icons.picture_as_pdf, size: 14),
                        label: Text(
                          _selectedInvoiceIds.isEmpty
                              ? 'Export PDF'
                              : 'Export PDF (${_selectedInvoiceIds.length})',
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
                        'Total Invoices',
                        totalInvoices.toString(),
                        Icons.receipt_long,
                        const Color(0xFF2196F3),
                      ),
                      const SizedBox(width: 8),
                      _buildSummaryCard(
                        'Total Amount',
                        'Rs ${totalAmount.toStringAsFixed(2)}',
                        Icons.attach_money,
                        const Color(0xFF4CAF50),
                      ),
                      const SizedBox(width: 8),
                      _buildSummaryCard(
                        'Total Paid',
                        'Rs ${totalPaid.toStringAsFixed(2)}',
                        Icons.check_circle,
                        const Color(0xFF8BC34A),
                      ),
                      const SizedBox(width: 8),
                      _buildSummaryCard(
                        'Total Due',
                        'Rs ${totalDue.toStringAsFixed(2)}',
                        Icons.pending,
                        const Color(0xFFFF9800),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Tab selector and Search and Table
            // Tabs: All / Regular Orders / Custom Orders
            Container(
              margin: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _activeTabIndex = 0; // All
                            currentPageAll = 1;
                          });
                          _fetchAllAllInvoicesOnInit();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _activeTabIndex == 0
                            ? const Color(0xFF0D1845)
                            : Colors.white,
                        foregroundColor: _activeTabIndex == 0
                            ? Colors.white
                            : const Color(0xFF0D1845),
                        elevation: _activeTabIndex == 0 ? 2 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: _activeTabIndex == 0
                                ? Colors.transparent
                                : const Color(0xFFDEE2E6),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('All'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _activeTabIndex = 1; // Regular
                            currentPage = 1;
                          });
                          // Always refresh regular invoices when tab clicked
                          _fetchAllInvoicesOnInit();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _activeTabIndex == 1
                            ? const Color(0xFF0D1845)
                            : Colors.white,
                        foregroundColor: _activeTabIndex == 1
                            ? Colors.white
                            : const Color(0xFF0D1845),
                        elevation: _activeTabIndex == 1 ? 2 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: _activeTabIndex == 1
                                ? Colors.transparent
                                : const Color(0xFFDEE2E6),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Regular Orders'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        if (mounted) {
                          setState(() {
                            _activeTabIndex = 2; // Custom
                            currentPageCustom = 1;
                          });
                          // Always refresh custom orders when tab clicked
                          _fetchAllCustomInvoicesOnInit();
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _activeTabIndex == 2
                            ? const Color(0xFF0D1845)
                            : Colors.white,
                        foregroundColor: _activeTabIndex == 2
                            ? Colors.white
                            : const Color(0xFF0D1845),
                        elevation: _activeTabIndex == 2 ? 2 : 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(
                            color: _activeTabIndex == 2
                                ? Colors.transparent
                                : const Color(0xFFDEE2E6),
                          ),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Custom Orders'),
                    ),
                  ),
                ],
              ),
            ),

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
                    // Compact Filters Row
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
                                        setState(() {
                                          _selectedTimeFilter = value;
                                          if (_activeTabIndex == 0) {
                                            currentPageAll = 1;
                                          } else if (_activeTabIndex == 1) {
                                            currentPage = 1;
                                          } else {
                                            currentPageCustom = 1;
                                          }
                                        });
                                        _applyFiltersForActiveTab();
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
                                    value: _selectedPaymentFilter,
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
                                        setState(() {
                                          _selectedPaymentFilter = value;
                                          if (_activeTabIndex == 0) {
                                            currentPageAll = 1;
                                          } else if (_activeTabIndex == 1) {
                                            currentPage = 1;
                                          } else {
                                            currentPageCustom = 1;
                                          }
                                        });
                                        _applyFiltersForActiveTab();
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
                                              if (_activeTabIndex == 0) {
                                                currentPageAll = 1;
                                              } else if (_activeTabIndex == 1) {
                                                currentPage = 1;
                                              } else {
                                                currentPageCustom = 1;
                                              }
                                            });
                                            _applyFiltersForActiveTab();
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
                                              if (_activeTabIndex == 0) {
                                                currentPageAll = 1;
                                              } else if (_activeTabIndex == 1) {
                                                currentPage = 1;
                                              } else {
                                                currentPageCustom = 1;
                                              }
                                            });
                                            _applyFiltersForActiveTab();
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
                                              if (_activeTabIndex == 0) {
                                                currentPageAll = 1;
                                              } else if (_activeTabIndex == 1) {
                                                currentPage = 1;
                                              } else {
                                                currentPageCustom = 1;
                                              }
                                            });
                                          }
                                          _applyFiltersForActiveTab();
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
                                      'Search Invoices',
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
                                          'Search by invoice number, customer...',
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

                    // Table Header - switch between All-tab simplified header and full header
                    if (_activeTabIndex == 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
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
                            SizedBox(
                              width: 40,
                              child: Checkbox(
                                value: _selectAll,
                                onChanged: (value) {
                                  setState(() {
                                    _selectAll = value ?? false;
                                    if (_selectAll) {
                                      // Select all invoices from all pages
                                      _selectedInvoiceIds =
                                          _allFilteredAllTabInvoices
                                              .map((inv) => inv.invId)
                                              .toSet();
                                    } else {
                                      _selectedInvoiceIds.clear();
                                    }
                                  });
                                },
                                activeColor: const Color(0xFF0D1845),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text('Invoice #', style: _headerStyle()),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text('Customer', style: _headerStyle()),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text('Payment', style: _headerStyle()),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text('Paid Amount', style: _headerStyle()),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text('Total', style: _headerStyle()),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text('Due', style: _headerStyle()),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text('Salesman', style: _headerStyle()),
                            ),
                          ],
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
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
                            SizedBox(
                              width: 40,
                              child: Checkbox(
                                value: _selectAll,
                                onChanged: (value) {
                                  setState(() {
                                    _selectAll = value ?? false;
                                    // Select from all pages, not just current page
                                    final List<Invoice> allList =
                                        _activeTabIndex == 1
                                        ? _allFilteredInvoices
                                        : _allFilteredCustomInvoices;
                                    if (_selectAll) {
                                      _selectedInvoiceIds = allList
                                          .map((inv) => inv.invId)
                                          .toSet();
                                    } else {
                                      _selectedInvoiceIds.clear();
                                    }
                                  });
                                },
                                activeColor: const Color(0xFF0D1845),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text('Invoice #', style: _headerStyle()),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text('Customer', style: _headerStyle()),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text('Date', style: _headerStyle()),
                            ),
                            // Show Due Date column only for Custom Orders tab
                            if (_activeTabIndex == 2) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: Text('Due Date', style: _headerStyle()),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text('Total', style: _headerStyle()),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text('Paid Amount', style: _headerStyle()),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text('Due', style: _headerStyle()),
                            ),
                            // For Custom Orders tab, replace Payment with three columns
                            if (_activeTabIndex == 2) ...[
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Inv Amount',
                                  style: _headerStyle(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Extra Expenses',
                                  style: _headerStyle(),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: Text(
                                  'Net Profit',
                                  style: _headerStyle(),
                                ),
                              ),
                            ] else ...[
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: Text('Payment', style: _headerStyle()),
                              ),
                            ],
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text('Salesman', style: _headerStyle()),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Text('Actions', style: _headerStyle()),
                            ),
                          ],
                        ),
                      ),

                    // Table Body
                    Expanded(
                      child: Builder(
                        builder: (context) {
                          final isLoading = _activeTabIndex == 0
                              ? _isLoadingAllTab
                              : (_activeTabIndex == 1
                                    ? _isLoading
                                    : _isLoadingCustom);
                          if (isLoading)
                            return const Center(
                              child: CircularProgressIndicator(),
                            );

                          final errorMsg = _activeTabIndex == 0
                              ? _errorMessageAllTab
                              : (_activeTabIndex == 1
                                    ? _errorMessage
                                    : _errorMessageCustom);
                          if (errorMsg != null) {
                            return Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    errorMsg,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _activeTabIndex == 0
                                        ? _fetchAllAllInvoicesOnInit
                                        : (_activeTabIndex == 1
                                              ? _fetchAllInvoicesOnInit
                                              : _fetchAllCustomInvoicesOnInit),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            );
                          }

                          final List<Invoice> selectedFiltered =
                              _activeTabIndex == 0
                              ? _filteredAllTabInvoices
                              : (_activeTabIndex == 1
                                    ? _filteredInvoices
                                    : _filteredCustomInvoices);
                          if (selectedFiltered.isEmpty) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24.0),
                                child: Text(
                                  _activeTabIndex == 0
                                      ? 'No invoices found for the selected filters.'
                                      : (_activeTabIndex == 1
                                            ? 'No invoices found for the selected filters.'
                                            : 'No custom orders found. If your API returned data, check console logs for details.'),
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Color(0xFF6C757D),
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            );
                          }

                          return Column(
                            children: [
                              Expanded(
                                child: SingleChildScrollView(
                                  child: Column(
                                    children: selectedFiltered.map((invoice) {
                                      if (_activeTabIndex == 0) {
                                        // Simplified row for All tab
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border(
                                              bottom: BorderSide(
                                                color: Colors.grey[100]!,
                                              ),
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              SizedBox(
                                                width: 40,
                                                child: Checkbox(
                                                  value: _selectedInvoiceIds
                                                      .contains(invoice.invId),
                                                  onChanged: (value) {
                                                    setState(() {
                                                      if (value == true) {
                                                        _selectedInvoiceIds.add(
                                                          invoice.invId,
                                                        );
                                                      } else {
                                                        _selectedInvoiceIds
                                                            .remove(
                                                              invoice.invId,
                                                            );
                                                        _selectAll = false;
                                                      }
                                                    });
                                                  },
                                                  activeColor: const Color(
                                                    0xFF0D1845,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  'INV-${invoice.invId}',
                                                  style: _cellStyle(),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  invoice.customerName,
                                                  style: _cellStyle(),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  invoice.paymentMode,
                                                  style: _cellStyle(),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  'Rs. ${invoice.paidAmount.toStringAsFixed(2)}',
                                                  style: _cellStyle(),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  'Rs. ${invoice.invAmount.toStringAsFixed(2)}',
                                                  style: _cellStyle(),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  'Rs. ${invoice.dueAmount.toStringAsFixed(2)}',
                                                  style: _cellStyle(),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  invoice.salesmanName ?? 'N/A',
                                                  style: _cellStyle(),
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }

                                      // Full row for Regular / Custom tabs
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.grey[100]!,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            SizedBox(
                                              width: 40,
                                              child: Checkbox(
                                                value: _selectedInvoiceIds
                                                    .contains(invoice.invId),
                                                onChanged: (value) {
                                                  setState(() {
                                                    if (value == true) {
                                                      _selectedInvoiceIds.add(
                                                        invoice.invId,
                                                      );
                                                    } else {
                                                      _selectedInvoiceIds
                                                          .remove(
                                                            invoice.invId,
                                                          );
                                                      _selectAll = false;
                                                    }
                                                  });
                                                },
                                                activeColor: const Color(
                                                  0xFF0D1845,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'INV-${invoice.invId}',
                                                style: _cellStyle(),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 2,
                                              child: Align(
                                                alignment: Alignment.centerLeft,
                                                child: Text(
                                                  invoice.customerName,
                                                  style: _cellStyle(),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                DateFormat(
                                                  'dd MMM yyyy',
                                                ).format(
                                                  DateTime.parse(
                                                    invoice.invDate,
                                                  ),
                                                ),
                                                style: _cellStyle(),
                                              ),
                                            ),
                                            // Show due date only for Custom Orders tab
                                            if (_activeTabIndex == 2) ...[
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  (() {
                                                    try {
                                                      if (invoice.dueDate !=
                                                              null &&
                                                          invoice
                                                              .dueDate!
                                                              .isNotEmpty) {
                                                        return DateFormat(
                                                          'dd MMM yyyy',
                                                        ).format(
                                                          DateTime.parse(
                                                            invoice.dueDate!,
                                                          ),
                                                        );
                                                      }
                                                    } catch (_) {}
                                                    return invoice.dueDate
                                                            ?.toString() ??
                                                        '';
                                                  })(),
                                                  style: _cellStyle(),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'Rs. ${invoice.invAmount.toStringAsFixed(2)}',
                                                style: _cellStyle(),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'Rs. ${invoice.paidAmount.toStringAsFixed(2)}',
                                                style: _cellStyle(),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                'Rs. ${invoice.dueAmount.toStringAsFixed(2)}',
                                                style: _cellStyle(),
                                              ),
                                            ),
                                            // For Custom Orders tab, replace Payment with three columns
                                            if (_activeTabIndex == 2) ...[
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  'Rs. ${invoice.invAmount.toStringAsFixed(2)}',
                                                  style: _cellStyle(),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  'Rs. ${(invoice.totalExtraExpenses ?? 0).toStringAsFixed(2)}',
                                                  style: _cellStyle(),
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 2,
                                                child: Text(
                                                  'Rs. ${(invoice.netProfit ?? 0).toStringAsFixed(2)}',
                                                  style: _cellStyle(),
                                                ),
                                              ),
                                            ] else ...[
                                              const SizedBox(width: 8),
                                              Expanded(
                                                flex: 2,
                                                child: Align(
                                                  alignment:
                                                      Alignment.centerLeft,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 3,
                                                          vertical: 1,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color:
                                                          _getPaymentModeColor(
                                                            invoice.paymentMode,
                                                          ).withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            2,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      invoice.paymentMode,
                                                      style: TextStyle(
                                                        color:
                                                            _getPaymentModeColor(
                                                              invoice
                                                                  .paymentMode,
                                                            ),
                                                        fontSize: 11,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                invoice.salesmanName ?? 'N/A',
                                                style: _cellStyle(),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 2,
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
                                                      size: 16,
                                                    ),
                                                    onPressed: () =>
                                                        _viewInvoiceDetails(
                                                          invoice,
                                                        ),
                                                    tooltip: 'View Details',
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    constraints:
                                                        const BoxConstraints(),
                                                  ),
                                                  if (_activeTabIndex == 2) ...[
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.add,
                                                        color: Colors.green,
                                                        size: 16,
                                                      ),
                                                      onPressed: () =>
                                                          _showCustomOrderPopup(
                                                            invoice,
                                                          ),
                                                      tooltip:
                                                          'Manage Extras & Expenses',
                                                      padding:
                                                          const EdgeInsets.all(
                                                            6,
                                                          ),
                                                      constraints:
                                                          const BoxConstraints(),
                                                    ),
                                                  ],
                                                  IconButton(
                                                    icon: Icon(
                                                      Icons.delete,
                                                      color: Colors.red,
                                                      size: 18,
                                                    ),
                                                    onPressed: () =>
                                                        _deleteInvoice(invoice),
                                                    tooltip: 'Delete',
                                                    padding:
                                                        const EdgeInsets.all(6),
                                                    constraints:
                                                        const BoxConstraints(),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ),
                              // Pagination Controls
                              Builder(
                                builder: (context) {
                                  final List<Invoice> currentAllFiltered =
                                      _activeTabIndex == 0
                                      ? _allFilteredAllTabInvoices
                                      : (_activeTabIndex == 1
                                            ? _allFilteredInvoices
                                            : _allFilteredCustomInvoices);

                                  if (currentAllFiltered.isEmpty)
                                    return SizedBox.shrink();

                                  final currentPageLocal = _activeTabIndex == 0
                                      ? currentPageAll
                                      : (_activeTabIndex == 1
                                            ? currentPage
                                            : currentPageCustom);
                                  final totalPagesLocal = _activeTabIndex == 0
                                      ? _getTotalPagesAll()
                                      : (_activeTabIndex == 1
                                            ? _getTotalPages()
                                            : _getTotalPagesCustom());

                                  return Container(
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
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        ElevatedButton.icon(
                                          onPressed: currentPageLocal > 1
                                              ? () => _activeTabIndex == 0
                                                    ? _changePageAll(
                                                        currentPageLocal - 1,
                                                      )
                                                    : (_activeTabIndex == 1
                                                          ? _changePage(
                                                              currentPageLocal -
                                                                  1,
                                                            )
                                                          : _changePageCustom(
                                                              currentPageLocal -
                                                                  1,
                                                            ))
                                              : null,
                                          icon: Icon(
                                            Icons.chevron_left,
                                            size: 14,
                                          ),
                                          label: Text(
                                            'Previous',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white,
                                            foregroundColor:
                                                currentPageLocal > 1
                                                ? const Color(0xFF0D1845)
                                                : const Color(0xFF6C757D),
                                            elevation: 0,
                                            side: const BorderSide(
                                              color: Color(0xFFDEE2E6),
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(5),
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Page numbers
                                        ..._buildPageButtons(
                                          current: currentPageLocal,
                                          totalPages: totalPagesLocal,
                                          onPageSelected: (i) =>
                                              _activeTabIndex == 0
                                              ? _changePageAll(i)
                                              : (_activeTabIndex == 1
                                                    ? _changePage(i)
                                                    : _changePageCustom(i)),
                                        ),

                                        const SizedBox(width: 8),

                                        ElevatedButton.icon(
                                          onPressed:
                                              currentPageLocal < totalPagesLocal
                                              ? () => _activeTabIndex == 0
                                                    ? _changePageAll(
                                                        currentPageLocal + 1,
                                                      )
                                                    : (_activeTabIndex == 1
                                                          ? _changePage(
                                                              currentPageLocal +
                                                                  1,
                                                            )
                                                          : _changePageCustom(
                                                              currentPageLocal +
                                                                  1,
                                                            ))
                                              : null,
                                          icon: Icon(
                                            Icons.chevron_right,
                                            size: 14,
                                          ),
                                          label: Text(
                                            'Next',
                                            style: TextStyle(fontSize: 11),
                                          ),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor:
                                                currentPageLocal <
                                                    totalPagesLocal
                                                ? const Color(0xFF0D1845)
                                                : Colors.grey.shade300,
                                            foregroundColor:
                                                currentPageLocal <
                                                    totalPagesLocal
                                                ? Colors.white
                                                : Colors.grey.shade600,
                                            elevation:
                                                currentPageLocal <
                                                    totalPagesLocal
                                                ? 2
                                                : 0,
                                            side:
                                                currentPageLocal <
                                                    totalPagesLocal
                                                ? null
                                                : const BorderSide(
                                                    color: Color(0xFFDEE2E6),
                                                  ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(5),
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
                                            horizontal: 12,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Color(0xFFF8F9FA),
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            'Page $currentPageLocal of $totalPagesLocal (${currentAllFiltered.length} total)',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF6C757D),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCustomOrderPopup(Invoice invoice) async {
    // Fetch invoice details first
    late BuildContext dialogContext;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext ctx) {
        dialogContext = ctx;
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Loading invoice details...'),
            ],
          ),
        );
      },
    );

    try {
      final invoiceDetail = await SalesService.getBridalById(invoice.invId);
      Navigator.of(dialogContext).pop(); // Close loading dialog

      if (mounted) {
        showDialog(
          context: context,
          builder: (BuildContext context) {
            return CustomOrderPopup(
              invoice: invoice,
              invoiceDetail: invoiceDetail,
              onExtrasChanged: () {
                // Refresh the invoice list to reflect changes
                _fetchAllCustomInvoicesOnInit();
              },
            );
          },
        );
      }
    } catch (e) {
      Navigator.of(dialogContext).pop(); // Close loading dialog
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load invoice details: $e')),
        );
      }
    }
  }

  Future<void> exportToPDF() async {
    try {
      // Check if any invoices are selected
      if (_selectedInvoiceIds.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select at least one invoice to export'),
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

      // Get ALL selected invoices from the full cache, not just current page
      List<Invoice> selectedInvoices;
      if (_activeTabIndex == 0) {
        selectedInvoices = _allAllInvoicesCache
            .where((inv) => _selectedInvoiceIds.contains(inv.invId))
            .toList();
      } else if (_activeTabIndex == 1) {
        selectedInvoices = _allInvoicesCache
            .where((inv) => _selectedInvoiceIds.contains(inv.invId))
            .toList();
      } else {
        selectedInvoices = _allCustomInvoicesCache
            .where((inv) => _selectedInvoiceIds.contains(inv.invId))
            .toList();
      }

      // If no invoices found in cache, try to load data
      if (selectedInvoices.isEmpty) {
        try {
          if (_activeTabIndex == 0) {
            if (_allAllInvoicesCache.isEmpty) {
              await _fetchAllAllInvoicesOnInit();
            }
            selectedInvoices = _allAllInvoicesCache
                .where((inv) => _selectedInvoiceIds.contains(inv.invId))
                .toList();
          } else if (_activeTabIndex == 1) {
            if (_allInvoicesCache.isEmpty) {
              await _fetchAllInvoicesOnInit();
            }
            selectedInvoices = _allInvoicesCache
                .where((inv) => _selectedInvoiceIds.contains(inv.invId))
                .toList();
          } else {
            if (_allCustomInvoicesCache.isEmpty) {
              await _fetchAllCustomInvoicesOnInit();
            }
            selectedInvoices = _allCustomInvoicesCache
                .where((inv) => _selectedInvoiceIds.contains(inv.invId))
                .toList();
          }
        } catch (e) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to fetch data for export: $e')),
          );
          return;
        }
      }

      if (selectedInvoices.isEmpty) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No rows available to export for the selected tab.'),
          ),
        );
        return;
      }

      // Create PDF document
      final PdfDocument document = PdfDocument();
      document.pageSettings.orientation = PdfPageOrientation.landscape;
      document.pageSettings.margins.all = 20;

      // Create page template for header and footer
      final PdfPageTemplateElement headerTemplate = PdfPageTemplateElement(
        Rect.fromLTWH(0, 0, document.pageSettings.size.width, 50),
      );

      // Add header title depending on tab
      final String reportTitle = _activeTabIndex == 0
          ? 'All Invoices Report (${selectedInvoices.length} selected)'
          : (_activeTabIndex == 1
                ? 'Invoices Report (${selectedInvoices.length} selected)'
                : 'Custom Orders Report (${selectedInvoices.length} selected)');

      headerTemplate.graphics.drawString(
        reportTitle,
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

      // Calculate page width for summary positioning
      final double pageWidth = page.getClientSize().width;

      // Draw title and header info at the top of the page
      double currentY = 0;

      // Draw invoice type title
      final String invoiceTypeTitle = _activeTabIndex == 0
          ? 'ALL INVOICES'
          : (_activeTabIndex == 1
                ? 'REGULAR ORDER INVOICES'
                : 'CUSTOM ORDER INVOICES');

      page.graphics.drawString(
        invoiceTypeTitle,
        PdfStandardFont(PdfFontFamily.helvetica, 20, style: PdfFontStyle.bold),
        bounds: Rect.fromLTWH(20, currentY, 400, 25),
        format: PdfStringFormat(alignment: PdfTextAlignment.left),
      );

      // Draw generated date at top right
      final String generatedOnText =
          'Generated on: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}';
      page.graphics.drawString(
        generatedOnText,
        PdfStandardFont(PdfFontFamily.helvetica, 9),
        bounds: Rect.fromLTWH(pageWidth - 250, currentY + 5, 240, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );

      currentY += 35;

      // Add subtitle with count
      final String subtitleText =
          '${selectedInvoices.length} invoices selected';
      page.graphics.drawString(
        subtitleText,
        PdfStandardFont(PdfFontFamily.helvetica, 10),
        bounds: Rect.fromLTWH(20, currentY, 200, 15),
        format: PdfStringFormat(alignment: PdfTextAlignment.left),
      );

      currentY += 20;

      // Calculate summary totals for selected invoices
      double totalAmount = 0.0;
      double totalExpense = 0.0;

      for (final invoice in selectedInvoices) {
        totalAmount += invoice.invAmount;

        // For custom orders, load and sum expenses
        if (_activeTabIndex == 2) {
          try {
            final response = await SalesService.getCustomExtraExpenses(
              invoice.invId,
            );
            if (response['success'] == true && response['data'] != null) {
              final data = response['data'];
              // API returns extra_exps as a list of expense objects
              final expenses = (data['extra_exps'] as List<dynamic>? ?? []);
              for (final exp in expenses) {
                totalExpense +=
                    double.tryParse(exp['amount']?.toString() ?? '0') ?? 0.0;
              }
            }
          } catch (e) {
            // Ignore errors for individual invoices
          }
        }
      }

      final double netProfit = totalAmount - totalExpense;

      // Draw summary box at top right of first page
      final double summaryX = pageWidth - 300;
      final double summaryY = 20; // Top of page with small margin
      final double summaryWidth = 280;
      final double labelColWidth = 150;
      final double amountColWidth = 130;
      final double headerHeight = 20;
      final double rowHeight = 16;

      // Draw summary header background (blue like main grid)
      page.graphics.drawRectangle(
        bounds: Rect.fromLTWH(summaryX, summaryY, summaryWidth, headerHeight),
        brush: PdfSolidBrush(PdfColor(0, 123, 255)),
        pen: PdfPen(PdfColor(0, 123, 255), width: 1),
      );

      // Draw summary header text
      page.graphics.drawString(
        'Summary',
        PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold),
        bounds: Rect.fromLTWH(
          summaryX + 5,
          summaryY + 3,
          labelColWidth - 10,
          headerHeight,
        ),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.left,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
        brush: PdfBrushes.white,
      );

      page.graphics.drawString(
        'Amount (Rs.)',
        PdfStandardFont(PdfFontFamily.helvetica, 10, style: PdfFontStyle.bold),
        bounds: Rect.fromLTWH(
          summaryX + labelColWidth,
          summaryY + 3,
          amountColWidth - 5,
          headerHeight,
        ),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.right,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
        brush: PdfBrushes.white,
      );

      // Draw vertical separator line in header
      page.graphics.drawLine(
        PdfPen(PdfColor(200, 200, 200), width: 0.5),
        Offset(summaryX + labelColWidth, summaryY),
        Offset(summaryX + labelColWidth, summaryY + headerHeight),
      );

      // Draw summary rows with alternating background colors
      double rowY = summaryY + headerHeight;
      final List<MapEntry<String, double>> summaryData = [
        MapEntry('Total Amount', totalAmount),
        MapEntry('Total Expense', totalExpense),
        MapEntry('Net Profit', netProfit),
      ];

      for (int i = 0; i < summaryData.length; i++) {
        // Alternating row background
        if (i % 2 == 1) {
          page.graphics.drawRectangle(
            bounds: Rect.fromLTWH(summaryX, rowY, summaryWidth, rowHeight),
            brush: PdfSolidBrush(PdfColor(245, 245, 245)),
          );
        }

        // Draw row border
        page.graphics.drawLine(
          PdfPen(PdfColor(220, 220, 220), width: 0.5),
          Offset(summaryX, rowY),
          Offset(summaryX + summaryWidth, rowY),
        );

        // Draw label
        page.graphics.drawString(
          summaryData[i].key,
          PdfStandardFont(PdfFontFamily.helvetica, 9),
          bounds: Rect.fromLTWH(
            summaryX + 5,
            rowY + 2,
            labelColWidth - 10,
            rowHeight,
          ),
          format: PdfStringFormat(alignment: PdfTextAlignment.left),
        );

        // Draw vertical separator
        page.graphics.drawLine(
          PdfPen(PdfColor(220, 220, 220), width: 0.5),
          Offset(summaryX + labelColWidth, rowY),
          Offset(summaryX + labelColWidth, rowY + rowHeight),
        );

        // Draw amount
        page.graphics.drawString(
          'Rs. ${summaryData[i].value.toStringAsFixed(2)}',
          PdfStandardFont(PdfFontFamily.helvetica, 9, style: PdfFontStyle.bold),
          bounds: Rect.fromLTWH(
            summaryX + labelColWidth + 5,
            rowY + 2,
            amountColWidth - 10,
            rowHeight,
          ),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );

        rowY += rowHeight;
      }

      // Draw outer border
      page.graphics.drawRectangle(
        bounds: Rect.fromLTWH(
          summaryX,
          summaryY,
          summaryWidth,
          headerHeight + (rowHeight * summaryData.length),
        ),
        pen: PdfPen(PdfColor(0, 123, 255), width: 1),
      );

      // Calculate total width for centered grid
      double gridTotalWidth = 0;
      if (_activeTabIndex == 2) {
        // Custom orders: sum all column widths
        gridTotalWidth = 70 + 100 + 70 + 70 + 70 + 70 + 70 + 70 + 70 + 70 + 70;
      } else {
        // Regular orders: sum all column widths
        gridTotalWidth = 80 + 120 + 80 + 80 + 80 + 80 + 100 + 100;
      }

      // Calculate left margin to center the grid
      final double centerMargin = (pageWidth - gridTotalWidth) / 2;

      // Set main grid bounds - centered and positioned below the summary box
      final double summaryHeight =
          headerHeight + (rowHeight * summaryData.length) + 50;
      final Rect mainGridBounds = Rect.fromLTWH(
        centerMargin,
        summaryHeight, // Position grid below the summary box
        gridTotalWidth,
        page.getClientSize().height - summaryHeight - 0,
      );

      final PdfGrid grid = PdfGrid();

      // Define columns and headers. For Custom Orders include Due Date column.
      if (_activeTabIndex == 2) {
        grid.columns.add(count: 11);
        grid.headers.add(1);

        // Set column widths for 11 cols, total 800 pixels for custom orders
        grid.columns[0].width = 70; // Invoice #
        grid.columns[1].width = 100; // Customer
        grid.columns[2].width = 70; // Date
        grid.columns[3].width = 70; // Due Date
        grid.columns[4].width = 70; // Total
        grid.columns[5].width = 70; // Paid
        grid.columns[6].width = 70; // Due
        grid.columns[7].width = 70; // Inv Amount
        grid.columns[8].width = 70; // Extra Expenses
        grid.columns[9].width = 70; // Net Profit
        grid.columns[10].width = 70; // Salesman

        // Set header style
        final PdfGridRow header = grid.headers[0];
        header.cells[0].value = 'Invoice #';
        header.cells[1].value = 'Customer';
        header.cells[2].value = 'Date';
        header.cells[3].value = 'Due Date';
        header.cells[4].value = 'Total';
        header.cells[5].value = 'Paid Amount';
        header.cells[6].value = 'Due';
        header.cells[7].value = 'Inv Amount';
        header.cells[8].value = 'Extra Expenses';
        header.cells[9].value = 'Net Profit';
        header.cells[10].value = 'Salesman';
      } else {
        grid.columns.add(count: 8);
        grid.headers.add(1);

        // Set column widths
        grid.columns[0].width = 80; // Invoice #
        grid.columns[1].width = 120; // Customer
        grid.columns[2].width = 80; // Date
        grid.columns[3].width = 80; // Total
        grid.columns[4].width = 80; // Paid
        grid.columns[5].width = 80; // Due
        grid.columns[6].width = 100; // Payment Mode
        grid.columns[7].width = 100; // Salesman

        // Set header style
        final PdfGridRow header = grid.headers[0];
        header.cells[0].value = 'Invoice #';
        header.cells[1].value = 'Customer';
        header.cells[2].value = 'Date';
        header.cells[3].value = 'Total';
        header.cells[4].value = 'Paid Amount';
        header.cells[5].value = 'Due';
        header.cells[6].value = 'Payment Mode';
        header.cells[7].value = 'Salesman';
      }

      // Reference header row (cells were populated above) and style headers
      final PdfGridRow header = grid.headers[0];

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

      // Add data rows (only currently visible rows / current page)
      for (final invoice in selectedInvoices) {
        final PdfGridRow row = grid.rows.add();
        if (_activeTabIndex == 2) {
          // Custom Orders: includes Due Date column and replaces Payment Mode with three columns
          row.cells[0].value = 'INV-${invoice.invId}';
          row.cells[1].value = invoice.customerName;
          row.cells[2].value = invoice.invDate.isNotEmpty
              ? DateFormat('dd/MM/yyyy').format(DateTime.parse(invoice.invDate))
              : '';
          row.cells[3].value =
              (invoice.dueDate != null && invoice.dueDate!.isNotEmpty)
              ? (() {
                  try {
                    return DateFormat(
                      'dd/MM/yyyy',
                    ).format(DateTime.parse(invoice.dueDate!));
                  } catch (_) {
                    return invoice.dueDate!;
                  }
                })()
              : '';
          row.cells[4].value = invoice.invAmount.toStringAsFixed(2);
          row.cells[5].value = invoice.paidAmount.toStringAsFixed(2);
          row.cells[6].value = invoice.dueAmount.toStringAsFixed(2);
          row.cells[7].value = invoice.invAmount.toStringAsFixed(2);
          row.cells[8].value = (invoice.totalExtraExpenses ?? 0)
              .toStringAsFixed(2);
          row.cells[9].value = (invoice.netProfit ?? 0).toStringAsFixed(2);
          row.cells[10].value = invoice.salesmanName ?? 'N/A';
        } else {
          row.cells[0].value = 'INV-${invoice.invId}';
          row.cells[1].value = invoice.customerName;
          row.cells[2].value = invoice.invDate.isNotEmpty
              ? DateFormat('dd/MM/yyyy').format(DateTime.parse(invoice.invDate))
              : '';
          row.cells[3].value = invoice.invAmount.toStringAsFixed(2);
          row.cells[4].value = invoice.paidAmount.toStringAsFixed(2);
          row.cells[5].value = invoice.dueAmount.toStringAsFixed(2);
          row.cells[6].value = invoice.paymentMode;
          row.cells[7].value = invoice.salesmanName ?? 'N/A';
        }

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
      grid.draw(page: page, bounds: mainGridBounds);

      // Save PDF
      final List<int> bytes = await document.save();
      document.dispose();

      // Let user choose save location
      final String slug = _activeTabIndex == 0
          ? 'all_invoices'
          : (_activeTabIndex == 1 ? 'invoices' : 'custom_orders');
      final String defaultFileName =
          '${slug}_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.pdf';

      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save PDF Report',
        fileName: defaultFileName,
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
            content: Text('$reportTitle exported successfully to $outputFile'),
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
}

class CustomOrderPopup extends StatefulWidget {
  final Invoice invoice;
  final InvoiceDetailResponse invoiceDetail;
  final VoidCallback onExtrasChanged;

  const CustomOrderPopup({
    Key? key,
    required this.invoice,
    required this.invoiceDetail,
    required this.onExtrasChanged,
  }) : super(key: key);

  @override
  State<CustomOrderPopup> createState() => _CustomOrderPopupState();
}

class _CustomOrderPopupState extends State<CustomOrderPopup> {
  late List<Map<String, dynamic>> extras;
  late List<Map<String, dynamic>> expenses;
  bool isLoading = false;
  bool isSavingExtras = false;
  double _originalExtrasTotal = 0.0;
  double _baseWithoutExtras = 0.0;

  // Sanitize amount input: allow digits and a single decimal point, limit to 2 decimals
  String _sanitizeAmount(String input) {
    var s = input.replaceAll(RegExp(r'[^0-9\.]'), '');
    if (s.isEmpty) return '';
    // Keep only first decimal point
    if (s.contains('.')) {
      final parts = s.split('.');
      final intPart = parts.first;
      final decPart = parts.sublist(1).join('');
      final decLimited = decPart.length > 2 ? decPart.substring(0, 2) : decPart;
      return '$intPart${decLimited.isNotEmpty ? '.' + decLimited : ''}';
    }
    return s;
  }

  // Formatter for date input to auto-insert dashes for dd-MM-yyyy
  TextInputFormatter get _dateDashFormatter {
    return TextInputFormatter.withFunction((oldValue, newValue) {
      // If deleting, allow without reformatting to let user erase dashes
      if (newValue.text.length < oldValue.text.length) {
        return newValue;
      }
      final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
      final capped = digits.length > 8 ? digits.substring(0, 8) : digits;
      final buffer = StringBuffer();
      for (var i = 0; i < capped.length; i++) {
        buffer.write(capped[i]);
        if (i == 1 || i == 3) buffer.write('-');
      }
      final formatted = buffer.toString();
      return TextEditingValue(
        text: formatted,
        selection: TextSelection.collapsed(offset: formatted.length),
      );
    });
  }

  // Input formatter to allow only letters, spaces, dash and apostrophe in titles
  TextInputFormatter get _titleOnlyFormatter {
    return FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z\s\-']"));
  }

  @override
  void initState() {
    super.initState();
    extras = widget.invoiceDetail.details
        .expand((detail) => detail.extras)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    // Compute original extras total and base amount without extras so we can
    // show a live-updating invoice total when extras are edited.
    _originalExtrasTotal = 0.0;
    for (final d in widget.invoiceDetail.details) {
      for (final ex in d.extras) {
        _originalExtrasTotal +=
            double.tryParse(ex['amount']?.toString() ?? '0') ?? 0.0;
      }
    }
    final baseAmount =
        double.tryParse(widget.invoiceDetail.invAmount) ??
        double.tryParse(
          widget.invoiceDetail.rawData['computed']?['grand_total']
                  ?.toString() ??
              '0',
        ) ??
        0.0;
    _baseWithoutExtras = baseAmount - _originalExtrasTotal;
    expenses = [];
    _loadExpenses();
  }

  double get currentInvoiceTotal => (_baseWithoutExtras + totalExtras);

  Future<void> _loadExpenses() async {
    try {
      final response = await SalesService.getCustomExtraExpenses(
        widget.invoice.invId,
      );
      if (response['success'] == true && response['data'] != null) {
        final data = response['data'];

        // Extract extras from details[].extras — preserve pos_detail (prod_id)
        final List<Map<String, dynamic>> fetchedExtras = [];
        try {
          final details = (data['details'] as List<dynamic>? ?? []);
          for (final d in details) {
            final posDetailId = d['prod_id'] ?? d['pos_detail_id'] ?? 0;
            final productExtras = (d['extras'] as List<dynamic>? ?? []);
            for (final ex in productExtras) {
              fetchedExtras.add({
                'pos_detail_id': posDetailId,
                'title':
                    ex['title']?.toString() ?? ex['name']?.toString() ?? '',
                'amount':
                    double.tryParse(ex['amount']?.toString() ?? '0') ?? 0.0,
              });
            }
          }
        } catch (_) {}

        // Extract expense items from extra_exps
        final List<Map<String, dynamic>> fetchedExpenses = [];
        try {
          final extraExps = (data['extra_exps'] as List<dynamic>? ?? []);
          for (final ee in extraExps) {
            fetchedExpenses.add({
              'id': ee['id'],
              'pos_detail_id': ee['pos_detail_id'] ?? '',
              'date':
                  ee['exp_date']?.toString().split(' ').first ??
                  ee['date']?.toString() ??
                  '',
              'title': ee['title']?.toString() ?? '',
              'amount': double.tryParse(ee['amount']?.toString() ?? '0') ?? 0.0,
            });
          }
        } catch (_) {}

        if (!mounted) return;
        setState(() {
          // Merge fetched extras with any existing ones (prefer fetched)
          if (fetchedExtras.isNotEmpty) {
            extras = fetchedExtras;
          }
          expenses = fetchedExpenses;
        });
      }
    } catch (e) {
      print('Failed to load extras/expenses: $e');
    }

    // Fetch POS extras from the new API
    try {
      final extrasResponse = await SalesService.getPosExtras(
        widget.invoice.invId,
      );
      if (extrasResponse['success'] == true && extrasResponse['data'] is List) {
        final fetchedExtras = (extrasResponse['data'] as List)
            .map(
              (e) => {
                'id': e['id'],
                'title': e['title']?.toString() ?? '',
                'amount':
                    double.tryParse(e['amount']?.toString() ?? '0') ?? 0.0,
                'created_at': e['created_at']?.toString() ?? '',
              },
            )
            .toList();

        if (mounted) {
          setState(() {
            extras = fetchedExtras;
          });
        }
      }
    } catch (e) {
      print('Failed to load POS extras: $e');
    }
  }

  Future<void> _saveExpenses() async {
    if (expenses.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No expenses to save')));
      }
      return;
    }

    // Validate each expense has required fields
    for (int i = 0; i < expenses.length; i++) {
      final expense = expenses[i];
      final date = (expense['date']?.toString() ?? '').trim();
      final title = (expense['title']?.toString() ?? '').trim();
      final amount = (expense['amount'] is String)
          ? double.tryParse(expense['amount']) ?? 0.0
          : (expense['amount'] ?? 0.0);

      if (date.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Expense ${i + 1}: Date cannot be empty')),
          );
        }
        return;
      }

      if (title.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Expense ${i + 1}: Title cannot be empty')),
          );
        }
        return;
      }

      if (amount <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Expense ${i + 1}: Amount must be greater than 0'),
            ),
          );
        }
        return;
      }
    }

    setState(() => isLoading = true);
    try {
      final payload = {
        'pos_id': widget.invoice.invId,
        'expenses': expenses
            .map((e) => {'title': e['title'], 'amount': e['amount']})
            .toList(),
      };
      await SalesService.saveCustomExtraExpenses(payload);
      widget.onExtrasChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expenses saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save expenses: $e')));
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _addExtra() {
    setState(() {
      extras.add({'title': '', 'amount': 0.0});
    });
  }

  Future<void> _deleteExtra(int index) async {
    final extra = extras[index];
    final extraId = extra['id'];
    if (extraId == null) {
      // If no id, just remove locally (for newly added extras)
      setState(() {
        extras.removeAt(index);
      });
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Extra'),
        content: const Text(
          'Are you sure you want to delete this extra? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SalesService.deletePosExtra(extraId);
      setState(() {
        extras.removeAt(index);
      });
      widget.onExtrasChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Extra deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete extra: $e')));
      }
    }
  }

  void _addExpense() {
    setState(() {
      expenses.add({
        'pos_detail_id': widget.invoiceDetail.details.first.id,
        'date': DateFormat('yyyy-MM-dd').format(DateTime.now()),
        'title': '',
        'amount': 0.0,
      });
    });
  }

  Future<void> _deleteExpense(int index) async {
    final expense = expenses[index];
    final expenseId = expense['id'];
    if (expenseId == null) {
      // If no id, just remove locally (for newly added expenses)
      setState(() {
        expenses.removeAt(index);
      });
      return;
    }

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Expense'),
        content: const Text(
          'Are you sure you want to delete this expense? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await SalesService.deleteCustomExtraExpense(expenseId);
      setState(() {
        expenses.removeAt(index);
      });
      widget.onExtrasChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Expense deleted successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to delete expense: $e')));
      }
    }
  }

  Future<void> _saveExtras() async {
    if (extras.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No extras to save')));
      }
      return;
    }

    // Validate each extra has required fields
    for (int i = 0; i < extras.length; i++) {
      final extra = extras[i];
      final title = (extra['title']?.toString() ?? '').trim();
      final amount = (extra['amount'] is String)
          ? double.tryParse(extra['amount']) ?? 0.0
          : (extra['amount'] ?? 0.0);

      if (title.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Extra ${i + 1}: Title cannot be empty')),
          );
        }
        return;
      }

      if (amount <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Extra ${i + 1}: Amount must be greater than 0'),
            ),
          );
        }
        return;
      }
    }

    setState(() => isSavingExtras = true);
    try {
      // Build payload expected by PUT /pos/customExtraExp/{id}
      // Ensure each extra contains pos_detail_id. If missing, fall back to
      // the first detail's id from the invoice detail.
      final int fallbackPosDetailId = widget.invoiceDetail.details.isNotEmpty
          ? widget.invoiceDetail.details.first.id
          : 0;

      final List<Map<String, dynamic>> payloadExtras = extras.map((e) {
        return {
          'pos_detail_id': e['pos_detail_id'] ?? fallbackPosDetailId,
          'title': e['title'] ?? '',
          'amount': (e['amount'] is String)
              ? double.tryParse(e['amount']) ?? 0.0
              : (e['amount'] ?? 0.0),
        };
      }).toList();

      final payload = {'extras': payloadExtras};

      await SalesService.saveCustomExtras(widget.invoice.invId, payload);
      widget.onExtrasChanged();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Extras updated successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update extras: $e')));
      }
    } finally {
      setState(() => isSavingExtras = false);
    }
  }

  double get totalExtras => extras.fold(
    0.0,
    (sum, ex) =>
        sum + (double.tryParse(ex['amount']?.toString() ?? '0') ?? 0.0),
  );
  double get totalExpenses => expenses.fold(
    0.0,
    (sum, ex) =>
        sum + (double.tryParse(ex['amount']?.toString() ?? '0') ?? 0.0),
  );

  Future<void> _generateCustomOrderPDF() async {
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

      // Create PDF document with landscape orientation for better space
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      final PdfGraphics graphics = page.graphics;
      final double pageWidth = page.getClientSize().width;
      final double pageHeight = page.getClientSize().height;

      // Set up fonts
      final PdfFont titleFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        22,
        style: PdfFontStyle.bold,
      );
      final PdfFont sectionFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        12,
        style: PdfFontStyle.bold,
      );
      final PdfFont boldFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        10,
        style: PdfFontStyle.bold,
      );
      final PdfFont regularFont = PdfStandardFont(PdfFontFamily.helvetica, 9);
      final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 8);

      double yPos = 15;
      const double leftMargin = 25;
      const double rightMargin = 25;
      final double contentWidth = pageWidth - leftMargin - rightMargin;

      // Header background
      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(13, 24, 69)), // Dark blue background
        bounds: Rect.fromLTWH(0, 0, pageWidth, 60),
      );

      // Title in white
      graphics.drawString(
        'CUSTOM ORDER DETAILS',
        titleFont,
        bounds: Rect.fromLTWH(leftMargin, yPos + 5, contentWidth, 25),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
        brush: PdfBrushes.white,
      );
      yPos += 50;

      // Invoice ID and Date
      graphics.drawString(
        'Invoice: INV-${widget.invoice.invId}',
        boldFont,
        bounds: Rect.fromLTWH(leftMargin, yPos, contentWidth / 2, 12),
      );
      graphics.drawString(
        'Generated: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())}',
        boldFont,
        bounds: Rect.fromLTWH(
          leftMargin + contentWidth / 2,
          yPos,
          contentWidth / 2,
          12,
        ),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
      yPos += 18;

      // Separator line
      graphics.drawLine(
        PdfPen(PdfColor(0, 123, 255), width: 2),
        Offset(leftMargin, yPos),
        Offset(pageWidth - rightMargin, yPos),
      );
      yPos += 15;

      // Order Information Section with background
      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(245, 245, 245)),
        bounds: Rect.fromLTWH(leftMargin, yPos, contentWidth, 55),
      );

      graphics.drawString(
        'ORDER INFORMATION',
        sectionFont,
        bounds: Rect.fromLTWH(leftMargin + 10, yPos + 5, contentWidth - 20, 12),
      );
      yPos += 18;

      // Customer info in 2 columns
      graphics.drawString(
        'Customer: ${widget.invoiceDetail.customerName.isNotEmpty ? widget.invoiceDetail.customerName : 'Walk-in Customer'}',
        regularFont,
        bounds: Rect.fromLTWH(leftMargin + 10, yPos, contentWidth / 2 - 15, 12),
      );
      graphics.drawString(
        'Date: ${DateFormat('dd MMM yyyy').format(DateTime.parse(widget.invoiceDetail.invDate))}',
        regularFont,
        bounds: Rect.fromLTWH(
          leftMargin + contentWidth / 2 + 10,
          yPos,
          contentWidth / 2 - 15,
          12,
        ),
      );
      yPos += 18;

      double currentInvoiceTotal = (_baseWithoutExtras + totalExtras);
      graphics.drawString(
        'Invoice Amount: Rs. ${currentInvoiceTotal.toStringAsFixed(2)}',
        boldFont,
        bounds: Rect.fromLTWH(leftMargin + 10, yPos, contentWidth - 20, 12),
      );
      yPos += 30;

      // Extras Section with background
      if (extras.isNotEmpty) {
        graphics.drawRectangle(
          brush: PdfSolidBrush(PdfColor(220, 240, 255)),
          bounds: Rect.fromLTWH(
            leftMargin,
            yPos,
            contentWidth,
            10 + (extras.length * 12) + 20,
          ),
        );
        graphics.drawLine(
          PdfPen(PdfColor(0, 123, 255), width: 1),
          Offset(leftMargin, yPos),
          Offset(pageWidth - rightMargin, yPos),
        );

        graphics.drawString(
          'EXTRA (Add-on Items)',
          sectionFont,
          bounds: Rect.fromLTWH(
            leftMargin + 10,
            yPos + 5,
            contentWidth - 20,
            12,
          ),
        );
        yPos += 20;

        for (var extra in extras) {
          final amount =
              double.tryParse(extra['amount']?.toString() ?? '0') ?? 0.0;
          graphics.drawString(
            '• ${extra['title'] ?? 'Unnamed Extra'}',
            regularFont,
            bounds: Rect.fromLTWH(
              leftMargin + 15,
              yPos,
              contentWidth - 130,
              12,
            ),
          );
          graphics.drawString(
            'Rs. ${amount.toStringAsFixed(2)}',
            regularFont,
            bounds: Rect.fromLTWH(
              leftMargin + contentWidth - 110,
              yPos,
              100,
              12,
            ),
            format: PdfStringFormat(alignment: PdfTextAlignment.right),
          );
          yPos += 12;
        }

        // Total Extras
        graphics.drawLine(
          PdfPen(PdfColor(200, 200, 200), width: 0.5),
          Offset(leftMargin + 15, yPos),
          Offset(pageWidth - rightMargin - 15, yPos),
        );
        yPos += 8;
        graphics.drawString(
          'Total Extras:',
          boldFont,
          bounds: Rect.fromLTWH(leftMargin + 15, yPos, contentWidth - 130, 12),
        );
        graphics.drawString(
          'Rs. ${totalExtras.toStringAsFixed(2)}',
          boldFont,
          bounds: Rect.fromLTWH(leftMargin + contentWidth - 110, yPos, 100, 12),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        yPos += 20;
      }

      // Expenses Section with background
      if (expenses.isNotEmpty) {
        graphics.drawRectangle(
          brush: PdfSolidBrush(PdfColor(255, 245, 220)),
          bounds: Rect.fromLTWH(
            leftMargin,
            yPos,
            contentWidth,
            10 + (expenses.length * 12) + 20,
          ),
        );
        graphics.drawLine(
          PdfPen(PdfColor(255, 165, 0), width: 1),
          Offset(leftMargin, yPos),
          Offset(pageWidth - rightMargin, yPos),
        );

        graphics.drawString(
          'EXPENSE (Internal Costs)',
          sectionFont,
          bounds: Rect.fromLTWH(
            leftMargin + 10,
            yPos + 5,
            contentWidth - 20,
            12,
          ),
        );
        yPos += 20;

        for (var expense in expenses) {
          final amount =
              double.tryParse(expense['amount']?.toString() ?? '0') ?? 0.0;
          final date = expense['date']?.toString() ?? '';
          final title = expense['title']?.toString() ?? 'Unnamed';
          graphics.drawString(
            '• $date - $title',
            regularFont,
            bounds: Rect.fromLTWH(
              leftMargin + 15,
              yPos,
              contentWidth - 130,
              12,
            ),
          );
          graphics.drawString(
            'Rs. ${amount.toStringAsFixed(2)}',
            regularFont,
            bounds: Rect.fromLTWH(
              leftMargin + contentWidth - 110,
              yPos,
              100,
              12,
            ),
            format: PdfStringFormat(alignment: PdfTextAlignment.right),
          );
          yPos += 12;
        }

        // Total Expenses
        graphics.drawLine(
          PdfPen(PdfColor(200, 200, 200), width: 0.5),
          Offset(leftMargin + 15, yPos),
          Offset(pageWidth - rightMargin - 15, yPos),
        );
        yPos += 8;
        graphics.drawString(
          'Total Expenses:',
          boldFont,
          bounds: Rect.fromLTWH(leftMargin + 15, yPos, contentWidth - 130, 12),
        );
        graphics.drawString(
          'Rs. ${totalExpenses.toStringAsFixed(2)}',
          boldFont,
          bounds: Rect.fromLTWH(leftMargin + contentWidth - 110, yPos, 100, 12),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        yPos += 25;
      }

      // Summary Section with prominent styling
      graphics.drawRectangle(
        brush: PdfSolidBrush(PdfColor(220, 255, 220)),
        bounds: Rect.fromLTWH(leftMargin, yPos, contentWidth, 85),
      );
      graphics.drawLine(
        PdfPen(PdfColor(40, 167, 69), width: 2),
        Offset(leftMargin, yPos),
        Offset(pageWidth - rightMargin, yPos),
      );

      graphics.drawString(
        'SUMMARY',
        sectionFont,
        bounds: Rect.fromLTWH(leftMargin + 10, yPos + 8, contentWidth - 20, 12),
      );
      yPos += 25;

      // Summary details with larger fonts
      final summaryItems = [
        ('Invoice Total:', currentInvoiceTotal),
        ('Total Expenses:', totalExpenses),
        ('Net Profit:', currentInvoiceTotal - totalExpenses),
      ];

      for (var item in summaryItems) {
        graphics.drawString(
          item.$1,
          boldFont,
          bounds: Rect.fromLTWH(leftMargin + 15, yPos, contentWidth - 130, 12),
        );
        graphics.drawString(
          'Rs. ${item.$2.toStringAsFixed(2)}',
          boldFont,
          bounds: Rect.fromLTWH(leftMargin + contentWidth - 110, yPos, 100, 12),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        yPos += 18;
      }

      // Footer with timestamp
      yPos = pageHeight - 20;
      graphics.drawLine(
        PdfPen(PdfColor(200, 200, 200), width: 0.5),
        Offset(leftMargin, yPos),
        Offset(pageWidth - rightMargin, yPos),
      );
      graphics.drawString(
        'Generated on: ${DateFormat('dd MMM yyyy, HH:mm').format(DateTime.now())} | POS System',
        smallFont,
        bounds: Rect.fromLTWH(leftMargin, yPos + 5, contentWidth, 10),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // Save PDF
      final List<int> bytes = await document.save();
      document.dispose();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Save file using FilePicker
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Custom Order PDF',
        fileName:
            'custom_order_${widget.invoice.invId}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFile != null) {
        final File file = File(outputFile);
        await file.writeAsBytes(bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white),
                  const SizedBox(width: 8),
                  Expanded(child: Text('PDF saved successfully')),
                ],
              ),
              backgroundColor: const Color(0xFF28A745),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
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
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(child: Text('Failed to generate PDF: $e')),
              ],
            ),
            backgroundColor: const Color(0xFFDC3545),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.receipt_long, color: Colors.white, size: 24),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Custom Order Details',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'INV-${widget.invoice.invId}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _generateCustomOrderPDF,
                    icon: const Icon(Icons.picture_as_pdf, size: 16),
                    label: const Text('PDF', style: TextStyle(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFDC3545),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Info
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Order Information',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D1845),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.person,
                                color: Color(0xFF0D1845),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.invoiceDetail.customerName.isNotEmpty
                                    ? widget.invoiceDetail.customerName
                                    : 'Walk-in Customer',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                color: Color(0xFF0D1845),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                DateFormat('dd MMM yyyy').format(
                                  DateTime.parse(widget.invoiceDetail.invDate),
                                ),
                                style: const TextStyle(fontSize: 12),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.receipt_long,
                                color: Color(0xFF0D1845),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Tax:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Rs. ${double.tryParse(widget.invoiceDetail.rawData['tax']?.toString() ?? '')?.toStringAsFixed(2) ?? '0.00'}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(
                                Icons.receipt_long,
                                color: Color(0xFF0D1845),
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Invoice Amount:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                'Rs. ${currentInvoiceTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // EXTRA Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'EXTRA (Add-on Items)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D1845),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'Total: Rs. ${totalExtras.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.blue,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add,
                                      color: Colors.green,
                                    ),
                                    iconSize: 16,
                                    onPressed: _addExtra,
                                    tooltip: 'Add Extra',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (extras.isEmpty)
                            const Text(
                              'No extras added',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            )
                          else
                            ...extras.asMap().entries.map((entry) {
                              final index = entry.key;
                              final ex = entry.value;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 250,
                                      child: TextFormField(
                                        initialValue: ex['title'],
                                        inputFormatters: [_titleOnlyFormatter],
                                        decoration: const InputDecoration(
                                          labelText: 'Title',
                                          labelStyle: TextStyle(fontSize: 12),
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                        ),
                                        style: TextStyle(fontSize: 12),
                                        onChanged: (value) =>
                                            ex['title'] = value.replaceAll(
                                              RegExp(r"[^A-Za-z\s\-']"),
                                              '',
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    SizedBox(
                                      width: 120,
                                      child: TextFormField(
                                        initialValue: ex['amount'].toString(),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9\.]'),
                                          ),
                                        ],
                                        decoration: const InputDecoration(
                                          labelText: 'Amount',
                                          labelStyle: TextStyle(fontSize: 12),
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                        ),
                                        style: TextStyle(fontSize: 12),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        onChanged: (value) {
                                          final sanitized = _sanitizeAmount(
                                            value,
                                          );
                                          ex['amount'] =
                                              double.tryParse(sanitized) ?? 0.0;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      iconSize: 16,
                                      onPressed: () => _deleteExtra(index),
                                      tooltip: 'Delete Extra',
                                    ),
                                  ],
                                ),
                              );
                            }),
                          const SizedBox(height: 8),
                          Center(
                            child: ElevatedButton(
                              onPressed: isSavingExtras ? null : _saveExtras,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                              ),
                              child: isSavingExtras
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Save Extras',
                                      style: TextStyle(fontSize: 12),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 16),

                    // EXPENSE Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'EXPENSE (Internal Costs)',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0D1845),
                                ),
                              ),
                              Row(
                                children: [
                                  Text(
                                    'Total: Rs. ${totalExpenses.toStringAsFixed(2)}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.orange,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.add,
                                      color: Colors.green,
                                    ),
                                    iconSize: 16,
                                    onPressed: _addExpense,
                                    tooltip: 'Add Expense',
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (expenses.isEmpty)
                            const Text(
                              'No expenses added',
                              style: TextStyle(
                                color: Colors.grey,
                                fontSize: 12,
                              ),
                            )
                          else
                            ...expenses.asMap().entries.map((entry) {
                              final index = entry.key;
                              final exp = entry.value;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    SizedBox(
                                      width: 120,
                                      child: TextFormField(
                                        initialValue: exp['date'],
                                        inputFormatters: [_dateDashFormatter],
                                        decoration: const InputDecoration(
                                          labelText: 'Date',
                                          labelStyle: TextStyle(fontSize: 12),
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                        ),
                                        style: TextStyle(fontSize: 12),
                                        keyboardType: TextInputType.number,
                                        onChanged: (value) =>
                                            exp['date'] = value,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    SizedBox(
                                      width: 200,
                                      child: TextFormField(
                                        initialValue: exp['title'],
                                        inputFormatters: [_titleOnlyFormatter],
                                        decoration: const InputDecoration(
                                          labelText: 'Title',
                                          labelStyle: TextStyle(fontSize: 12),
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                        ),
                                        style: TextStyle(fontSize: 12),
                                        onChanged: (value) =>
                                            exp['title'] = value.replaceAll(
                                              RegExp(r"[^A-Za-z\s\-']"),
                                              '',
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    SizedBox(
                                      width: 100,
                                      child: TextFormField(
                                        initialValue: exp['amount'].toString(),
                                        inputFormatters: [
                                          FilteringTextInputFormatter.allow(
                                            RegExp(r'[0-9\.]'),
                                          ),
                                        ],
                                        decoration: const InputDecoration(
                                          labelText: 'Amount',
                                          labelStyle: TextStyle(fontSize: 12),
                                          border: OutlineInputBorder(),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                        ),
                                        style: TextStyle(fontSize: 12),
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        onChanged: (value) {
                                          final sanitized = _sanitizeAmount(
                                            value,
                                          );
                                          exp['amount'] =
                                              double.tryParse(sanitized) ?? 0.0;
                                        },
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        color: Colors.red,
                                      ),
                                      iconSize: 16,
                                      onPressed: () => _deleteExpense(index),
                                      tooltip: 'Delete Expense',
                                    ),
                                  ],
                                ),
                              );
                            }),
                          const SizedBox(height: 8),
                          Center(
                            child: ElevatedButton(
                              onPressed: isLoading ? null : _saveExpenses,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.orange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 6,
                                ),
                              ),
                              child: isLoading
                                  ? const SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Text(
                                      'Save Expenses',
                                      style: TextStyle(fontSize: 12),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Summary Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.green.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Summary',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0D1845),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Invoice Total:',
                                style: TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Rs. ${currentInvoiceTotal.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Total Expense:',
                                style: TextStyle(fontSize: 12),
                              ),
                              Text(
                                'Rs. ${totalExpenses.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Net Profit:',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                'Rs. ${(currentInvoiceTotal - totalExpenses).toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Bottom action row removed; Save Expenses moved inside EXPENSE card
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
