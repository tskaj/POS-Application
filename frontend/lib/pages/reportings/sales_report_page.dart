import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import '../../services/sales_report_service.dart';

class SalesReportPage extends StatefulWidget {
  const SalesReportPage({super.key});

  @override
  State<SalesReportPage> createState() => _SalesReportPageState();
}

class _SalesReportPageState extends State<SalesReportPage> {
  // API data (product-level sales report)
  List<ProductSalesReport> _salesReport = [];
  List<ProductSalesReport> _selectedReports = [];
  bool _selectAll = false;
  bool _isLoading = true;
  String _errorMessage = '';

  // Pagination
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  int _totalPages = 1;

  // Filter states
  String _selectedVendor = 'All';
  String _selectedCategory = 'All';

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadSalesReport();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSalesReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await SalesReportService.getProductSalesReport();
      setState(() {
        // Deduplicate by product id
        final uniqueReports = <int, ProductSalesReport>{};
        for (final report in response.data) {
          uniqueReports[report.productId] = report;
        }
        _salesReport = uniqueReports.values.toList();
        _selectedReports.clear();
        _selectAll = false;
        _currentPage = 1;
        _isLoading = false;
        _errorMessage = ''; // Clear any error message
      });
    } catch (e) {
      print('📊 Sales Report Error: $e');

      // Check if it's a 404 "no product sales found" error
      if (e.toString().contains('404') ||
          e.toString().contains('No product sales found')) {
        // No sales data is a valid state, not an error
        setState(() {
          _salesReport = [];
          _selectedReports.clear();
          _selectAll = false;
          _currentPage = 1;
          _isLoading = false;
          _errorMessage = ''; // Don't show error for empty state
        });
      } else {
        // Actual error occurred
        setState(() {
          _salesReport = [];
          _selectedReports.clear();
          _selectAll = false;
          _currentPage = 1;
          _errorMessage = 'Failed to load sales report: $e';
          _isLoading = false;
        });
      }
    }
  }

  void _toggleReportSelection(ProductSalesReport report) {
    setState(() {
      final reportId = report.productId;
      final existingIndex = _selectedReports.indexWhere(
        (r) => r.productId == reportId,
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
      final currentPageReports = _getPaginatedReports();
      if (_selectAll) {
        // Remove all current page items from selection
        for (final report in currentPageReports) {
          _selectedReports.removeWhere((r) => r.productId == report.productId);
        }
      } else {
        // Add all current page items to selection (avoiding duplicates)
        for (final report in currentPageReports) {
          if (!_selectedReports.any((r) => r.productId == report.productId)) {
            _selectedReports.add(report);
          }
        }
      }
      _updateSelectAllState();
    });
  }

  void _updateSelectAllState() {
    final currentPageReports = _getPaginatedReports();
    _selectAll =
        currentPageReports.isNotEmpty &&
        currentPageReports.every(
          (report) =>
              _selectedReports.any((r) => r.productId == report.productId),
        );
  }

  List<ProductSalesReport> _getFilteredReports() {
    return _salesReport.where((report) {
      final vendorMatch =
          _selectedVendor == 'All' || report.vendorName == _selectedVendor;
      final categoryMatch =
          _selectedCategory == 'All' ||
          report.categoryName == _selectedCategory;

      // Search by product name
      if (_searchQuery.isNotEmpty) {
        final name = report.productName.toLowerCase();
        if (!name.contains(_searchQuery.toLowerCase())) return false;
      }

      return vendorMatch && categoryMatch;
    }).toList();
  }

  List<ProductSalesReport> _getPaginatedReports() {
    final filteredReports = _getFilteredReports();
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;

    _totalPages = (filteredReports.length / _itemsPerPage).ceil();
    if (_totalPages == 0) _totalPages = 1;

    return filteredReports.sublist(
      startIndex,
      endIndex > filteredReports.length ? filteredReports.length : endIndex,
    );
  }

  double _calculateTotal(String field) {
    return _getFilteredReports().fold(0.0, (sum, report) {
      switch (field) {
        case 'totalSold':
          return sum + report.soldQuantity.toDouble();
        case 'totalStock':
          return sum + report.inStockQty.toDouble();
        case 'totalAmount':
          return sum + report.totalSaleAmount;
        default:
          return sum;
      }
    });
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
        'Sales Report',
        titleFont,
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 30),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );

      String filterInfo =
          'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}';
      if (_selectedVendor != 'All') {
        filterInfo += ' | Vendor: $_selectedVendor';
      }
      if (_selectedCategory != 'All') {
        filterInfo += ' | Category: $_selectedCategory';
      }
      graphics.drawString(
        filterInfo,
        smallFont,
        bounds: Rect.fromLTWH(0, 30, page.getClientSize().width, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 7);

      final double pageWidth = page.getClientSize().width;
      final double tableWidth = pageWidth * 0.95;

      grid.columns[0].width = tableWidth * 0.08; // Product ID
      grid.columns[1].width = tableWidth * 0.22; // Product Name
      grid.columns[2].width = tableWidth * 0.18; // Vendor
      grid.columns[3].width = tableWidth * 0.16; // Category
      grid.columns[4].width = tableWidth * 0.12; // Sold Qty
      grid.columns[5].width = tableWidth * 0.14; // Sale Amount
      grid.columns[6].width = tableWidth * 0.10; // In Stock

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
        font: smallFont,
      );

      final PdfGridRow headerRow = grid.headers.add(1)[0];
      headerRow.cells[0].value = 'Product ID';
      headerRow.cells[1].value = 'Product Name';
      headerRow.cells[2].value = 'Vendor';
      headerRow.cells[3].value = 'Category';
      headerRow.cells[4].value = 'Sold Qty';
      headerRow.cells[5].value = 'Sale Amount';
      headerRow.cells[6].value = 'In Stock';

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
        row.cells[0].value = report.productId.toString();
        row.cells[1].value = report.productName;
        row.cells[2].value = report.vendorName;
        row.cells[3].value = report.categoryName;
        row.cells[4].value = report.soldQuantity.toString();
        row.cells[5].value = report.totalSaleAmount.toStringAsFixed(2);
        row.cells[6].value = report.inStockQty.toString();

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
        dialogTitle: 'Save Sales Report PDF',
        fileName:
            'sales_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning, color: Colors.orange, size: 48),
              const SizedBox(height: 16),
              Text(
                'API Error - Showing Mock Data',
                style: const TextStyle(
                  color: Colors.orange,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage.split('\n\n')[0], // Show only the error part
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadSalesReport,
                child: const Text('Retry API Call'),
              ),
            ],
          ),
        ),
      );
    }

    final filteredReports = _getFilteredReports();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sales Report'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Sales Report',
            onPressed: () async {
              setState(() => _isLoading = true);
              await _loadSalesReport();
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
                          Icons.bar_chart,
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
                              'Sales Report',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Comprehensive sales analytics and reporting',
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
                        'Total Sold Qty',
                        '${_calculateTotal('totalSold').toInt()}',
                        Icons.shopping_cart,
                        Colors.blue,
                      ),
                      _buildSummaryCard(
                        'Total Sale Amount',
                        '${_calculateTotal('totalAmount').toStringAsFixed(2)}',
                        Icons.attach_money,
                        Colors.green,
                      ),
                      _buildSummaryCard(
                        'Total In Stock',
                        '${_calculateTotal('totalStock').toInt()}',
                        Icons.inventory,
                        Colors.purple,
                      ),
                      _buildSummaryCard(
                        'Total Products',
                        '${filteredReports.length}',
                        Icons.category,
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
                                      hintText: 'Search products...',
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
                              // Vendor Filter
                              Expanded(
                                flex: 1,
                                child: Container(
                                  height: 36,
                                  margin: const EdgeInsets.only(right: 8),
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedVendor,
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
                                        Icons.person,
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
                                              ..._salesReport
                                                  .map((r) => r.vendorName)
                                                  .toSet()
                                                  .toList(),
                                            ]
                                            .map(
                                              (vendor) =>
                                                  DropdownMenuItem<String>(
                                                    value: vendor,
                                                    child: Text(vendor),
                                                  ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedVendor = value;
                                          _currentPage = 1;
                                          _updateSelectAllState();
                                        });
                                      }
                                    },
                                  ),
                                ),
                              ),
                              // Category Filter
                              Expanded(
                                flex: 1,
                                child: Container(
                                  height: 36,
                                  margin: const EdgeInsets.only(right: 8),
                                  child: DropdownButtonFormField<String>(
                                    value: _selectedCategory,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.black,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Category',
                                      hintStyle: const TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                      prefixIcon: const Icon(
                                        Icons.category,
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
                                              ..._salesReport
                                                  .map((r) => r.categoryName)
                                                  .toSet()
                                                  .toList(),
                                            ]
                                            .map(
                                              (category) =>
                                                  DropdownMenuItem<String>(
                                                    value: category,
                                                    child: Text(category),
                                                  ),
                                            )
                                            .toList(),
                                    onChanged: (value) {
                                      if (value != null) {
                                        setState(() {
                                          _selectedCategory = value;
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
                          // Product ID Column
                          Expanded(
                            flex: 1,
                            child: Text('Product ID', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          // Product Name Column
                          Expanded(
                            flex: 2,
                            child: Text('Product Name', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          // Vendor Column
                          Expanded(
                            flex: 2,
                            child: Text('Vendor', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          // Category Column
                          Expanded(
                            flex: 2,
                            child: Text('Category', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          // Sold Qty Column - Centered
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: Text('Sold Qty', style: _headerStyle()),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Sale Amount Column - Centered
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: Text('Sale Amount', style: _headerStyle()),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // In Stock Column - Centered
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: Text('In Stock', style: _headerStyle()),
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
                                    Icons.shopping_cart_outlined,
                                    size: 64,
                                    color: Colors.grey.shade400,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No product sales found',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Sales data will appear here when available',
                                    style: TextStyle(
                                      color: Colors.grey.shade500,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _getPaginatedReports().length,
                              itemBuilder: (context, index) {
                                final report = _getPaginatedReports()[index];
                                final isSelected = _selectedReports.any(
                                  (r) => r.productId == report.productId,
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
                                      // Product ID Column
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          report.productId.toString(),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF495057),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Product Name Column
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          report.productName,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0D1845),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Vendor Column
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
                                      // Category Column
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          report.categoryName,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF495057),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Sold Qty Column - Centered
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Text(
                                            report.soldQuantity.toString(),
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF495057),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Sale Amount Column - Centered
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Text(
                                            report.totalSaleAmount
                                                .toStringAsFixed(2),
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0D1845),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // In Stock Column - Centered
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Text(
                                            report.inStockQty.toString(),
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF495057),
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
}
