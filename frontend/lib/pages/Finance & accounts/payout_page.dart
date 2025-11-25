import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../services/payout_service.dart';
import '../../providers/providers.dart';
import 'add_payment_page.dart';

class PayoutPage extends StatefulWidget {
  const PayoutPage({super.key});

  @override
  State<PayoutPage> createState() => _PayoutPageState();
}

class _PayoutPageState extends State<PayoutPage> {
  List<Payout> _filteredPayouts = [];
  bool _isLoading = true;

  // Pagination
  int currentPage = 1;
  final int itemsPerPage = 10;
  List<Payout> _paginatedPayouts = [];

  // Checkbox selection
  Set<int> _selectedPayoutIds = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _loadPayouts();
  }

  Future<void> _loadPayouts() async {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );

    // Check if payouts are already cached
    if (financeProvider.payouts.isNotEmpty) {
      setState(() {
        _filteredPayouts = financeProvider.payouts;
        _applyPagination();
        _isLoading = false;
      });
      return;
    }

    try {
      setState(() {
        _isLoading = true;
      });

      final payouts = await PayoutService.getAllPayouts();
      financeProvider.setPayouts(payouts);

      setState(() {
        _filteredPayouts = payouts;
        _applyPagination();
        _isLoading = false;
      });
    } catch (e) {
      print('📊 Payout Load Error: $e');

      // Check if it's a 404 "no records" error
      if (e.toString().contains('404') ||
          e.toString().contains('No PayOut records found')) {
        // No records found is a valid state, not an error
        if (mounted) {
          setState(() {
            _filteredPayouts = [];
            _applyPagination();
            _isLoading = false;
          });
        }
      } else {
        // Actual error occurred
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load payouts: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _applyPagination() {
    if (_filteredPayouts.isEmpty) {
      setState(() {
        _paginatedPayouts = [];
      });
      return;
    }

    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;

    if (startIndex >= _filteredPayouts.length) {
      setState(() {
        currentPage = 1;
      });
      _applyPagination();
      return;
    }

    setState(() {
      _paginatedPayouts = _filteredPayouts.sublist(
        startIndex,
        endIndex > _filteredPayouts.length ? _filteredPayouts.length : endIndex,
      );
    });
  }

  void _changePage(int newPage) {
    setState(() {
      currentPage = newPage;
    });
    _applyPagination();
  }

  int _getTotalPages() {
    if (_filteredPayouts.isEmpty) return 1;
    return (_filteredPayouts.length / itemsPerPage).ceil();
  }

  bool _canGoToNextPage() {
    return currentPage < _getTotalPages();
  }

  List<Widget> _buildPageButtons() {
    final totalPages = _getTotalPages();
    final current = currentPage;

    const maxButtons = 5;
    final halfRange = maxButtons ~/ 2;

    int startPage = (current - halfRange).clamp(1, totalPages);
    int endPage = (startPage + maxButtons - 1).clamp(1, totalPages);

    if (endPage > totalPages) {
      endPage = totalPages;
      startPage = (endPage - maxButtons + 1).clamp(1, totalPages);
    }

    List<Widget> buttons = [];

    for (int i = startPage; i <= endPage; i++) {
      buttons.add(
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 1),
          child: ElevatedButton(
            onPressed: i == current ? null : () => _changePage(i),
            style: ElevatedButton.styleFrom(
              backgroundColor: i == current
                  ? const Color(0xFF17A2B8)
                  : Colors.white,
              foregroundColor: i == current
                  ? Colors.white
                  : const Color(0xFF6C757D),
              elevation: i == current ? 2 : 0,
              side: i == current
                  ? null
                  : const BorderSide(color: Color(0xFFDEE2E6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(32, 32),
            ),
            child: Text(
              i.toString(),
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
            ),
          ),
        ),
      );
    }

    return buttons;
  }

  // Export selected payouts to PDF
  Future<void> _exportToPDF() async {
    if (_selectedPayoutIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one payout to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final selectedPayouts = _filteredPayouts
          .where((payout) => _selectedPayoutIds.contains(payout.id))
          .toList();

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

      graphics.drawString(
        'Pay-Out Report',
        titleFont,
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 30),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );

      String filterInfo =
          'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}';
      filterInfo += ' | Selected: ${selectedPayouts.length} payouts';

      graphics.drawString(
        filterInfo,
        smallFont,
        bounds: Rect.fromLTWH(0, 30, page.getClientSize().width, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 5);

      final double pageWidth = page.getClientSize().width;
      final double tableWidth = pageWidth * 0.95;

      grid.columns[0].width = tableWidth * 0.12;
      grid.columns[1].width = tableWidth * 0.30;
      grid.columns[2].width = tableWidth * 0.22;
      grid.columns[3].width = tableWidth * 0.18;
      grid.columns[4].width = tableWidth * 0.18;

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
        font: smallFont,
      );

      final PdfGridRow headerRow = grid.headers.add(1)[0];
      headerRow.cells[0].value = 'Date';
      headerRow.cells[1].value = 'Description';
      headerRow.cells[2].value = 'Category';
      headerRow.cells[3].value = 'Amount';
      headerRow.cells[4].value = 'User';

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

      double totalAmount = 0.0;
      for (final payout in selectedPayouts) {
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = DateFormat(
          'dd MMM yyyy',
        ).format(DateTime.tryParse(payout.date) ?? DateTime.now());
        row.cells[1].value = payout.description;
        row.cells[2].value = payout.transactionType.transType;

        final amount = double.tryParse(payout.amount) ?? 0.0;
        totalAmount += amount;
        row.cells[3].value =
            'Rs. ${NumberFormat('#,##0').format(amount.round())}';
        row.cells[4].value = '${payout.user.firstName} ${payout.user.lastName}';

        for (int i = 0; i < row.cells.count; i++) {
          row.cells[i].style = PdfGridCellStyle(
            format: PdfStringFormat(
              alignment: i == 1 || i == 2
                  ? PdfTextAlignment.left
                  : PdfTextAlignment.center,
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
          page.getClientSize().width,
          page.getClientSize().height - 100,
        ),
      );

      final double yPosition = grid.rows.count * 20 + 80;
      if (yPosition < page.getClientSize().height - 40) {
        graphics.drawString(
          'Total Amount: Rs. ${NumberFormat('#,##0').format(totalAmount.round())}',
          PdfStandardFont(
            PdfFontFamily.helvetica,
            12,
            style: PdfFontStyle.bold,
          ),
          bounds: Rect.fromLTWH(
            page.getClientSize().width - 250,
            yPosition,
            250,
            20,
          ),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
      }

      final List<int> bytes = await document.save();
      document.dispose();

      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/payout_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(path);
      await file.writeAsBytes(bytes);

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF exported successfully to:\n$path'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
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
        title: const Text('Payouts'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
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
            // Header with compact Summary Cards (made denser to match product list style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF0D1845).withOpacity(0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.payments,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Payout Management',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.25,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AddPaymentPage(),
                                      ),
                                    ).then((_) {
                                      // Refresh the payouts list when returning from add payment page
                                      _loadPayouts();
                                    });
                                  },
                                  icon: const Icon(Icons.add, size: 12),
                                  label: const Text(
                                    'Add Payment',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF0D1845),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    elevation: 1,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton.icon(
                                  onPressed: _exportToPDF,
                                  icon: const Icon(
                                    Icons.picture_as_pdf,
                                    size: 12,
                                  ),
                                  label: Text(
                                    'Export PDF${_selectedPayoutIds.isNotEmpty ? ' (${_selectedPayoutIds.length})' : ''}',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF0D1845),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 6,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Track and manage all business payouts',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Compact Summary Cards (denser)
                  Row(
                    children: [
                      _buildSummaryCard(
                        'Total Payouts',
                        '${Provider.of<FinanceProvider>(context, listen: false).payouts.length}',
                        Icons.receipt_long,
                        const Color(0xFFDC3545),
                      ),
                      const SizedBox(width: 6),
                      _buildSummaryCard(
                        'Total Amount',
                        'Rs. ${NumberFormat('#,##0').format(_getTotalPayouts().round())}',
                        Icons.money_off,
                        const Color(0xFFF44336),
                      ),
                      const SizedBox(width: 6),
                      _buildSummaryCard(
                        'This Month',
                        '${_getThisMonthPayouts()}',
                        Icons.calendar_today,
                        const Color(0xFFFF5722),
                      ),
                      const SizedBox(width: 6),
                      _buildSummaryCard(
                        'Avg. Payout',
                        'Rs. ${NumberFormat('#,##0').format(_getAveragePayout().round())}',
                        Icons.trending_down,
                        const Color(0xFF9C27B0),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search and Table
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
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
                    // Search and Filter Bar (Compact)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Search Field
                          Expanded(
                            flex: 3,
                            child: Container(
                              height: 32,
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search payouts...',
                                  hintStyle: TextStyle(
                                    color: Color(0xFFADB5BD),
                                    fontSize: 12,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: Color(0xFF6C757D),
                                    size: 16,
                                  ),
                                  filled: true,
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 0,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide(
                                      color: Color(0xFFDEE2E6),
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide(
                                      color: Color(0xFFDEE2E6),
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide(
                                      color: Color(0xFF0D1845),
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Transaction Type Filter
                          Container(
                            height: 32,
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Color(0xFFDEE2E6)),
                            ),
                            child: DropdownButton<String>(
                              value: 'All Types',
                              underline: SizedBox(),
                              icon: Icon(Icons.arrow_drop_down, size: 18),
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF343A40),
                              ),
                              items: ['All Types', 'Expense', 'Payment'].map((
                                String value,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: value,
                                  child: Text(value),
                                );
                              }).toList(),
                              onChanged: (String? newValue) {
                                // Handle filter change
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Date Filter
                          Container(
                            height: 32,
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: Color(0xFFDEE2E6)),
                            ),
                            child: DropdownButton<String>(
                              value: 'All Time',
                              underline: SizedBox(),
                              icon: Icon(Icons.arrow_drop_down, size: 18),
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF343A40),
                              ),
                              items:
                                  [
                                    'All Time',
                                    'Today',
                                    'This Week',
                                    'This Month',
                                  ].map((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                              onChanged: (String? newValue) {
                                // Handle filter change
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
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
                          SizedBox(
                            width: 40,
                            child: Checkbox(
                              value: _selectAll,
                              onChanged: (value) {
                                setState(() {
                                  _selectAll = value ?? false;
                                  if (_selectAll) {
                                    _selectedPayoutIds = _filteredPayouts
                                        .map((payout) => payout.id)
                                        .toSet();
                                  } else {
                                    _selectedPayoutIds.clear();
                                  }
                                });
                              },
                              activeColor: const Color(0xFF0D1845),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            flex: 1,
                            child: Text('ID', style: _headerStyle()),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Text('Date', style: _headerStyle()),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Text('Description', style: _headerStyle()),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Transaction Type',
                              style: _headerStyle(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Chart of Account',
                              style: _headerStyle(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Text('User', style: _headerStyle()),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: Text('Amount', style: _headerStyle()),
                          ),
                        ],
                      ),
                    ),

                    // Table Body
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _paginatedPayouts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.inbox,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No payouts found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _paginatedPayouts.length,
                              itemBuilder: (context, index) {
                                final payout = _paginatedPayouts[index];

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      SizedBox(
                                        width: 40,
                                        child: Checkbox(
                                          value: _selectedPayoutIds.contains(
                                            payout.id,
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedPayoutIds.add(
                                                  payout.id,
                                                );
                                              } else {
                                                _selectedPayoutIds.remove(
                                                  payout.id,
                                                );
                                                _selectAll = false;
                                              }
                                            });
                                          },
                                          activeColor: const Color(0xFF0D1845),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          payout.id.toString(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF0D1845),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          payout.date,
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          payout.description,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '${payout.transactionType.code} - ${payout.transactionType.transType}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '${payout.coa.code} - ${payout.coa.title}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          payout.user.fullName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          'Rs. ${NumberFormat('#,##0').format(payout.amountAsDouble.round())}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF28A745),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    // Pagination Controls
                    ...(_filteredPayouts.isNotEmpty
                        ? [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
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
                                    onPressed: currentPage > 1
                                        ? () => _changePage(currentPage - 1)
                                        : null,
                                    icon: Icon(Icons.chevron_left, size: 12),
                                    label: Text(
                                      'Previous',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.white,
                                      foregroundColor: currentPage > 1
                                          ? const Color(0xFF0D1845)
                                          : const Color(0xFF6C757D),
                                      elevation: 0,
                                      side: const BorderSide(
                                        color: Color(0xFFDEE2E6),
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),

                                  // Page numbers
                                  ..._buildPageButtons(),

                                  const SizedBox(width: 6),

                                  // Next button
                                  ElevatedButton.icon(
                                    onPressed: _canGoToNextPage()
                                        ? () => _changePage(currentPage + 1)
                                        : null,
                                    icon: Icon(Icons.chevron_right, size: 12),
                                    label: Text(
                                      'Next',
                                      style: TextStyle(fontSize: 10),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: _canGoToNextPage()
                                          ? const Color(0xFF0D1845)
                                          : Colors.grey.shade300,
                                      foregroundColor: _canGoToNextPage()
                                          ? Colors.white
                                          : Colors.grey.shade600,
                                      elevation: _canGoToNextPage() ? 2 : 0,
                                      side: _canGoToNextPage()
                                          ? null
                                          : const BorderSide(
                                              color: Color(0xFFDEE2E6),
                                            ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 4,
                                      ),
                                    ),
                                  ),

                                  // Page info
                                  const SizedBox(width: 12),
                                  Container(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Color(0xFFF8F9FA),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      'Page $currentPage of ${_getTotalPages()} (${_filteredPayouts.length} total)',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Color(0xFF6C757D),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ]
                        : []),
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
      fontWeight: FontWeight.w600,
      color: Color(0xFF343A40),
      fontSize: 12,
    );
  }

  double _getTotalPayouts() {
    return Provider.of<FinanceProvider>(
      context,
      listen: false,
    ).payouts.fold(0.0, (sum, payout) => sum + payout.amountAsDouble);
  }

  int _getThisMonthPayouts() {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    return financeProvider.payouts.where((payout) {
      try {
        final payoutDate = DateTime.parse(payout.date);
        return payoutDate.year == thisMonth.year &&
            payoutDate.month == thisMonth.month;
      } catch (e) {
        return false;
      }
    }).length;
  }

  double _getAveragePayout() {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );
    if (financeProvider.payouts.isEmpty) return 0.0;
    return _getTotalPayouts() / financeProvider.payouts.length;
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
          color: Colors.white.withOpacity(0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withOpacity(0.14)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: color.withOpacity(0.22),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(icon, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white.withOpacity(0.85),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
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
}
