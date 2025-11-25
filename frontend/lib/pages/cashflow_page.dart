import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../services/cashflow_service.dart';
import 'package:provider/provider.dart';
import '../providers/providers.dart';

class CashflowPage extends StatefulWidget {
  const CashflowPage({super.key});

  @override
  State<CashflowPage> createState() => _CashflowPageState();
}

class _CashflowPageState extends State<CashflowPage> {
  bool _isLoading = true;
  String _errorMessage = '';
  int _currentPage = 1;
  final int _itemsPerPage = 13;
  final TextEditingController _searchController = TextEditingController();

  // Date filter
  DateTime? _startDate;
  DateTime? _endDate;

  // Checkbox selection
  Set<int> _selectedCashflowIds = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _loadCashflowData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fetch cashflow data once when page loads
  Future<void> _loadCashflowData() async {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );

    // Check if cashflow data is already cached
    if (financeProvider.cashflow.isNotEmpty) {
      setState(() {
        _applyFiltersClientSide();
        _isLoading = false;
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final response = await CashflowService.getAllCashflow();
      if (response.status) {
        financeProvider.setCashflow(response.data);
        _applyFiltersClientSide();
        setState(() {
          _isLoading = false;
        });
      } else {
        setState(() {
          _errorMessage = response.message;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load cashflow data: $e';
        _isLoading = false;
      });
    }
  }

  List<Cashflow> get _filteredData {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );

    var filtered = financeProvider.cashflow;

    // Apply date filter
    if (_startDate != null || _endDate != null) {
      filtered = filtered.where((item) {
        try {
          final itemDate = DateTime.parse(item.date);
          if (_startDate != null && itemDate.isBefore(_startDate!)) {
            return false;
          }
          if (_endDate != null &&
              itemDate.isAfter(_endDate!.add(Duration(days: 1)))) {
            return false;
          }
          return true;
        } catch (e) {
          return true; // Include items with invalid dates
        }
      }).toList();
    }

    // Apply search filter
    if (_searchController.text.isEmpty) {
      return filtered;
    }
    final query = _searchController.text.toLowerCase();
    return filtered.where((item) {
      return item.description.toLowerCase().contains(query) ||
          item.invRef.toLowerCase().contains(query) ||
          item.coasId.toLowerCase().contains(query);
    }).toList();
  }

  // Client-side filtering method
  void _applyFiltersClientSide() {
    setState(() {
      // Reset to first page when filters change
      _currentPage = 1;
    });
  }

  List<Cashflow> get _paginatedData {
    final filtered = _filteredData;
    final totalPages = (filtered.length / _itemsPerPage).ceil();

    // Reset current page if it's out of bounds
    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = totalPages;
    } else if (totalPages == 0) {
      _currentPage = 1;
    }

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return filtered.sublist(
      startIndex,
      endIndex > filtered.length ? filtered.length : endIndex,
    );
  }

  int get _totalPages {
    final filteredLength = _filteredData.length;
    return filteredLength == 0 ? 0 : (filteredLength / _itemsPerPage).ceil();
  }

  double get _totalDebit {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );
    return financeProvider.cashflow.fold(0.0, (sum, item) {
      final debit = double.tryParse(item.debit) ?? 0.0;
      return sum + debit;
    });
  }

  double get _totalCredit {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );
    return financeProvider.cashflow.fold(0.0, (sum, item) {
      final credit = double.tryParse(item.credit) ?? 0.0;
      return sum + credit;
    });
  }

  double get _balance {
    return _totalDebit - _totalCredit;
  }

  String _formatDate(String dateString) {
    try {
      // Try parsing as ISO 8601 first
      final dateTime = DateTime.parse(dateString);
      return DateFormat('dd/MM/yyyy').format(dateTime);
    } catch (e) {
      // If parsing fails, return the original string
      return dateString;
    }
  }

  // Show date range picker
  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      initialDateRange: _startDate != null && _endDate != null
          ? DateTimeRange(start: _startDate!, end: _endDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF0D1845),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _startDate = picked.start;
        _endDate = picked.end;
        _currentPage = 1; // Reset to first page
      });
    }
  }

  // Clear date filter
  void _clearDateFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _currentPage = 1;
    });
  }

  // Export selected cashflow items to PDF
  Future<void> _exportToPDF() async {
    if (_selectedCashflowIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one transaction to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Filter selected cashflows
      final selectedCashflows = _filteredData
          .where((cashflow) => _selectedCashflowIds.contains(cashflow.id))
          .toList();

      // Create PDF document
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
        10,
        style: PdfFontStyle.bold,
      );
      final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 9);

      final PdfPage page = document.pages.add();
      final PdfGraphics graphics = page.graphics;

      // Draw title
      graphics.drawString(
        'Cashflow Report',
        titleFont,
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 30),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );

      // Draw generation info
      String filterInfo =
          'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}';
      filterInfo += ' | Selected: ${selectedCashflows.length} transactions';
      if (_startDate != null) {
        filterInfo +=
            ' | From: ${DateFormat('dd MMM yyyy').format(_startDate!)}';
      }
      if (_endDate != null) {
        filterInfo += ' | To: ${DateFormat('dd MMM yyyy').format(_endDate!)}';
      }

      graphics.drawString(
        filterInfo,
        smallFont,
        bounds: Rect.fromLTWH(0, 30, page.getClientSize().width, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // Create table
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 6);

      final double pageWidth = page.getClientSize().width;
      final double tableWidth = pageWidth * 0.95;

      grid.columns[0].width = tableWidth * 0.12; // Date
      grid.columns[1].width = tableWidth * 0.15; // Invoice Ref
      grid.columns[2].width = tableWidth * 0.12; // COA ID
      grid.columns[3].width = tableWidth * 0.35; // Description
      grid.columns[4].width = tableWidth * 0.13; // Debit
      grid.columns[5].width = tableWidth * 0.13; // Credit

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
        font: smallFont,
      );

      // Add header row
      final PdfGridRow headerRow = grid.headers.add(1)[0];
      headerRow.cells[0].value = 'Date';
      headerRow.cells[1].value = 'Invoice Ref';
      headerRow.cells[2].value = 'COA ID';
      headerRow.cells[3].value = 'Description';
      headerRow.cells[4].value = 'Debit';
      headerRow.cells[5].value = 'Credit';

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

      // Add data rows
      double totalDebit = 0.0;
      double totalCredit = 0.0;
      for (final cashflow in selectedCashflows) {
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = _formatDate(cashflow.date);
        row.cells[1].value = cashflow.invRef.isNotEmpty
            ? cashflow.invRef
            : 'N/A';
        row.cells[2].value = cashflow.coasId.isNotEmpty
            ? cashflow.coasId
            : 'N/A';
        row.cells[3].value = cashflow.description.isNotEmpty
            ? cashflow.description
            : 'N/A';

        final debit = double.tryParse(cashflow.debit) ?? 0.0;
        final credit = double.tryParse(cashflow.credit) ?? 0.0;
        totalDebit += debit;
        totalCredit += credit;

        row.cells[4].value = 'Rs. ${NumberFormat('#,##0.00').format(debit)}';
        row.cells[5].value = 'Rs. ${NumberFormat('#,##0.00').format(credit)}';

        // Align cells
        for (int i = 0; i < row.cells.count; i++) {
          row.cells[i].style = PdfGridCellStyle(
            format: PdfStringFormat(
              alignment: i == 3
                  ? PdfTextAlignment.left
                  : PdfTextAlignment.center,
              lineAlignment: PdfVerticalAlignment.middle,
            ),
          );
        }
      }

      // Draw grid
      grid.draw(
        page: page,
        bounds: Rect.fromLTWH(
          0,
          60,
          page.getClientSize().width,
          page.getClientSize().height - 120,
        ),
      );

      // Add totals at the bottom
      final double yPosition = grid.rows.count * 20 + 80;
      if (yPosition < page.getClientSize().height - 60) {
        final balance = totalDebit - totalCredit;
        graphics.drawString(
          'Total Debit: Rs. ${NumberFormat('#,##0.00').format(totalDebit)}  |  Total Credit: Rs. ${NumberFormat('#,##0.00').format(totalCredit)}  |  Balance: Rs. ${NumberFormat('#,##0.00').format(balance)}',
          PdfStandardFont(
            PdfFontFamily.helvetica,
            11,
            style: PdfFontStyle.bold,
          ),
          bounds: Rect.fromLTWH(0, yPosition, page.getClientSize().width, 20),
          format: PdfStringFormat(alignment: PdfTextAlignment.center),
        );
      }

      // Save the document
      final List<int> bytes = await document.save();
      document.dispose();

      // Get directory and save file
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/cashflow_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(path);
      await file.writeAsBytes(bytes);

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF exported successfully to:\n$path'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Cashflow'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _exportToPDF,
              icon: const Icon(
                Icons.picture_as_pdf,
                color: Colors.white,
                size: 20,
              ),
              label: Text(
                'Export PDF${_selectedCashflowIds.isNotEmpty ? ' (${_selectedCashflowIds.length})' : ''}',
                style: const TextStyle(color: Colors.white, fontSize: 13),
              ),
              style: TextButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
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
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.account_balance_wallet,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cashflow Management',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Track and monitor cashflow transactions',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  // Summary Cards
                  Row(
                    children: [
                      _buildSummaryCard(
                        'Total Debit',
                        'Rs. ${NumberFormat('#,##0.00').format(_totalDebit)}',
                        Icons.arrow_upward,
                        const Color(0xFF4CAF50),
                      ),
                      _buildSummaryCard(
                        'Total Credit',
                        'Rs. ${NumberFormat('#,##0.00').format(_totalCredit)}',
                        Icons.arrow_downward,
                        const Color(0xFFF44336),
                      ),
                      _buildSummaryCard(
                        'Balance',
                        'Rs. ${NumberFormat('#,##0.00').format(_balance)}',
                        Icons.account_balance,
                        _balance >= 0
                            ? const Color(0xFF2196F3)
                            : const Color(0xFFFF9800),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search and Table
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
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
                    // Filters Section
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 3,
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
                                        size: 14,
                                        color: Color(0xFF0D1845),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Search Transactions',
                                        style: TextStyle(
                                          fontSize: 12,
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
                                      filled: true,
                                      fillColor: Colors.white,
                                      hintText:
                                          'Search by description, invoice ref, or COA...',
                                      hintStyle: TextStyle(
                                        color: Color(0xFFADB5BD),
                                        fontSize: 13,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        color: Color(0xFF0D1845),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Color(0xFFDEE2E6),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Color(0xFFDEE2E6),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Color(0xFF0D1845),
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                    ),
                                    onChanged: (value) {
                                      setState(() {
                                        _currentPage =
                                            1; // Reset to first page on search
                                      });
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Date Filter
                          Expanded(
                            flex: 2,
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
                                        size: 14,
                                        color: Color(0xFF0D1845),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Date Range',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF343A40),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Row(
                                  children: [
                                    Expanded(
                                      child: InkWell(
                                        onTap: _selectDateRange,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Color(0xFFDEE2E6),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.05,
                                                ),
                                                blurRadius: 4,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  _startDate != null &&
                                                          _endDate != null
                                                      ? '${DateFormat('dd/MM/yy').format(_startDate!)} - ${DateFormat('dd/MM/yy').format(_endDate!)}'
                                                      : 'All Dates',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: _startDate != null
                                                        ? Colors.black87
                                                        : Color(0xFFADB5BD),
                                                  ),
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Icon(
                                                Icons.calendar_today,
                                                color: Color(0xFF6C757D),
                                                size: 16,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (_startDate != null || _endDate != null)
                                      IconButton(
                                        onPressed: _clearDateFilter,
                                        icon: Icon(
                                          Icons.clear,
                                          size: 20,
                                          color: Colors.red,
                                        ),
                                        tooltip: 'Clear Date Filter',
                                        padding: EdgeInsets.all(4),
                                        constraints: BoxConstraints(),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 45,
                            child: Checkbox(
                              value: _selectAll,
                              onChanged: (value) {
                                setState(() {
                                  _selectAll = value ?? false;
                                  if (_selectAll) {
                                    _selectedCashflowIds = _paginatedData
                                        .map((item) => item.id)
                                        .toSet();
                                  } else {
                                    _selectedCashflowIds.clear();
                                  }
                                });
                              },
                              activeColor: const Color(0xFF0D1845),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Text('Date', style: _headerStyle()),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Text('Invoice Ref', style: _headerStyle()),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Text('COA ID', style: _headerStyle()),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Text('Description', style: _headerStyle()),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Text('Debit', style: _headerStyle()),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Text('Credit', style: _headerStyle()),
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
                                  const Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _errorMessage,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _loadCashflowData,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _paginatedData.isEmpty
                          ? const Center(
                              child: Text(
                                'No cashflow data found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _paginatedData.length,
                              itemBuilder: (context, index) {
                                final item = _paginatedData[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 45,
                                        child: Checkbox(
                                          value: _selectedCashflowIds.contains(
                                            item.id,
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedCashflowIds.add(
                                                  item.id,
                                                );
                                              } else {
                                                _selectedCashflowIds.remove(
                                                  item.id,
                                                );
                                              }
                                            });
                                          },
                                          activeColor: const Color(0xFF0D1845),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          _formatDate(item.date),
                                          style: _cellStyle(),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item.invRef.isNotEmpty
                                              ? item.invRef
                                              : 'N/A',
                                          style: _cellStyle(),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          item.coasId.isNotEmpty
                                              ? item.coasId
                                              : 'N/A',
                                          style: _cellStyle(),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          item.description.isNotEmpty
                                              ? item.description
                                              : 'N/A',
                                          style: _cellStyle(),
                                          overflow: TextOverflow.ellipsis,
                                          maxLines: 2,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Rs. ${NumberFormat('#,##0.00').format(double.tryParse(item.debit) ?? 0.0)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.green[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Rs. ${NumberFormat('#,##0.00').format(double.tryParse(item.credit) ?? 0.0)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.red[700],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    // Enhanced Pagination
                    const SizedBox(height: 20),
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
                            onPressed: (_currentPage > 1 && _totalPages > 0)
                                ? () => setState(() => _currentPage--)
                                : null,
                            icon: Icon(Icons.chevron_left, size: 14),
                            label: Text(
                              'Previous',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor:
                                  (_currentPage > 1 && _totalPages > 0)
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
                            onPressed:
                                (_currentPage < _totalPages && _totalPages > 0)
                                ? () => setState(() => _currentPage++)
                                : null,
                            icon: Icon(Icons.chevron_right, size: 14),
                            label: Text('Next', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  (_currentPage < _totalPages &&
                                      _totalPages > 0)
                                  ? Color(0xFF17A2B8)
                                  : Colors.grey.shade300,
                              foregroundColor:
                                  (_currentPage < _totalPages &&
                                      _totalPages > 0)
                                  ? Colors.white
                                  : Colors.grey.shade600,
                              elevation:
                                  (_currentPage < _totalPages &&
                                      _totalPages > 0)
                                  ? 2
                                  : 0,
                              side:
                                  (_currentPage < _totalPages &&
                                      _totalPages > 0)
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
                              _totalPages == 0
                                  ? 'No data'
                                  : 'Page $_currentPage of $_totalPages (${_filteredData.length} total)',
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
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 11,
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
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: Color(0xFF343A40),
    );
  }

  TextStyle _cellStyle() {
    return const TextStyle(fontSize: 12, color: Color(0xFF6C757D));
  }

  List<Widget> _buildPageButtons() {
    final totalPages = _totalPages;
    final current = _currentPage;

    // If no pages, return empty list
    if (totalPages == 0) {
      return [];
    }

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
            onPressed: i == current
                ? null
                : () => setState(() => _currentPage = i),
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
}
