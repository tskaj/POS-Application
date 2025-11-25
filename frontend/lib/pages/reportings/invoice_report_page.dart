import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';

class InvoiceReportPage extends StatefulWidget {
  const InvoiceReportPage({super.key});

  @override
  State<InvoiceReportPage> createState() => _InvoiceReportPageState();
}

class _InvoiceReportPageState extends State<InvoiceReportPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedVendor = 'All Vendors';
  String _selectedStatus = 'All Status';

  final List<String> _vendors = [
    'All Vendors',
    'John Doe',
    'Jane Smith',
    'Bob Johnson',
    'Alice Brown',
  ];
  final List<String> _statuses = [
    'All Status',
    'Paid',
    'Unpaid',
    'Partial',
    'Overdue',
  ];

  final List<Map<String, dynamic>> _invoiceData = [
    {
      'invoiceNo': 'INV-001',
      'date': '2024-01-15',
      'vendor': 'John Doe',
      'biller': 'Biller 1',
      'total': 1250.00,
      'paid': 1250.00,
      'due': 0.00,
      'status': 'Paid',
      'paymentMethod': 'Cash',
    },
    {
      'invoiceNo': 'INV-002',
      'date': '2024-01-14',
      'vendor': 'Jane Smith',
      'biller': 'Biller 2',
      'total': 890.50,
      'paid': 445.25,
      'due': 445.25,
      'status': 'Partial',
      'paymentMethod': 'Card',
    },
    {
      'invoiceNo': 'INV-003',
      'date': '2024-01-13',
      'vendor': 'Bob Johnson',
      'biller': 'Biller 1',
      'total': 2100.75,
      'paid': 0.00,
      'due': 2100.75,
      'status': 'Unpaid',
      'paymentMethod': 'Bank Transfer',
    },
    {
      'invoiceNo': 'INV-004',
      'date': '2024-01-12',
      'vendor': 'Alice Brown',
      'biller': 'Biller 3',
      'total': 675.25,
      'paid': 675.25,
      'due': 0.00,
      'status': 'Paid',
      'paymentMethod': 'Cash',
    },
    {
      'invoiceNo': 'INV-005',
      'date': '2024-01-11',
      'vendor': 'John Doe',
      'biller': 'Biller 2',
      'total': 1540.00,
      'paid': 770.00,
      'due': 770.00,
      'status': 'Partial',
      'paymentMethod': 'Cheque',
    },
  ];

  List<Map<String, dynamic>> get _filteredData {
    return _invoiceData.where((invoice) {
      final matchesSearch =
          invoice['invoiceNo'].toString().toLowerCase().contains(
            _searchController.text.toLowerCase(),
          ) ||
          invoice['vendor'].toString().toLowerCase().contains(
            _searchController.text.toLowerCase(),
          );
      final matchesCustomer =
          _selectedVendor == 'All Vendors' ||
          invoice['vendor'] == _selectedVendor;
      final matchesStatus =
          _selectedStatus == 'All Status' ||
          invoice['status'] == _selectedStatus;

      return matchesSearch && matchesCustomer && matchesStatus;
    }).toList();
  }

  double get _totalAmount =>
      _filteredData.fold(0.0, (sum, invoice) => sum + invoice['total']);
  double get _totalPaid =>
      _filteredData.fold(0.0, (sum, invoice) => sum + invoice['paid']);
  double get _totalDue =>
      _filteredData.fold(0.0, (sum, invoice) => sum + invoice['due']);

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green;
      case 'Unpaid':
        return Colors.red;
      case 'Partial':
        return Colors.orange;
      case 'Overdue':
        return Colors.red.shade800;
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

      graphics.drawString(
        'Invoice Report',
        titleFont,
        bounds: Rect.fromLTWH(20, yPos, pageSize.width - 40, 30),
        brush: PdfSolidBrush(PdfColor(13, 24, 69)),
      );

      yPos += 35;

      String filterInfo =
          'Generated: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now())}';
      if (_selectedVendor != 'All Vendors')
        filterInfo += ' | Vendor: $_selectedVendor';
      if (_selectedStatus != 'All Status')
        filterInfo += ' | Status: $_selectedStatus';

      graphics.drawString(
        filterInfo,
        smallFont,
        bounds: Rect.fromLTWH(20, yPos, pageSize.width - 40, 20),
        brush: PdfSolidBrush(PdfColor(100, 100, 100)),
      );

      yPos += 30;

      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 8);

      final double pageWidth = pageSize.width;
      final double tableWidth = pageWidth * 0.95;

      grid.columns[0].width = tableWidth * 0.10;
      grid.columns[1].width = tableWidth * 0.10;
      grid.columns[2].width = tableWidth * 0.15;
      grid.columns[3].width = tableWidth * 0.13;
      grid.columns[4].width = tableWidth * 0.13;
      grid.columns[5].width = tableWidth * 0.13;
      grid.columns[6].width = tableWidth * 0.13;
      grid.columns[7].width = tableWidth * 0.13;

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
        font: smallFont,
      );

      final PdfGridRow headerRow = grid.headers.add(1)[0];
      final PdfColor tableHeaderColor = PdfColor(248, 249, 250);

      headerRow.cells[0].value = 'Invoice';
      headerRow.cells[1].value = 'Date';
      headerRow.cells[2].value = 'Customer';
      headerRow.cells[3].value = 'Total';
      headerRow.cells[4].value = 'Paid';
      headerRow.cells[5].value = 'Due';
      headerRow.cells[6].value = 'Status';
      headerRow.cells[7].value = 'Payment';

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

      for (var invoice in _invoiceData) {
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = invoice['invoiceNo'];
        row.cells[1].value = DateFormat(
          'MMM dd',
        ).format(DateTime.parse(invoice['date']));
        row.cells[2].value = invoice['vendor'];
        row.cells[3].value = 'Rs ${invoice['total'].toStringAsFixed(2)}';
        row.cells[4].value = 'Rs ${invoice['paid'].toStringAsFixed(2)}';
        row.cells[5].value = 'Rs ${invoice['due'].toStringAsFixed(2)}';
        row.cells[6].value = invoice['status'];
        row.cells[7].value = invoice['paymentMethod'];

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

      final List<int> bytes = await document.save();
      document.dispose();

      if (mounted) Navigator.of(context).pop();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Minimize application to save PDF'),
            duration: Duration(seconds: 2),
          ),
        );
      }

      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Invoice Report PDF',
        fileName:
            'invoice_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
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
    final filteredData = _filteredData;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Invoice Report'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Invoice Report',
            onPressed: () {
              // Add refresh logic if needed
              setState(() {});
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
                          Icons.receipt_long,
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
                              'Invoice Report',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Comprehensive invoice analytics and reporting',
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
                        'Total Invoices',
                        filteredData.length.toString(),
                        Icons.receipt,
                        Colors.blue,
                      ),
                      _buildSummaryCard(
                        'Total Amount',
                        'Rs. ${NumberFormat('#,##0.00').format(_totalAmount)}',
                        Icons.attach_money,
                        Colors.green,
                      ),
                      _buildSummaryCard(
                        'Total Paid',
                        'Rs. ${NumberFormat('#,##0.00').format(_totalPaid)}',
                        Icons.payment,
                        Colors.orange,
                      ),
                      _buildSummaryCard(
                        'Total Due',
                        'Rs. ${NumberFormat('#,##0.00').format(_totalDue)}',
                        Icons.pending,
                        Colors.red,
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
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Search by Invoice No
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 36,
                              margin: const EdgeInsets.only(right: 8),
                              child: TextField(
                                controller: _searchController,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Colors.black,
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search by invoice no. or vendor',
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
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                onChanged: (value) => setState(() {}),
                              ),
                            ),
                          ),
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
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                items: _vendors.map((value) {
                                  return DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null)
                                    setState(() => _selectedVendor = value);
                                },
                              ),
                            ),
                          ),
                          // Status Filter
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
                                  prefixIcon: const Icon(Icons.flag, size: 16),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                ),
                                items: _statuses.map((value) {
                                  return DropdownMenuItem(
                                    value: value,
                                    child: Text(value),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  if (value != null)
                                    setState(() => _selectedStatus = value);
                                },
                              ),
                            ),
                          ),
                          SizedBox(
                            height: 32,
                            child: ElevatedButton.icon(
                              onPressed: _exportToPDF,
                              icon: const Icon(Icons.picture_as_pdf, size: 14),
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
                          // Invoice No Column
                          Expanded(
                            flex: 1,
                            child: Text('Invoice No', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          // Date Column
                          Expanded(
                            flex: 1,
                            child: Text('Date', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          // Vendor Column
                          Expanded(
                            flex: 2,
                            child: Text('Vendor', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          // Biller Column
                          Expanded(
                            flex: 1,
                            child: Text('Biller', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          // Total Column - Centered
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: Text('Total', style: _headerStyle()),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Paid Column - Centered
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: Text('Paid', style: _headerStyle()),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Due Column - Centered
                          Expanded(
                            flex: 1,
                            child: Center(
                              child: Text('Due', style: _headerStyle()),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Status Column
                          Expanded(
                            flex: 1,
                            child: Text('Status', style: _headerStyle()),
                          ),
                        ],
                      ),
                    ),

                    // Table Body
                    Expanded(
                      child: filteredData.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.receipt_long,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No invoice records found',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: filteredData.length,
                              itemBuilder: (context, index) {
                                final invoice = filteredData[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
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
                                      // Invoice No Column
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          invoice['invoiceNo'],
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0D1845),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Date Column
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          DateFormat('dd MMM yyyy').format(
                                            DateTime.parse(invoice['date']),
                                          ),
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF495057),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Vendor Column
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          invoice['vendor'],
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF495057),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Biller Column
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          invoice['biller'],
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF495057),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Total Column - Centered
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Text(
                                            'Rs. ${invoice['total'].toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w600,
                                              color: Color(0xFF0D1845),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Paid Column - Centered
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Text(
                                            'Rs. ${invoice['paid'].toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF495057),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Due Column - Centered
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Text(
                                            'Rs. ${invoice['due'].toStringAsFixed(2)}',
                                            style: const TextStyle(
                                              fontSize: 9,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF495057),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Status Column
                                      Expanded(
                                        flex: 1,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getStatusColor(
                                              invoice['status'],
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: Center(
                                            child: Text(
                                              invoice['status'],
                                              style: TextStyle(
                                                fontSize: 8,
                                                fontWeight: FontWeight.w600,
                                                color: _getStatusColor(
                                                  invoice['status'],
                                                ),
                                              ),
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
          ],
        ),
      ),
    );
  }

  TextStyle _headerStyle() {
    return const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: Color(0xFF495057),
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
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              title,
              style: TextStyle(
                fontSize: 10,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
