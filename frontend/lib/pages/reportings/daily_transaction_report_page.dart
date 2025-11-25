import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import '../../services/transaction_service.dart';

class DailyTransactionReportPage extends StatefulWidget {
  const DailyTransactionReportPage({super.key});

  @override
  State<DailyTransactionReportPage> createState() =>
      _DailyTransactionReportPageState();
}

class _DailyTransactionReportPageState
    extends State<DailyTransactionReportPage> {
  DateTime? _startDate = DateTime.now();
  DateTime? _endDate = DateTime.now();
  DailyTransactionReport? _reportData;
  bool _isLoading = false;
  String? _errorMessage;

  // Selection
  List<TransactionEntry> _selectedTransactions = [];
  bool _selectAll = false;

  // Pagination
  int _currentPage = 1;
  final int _itemsPerPage = 10;

  int get _totalPages {
    if (_reportData == null || _reportData!.transactions.isEmpty) return 1;
    return (_reportData!.transactions.length / _itemsPerPage).ceil();
  }

  List<TransactionEntry> get _paginatedTransactions {
    if (_reportData == null) return [];
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return _reportData!.transactions.sublist(
      startIndex,
      endIndex > _reportData!.transactions.length
          ? _reportData!.transactions.length
          : endIndex,
    );
  }

  @override
  void initState() {
    super.initState();
    // Set default dates: current date to current date
    _startDate = DateTime.now();
    _endDate = DateTime.now();
    // Load transactions automatically on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadTransactions();
    });
  }

  Future<void> _loadTransactions() async {
    if (_startDate == null || _endDate == null) {
      setState(() {
        _errorMessage = 'Please select both start and end dates';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final startDateStr = DateFormat('yyyy-MM-dd').format(_startDate!);
      final endDateStr = DateFormat('yyyy-MM-dd').format(_endDate!);

      final report = await TransactionService.getTransactionsByDateRange(
        startDate: startDateStr,
        endDate: endDateStr,
      );

      setState(() {
        _reportData = report;
        _isLoading = false;
        _currentPage = 1; // Reset to first page
        _selectedTransactions.clear(); // Clear selection on new data
        _selectAll = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load transactions: $e';
        _isLoading = false;
      });
    }
  }

  void _toggleTransactionSelection(TransactionEntry transaction) {
    setState(() {
      final transactionId = transaction.tranId;
      final existingIndex = _selectedTransactions.indexWhere(
        (t) => t.tranId == transactionId,
      );

      if (existingIndex >= 0) {
        _selectedTransactions.removeAt(existingIndex);
      } else {
        _selectedTransactions.add(transaction);
      }

      _updateSelectAllState();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectAll) {
        _selectedTransactions.clear();
        _selectAll = false;
      } else {
        _selectedTransactions = List.from(_reportData!.transactions);
        _selectAll = true;
      }
    });
  }

  void _updateSelectAllState() {
    if (_reportData == null || _reportData!.transactions.isEmpty) {
      _selectAll = false;
      return;
    }

    _selectAll =
        _selectedTransactions.length == _reportData!.transactions.length;
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

      // Determine which transactions to export
      final toExport = _selectedTransactions.isNotEmpty
          ? _selectedTransactions
          : (_reportData?.transactions ?? []);

      if (toExport.isEmpty) {
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

      // Title
      graphics.drawString(
        'Daily Transaction Report',
        titleFont,
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 30),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );

      // Date range and generation info
      String filterInfo =
          'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}';
      if (_startDate != null && _endDate != null) {
        filterInfo +=
            ' | Period: ${DateFormat('dd MMM yyyy').format(_startDate!)} - ${DateFormat('dd MMM yyyy').format(_endDate!)}';
      }
      if (_selectedTransactions.isNotEmpty) {
        filterInfo +=
            ' | Selected: ${_selectedTransactions.length} transactions';
      }
      graphics.drawString(
        filterInfo,
        smallFont,
        bounds: Rect.fromLTWH(0, 30, page.getClientSize().width, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // Summary info
      if (_reportData != null) {
        String summaryInfo =
            'Opening Balance: Rs ${double.tryParse(_reportData!.openingBalance)?.toStringAsFixed(2) ?? _reportData!.openingBalance} | ';
        summaryInfo +=
            'Total Debit: Rs ${_reportData!.summary.debit.toStringAsFixed(2)} | ';
        summaryInfo +=
            'Total Credit: Rs ${_reportData!.summary.credit.toStringAsFixed(2)} | ';
        summaryInfo +=
            'Closing Balance: Rs ${_reportData!.summary.closingBalance.toStringAsFixed(2)}';

        graphics.drawString(
          summaryInfo,
          smallFont,
          bounds: Rect.fromLTWH(0, 50, page.getClientSize().width, 20),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
      }

      // Table
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 6);

      final double pageWidth = page.getClientSize().width;
      final double tableWidth = pageWidth * 0.95;

      grid.columns[0].width = tableWidth * 0.10; // ID
      grid.columns[1].width = tableWidth * 0.15; // Date
      grid.columns[2].width = tableWidth * 0.35; // Description
      grid.columns[3].width = tableWidth * 0.13; // Debit
      grid.columns[4].width = tableWidth * 0.13; // Credit
      grid.columns[5].width = tableWidth * 0.14; // Balance

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
        font: smallFont,
      );

      // Header row
      final PdfGridRow headerRow = grid.headers.add(1)[0];
      headerRow.cells[0].value = 'ID';
      headerRow.cells[1].value = 'Date';
      headerRow.cells[2].value = 'Description';
      headerRow.cells[3].value = 'Debit';
      headerRow.cells[4].value = 'Credit';
      headerRow.cells[5].value = 'Balance';

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

      // Data rows
      for (final transaction in toExport) {
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = transaction.tranId.toString();
        row.cells[1].value = transaction.date;
        row.cells[2].value = transaction.description;

        final debitValue = double.tryParse(transaction.debit) ?? 0;
        final creditValue = double.tryParse(transaction.credit) ?? 0;

        row.cells[3].value = debitValue > 0
            ? 'Rs ${debitValue.toStringAsFixed(2)}'
            : '-';
        row.cells[4].value = creditValue > 0
            ? 'Rs ${creditValue.toStringAsFixed(2)}'
            : '-';
        row.cells[5].value = 'Rs ${transaction.balance.toStringAsFixed(2)}';

        // Align numeric columns
        row.cells[3].style = PdfGridCellStyle(
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        row.cells[4].style = PdfGridCellStyle(
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        row.cells[5].style = PdfGridCellStyle(
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
      }

      // Draw the main table and get its result to know where it ended
      final PdfLayoutResult result = grid.draw(
        page: page,
        bounds: Rect.fromLTWH(
          0,
          75,
          page.getClientSize().width,
          page.getClientSize().height - 75,
        ),
      )!;

      // Add Summary Section after the table
      if (_reportData != null) {
        // Summary needs about 150 pixels (title + 5 rows)
        const double summaryHeight = 150;
        final double summaryY = result.bounds.bottom + 20;

        // Check if we have enough space for the complete summary box
        PdfPage summaryPage = result.page;
        double summaryYPosition = summaryY;

        // If not enough space for complete summary, start on new page
        if (summaryY + summaryHeight > summaryPage.getClientSize().height) {
          summaryPage = document.pages.add();
          summaryYPosition = 20;
        }

        final PdfGraphics summaryGraphics = summaryPage.graphics;

        // Summary Title
        summaryGraphics.drawString(
          'Summary',
          headerFont,
          bounds: Rect.fromLTWH(
            0,
            summaryYPosition,
            summaryPage.getClientSize().width,
            20,
          ),
          format: PdfStringFormat(
            alignment: PdfTextAlignment.left,
            lineAlignment: PdfVerticalAlignment.middle,
          ),
        );

        // Create summary grid
        final PdfGrid summaryGrid = PdfGrid();
        summaryGrid.columns.add(count: 2);

        final double summaryWidth = 300;
        summaryGrid.columns[0].width = summaryWidth * 0.6;
        summaryGrid.columns[1].width = summaryWidth * 0.4;

        summaryGrid.style = PdfGridStyle(
          cellPadding: PdfPaddings(left: 5, right: 5, top: 4, bottom: 4),
          font: smallFont,
        );

        // Summary rows - matching exactly what appears in the summary dialog
        final summaryData = [
          ['Period', '${_reportData!.from} to ${_reportData!.to}'],
          [
            'Opening Balance',
            'Rs ${double.tryParse(_reportData!.openingBalance)?.toStringAsFixed(2) ?? _reportData!.openingBalance}',
          ],
          [
            'Total Debit',
            'Rs ${_reportData!.summary.debit.toStringAsFixed(2)}',
          ],
          [
            'Total Credit',
            'Rs ${_reportData!.summary.credit.toStringAsFixed(2)}',
          ],
          [
            'Closing Balance',
            'Rs ${_reportData!.summary.closingBalance.toStringAsFixed(2)}',
          ],
        ];

        for (int i = 0; i < summaryData.length; i++) {
          final PdfGridRow row = summaryGrid.rows.add();
          row.cells[0].value = summaryData[i][0];
          row.cells[1].value = summaryData[i][1];

          // Style for labels
          row.cells[0].style = PdfGridCellStyle(
            backgroundBrush: PdfSolidBrush(PdfColor(248, 249, 250)),
            textBrush: PdfSolidBrush(PdfColor(73, 80, 87)),
            font: i == 0 || i == 4
                ? headerFont
                : smallFont, // Period and Closing Balance are bold
          );

          // Style for values (right-aligned)
          row.cells[1].style = PdfGridCellStyle(
            backgroundBrush: i == 0 || i == 4
                ? PdfSolidBrush(PdfColor(230, 240, 255))
                : PdfSolidBrush(PdfColor(255, 255, 255)),
            textBrush: i == 2
                ? PdfSolidBrush(PdfColor(220, 53, 69)) // Red for debit
                : i == 3
                ? PdfSolidBrush(PdfColor(40, 167, 69)) // Green for credit
                : i == 4
                ? PdfSolidBrush(
                    PdfColor(13, 110, 253),
                  ) // Blue for closing balance
                : PdfSolidBrush(PdfColor(73, 80, 87)),
            font: i == 0 || i == 4
                ? headerFont
                : smallFont, // Period and Closing Balance are bold
            format: PdfStringFormat(alignment: PdfTextAlignment.right),
          );
        }

        // Draw summary grid with layout format to prevent pagination
        summaryGrid.draw(
          page: summaryPage,
          bounds: Rect.fromLTWH(0, summaryYPosition + 25, summaryWidth, 0),
          format: PdfLayoutFormat(layoutType: PdfLayoutType.onePage),
        );
      }

      // Save the PDF
      final List<int> bytes = await document.save();
      document.dispose();

      // Ask user where to save
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Daily Transaction Report PDF',
        fileName:
            'daily_transaction_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFile != null) {
        final File file = File(outputFile);
        await file.writeAsBytes(bytes, flush: true);

        if (!mounted) return;
        Navigator.of(context).pop(); // Close loading dialog

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved successfully!'),
            backgroundColor: Color(0xFF27ae60),
          ),
        );
      } else {
        if (!mounted) return;
        Navigator.of(context).pop(); // Close loading dialog
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop(); // Close loading dialog

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting PDF: $e'),
          backgroundColor: Color(0xFFDC3545),
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _showSummaryDialog() {
    if (_reportData == null) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Transaction Summary',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Container(
          width: 400,
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSummaryRow(
                'Period',
                '${_reportData!.from} to ${_reportData!.to}',
                isHeader: true,
              ),
              const Divider(height: 24),
              _buildSummaryRow(
                'Opening Balance',
                'Rs ${double.tryParse(_reportData!.openingBalance)?.toStringAsFixed(2) ?? _reportData!.openingBalance}',
              ),
              const SizedBox(height: 12),
              _buildSummaryRow(
                'Total Debit',
                'Rs ${_reportData!.summary.debit.toStringAsFixed(2)}',
                color: Colors.red.shade700,
              ),
              const SizedBox(height: 12),
              _buildSummaryRow(
                'Total Credit',
                'Rs ${_reportData!.summary.credit.toStringAsFixed(2)}',
                color: Colors.green.shade700,
              ),
              const Divider(height: 24),
              _buildSummaryRow(
                'Closing Balance',
                'Rs ${_reportData!.summary.closingBalance.toStringAsFixed(2)}',
                isHeader: true,
                color: Colors.blue.shade700,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isHeader = false,
    Color? color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isHeader ? 16 : 14,
            fontWeight: isHeader ? FontWeight.bold : FontWeight.w500,
            color: color ?? Colors.black87,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: isHeader ? 16 : 14,
            fontWeight: isHeader ? FontWeight.bold : FontWeight.w600,
            color: color ?? Colors.black87,
          ),
        ),
      ],
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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Column(
        children: [
          // Page Title Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Text(
              'Daily Transaction Report',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                letterSpacing: 0.5,
              ),
            ),
          ),

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
                  color: const Color(0xFF0D1845).withOpacity(0.3),
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
                        Icons.calendar_month,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Daily Transaction Report',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            'Comprehensive transaction ledger with debit, credit & balance tracking',
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
                if (_reportData != null)
                  Row(
                    children: [
                      _buildSummaryCard(
                        'Opening Balance',
                        'Rs ${double.tryParse(_reportData!.openingBalance)?.toStringAsFixed(2) ?? _reportData!.openingBalance}',
                        Icons.account_balance_wallet,
                        Colors.blue,
                      ),
                      _buildSummaryCard(
                        'Total Debit',
                        'Rs ${_reportData!.summary.debit.toStringAsFixed(2)}',
                        Icons.arrow_upward,
                        Colors.red,
                      ),
                      _buildSummaryCard(
                        'Total Credit',
                        'Rs ${_reportData!.summary.credit.toStringAsFixed(2)}',
                        Icons.arrow_downward,
                        Colors.green,
                      ),
                      _buildSummaryCard(
                        'Closing Balance',
                        'Rs ${_reportData!.summary.closingBalance.toStringAsFixed(2)}',
                        Icons.payments,
                        Colors.purple,
                      ),
                    ],
                  ),
              ],
            ),
          ),

          // Filters Section (below summary cards)
          Container(
            margin: const EdgeInsets.fromLTRB(24, 0, 24, 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                // From Date
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 14,
                            color: Color(0xFF0D1845),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'From Date',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF343A40),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _selectDate(context, true),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Color(0xFFDEE2E6)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _startDate != null
                                      ? DateFormat(
                                          'dd MMM yyyy',
                                        ).format(_startDate!)
                                      : 'Select Date',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _startDate != null
                                        ? Colors.black87
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Color(0xFF6C757D),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // To Date
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.event, size: 14, color: Color(0xFF0D1845)),
                          const SizedBox(width: 6),
                          const Text(
                            'To Date',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF343A40),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: () => _selectDate(context, false),
                        child: Container(
                          height: 36,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Color(0xFFDEE2E6)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  _endDate != null
                                      ? DateFormat(
                                          'dd MMM yyyy',
                                        ).format(_endDate!)
                                      : 'Select Date',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: _endDate != null
                                        ? Colors.black87
                                        : Colors.grey,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.calendar_today,
                                size: 16,
                                color: Color(0xFF6C757D),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Load Button
                Padding(
                  padding: const EdgeInsets.only(top: 22),
                  child: ElevatedButton.icon(
                    onPressed: _isLoading ? null : _loadTransactions,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh, size: 16),
                    label: const Text('Load', style: TextStyle(fontSize: 13)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3498db),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content Area
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              style: TextStyle(color: Colors.red.shade700, fontSize: 16),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTransactions,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_reportData == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.analytics_outlined,
              size: 64,
              color: Colors.grey.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              'Select dates and click "Load" to view transactions',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
            ),
          ],
        ),
      );
    }

    return Container(
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
          // Table Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.receipt_long,
                      size: 18,
                      color: const Color(0xFF0D1845),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Transaction Ledger',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D1845),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${_reportData!.transactions.length} entries',
                        style: TextStyle(
                          fontSize: 10,
                          color: Colors.blue.shade700,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    ElevatedButton.icon(
                      onPressed: _showSummaryDialog,
                      icon: const Icon(Icons.summarize, size: 14),
                      label: const Text(
                        'Summary',
                        style: TextStyle(fontSize: 11),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF27ae60),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _exportToPDF,
                      icon: const Icon(Icons.picture_as_pdf, size: 14),
                      label: const Text(
                        'Export PDF',
                        style: TextStyle(fontSize: 11),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
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

          // Table
          Expanded(
            child: _reportData!.transactions.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 64,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No transaction history found',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try selecting a different date range',
                          style: TextStyle(
                            color: Colors.grey.shade500,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: Container(
                      width: double.infinity,
                      child: DataTable(
                        headingRowColor: MaterialStateProperty.all(
                          const Color(0xFFF8F9FA),
                        ),
                        headingRowHeight: 40,
                        dataRowHeight: 48,
                        columnSpacing: 20,
                        horizontalMargin: 16,
                        columns: [
                          DataColumn(
                            label: Checkbox(
                              value: _selectAll,
                              onChanged: (value) => _toggleSelectAll(),
                              activeColor: const Color(0xFF0D1845),
                            ),
                          ),
                          DataColumn(label: Text('ID', style: _headerStyle())),
                          DataColumn(
                            label: Text('Date', style: _headerStyle()),
                          ),
                          DataColumn(
                            label: Text('Description', style: _headerStyle()),
                          ),
                          DataColumn(
                            label: Text('Debit', style: _headerStyle()),
                          ),
                          DataColumn(
                            label: Text('Credit', style: _headerStyle()),
                          ),
                          DataColumn(
                            label: Text('Balance', style: _headerStyle()),
                            numeric: true,
                          ),
                        ],
                        rows: _paginatedTransactions.map((transaction) {
                          final debitValue =
                              double.tryParse(transaction.debit) ?? 0;
                          final creditValue =
                              double.tryParse(transaction.credit) ?? 0;
                          final isSelected = _selectedTransactions.any(
                            (t) => t.tranId == transaction.tranId,
                          );

                          return DataRow(
                            cells: [
                              DataCell(
                                Checkbox(
                                  value: isSelected,
                                  onChanged: (value) =>
                                      _toggleTransactionSelection(transaction),
                                  activeColor: const Color(0xFF0D1845),
                                ),
                              ),
                              DataCell(
                                Text(
                                  transaction.tranId.toString(),
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF0D1845),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  transaction.date,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: Color(0xFF6c757d),
                                  ),
                                ),
                              ),
                              DataCell(
                                SizedBox(
                                  width: 300,
                                  child: Text(
                                    transaction.description,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Color(0xFF495057),
                                    ),
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  debitValue > 0
                                      ? 'Rs ${debitValue.toStringAsFixed(2)}'
                                      : '-',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: debitValue > 0
                                        ? Colors.red.shade700
                                        : Colors.grey.shade400,
                                    fontWeight: debitValue > 0
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  creditValue > 0
                                      ? 'Rs ${creditValue.toStringAsFixed(2)}'
                                      : '-',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: creditValue > 0
                                        ? Colors.green.shade700
                                        : Colors.grey.shade400,
                                    fontWeight: creditValue > 0
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ),
                              DataCell(
                                Text(
                                  'Rs ${transaction.balance.toStringAsFixed(2)}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF0D1845),
                                  ),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ),
                    ),
                  ),
          ),

          // Pagination Controls
          if (_reportData!.transactions.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(16),
                  bottomRight: Radius.circular(16),
                ),
                border: Border(top: BorderSide(color: Colors.grey.shade200)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Showing ${((_currentPage - 1) * _itemsPerPage) + 1}-${(_currentPage * _itemsPerPage).clamp(0, _reportData!.transactions.length)} of ${_reportData!.transactions.length} transactions',
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                  Row(
                    children: [
                      IconButton(
                        onPressed: _currentPage > 1
                            ? () {
                                setState(() {
                                  _currentPage--;
                                });
                              }
                            : null,
                        icon: const Icon(Icons.chevron_left, size: 20),
                        tooltip: 'Previous Page',
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1845),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Page $_currentPage of $_totalPages',
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: _currentPage < _totalPages
                            ? () {
                                setState(() {
                                  _currentPage++;
                                });
                              }
                            : null,
                        icon: const Icon(Icons.chevron_right, size: 20),
                        tooltip: 'Next Page',
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
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
