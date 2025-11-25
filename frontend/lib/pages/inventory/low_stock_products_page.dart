import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:excel/excel.dart' as excel_pkg;
import 'package:provider/provider.dart';
import '../../services/inventory_service.dart';
import '../../models/product.dart';
import '../../providers/providers.dart';

class LowStockProductsPage extends StatefulWidget {
  const LowStockProductsPage({super.key});

  @override
  State<LowStockProductsPage> createState() => _LowStockProductsPageState();
}

class _LowStockProductsPageState extends State<LowStockProductsPage> {
  List<Product> lowStockProducts = [];
  bool isLoading = true;
  String? errorMessage;
  int currentPage = 1;
  int totalProducts = 0;
  int totalPages = 1;
  final int itemsPerPage = 17;

  // Vendor search
  final TextEditingController _vendorSearchController = TextEditingController();
  String vendorSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchLowStockProducts();
  }

  @override
  void dispose() {
    _vendorSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchLowStockProducts({int page = 1}) async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Get provider instance
      final provider = Provider.of<InventoryProvider>(context, listen: false);

      // Check if vendor search is active
      bool hasVendorSearch = vendorSearchQuery.trim().isNotEmpty;

      print(
        '🔍 LOW STOCK SEARCH: vendorQuery="$vendorSearchQuery", hasVendorSearch=$hasVendorSearch',
      );

      // Check if low stock products are already cached in provider
      // Only use cache if page is 1 AND no search is active
      if (provider.lowStockProducts.isNotEmpty &&
          page == 1 &&
          !hasVendorSearch) {
        print(
          '💾 Using cached low stock products from provider: ${provider.lowStockProducts.length} products',
        );
        setState(() {
          lowStockProducts = List.from(provider.lowStockProducts);
          currentPage = 1;
          totalProducts = provider.lowStockProducts.length;
          totalPages = (totalProducts / itemsPerPage).ceil();
          isLoading = false;
        });
        return;
      }

      print('🌐 Fetching low stock products from API...');
      final response = await InventoryService.getLowStockProducts(
        page: page,
        limit: itemsPerPage,
      );

      print(
        '✅ API Response received with ${response['data']?.length ?? 0} products',
      );

      // Handle case where API returns a message instead of data (empty state)
      if (response.containsKey('message') &&
          response['message'].toString().contains(
            'No low stock products found',
          )) {
        print('📭 No low stock products found (message received)');
        setState(() {
          lowStockProducts = [];
          currentPage = 1;
          totalProducts = 0;
          totalPages = 1;
          isLoading = false;
          errorMessage = ''; // Clear any error message
        });
        return;
      }

      // Handle case where API returns no data (empty state)
      if (response['data'] == null || response['data'] is! List) {
        print('📭 No low stock products found (no data field)');
        setState(() {
          lowStockProducts = [];
          currentPage = 1;
          totalProducts = 0;
          totalPages = 1;
          isLoading = false;
          errorMessage = ''; // Clear any error message
        });
        return;
      }

      var products = (response['data'] as List)
          .map((item) => Product.fromJson(item))
          .toList();

      // Apply client-side vendor filtering if search query exists
      if (hasVendorSearch) {
        final searchLower = vendorSearchQuery.toLowerCase().trim();
        products = products.where((product) {
          final vendorName = (product.vendor.name ?? '').toLowerCase();
          return vendorName.contains(searchLower);
        }).toList();
        print(
          '🔍 Filtered to ${products.length} products matching vendor: "$vendorSearchQuery"',
        );
      }

      setState(() {
        lowStockProducts = products;
        currentPage = page;
        totalProducts = hasVendorSearch
            ? products.length
            : (response['total'] ?? products.length);
        totalPages = (totalProducts / itemsPerPage).ceil();
        isLoading = false;
      });

      print(
        '📊 Updated UI with ${products.length} products, total: $totalProducts',
      );

      // Update provider cache only for unfiltered results (page 1, no search)
      if (page == 1 && !hasVendorSearch) {
        provider.setLowStockProducts(products);
        print('💾 Cached ${products.length} unfiltered products to provider');
      }
    } catch (e) {
      print('❌ Error fetching low stock products: $e');
      // Check if it's a "no products found" message (not an actual error)
      if (e.toString().contains('No low stock products found')) {
        setState(() {
          lowStockProducts = [];
          currentPage = 1;
          totalProducts = 0;
          totalPages = 1;
          isLoading = false;
          errorMessage = ''; // Don't show error for empty state
        });
      } else {
        setState(() {
          errorMessage = e.toString();
          isLoading = false;
        });
      }
    }
  }

  void exportToPDF() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                ),
                SizedBox(width: 16),
                Text('Fetching all low stock products...'),
              ],
            ),
          );
        },
      );

      // Always fetch ALL low stock products from database for export
      List<Product> allLowStockProductsForExport = [];

      try {
        // Fetch ALL low stock products with unlimited pagination
        int currentPage = 1;
        bool hasMorePages = true;

        while (hasMorePages) {
          final pageResponse = await InventoryService.getLowStockProducts(
            page: currentPage,
            limit: 100, // Fetch in chunks of 100
          );

          final products = (pageResponse['data'] as List)
              .map((item) => Product.fromJson(item))
              .toList();

          allLowStockProductsForExport.addAll(products);

          // Check if there are more pages
          final totalItems = pageResponse['total'] ?? 0;
          final fetchedSoFar = allLowStockProductsForExport.length;

          if (fetchedSoFar >= totalItems) {
            hasMorePages = false;
          } else {
            currentPage++;
          }

          // Update loading message
          Navigator.of(context).pop();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                content: Row(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF6B35),
                      ),
                    ),
                    SizedBox(width: 16),
                    Text(
                      'Fetched ${allLowStockProductsForExport.length} low stock products...',
                    ),
                  ],
                ),
              );
            },
          );
        }

        // Apply filters if any are active (Note: Low stock products page doesn't have search/status filters like products page)
        // Add any filtering logic here if needed in the future
      } catch (e) {
        print('Error fetching all low stock products: $e');
        // Fallback to current data
        allLowStockProductsForExport = lowStockProducts.isNotEmpty
            ? lowStockProducts
            : [];
      }

      if (allLowStockProductsForExport.isEmpty) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No low stock products to export'),
            backgroundColor: Color(0xFFDC3545),
          ),
        );
        return;
      }

      // Update loading message
      Navigator.of(context).pop();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                ),
                SizedBox(width: 16),
                Text(
                  'Generating PDF with ${allLowStockProductsForExport.length} low stock products...',
                ),
              ],
            ),
          );
        },
      );

      // Create a new PDF document with landscape orientation for better table fit
      final PdfDocument document = PdfDocument();

      // Set page to landscape for better table visibility
      document.pageSettings.orientation = PdfPageOrientation.landscape;
      document.pageSettings.size = PdfPageSize.a4;

      // Define fonts - adjusted for landscape
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
      final PdfFont regularFont = PdfStandardFont(PdfFontFamily.helvetica, 10);
      final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 9);

      // Colors
      final PdfColor headerColor = PdfColor(
        255,
        107,
        53,
      ); // Low stock theme color
      final PdfColor tableHeaderColor = PdfColor(248, 249, 250);

      // Create table with proper settings for pagination
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 5);

      // Use full page width but account for table borders and padding
      final double pageWidth =
          document.pageSettings.size.width -
          15; // Only 15px left margin, 0px right margin
      final double tableWidth =
          pageWidth *
          0.85; // Use 85% to ensure right boundary is clearly visible

      // Balanced column widths for low stock products (removed status column)
      grid.columns[0].width = tableWidth * 0.20; // 20% - Product Code
      grid.columns[1].width = tableWidth * 0.30; // 30% - Product Name
      grid.columns[2].width = tableWidth * 0.20; // 20% - Stock Quantity
      grid.columns[3].width = tableWidth * 0.15; // 15% - Sale Price
      grid.columns[4].width = tableWidth * 0.15; // 15% - Vendor

      // Enable automatic page breaking and row splitting
      grid.allowRowBreakingAcrossPages = true;

      // Set grid style with better padding for readability
      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 4, right: 4, top: 4, bottom: 4),
        font: smallFont,
      );

      // Add header row
      final PdfGridRow headerRow = grid.headers.add(1)[0];
      headerRow.cells[0].value = 'Product Code';
      headerRow.cells[1].value = 'Product Name';
      headerRow.cells[2].value = 'Stock Quantity';
      headerRow.cells[3].value = 'Sale Price';
      headerRow.cells[4].value = 'Vendor';

      // Style header row
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

      // Add all low stock product data rows
      for (var product in allLowStockProductsForExport) {
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = product.designCode;
        row.cells[1].value = product.title;
        row.cells[2].value = product.inStockQuantity;
        row.cells[3].value = 'PKR ${product.salePrice}';
        row.cells[4].value = product.vendor.name ?? 'N/A';

        // Style data cells with better text wrapping
        for (int i = 0; i < row.cells.count; i++) {
          row.cells[i].style = PdfGridCellStyle(
            font: smallFont,
            textBrush: PdfSolidBrush(PdfColor(33, 37, 41)),
            format: PdfStringFormat(
              alignment: i == 2 || i == 3
                  ? PdfTextAlignment.center
                  : PdfTextAlignment.left,
              lineAlignment: PdfVerticalAlignment.top,
              wordWrap: PdfWordWrapType.word,
            ),
          );
        }
      }

      // Set up page template for headers and footers
      final PdfPageTemplateElement headerTemplate = PdfPageTemplateElement(
        Rect.fromLTWH(0, 0, document.pageSettings.size.width, 50),
      );

      // Draw header on template - minimal left margin, full width
      headerTemplate.graphics.drawString(
        'Low Stock Products Database Export',
        titleFont,
        brush: PdfSolidBrush(headerColor),
        bounds: Rect.fromLTWH(
          15,
          10,
          document.pageSettings.size.width - 15,
          25,
        ),
      );

      headerTemplate.graphics.drawString(
        'Total Low Stock Products: ${allLowStockProductsForExport.length} | Generated: ${DateTime.now().toString().substring(0, 19)} | Low Stock Alert Report',
        regularFont,
        brush: PdfSolidBrush(PdfColor(108, 117, 125)),
        bounds: Rect.fromLTWH(
          15,
          32,
          document.pageSettings.size.width - 15,
          15,
        ),
      );

      // Add line under header - full width
      headerTemplate.graphics.drawLine(
        PdfPen(PdfColor(200, 200, 200), width: 1),
        Offset(15, 48),
        Offset(document.pageSettings.size.width, 48),
      );

      // Create footer template
      final PdfPageTemplateElement footerTemplate = PdfPageTemplateElement(
        Rect.fromLTWH(
          0,
          document.pageSettings.size.height - 25,
          document.pageSettings.size.width,
          25,
        ),
      );

      // Draw footer - full width
      footerTemplate.graphics.drawString(
        'Page \$PAGE of \$TOTAL | ${allLowStockProductsForExport.length} Total Low Stock Products | Generated from POS System',
        regularFont,
        brush: PdfSolidBrush(PdfColor(108, 117, 125)),
        bounds: Rect.fromLTWH(15, 8, document.pageSettings.size.width - 15, 15),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // Apply templates to document
      document.template.top = headerTemplate;
      document.template.bottom = footerTemplate;

      // Draw the grid with automatic pagination - use full width, minimal left margin
      grid.draw(
        page: document.pages.add(),
        bounds: Rect.fromLTWH(
          15,
          55,
          document.pageSettings.size.width - 15,
          document.pageSettings.size.height - 85,
        ),
        format: PdfLayoutFormat(
          layoutType: PdfLayoutType.paginate,
          breakType: PdfLayoutBreakType.fitPage,
        ),
      );

      // Get page count before disposal
      final int pageCount = document.pages.count;
      print(
        'PDF generated with $pageCount page(s) for ${allLowStockProductsForExport.length} low stock products',
      );

      // Save PDF
      final List<int> bytes = await document.save();
      document.dispose();

      // Close loading dialog
      Navigator.of(context).pop();

      // Let user choose save location
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Low Stock Products Database PDF',
        fileName:
            'low_stock_products_${DateTime.now().millisecondsSinceEpoch}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Low Stock Products Exported!\n📊 ${allLowStockProductsForExport.length} products across $pageCount pages\n📄 Landscape format for better visibility',
              ),
              backgroundColor: Color(0xFF28A745),
              duration: Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
                onPressed: () async {
                  try {
                    await Process.run('explorer', ['/select,', outputFile]);
                  } catch (e) {
                    print('File saved at: $outputFile');
                  }
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if it's open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Color(0xFFDC3545),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> exportToExcel() async {
    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                ),
                SizedBox(width: 16),
                Text('Fetching all low stock products...'),
              ],
            ),
          );
        },
      );

      // Always fetch ALL low stock products from database for export
      List<Product> allLowStockProductsForExport = [];

      try {
        // Fetch ALL low stock products with unlimited pagination
        int currentPage = 1;
        bool hasMorePages = true;

        while (hasMorePages) {
          final pageResponse = await InventoryService.getLowStockProducts(
            page: currentPage,
            limit: 100, // Fetch in chunks of 100
          );

          final products = (pageResponse['data'] as List)
              .map((item) => Product.fromJson(item))
              .toList();

          allLowStockProductsForExport.addAll(products);

          // Check if there are more pages
          final totalItems = pageResponse['total'] ?? 0;
          final fetchedSoFar = allLowStockProductsForExport.length;

          if (fetchedSoFar >= totalItems) {
            hasMorePages = false;
          } else {
            currentPage++;
          }

          // Update loading message
          Navigator.of(context).pop();
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                content: Row(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFFFF6B35),
                      ),
                    ),
                    SizedBox(width: 16),
                    Text(
                      'Fetched ${allLowStockProductsForExport.length} low stock products...',
                    ),
                  ],
                ),
              );
            },
          );
        }

        // Apply filters if any are active (Note: Low stock products page doesn't have search/status filters like products page)
        // Add any filtering logic here if needed in the future
      } catch (e) {
        print('Error fetching all low stock products: $e');
        // Fallback to current data
        allLowStockProductsForExport = lowStockProducts.isNotEmpty
            ? lowStockProducts
            : [];
      }

      if (allLowStockProductsForExport.isEmpty) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No low stock products to export'),
            backgroundColor: Color(0xFFDC3545),
          ),
        );
        return;
      }

      // Update loading message
      Navigator.of(context).pop();
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                ),
                SizedBox(width: 16),
                Text(
                  'Generating Excel with ${allLowStockProductsForExport.length} low stock products...',
                ),
              ],
            ),
          );
        },
      );

      // Create a new Excel document
      final excel_pkg.Excel excel = excel_pkg.Excel.createExcel();
      final excel_pkg.Sheet sheet = excel['Low Stock Products'];

      // Add header row with styling
      sheet.appendRow([
        excel_pkg.TextCellValue('Product Code'),
        excel_pkg.TextCellValue('Product Name'),
        excel_pkg.TextCellValue('Stock Quantity'),
        excel_pkg.TextCellValue('Sale Price'),
        excel_pkg.TextCellValue('Vendor'),
      ]);

      // Style header row
      final headerStyle = excel_pkg.CellStyle(bold: true, fontSize: 12);

      for (int i = 0; i < 5; i++) {
        sheet
                .cell(
                  excel_pkg.CellIndex.indexByColumnRow(
                    columnIndex: i,
                    rowIndex: 0,
                  ),
                )
                .cellStyle =
            headerStyle;
      }

      // Add all low stock product data rows
      for (var product in allLowStockProductsForExport) {
        sheet.appendRow([
          excel_pkg.TextCellValue(product.designCode),
          excel_pkg.TextCellValue(product.title),
          excel_pkg.TextCellValue(product.inStockQuantity),
          excel_pkg.TextCellValue('PKR ${product.salePrice}'),
          excel_pkg.TextCellValue(product.vendor.name ?? 'N/A'),
        ]);
      }

      // Save Excel file
      final List<int>? bytes = excel.save();
      if (bytes == null) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to generate Excel file'),
            backgroundColor: Color(0xFFDC3545),
          ),
        );
        return;
      }

      // Close loading dialog
      Navigator.of(context).pop();

      // Let user choose save location
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Low Stock Products Database Excel',
        fileName:
            'low_stock_products_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(bytes);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Low Stock Products Exported!\n📊 ${allLowStockProductsForExport.length} products exported to Excel\n📈 Ready for inventory analysis',
              ),
              backgroundColor: Color(0xFF28A745),
              duration: Duration(seconds: 5),
              action: SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
                onPressed: () async {
                  try {
                    await Process.run('explorer', ['/select,', outputFile]);
                  } catch (e) {
                    print('File saved at: $outputFile');
                  }
                },
              ),
            ),
          );
        }
      }
    } catch (e) {
      // Close loading dialog if it's open
      if (Navigator.canPop(context)) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Color(0xFFDC3545),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Low Stock Products'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, Color(0xFFF8F9FA)],
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
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Icon(
                          Icons.warning_amber,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Low Stock Products',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              'Monitor and manage products that are running low on stock',
                              style: TextStyle(
                                fontSize: 9,
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
                        'Total Low Stock',
                        lowStockProducts.length.toString(),
                        Icons.warning_amber,
                        Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      _buildSummaryCard(
                        'Critical Stock',
                        lowStockProducts
                            .where(
                              (p) =>
                                  (int.tryParse(p.inStockQuantity) ?? 0) <= 5,
                            )
                            .length
                            .toString(),
                        Icons.error,
                        Colors.red,
                      ),
                      const SizedBox(width: 12),
                      _buildSummaryCard(
                        'Low Stock',
                        lowStockProducts
                            .where(
                              (p) => (int.tryParse(p.inStockQuantity) ?? 0) > 5,
                            )
                            .length
                            .toString(),
                        Icons.warning,
                        Colors.yellow,
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
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Vendor Search Bar
                          Expanded(
                            flex: 3,
                            child: Container(
                              height: 36,
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: const Color(0xFF0D1845),
                                  width: 1.5,
                                ),
                                borderRadius: BorderRadius.circular(12),
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: TextField(
                                controller: _vendorSearchController,
                                decoration: InputDecoration(
                                  hintText: 'Search by vendor name...',
                                  hintStyle: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[500],
                                  ),
                                  prefixIcon: const Icon(
                                    Icons.store,
                                    color: Color(0xFF0D1845),
                                    size: 20,
                                  ),
                                  suffixIcon: vendorSearchQuery.isNotEmpty
                                      ? IconButton(
                                          icon: const Icon(
                                            Icons.clear,
                                            size: 18,
                                          ),
                                          onPressed: () {
                                            setState(() {
                                              _vendorSearchController.clear();
                                              vendorSearchQuery = '';
                                              currentPage = 1;
                                            });
                                            _fetchLowStockProducts(page: 1);
                                          },
                                        )
                                      : null,
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Color(0xFF0D1845),
                                ),
                                onChanged: (value) {
                                  setState(() {
                                    vendorSearchQuery = value;
                                    currentPage = 1;
                                  });
                                  // Use debouncing in production, for now direct search
                                },
                                onSubmitted: (value) {
                                  setState(() {
                                    vendorSearchQuery = value;
                                    currentPage = 1;
                                  });
                                  _fetchLowStockProducts(page: 1);
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Search Button
                          SizedBox(
                            height: 36,
                            child: ElevatedButton.icon(
                              onPressed: () {
                                setState(() {
                                  currentPage = 1;
                                });
                                _fetchLowStockProducts(page: 1);
                              },
                              icon: const Icon(Icons.search, size: 16),
                              label: const Text('Search'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF0D1845),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Export Buttons - More Compact
                          SizedBox(
                            height: 36,
                            child: ElevatedButton.icon(
                              onPressed: exportToPDF,
                              icon: const Icon(Icons.picture_as_pdf, size: 16),
                              label: const Text('PDF'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFDC3545),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 36,
                            child: ElevatedButton.icon(
                              onPressed: exportToExcel,
                              icon: const Icon(Icons.table_chart, size: 16),
                              label: const Text('Excel'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF28A745),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
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
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : errorMessage != null && errorMessage!.isNotEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    errorMessage!,
                                    style: const TextStyle(color: Colors.grey),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: () => _fetchLowStockProducts(
                                      page: currentPage,
                                    ),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : lowStockProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.warning_amber_outlined,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No low stock products found',
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: lowStockProducts.length,
                              itemBuilder: (context, index) {
                                final product = lowStockProducts[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 6,
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
                                      // Product Details Column
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              product.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF0D1845),
                                                fontSize: 12,
                                              ),
                                            ),
                                            const SizedBox(height: 1),
                                            Text(
                                              'Code: ${product.designCode}',
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Vendor Column
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          product.vendor.name ?? 'N/A',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF6C757D),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Price Column - Centered
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Text(
                                            'PKR ${product.salePrice}',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              color: Color(0xFF6C757D),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Stock Column - Centered
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF3CD),
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              product.inStockQuantity,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF856404),
                                              ),
                                              textAlign: TextAlign.center,
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
            if (lowStockProducts.isNotEmpty) ...[
              Container(
                margin: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Previous button
                    ElevatedButton.icon(
                      onPressed: currentPage > 1
                          ? () => _fetchLowStockProducts(page: currentPage - 1)
                          : null,
                      icon: const Icon(Icons.chevron_left, size: 16),
                      label: const Text('Previous'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentPage > 1
                            ? const Color(0xFF0D1845)
                            : Colors.grey.shade300,
                        foregroundColor: currentPage > 1
                            ? Colors.white
                            : Colors.grey.shade600,
                        elevation: currentPage > 1 ? 2 : 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Page info
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'Page $currentPage of $totalPages (${lowStockProducts.length} total)',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6C757D),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    // Next button
                    ElevatedButton.icon(
                      onPressed: currentPage < totalPages
                          ? () => _fetchLowStockProducts(page: currentPage + 1)
                          : null,
                      icon: const Icon(Icons.chevron_right, size: 16),
                      label: const Text('Next'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentPage < totalPages
                            ? const Color(0xFF0D1845)
                            : Colors.grey.shade300,
                        foregroundColor: currentPage < totalPages
                            ? Colors.white
                            : Colors.grey.shade600,
                        elevation: currentPage < totalPages ? 2 : 0,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
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
