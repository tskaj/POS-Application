import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import '../../services/vendor_reporting_service.dart';

enum VendorReportType { all, dues }

class VendorReportPage extends StatefulWidget {
  const VendorReportPage({super.key});

  @override
  State<VendorReportPage> createState() => _VendorReportPageState();
}

class _VendorReportPageState extends State<VendorReportPage> {
  // Report type state
  VendorReportType _currentReportType = VendorReportType.all;

  // Data states
  List<VendorReport> _vendors = [];
  VendorOverallTotals? _overallTotals;
  List<dynamic> _selectedReports = [];
  bool _selectAll = false;
  bool _isLoading = true;
  String? _errorMessage;

  // Pagination
  int _currentPage = 1;
  final int _itemsPerPage = 50;
  int _totalPages = 1;

  // Table scroll controller
  final ScrollController _tableScrollController = ScrollController();

  // Filter states
  String _searchText = '';
  String _statusFilter = 'All';

  @override
  void initState() {
    super.initState();
    _loadVendorReport();
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadVendorReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await VendorReportingService.getAllVendorsReport();
      _vendors = response.data;
      _overallTotals = response.overallTotals;

      // Calculate total pages and reset pagination
      final totalItems = _vendors.length;
      _totalPages = (totalItems / _itemsPerPage).ceil();
      _currentPage = 1;
      _selectedReports.clear();
      _selectAll = false;
    } catch (e) {
      _errorMessage = 'Failed to load vendor report: $e';
      _vendors = [];
      _overallTotals = null;
      _totalPages = 1;
      _currentPage = 1;
      _selectedReports.clear();
      _selectAll = false;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _changeReportType(VendorReportType reportType) {
    if (_currentReportType != reportType) {
      setState(() {
        _currentReportType = reportType;
        _selectedReports.clear();
        _selectAll = false;
        _searchText = '';
        _statusFilter = 'All';
        _currentPage = 1; // Reset to first page when changing report type
      });
      // Reset table scroll position
      _tableScrollController.jumpTo(0.0);
      _loadVendorReport();
    }
  }

  void _toggleReportSelection(dynamic report) {
    setState(() {
      final reportId = _getReportId(report);
      final existingIndex = _selectedReports.indexWhere(
        (r) => _getReportId(r) == reportId,
      );

      if (existingIndex >= 0) {
        _selectedReports.removeAt(existingIndex);
      } else {
        _selectedReports.add(report);
      }

      _updateSelectAllState();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectAll) {
        _selectedReports.clear();
      } else {
        _selectedReports = List.from(_getFilteredReports());
      }
      _selectAll = !_selectAll;
    });
  }

  void _updateSelectAllState() {
    final filteredReports = _getFilteredReports();
    final paginatedReports = _getPaginatedReports(filteredReports);
    _selectAll =
        paginatedReports.isNotEmpty &&
        _selectedReports.length == paginatedReports.length;
  }

  int _getTotalItems() {
    return _vendors.length;
  }

  dynamic _getReportId(dynamic report) {
    return (report as VendorReport).id;
  }

  List<dynamic> _getFilteredReports() {
    List<dynamic> reports = _vendors;

    List<dynamic> filtered = reports.where((report) {
      // Filter by search text (name)
      final name = _getVendorName(report).toLowerCase();
      final matchesSearch =
          _searchText.isEmpty || name.contains(_searchText.toLowerCase());

      // Filter by status
      bool matchesStatus = true;
      if (_statusFilter != 'All') {
        final vendor = report as VendorReport;
        switch (_currentReportType) {
          case VendorReportType.all:
            final hasTransactions = vendor.totalInvoices > 0;
            matchesStatus =
                (_statusFilter == 'Active' && hasTransactions) ||
                (_statusFilter == 'Inactive' && !hasTransactions);
            break;
          case VendorReportType.dues:
            final hasDue =
                vendor.balance < 0; // Negative balance means vendor owes money
            matchesStatus =
                (_statusFilter == 'With Due' && hasDue) ||
                (_statusFilter == 'No Due' && !hasDue);
            break;
        }
      }

      return matchesSearch && matchesStatus;
    }).toList();

    // Sort by name by default
    filtered.sort((a, b) {
      return _getVendorName(a).compareTo(_getVendorName(b));
    });

    return filtered;
  }

  List<dynamic> _getPaginatedReports(List<dynamic> reports) {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return reports.sublist(
      startIndex,
      endIndex > reports.length ? reports.length : endIndex,
    );
  }

  String _getVendorName(dynamic report) {
    return (report as VendorReport).name;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, color: Colors.red, size: 48),
                const SizedBox(height: 16),
                Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _loadVendorReport,
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final filteredReports = _getFilteredReports();
    final paginatedReports = _getPaginatedReports(filteredReports);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Vendor Report'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Vendor Report',
            onPressed: () async {
              setState(() => _isLoading = true);
              await _loadVendorReport();
              setState(() => _isLoading = false);
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
        child: SingleChildScrollView(
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
                          child: Icon(
                            _getReportIcon(),
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
                                _getReportTitle(),
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                _getReportDescription(),
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
                    _buildSummaryCards(filteredReports),
                  ],
                ),
              ),

              // Search and Table
              Container(
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
                              // Report Type Tabs (only All Report)
                              _buildTabButton(
                                'All Report',
                                VendorReportType.all,
                              ),
                              const SizedBox(width: 16),
                              // Search Field
                              Expanded(
                                flex: 2,
                                child: Container(
                                  height: 36,
                                  child: TextField(
                                    onChanged: (value) {
                                      setState(() {
                                        _searchText = value;
                                        _updateSelectAllState();
                                      });
                                    },
                                    decoration: InputDecoration(
                                      hintText: 'Search vendors...',
                                      hintStyle: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
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
                                    style: const TextStyle(fontSize: 13),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Status Filter
                              Expanded(
                                flex: 1,
                                child: Container(
                                  height: 36,
                                  margin: const EdgeInsets.only(right: 8),
                                  child: DropdownButtonFormField<String>(
                                    value: _statusFilter,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Status',
                                      hintStyle: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.filter_list,
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
                                    items: _getStatusFilterOptions()
                                        .map(
                                          (status) => DropdownMenuItem(
                                            value: status,
                                            child: Text(status),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _statusFilter = value;
                                          _updateSelectAllState();
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              SizedBox(
                                height: 32,
                                child: ElevatedButton.icon(
                                  onPressed: _exportToPDF,
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
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Table Section
                    _buildTableSection(paginatedReports),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, VendorReportType reportType) {
    final isSelected = _currentReportType == reportType;
    return ElevatedButton(
      onPressed: () => _changeReportType(reportType),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF0D1845) : Colors.white,
        foregroundColor: isSelected ? Colors.white : const Color(0xFF0D1845),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: isSelected ? 2 : 0,
        side: BorderSide(
          color: isSelected ? const Color(0xFF0D1845) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Text(title, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildSummaryCards(List<dynamic> filteredReports) {
    switch (_currentReportType) {
      case VendorReportType.all:
        return Row(
          children: [
            _buildSummaryCard(
              'Total Vendors',
              '${filteredReports.length}',
              Icons.business,
              Colors.blue,
            ),
            _buildSummaryCard(
              'Total Purchases',
              '${_calculateTotalPurchases(filteredReports)}',
              Icons.shopping_cart,
              Colors.green,
            ),
            _buildSummaryCard(
              'Total Amount',
              'Rs. ${_calculateTotalAmount(filteredReports)}',
              Icons.attach_money,
              Colors.purple,
            ),
            _buildSummaryCard(
              'Active Vendors',
              '${filteredReports.where((r) => (r as VendorReport).totalInvoices > 0).length}',
              Icons.check_circle,
              Colors.orange,
            ),
          ],
        );
      case VendorReportType.dues:
        return Row(
          children: [
            _buildSummaryCard(
              'Total Vendors',
              '${filteredReports.length}',
              Icons.business,
              Colors.blue,
            ),
            _buildSummaryCard(
              'Total Due Amount',
              'Rs. ${_calculateTotalDue(filteredReports)}',
              Icons.money_off,
              Colors.red,
            ),
            _buildSummaryCard(
              'Paid Amount',
              'Rs. ${_calculateTotalPaid(filteredReports)}',
              Icons.payment,
              Colors.green,
            ),
            _buildSummaryCard(
              'Vendors with Due',
              '${filteredReports.where((r) => (r as VendorReport).balance < 0).length}',
              Icons.warning,
              Colors.orange,
            ),
          ],
        );
    }
  }

  Widget _buildTableSection(List<dynamic> paginatedReports) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                // Select Column
                SizedBox(
                  width: 40,
                  child: Checkbox(
                    value: _selectAll,
                    onChanged: (value) => _toggleSelectAll(),
                    activeColor: Color(0xFF0D1845),
                  ),
                ),
                const SizedBox(width: 16),
                // Dynamic columns based on report type
                ..._getTableHeaderColumns(),
              ],
            ),
          ),

          // Table Body
          SizedBox(
            height:
                400, // Fixed height for table body to prevent unbounded constraints
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : paginatedReports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_getReportIcon(), size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No vendor records found',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _tableScrollController,
                    itemCount: paginatedReports.length,
                    itemBuilder: (context, index) {
                      final report = paginatedReports[index];
                      final isSelected = _selectedReports.any(
                        (r) => _getReportId(r) == _getReportId(report),
                      );
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
                            bottom: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Select Column
                            SizedBox(
                              width: 40,
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (value) =>
                                    _toggleReportSelection(report),
                                activeColor: Color(0xFF0D1845),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Dynamic row content based on report type
                            ..._getTableRowColumns(report, isSelected),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Pagination Controls within table
          _buildPaginationControls(),
        ],
      ),
    );
  }

  TextStyle _headerStyle() {
    return const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: Color(0xFF0D1845),
    );
  }

  List<Widget> _getTableHeaderColumns() {
    switch (_currentReportType) {
      case VendorReportType.all:
        return [
          // Vendor ID Column
          Expanded(flex: 1, child: Text('Vendor ID', style: _headerStyle())),
          const SizedBox(width: 8),
          // Vendor Name Column
          Expanded(flex: 1, child: Text('Vendor Name', style: _headerStyle())),
          const SizedBox(width: 8),
          // Number of Invoices Column - Centered
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Number of Invoices (Num of Inv)',
                style: _headerStyle(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Total Amount Column
          Expanded(flex: 1, child: Text('Total Amount', style: _headerStyle())),
          const SizedBox(width: 8),
          // Balance Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: Text('Balance', style: _headerStyle())),
          ),
          const SizedBox(width: 8),
          // View Column
          SizedBox(
            width: 80,
            child: Center(child: Text('Action', style: _headerStyle())),
          ),
        ];
      case VendorReportType.dues:
        return [
          // Vendor ID Column
          Expanded(flex: 1, child: Text('Vendor ID', style: _headerStyle())),
          const SizedBox(width: 8),
          // Vendor Name Column
          Expanded(flex: 1, child: Text('Vendor Name', style: _headerStyle())),
          const SizedBox(width: 8),
          // Email Column
          Expanded(flex: 1, child: Text('Email', style: _headerStyle())),
          const SizedBox(width: 8),
          // Phone Column
          Expanded(flex: 1, child: Text('Phone', style: _headerStyle())),
          const SizedBox(width: 8),
          // Total Purchases Column
          Expanded(
            flex: 1,
            child: Text('Total Purchases', style: _headerStyle()),
          ),
          const SizedBox(width: 8),
          // Total Paid Column
          Expanded(flex: 1, child: Text('Total Paid', style: _headerStyle())),
          const SizedBox(width: 8),
          // Total Due Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: Text('Total Due', style: _headerStyle())),
          ),
          const SizedBox(width: 8),
          // View Column
          SizedBox(
            width: 80,
            child: Center(child: Text('Action', style: _headerStyle())),
          ),
        ];
    }
  }

  List<Widget> _getTableRowColumns(dynamic report, bool isSelected) {
    switch (_currentReportType) {
      case VendorReportType.all:
        final vendor = report as VendorReport;
        return [
          // Vendor ID Column
          Expanded(
            flex: 1,
            child: Text(
              vendor.id,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF495057),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Vendor Name Column
          Expanded(flex: 1, child: _buildVendorCell(vendor.name)),
          const SizedBox(width: 8),
          // Number of Invoices Column - Centered
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                vendor.totalInvoices.toString(),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF495057),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Total Amount Column
          Expanded(
            flex: 1,
            child: Text(
              'Rs. ${vendor.debit.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF495057),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Balance Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: _buildBalanceCell(vendor.balance)),
          ),
          const SizedBox(width: 8),
          // View Button Column
          SizedBox(
            width: 80,
            child: Center(
              child: ElevatedButton(
                onPressed: () => _viewVendorTransactions(vendor),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D1845),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(60, 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('View', style: TextStyle(fontSize: 11)),
              ),
            ),
          ),
        ];
      case VendorReportType.dues:
        final vendor = report as VendorReport;
        return [
          // Vendor ID Column
          Expanded(
            flex: 1,
            child: Text(
              vendor.id,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF495057),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Vendor Name Column
          Expanded(flex: 1, child: _buildVendorCell(vendor.name)),
          const SizedBox(width: 8),
          // Email Column
          Expanded(
            flex: 1,
            child: Text(
              vendor.email,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF495057),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Phone Column
          Expanded(
            flex: 1,
            child: Text(
              vendor.phone,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF495057),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          // Total Purchases Column
          Expanded(
            flex: 1,
            child: Text(
              vendor.totalInvoices.toString(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF495057),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Total Paid Column
          Expanded(
            flex: 1,
            child: Text(
              'Rs. ${vendor.credit.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF495057),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Total Due Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: _buildDueAmountCell(vendor.balance)),
          ),
          const SizedBox(width: 8),
          // View Button Column
          SizedBox(
            width: 80,
            child: Center(
              child: ElevatedButton(
                onPressed: () => _viewVendorTransactions(vendor),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D1845),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  minimumSize: const Size(60, 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: const Text('View', style: TextStyle(fontSize: 11)),
              ),
            ),
          ),
        ];
    }
  }

  Widget _buildVendorCell(String vendorName) {
    return Text(
      vendorName,
      style: TextStyle(fontWeight: FontWeight.w500),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  Widget _buildBalanceCell(double amount) {
    final color = amount >= 0 ? Colors.green : Colors.red;
    return Text(
      'Rs. ${amount.toStringAsFixed(2)}',
      style: TextStyle(fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _buildDueAmountCell(double amount) {
    final color = amount > 0 ? Colors.red : Colors.green;
    return Text(
      'Rs. ${amount.toStringAsFixed(2)}',
      style: TextStyle(fontWeight: FontWeight.bold, color: color),
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

  // Calculation methods
  int _calculateTotalPurchases(List<dynamic> reports) {
    if (_currentReportType != VendorReportType.all) return 0;
    return reports.fold(
      0,
      (sum, report) => sum + (report as VendorReport).totalInvoices,
    );
  }

  String _calculateTotalAmount(List<dynamic> reports) {
    if (_currentReportType != VendorReportType.all) return '0.00';
    final total = reports.fold<double>(0.0, (sum, report) {
      final vendor = report as VendorReport;
      return sum + vendor.debit;
    });
    return total.toStringAsFixed(2);
  }

  String _calculateTotalDue(List<dynamic> reports) {
    if (_currentReportType != VendorReportType.dues) return '0.00';
    final total = reports.fold<double>(
      0.0,
      (sum, report) =>
          sum + ((report.balance < 0) ? report.balance.abs() : 0.0),
    );
    return total.toStringAsFixed(2);
  }

  String _calculateTotalPaid(List<dynamic> reports) {
    if (_currentReportType != VendorReportType.dues) return '0.00';
    final total = reports.fold<double>(
      0.0,
      (sum, report) => sum + (report as VendorReport).credit,
    );
    return total.toStringAsFixed(2);
  }

  Widget _buildPaginationControls() {
    // Show pagination controls even with 1 page for testing
    // if (_totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          IconButton(
            onPressed: _currentPage > 1
                ? () {
                    setState(() {
                      _currentPage--;
                      _updateSelectAllState();
                    });
                    // Reset table scroll position
                    _tableScrollController.jumpTo(0.0);
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
            color: _currentPage > 1 ? Color(0xFF0D1845) : Colors.grey,
            tooltip: 'Previous Page',
          ),

          // Page numbers
          ..._buildPageNumbers(),

          // Next button
          IconButton(
            onPressed: _currentPage < _totalPages
                ? () {
                    setState(() {
                      _currentPage++;
                      _updateSelectAllState();
                    });
                    // Reset table scroll position
                    _tableScrollController.jumpTo(0.0);
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
            color: _currentPage < _totalPages ? Color(0xFF0D1845) : Colors.grey,
            tooltip: 'Next Page',
          ),

          // Page info
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFF0D1845).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Page $_currentPage of $_totalPages',
              style: TextStyle(
                color: Color(0xFF0D1845),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> pageNumbers = [];
    int startPage = 1;
    int endPage = _totalPages;

    // Show max 5 page numbers at a time
    if (_totalPages > 5) {
      if (_currentPage <= 3) {
        endPage = 5;
      } else if (_currentPage >= _totalPages - 2) {
        startPage = _totalPages - 4;
      } else {
        startPage = _currentPage - 2;
        endPage = _currentPage + 2;
      }
    }

    for (int i = startPage; i <= endPage; i++) {
      pageNumbers.add(
        InkWell(
          onTap: () {
            setState(() {
              _currentPage = i;
              _updateSelectAllState();
            });
            // Reset table scroll position
            _tableScrollController.jumpTo(0.0);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _currentPage == i ? Color(0xFF0D1845) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _currentPage == i
                    ? Color(0xFF0D1845)
                    : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Text(
              i.toString(),
              style: TextStyle(
                color: _currentPage == i ? Colors.white : Color(0xFF0D1845),
                fontWeight: _currentPage == i
                    ? FontWeight.bold
                    : FontWeight.normal,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
    }

    return pageNumbers;
  }

  String _getReportTitle() {
    switch (_currentReportType) {
      case VendorReportType.all:
        return 'All Vendor Reports';
      case VendorReportType.dues:
        return 'Vendor Due Reports';
    }
  }

  Future<void> _exportToPDF() async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Generating PDF...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final PdfDocument document = PdfDocument();
      final PdfPage page = document.pages.add();
      final PdfGraphics graphics = page.graphics;

      final Size pageSize = page.getClientSize();
      final PdfFont headerFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        14,
        style: PdfFontStyle.bold,
      );
      final PdfFont titleFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        20,
        style: PdfFontStyle.bold,
      );
      final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 10);

      double yPos = 20;

      // Header
      graphics.drawString(
        _getReportTitle(),
        titleFont,
        bounds: Rect.fromLTWH(20, yPos, pageSize.width - 40, 30),
        brush: PdfSolidBrush(PdfColor(13, 24, 69)),
      );

      yPos += 35;

      // Date and filters info
      String filterInfo =
          'Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}';

      graphics.drawString(
        filterInfo,
        smallFont,
        bounds: Rect.fromLTWH(20, yPos, pageSize.width - 40, 20),
        brush: PdfSolidBrush(PdfColor(100, 100, 100)),
      );

      yPos += 30;

      // Create table
      final PdfGrid grid = PdfGrid();
      grid.columns.add(
        count: _currentReportType == VendorReportType.all ? 5 : 7,
      );

      final double pageWidth = pageSize.width;
      final double tableWidth = pageWidth * 0.95;

      // Set column widths based on report type
      switch (_currentReportType) {
        case VendorReportType.all:
          grid.columns[0].width = tableWidth * 0.15; // Vendor ID
          grid.columns[1].width = tableWidth * 0.20; // Vendor Name
          grid.columns[2].width = tableWidth * 0.20; // Number of Invoices
          grid.columns[3].width = tableWidth * 0.25; // Total Amount
          grid.columns[4].width = tableWidth * 0.20; // Balance
          break;
        case VendorReportType.dues:
          grid.columns[0].width = tableWidth * 0.15; // Vendor ID
          grid.columns[1].width = tableWidth * 0.20; // Vendor Name
          grid.columns[2].width = tableWidth * 0.15; // Email
          grid.columns[3].width = tableWidth * 0.15; // Phone
          grid.columns[4].width = tableWidth * 0.15; // Total Purchases
          grid.columns[5].width = tableWidth * 0.15; // Total Paid
          grid.columns[6].width = tableWidth * 0.15; // Total Due
          break;
      }

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
        font: smallFont,
      );

      // Header row
      final PdfGridRow headerRow = grid.headers.add(1)[0];
      final PdfColor tableHeaderColor = PdfColor(248, 249, 250);

      switch (_currentReportType) {
        case VendorReportType.all:
          headerRow.cells[0].value = 'Vendor ID';
          headerRow.cells[1].value = 'Vendor Name';
          headerRow.cells[2].value = 'Number of Invoices (Num of Inv)';
          headerRow.cells[3].value = 'Total Amount';
          headerRow.cells[4].value = 'Balance';
          break;
        case VendorReportType.dues:
          headerRow.cells[0].value = 'Vendor ID';
          headerRow.cells[1].value = 'Vendor Name';
          headerRow.cells[2].value = 'Email';
          headerRow.cells[3].value = 'Phone';
          headerRow.cells[4].value = 'Total Purchases';
          headerRow.cells[5].value = 'Total Paid';
          headerRow.cells[6].value = 'Total Due';
          break;
      }

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

      // Data rows
      final filteredReports = _getFilteredReports();
      for (var report in filteredReports) {
        final PdfGridRow row = grid.rows.add();

        switch (_currentReportType) {
          case VendorReportType.all:
            final vendor = report as VendorReport;
            row.cells[0].value = vendor.id;
            row.cells[1].value = vendor.name;
            row.cells[2].value = vendor.totalInvoices.toString();
            row.cells[3].value = 'Rs ${vendor.debit.toStringAsFixed(2)}';
            row.cells[4].value = 'Rs ${vendor.balance.toStringAsFixed(2)}';
            break;
          case VendorReportType.dues:
            final vendor = report as VendorReport;
            row.cells[0].value = vendor.id;
            row.cells[1].value = vendor.name;
            row.cells[2].value = vendor.email;
            row.cells[3].value = vendor.phone;
            row.cells[4].value = vendor.totalInvoices.toString();
            row.cells[5].value = 'Rs ${vendor.credit.toStringAsFixed(2)}';
            row.cells[6].value = 'Rs ${vendor.balance.toStringAsFixed(2)}';
            break;
        }

        for (int i = 0; i < row.cells.count; i++) {
          row.cells[i].style = PdfGridCellStyle(
            font: smallFont,
            textBrush: PdfSolidBrush(PdfColor(33, 37, 41)),
            format: PdfStringFormat(
              alignment: PdfTextAlignment.center,
              lineAlignment: PdfVerticalAlignment.middle,
            ),
          );
        }
      }

      grid.draw(
        page: page,
        bounds: Rect.fromLTWH(
          10,
          yPos,
          pageSize.width - 20,
          pageSize.height - yPos - 40,
        ),
      );

      // Get PDF bytes
      final List<int> bytes = await document.save();
      document.dispose();

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show minimize message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Minimize application to save PDF'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      // Save file
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Vendor Report PDF',
        fileName:
            'vendor_report_${_currentReportType == VendorReportType.all ? 'all' : 'dues'}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFile != null) {
        final File file = File(outputFile);
        await file.writeAsBytes(bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('PDF exported successfully to ${file.path}'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to export PDF: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  String _getReportDescription() {
    switch (_currentReportType) {
      case VendorReportType.all:
        return 'Complete vendor purchase history and details';
      case VendorReportType.dues:
        return 'Vendor payment status and outstanding dues';
    }
  }

  IconData _getReportIcon() {
    switch (_currentReportType) {
      case VendorReportType.all:
        return Icons.business;
      case VendorReportType.dues:
        return Icons.account_balance_wallet;
    }
  }

  void _viewVendorTransactions(VendorReport vendor) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading vendor transactions...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      // Some vendor ids come as codes like "VNDR-6"; extract the numeric DB id before calling API.
      final numericId = RegExp(r"\d+").firstMatch(vendor.id)?.group(0);
      if (numericId == null) {
        if (mounted) Navigator.of(context).pop();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Invalid vendor id: ${vendor.id}'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final response = await VendorReportingService.getVendorTransactions(
        numericId,
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog

        showDialog(
          context: context,
          builder: (context) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.9,
              height: MediaQuery.of(context).size.height * 0.9,
              child: Column(
                children: [
                  // Header
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
                      ),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.business, color: Colors.white, size: 32),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    vendor.id,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                    ),
                                  ),
                                  Text(
                                    vendor.name,
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close, color: Colors.white),
                              onPressed: () => Navigator.of(context).pop(),
                            ),
                          ],
                        ),
                        SizedBox(height: 16),
                        // Summary cards
                        Row(
                          children: [
                            _buildDetailSummaryCard(
                              'Total Debit',
                              'Rs. ${response.totalDebit.toStringAsFixed(2)}',
                              Icons.arrow_downward,
                              Colors.red,
                            ),
                            SizedBox(width: 8),
                            _buildDetailSummaryCard(
                              'Total Credit',
                              'Rs. ${response.totalCredit.toStringAsFixed(2)}',
                              Icons.arrow_upward,
                              Colors.green,
                            ),
                            SizedBox(width: 8),
                            _buildDetailSummaryCard(
                              'Balance',
                              'Rs. ${response.balance.toStringAsFixed(2)}',
                              Icons.account_balance,
                              response.balance >= 0 ? Colors.blue : Colors.red,
                            ),
                            SizedBox(width: 8),
                            _buildDetailSummaryCard(
                              'Total Transactions',
                              '${response.totalTransactions}',
                              Icons.receipt,
                              Colors.purple,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Transactions list area
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          // Table header (dark)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              vertical: 12,
                              horizontal: 12,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D1845),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Trans ID',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Date',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 2,
                                  child: Text(
                                    'Description',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.left,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Debit',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 1,
                                  child: Text(
                                    'Credit',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Table body
                          Expanded(
                            child: response.transactions.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: const [
                                        Icon(
                                          Icons.receipt_long,
                                          size: 48,
                                          color: Colors.grey,
                                        ),
                                        SizedBox(height: 16),
                                        Text(
                                          'No transactions found',
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    itemCount: response.transactions.length,
                                    itemBuilder: (context, index) {
                                      final transaction =
                                          response.transactions[index];
                                      final isEven = index % 2 == 0;
                                      return Container(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 12,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isEven
                                              ? Colors.white
                                              : Colors.grey[50],
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
                                        child: Row(
                                          children: [
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                transaction.transId,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                transaction.date,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                transaction.description,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                transaction.debit,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.red,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                transaction.credit,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.green,
                                                ),
                                                textAlign: TextAlign.center,
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
                ],
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load vendor transactions: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildDetailSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withOpacity(0.8),
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  List<String> _getStatusFilterOptions() {
    switch (_currentReportType) {
      case VendorReportType.all:
        return ['All', 'Active', 'Inactive'];
      case VendorReportType.dues:
        return ['All', 'With Due', 'No Due'];
    }
  }
}
