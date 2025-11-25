import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../services/income_services.dart';
import '../../providers/providers.dart';
import 'add_income_page.dart';

class PayInPage extends StatefulWidget {
  const PayInPage({super.key});

  @override
  State<PayInPage> createState() => _PayInPageState();
}

class _PayInPageState extends State<PayInPage> {
  // API data
  List<PayIn> _filteredPayIns = [];
  List<PayIn> _allFilteredPayIns = [];
  bool _isLoading = true;
  String? _errorMessage;
  int currentPage = 1;
  final int itemsPerPage = 10;

  // Filter states
  String _selectedCategory = 'All';
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Date filter states
  DateTime? _startDate;
  DateTime? _endDate;
  String _dateFilter =
      'All'; // 'All', 'Today', 'This Week', 'This Month', 'Custom'

  // Checkbox selection
  Set<int> _selectedPayInIds = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _fetchAllPayInsOnInit();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // Fetch all payins once when page loads
  Future<void> _fetchAllPayInsOnInit() async {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );

    // Check if payins are already cached
    if (financeProvider.payIns.isNotEmpty) {
      setState(() {
        _applyFiltersClientSide();
      });
      return;
    }

    try {
      setState(() {
        _errorMessage = null;
      });

      final response = await IncomeService.getPayIns();
      financeProvider.setPayIns(response.data);

      // Apply initial filters
      _applyFiltersClientSide();
    } catch (e) {
      print('📊 PayIn Load Error: $e');

      // Check if it's a 404 "no records" error
      if (e.toString().contains('404') ||
          e.toString().contains('No PayIn records found')) {
        // No records found is a valid state, not an error
        if (mounted) {
          setState(() {
            _errorMessage = null;
            _isLoading = false;
            _filteredPayIns = [];
            _allFilteredPayIns = [];
          });
        }
      } else {
        // Actual error occurred
        if (mounted) {
          setState(() {
            _errorMessage = 'Failed to load pay-ins. Please refresh the page.';
            _isLoading = false;
          });
        }
      }
    }
  }

  // Client-side only filter application
  void _applyFilters() {
    _applyFiltersClientSide();
  }

  // Pure client-side filtering method
  void _applyFiltersClientSide() {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );

    try {
      final searchLower = _searchQuery.toLowerCase().trim();

      // Apply filters to cached payins
      _allFilteredPayIns = financeProvider.payIns.where((payIn) {
        try {
          // Category filter based on COA title
          if (_selectedCategory != 'All' &&
              payIn.coa.title != _selectedCategory) {
            return false;
          }

          // Search filter - search in description, amount, COA title
          if (searchLower.isNotEmpty) {
            final description = payIn.description.toLowerCase();
            final amount = payIn.amount.toString().toLowerCase();
            final coaTitle = payIn.coa.title.toLowerCase();

            if (!description.contains(searchLower) &&
                !amount.contains(searchLower) &&
                !coaTitle.contains(searchLower)) {
              return false;
            }
          }

          // Date filter
          if (_dateFilter != 'All') {
            final payInDate = DateTime.tryParse(payIn.date);
            if (payInDate == null) return false;

            if (_dateFilter == 'Today') {
              final today = DateTime.now();
              if (payInDate.year != today.year ||
                  payInDate.month != today.month ||
                  payInDate.day != today.day) {
                return false;
              }
            } else if (_dateFilter == 'This Week') {
              final now = DateTime.now();
              final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
              final endOfWeek = startOfWeek.add(const Duration(days: 6));
              if (payInDate.isBefore(startOfWeek) ||
                  payInDate.isAfter(endOfWeek)) {
                return false;
              }
            } else if (_dateFilter == 'This Month') {
              final now = DateTime.now();
              if (payInDate.year != now.year || payInDate.month != now.month) {
                return false;
              }
            } else if (_dateFilter == 'Custom') {
              if (_startDate != null && payInDate.isBefore(_startDate!)) {
                return false;
              }
              if (_endDate != null && payInDate.isAfter(_endDate!)) {
                return false;
              }
            }
          }

          return true;
        } catch (e) {
          return false;
        }
      }).toList();

      // Apply local pagination to filtered results
      _paginateFilteredPayIns();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search error: Please try a different search term';
        _isLoading = false;
        _filteredPayIns = [];
      });
    }
  }

  // Apply local pagination to filtered payins
  void _paginateFilteredPayIns() {
    try {
      if (_allFilteredPayIns.isEmpty) {
        setState(() {
          _filteredPayIns = [];
        });
        return;
      }

      final startIndex = (currentPage - 1) * itemsPerPage;
      final endIndex = startIndex + itemsPerPage;

      if (startIndex >= _allFilteredPayIns.length) {
        setState(() {
          currentPage = 1;
        });
        _paginateFilteredPayIns();
        return;
      }

      setState(() {
        _filteredPayIns = _allFilteredPayIns.sublist(
          startIndex,
          endIndex > _allFilteredPayIns.length
              ? _allFilteredPayIns.length
              : endIndex,
        );
      });
    } catch (e) {
      setState(() {
        _filteredPayIns = [];
        currentPage = 1;
      });
    }
  }

  // Handle page changes
  Future<void> _changePage(int newPage) async {
    setState(() {
      currentPage = newPage;
    });
    _paginateFilteredPayIns();
  }

  // Show custom date picker dialog
  Future<void> _showCustomDatePicker() async {
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
        _dateFilter = 'Custom';
        currentPage = 1;
      });
      _applyFilters();
    }
  }

  bool _canGoToNextPage() {
    final totalPages = _getTotalPages();
    return currentPage < totalPages;
  }

  int _getTotalPages() {
    if (_allFilteredPayIns.isEmpty) return 1;
    return (_allFilteredPayIns.length / itemsPerPage).ceil();
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
          margin: EdgeInsets.symmetric(horizontal: 1),
          child: ElevatedButton(
            onPressed: i == current ? null : () => _changePage(i),
            style: ElevatedButton.styleFrom(
              backgroundColor: i == current ? Color(0xFF17A2B8) : Colors.white,
              foregroundColor: i == current ? Colors.white : Color(0xFF6C757D),
              elevation: i == current ? 2 : 0,
              side: i == current ? null : BorderSide(color: Color(0xFFDEE2E6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(28, 28),
            ),
            child: Text(
              i.toString(),
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 10),
            ),
          ),
        ),
      );
    }

    return buttons;
  }

  double _getTotalPayIns() {
    return _allFilteredPayIns.fold(
      0.0,
      (sum, payIn) => sum + payIn.amountValue,
    );
  }

  // Export selected pay-ins to PDF
  Future<void> _exportToPDF() async {
    if (_selectedPayInIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one pay-in to export'),
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

      // Filter selected pay-ins
      final selectedPayIns = _allFilteredPayIns
          .where((payIn) => _selectedPayInIds.contains(payIn.id))
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
        'Pay-In Report',
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
      filterInfo += ' | Selected: ${selectedPayIns.length} pay-ins';

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

      grid.columns[0].width = tableWidth * 0.10; // Date
      grid.columns[1].width = tableWidth * 0.20; // Narration
      grid.columns[2].width = tableWidth * 0.25; // Description
      grid.columns[3].width = tableWidth * 0.20; // Category
      grid.columns[4].width = tableWidth * 0.15; // Amount
      grid.columns[5].width = tableWidth * 0.10; // User

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
        font: smallFont,
      );

      // Add header row
      final PdfGridRow headerRow = grid.headers.add(1)[0];
      headerRow.cells[0].value = 'Date';
      headerRow.cells[1].value = 'Narration';
      headerRow.cells[2].value = 'Description';
      headerRow.cells[3].value = 'Category';
      headerRow.cells[4].value = 'Amount';
      headerRow.cells[5].value = 'User';

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
      double totalAmount = 0.0;
      for (final payIn in selectedPayIns) {
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = DateFormat(
          'dd MMM yyyy',
        ).format(DateTime.tryParse(payIn.date) ?? DateTime.now());
        row.cells[1].value = payIn.naration;
        row.cells[2].value = payIn.description;
        row.cells[3].value = payIn.transactionType.transType;

        totalAmount += payIn.amountValue;
        row.cells[4].value =
            'Rs. ${NumberFormat('#,##0').format(payIn.amountValue.round())}';
        row.cells[5].value = '${payIn.user.firstName} ${payIn.user.lastName}';

        // Align cells
        for (int i = 0; i < row.cells.count; i++) {
          row.cells[i].style = PdfGridCellStyle(
            format: PdfStringFormat(
              alignment: i == 1 || i == 2 || i == 3
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
          page.getClientSize().height - 100,
        ),
      );

      // Add total at the bottom
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

      // Save the document
      final List<int> bytes = await document.save();
      document.dispose();

      // Get directory and save file
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/payin_report_${DateTime.now().millisecondsSinceEpoch}.pdf';
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
        title: const Text('Pay-Ins'),
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
            // Header with compact Summary Cards (denser, product-list style)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                          Icons.trending_up,
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
                                    'Pay-In Management',
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
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AddIncomePage(),
                                      ),
                                    );
                                    if (result == true) {
                                      // Refresh the payins list
                                      _fetchAllPayInsOnInit();
                                    }
                                  },
                                  icon: const Icon(Icons.add, size: 12),
                                  label: const Text(
                                    'Add Income',
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
                                    'Export PDF${_selectedPayInIds.isNotEmpty ? ' (${_selectedPayInIds.length})' : ''}',
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
                              'Track and manage all business pay-ins',
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
                  // Compact Summary Cards row
                  Row(
                    children: [
                      _buildSummaryCard(
                        'Total Pay-Ins',
                        '${Provider.of<FinanceProvider>(context, listen: false).payIns.length}',
                        Icons.receipt,
                        const Color(0xFF4CAF50),
                      ),
                      const SizedBox(width: 6),
                      _buildSummaryCard(
                        'Total Amount',
                        'Rs. ${NumberFormat('#,##0').format(_getTotalPayIns().round())}',
                        Icons.attach_money,
                        const Color(0xFF2196F3),
                      ),
                      const SizedBox(width: 6),
                      _buildSummaryCard(
                        'This Month',
                        '${_getThisMonthPayIns()}',
                        Icons.calendar_today,
                        const Color(0xFF8BC34A),
                      ),
                      const SizedBox(width: 6),
                      _buildSummaryCard(
                        'Avg. Pay-In',
                        'Rs. ${NumberFormat('#,##0').format(_getAveragePayIn().round())}',
                        Icons.trending_up,
                        const Color(0xFFFF9800),
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
                    // Filters Section (compact - all in one line)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
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
                          // Search Field
                          Expanded(
                            flex: 3,
                            child: Container(
                              height: 32,
                              child: TextField(
                                controller: _searchController,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText: 'Search by description, amount...',
                                  hintStyle: TextStyle(
                                    color: Color(0xFFADB5BD),
                                    fontSize: 12,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    size: 16,
                                    color: Color(0xFF6C757D),
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
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 0,
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    _searchQuery = value;
                                    currentPage = 1;
                                  });
                                  _applyFilters();
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Date Filter
                          Container(
                            height: 32,
                            width: 160,
                            child: DropdownButtonFormField<String>(
                              value: _dateFilter,
                              decoration: InputDecoration(
                                filled: true,
                                fillColor: Colors.white,
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
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                              ),
                              items:
                                  [
                                    'All',
                                    'Today',
                                    'This Week',
                                    'This Month',
                                    'Custom',
                                  ].map((filter) {
                                    return DropdownMenuItem(
                                      value: filter,
                                      child: Row(
                                        children: [
                                          Icon(
                                            filter == 'All'
                                                ? Icons.all_inclusive
                                                : filter == 'Today'
                                                ? Icons.today
                                                : filter == 'Custom'
                                                ? Icons.date_range
                                                : Icons.calendar_month,
                                            size: 14,
                                            color: Color(0xFF0D1845),
                                          ),
                                          SizedBox(width: 6),
                                          Text(
                                            filter,
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF343A40),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                              onChanged: (value) async {
                                if (value == 'Custom') {
                                  await _showCustomDatePicker();
                                } else {
                                  setState(() {
                                    _dateFilter = value!;
                                    currentPage = 1;
                                  });
                                  _applyFilters();
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 8),
                          // COA Category Filter
                          Expanded(
                            flex: 2,
                            child: Container(
                              height: 32,
                              child: DropdownButtonFormField<String>(
                                value: _selectedCategory,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText: 'Select COA',
                                  hintStyle: TextStyle(
                                    color: Color(0xFFADB5BD),
                                    fontSize: 12,
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
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 0,
                                  ),
                                ),
                                items:
                                    [
                                          'All',
                                          ...Provider.of<FinanceProvider>(
                                                context,
                                                listen: false,
                                              ).payIns
                                              .map((payIn) => payIn.coa.title)
                                              .toSet()
                                              .toList(),
                                        ]
                                        .map(
                                          (category) => DropdownMenuItem(
                                            value: category,
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  category == 'All'
                                                      ? Icons
                                                            .inventory_2_rounded
                                                      : Icons.category,
                                                  color: category == 'All'
                                                      ? Color(0xFF6C757D)
                                                      : Color(0xFF0D1845),
                                                  size: 14,
                                                ),
                                                SizedBox(width: 6),
                                                Flexible(
                                                  child: Text(
                                                    category,
                                                    style: TextStyle(
                                                      color: Color(0xFF343A40),
                                                      fontSize: 12,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
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
                                      currentPage = 1;
                                    });
                                    _applyFilters();
                                  }
                                },
                              ),
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
                                    _selectedPayInIds = _allFilteredPayIns
                                        .map((payIn) => payIn.id)
                                        .toSet();
                                  } else {
                                    _selectedPayInIds.clear();
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
                            child: Text('COA', style: _headerStyle()),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Text('Amount', style: _headerStyle()),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 5,
                            child: Text('Description', style: _headerStyle()),
                          ),
                        ],
                      ),
                    ),

                    // Table Body
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _errorMessage != null
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
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _fetchAllPayInsOnInit,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _filteredPayIns.isEmpty
                          ? const Center(
                              child: Text(
                                'No pay-ins found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredPayIns.length,
                              itemBuilder: (context, index) {
                                final payIn = _filteredPayIns[index];
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
                                          value: _selectedPayInIds.contains(
                                            payIn.id,
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedPayInIds.add(payIn.id);
                                              } else {
                                                _selectedPayInIds.remove(
                                                  payIn.id,
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
                                          payIn.id.toString(),
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
                                          DateFormat(
                                            'dd MMM yyyy',
                                          ).format(DateTime.parse(payIn.date)),
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          '${payIn.coa.code} ${payIn.coa.title}',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Rs. ${NumberFormat('#,##0').format(payIn.amountValue.round())}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF28A745),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 5,
                                        child: Text(
                                          payIn.description,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(fontSize: 11),
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    // Pagination Controls
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 8,
                        horizontal: 16,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Previous button
                          ElevatedButton.icon(
                            onPressed: currentPage > 1
                                ? () {
                                    setState(() {
                                      currentPage--;
                                      _paginateFilteredPayIns();
                                    });
                                  }
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
                              side: const BorderSide(color: Color(0xFFDEE2E6)),
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
                                ? () {
                                    setState(() {
                                      currentPage++;
                                      _paginateFilteredPayIns();
                                    });
                                  }
                                : null,
                            icon: Icon(Icons.chevron_right, size: 12),
                            label: Text('Next', style: TextStyle(fontSize: 10)),
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
                                  : const BorderSide(color: Color(0xFFDEE2E6)),
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
                              'Page $currentPage of ${_getTotalPages()} (${_allFilteredPayIns.length} total)',
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
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  int _getThisMonthPayIns() {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    return financeProvider.payIns.where((payIn) {
      try {
        final payInDate = DateTime.parse(payIn.date);
        return payInDate.year == thisMonth.year &&
            payInDate.month == thisMonth.month;
      } catch (e) {
        return false;
      }
    }).length;
  }

  double _getAveragePayIn() {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );
    if (financeProvider.payIns.isEmpty) return 0.0;
    return _getTotalPayIns() / financeProvider.payIns.length;
  }

  TextStyle _headerStyle() {
    return const TextStyle(
      fontWeight: FontWeight.w600,
      color: Color(0xFF343A40),
      fontSize: 12,
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
