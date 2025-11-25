import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import '../../services/purchase_reporting_service.dart';

class PurchaseReportPage extends StatefulWidget {
  const PurchaseReportPage({super.key});

  @override
  State<PurchaseReportPage> createState() => _PurchaseReportPageState();
}

class _PurchaseReportPageState extends State<PurchaseReportPage> {
  // API data
  List<PurchaseReport> _purchaseReports = [];
  List<PurchaseReport> _selectedReports = [];
  bool _selectAll = false;

  // Loading and error states
  bool _isLoading = true;
  String? _errorMessage;

  // Pagination
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  int get _totalPages => (_getFilteredReports().length / _itemsPerPage).ceil();

  // Table scroll controller
  final ScrollController _tableScrollController = ScrollController();

  // Filter states
  String _selectedPeriod = 'All Time';
  String _selectedSupplier = 'All';
  String _selectedStatus = 'All';

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadPurchaseReports();
  }

  Future<void> _loadPurchaseReports() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await PurchaseReportingService.getPurchaseReports();
      _purchaseReports = response.data;

      // Calculate total pages
      _currentPage = 1;
      _selectedReports.clear();
      _selectAll = false;
    } catch (e) {
      _errorMessage = 'Failed to load purchase reports: $e';
      // Set empty data on error
      _purchaseReports = [];
      _currentPage = 1;
      _selectedReports.clear();
      _selectAll = false;
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _tableScrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _toggleReportSelection(PurchaseReport report) {
    setState(() {
      final reportId = report.purInvId;
      final existingIndex = _selectedReports.indexWhere(
        (r) => r.purInvId == reportId,
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
    final paginatedReports = _getPaginatedReports();
    _selectAll =
        paginatedReports.isNotEmpty &&
        _selectedReports.length == paginatedReports.length &&
        paginatedReports.every((report) => _selectedReports.contains(report));
  }

  List<PurchaseReport> _getFilteredReports() {
    return _purchaseReports.where((report) {
      final supplierMatch =
          _selectedSupplier == 'All' || report.vendorName == _selectedSupplier;
      // Use vendorStatus (Active/Inactive) when available from nested vendor object
      final statusMatch =
          _selectedStatus == 'All' || report.vendorStatus == _selectedStatus;

      // Date filtering
      bool dateMatch = true;
      if (_selectedPeriod == 'Last 7 Days') {
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        final reportDate = DateTime.tryParse(report.purDate) ?? DateTime.now();
        dateMatch = reportDate.isAfter(sevenDaysAgo);
      } else if (_selectedPeriod == 'Last 30 Days') {
        final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
        final reportDate = DateTime.tryParse(report.purDate) ?? DateTime.now();
        dateMatch = reportDate.isAfter(thirtyDaysAgo);
      }

      // Search by supplier name
      if (_searchQuery.isNotEmpty) {
        final supplierName = report.vendorName.toLowerCase();
        if (!supplierName.contains(_searchQuery.toLowerCase())) return false;
      }

      return supplierMatch && statusMatch && dateMatch;
    }).toList();
  }

  List<PurchaseReport> _getPaginatedReports() {
    final filteredReports = _getFilteredReports();
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return filteredReports.sublist(
      startIndex,
      endIndex > filteredReports.length ? filteredReports.length : endIndex,
    );
  }

  int _calculateTotalQuantity(PurchaseReport report) {
    return report.purDetails.fold(
      0,
      (sum, detail) => sum + (int.tryParse(detail.quantity) ?? 0),
    );
  }

  double _calculateReportAmount(PurchaseReport report) {
    // Prefer the invoice amount if provided and valid, otherwise sum detail amounts
    final inv = double.tryParse(report.invAmount) ?? 0.0;
    if (inv > 0.0) return inv;

    return report.purDetails.fold(0.0, (sum, d) {
      return sum + (double.tryParse(d.amount) ?? 0.0);
    });
  }

  double _calculateTotal(String field) {
    return _getFilteredReports().fold(0.0, (sum, report) {
      switch (field) {
        case 'grandTotal':
          return sum + (double.tryParse(report.invAmount) ?? 0.0);
        case 'paidAmount':
          // For paid amount, we need to calculate from payment status
          return sum +
              (report.paymentStatus.toLowerCase() == 'paid'
                  ? (double.tryParse(report.invAmount) ?? 0.0)
                  : 0.0);
        default:
          return sum;
      }
    });
  }

  int _calculateTotalInt(String field) {
    return _getFilteredReports().fold(0, (sum, report) {
      switch (field) {
        case 'totalItems':
          return sum + report.purDetails.length;
        case 'totalQuantity':
          return sum +
              report.purDetails.fold(
                0,
                (qSum, detail) => qSum + (int.tryParse(detail.quantity) ?? 0),
              );
        default:
          return sum;
      }
    });
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> pageNumbers = [];
    int startPage = 1;
    int endPage = _totalPages;

    // Show max 10 page numbers at a time
    if (_totalPages > 10) {
      if (_currentPage <= 5) {
        endPage = 10;
      } else if (_currentPage >= _totalPages - 4) {
        startPage = _totalPages - 9;
      } else {
        startPage = _currentPage - 4;
        endPage = _currentPage + 5;
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

  Future<void> _exportToPDF() async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D1845)),
                ),
                SizedBox(width: 16),
                Text(
                  'Generating PDF...',
                  style: TextStyle(color: Colors.black),
                ),
              ],
            ),
          );
        },
      );

      final filtered = _getFilteredReports();
      if (filtered.isEmpty) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No data to export'),
            backgroundColor: Color(0xFFDC3545),
          ),
        );
        return;
      }

      final PdfDocument document = PdfDocument();
      document.pageSettings.orientation = PdfPageOrientation.landscape;
      document.pageSettings.size = PdfPageSize.a4;

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
      final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 9);

      final PdfPage page = document.pages.add();
      final PdfGraphics graphics = page.graphics;

      graphics.drawString(
        'Purchase Report',
        titleFont,
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 30),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );

      String filterInfo =
          'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}';
      if (_selectedSupplier != 'All') {
        filterInfo += ' | Vendor: $_selectedSupplier';
      }
      if (_selectedStatus != 'All') {
        filterInfo += ' | Status: $_selectedStatus';
      }
      if (_selectedPeriod != 'All Time') {
        filterInfo += ' | Period: $_selectedPeriod';
      }
      graphics.drawString(
        filterInfo,
        smallFont,
        bounds: Rect.fromLTWH(0, 30, page.getClientSize().width, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 6);

      final double pageWidth = page.getClientSize().width;
      final double tableWidth = pageWidth * 0.95;

      grid.columns[0].width = tableWidth * 0.15; // Date
      grid.columns[1].width = tableWidth * 0.18; // Reference
      grid.columns[2].width = tableWidth * 0.25; // Vendor
      grid.columns[3].width = tableWidth * 0.12; // Items
      grid.columns[4].width = tableWidth * 0.12; // Qty
      grid.columns[5].width = tableWidth * 0.18; // Amount

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
        font: smallFont,
      );

      final PdfGridRow headerRow = grid.headers.add(1)[0];
      headerRow.cells[0].value = 'Date';
      headerRow.cells[1].value = 'Reference';
      headerRow.cells[2].value = 'Vendor';
      headerRow.cells[3].value = 'Items';
      headerRow.cells[4].value = 'Qty';
      headerRow.cells[5].value = 'Amount';

      final PdfColor tableHeaderColor = PdfColor(248, 249, 250);
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

      for (int idx = 0; idx < filtered.length; idx++) {
        final report = filtered[idx];
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = DateFormat(
          'dd MMM yyyy',
        ).format(DateTime.tryParse(report.purDate) ?? DateTime.now());
        row.cells[1].value = report.venInvNo;
        row.cells[2].value = report.vendorName;
        row.cells[3].value = report.purDetails.length.toString();
        row.cells[4].value = _calculateTotalQuantity(report).toString();
        final amount = double.tryParse(report.invAmount) ?? 0.0;
        row.cells[5].value = 'Rs ${amount.toStringAsFixed(2)}';

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
          0,
          60,
          pageWidth,
          page.getClientSize().height - 60,
        ),
      );

      final List<int> bytes = await document.save();
      document.dispose();

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Minimize application to save PDF',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF0D1845),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );

      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Purchase Report PDF',
        fileName:
            'purchase_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputPath != null) {
        final File file = File(outputPath);
        await file.writeAsBytes(bytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('PDF exported successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Error exporting PDF: $e')),
            ],
          ),
          backgroundColor: Color(0xFFDC3545),
          duration: Duration(seconds: 4),
        ),
      );
    }
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

  TextStyle _headerStyle() {
    return const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Color(0xFF0D1845),
    );
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
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadPurchaseReports,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final filteredReports = _getFilteredReports();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Purchase Report'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Purchase Report',
            onPressed: () async {
              setState(() => _isLoading = true);
              await _loadPurchaseReports();
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
                          Icons.shopping_bag,
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
                              'Purchase Report',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Comprehensive purchase transactions and supplier analytics',
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
                        'Total Purchases',
                        '${filteredReports.length}',
                        Icons.shopping_bag,
                        Colors.blue,
                      ),
                      _buildSummaryCard(
                        'Total Items',
                        '${_calculateTotalInt('totalItems')}',
                        Icons.inventory,
                        Colors.green,
                      ),
                      _buildSummaryCard(
                        'Total Amount',
                        'Rs. ${_calculateTotal('grandTotal').toStringAsFixed(2)}',
                        Icons.attach_money,
                        Colors.purple,
                      ),
                      _buildSummaryCard(
                        'Total Paid',
                        'Rs. ${_calculateTotal('paidAmount').toStringAsFixed(2)}',
                        Icons.payments,
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
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Search Bar
                          Row(
                            children: [
                              Flexible(
                                flex: 1,
                                child: SizedBox(
                                  height: 28,
                                  child: TextField(
                                    controller: _searchController,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: InputDecoration(
                                      hintText: 'Search suppliers...',
                                      hintStyle: const TextStyle(fontSize: 11),
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        size: 14,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 6,
                                          ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _searchQuery = value.trim();
                                        _currentPage = 1;
                                        _updateSelectAllState();
                                      });
                                    },
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          // Filters Row
                          Row(
                            children: [
                              // Period Filter
                              Expanded(
                                flex: 1,
                                child: Container(
                                  height: 36,
                                  margin: const EdgeInsets.only(right: 8),
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedPeriod,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Period',
                                      hintStyle: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.date_range,
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
                                    items:
                                        [
                                              'Last 7 Days',
                                              'Last 30 Days',
                                              'All Time',
                                            ]
                                            .map(
                                              (period) => DropdownMenuItem(
                                                value: period,
                                                child: Text(period),
                                              ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedPeriod = value;
                                          _currentPage = 1;
                                          _updateSelectAllState();
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              // Supplier Filter
                              Expanded(
                                flex: 1,
                                child: Container(
                                  height: 36,
                                  margin: const EdgeInsets.only(right: 8),
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedSupplier,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Vendor',
                                      hintStyle: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.business,
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
                                    items:
                                        [
                                              'All',
                                              ..._purchaseReports
                                                  .map((r) => r.vendorName)
                                                  .toSet()
                                                  .toList(),
                                            ]
                                            .map(
                                              (supplier) =>
                                                  DropdownMenuItem<String>(
                                                    value: supplier,
                                                    child: Text(supplier),
                                                  ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedSupplier = value;
                                          _currentPage = 1;
                                          _updateSelectAllState();
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              // Status Filter (uses vendor status when available)
                              Expanded(
                                flex: 1,
                                child: Container(
                                  height: 36,
                                  margin: const EdgeInsets.only(right: 8),
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedStatus,
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
                                        Icons.info,
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
                                    items:
                                        [
                                              'All',
                                              ..._purchaseReports
                                                  .map((r) => r.vendorStatus)
                                                  .toSet()
                                                  .toList(),
                                            ]
                                            .map(
                                              (status) =>
                                                  DropdownMenuItem<String>(
                                                    value: status,
                                                    child: Text(status),
                                                  ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedStatus = value;
                                          _currentPage = 1;
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
                          // Date Column
                          Expanded(
                            flex: 1,
                            child: Text('Date', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          // Reference Column
                          Expanded(
                            flex: 1,
                            child: Text('Reference', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          // Vendor Column
                          Expanded(
                            flex: 2,
                            child: Text('Vendor', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          // Items Column - Centered
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: Text('Items', style: _headerStyle()),
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
                          const SizedBox(width: 16),
                          // Amount Column - Centered
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: Text('Amount', style: _headerStyle()),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Body
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _getPaginatedReports().isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.shopping_bag,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No purchase records found',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _getPaginatedReports().length,
                              itemBuilder: (context, index) {
                                final report = _getPaginatedReports()[index];
                                final isSelected = _selectedReports.any(
                                  (r) => r.purInvId == report.purInvId,
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
                                      bottom: BorderSide(
                                        color: Colors.grey[200]!,
                                      ),
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
                                      // Date Column
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          DateFormat('dd MMM yyyy').format(
                                            DateTime.tryParse(report.purDate) ??
                                                DateTime.now(),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF495057),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Reference Column
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          report.venInvNo,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF495057),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Supplier Column
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          report.vendorName,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF495057),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Items Column - Centered
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Text(
                                            report.purDetails.length.toString(),
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF495057),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Qty Column - Centered
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Text(
                                            _calculateTotalQuantity(
                                              report,
                                            ).toString(),
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF495057),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Amount Column - Centered
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Text(
                                            'Rs. ${_calculateReportAmount(report).toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0D1845),
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

            // Pagination Controls
            if (filteredReports.isNotEmpty) ...[
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
                      onPressed: _currentPage > 1
                          ? () => setState(() {
                              _currentPage--;
                              _updateSelectAllState();
                            })
                          : null,
                      icon: Icon(Icons.chevron_left, size: 14),
                      label: Text('Previous', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _currentPage > 1
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
                    ..._buildPageNumbers(),

                    const SizedBox(width: 8),

                    // Next button
                    ElevatedButton.icon(
                      onPressed: _currentPage < _totalPages
                          ? () => setState(() {
                              _currentPage++;
                              _updateSelectAllState();
                            })
                          : null,
                      icon: Icon(Icons.chevron_right, size: 14),
                      label: Text('Next', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _currentPage < _totalPages
                            ? const Color(0xFF0D1845)
                            : Colors.grey.shade300,
                        foregroundColor: _currentPage < _totalPages
                            ? Colors.white
                            : Colors.grey.shade600,
                        elevation: _currentPage < _totalPages ? 2 : 0,
                        side: _currentPage < _totalPages
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
                        'Page $_currentPage of $_totalPages (${filteredReports.length} total)',
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
}
