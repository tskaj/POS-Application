import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class SupplierReportPage extends StatefulWidget {
  const SupplierReportPage({super.key});

  @override
  State<SupplierReportPage> createState() => _SupplierReportPageState();
}

class _SupplierReportPageState extends State<SupplierReportPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedPeriod = 'Today';
  String _selectedSupplier = 'All Suppliers';
  String _selectedStatus = 'All Status';

  final List<String> _periods = [
    'Today',
    'Yesterday',
    'Last 7 Days',
    'Last 30 Days',
    'This Month',
    'Last Month',
    'Custom Range',
  ];
  final List<String> _suppliers = [
    'All Suppliers',
    'TechCorp Inc',
    'Global Supplies Ltd',
    'Prime Distributors',
    'Quality Goods Co',
  ];
  final List<String> _statuses = [
    'All Status',
    'Active',
    'Inactive',
    'Suspended',
  ];

  final List<Map<String, dynamic>> _supplierData = [
    {
      'supplierId': 'SUP-001',
      'name': 'TechCorp Inc',
      'contact': '+1-555-0123',
      'email': 'contact@techcorp.com',
      'totalPurchases': 15,
      'totalAmount': 45000.00,
      'lastPurchase': '2024-01-15',
      'status': 'Active',
      'outstanding': 2500.00,
      'city': 'New York',
    },
    {
      'supplierId': 'SUP-002',
      'name': 'Global Supplies Ltd',
      'contact': '+1-555-0456',
      'email': 'info@globalsupplies.com',
      'totalPurchases': 23,
      'totalAmount': 67800.50,
      'lastPurchase': '2024-01-14',
      'status': 'Active',
      'outstanding': 0.00,
      'city': 'Los Angeles',
    },
    {
      'supplierId': 'SUP-003',
      'name': 'Prime Distributors',
      'contact': '+1-555-0789',
      'email': 'sales@primedist.com',
      'totalPurchases': 8,
      'totalAmount': 12500.75,
      'lastPurchase': '2024-01-10',
      'status': 'Active',
      'outstanding': 1250.00,
      'city': 'Chicago',
    },
    {
      'supplierId': 'SUP-004',
      'name': 'Quality Goods Co',
      'contact': '+1-555-0321',
      'email': 'support@qualitygoods.com',
      'totalPurchases': 31,
      'totalAmount': 89500.25,
      'lastPurchase': '2024-01-12',
      'status': 'Active',
      'outstanding': 3500.00,
      'city': 'Houston',
    },
    {
      'supplierId': 'SUP-005',
      'name': 'Metro Supplies',
      'contact': '+1-555-0654',
      'email': 'orders@metrosupplies.com',
      'totalPurchases': 12,
      'totalAmount': 28500.00,
      'lastPurchase': '2024-01-08',
      'status': 'Inactive',
      'outstanding': 0.00,
      'city': 'Phoenix',
    },
  ];

  List<Map<String, dynamic>> get _filteredData {
    return _supplierData.where((supplier) {
      final matchesSearch =
          supplier['name'].toString().toLowerCase().contains(
            _searchController.text.toLowerCase(),
          ) ||
          supplier['supplierId'].toString().toLowerCase().contains(
            _searchController.text.toLowerCase(),
          ) ||
          supplier['email'].toString().toLowerCase().contains(
            _searchController.text.toLowerCase(),
          );
      final matchesSupplier =
          _selectedSupplier == 'All Suppliers' ||
          supplier['name'] == _selectedSupplier;
      final matchesStatus =
          _selectedStatus == 'All Status' ||
          supplier['status'] == _selectedStatus;

      return matchesSearch && matchesSupplier && matchesStatus;
    }).toList();
  }

  double get _totalSuppliers => _filteredData.length.toDouble();
  double get _totalPurchases => _filteredData.fold(
    0.0,
    (sum, supplier) => sum + supplier['totalPurchases'],
  );
  double get _totalAmount =>
      _filteredData.fold(0.0, (sum, supplier) => sum + supplier['totalAmount']);
  double get _totalOutstanding =>
      _filteredData.fold(0.0, (sum, supplier) => sum + supplier['outstanding']);

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Inactive':
        return Colors.grey;
      case 'Suspended':
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
        'Supplier Report',
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
      if (_selectedSupplier != 'All Suppliers')
        filterInfo += ' | Supplier: $_selectedSupplier';
      if (_selectedStatus != 'All Status')
        filterInfo += ' | Status: $_selectedStatus';
      if (_searchController.text.isNotEmpty)
        filterInfo += ' | Search: ${_searchController.text}';

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

      grid.columns[0].width = tableWidth * 0.10; // Supplier ID
      grid.columns[1].width = tableWidth * 0.15; // Name
      grid.columns[2].width = tableWidth * 0.12; // Contact
      grid.columns[3].width = tableWidth * 0.18; // Email
      grid.columns[4].width = tableWidth * 0.10; // Total Purchases
      grid.columns[5].width = tableWidth * 0.12; // Total Amount
      grid.columns[6].width = tableWidth * 0.10; // Outstanding
      grid.columns[7].width = tableWidth * 0.08; // Last Purchase
      grid.columns[8].width = tableWidth * 0.05; // Status

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
        font: smallFont,
      );

      // Header row
      final PdfGridRow headerRow = grid.headers.add(1)[0];
      final PdfColor tableHeaderColor = PdfColor(248, 249, 250);

      headerRow.cells[0].value = 'ID';
      headerRow.cells[1].value = 'Name';
      headerRow.cells[2].value = 'Contact';
      headerRow.cells[3].value = 'Email';
      headerRow.cells[4].value = 'Purchases';
      headerRow.cells[5].value = 'Total Amount';
      headerRow.cells[6].value = 'Outstanding';
      headerRow.cells[7].value = 'Last Purchase';
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
      final filteredData = _filteredData;
      for (var supplier in filteredData) {
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = supplier['supplierId'];
        row.cells[1].value = supplier['name'];
        row.cells[2].value = supplier['contact'];
        row.cells[3].value = supplier['email'];
        row.cells[4].value = supplier['totalPurchases'].toString();
        row.cells[5].value = 'Rs ${supplier['totalAmount'].toStringAsFixed(2)}';
        row.cells[6].value = 'Rs ${supplier['outstanding'].toStringAsFixed(2)}';
        row.cells[7].value = DateFormat(
          'dd/MM/yy',
        ).format(DateTime.parse(supplier['lastPurchase']));
        row.cells[8].value = supplier['status'];

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
        dialogTitle: 'Save Supplier Report PDF',
        fileName:
            'supplier_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
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
                          Icons.business,
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
                              'Supplier Report',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Comprehensive supplier analytics and reporting',
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
                        icon: const Icon(Icons.picture_as_pdf, size: 18),
                        label: const Text('Export PDF'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Color(0xFF0D1845),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Compact Filters
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      // Period Filter
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedPeriod,
                          underline: SizedBox(),
                          dropdownColor: Color(0xFF0D1845),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white,
                            size: 20,
                          ),
                          style: TextStyle(color: Colors.white, fontSize: 12),
                          items: _periods
                              .map(
                                (period) => DropdownMenuItem(
                                  value: period,
                                  child: Text(period),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedPeriod = value!;
                            });
                          },
                        ),
                      ),
                      // Supplier Filter
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedSupplier,
                          underline: SizedBox(),
                          dropdownColor: Color(0xFF0D1845),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white,
                            size: 20,
                          ),
                          style: TextStyle(color: Colors.white, fontSize: 12),
                          items: _suppliers
                              .map(
                                (supplier) => DropdownMenuItem(
                                  value: supplier,
                                  child: Text(supplier),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedSupplier = value!;
                            });
                          },
                        ),
                      ),
                      // Status Filter
                      Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.3),
                          ),
                        ),
                        child: DropdownButton<String>(
                          value: _selectedStatus,
                          underline: SizedBox(),
                          dropdownColor: Color(0xFF0D1845),
                          icon: Icon(
                            Icons.arrow_drop_down,
                            color: Colors.white,
                            size: 20,
                          ),
                          style: TextStyle(color: Colors.white, fontSize: 12),
                          items: _statuses
                              .map(
                                (status) => DropdownMenuItem(
                                  value: status,
                                  child: Text(status),
                                ),
                              )
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStatus = value!;
                            });
                          },
                        ),
                      ),
                      // Clear Filters Button
                      if (_selectedPeriod != 'Today' ||
                          _selectedSupplier != 'All Suppliers' ||
                          _selectedStatus != 'All Status' ||
                          _searchController.text.isNotEmpty)
                        Container(
                          height: 36,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedPeriod = 'Today';
                                _selectedSupplier = 'All Suppliers';
                                _selectedStatus = 'All Status';
                                _searchController.clear();
                              });
                            },
                            icon: Icon(Icons.clear, size: 16),
                            label: Text('Clear'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.8),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
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
                  'Total Suppliers',
                  _totalSuppliers.toInt().toString(),
                  Icons.business,
                  Colors.blue,
                ),
                _buildSummaryCard(
                  'Total Purchases',
                  _totalPurchases.toInt().toString(),
                  Icons.shopping_cart,
                  Colors.green,
                ),
                _buildSummaryCard(
                  'Total Amount',
                  'Rs. ${NumberFormat('#,##0.00').format(_totalAmount)}',
                  Icons.attach_money,
                  Colors.orange,
                ),
                _buildSummaryCard(
                  'Outstanding',
                  'Rs. ${NumberFormat('#,##0.00').format(_totalOutstanding)}',
                  Icons.pending,
                  Colors.red,
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
                  // Search Field
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 4, bottom: 6),
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
                                'Search by supplier name, ID, or email...',
                            prefixIcon: Icon(
                              Icons.search,
                              color: Color(0xFF0D1845),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Color(0xFFDEE2E6)),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Color(0xFFDEE2E6)),
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
                          Icons.business,
                          color: Color(0xFF0D1845),
                          size: 18,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Supplier Report Details',
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
                                Icons.business,
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
                        DataColumn(label: Text('Supplier ID')),
                        DataColumn(label: Text('Name')),
                        DataColumn(label: Text('Contact')),
                        DataColumn(label: Text('Email')),
                        DataColumn(label: Text('Total Purchases')),
                        DataColumn(label: Text('Total Amount')),
                        DataColumn(label: Text('Outstanding')),
                        DataColumn(label: Text('Last Purchase')),
                        DataColumn(label: Text('Status')),
                      ],
                      rows: _filteredData.map((supplier) {
                        return DataRow(
                          cells: [
                            DataCell(
                              Text(
                                supplier['supplierId'],
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
                                      Icons.business,
                                      color: Color(0xFF0D1845),
                                      size: 12,
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  Text(supplier['name']),
                                ],
                              ),
                            ),
                            DataCell(Text(supplier['contact'])),
                            DataCell(
                              Text(
                                supplier['email'],
                                style: TextStyle(color: Colors.blue),
                              ),
                            ),
                            DataCell(
                              Text(supplier['totalPurchases'].toString()),
                            ),
                            DataCell(
                              Text(
                                'Rs. ${NumberFormat('#,##0.00').format(supplier['totalAmount'])}',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                            DataCell(
                              Text(
                                'Rs. ${NumberFormat('#,##0.00').format(supplier['outstanding'])}',
                              ),
                            ),
                            DataCell(
                              Text(
                                DateFormat('dd MMM yyyy').format(
                                  DateTime.parse(supplier['lastPurchase']),
                                ),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    supplier['status'],
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  supplier['status'],
                                  style: TextStyle(
                                    color: _getStatusColor(supplier['status']),
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
        margin: const EdgeInsets.all(8.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFDEE2E6), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.2),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
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
                    child: Icon(icon, color: color),
                  ),
                  const Spacer(),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: const TextStyle(fontSize: 14, color: Color(0xFF6C757D)),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF343A40),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
