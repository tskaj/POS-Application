import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';

class ProductReportPage extends StatefulWidget {
  const ProductReportPage({super.key});

  @override
  State<ProductReportPage> createState() => _ProductReportPageState();
}

class _ProductReportPageState extends State<ProductReportPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedPeriod = 'Today';
  String _selectedCategory = 'All Categories';
  String _selectedStockStatus = 'All Status';

  final List<String> _periods = [
    'Today',
    'Yesterday',
    'Last 7 Days',
    'Last 30 Days',
    'This Month',
    'Last Month',
    'Custom Range',
  ];
  final List<String> _categories = [
    'All Categories',
    'Electronics',
    'Clothing',
    'Home & Garden',
    'Sports',
    'Books',
  ];
  final List<String> _stockStatuses = [
    'All Status',
    'In Stock',
    'Low Stock',
    'Out of Stock',
  ];

  final List<Map<String, dynamic>> _productData = [
    {
      'productId': 'PRD-001',
      'name': 'Wireless Headphones',
      'category': 'Electronics',
      'sku': 'WH-001',
      'stock': 45,
      'minStock': 10,
      'maxStock': 100,
      'unitCost': 25.50,
      'sellingPrice': 79.99,
      'totalSold': 156,
      'revenue': 12455.44,
      'lastUpdated': '2024-01-15',
      'status': 'In Stock',
    },
    {
      'productId': 'PRD-002',
      'name': 'Cotton T-Shirt',
      'category': 'Clothing',
      'sku': 'CT-002',
      'stock': 8,
      'minStock': 15,
      'maxStock': 200,
      'unitCost': 8.75,
      'sellingPrice': 24.99,
      'totalSold': 89,
      'revenue': 2224.11,
      'lastUpdated': '2024-01-14',
      'status': 'Low Stock',
    },
    {
      'productId': 'PRD-003',
      'name': 'Garden Hose',
      'category': 'Home & Garden',
      'sku': 'GH-003',
      'stock': 0,
      'minStock': 5,
      'maxStock': 50,
      'unitCost': 12.30,
      'sellingPrice': 34.99,
      'totalSold': 67,
      'revenue': 2343.33,
      'lastUpdated': '2024-01-13',
      'status': 'Out of Stock',
    },
    {
      'productId': 'PRD-004',
      'name': 'Yoga Mat',
      'category': 'Sports',
      'sku': 'YM-004',
      'stock': 23,
      'minStock': 8,
      'maxStock': 75,
      'unitCost': 15.20,
      'sellingPrice': 45.99,
      'totalSold': 134,
      'revenue': 6158.66,
      'lastUpdated': '2024-01-12',
      'status': 'In Stock',
    },
    {
      'productId': 'PRD-005',
      'name': 'Programming Book',
      'category': 'Books',
      'sku': 'PB-005',
      'stock': 67,
      'minStock': 12,
      'maxStock': 150,
      'unitCost': 18.50,
      'sellingPrice': 49.99,
      'totalSold': 203,
      'revenue': 10144.97,
      'lastUpdated': '2024-01-11',
      'status': 'In Stock',
    },
  ];

  List<Map<String, dynamic>> get _filteredData {
    return _productData.where((product) {
      final matchesSearch =
          product['name'].toString().toLowerCase().contains(
            _searchController.text.toLowerCase(),
          ) ||
          product['productId'].toString().toLowerCase().contains(
            _searchController.text.toLowerCase(),
          ) ||
          product['sku'].toString().toLowerCase().contains(
            _searchController.text.toLowerCase(),
          );
      final matchesCategory =
          _selectedCategory == 'All Categories' ||
          product['category'] == _selectedCategory;
      final matchesStatus =
          _selectedStockStatus == 'All Status' ||
          product['status'] == _selectedStockStatus;

      return matchesSearch && matchesCategory && matchesStatus;
    }).toList();
  }

  double get _totalProducts => _filteredData.length.toDouble();
  double get _totalStock =>
      _filteredData.fold(0.0, (sum, product) => sum + product['stock']);
  double get _totalRevenue =>
      _filteredData.fold(0.0, (sum, product) => sum + product['revenue']);
  double get _averagePrice => _filteredData.isEmpty
      ? 0.0
      : _filteredData.fold(
              0.0,
              (sum, product) => sum + product['sellingPrice'],
            ) /
            _filteredData.length;

  Color _getStockStatusColor(String status) {
    switch (status) {
      case 'In Stock':
        return Colors.green;
      case 'Low Stock':
        return Colors.orange;
      case 'Out of Stock':
        return Colors.red;
      default:
        return Colors.grey;
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
        'Product Report',
        titleFont,
        bounds: Rect.fromLTWH(20, yPos, pageSize.width - 40, 30),
        brush: PdfSolidBrush(PdfColor(13, 24, 69)),
      );

      yPos += 35;

      // Date and filters info
      String filterInfo =
          'Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}';
      if (_selectedPeriod != 'Today')
        filterInfo += ' | Period: $_selectedPeriod';
      if (_selectedCategory != 'All Categories')
        filterInfo += ' | Category: $_selectedCategory';
      if (_selectedStockStatus != 'All Status')
        filterInfo += ' | Status: $_selectedStockStatus';

      graphics.drawString(
        filterInfo,
        smallFont,
        bounds: Rect.fromLTWH(20, yPos, pageSize.width - 40, 20),
        brush: PdfSolidBrush(PdfColor(100, 100, 100)),
      );

      yPos += 30;

      // Create table
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 9);

      final double pageWidth = pageSize.width;
      final double tableWidth = pageWidth * 0.95;

      // Set column widths
      grid.columns[0].width = tableWidth * 0.10; // Product ID
      grid.columns[1].width = tableWidth * 0.20; // Name
      grid.columns[2].width = tableWidth * 0.12; // Category
      grid.columns[3].width = tableWidth * 0.10; // Stock
      grid.columns[4].width = tableWidth * 0.10; // Unit Cost
      grid.columns[5].width = tableWidth * 0.10; // Selling Price
      grid.columns[6].width = tableWidth * 0.08; // Total Sold
      grid.columns[7].width = tableWidth * 0.10; // Revenue
      grid.columns[8].width = tableWidth * 0.10; // Status

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
        font: smallFont,
      );

      // Header row
      final PdfGridRow headerRow = grid.headers.add(1)[0];
      final PdfColor tableHeaderColor = PdfColor(248, 249, 250);

      headerRow.cells[0].value = 'Product ID';
      headerRow.cells[1].value = 'Name';
      headerRow.cells[2].value = 'Category';
      headerRow.cells[3].value = 'Stock';
      headerRow.cells[4].value = 'Unit Cost';
      headerRow.cells[5].value = 'Selling Price';
      headerRow.cells[6].value = 'Total Sold';
      headerRow.cells[7].value = 'Revenue';
      headerRow.cells[8].value = 'Status';

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
      for (var product in _filteredData) {
        final PdfGridRow row = grid.rows.add();

        row.cells[0].value = product['productId'];
        row.cells[1].value = product['name'];
        row.cells[2].value = product['category'];
        row.cells[3].value =
            '${product['stock']} (${product['minStock']}-${product['maxStock']})';
        row.cells[4].value = 'Rs ${product['unitCost'].toStringAsFixed(2)}';
        row.cells[5].value = 'Rs ${product['sellingPrice'].toStringAsFixed(2)}';
        row.cells[6].value = product['totalSold'].toString();
        row.cells[7].value = 'Rs ${product['revenue'].toStringAsFixed(2)}';
        row.cells[8].value = product['status'];

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
        dialogTitle: 'Save Product Report PDF',
        fileName:
            'product_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
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

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, const Color(0xFFF8F9FA)],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Header
            Container(
              padding: const EdgeInsets.all(24),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.inventory,
                          color: Colors.white,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Product Report',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Comprehensive product analytics and inventory reporting',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _exportToPDF,
                        icon: const Icon(Icons.picture_as_pdf, size: 16),
                        label: const Text('Export PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0D1845),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Filters Row
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      // Period Filter
                      Container(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          value: _selectedPeriod,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            labelText: 'Period',
                            labelStyle: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                          dropdownColor: Colors.white,
                          style: TextStyle(color: const Color(0xFF0D1845)),
                          items: _periods
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
                              });
                            }
                          },
                        ),
                      ),
                      // Category Filter
                      Container(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          value: _selectedCategory,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            labelText: 'Category',
                            labelStyle: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                          dropdownColor: Colors.white,
                          style: TextStyle(color: const Color(0xFF0D1845)),
                          items: _categories
                              .map(
                                (category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() {
                                _selectedCategory = value;
                              });
                            }
                          },
                        ),
                      ),
                      // Stock Status Filter
                      Container(
                        width: 180,
                        child: DropdownButtonFormField<String>(
                          value: _selectedStockStatus,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            labelText: 'Stock Status',
                            labelStyle: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 12,
                            ),
                          ),
                          dropdownColor: Colors.white,
                          style: TextStyle(color: const Color(0xFF0D1845)),
                          items: _stockStatuses
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
                                _selectedStockStatus = value;
                              });
                            }
                          },
                        ),
                      ),
                      // Clear Filters Button (only show if filters are applied)
                      if (_selectedPeriod != 'Today' ||
                          _selectedCategory != 'All Categories' ||
                          _selectedStockStatus != 'All Status')
                        ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _selectedPeriod = 'Today';
                              _selectedCategory = 'All Categories';
                              _selectedStockStatus = 'All Status';
                            });
                          },
                          icon: const Icon(Icons.clear, size: 16),
                          label: const Text('Clear Filters'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red.withOpacity(0.2),
                            foregroundColor: Colors.white,
                            side: BorderSide(color: Colors.white, width: 1),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
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
            const SizedBox(height: 24),

            // Summary Cards
            Row(
              children: [
                _buildSummaryCard(
                  'Total Products',
                  _totalProducts.toInt().toString(),
                  Icons.inventory,
                  Colors.blue,
                ),
                _buildSummaryCard(
                  'Total Stock',
                  _totalStock.toInt().toString(),
                  Icons.warehouse,
                  Colors.green,
                ),
                _buildSummaryCard(
                  'Total Revenue',
                  'Rs. ${NumberFormat('#,##0.00').format(_totalRevenue)}',
                  Icons.attach_money,
                  Colors.orange,
                ),
                _buildSummaryCard(
                  'Avg Price',
                  'Rs. ${NumberFormat('#,##0.00').format(_averagePrice)}',
                  Icons.trending_up,
                  Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Enhanced Filters Section
            Container(
              padding: const EdgeInsets.all(16),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Period Filter
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 6,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.date_range,
                                    size: 16,
                                    color: Color(0xFF0D1845),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Time Period',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF343A40),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedPeriod,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Color(0xFFDEE2E6),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Color(0xFFDEE2E6),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Color(0xFF0D1845),
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                items: _periods
                                    .map(
                                      (period) => DropdownMenuItem(
                                        value: period,
                                        child: Row(
                                          children: [
                                            Icon(
                                              period == 'Custom Range'
                                                  ? Icons.calendar_today
                                                  : Icons.schedule,
                                              color: Color(0xFF0D1845),
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              period,
                                              style: TextStyle(
                                                color: Color(0xFF343A40),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedPeriod = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Category Filter
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 6,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.category,
                                    size: 16,
                                    color: Color(0xFF0D1845),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Category',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF343A40),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedCategory,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Color(0xFFDEE2E6),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Color(0xFFDEE2E6),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Color(0xFF0D1845),
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                items: _categories
                                    .map(
                                      (category) => DropdownMenuItem(
                                        value: category,
                                        child: Row(
                                          children: [
                                            Icon(
                                              category == 'All Categories'
                                                  ? Icons.category
                                                  : Icons.inventory_2,
                                              color:
                                                  category == 'All Categories'
                                                  ? Color(0xFF6C757D)
                                                  : Color(0xFF0D1845),
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              category,
                                              style: TextStyle(
                                                color: Color(0xFF343A40),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedCategory = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      // Stock Status Filter
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 6,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.flag,
                                    size: 16,
                                    color: Color(0xFF0D1845),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Stock Status',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF343A40),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: DropdownButtonFormField<String>(
                                value: _selectedStockStatus,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Color(0xFFDEE2E6),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Color(0xFFDEE2E6),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Color(0xFF0D1845),
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                items: _stockStatuses
                                    .map(
                                      (status) => DropdownMenuItem(
                                        value: status,
                                        child: Row(
                                          children: [
                                            Icon(
                                              status == 'All Status'
                                                  ? Icons.list
                                                  : Icons.flag,
                                              color: status == 'All Status'
                                                  ? Color(0xFF6C757D)
                                                  : Color(0xFF0D1845),
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              status,
                                              style: TextStyle(
                                                color: Color(0xFF343A40),
                                                fontSize: 14,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    setState(() {
                                      _selectedStockStatus = value;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Search Field
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(
                                left: 4,
                                bottom: 6,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.search,
                                    size: 16,
                                    color: Color(0xFF0D1845),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Search',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF343A40),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  hintText:
                                      'Search by product name, ID, or SKU...',
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: Color(0xFF0D1845),
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Color(0xFFDEE2E6),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Color(0xFFDEE2E6),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: Color(0xFF0D1845),
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                onChanged: (value) => setState(() {}),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Enhanced Table Section
            Container(
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
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Icon(
                          Icons.inventory,
                          color: Color(0xFF0D1845),
                          size: 18,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Product Report Details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF343A40),
                          ),
                        ),
                        Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.inventory_2,
                                color: Color(0xFF1976D2),
                                size: 12,
                              ),
                              SizedBox(width: 3),
                              Text(
                                '${_filteredData.length} Records',
                                style: TextStyle(
                                  color: Color(0xFF1976D2),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(
                        Color(0xFFF8F9FA),
                      ),
                      dataRowColor: MaterialStateProperty.resolveWith<Color>((
                        Set<MaterialState> states,
                      ) {
                        if (states.contains(MaterialState.selected)) {
                          return Color(0xFF0D1845).withOpacity(0.1);
                        }
                        return Colors.white;
                      }),
                      columns: const [
                        DataColumn(label: Text('Product ID')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Category')),
                        DataColumn(label: Text('Stock')),
                        DataColumn(label: Text('Unit Cost')),
                        DataColumn(label: Text('Selling Price')),
                        DataColumn(label: Text('Total Sold')),
                        DataColumn(label: Text('Revenue')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: _filteredData.map((product) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                product['productId'],
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    decoration: BoxDecoration(
                                      color: Color(0xFF0D1845).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      Icons.inventory_2,
                                      color: Color(0xFF0D1845),
                                      size: 12,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(product['name']),
                                ],
                              ),
                            ),
                            DataCell(Text(product['category'])),
                            DataCell(
                              Text(
                                '${product['stock']} (${product['minStock']}-${product['maxStock']})',
                              ),
                            ),
                            DataCell(
                              Text(
                                'Rs. ${NumberFormat('#,##0.00').format(product['unitCost'])}',
                              ),
                            ),
                            DataCell(
                              Text(
                                'Rs. ${NumberFormat('#,##0.00').format(product['sellingPrice'])}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataCell(Text(product['totalSold'].toString())),
                            DataCell(
                              Text(
                                'Rs. ${NumberFormat('#,##0.00').format(product['revenue'])}',
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStockStatusColor(
                                    product['status'],
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  product['status'],
                                  style: TextStyle(
                                    color: _getStockStatusColor(
                                      product['status'],
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        );
                      }).toList(),
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

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                color: Color(0xFF6C757D),
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
