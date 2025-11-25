import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import '../../services/account_statement_service.dart';

class AccountStatementPage extends StatefulWidget {
  const AccountStatementPage({super.key});

  @override
  State<AccountStatementPage> createState() => _AccountStatementPageState();
}

class _AccountStatementPageState extends State<AccountStatementPage> {
  // Using the /accountStatementList API which returns a list of accounts
  List<AccountListItem> _accounts = [];
  List<AccountListItem> _filteredAccounts = [];
  bool _isLoading = true;
  String? _errorMessage;

  // Filter states
  String _selectedMain = 'All';
  String _selectedSub = 'All';
  String _selectedTitle = 'All';

  // Pagination
  int _currentPage = 1;
  final int _itemsPerPage = 13;

  // Checkbox selection
  Set<int> _selectedAccountIds = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _fetchAccountListOnInit();
  }

  Future<void> _fetchAccountListOnInit() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final accounts = await AccountStatementService.getAccountStatementList();

      // Optionally cache in provider if desired (provider may have different field)
      // final financeProvider = Provider.of<FinanceProvider>(context, listen: false);
      // financeProvider.setAccountList(accounts);

      setState(() {
        _accounts = accounts;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load accounts: $e';
        _isLoading = false;
      });
    }
  }

  // Apply filters to accounts
  void _applyFilters() {
    _filteredAccounts = _accounts.where((account) {
      // Filter by Main category
      if (_selectedMain != 'All') {
        final mainTitle = account.main?['title']?.toString() ?? '';
        if (mainTitle != _selectedMain) return false;
      }

      // Filter by Sub category
      if (_selectedSub != 'All') {
        final subTitle = account.sub?['title']?.toString() ?? '';
        if (subTitle != _selectedSub) return false;
      }

      // Filter by Title
      if (_selectedTitle != 'All') {
        if (account.title != _selectedTitle) return false;
      }

      return true;
    }).toList();

    // Reset to first page when filters change
    _currentPage = 1;
  }

  // Pagination helpers
  List<AccountListItem> get _paginatedData {
    final totalPages = _totalPages;

    // Reset current page if it's out of bounds
    if (_currentPage > totalPages && totalPages > 0) {
      _currentPage = totalPages;
    } else if (totalPages == 0) {
      _currentPage = 1;
    }

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return _filteredAccounts.sublist(
      startIndex,
      endIndex > _filteredAccounts.length ? _filteredAccounts.length : endIndex,
    );
  }

  int get _totalPages {
    final filteredLength = _filteredAccounts.length;
    return filteredLength == 0 ? 0 : (filteredLength / _itemsPerPage).ceil();
  }

  // Show title selection dialog
  Future<void> _showTitleSelectionDialog(BuildContext parentContext) async {
    await _showSelectionDialog(
      parentContext,
      'Select Title',
      Icons.title,
      _getTitles(),
      _selectedTitle,
      (selected) {
        setState(() {
          _selectedTitle = selected;
          // Auto-populate Sub and Main based on selected Title
          if (selected != 'All') {
            final selectedAccount = _accounts.firstWhere(
              (account) => account.title == selected,
              orElse: () => _accounts.first,
            );
            _selectedSub = selectedAccount.sub?['title']?.toString() ?? 'All';
            _selectedMain = selectedAccount.main?['title']?.toString() ?? 'All';
          }
          _applyFilters();
        });
      },
    );
  }

  // Show main category selection dialog
  Future<void> _showMainCategorySelectionDialog(
    BuildContext parentContext,
  ) async {
    await _showSelectionDialog(
      parentContext,
      'Select Main Category',
      Icons.category,
      _getMainCategories(),
      _selectedMain,
      (selected) {
        setState(() {
          _selectedMain = selected;
          _applyFilters();
        });
      },
    );
  }

  // Show sub category selection dialog
  Future<void> _showSubCategorySelectionDialog(
    BuildContext parentContext,
  ) async {
    await _showSelectionDialog(
      parentContext,
      'Select Sub Category',
      Icons.subdirectory_arrow_right,
      _getSubCategories(),
      _selectedSub,
      (selected) {
        setState(() {
          _selectedSub = selected;
          _applyFilters();
        });
      },
    );
  }

  // Generic selection dialog
  Future<void> _showSelectionDialog(
    BuildContext parentContext,
    String title,
    IconData icon,
    List<String> items,
    String selectedItem,
    Function(String) onSelect,
  ) async {
    final searchController = TextEditingController();
    List<String> filteredItems = items;

    await showDialog(
      context: parentContext,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          void filterItems(String query) {
            setState(() {
              if (query.isEmpty) {
                filteredItems = items;
              } else {
                filteredItems = items
                    .where(
                      (item) =>
                          item.toLowerCase().contains(query.toLowerCase()),
                    )
                    .toList();
              }
            });
          }

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              width: MediaQuery.of(context).size.width * 0.4,
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1845).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(icon, color: Color(0xFF0D1845), size: 24),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: Colors.black87,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Search Field
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade200),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.03),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: searchController,
                      decoration: InputDecoration(
                        hintText: 'Search...',
                        prefixIcon: const Icon(
                          Icons.search,
                          color: Color(0xFF0D1845),
                          size: 20,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                      onChanged: filterItems,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Items List
                  Flexible(
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 400),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 4,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: filteredItems.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.search_off,
                                      size: 48,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No items found',
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge
                                          ?.copyWith(
                                            color: Colors.grey.shade600,
                                          ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: filteredItems.length,
                              itemBuilder: (context, index) {
                                final item = filteredItems[index];
                                final isSelected = item == selectedItem;

                                return InkWell(
                                  onTap: () {
                                    onSelect(item);
                                    Navigator.of(context).pop();
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                    decoration: BoxDecoration(
                                      color: isSelected
                                          ? const Color(
                                              0xFF0D1845,
                                            ).withOpacity(0.1)
                                          : Colors.transparent,
                                      border: index < filteredItems.length - 1
                                          ? Border(
                                              bottom: BorderSide(
                                                color: Colors.grey.shade100,
                                              ),
                                            )
                                          : null,
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            item,
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium
                                                ?.copyWith(
                                                  fontWeight: FontWeight.w500,
                                                  color: isSelected
                                                      ? const Color(0xFF0D1845)
                                                      : Colors.black87,
                                                ),
                                          ),
                                        ),
                                        if (isSelected)
                                          const Icon(
                                            Icons.check_circle,
                                            color: Color(0xFF0D1845),
                                            size: 20,
                                          ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Close Button
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // Get unique main categories
  List<String> _getMainCategories() {
    final mains = _accounts
        .map((a) => a.main?['title']?.toString() ?? '')
        .where((m) => m.isNotEmpty)
        .toSet()
        .toList();
    mains.sort();
    return ['All', ...mains];
  }

  // Get unique sub categories
  List<String> _getSubCategories() {
    final subs = _accounts
        .map((a) => a.sub?['title']?.toString() ?? '')
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    subs.sort();
    return ['All', ...subs];
  }

  // Get unique titles
  List<String> _getTitles() {
    final titles = _accounts
        .map((a) => a.title)
        .where((t) => t.isNotEmpty)
        .toSet()
        .toList();
    titles.sort();
    return ['All', ...titles];
  }

  // Export selected accounts to PDF
  Future<void> _exportToPDF() async {
    if (_selectedAccountIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one account to export'),
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

      // Filter selected accounts
      final selectedAccounts = _filteredAccounts
          .where((account) => _selectedAccountIds.contains(account.id))
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
        'Account Statement Report',
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
      filterInfo += ' | Selected: ${selectedAccounts.length} accounts';

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

      grid.columns[0].width = tableWidth * 0.08; // ID
      grid.columns[1].width = tableWidth * 0.12; // Code
      grid.columns[2].width = tableWidth * 0.22; // Title
      grid.columns[3].width = tableWidth * 0.18; // Sub Head
      grid.columns[4].width = tableWidth * 0.18; // Main Head
      grid.columns[5].width = tableWidth * 0.22; // Balance

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
        font: smallFont,
      );

      // Add header row
      final PdfGridRow headerRow = grid.headers.add(1)[0];
      headerRow.cells[0].value = 'ID';
      headerRow.cells[1].value = 'Code';
      headerRow.cells[2].value = 'Title';
      headerRow.cells[3].value = 'Sub Head';
      headerRow.cells[4].value = 'Main Head';
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

      // Add data rows
      double totalBalance = 0.0;
      for (final account in selectedAccounts) {
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = account.id.toString();
        row.cells[1].value = account.code;
        row.cells[2].value = account.title;
        row.cells[3].value = account.sub?['title']?.toString() ?? 'N/A';
        row.cells[4].value = account.main?['title']?.toString() ?? 'N/A';

        totalBalance += account.balance;
        row.cells[5].value = 'Rs. ${account.balance.toStringAsFixed(2)}';

        // Align cells
        for (int i = 0; i < row.cells.count; i++) {
          row.cells[i].style = PdfGridCellStyle(
            format: PdfStringFormat(
              alignment: i == 2 || i == 3 || i == 4
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
          'Total Balance: Rs. ${totalBalance.toStringAsFixed(2)}',
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

      // Close loading dialog
      Navigator.of(context).pop();

      // Ask user where to save the file
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Account Statement PDF',
        fileName:
            'account_statement_${DateTime.now().millisecondsSinceEpoch}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(bytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved successfully to:\n$outputFile'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF export cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
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
        title: const Text('Account Statement'),
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
                'Export PDF${_selectedAccountIds.isNotEmpty ? ' (${_selectedAccountIds.length})' : ''}',
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
                              'Account Statement',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Detailed transaction history and balance tracking',
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
                  // Summary Cards (derived from account list)
                  Row(
                    children: [
                      _buildSummaryCard(
                        'Total Accounts',
                        _filteredAccounts.length.toString(),
                        Icons.account_balance_wallet,
                        const Color(0xFF4CAF50),
                      ),
                      _buildSummaryCard(
                        'Total Balance',
                        'Rs. ${_filteredAccounts.fold<double>(0.0, (p, e) => p + e.balance).toStringAsFixed(2)}',
                        Icons.receipt_long,
                        const Color(0xFF2196F3),
                      ),
                      _buildSummaryCard(
                        'Types',
                        _accounts.map((a) => a.type).toSet().length.toString(),
                        Icons.category,
                        const Color(0xFFFF9800),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Table Section
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
                          // Title Filter (First)
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
                                        Icons.title,
                                        size: 14,
                                        color: Color(0xFF0D1845),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Title',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF343A40),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () =>
                                      _showTitleSelectionDialog(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Color(0xFFDEE2E6),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _selectedTitle,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: _selectedTitle == 'All'
                                                  ? Color(0xFFADB5BD)
                                                  : Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_drop_down,
                                          color: Color(0xFF6C757D),
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Sub Category Filter (Second)
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
                                        Icons.subdirectory_arrow_right,
                                        size: 14,
                                        color: Color(0xFF0D1845),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Sub Category',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF343A40),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () =>
                                      _showSubCategorySelectionDialog(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Color(0xFFDEE2E6),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _selectedSub,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: _selectedSub == 'All'
                                                  ? Color(0xFFADB5BD)
                                                  : Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_drop_down,
                                          color: Color(0xFF6C757D),
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          // Main Category Filter (Third)
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
                                        Icons.category,
                                        size: 14,
                                        color: Color(0xFF0D1845),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Main Category',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF343A40),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                InkWell(
                                  onTap: () =>
                                      _showMainCategorySelectionDialog(context),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Color(0xFFDEE2E6),
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.05),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            _selectedMain,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: _selectedMain == 'All'
                                                  ? Color(0xFFADB5BD)
                                                  : Colors.black87,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        Icon(
                                          Icons.arrow_drop_down,
                                          color: Color(0xFF6C757D),
                                          size: 20,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Header (Account list)
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
                                    _selectedAccountIds = _filteredAccounts
                                        .map((account) => account.id)
                                        .toSet();
                                  } else {
                                    _selectedAccountIds.clear();
                                  }
                                });
                              },
                              activeColor: const Color(0xFF0D1845),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: Text('Code', style: _headerStyle()),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 3,
                            child: Text('Title', style: _headerStyle()),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Text('Type', style: _headerStyle()),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Text('Main', style: _headerStyle()),
                          ),
                          const SizedBox(width: 2),
                          Expanded(
                            flex: 2,
                            child: Text('Sub', style: _headerStyle()),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Text('Balance', style: _headerStyle()),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: Text('Actions', style: _headerStyle()),
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
                                    onPressed: _fetchAccountListOnInit,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _paginatedData.isEmpty
                          ? const Center(
                              child: Text(
                                'No accounts found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _paginatedData.length,
                              itemBuilder: (context, index) {
                                final account = _paginatedData[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
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
                                        width: 45,
                                        child: Checkbox(
                                          value: _selectedAccountIds.contains(
                                            account.id,
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedAccountIds.add(
                                                  account.id,
                                                );
                                              } else {
                                                _selectedAccountIds.remove(
                                                  account.id,
                                                );
                                                _selectAll = false;
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
                                          account.code,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF0D1845),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          account.title,
                                          style: TextStyle(fontSize: 12),
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          account.type,
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          (account.main != null
                                              ? (account.main!['title']
                                                        ?.toString() ??
                                                    account.main!['name']
                                                        ?.toString() ??
                                                    account.main.toString())
                                              : '-'),
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          (account.sub != null
                                              ? (account.sub!['title']
                                                        ?.toString() ??
                                                    account.sub!['name']
                                                        ?.toString() ??
                                                    account.sub.toString())
                                              : '-'),
                                          style: TextStyle(fontSize: 12),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Rs. ${account.balance.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0D1845),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 1,
                                        child: IconButton(
                                          onPressed: () =>
                                              _showTransactionDetails(
                                                account.id.toString(),
                                              ),
                                          icon: Icon(
                                            Icons.visibility,
                                            color: Color(0xFF007BFF),
                                            size: 20,
                                          ),
                                          tooltip: 'View Details',
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
                                  : 'Page $_currentPage of $_totalPages (${_filteredAccounts.length} total)',
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

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('dd MMM yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  TextStyle _headerStyle() {
    return const TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.bold,
      color: Color(0xFF343A40),
    );
  }

  Future<void> _showTransactionDetails(String accountId) async {
    // Convert string ID to int
    final id = int.tryParse(accountId);
    if (id == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Invalid account ID')));
      return;
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            constraints: const BoxConstraints(maxWidth: 1200),
            child: FutureBuilder<AccountStatement>(
              future: AccountStatementService.getAccountStatementById(id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Container(
                    height: 400,
                    child: const Center(child: CircularProgressIndicator()),
                  );
                } else if (snapshot.hasError) {
                  return Container(
                    height: 400,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 60,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Failed to load account statement',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '${snapshot.error}',
                            style: const TextStyle(color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                } else if (snapshot.hasData) {
                  final accountStatement = snapshot.data!;

                  // Calculate totals
                  double totalDebit = 0.0;
                  double totalCredit = 0.0;
                  for (var t in accountStatement.transactions) {
                    totalDebit +=
                        double.tryParse(t.debit.replaceAll(',', '')) ?? 0.0;
                    totalCredit +=
                        double.tryParse(t.credit.replaceAll(',', '')) ?? 0.0;
                  }
                  final closingBalance =
                      accountStatement.openingBalance +
                      totalCredit -
                      totalDebit;

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Header Section
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D1845), Color(0xFF1E3A8A)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            topRight: Radius.circular(20),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Account Statement',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: Colors.white.withOpacity(0.9),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        accountStatement.accountName,
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                  ),
                                  onPressed: () => Navigator.of(context).pop(),
                                  tooltip: 'Close',
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Period: ${_formatDate(accountStatement.fromDate)} - ${_formatDate(accountStatement.toDate)}',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Summary Cards
                      Container(
                        padding: const EdgeInsets.all(20),
                        color: const Color(0xFFF8F9FA),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildStatementSummaryCard(
                                'Opening Balance',
                                'Rs. ${accountStatement.openingBalance.toStringAsFixed(2)}',
                                Icons.account_balance_wallet,
                                const Color(0xFF6366F1),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatementSummaryCard(
                                'Total Debit',
                                'Rs. ${totalDebit.toStringAsFixed(2)}',
                                Icons.arrow_upward,
                                const Color(0xFFEF4444),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatementSummaryCard(
                                'Total Credit',
                                'Rs. ${totalCredit.toStringAsFixed(2)}',
                                Icons.arrow_downward,
                                const Color(0xFF10B981),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildStatementSummaryCard(
                                'Closing Balance',
                                'Rs. ${closingBalance.toStringAsFixed(2)}',
                                Icons.account_balance,
                                const Color(0xFF8B5CF6),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Transactions Table
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        color: Colors.white,
                        child: Row(
                          children: [
                            const Icon(
                              Icons.receipt_long,
                              size: 20,
                              color: Color(0xFF64748B),
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Transactions',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF3B82F6),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                '${accountStatement.transactions.length}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Table Header
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 12,
                        ),
                        color: const Color(0xFFF1F5F9),
                        child: Row(
                          children: const [
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Date',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Code',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              flex: 3,
                              child: Text(
                                'Title',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              flex: 4,
                              child: Text(
                                'Description',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Debit',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF475569),
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Credit',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF475569),
                                ),
                                textAlign: TextAlign.right,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Ref',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                  color: Color(0xFF475569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Transactions List
                      Flexible(
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 400),
                          color: Colors.white,
                          child: accountStatement.transactions.isEmpty
                              ? Center(
                                  child: Padding(
                                    padding: const EdgeInsets.all(40),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.receipt_long_outlined,
                                          size: 64,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(height: 16),
                                        Text(
                                          'No transactions found',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  itemCount:
                                      accountStatement.transactions.length,
                                  itemBuilder: (context, i) {
                                    final t = accountStatement.transactions[i];
                                    final isEven = i % 2 == 0;
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 20,
                                        vertical: 12,
                                      ),
                                      color: isEven
                                          ? Colors.white
                                          : const Color(0xFFFAFAFA),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              _formatDate(t.date),
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF334155),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              t.code,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                                color: Color(0xFF475569),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 3,
                                            child: Text(
                                              t.title,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF334155),
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 4,
                                            child: Text(
                                              t.description,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              t.debit != '0.00'
                                                  ? 'Rs. ${t.debit}'
                                                  : '-',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: t.debit != '0.00'
                                                    ? const Color(0xFFEF4444)
                                                    : Colors.grey[400],
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              t.credit != '0.00'
                                                  ? 'Rs. ${t.credit}'
                                                  : '-',
                                              style: TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w600,
                                                color: t.credit != '0.00'
                                                    ? const Color(0xFF10B981)
                                                    : Colors.grey[400],
                                              ),
                                              textAlign: TextAlign.right,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            flex: 2,
                                            child: Text(
                                              t.referenceNumber,
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.grey[600],
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),
                        ),
                      ),

                      // Footer with Close Button
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: const BorderRadius.only(
                            bottomLeft: Radius.circular(20),
                            bottomRight: Radius.circular(20),
                          ),
                          border: Border(
                            top: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            ElevatedButton.icon(
                              onPressed: () => _generateAccountStatementPDF(
                                accountStatement,
                              ),
                              icon: const Icon(Icons.picture_as_pdf, size: 18),
                              label: const Text('Generate PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D1845),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: TextButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 24,
                                  vertical: 12,
                                ),
                              ),
                              child: const Text(
                                'Close',
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                } else {
                  return Container(
                    height: 400,
                    child: const Center(child: Text('No data available')),
                  );
                }
              },
            ),
          ),
        );
      },
    );
  }

  Future<void> _generateAccountStatementPDF(
    AccountStatement accountStatement,
  ) async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Calculate totals
      double totalDebit = 0.0;
      double totalCredit = 0.0;
      for (var t in accountStatement.transactions) {
        totalDebit += double.tryParse(t.debit.replaceAll(',', '')) ?? 0.0;
        totalCredit += double.tryParse(t.credit.replaceAll(',', '')) ?? 0.0;
      }
      final closingBalance =
          accountStatement.openingBalance + totalCredit - totalDebit;

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
        'Account Statement Report',
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
      filterInfo += ' | Account: ${accountStatement.accountName}';

      graphics.drawString(
        filterInfo,
        smallFont,
        bounds: Rect.fromLTWH(0, 30, page.getClientSize().width, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // Create table
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 8);

      final double pageWidth = page.getClientSize().width;
      final double tableWidth = pageWidth * 0.95;

      grid.columns[0].width = tableWidth * 0.10; // Date
      grid.columns[1].width = tableWidth * 0.08; // Code
      grid.columns[2].width = tableWidth * 0.15; // Title
      grid.columns[3].width = tableWidth * 0.25; // Description
      grid.columns[4].width = tableWidth * 0.12; // Debit
      grid.columns[5].width = tableWidth * 0.12; // Credit
      grid.columns[6].width = tableWidth * 0.08; // Ref
      grid.columns[7].width = tableWidth * 0.10; // Balance

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
        font: smallFont,
      );

      // Add header row
      final PdfGridRow headerRow = grid.headers.add(1)[0];
      headerRow.cells[0].value = 'Date';
      headerRow.cells[1].value = 'Code';
      headerRow.cells[2].value = 'Title';
      headerRow.cells[3].value = 'Description';
      headerRow.cells[4].value = 'Debit';
      headerRow.cells[5].value = 'Credit';
      headerRow.cells[6].value = 'Ref';
      headerRow.cells[7].value = 'Balance';

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

      // Add summary row first - Opening Balance
      final PdfGridRow summaryRow = grid.rows.add();
      summaryRow.cells[0].value = '';
      summaryRow.cells[1].value = '';
      summaryRow.cells[2].value = 'Opening Balance';
      summaryRow.cells[3].value = '';
      summaryRow.cells[4].value = '';
      summaryRow.cells[5].value = '';
      summaryRow.cells[6].value = '';
      summaryRow.cells[7].value =
          'Rs. ${accountStatement.openingBalance.toStringAsFixed(2)}';

      // Style summary row with background
      for (int i = 0; i < summaryRow.cells.count; i++) {
        summaryRow.cells[i].style = PdfGridCellStyle(
          backgroundBrush: PdfSolidBrush(PdfColor(240, 240, 240)),
          format: PdfStringFormat(
            alignment: i == 7
                ? PdfTextAlignment.right
                : (i == 2 ? PdfTextAlignment.left : PdfTextAlignment.center),
            lineAlignment: PdfVerticalAlignment.middle,
          ),
          font: PdfStandardFont(
            PdfFontFamily.helvetica,
            9,
            style: PdfFontStyle.bold,
          ),
        );
      }

      // Add data rows
      double runningBalance = accountStatement.openingBalance.toDouble();
      for (final transaction in accountStatement.transactions) {
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = _formatDate(transaction.date);
        row.cells[1].value = transaction.code;
        row.cells[2].value = transaction.title;
        row.cells[3].value = transaction.description;
        row.cells[4].value = transaction.debit != '0.00'
            ? 'Rs. ${transaction.debit}'
            : '-';
        row.cells[5].value = transaction.credit != '0.00'
            ? 'Rs. ${transaction.credit}'
            : '-';
        row.cells[6].value = transaction.referenceNumber;

        // Calculate running balance
        final debit =
            double.tryParse(transaction.debit.replaceAll(',', '')) ?? 0.0;
        final credit =
            double.tryParse(transaction.credit.replaceAll(',', '')) ?? 0.0;
        runningBalance = runningBalance + credit - debit;
        row.cells[7].value = 'Rs. ${runningBalance.toStringAsFixed(2)}';

        // Align cells
        for (int i = 0; i < row.cells.count; i++) {
          row.cells[i].style = PdfGridCellStyle(
            format: PdfStringFormat(
              alignment: i == 4 || i == 5 || i == 7
                  ? PdfTextAlignment.right
                  : i == 0 || i == 1
                  ? PdfTextAlignment.center
                  : PdfTextAlignment.left,
              lineAlignment: PdfVerticalAlignment.middle,
            ),
          );
        }
      }

      // Draw closing balance before grid
      final double closingBalanceY = 55;
      graphics.drawString(
        'Closing Balance: Rs. ${closingBalance.toStringAsFixed(2)}',
        PdfStandardFont(PdfFontFamily.helvetica, 11, style: PdfFontStyle.bold),
        bounds: Rect.fromLTWH(
          page.getClientSize().width - 300,
          closingBalanceY,
          280,
          15,
        ),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );

      // Draw grid below closing balance
      grid.draw(
        page: page,
        bounds: Rect.fromLTWH(
          0,
          80,
          page.getClientSize().width,
          page.getClientSize().height - 120,
        ),
      );

      // Save the document
      final List<int> bytes = await document.save();
      document.dispose();

      // Close loading dialog
      Navigator.of(context).pop();

      // Ask user where to save the file
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Account Statement PDF',
        fileName:
            'account_statement_${DateTime.now().millisecondsSinceEpoch}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(bytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved successfully to:\n$outputFile'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 5),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('PDF export cancelled'),
            backgroundColor: Colors.orange,
          ),
        );
      }
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

  Widget _buildStatementSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
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
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  // Note: detailed-row helper removed; details are shown in a compact table view.

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
}
