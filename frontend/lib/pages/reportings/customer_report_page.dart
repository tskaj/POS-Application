import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import '../../services/customer_reporting_service.dart';

enum CustomerReportType { invoices, dues }

class CustomerReportPage extends StatefulWidget {
  const CustomerReportPage({super.key});

  @override
  State<CustomerReportPage> createState() => _CustomerReportPageState();
}

class _CustomerReportPageState extends State<CustomerReportPage> {
  // Report type state
  CustomerReportType _currentReportType = CustomerReportType.invoices;

  // Data states
  List<Customer> _customers = [];
  List<CustomerDue> _customerDues = [];
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
    _loadCustomerReport();
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadCustomerReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      switch (_currentReportType) {
        case CustomerReportType.invoices:
          final response = await CustomerReportingService.getInvoices();
          _customers = response.data;
          break;
        case CustomerReportType.dues:
          // Fetch both dues and invoices to get phone numbers
          final duesResponse = await CustomerReportingService.getDues();
          final invoicesResponse = await CustomerReportingService.getInvoices();

          // Create a map of customer ID to phone number from invoices data
          final Map<int, String> phoneMap = {};
          for (var customer in invoicesResponse.data) {
            phoneMap[customer.id] = customer.cellNo1;
          }

          // Update customer dues with phone numbers
          _customerDues = duesResponse.data.map((due) {
            final phone = phoneMap[due.id] ?? '';
            return CustomerDue(
              id: due.id,
              name: due.name,
              phoneNumber: phone,
              totalInvoice: due.totalInvoice,
              totalPaid: due.totalPaid,
              totalDue: due.totalDue,
            );
          }).toList();
          break;
      }
      // Calculate total pages and reset pagination
      final totalItems = _getTotalItems();
      _totalPages = (totalItems / _itemsPerPage).ceil();
      _currentPage = 1;
      _selectedReports.clear();
      _selectAll = false;
    } catch (e) {
      // Only show error for Invoices API failures, Dues API failures are handled in service
      if (_currentReportType == CustomerReportType.invoices) {
        _errorMessage = 'Failed to load customer report: $e';
        // Clear data instead of setting mock data
        _customers = [];
        _totalPages = 1;
        _currentPage = 1;
        _selectedReports.clear();
        _selectAll = false;
      }
      // For Dues API failures, the service already returns empty data
      _customerDues = [];
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

  void _changeReportType(CustomerReportType reportType) {
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
      _loadCustomerReport();
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
    switch (_currentReportType) {
      case CustomerReportType.invoices:
        return _customers.length;
      case CustomerReportType.dues:
        return _customerDues.length;
    }
  }

  dynamic _getReportId(dynamic report) {
    switch (_currentReportType) {
      case CustomerReportType.invoices:
        return (report as Customer).id;
      case CustomerReportType.dues:
        return (report as CustomerDue).id;
    }
  }

  List<dynamic> _getFilteredReports() {
    List<dynamic> reports;
    switch (_currentReportType) {
      case CustomerReportType.invoices:
        reports = _customers;
        break;
      case CustomerReportType.dues:
        reports = _customerDues;
        break;
    }

    List<dynamic> filtered = reports.where((report) {
      // Filter by search text (name)
      final name = _getCustomerName(report).toLowerCase();
      final matchesSearch =
          _searchText.isEmpty || name.contains(_searchText.toLowerCase());

      // Filter by status
      bool matchesStatus = true;
      if (_statusFilter != 'All') {
        switch (_currentReportType) {
          case CustomerReportType.dues:
            final customer = report as CustomerDue;
            final hasDue = customer.totalDue > 0;
            matchesStatus =
                (_statusFilter == 'With Due' && hasDue) ||
                (_statusFilter == 'No Due' && !hasDue);
            break;
          case CustomerReportType.invoices:
            // No status filtering for invoices (only 'All' option available)
            matchesStatus = true;
            break;
        }
      }

      return matchesSearch && matchesStatus;
    }).toList();

    // Sort by name by default
    filtered.sort((a, b) {
      return _getCustomerName(a).compareTo(_getCustomerName(b));
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

  String _getCustomerName(dynamic report) {
    switch (_currentReportType) {
      case CustomerReportType.invoices:
        return (report as Customer).name;
      case CustomerReportType.dues:
        return (report as CustomerDue).name;
    }
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
                  onPressed: _loadCustomerReport,
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
        title: const Text('Customer Report'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Customer Report',
            onPressed: () async {
              setState(() => _isLoading = true);
              await _loadCustomerReport();
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
                              // Report Type Tabs
                              _buildTabButton(
                                'Invoices',
                                CustomerReportType.invoices,
                              ),
                              const SizedBox(width: 8),
                              _buildTabButton('Dues', CustomerReportType.dues),
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
                                      hintText: 'Search customers...',
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

  Widget _buildTabButton(String title, CustomerReportType reportType) {
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
      case CustomerReportType.invoices:
        return Row(
          children: [
            _buildSummaryCard(
              'Total Customers',
              '${filteredReports.length}',
              Icons.business,
              Colors.blue,
            ),
            _buildSummaryCard(
              'Total Invoices',
              '${_calculateTotalInvoices(filteredReports)}',
              Icons.receipt,
              Colors.green,
            ),
            _buildSummaryCard(
              'Total Amount',
              'Rs. ${_calculateTotalAmount(filteredReports)}',
              Icons.attach_money,
              Colors.purple,
            ),
            _buildSummaryCard(
              'Active Customers',
              '${filteredReports.where((r) => (r as Customer).totals.totalInvoices > 0).length}',
              Icons.check_circle,
              Colors.orange,
            ),
          ],
        );
      case CustomerReportType.dues:
        return Row(
          children: [
            _buildSummaryCard(
              'Total Customers',
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
              'Total Paid Amount',
              'Rs. ${_calculateTotalPaid(filteredReports)}',
              Icons.payment,
              Colors.green,
            ),
            _buildSummaryCard(
              'Customers with Due',
              '${filteredReports.where((r) => (r as CustomerDue).totalDue > 0).length}',
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
                          'No customer records found',
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
      case CustomerReportType.invoices:
        return [
          // ID
          SizedBox(width: 60, child: Text('ID', style: _headerStyle())),
          const SizedBox(width: 16),
          // Customer Name
          Expanded(flex: 3, child: Text('Name', style: _headerStyle())),
          const SizedBox(width: 16),
          // Phone
          Expanded(flex: 2, child: Text('Phone', style: _headerStyle())),
          const SizedBox(width: 16),
          // City
          Expanded(flex: 2, child: Text('City', style: _headerStyle())),
          const SizedBox(width: 16),
          // Total Invoice (count)
          Expanded(
            flex: 1,
            child: Center(child: Text('Total Invoice', style: _headerStyle())),
          ),
          const SizedBox(width: 16),
          // Actions
          SizedBox(
            width: 80,
            child: Center(child: Text('Actions', style: _headerStyle())),
          ),
        ];
      case CustomerReportType.dues:
        return [
          // ID Column
          SizedBox(width: 60, child: Text('ID', style: _headerStyle())),
          const SizedBox(width: 16),
          // Customer Name Column
          Expanded(
            flex: 2,
            child: Text('Customer Name', style: _headerStyle()),
          ),
          const SizedBox(width: 16),
          // Phone Column
          Expanded(flex: 2, child: Text('Phone', style: _headerStyle())),
          const SizedBox(width: 16),
          // Total Invoice Column
          Expanded(
            flex: 1,
            child: Text('Total Invoice', style: _headerStyle()),
          ),
          const SizedBox(width: 16),
          // Total Paid Column
          Expanded(flex: 1, child: Text('Total Paid', style: _headerStyle())),
          const SizedBox(width: 16),
          // Total Due Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: Text('Total Due', style: _headerStyle())),
          ),
          const SizedBox(width: 16),
          // Actions
          SizedBox(
            width: 80,
            child: Center(child: Text('Actions', style: _headerStyle())),
          ),
        ];
    }
  }

  List<Widget> _getTableRowColumns(dynamic report, bool isSelected) {
    switch (_currentReportType) {
      case CustomerReportType.invoices:
        final customer = report as Customer;
        final totalInvoices = customer.totals.totalInvoices;
        return [
          // ID
          SizedBox(
            width: 60,
            child: Text(
              customer.id.toString(),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 16),
          // Name
          Expanded(flex: 3, child: _buildCustomerCell(customer.name)),
          const SizedBox(width: 16),
          // Phone
          Expanded(
            flex: 2,
            child: Text(customer.cellNo1, style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 16),
          // City
          Expanded(
            flex: 2,
            child: Text(customer.cityId, style: const TextStyle(fontSize: 12)),
          ),
          const SizedBox(width: 16),
          // Total Invoice (count) - centered and clickable
          Expanded(
            flex: 1,
            child: Center(
              child: InkWell(
                onTap: () => _showCustomerInvoicesDialog(customer),
                child: Text(
                  totalInvoices.toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF495057),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Actions - View button
          SizedBox(
            width: 80,
            child: Center(
              child: ElevatedButton(
                onPressed: () => _showCustomerInvoiceDetailsDialog(customer.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0D1845),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size(60, 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text('View', style: TextStyle(fontSize: 11)),
              ),
            ),
          ),
        ];
      case CustomerReportType.dues:
        final customer = report as CustomerDue;
        return [
          // ID Column
          SizedBox(
            width: 60,
            child: Text(
              customer.id.toString(),
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 16),
          // Customer Name Column
          Expanded(flex: 2, child: _buildCustomerCell(customer.name)),
          const SizedBox(width: 16),
          // Phone Column
          Expanded(
            flex: 2,
            child: Text(
              customer.phoneNumber.isEmpty ? 'N/A' : customer.phoneNumber,
              style: const TextStyle(fontSize: 12),
            ),
          ),
          const SizedBox(width: 16),
          // Total Invoice Column
          Expanded(
            flex: 1,
            child: Text(
              'Rs. ${customer.totalInvoice.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF495057),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Total Paid Column
          Expanded(
            flex: 1,
            child: Text(
              'Rs. ${customer.totalPaid.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF495057),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Total Due Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: _buildDueAmountCell(customer.totalDue)),
          ),
          const SizedBox(width: 16),
          // Actions - View button
          SizedBox(
            width: 80,
            child: Center(
              child: ElevatedButton(
                onPressed: () => _showCustomerInvoiceDetailsDialog(customer.id),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF0D1845),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size(60, 28),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                child: Text('View', style: TextStyle(fontSize: 11)),
              ),
            ),
          ),
        ];
    }
  }

  Widget _buildCustomerCell(String customerName) {
    return Text(
      customerName,
      style: TextStyle(fontWeight: FontWeight.w500),
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
    );
  }

  void _showCustomerInvoicesDialog(Customer customer) {
    showDialog(
      context: context,
      builder: (context) {
        final invoices = customer.invoices;
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          title: Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.receipt_long, color: Colors.white, size: 24),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '${customer.name} - Invoices',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: invoices.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                        SizedBox(height: 16),
                        Text(
                          'No invoices found for this customer.',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  )
                : Column(
                    children: [
                      // Header row
                      Container(
                        padding: EdgeInsets.symmetric(
                          vertical: 8,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          color: Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Invoice ID',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF0D1845),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Amount',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF0D1845),
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Paid',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: Color(0xFF0D1845),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 8),
                      // Invoice list
                      Expanded(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemBuilder: (context, index) {
                            final inv = invoices[index];
                            return Container(
                              padding: EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 12,
                              ),
                              decoration: BoxDecoration(
                                color: index % 2 == 0
                                    ? Colors.white
                                    : Colors.grey[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      inv.customerId.isNotEmpty
                                          ? inv.customerId
                                          : inv.id.toString(),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Rs. ${inv.invAmount}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF0D1845),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      'Rs. ${inv.paid}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green[700],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                          separatorBuilder: (_, __) => SizedBox(height: 4),
                          itemCount: invoices.length,
                        ),
                      ),
                    ],
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                backgroundColor: Color(0xFF0D1845),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showCustomerInvoiceDetailsDialog(int customerId) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Card(
          child: Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D1845)),
                ),
                SizedBox(height: 16),
                Text('Loading customer details...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final response = await CustomerReportingService.getCustomerInvoiceDetails(
        customerId,
      );

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show details dialog
      if (mounted) {
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
                            Icon(Icons.person, color: Colors.white, size: 32),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                response.name,
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
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
                              'Total Invoices',
                              response.totalInvoices.toString(),
                              Icons.receipt,
                              Colors.blue,
                            ),
                            SizedBox(width: 8),
                            _buildDetailSummaryCard(
                              'Total Amount',
                              'Rs. ${response.totalAmount.toStringAsFixed(2)}',
                              Icons.attach_money,
                              Colors.green,
                            ),
                            SizedBox(width: 8),
                            _buildDetailSummaryCard(
                              'Total Paid',
                              'Rs. ${response.totalPaid.toStringAsFixed(2)}',
                              Icons.payment,
                              Colors.orange,
                            ),
                            SizedBox(width: 8),
                            _buildDetailSummaryCard(
                              'Total Due',
                              'Rs. ${response.totalDue.toStringAsFixed(2)}',
                              Icons.money_off,
                              Colors.red,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Invoices list
                  Expanded(
                    child: response.invoices.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.inbox,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                SizedBox(height: 16),
                                Text(
                                  'No invoices found',
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ],
                            ),
                          )
                        : Container(
                            padding: EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Table Header
                                Container(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 12,
                                    horizontal: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF0D1845),
                                    borderRadius: BorderRadius.only(
                                      topLeft: Radius.circular(8),
                                      topRight: Radius.circular(8),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // ID
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'ID',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      // Date
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Date',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      // Description
                                      Expanded(
                                        flex: 4,
                                        child: Text(
                                          'Description',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.left,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      // Inv.Amount
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'Inv.Amount',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      // Paid.Amount
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'Paid.Amount',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 12,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                // Table Body
                                Expanded(
                                  child: ListView.builder(
                                    itemCount: response.invoices.length,
                                    itemBuilder: (context, index) {
                                      final invoice = response.invoices[index];
                                      final isEven = index % 2 == 0;
                                      return Container(
                                        padding: EdgeInsets.symmetric(
                                          vertical: 12,
                                          horizontal: 8,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isEven
                                              ? Colors.white
                                              : Colors.grey[50],
                                          border: Border(
                                            bottom: BorderSide(
                                              color: Colors.grey[200]!,
                                              width: 1,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            // ID
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                invoice.id.toString(),
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            // Date
                                            Expanded(
                                              flex: 2,
                                              child: Text(
                                                invoice.invDate,
                                                style: TextStyle(fontSize: 12),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            // Description
                                            Expanded(
                                              flex: 4,
                                              child: Text(
                                                invoice.description,
                                                style: TextStyle(fontSize: 12),
                                                textAlign: TextAlign.left,
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            // Inv.Amount
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                double.tryParse(
                                                      invoice.invAmount,
                                                    )?.toInt().toString() ??
                                                    '0',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                textAlign: TextAlign.center,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            // Paid.Amount
                                            Expanded(
                                              flex: 1,
                                              child: Text(
                                                double.tryParse(
                                                      invoice.paid,
                                                    )?.toInt().toString() ??
                                                    '0',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.green[700],
                                                  fontWeight: FontWeight.w500,
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
      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show error dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(Icons.error, color: Colors.red, size: 28),
                SizedBox(width: 12),
                Text('Error'),
              ],
            ),
            content: Text(e.toString().replaceAll('Exception: ', '')),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  backgroundColor: Color(0xFF0D1845),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text('OK'),
              ),
            ],
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

  Widget _buildInvoiceCard(CustomerInvoiceDetailed invoice) {
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        tilePadding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        childrenPadding: EdgeInsets.all(16),
        title: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Color(0xFF0D1845).withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.receipt_long,
                color: Color(0xFF0D1845),
                size: 24,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invoice #${invoice.id}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF0D1845),
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Date: ${invoice.invDate}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  if (invoice.description.isNotEmpty) ...[
                    SizedBox(height: 4),
                    Text(
                      invoice.description,
                      style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'Rs. ${invoice.invAmount}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Color(0xFF0D1845),
                  ),
                ),
                Text(
                  'Paid: Rs. ${invoice.paid}',
                  style: TextStyle(fontSize: 12, color: Colors.green[700]),
                ),
              ],
            ),
          ],
        ),
        children: [
          // Invoice details section
          if (invoice.details.isNotEmpty) ...[
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Products',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF0D1845),
                ),
              ),
            ),
            SizedBox(height: 8),
            ...invoice.details.map(
              (detail) => Container(
                margin: EdgeInsets.only(bottom: 12),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            detail.product,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFF0D1845),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            'Qty: ${detail.qty}',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (detail.extras.isNotEmpty) ...[
                      SizedBox(height: 8),
                      Divider(height: 1),
                      SizedBox(height: 8),
                      Text(
                        'Extras:',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(height: 4),
                      ...detail.extras.map(
                        (extra) => Padding(
                          padding: EdgeInsets.only(left: 12, top: 4),
                          child: Row(
                            children: [
                              Icon(
                                Icons.chevron_right,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  '${extra.title} - ${extra.value}',
                                  style: TextStyle(fontSize: 12),
                                ),
                              ),
                              Text(
                                'Rs. ${extra.amount}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.green[700],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
          // Bank details section
          if (invoice.bankDetails.isNotEmpty) ...[
            SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Bank Details',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF0D1845),
                ),
              ),
            ),
            SizedBox(height: 8),
            ...invoice.bankDetails.map(
              (bank) => Container(
                margin: EdgeInsets.only(bottom: 8),
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.account_balance,
                      color: Colors.blue[700],
                      size: 20,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bank.bankName,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (bank.accountTitle != null)
                            Text(
                              bank.accountTitle!,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                            ),
                          Text(
                            bank.accountNumber,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (bank.amount != null)
                      Text(
                        'Rs. ${bank.amount}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.blue[700],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
          // Invoice summary
          Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Tax:', style: TextStyle(fontSize: 12)),
              Text('Rs. ${invoice.tax}', style: TextStyle(fontSize: 12)),
            ],
          ),
          SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Discount:', style: TextStyle(fontSize: 12)),
              Text(
                'Rs. ${invoice.discAmount} (${invoice.discPer}%)',
                style: TextStyle(fontSize: 12),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDueAmountCell(double amount) {
    final color = amount > 0
        ? Colors.red
        : amount < 0
        ? Colors.green
        : Colors.black;
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
  int _calculateTotalInvoices(List<dynamic> reports) {
    if (_currentReportType != CustomerReportType.invoices) return 0;
    return reports.fold(
      0,
      (sum, report) => sum + (report as Customer).invoices.length,
    );
  }

  String _calculateTotalAmount(List<dynamic> reports) {
    if (_currentReportType != CustomerReportType.invoices) return '0.00';
    final total = reports.fold<double>(0.0, (sum, report) {
      final customer = report as Customer;
      return sum +
          customer.invoices.fold<double>(
            0.0,
            (pSum, invoice) =>
                pSum + (double.tryParse(invoice.invAmount) ?? 0.0),
          );
    });
    return total.toStringAsFixed(2);
  }

  String _calculateTotalDue(List<dynamic> reports) {
    if (_currentReportType != CustomerReportType.dues) return '0.00';
    final total = reports.fold<double>(
      0.0,
      (sum, report) => sum + (report as CustomerDue).totalDue,
    );
    return total.toStringAsFixed(2);
  }

  String _calculateTotalPaid(List<dynamic> reports) {
    if (_currentReportType != CustomerReportType.dues) return '0.00';
    final total = reports.fold<double>(
      0.0,
      (sum, report) => sum + (report as CustomerDue).totalPaid,
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
      case CustomerReportType.invoices:
        return 'Customer Invoices Report';
      case CustomerReportType.dues:
        return 'Customer Dues Report';
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
      // For invoices show 5 columns: ID, Name, Phone, City, Total Invoice
      // For dues show 6 columns: ID, Name, Phone, Total Invoice, Total Paid, Total Due
      grid.columns.add(
        count: _currentReportType == CustomerReportType.invoices ? 5 : 6,
      );

      final double pageWidth = pageSize.width;
      final double tableWidth = pageWidth * 0.95;

      // Set column widths based on report type
      switch (_currentReportType) {
        case CustomerReportType.invoices:
          grid.columns[0].width = tableWidth * 0.12; // ID
          grid.columns[1].width = tableWidth * 0.36; // Name
          grid.columns[2].width = tableWidth * 0.16; // Phone
          grid.columns[3].width = tableWidth * 0.18; // City
          grid.columns[4].width = tableWidth * 0.18; // Total Invoice
          break;
        case CustomerReportType.dues:
          grid.columns[0].width = tableWidth * 0.10; // ID
          grid.columns[1].width = tableWidth * 0.28; // Customer Name
          grid.columns[2].width = tableWidth * 0.16; // Phone
          grid.columns[3].width = tableWidth * 0.15; // Total Invoice
          grid.columns[4].width = tableWidth * 0.15; // Total Paid
          grid.columns[5].width = tableWidth * 0.16; // Total Due
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
        case CustomerReportType.invoices:
          headerRow.cells[0].value = 'ID';
          headerRow.cells[1].value = 'Name';
          headerRow.cells[2].value = 'Phone';
          headerRow.cells[3].value = 'City';
          headerRow.cells[4].value = 'Total Invoice';
          break;
        case CustomerReportType.dues:
          headerRow.cells[0].value = 'ID';
          headerRow.cells[1].value = 'Customer Name';
          headerRow.cells[2].value = 'Phone';
          headerRow.cells[3].value = 'Total Invoice';
          headerRow.cells[4].value = 'Total Paid';
          headerRow.cells[5].value = 'Total Due';
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
          case CustomerReportType.invoices:
            final customer = report as Customer;
            row.cells[0].value = customer.id.toString();
            row.cells[1].value = customer.name;
            row.cells[2].value = customer.cellNo1;
            row.cells[3].value = customer.cityId;
            row.cells[4].value = customer.totals.totalInvoices.toString();
            break;
          case CustomerReportType.dues:
            final customer = report as CustomerDue;
            row.cells[0].value = customer.id.toString();
            row.cells[1].value = customer.name;
            row.cells[2].value = customer.phoneNumber.isEmpty
                ? 'N/A'
                : customer.phoneNumber;
            row.cells[3].value =
                'Rs ${customer.totalInvoice.toStringAsFixed(2)}';
            row.cells[4].value = 'Rs ${customer.totalPaid.toStringAsFixed(2)}';
            row.cells[5].value = 'Rs ${customer.totalDue.toStringAsFixed(2)}';
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
        dialogTitle: 'Save Customer Report PDF',
        fileName:
            'customer_report_${_currentReportType == CustomerReportType.invoices ? 'invoices' : 'dues'}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
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
      case CustomerReportType.invoices:
        return 'Complete customer invoice history and details';
      case CustomerReportType.dues:
        return 'Customer payment status and outstanding dues';
    }
  }

  IconData _getReportIcon() {
    switch (_currentReportType) {
      case CustomerReportType.invoices:
        return Icons.receipt;
      case CustomerReportType.dues:
        return Icons.account_balance_wallet;
    }
  }

  List<String> _getStatusFilterOptions() {
    switch (_currentReportType) {
      case CustomerReportType.invoices:
        return ['All'];
      case CustomerReportType.dues:
        return ['All', 'With Due', 'No Due'];
    }
  }
}
