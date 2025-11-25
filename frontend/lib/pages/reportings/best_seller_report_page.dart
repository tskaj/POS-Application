import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import '../../services/reporting_service.dart';
import '../../utils/barcode_utils.dart';

class BestSellerReportPage extends StatefulWidget {
  const BestSellerReportPage({super.key});

  @override
  State<BestSellerReportPage> createState() => _BestSellerReportPageState();
}

class _BestSellerReportPageState extends State<BestSellerReportPage> {
  // API data
  List<BestSellingProduct> _bestSellerProducts = [];
  List<BestSellingProduct> _selectedReports = [];
  bool _selectAll = false;
  bool _isLoading = true;
  String _errorMessage = '';

  // Pagination
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  int _totalPages = 1;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBestSellerProducts();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBestSellerProducts() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await ReportingService.getBestSellingProducts();
      setState(() {
        _bestSellerProducts = response.data;
        _totalPages = (_bestSellerProducts.length / _itemsPerPage).ceil();
        _currentPage = 1; // Reset to first page when new data loads
        _selectedReports.clear(); // Clear selections when new data loads
        _selectAll = false;
        _isLoading = false;
      });
    } catch (e) {
      // Temporary mock data for testing pagination
      setState(() {
        _bestSellerProducts = _generateMockData();
        _totalPages = (_bestSellerProducts.length / _itemsPerPage).ceil();
        _currentPage = 1;
        _selectedReports.clear();
        _selectAll = false;
        _errorMessage =
            'API Error: $e\n\nShowing mock data for testing pagination';
        _isLoading = false;
      });
    }
  }

  List<BestSellingProduct> _generateMockData() {
    return List.generate(
      25,
      (index) => BestSellingProduct(
        productId: index + 1,
        productName: 'Product ${index + 1}',
        designCode: 'DC${(index + 1).toString().padLeft(3, '0')}',
        imagePath: '',
        subCategoryId: 'SUB${index % 5 + 1}',
        salePrice: '${(index + 1) * 100}',
        openingStockQuantity: '${100 + index}',
        stockInQuantity: '${50 + index}',
        stockOutQuantity: '${20 + index}',
        inStockQuantity: '${130 + index}',
        vendorId: 'VENDOR${index % 3 + 1}',
        vendor: Vendor(
          id: index % 3 + 1,
          firstName: 'Vendor${index % 3 + 1}',
          lastName: 'Last',
          cnic: '12345-6789012-${index % 3 + 1}',
          address: 'Address ${index % 3 + 1}',
          cityId: 'CITY${index % 3 + 1}',
          email: 'vendor${index % 3 + 1}@example.com',
          phone: '0300-123456${index % 3 + 1}',
          status: 'active',
        ),
        barcode: 'BAR${(index + 1).toString().padLeft(6, '0')}',
        status: 'active',
        createdAt: DateTime.now()
            .subtract(Duration(days: index))
            .toIso8601String(),
        updatedAt: DateTime.now()
            .subtract(Duration(days: index))
            .toIso8601String(),
        totalSold: 50 - index,
        totalRevenue: (50 - index) * (index + 1) * 100.0,
      ),
    );
  }

  void _toggleReportSelection(BestSellingProduct report) {
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
      if (_selectAll) {
        _selectedReports.clear();
      } else {
        _selectedReports = List.from(_getFilteredProducts());
      }
      _selectAll = !_selectAll;
    });
  }

  void _updateSelectAllState() {
    final filteredProducts = _getFilteredProducts();
    final paginatedProducts = _getPaginatedProducts(filteredProducts);
    _selectAll =
        paginatedProducts.isNotEmpty &&
        _selectedReports.length == paginatedProducts.length &&
        paginatedProducts.every(
          (product) => _selectedReports.contains(product),
        );
  }

  List<BestSellingProduct> _getFilteredProducts() {
    List<BestSellingProduct> filtered = _bestSellerProducts.where((product) {
      // For now, we'll skip date filtering since the API doesn't provide lastSold date
      // Date filtering can be added when the API provides this information

      // Category filtering - we'll need to map subcategories or use a different approach
      // For now, we'll show all products since category info isn't directly available
      // Search by product name
      if (_searchQuery.isNotEmpty) {
        final name = product.productName.toLowerCase();
        if (!name.contains(_searchQuery.toLowerCase())) return false;
      }

      return true;
    }).toList();

    // Default sort by total sold desc
    filtered.sort((a, b) => b.totalSold.compareTo(a.totalSold));

    return filtered;
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

      final filtered = _getFilteredProducts();
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
        'Best Seller Report',
        titleFont,
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 30),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );

      String filterInfo =
          'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}';
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

      grid.columns[0].width = tableWidth * 0.06; // Rank
      grid.columns[1].width = tableWidth * 0.28; // Product
      grid.columns[2].width = tableWidth * 0.14; // Code
      grid.columns[3].width = tableWidth * 0.18; // Category
      grid.columns[4].width = tableWidth * 0.12; // Stock Left
      grid.columns[5].width = tableWidth * 0.20; // Sale Price

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
        font: smallFont,
      );

      final PdfGridRow headerRow = grid.headers.add(1)[0];
      headerRow.cells[0].value = 'Rank';
      headerRow.cells[1].value = 'Product';
      headerRow.cells[2].value = 'Code';
      headerRow.cells[3].value = 'Category';
      headerRow.cells[4].value = 'Stock Left';
      headerRow.cells[5].value = 'Sale Price';

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
        final product = filtered[idx];
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = (idx + 1).toString();
        row.cells[1].value = product.productName;
        row.cells[2].value = product.designCode;
        row.cells[3].value = product.subCategoryId;
        row.cells[4].value = product.inStockQuantity;
        final _sale = double.tryParse(product.salePrice) ?? 0.0;
        row.cells[5].value = 'Rs ${_sale.toStringAsFixed(2)}';

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
        dialogTitle: 'Save Best Seller Report PDF',
        fileName:
            'best_seller_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
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

  List<BestSellingProduct> _getPaginatedProducts(
    List<BestSellingProduct> products,
  ) {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return products.sublist(
      startIndex,
      endIndex > products.length ? products.length : endIndex,
    );
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
                onPressed: _loadBestSellerProducts,
                child: const Text('Retry API Call'),
              ),
            ],
          ),
        ),
      );
    }

    final filteredProducts = _getFilteredProducts();
    final paginatedProducts = _getPaginatedProducts(filteredProducts);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Best Sellers'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Best Sellers',
            onPressed: () async {
              setState(() => _isLoading = true);
              await _loadBestSellerProducts();
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
                          Icons.star,
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
                              'Best Sellers',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Top performing products and sales analytics',
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
                        'Total Products',
                        filteredProducts.length.toString(),
                        Icons.inventory_2,
                        Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _buildSummaryCard(
                        'Total Sold',
                        filteredProducts
                            .fold<int>(0, (sum, p) => sum + p.totalSold)
                            .toString(),
                        Icons.shopping_cart,
                        Colors.green,
                      ),
                      const SizedBox(width: 12),
                      _buildSummaryCard(
                        'Total Revenue',
                        'Rs. ${filteredProducts.fold<double>(0, (sum, p) => sum + p.totalRevenue).toStringAsFixed(2)}',
                        Icons.attach_money,
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
                      child: Row(
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
                                  contentPadding: const EdgeInsets.symmetric(
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
                          const SizedBox(width: 6),
                          SizedBox(
                            height: 24,
                            child: ElevatedButton.icon(
                              onPressed: _exportToPDF,
                              icon: const Icon(Icons.picture_as_pdf, size: 12),
                              label: const Text(
                                'PDF',
                                style: TextStyle(fontSize: 10),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.red,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(3),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 4,
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
                          // Product Details Column
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Product Details',
                              style: _headerStyle(),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Vendor Column
                          Expanded(
                            flex: 2,
                            child: Text('Vendor', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          // Price Column - Centered
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: Text('Price', style: _headerStyle()),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Stock Column - Centered
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: Text('Stock', style: _headerStyle()),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Body
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : paginatedProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.star_border,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No best seller products found',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: paginatedProducts.length,
                              itemBuilder: (context, index) {
                                final product = paginatedProducts[index];
                                final isSelected = _selectedReports.any(
                                  (r) => r.productId == product.productId,
                                );
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
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
                                              _toggleReportSelection(product),
                                          activeColor: Color(0xFF0D1845),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Product Details Column
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.productName,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF0D1845),
                                                fontSize: 9,
                                              ),
                                            ),
                                            Text(
                                              'Code: ${product.designCode}',
                                              style: TextStyle(
                                                fontSize: 7,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                            Text(
                                              'Barcode: ${getNumericBarcodeFromString(product.barcode)}',
                                              style: TextStyle(
                                                fontSize: 7,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Vendor Column
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          product.vendor.firstName +
                                              ' ' +
                                              product.vendor.lastName,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF495057),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Price Column - Centered
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Text(
                                            'Rs. ${product.salePrice}',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF495057),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      // Stock Column - Centered
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Text(
                                            product.inStockQuantity,
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
            if (filteredProducts.isNotEmpty) ...[
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
                        'Page $_currentPage of $_totalPages (${filteredProducts.length} total)',
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

  // Summary cards removed for best seller report; kept helper removed.

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
