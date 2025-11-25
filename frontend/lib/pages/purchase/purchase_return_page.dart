import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/purchases_service.dart';
import 'create_purchase_return_page.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';

class PurchaseReturnPage extends StatefulWidget {
  const PurchaseReturnPage({super.key});

  @override
  State<PurchaseReturnPage> createState() => _PurchaseReturnPageState();
}

class _PurchaseReturnPageState extends State<PurchaseReturnPage>
    with WidgetsBindingObserver, RouteAware {
  // API data
  List<PurchaseReturn> _filteredPurchaseReturns = [];
  List<PurchaseReturn> _allFilteredPurchaseReturns =
      []; // Store all filtered purchase returns for local pagination
  bool _isLoading = true;
  String _errorMessage = '';
  int currentPage = 1;
  final int itemsPerPage = 12;

  // Filter states

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fetchAllPurchaseReturnsOnInit();
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

  // Fetch all purchase returns once when page loads
  Future<void> _fetchAllPurchaseReturnsOnInit({
    bool forceRefresh = false,
  }) async {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );

    // Check if purchase returns are already cached (skip if forceRefresh is true)
    if (!forceRefresh && purchaseProvider.purchaseReturns.isNotEmpty) {
      print(
        '💾 Using cached purchase returns: ${purchaseProvider.purchaseReturns.length} items',
      );
      _applyFiltersClientSide();
      return;
    }

    try {
      print('�🚀 Initial load: Fetching all purchase returns');
      setState(() {
        _errorMessage = '';
      });

      // Fetch all purchase returns from all pages
      List<PurchaseReturn> allPurchaseReturns = [];
      int currentFetchPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        try {
          print('📡 Fetching page $currentFetchPage');
          final response = await PurchaseReturnService.getPurchaseReturns(
            page: currentFetchPage,
            perPage: 50, // Use larger page size for efficiency
          );

          allPurchaseReturns.addAll(response.data);
          print(
            '📦 Page $currentFetchPage: ${response.data.length} purchase returns (total: ${allPurchaseReturns.length})',
          );

          // Check if there are more pages
          if (response.data.length < 50) {
            hasMorePages = false;
          } else {
            currentFetchPage++;
          }
        } catch (e) {
          print('❌ Error fetching page $currentFetchPage: $e');
          hasMorePages = false; // Stop fetching on error
        }
      }

      // Sort purchase returns by return_date descending (newest first)
      // If return_date is same or invalid, fallback to purchaseReturnId descending
      allPurchaseReturns.sort((a, b) {
        try {
          if (a.returnDate.isNotEmpty && b.returnDate.isNotEmpty) {
            final dateA = DateTime.parse(a.returnDate);
            final dateB = DateTime.parse(b.returnDate);
            final comparison = dateB.compareTo(dateA);
            if (comparison != 0) return comparison;
          }
        } catch (e) {
          // If date parsing fails, fall through to ID comparison
        }
        // Fallback to ID comparison
        return b.purchaseReturnId.compareTo(a.purchaseReturnId);
      });

      // Cache purchase returns in provider
      purchaseProvider.setPurchaseReturns(allPurchaseReturns);
      print('💾 Cached ${allPurchaseReturns.length} total purchase returns');

      // Apply initial filters (which will be no filters, showing all purchase returns)
      _applyFiltersClientSide();
    } catch (e) {
      print('❌ Critical error in _fetchAllPurchaseReturnsOnInit: $e');
      setState(() {
        _errorMessage =
            'Failed to load purchase returns. Please refresh the page.';
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
      // Apply filters to cached purchase returns (no API calls)
      _filterCachedPurchaseReturns();
      print(
        '📦 purchaseProvider.purchaseReturns.length: ${purchaseProvider.purchaseReturns.length}',
      );
      print(
        '🎯 _allFilteredPurchaseReturns.length: ${_allFilteredPurchaseReturns.length}',
      );
      print(
        '👀 _filteredPurchaseReturns.length: ${_filteredPurchaseReturns.length}',
      );
    } catch (e) {
      print('❌ Error in _applyFiltersClientSide: $e');
      setState(() {
        _errorMessage = 'Search error: Please try a different search term';
        _isLoading = false;
        _filteredPurchaseReturns = [];
      });
    }
  }

  // Filter cached purchase returns without any API calls
  void _filterCachedPurchaseReturns() {
    final purchaseProvider = Provider.of<PurchaseProvider>(
      context,
      listen: false,
    );

    try {
      // Apply filters to cached purchase returns
      _allFilteredPurchaseReturns = purchaseProvider.purchaseReturns;
      print(
        '🔍 After filtering: ${_allFilteredPurchaseReturns.length} purchase returns match criteria',
      );
      // Apply local pagination to filtered results
      _paginateFilteredPurchaseReturns();
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('❌ Critical error in _filterCachedPurchaseReturns: $e');
      setState(() {
        _errorMessage =
            'Search failed. Please try again with a simpler search term.';
        _isLoading = false;
        // Fallback: show empty results instead of crashing
        _filteredPurchaseReturns = [];
        _allFilteredPurchaseReturns = [];
      });
    }
  }

  // Apply local pagination to filtered purchase returns
  void _paginateFilteredPurchaseReturns() {
    try {
      // Handle empty results case
      if (_allFilteredPurchaseReturns.isEmpty) {
        setState(() {
          _filteredPurchaseReturns = [];
        });
        return;
      }

      final startIndex = (currentPage - 1) * itemsPerPage;
      final endIndex = startIndex + itemsPerPage;

      // Ensure startIndex is not greater than the list length
      if (startIndex >= _allFilteredPurchaseReturns.length) {
        // Reset to page 1 if current page is out of bounds
        setState(() {
          currentPage = 1;
        });
        _paginateFilteredPurchaseReturns(); // Recursive call with corrected page
        return;
      }

      setState(() {
        _filteredPurchaseReturns = _allFilteredPurchaseReturns.sublist(
          startIndex,
          endIndex > _allFilteredPurchaseReturns.length
              ? _allFilteredPurchaseReturns.length
              : endIndex,
        );
      });
    } catch (e) {
      print('❌ Error in _paginateFilteredPurchaseReturns: $e');
      setState(() {
        _filteredPurchaseReturns = [];
        currentPage = 1;
      });
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateString; // Return original string if parsing fails
    }
  }

  Future<void> _deletePurchaseReturn(int purchaseReturnId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Purchase Return'),
        content: const Text(
          'Are you sure you want to delete this purchase return? This action cannot be undone.',
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
        await PurchaseReturnService.deletePurchaseReturn(purchaseReturnId);

        final purchaseProvider = Provider.of<PurchaseProvider>(
          context,
          listen: false,
        );

        // Remove from local cache
        List<PurchaseReturn> updatedPurchaseReturns = List.from(
          purchaseProvider.purchaseReturns,
        );
        updatedPurchaseReturns.removeWhere(
          (purchaseReturn) =>
              purchaseReturn.purchaseReturnId == purchaseReturnId,
        );
        purchaseProvider.setPurchaseReturns(updatedPurchaseReturns);

        // Re-apply filters to update the display
        _applyFiltersClientSide();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Purchase return deleted successfully'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete purchase return: $e')),
          );
        }
      }
    }
  }

  // View purchase return details
  Future<void> _viewPurchaseReturnDetails(int purchaseReturnId) async {
    // Show dialog immediately with loading state
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading purchase return details...'),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final purchaseReturn = await PurchaseReturnService.getPurchaseReturnById(
        purchaseReturnId,
      );

      // Close loading dialog and show details dialog
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showPurchaseReturnDetailsDialog(purchaseReturn);
      }
    } catch (e) {
      // Close loading dialog and show error
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load purchase return details: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Edit purchase return
  Future<void> _editPurchaseReturn(int purchaseReturnId) async {
    // Show dialog immediately with loading state
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Card(
            child: Padding(
              padding: EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading purchase return for editing...'),
                ],
              ),
            ),
          ),
        );
      },
    );

    try {
      final purchaseReturn = await PurchaseReturnService.getPurchaseReturnById(
        purchaseReturnId,
      );

      // Close loading dialog and show edit dialog
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showEditPurchaseReturnDialog(purchaseReturn);
      }
    } catch (e) {
      // Close loading dialog and show error
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load purchase return for editing: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  double _getTotalReturnedAmountFiltered() {
    return _allFilteredPurchaseReturns.fold(
      0.0,
      (sum, item) => sum + (double.tryParse(item.returnAmount) ?? 0.0),
    );
  }

  double _getTotalPaidAmountFiltered() {
    // Since the API doesn't provide paid amounts, we'll assume all amounts are paid for now
    // In a real implementation, you might need to calculate this differently
    return _getTotalReturnedAmountFiltered();
  }

  double _getTotalDueAmountFiltered() {
    // Since the API doesn't provide due amounts, we'll return 0 for now
    return 0.0;
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

    // Always use client-side pagination when we have cached purchase returns
    if (purchaseProvider.purchaseReturns.isNotEmpty) {
      _paginateFilteredPurchaseReturns();
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
    super.dispose();
  }

  // RouteAware callbacks
  @override
  void didPush() {
    print('📍 PurchaseReturnPage: didPush - refreshing purchase returns');
    _fetchAllPurchaseReturnsOnInit(forceRefresh: true);
  }

  @override
  void didPopNext() {
    print('📍 PurchaseReturnPage: didPopNext - refreshing purchase returns');
    _fetchAllPurchaseReturnsOnInit(forceRefresh: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      _fetchAllPurchaseReturnsOnInit(forceRefresh: true);
    }
  }

  bool _canGoToNextPage() {
    final totalPages = _getTotalPages();
    return currentPage < totalPages;
  }

  int _getTotalPages() {
    if (_allFilteredPurchaseReturns.isEmpty) return 1;
    return (_allFilteredPurchaseReturns.length / itemsPerPage).ceil();
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withValues(alpha: 0.8),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Return'),
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF0D1845).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              margin: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.assignment_return,
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
                              'Purchase Return Management',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            Text(
                              'Track and manage all purchase return transactions',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withValues(alpha: 0.8),
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
                              builder: (context) =>
                                  const CreatePurchaseReturnPage(),
                            ),
                          );

                          // If purchase return was created successfully, force refresh to show new return at top
                          if (result == true) {
                            setState(() {
                              currentPage = 1; // Reset to first page
                              _isLoading = true;
                            });
                            await _fetchAllPurchaseReturnsOnInit(
                              forceRefresh: true,
                            );

                            // Show success message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle,
                                      color: Colors.white,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Purchase return created successfully!',
                                    ),
                                  ],
                                ),
                                backgroundColor: Color(0xFF28A745),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text(
                          'Add Return',
                          style: TextStyle(fontSize: 12),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D1845),
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
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Summary Cards - More compact
                  Row(
                    children: [
                      _buildSummaryCard(
                        'Total Returns',
                        '${_allFilteredPurchaseReturns.length}',
                        Icons.assignment_return,
                        const Color(0xFF2196F3),
                      ),
                      _buildSummaryCard(
                        'Total Amount',
                        'Rs. ${_getTotalReturnedAmountFiltered().toStringAsFixed(2)}',
                        Icons.attach_money,
                        const Color(0xFF4CAF50),
                      ),
                      _buildSummaryCard(
                        'Paid Amount',
                        'Rs. ${_getTotalPaidAmountFiltered().toStringAsFixed(2)}',
                        Icons.check_circle,
                        const Color(0xFF8BC34A),
                      ),
                      _buildSummaryCard(
                        'Due Amount',
                        'Rs. ${_getTotalDueAmountFiltered().toStringAsFixed(2)}',
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
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text('Vendor Name', style: _headerStyle()),
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
                            child: Text(
                              'Total Returned Amount',
                              style: _headerStyle(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text('Actions', style: _headerStyle()),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Body
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _errorMessage.isNotEmpty
                          ? Center(
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
                                    'Error loading purchase returns',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.red,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    _errorMessage,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _fetchAllPurchaseReturnsOnInit,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _filteredPurchaseReturns.isEmpty
                          ? const Center(
                              child: Text(
                                'No purchase returns found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredPurchaseReturns.length,
                              itemBuilder: (context, index) {
                                final purchaseReturn =
                                    _filteredPurchaseReturns[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
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
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: Color(
                                                  0xFF0D1845,
                                                ).withValues(alpha: 0.1),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Icon(
                                                Icons.business,
                                                color: Color(0xFF0D1845),
                                                size: 16,
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                purchaseReturn.vendor.fullName,
                                                style: _cellStyle(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: InkWell(
                                          onTap: () {
                                            // TODO: Navigate to original purchase
                                          },
                                          child: Text(
                                            purchaseReturn.returnInvNo,
                                            style: _cellStyle().copyWith(
                                              color: Colors.blue,
                                              decoration:
                                                  TextDecoration.underline,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          _formatDate(
                                            purchaseReturn.returnDate,
                                          ),
                                          style: _cellStyle(),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Rs. ${double.tryParse(purchaseReturn.returnAmount)?.toStringAsFixed(2) ?? '0.00'}',
                                          style: _cellStyle(),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            // View button
                                            IconButton(
                                              icon: Icon(
                                                Icons.visibility,
                                                color: Color(0xFF17A2B8),
                                                size: 18,
                                              ),
                                              onPressed: () =>
                                                  _viewPurchaseReturnDetails(
                                                    purchaseReturn
                                                        .purchaseReturnId,
                                                  ),
                                              tooltip: 'View Details',
                                              padding: EdgeInsets.all(4),
                                              constraints: BoxConstraints(
                                                minWidth: 32,
                                                minHeight: 32,
                                              ),
                                            ),
                                            SizedBox(width: 4),
                                            // Edit button
                                            // IconButton(
                                            //   icon: Icon(
                                            //     Icons.edit,
                                            //     color: Color(0xFF28A745),
                                            //     size: 18,
                                            //   ),
                                            //   onPressed: () =>
                                            //       _editPurchaseReturn(
                                            //         purchaseReturn
                                            //             .purchaseReturnId,
                                            //       ),
                                            //   tooltip: 'Edit Purchase Return',
                                            //   padding: EdgeInsets.all(4),
                                            //   constraints: BoxConstraints(
                                            //     minWidth: 32,
                                            //     minHeight: 32,
                                            //   ),
                                            // ),
                                            // SizedBox(width: 4),
                                            // Delete button
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete,
                                                color: Color(0xFFDC3545),
                                                size: 18,
                                              ),
                                              onPressed: () =>
                                                  _deletePurchaseReturn(
                                                    purchaseReturn
                                                        .purchaseReturnId,
                                                  ),
                                              tooltip: 'Delete Purchase Return',
                                              padding: EdgeInsets.all(4),
                                              constraints: BoxConstraints(
                                                minWidth: 32,
                                                minHeight: 32,
                                              ),
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

                    // Pagination - Traditional page buttons
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
                            icon: Icon(Icons.chevron_left, size: 14),
                            label: Text(
                              'Previous',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: currentPage > 1
                                  ? Color(0xFF17A2B8)
                                  : Color(0xFF6C757D),
                              elevation: 0,
                              side: BorderSide(color: Color(0xFFDEE2E6)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
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
                            icon: Icon(Icons.chevron_right, size: 14),
                            label: Text('Next', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _canGoToNextPage()
                                  ? Color(0xFF17A2B8)
                                  : Colors.grey.shade300,
                              foregroundColor: _canGoToNextPage()
                                  ? Colors.white
                                  : Colors.grey.shade600,
                              elevation: _canGoToNextPage() ? 2 : 0,
                              side: _canGoToNextPage()
                                  ? null
                                  : BorderSide(color: Color(0xFFDEE2E6)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
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
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Page $currentPage of ${_getTotalPages()} (${_filteredPurchaseReturns.length} items)',
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
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper method to show purchase return details dialog
  void _showPurchaseReturnDetailsDialog(PurchaseReturn purchaseReturn) {
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
                          Icons.assignment_return,
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
                              'Purchase Return Details',
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
                                'Invoice: ${purchaseReturn.returnInvNo}',
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
                                    (double.tryParse(
                                              purchaseReturn.returnAmount,
                                            ) ??
                                            0) >
                                        0
                                    ? Color(0xFF28A745).withOpacity(0.1)
                                    : Color(0xFFDC3545).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      (double.tryParse(
                                                purchaseReturn.returnAmount,
                                              ) ??
                                              0) >
                                          0
                                      ? Color(0xFF28A745)
                                      : Color(0xFFDC3545),
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    (double.tryParse(
                                                  purchaseReturn.returnAmount,
                                                ) ??
                                                0) >
                                            0
                                        ? Icons.check_circle
                                        : Icons.pending,
                                    color:
                                        (double.tryParse(
                                                  purchaseReturn.returnAmount,
                                                ) ??
                                                0) >
                                            0
                                        ? Color(0xFF28A745)
                                        : Color(0xFFDC3545),
                                    size: 18,
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    (double.tryParse(
                                                  purchaseReturn.returnAmount,
                                                ) ??
                                                0) >
                                            0
                                        ? 'COMPLETED'
                                        : 'PENDING',
                                    style: TextStyle(
                                      color:
                                          (double.tryParse(
                                                    purchaseReturn.returnAmount,
                                                  ) ??
                                                  0) >
                                              0
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
                              'ID: ${purchaseReturn.purchaseReturnId}',
                              style: TextStyle(
                                color: Color(0xFF6C757D),
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 24),

                        // Return Information Card
                        _buildInfoCard(
                          'Return Information',
                          Icons.assignment_return,
                          Color(0xFF2196F3),
                          [
                            _buildModernDetailRow(
                              'Return Date',
                              purchaseReturn.returnDate.isNotEmpty
                                  ? DateFormat('dd MMM yyyy').format(
                                      DateTime.parse(purchaseReturn.returnDate),
                                    )
                                  : 'N/A',
                              Icons.calendar_today,
                            ),
                            _buildModernDetailRow(
                              'Vendor',
                              purchaseReturn.vendor.fullName,
                              Icons.business,
                            ),
                            _buildModernDetailRow(
                              'Return Invoice No',
                              purchaseReturn.returnInvNo,
                              Icons.receipt,
                            ),
                            _buildModernDetailRow(
                              'Reason',
                              purchaseReturn.reason,
                              Icons.description,
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
                                '${purchaseReturn.discountPercent}%',
                                Color(0xFFFFA726),
                              ),
                              SizedBox(height: 12),
                              Divider(thickness: 1.5),
                              SizedBox(height: 12),
                              _buildFinancialRow(
                                'Total Return Amount',
                                'Rs. ${double.tryParse(purchaseReturn.returnAmount)?.toStringAsFixed(2) ?? '0.00'}',
                                Color(0xFF28A745),
                                isTotal: true,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),

                        // Return Items Table
                        Container(
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
                            children: [
                              // Table Header
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Color(0xFFF8F9FA),
                                      Color(0xFFE9ECEF),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.only(
                                    topLeft: Radius.circular(16),
                                    topRight: Radius.circular(16),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.shopping_cart,
                                      color: Color(0xFF0D1845),
                                      size: 20,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      'Return Items',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0D1845),
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Column Headers
                              Container(
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Color(0xFFF8F9FA),
                                  border: Border(
                                    top: BorderSide(color: Color(0xFFDEE2E6)),
                                    bottom: BorderSide(
                                      color: Color(0xFFDEE2E6),
                                    ),
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
                                          color: Color(0xFF495057),
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        'Qty',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF495057),
                                          fontSize: 13,
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
                                          color: Color(0xFF495057),
                                          fontSize: 13,
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
                                          color: Color(0xFF495057),
                                          fontSize: 13,
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
                                          color: Color(0xFF495057),
                                          fontSize: 13,
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
                                          color: Color(0xFF495057),
                                          fontSize: 13,
                                        ),
                                        textAlign: TextAlign.right,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Items
                              ...purchaseReturn.details.asMap().entries.map((
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
                                          index <
                                              purchaseReturn.details.length - 1
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
                                                'Product ID: ${detail.productId}',
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
                                          detail.qty,
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
                                          'Rs. ${(double.tryParse(detail.unitPrice)! * double.tryParse(detail.qty)! - double.tryParse(detail.discAmount)!).toStringAsFixed(2)}',
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

  // Helper methods for view dialog
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

  // Helper method to show edit purchase return dialog
  void _showEditPurchaseReturnDialog(PurchaseReturn purchaseReturn) {
    // Controllers for form fields
    final _editReturnDateController = TextEditingController(
      text: purchaseReturn.returnDate,
    );
    final _editReturnInvNoController = TextEditingController(
      text: purchaseReturn.returnInvNo,
    );
    final _editReasonController = TextEditingController(
      text: purchaseReturn.reason,
    );
    final _editDiscountPercentController = TextEditingController(
      text: purchaseReturn.discountPercent.isEmpty
          ? '0'
          : purchaseReturn.discountPercent,
    );

    String _editSelectedPaymentStatus = 'unpaid';
    int? _editSelectedPurchaseId = purchaseReturn.purchase != null
        ? purchaseReturn.purchase['id']
        : null;
    int _editSelectedVendorId = purchaseReturn.vendor.id;
    List<Map<String, dynamic>> _editDetails = purchaseReturn.details
        .map(
          (detail) => {
            'product_id': int.tryParse(detail.productId) ?? 0,
            'qty': double.tryParse(detail.qty) ?? 0.0,
            'unit_price': double.tryParse(detail.unitPrice) ?? 0.0,
            'discPer': double.tryParse(detail.discPer) ?? 0.0,
            'discAmount': double.tryParse(detail.discAmount) ?? 0.0,
          },
        )
        .toList();

    // Calculate functions
    double _calculateEditSubtotal() {
      return _editDetails.fold(
        0.0,
        (sum, item) => sum + (item['unit_price'] * item['qty']),
      );
    }

    double _calculateEditDiscountAmount() {
      double subtotal = _calculateEditSubtotal();
      double discountPercent =
          double.tryParse(_editDiscountPercentController.text) ?? 0;
      return subtotal * (discountPercent / 100);
    }

    double _calculateEditTotalAmount() {
      double subtotal = _calculateEditSubtotal();
      double discountAmount = _calculateEditDiscountAmount();
      return subtotal - discountAmount;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: Column(
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0D1845),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.edit, color: Colors.white, size: 28),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Edit Purchase Return',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                                Text(
                                  'Invoice: ${purchaseReturn.returnInvNo}',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
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
                            // Basic Information
                            Text(
                              'Basic Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D1845),
                              ),
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _editReturnDateController,
                                    decoration: InputDecoration(
                                      labelText: 'Return Date',
                                      hintText: 'YYYY-MM-DD',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _editReturnInvNoController,
                                    decoration: InputDecoration(
                                      labelText: 'Return Invoice No',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            TextFormField(
                              controller: _editReasonController,
                              maxLines: 3,
                              decoration: InputDecoration(
                                labelText: 'Reason',
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Financial Information
                            Text(
                              'Financial Information',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0D1845),
                              ),
                            ),
                            const SizedBox(height: 16),

                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _editDiscountPercentController,
                                    keyboardType:
                                        TextInputType.numberWithOptions(
                                          decimal: true,
                                        ),
                                    decoration: InputDecoration(
                                      labelText: 'Discount Percent (%)',
                                      suffixText: '%',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        // Trigger recalculation
                                      });
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    value: _editSelectedPaymentStatus,
                                    decoration: InputDecoration(
                                      labelText: 'Payment Status',
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 16,
                                      ),
                                    ),
                                    items: ['paid', 'unpaid', 'partial']
                                        .map(
                                          (status) => DropdownMenuItem(
                                            value: status,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  status == 'paid'
                                                      ? Icons.check_circle
                                                      : Icons.pending,
                                                  color: status == 'paid'
                                                      ? Color(0xFF28A745)
                                                      : Color(0xFFFFA726),
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text(status.toUpperCase()),
                                              ],
                                            ),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _editSelectedPaymentStatus = value;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Return Items
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Return Items',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D1845),
                                  ),
                                ),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _editDetails.add({
                                        'product_id': 0,
                                        'qty': 0.0,
                                        'unit_price': 0.0,
                                        'discPer': 0.0,
                                        'discAmount': 0.0,
                                      });
                                    });
                                  },
                                  icon: Icon(Icons.add, size: 16),
                                  label: Text('Add Item'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Color(0xFF0D1845),
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            ..._editDetails.asMap().entries.map((entry) {
                              final index = entry.key;
                              final detail = entry.value;
                              return Container(
                                margin: EdgeInsets.only(bottom: 16),
                                padding: EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: detail['product_id']
                                                .toString(),
                                            decoration: InputDecoration(
                                              labelText: 'Product ID',
                                              border: OutlineInputBorder(),
                                            ),
                                            keyboardType: TextInputType.number,
                                            onChanged: (value) {
                                              detail['product_id'] =
                                                  int.tryParse(value) ?? 0;
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: detail['qty']
                                                .toString(),
                                            decoration: InputDecoration(
                                              labelText: 'Quantity',
                                              border: OutlineInputBorder(),
                                            ),
                                            keyboardType: TextInputType.number,
                                            onChanged: (value) {
                                              setState(() {
                                                detail['qty'] =
                                                    double.tryParse(value) ??
                                                    0.0;
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: detail['unit_price']
                                                .toString(),
                                            decoration: InputDecoration(
                                              labelText: 'Unit Price',
                                              border: OutlineInputBorder(),
                                            ),
                                            keyboardType:
                                                TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            onChanged: (value) {
                                              setState(() {
                                                detail['unit_price'] =
                                                    double.tryParse(value) ??
                                                    0.0;
                                              });
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: TextFormField(
                                            initialValue: detail['discPer']
                                                .toString(),
                                            decoration: InputDecoration(
                                              labelText: 'Discount %',
                                              border: OutlineInputBorder(),
                                            ),
                                            keyboardType:
                                                TextInputType.numberWithOptions(
                                                  decimal: true,
                                                ),
                                            onChanged: (value) {
                                              setState(() {
                                                detail['discPer'] =
                                                    double.tryParse(value) ??
                                                    0.0;
                                                // Calculate discount amount
                                                detail['discAmount'] =
                                                    (detail['unit_price'] *
                                                    detail['qty'] *
                                                    detail['discPer'] /
                                                    100);
                                              });
                                            },
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Container(
                                            padding: EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Color(0xFFF8F9FA),
                                              border: Border.all(
                                                color: Color(0xFFDEE2E6),
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Discount Amount',
                                                  style: TextStyle(
                                                    fontSize: 12,
                                                    color: Color(0xFF6C757D),
                                                  ),
                                                ),
                                                SizedBox(height: 4),
                                                Text(
                                                  'Rs. ${detail['discAmount'].toStringAsFixed(2)}',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                    color: Color(0xFFDC3545),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        IconButton(
                                          onPressed: () {
                                            setState(() {
                                              _editDetails.removeAt(index);
                                            });
                                          },
                                          icon: Icon(
                                            Icons.delete,
                                            color: Colors.red,
                                          ),
                                          tooltip: 'Remove Item',
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),

                            const SizedBox(height: 24),

                            // Summary
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFF8F9FA),
                                    Color(0xFFE9ECEF),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Color(0xFFDEE2E6)),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.shopping_cart,
                                            color: Color(0xFF6C757D),
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Subtotal:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF495057),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'Rs. ${_calculateEditSubtotal().toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.discount,
                                            color: Color(0xFFDC3545),
                                            size: 18,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Discount (${_editDiscountPercentController.text}%):',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFFDC3545),
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '- Rs. ${_calculateEditDiscountAmount().toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFFDC3545),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Divider(thickness: 2),
                                  const SizedBox(height: 12),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.account_balance_wallet,
                                            color: Color(0xFF28A745),
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Total Amount:',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 18,
                                              color: Color(0xFF28A745),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        'Rs. ${_calculateEditTotalAmount().toStringAsFixed(2)}',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: Color(0xFF28A745),
                                        ),
                                      ),
                                    ],
                                  ),
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
                          bottomLeft: Radius.circular(16),
                          bottomRight: Radius.circular(16),
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
                          TextButton.icon(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(Icons.close, size: 18),
                            label: const Text('Cancel'),
                            style: TextButton.styleFrom(
                              foregroundColor: Color(0xFF6C757D),
                              padding: EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            onPressed: () async {
                              try {
                                // Show loading
                                showDialog(
                                  context: context,
                                  barrierDismissible: false,
                                  builder: (BuildContext context) {
                                    return Center(
                                      child: Card(
                                        child: Padding(
                                          padding: EdgeInsets.all(20),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircularProgressIndicator(),
                                              SizedBox(height: 16),
                                              Text(
                                                'Updating purchase return...',
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );

                                // Prepare update data according to API spec
                                final updateData = {
                                  'return_date': _editReturnDateController.text,
                                  if (_editSelectedPurchaseId != null)
                                    'purchase_id': _editSelectedPurchaseId,
                                  'return_inv_no':
                                      _editReturnInvNoController.text,
                                  'vendor_id': _editSelectedVendorId,
                                  'reason': _editReasonController.text,
                                  'total_amount': _calculateEditTotalAmount(),
                                  'payment_status': _editSelectedPaymentStatus,
                                  'details': _editDetails,
                                };

                                // Call API
                                await PurchaseReturnService.updatePurchaseReturn(
                                  purchaseReturn.purchaseReturnId,
                                  updateData,
                                );

                                // Close loading dialog
                                if (mounted) {
                                  Navigator.of(context).pop();

                                  // Close edit dialog
                                  Navigator.of(context).pop();

                                  // Show success message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 12),
                                          Text(
                                            'Purchase return updated successfully',
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Color(0xFF28A745),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );

                                  // Refresh the list
                                  setState(() {
                                    currentPage = 1;
                                    _isLoading = true;
                                  });
                                  await _fetchAllPurchaseReturnsOnInit(
                                    forceRefresh: true,
                                  );
                                }
                              } catch (e) {
                                // Close loading dialog
                                if (mounted) {
                                  Navigator.of(context).pop();

                                  // Show error message
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text('Update failed: $e'),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Color(0xFFDC3545),
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                            icon: Icon(Icons.save, size: 18),
                            label: const Text('Update Purchase Return'),
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
      },
    );
  }
}
