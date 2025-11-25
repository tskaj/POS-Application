import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import '../../services/salesman_service.dart';

class SalesmanReportPage extends StatefulWidget {
  const SalesmanReportPage({super.key});

  @override
  State<SalesmanReportPage> createState() => _SalesmanReportPageState();
}

class _SalesmanReportPageState extends State<SalesmanReportPage> {
  List<Salesman> _salesmen = [];
  bool _isLoading = true;
  String _error = '';

  // Pagination
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  int _totalPages = 1;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Selection for PDF export
  Set<int> _selectedSalesmenIds = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _loadSalesmen();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSalesmen() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final resp = await SalesmanService.getAllSalesmen();
      setState(() {
        _salesmen = resp.data;
        _currentPage = 1;
        _totalPages = (_salesmen.length / _itemsPerPage).ceil();
        if (_totalPages == 0) _totalPages = 1;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _salesmen = [];
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  List<Salesman> _filtered() {
    if (_searchQuery.trim().isEmpty) return _salesmen;
    final q = _searchQuery.toLowerCase();
    return _salesmen.where((s) {
      return s.name.toLowerCase().contains(q) ||
          s.email.toLowerCase().contains(q) ||
          s.city.toLowerCase().contains(q) ||
          s.cellNo1.toLowerCase().contains(q) ||
          s.position.toLowerCase().contains(q) ||
          s.cnic.toLowerCase().contains(q);
    }).toList();
  }

  List<Salesman> _paginated(List<Salesman> list) {
    final start = (_currentPage - 1) * _itemsPerPage;
    final end = start + _itemsPerPage;
    _totalPages = (list.length / _itemsPerPage).ceil();
    if (_totalPages == 0) _totalPages = 1;
    return list.sublist(start, end > list.length ? list.length : end);
  }

  Future<void> _exportPdf() async {
    try {
      // Get salesmen to export based on selection
      List<Salesman> toExport;
      if (_selectedSalesmenIds.isEmpty) {
        // If nothing selected, export all filtered salesmen
        toExport = _filtered();
      } else {
        // Export only selected salesmen
        toExport = _salesmen
            .where((s) => _selectedSalesmenIds.contains(s.id))
            .toList();
      }

      if (toExport.isEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('No data to export')));
        return;
      }

      final PdfDocument document = PdfDocument();
      document.pageSettings.orientation = PdfPageOrientation.landscape;
      document.pageSettings.size = PdfPageSize.a4;

      final PdfFont titleFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        16,
        style: PdfFontStyle.bold,
      );
      final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 9);

      final PdfPage page = document.pages.add();
      final PdfGraphics graphics = page.graphics;

      graphics.drawString(
        'Salesmen Report',
        titleFont,
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 24),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );

      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 10);

      final double pageWidth = page.getClientSize().width;
      final double tableWidth = pageWidth * 0.95;

      // simple column widths
      for (int i = 0; i < grid.columns.count; i++) {
        grid.columns[i].width = tableWidth / grid.columns.count;
      }

      final headerRow = grid.headers.add(1)[0];
      final cols = [
        'ID',
        'Name',
        'Email',
        'Position',
        'CNIC',
        'Address',
        'City',
        'Cell 1',
        'Cell 2',
      ];
      for (int i = 0; i < cols.length; i++) headerRow.cells[i].value = cols[i];

      for (final s in toExport) {
        final row = grid.rows.add();
        row.cells[0].value = s.id.toString();
        row.cells[1].value = s.name;
        row.cells[2].value = s.email;
        row.cells[3].value = s.position;
        row.cells[4].value = s.cnic;
        row.cells[5].value = s.address;
        row.cells[6].value = s.city;
        row.cells[7].value = s.cellNo1;
        row.cells[8].value = s.cellNo2 ?? '';
      }

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
        font: smallFont,
      );
      grid.draw(
        page: page,
        bounds: Rect.fromLTWH(
          10,
          36,
          page.getClientSize().width - 20,
          page.getClientSize().height - 36 - 20,
        ),
      );

      final bytes = await document.save();
      document.dispose();

      final String fileName =
          'salesmen_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';
      String? out = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Salesmen Report',
        fileName: fileName,
      );
      if (out != null) {
        final f = File(out);
        await f.writeAsBytes(bytes);
        if (mounted)
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('PDF exported')));
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Export failed: $e')));
    }
  }

  List<Widget> _buildPageNumbers(int totalPages) {
    List<Widget> pageNumbers = [];
    int startPage = 1;
    int endPage = totalPages;

    if (totalPages > 5) {
      if (_currentPage <= 3) {
        endPage = 5;
      } else if (_currentPage >= totalPages - 2) {
        startPage = totalPages - 4;
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
            });
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _currentPage == i
                  ? const Color(0xFF0D1845)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _currentPage == i
                    ? const Color(0xFF0D1845)
                    : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Text(
              i.toString(),
              style: TextStyle(
                color: _currentPage == i
                    ? Colors.white
                    : const Color(0xFF0D1845),
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

  // Header style helper removed (unused)

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error.isNotEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.warning, color: Colors.orange, size: 48),
              const SizedBox(height: 16),
              const Text(
                'API Error',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadSalesmen,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final filtered = _filtered();
    final paginated = _paginated(filtered);

    return Scaffold(
      appBar: AppBar(
        title: const Text('All Salesman'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: () async {
              setState(() => _isLoading = true);
              await _loadSalesmen();
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
            // Header with summary (title on top, summary cards below)
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
                crossAxisAlignment: CrossAxisAlignment.start,
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
                          Icons.person,
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
                              'All Salesman',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'All Salesman',
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
                  Row(
                    children: [
                      _buildSummaryCard(
                        'Total Salesmen',
                        filtered.length.toString(),
                        Icons.group,
                        Colors.blue,
                      ),
                      const SizedBox(width: 12),
                      _buildSummaryCard(
                        'Active',
                        filtered
                            .where((s) => s.status.toLowerCase() == 'active')
                            .length
                            .toString(),
                        Icons.check_circle,
                        Colors.green,
                      ),
                      const SizedBox(width: 12),
                      _buildSummaryCard(
                        'Inactive',
                        filtered
                            .where((s) => s.status.toLowerCase() != 'active')
                            .length
                            .toString(),
                        Icons.block,
                        Colors.red,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search and table
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
                    // Search bar
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
                                  hintText: 'Search name, email, city, CNIC...',
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
                                onChanged: (v) {
                                  setState(() {
                                    _searchQuery = v.trim();
                                    _currentPage = 1;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          SizedBox(
                            height: 24,
                            child: ElevatedButton.icon(
                              onPressed: _exportPdf,
                              icon: const Icon(Icons.picture_as_pdf, size: 12),
                              label: Text(
                                _selectedSalesmenIds.isEmpty
                                    ? 'Export All PDF'
                                    : 'Export ${_selectedSalesmenIds.length} PDF',
                                style: const TextStyle(fontSize: 10),
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

                    // Table header
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
                          SizedBox(
                            width: 45,
                            child: Checkbox(
                              value: _selectAll,
                              onChanged: (value) {
                                setState(() {
                                  _selectAll = value ?? false;
                                  if (_selectAll) {
                                    _selectedSalesmenIds = _filtered()
                                        .map((s) => s.id)
                                        .toSet();
                                  } else {
                                    _selectedSalesmenIds.clear();
                                  }
                                });
                              },
                              activeColor: const Color(0xFF0D1845),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 40,
                            child: Text(
                              'ID',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Name',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Email',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'Position',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Text(
                              'City',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          const SizedBox(
                            width: 120,
                            child: Text(
                              'Cell',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                          const SizedBox(width: 12),
                          SizedBox(
                            width: 60,
                            child: Text(
                              'Actions',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table body
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : paginated.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: const [
                                  Icon(
                                    Icons.person_off,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    'No salesmen found',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: paginated.length,
                              itemBuilder: (context, idx) {
                                final s = paginated[idx];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: idx % 2 == 0
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
                                      SizedBox(
                                        width: 45,
                                        child: Checkbox(
                                          value: _selectedSalesmenIds.contains(
                                            s.id,
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedSalesmenIds.add(s.id);
                                              } else {
                                                _selectedSalesmenIds.remove(
                                                  s.id,
                                                );
                                                _selectAll = false;
                                              }
                                            });
                                          },
                                          activeColor: const Color(0xFF0D1845),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      SizedBox(
                                        width: 40,
                                        child: Text(s.id.toString()),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          s.name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(s.email)),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(s.position)),
                                      const SizedBox(width: 12),
                                      Expanded(child: Text(s.city)),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: 120,
                                        child: Text(s.cellNo1),
                                      ),
                                      const SizedBox(width: 12),
                                      SizedBox(
                                        width: 60,
                                        child: Center(
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.remove_red_eye,
                                              size: 18,
                                              color: Color(0xFF0D1845),
                                            ),
                                            tooltip: 'View',
                                            onPressed: () =>
                                                _onViewSalesman(s.id),
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

            // Pagination
            if (filtered.isNotEmpty)
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
                    ElevatedButton.icon(
                      onPressed: _currentPage > 1
                          ? () {
                              setState(() => _currentPage--);
                            }
                          : null,
                      icon: const Icon(Icons.chevron_left, size: 14),
                      label: const Text(
                        'Previous',
                        style: TextStyle(fontSize: 11),
                      ),
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
                    ..._buildPageNumbers(_totalPages),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: _currentPage < _totalPages
                          ? () {
                              setState(() => _currentPage++);
                            }
                          : null,
                      icon: const Icon(Icons.chevron_right, size: 14),
                      label: const Text('Next', style: TextStyle(fontSize: 11)),
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
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Page $_currentPage of $_totalPages (${filtered.length} total)',
                        style: const TextStyle(
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

  Future<void> _onViewSalesman(int id) async {
    // show loading dialog
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    try {
      final detail = await SalesmanService.getSalesmanDetail(id);
      Navigator.of(context).pop(); // remove loading

      // show detail dialog
      showDialog<void>(
        context: context,
        builder: (context) {
          final summary = detail.summary;
          final invoices = detail.data;
          return AlertDialog(
            title: Text(summary['salesman']?.toString() ?? 'Salesman'),
            content: SizedBox(
              width: 700,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary row
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _smallStatCard(
                          'Total Invoices',
                          summary['total_invoices']?.toString() ?? '0',
                        ),
                        _smallStatCard(
                          'Total Sales',
                          'Rs ${(_toDouble(summary['total_sales_amount'])?.toStringAsFixed(2) ?? '0')}',
                        ),
                        _smallStatCard(
                          'Total Paid',
                          'Rs ${(_toDouble(summary['total_paid'])?.toStringAsFixed(2) ?? '0')}',
                        ),
                        _smallStatCard(
                          'Total Discount',
                          'Rs ${(_toDouble(summary['total_discount'])?.toStringAsFixed(2) ?? '0')}',
                        ),
                        _smallStatCard(
                          'Total Tax',
                          'Rs ${(_toDouble(summary['total_tax'])?.toStringAsFixed(2) ?? '0')}',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(),
                    const SizedBox(height: 8),
                    // Invoices list
                    Text(
                      'Invoices (${invoices.length})',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ...invoices.map((inv) {
                      final details = (inv['details'] as List<dynamic>?) ?? [];
                      final computed = inv['computed'] as Map<String, dynamic>?;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Invoice #${inv['id']} - ${inv['inv_date'] ?? ''}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                Text(
                                  'Rs ${_toDouble(inv['inv_amount'])?.toStringAsFixed(2) ?? inv['inv_amount']?.toString() ?? '0'}',
                                ),
                              ],
                            ),
                            if ((inv['description'] ?? '')
                                .toString()
                                .isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Text(inv['description'].toString()),
                            ],
                            const SizedBox(height: 6),
                            // Items
                            ...details.map((d) {
                              final extras =
                                  (d['extras'] as List<dynamic>?) ?? [];
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '- ${d['product_name'] ?? ''} x${d['quantity'] ?? ''}  Rs ${d['price'] ?? ''}',
                                  ),
                                  if (extras.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 12,
                                        top: 4,
                                      ),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: extras
                                            .map<Widget>(
                                              (ex) => Text(
                                                '• ${ex['title'] ?? ''} Rs ${ex['amount'] ?? ''}',
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                ),
                                              ),
                                            )
                                            .toList(),
                                      ),
                                    ),
                                  const SizedBox(height: 6),
                                ],
                              );
                            }).toList(),
                            if (computed != null) ...[
                              const SizedBox(height: 6),
                              Text(
                                'Grand Total: Rs ${_toDouble(computed['grand_total'])?.toStringAsFixed(2) ?? ''}',
                              ),
                              Text(
                                'Balance Due: Rs ${_toDouble(computed['balance_due'])?.toStringAsFixed(2) ?? ''}',
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ],
          );
        },
      );
    } catch (e) {
      Navigator.of(context).pop();
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load detail: $e')));
    }
  }

  double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    try {
      return double.tryParse(v.toString());
    } catch (_) {
      return null;
    }
  }

  Widget _smallStatCard(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 6),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}
