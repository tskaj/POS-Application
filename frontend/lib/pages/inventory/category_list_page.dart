import 'package:flutter/material.dart';
import 'dart:io';
import 'dart:async';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:provider/provider.dart';
import '../../services/inventory_service.dart';
import '../../models/category.dart';
import 'package:excel/excel.dart' as excel_pkg;
import '../../providers/providers.dart';
import 'category_details_dialog.dart';
import 'edit_category_dialog.dart';
import 'add_category_page.dart';

class CategoryListPage extends StatefulWidget {
  const CategoryListPage({super.key});

  @override
  State<CategoryListPage> createState() => _CategoryListPageState();
}

class _CategoryListPageState extends State<CategoryListPage> with RouteAware {
  List<Category> categories = [];
  bool isLoading = false; // Start with false to show UI immediately
  String? errorMessage;
  int currentPage = 1;
  int totalCategories = 0;
  int totalPages = 1;
  final int itemsPerPage = 20;
  Timer? _searchDebounceTimer; // Add debounce timer for search
  bool _isFilterActive = false; // Track if any filter is currently active

  // Search and filter controllers
  final TextEditingController _searchController = TextEditingController();

  // Cache for all categories to avoid refetching
  List<Category> _allCategoriesCache = [];
  List<Category> _allFilteredCategories =
      []; // Store all filtered categories for local pagination

  // RouteObserver for navigation-based reloading
  final RouteObserver<ModalRoute<void>> _routeObserver =
      RouteObserver<ModalRoute<void>>();

  @override
  void initState() {
    super.initState();
    _fetchAllCategoriesOnInit(); // Fetch all categories once on page load
    _setupSearchListener();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final ModalRoute? route = ModalRoute.of(context);
    if (route != null) {
      _routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    _routeObserver.unsubscribe(this);
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didPopNext() {
    // Called when returning to this page from another page
    _refreshCategoriesAfterChange();
  }

  // ignore: unused_element
  Future<Uint8List?> _loadCategoryImage(String imagePath) async {
    try {
      // Extract filename from any path format
      String filename;
      if (imagePath.contains('/')) {
        // If it contains slashes, take the last part after the last /
        filename = imagePath.split('/').last;
      } else {
        // Use as is if no slashes
        filename = imagePath;
      }

      // Remove any query parameters
      if (filename.contains('?')) {
        filename = filename.split('?').first;
      }

      print('🖼️ Extracted filename: $filename from path: $imagePath');

      // Check if file exists in local categories directory
      final file = File('assets/images/categories/$filename');
      if (await file.exists()) {
        return await file.readAsBytes();
      } else {
        // Try to load from network if it's a valid URL
        if (imagePath.startsWith('http')) {
          // For now, return null to show default icon
          // In future, could implement network loading with caching
        }
      }
    } catch (e) {
      // Error loading image
    }
    return null;
  }

  Future<void> _fetchCategories({int page = 1}) async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await InventoryService.getCategories(
        page: page,
        limit: itemsPerPage,
      );

      setState(() {
        categories = response.data;
        currentPage = response.meta.currentPage;
        totalCategories = response.meta.total;
        totalPages = response.meta.lastPage;
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  // Fetch all categories once when page loads
  Future<void> _fetchAllCategoriesOnInit() async {
    final inventoryProvider = Provider.of<InventoryProvider>(
      context,
      listen: false,
    );

    if (inventoryProvider.categories.isNotEmpty) {
      print('� Using pre-fetched categories from provider');
      setState(() {
        _allCategoriesCache = inventoryProvider.categories;
      });
      _applyFiltersClientSide();
    } else {
      print('🚀 Pre-fetch not available, fetching categories');
      try {
        print('�🚀 Initial load: Fetching all categories');
        setState(() {
          errorMessage = null;
        });

        // Fetch all categories from all pages
        List<Category> allCategories = [];
        int currentFetchPage = 1;
        bool hasMorePages = true;

        while (hasMorePages) {
          try {
            print('📡 Fetching page $currentFetchPage');
            final response = await InventoryService.getCategories(
              page: currentFetchPage,
              limit: 50, // Use larger page size for efficiency
            );

            allCategories.addAll(response.data);
            print(
              '📦 Page $currentFetchPage: ${response.data.length} categories (total: ${allCategories.length})',
            );

            // Check if there are more pages
            if (response.meta.currentPage >= response.meta.lastPage) {
              hasMorePages = false;
            } else {
              currentFetchPage++;
            }
          } catch (e) {
            print('❌ Error fetching page $currentFetchPage: $e');
            hasMorePages = false; // Stop fetching on error
          }
        }

        _allCategoriesCache = allCategories;
        print('💾 Cached ${_allCategoriesCache.length} total categories');

        // Apply initial filters (which will be no filters, showing all categories)
        _applyFiltersClientSide();
      } catch (e) {
        print('❌ Critical error in _fetchAllCategoriesOnInit: $e');
        setState(() {
          errorMessage = 'Failed to load categories. Please refresh the page.';
          isLoading = false;
        });
      }
    }
  }

  // Force refresh categories from API (bypasses provider cache)
  Future<void> _refreshCategoriesAfterChange() async {
    print('🔄 Force refreshing categories from API after change');
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    try {
      // Fetch all categories from all pages (force fresh data)
      List<Category> allCategories = [];
      int currentFetchPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        try {
          print('📡 Force fetching page $currentFetchPage');
          final response = await InventoryService.getCategories(
            page: currentFetchPage,
            limit: 50, // Use larger page size for efficiency
          );

          allCategories.addAll(response.data);
          print(
            '📦 Force fetch page $currentFetchPage: ${response.data.length} categories (total: ${allCategories.length})',
          );

          // Check if there are more pages
          if (response.meta.currentPage >= response.meta.lastPage) {
            hasMorePages = false;
          } else {
            currentFetchPage++;
          }
        } catch (e) {
          print('❌ Error force fetching page $currentFetchPage: $e');
          hasMorePages = false; // Stop fetching on error
        }
      }

      _allCategoriesCache = allCategories;
      print('💾 Force cached ${_allCategoriesCache.length} total categories');

      // Apply current filters to the fresh data
      _applyFiltersClientSide();
    } catch (e) {
      print('❌ Critical error in _refreshCategoriesAfterChange: $e');
      setState(() {
        errorMessage = 'Failed to refresh categories. Please try again.';
        isLoading = false;
      });
    }
  }

  void _setupSearchListener() {
    _searchController.addListener(() {
      // Cancel previous timer
      _searchDebounceTimer?.cancel();

      // Set new timer for debounced search (500ms delay)
      _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
        print('🔍 Search triggered: "${_searchController.text}"');
        setState(() {
          currentPage = 1; // Reset to first page when search changes
        });
        // Apply filters when search changes
        _applyFilters();
      });
    });
  }

  // Client-side only filter application
  void _applyFilters() {
    print('🎯 _applyFilters called - performing client-side filtering only');
    _applyFiltersClientSide();
  }

  void _applyFiltersClientSide() {
    try {
      final searchText = _searchController.text.toLowerCase().trim();
      final hasSearch = searchText.isNotEmpty;

      print('🎯 Client-side filtering - search: "$searchText"');
      print('📊 hasSearch: $hasSearch');

      // Apply filters to cached categories (no API calls)
      _filterCachedCategories(searchText);

      // Update filter active state and trigger UI update
      setState(() {
        _isFilterActive = hasSearch;
      });

      print('🔄 _isFilterActive: $_isFilterActive');
      print('📦 _allCategoriesCache.length: ${_allCategoriesCache.length}');
      print(
        '🎯 _allFilteredCategories.length: ${_allFilteredCategories.length}',
      );
      print('👀 categories.length: ${categories.length}');
    } catch (e) {
      print('❌ Error in _applyFiltersClientSide: $e');
      setState(() {
        errorMessage = 'Search error: Please try a different search term';
        isLoading = false;
        categories = [];
      });
    }
  }

  // Filter cached categories without any API calls
  void _filterCachedCategories(String searchText) {
    try {
      print('🎯 Starting filtering with searchText: "$searchText"');
      print('📊 Total categories in cache: ${_allCategoriesCache.length}');

      // Apply filters to cached categories with enhanced error handling
      _allFilteredCategories = _allCategoriesCache.where((category) {
        try {
          // Search filter
          if (searchText.isEmpty) {
            return true;
          }

          // Search in multiple fields with better null safety and error handling
          final categoryTitle = category.title.toLowerCase();
          final categoryCode = category.categoryCode.toLowerCase();

          final matchesSearch =
              categoryTitle.contains(searchText) ||
              categoryCode.contains(searchText);

          if (!matchesSearch) {
            print(
              '❌ Filtering out category "${category.title}" - doesn\'t match search "$searchText"',
            );
          }

          return matchesSearch;
        } catch (e) {
          // If there's any error during filtering, exclude this category
          print('⚠️ Error filtering category ${category.id}: $e');
          return false;
        }
      }).toList();

      print(
        '🔍 After filtering: ${_allFilteredCategories.length} categories match criteria',
      );
      print('📝 Search text: "$searchText"');

      // Apply local pagination to filtered results
      _paginateFilteredCategories();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('❌ Critical error in _filterCachedCategories: $e');
      setState(() {
        errorMessage =
            'Search failed. Please try again with a simpler search term.';
        isLoading = false;
        // Fallback: show empty results instead of crashing
        categories = [];
        _allFilteredCategories = [];
      });
    }
  }

  // Apply local pagination to filtered categories
  void _paginateFilteredCategories() {
    try {
      // Handle empty results case
      if (_allFilteredCategories.isEmpty) {
        setState(() {
          categories = [];
          // Update pagination variables for pagination controls
          totalCategories = 0;
          totalPages = 1;
        });
        return;
      }

      final startIndex = (currentPage - 1) * itemsPerPage;
      final endIndex = startIndex + itemsPerPage;

      // Ensure startIndex is not greater than the list length
      if (startIndex >= _allFilteredCategories.length) {
        // Reset to page 1 if current page is out of bounds
        setState(() {
          currentPage = 1;
        });
        _paginateFilteredCategories(); // Recursive call with corrected page
        return;
      }

      setState(() {
        categories = _allFilteredCategories.sublist(
          startIndex,
          endIndex > _allFilteredCategories.length
              ? _allFilteredCategories.length
              : endIndex,
        );

        // Update pagination variables for pagination controls
        final calculatedTotalPages =
            (_allFilteredCategories.length / itemsPerPage).ceil();
        totalCategories = _allFilteredCategories.length;
        totalPages = calculatedTotalPages;

        print('📄 Pagination calculation:');
        print(
          '   📊 _allFilteredCategories.length: ${_allFilteredCategories.length}',
        );
        print('   📝 itemsPerPage: $itemsPerPage');
        print('   🔢 totalPages: $totalPages');
        print('   📍 currentPage: $currentPage');
      });
    } catch (e) {
      print('❌ Error in _paginateFilteredCategories: $e');
      setState(() {
        categories = [];
        currentPage = 1;
        totalCategories = 0;
        totalPages = 1;
      });
    }
  }

  // Handle page changes for both filtered and normal pagination
  Future<void> _changePage(int newPage) async {
    setState(() {
      currentPage = newPage;
    });

    // Always use client-side pagination when we have cached categories
    if (_allCategoriesCache.isNotEmpty) {
      _paginateFilteredCategories();
    } else {
      // Fallback to server pagination only if no cached data
      await _fetchCategories(page: newPage);
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
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D1845)),
                ),
                SizedBox(width: 16),
                Text('Fetching all categories...'),
              ],
            ),
          );
        },
      );

      // Always fetch ALL categories from database for export
      List<Category> allCategoriesForExport = [];

      try {
        // Fetch ALL categories with unlimited pagination
        allCategoriesForExport = [];
        int currentPage = 1;
        bool hasMorePages = true;

        while (hasMorePages) {
          final pageResponse = await InventoryService.getCategories(
            page: currentPage,
            limit: 100, // Fetch in chunks of 100
          );

          final categories = pageResponse.data;
          allCategoriesForExport.addAll(categories);

          // Check if there are more pages
          final totalItems = pageResponse.meta.total;
          final fetchedSoFar = allCategoriesForExport.length;

          if (fetchedSoFar >= totalItems) {
            hasMorePages = false;
          } else {
            currentPage++;
          }
        }
      } catch (e) {
        print('Error fetching all categories: $e');
        // Fallback to current data
        allCategoriesForExport = categories.isNotEmpty ? categories : [];
      }

      if (allCategoriesForExport.isEmpty) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No categories to export'),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D1845)),
                ),
                SizedBox(width: 16),
                Text(
                  'Generating PDF with ${allCategoriesForExport.length} categories...',
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
        13,
        24,
        69,
      ); // Categories theme color
      final PdfColor tableHeaderColor = PdfColor(248, 249, 250);

      // Create table with proper settings for pagination
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 2);

      // Use full page width but account for table borders and padding
      final double pageWidth =
          document.pageSettings.size.width -
          15; // Only 15px left margin, 0px right margin
      final double tableWidth =
          pageWidth *
          0.85; // Use 85% to ensure right boundary is clearly visible

      // Balanced column widths for categories
      grid.columns[0].width = tableWidth * 0.50; // 50% - Category Name
      grid.columns[1].width = tableWidth * 0.50; // 50% - Category Code

      // Enable automatic page breaking and row splitting
      grid.allowRowBreakingAcrossPages = true;

      // Set grid style with better padding for readability
      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 4, right: 4, top: 4, bottom: 4),
        font: smallFont,
      );

      // Add header row
      final PdfGridRow headerRow = grid.headers.add(1)[0];
      headerRow.cells[0].value = 'Category Name';
      headerRow.cells[1].value = 'Category Code';

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

      // Add all category data rows
      for (var category in allCategoriesForExport) {
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = category.title;
        row.cells[1].value = category.categoryCode;

        // Style data cells with better text wrapping
        for (int i = 0; i < row.cells.count; i++) {
          row.cells[i].style = PdfGridCellStyle(
            font: smallFont,
            textBrush: PdfSolidBrush(PdfColor(33, 37, 41)),
            format: PdfStringFormat(
              alignment: PdfTextAlignment.left,
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
        'Categories Database Export',
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
        'Total Categories: ${allCategoriesForExport.length} | Generated: ${DateTime.now().toString().substring(0, 19)} | Product Categories Report',
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
        'Page \$PAGE of \$TOTAL | ${allCategoriesForExport.length} Total Categories | Generated from POS System',
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
        'PDF generated with $pageCount page(s) for ${allCategoriesForExport.length} categories',
      );

      // Save PDF
      final List<int> bytes = await document.save();
      document.dispose();

      // Close loading dialog
      Navigator.of(context).pop();

      // Let user choose save location
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Categories Database PDF',
        fileName: 'categories_${DateTime.now().millisecondsSinceEpoch}.pdf',
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
                '✅ Categories Exported!\n📊 ${allCategoriesForExport.length} categories across $pageCount pages\n📄 Landscape format for better visibility',
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
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D1845)),
                ),
                SizedBox(width: 16),
                Text('Fetching all categories...'),
              ],
            ),
          );
        },
      );

      // Always fetch ALL categories from database for export
      List<Category> allCategoriesForExport = [];

      try {
        // Fetch ALL categories with unlimited pagination
        allCategoriesForExport = [];
        int currentPage = 1;
        bool hasMorePages = true;

        while (hasMorePages) {
          final pageResponse = await InventoryService.getCategories(
            page: currentPage,
            limit: 100, // Fetch in chunks of 100
          );

          final categories = pageResponse.data;
          allCategoriesForExport.addAll(categories);

          // Check if there are more pages
          final totalItems = pageResponse.meta.total;
          final fetchedSoFar = allCategoriesForExport.length;

          if (fetchedSoFar >= totalItems) {
            hasMorePages = false;
          } else {
            currentPage++;
          }
        }
      } catch (e) {
        print('Error fetching all categories: $e');
        // Fallback to current data
        allCategoriesForExport = categories.isNotEmpty ? categories : [];
      }

      if (allCategoriesForExport.isEmpty) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No categories to export'),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF0D1845)),
                ),
                SizedBox(width: 16),
                Text(
                  'Generating Excel with ${allCategoriesForExport.length} categories...',
                ),
              ],
            ),
          );
        },
      );

      // Create Excel document
      var excel = excel_pkg.Excel.createExcel();
      var sheet = excel['Categories'];

      // Add header row
      sheet.appendRow([
        excel_pkg.TextCellValue('Category Name'),
        excel_pkg.TextCellValue('Category Code'),
        excel_pkg.TextCellValue('Updated Date'),
      ]);

      // Style header row
      var headerStyle = excel_pkg.CellStyle(bold: true, fontSize: 12);

      for (int i = 0; i < 3; i++) {
        var cell = sheet.cell(
          excel_pkg.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.cellStyle = headerStyle;
      }

      // Add all category data rows
      for (var category in allCategoriesForExport) {
        // Format updated date
        String formattedUpdatedDate = 'N/A';
        try {
          final date = DateTime.parse(category.updatedAt);
          formattedUpdatedDate = '${date.day}/${date.month}/${date.year}';
        } catch (e) {
          // Keep default value
        }

        sheet.appendRow([
          excel_pkg.TextCellValue(category.title),
          excel_pkg.TextCellValue(category.categoryCode),
          excel_pkg.TextCellValue(formattedUpdatedDate),
        ]);
      }

      // Auto-fit columns
      for (int i = 0; i < 3; i++) {
        sheet.setColumnAutoFit(i);
      }

      // Save Excel file
      var fileBytes = excel.save();

      // Close loading dialog
      Navigator.of(context).pop();

      // Let user choose save location
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Categories Database Excel',
        fileName: 'categories_${DateTime.now().millisecondsSinceEpoch}.xlsx',
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile != null) {
        final file = File(outputFile);
        await file.writeAsBytes(fileBytes!);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '✅ Categories Exported!\n📊 ${allCategoriesForExport.length} categories exported to Excel\n📄 File saved successfully',
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
            content: Text('Excel export failed: ${e.toString()}'),
            backgroundColor: Color(0xFFDC3545),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void addNewCategory() async {
    await AddCategoryPage.show(context);

    // Always refresh the list after the dialog closes to ensure it's up to date
    // regardless of whether the operation was successful or cancelled
    await _refreshCategoriesAfterChange();
  }

  void deleteCategory(Category category) async {
    // First check if there are any sub-categories for this category
    try {
      setState(() => isLoading = true);

      final subCategoryResponse = await InventoryService.getSubCategories(
        limit: 1000,
      );
      final subCategoriesForCategory = subCategoryResponse.data
          .where((subCategory) => subCategory.categoryId == category.id)
          .toList();

      setState(() => isLoading = false);

      if (subCategoriesForCategory.isNotEmpty) {
        // Show dialog preventing deletion and asking to delete sub-categories first
        showDialog(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.warning, color: Color(0xFFFF6B35)),
                  SizedBox(width: 8),
                  Text('Cannot Delete Category'),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cannot delete "${category.title}" because it has ${subCategoriesForCategory.length} associated sub-categorie(s).',
                    style: TextStyle(color: Color(0xFF6C757D)),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Associated Sub-Categories:',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0D1845),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    constraints: BoxConstraints(maxHeight: 150),
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: subCategoriesForCategory.map((subCategory) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.subdirectory_arrow_right,
                                  size: 16,
                                  color: Color(0xFF6C757D),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    subCategory.title,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Color(0xFF495057),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Please delete all associated sub-categories first before deleting this category.',
                    style: TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Color(0xFFDC3545),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(),
                  child: Text('OK', style: TextStyle(color: Color(0xFF6C757D))),
                ),
              ],
            );
          },
        );
        return;
      }
    } catch (e) {
      setState(() => isLoading = false);
      print('Error checking sub-categories: $e');
      // Continue with normal delete dialog if we can't check sub-categories
    }

    // If no sub-categories found, show the normal delete dialog
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            bool isDeleting = false;

            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.warning, color: Color(0xFFDC3545)),
                  SizedBox(width: 8),
                  Text('Delete Category'),
                ],
              ),
              content: Text(
                'Are you sure you want to delete "${category.title}"?\n\nThis will also remove all associated products and sub-categories.',
                style: TextStyle(color: Color(0xFF6C757D)),
              ),
              actions: [
                TextButton(
                  onPressed: isDeleting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF6C757D)),
                  ),
                ),
                ElevatedButton(
                  onPressed: isDeleting
                      ? null
                      : () async {
                          setDialogState(() => isDeleting = true);

                          try {
                            // Attempt to delete from server first
                            await InventoryService.deleteCategory(category.id);

                            Navigator.of(
                              dialogContext,
                            ).pop(); // Close dialog first

                            // Remove from cache only - let filtering/pagination handle UI updates
                            _allCategoriesCache.removeWhere(
                              (item) => item.id == category.id,
                            );

                            // Also update provider cache to prevent stale data on refresh
                            final inventoryProvider =
                                Provider.of<InventoryProvider>(
                                  context,
                                  listen: false,
                                );
                            inventoryProvider.categories.removeWhere(
                              (item) => item.id == category.id,
                            );

                            // Re-apply current filters to the updated cache
                            _applyFiltersClientSide();

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.delete, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(
                                      'Category "${category.title}" deleted successfully',
                                    ),
                                  ],
                                ),
                                backgroundColor: Color(0xFFDC3545),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          } catch (e) {
                            Navigator.of(
                              dialogContext,
                            ).pop(); // Close dialog first

                            // Handle specific error cases
                            String errorMessage = 'Failed to delete category';
                            if (e.toString().contains('404')) {
                              errorMessage =
                                  'Category was already deleted or doesn\'t exist';
                            } else if (e.toString().contains('403') ||
                                e.toString().contains('401')) {
                              errorMessage =
                                  'You don\'t have permission to delete this category';
                            } else if (e.toString().contains('500')) {
                              errorMessage =
                                  'Server error occurred. Please try again later.';
                            } else {
                              errorMessage = e.toString().replaceFirst(
                                'Exception: ',
                                '',
                              );
                            }

                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.error, color: Colors.white),
                                    SizedBox(width: 8),
                                    Text(errorMessage),
                                  ],
                                ),
                                backgroundColor: Color(0xFFDC3545),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          }
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isDeleting
                        ? Colors.grey
                        : Color(0xFFDC3545),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: isDeleting
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text('Delete'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showCategoryDetailsDialog(int categoryId) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.8,
            height: MediaQuery.of(context).size.height * 0.8,
            child: CategoryDetailsDialog(categoryId: categoryId),
          ),
        );
      },
    );
  }

  void _showEditCategoryDialog(Category category) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.6,
            height: MediaQuery.of(context).size.height * 0.7,
            child: EditCategoryDialog(category: category),
          ),
        );
      },
    );

    if (result == true) {
      // Category was updated, refresh the list
      await _refreshCategoriesAfterChange();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Categories'),
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
            // Header with Summary Cards
            Container(
              padding: const EdgeInsets.all(8),
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
              margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.category,
                          color: Colors.white,
                          size: 18,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Categories',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.4,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Manage product categories',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: addNewCategory,
                        icon: const Icon(Icons.add, size: 14),
                        label: const Text('Add Category'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D1845),
                          foregroundColor: Colors.white,
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
                  const SizedBox(height: 8),
                  // Summary Cards
                  Row(
                    children: [
                      _buildSummaryCard(
                        'Total',
                        _allCategoriesCache.length.toString(),
                        Icons.category,
                        Colors.blue,
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
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Flexible(
                                flex: 1,
                                child: SizedBox(
                                  height: 32,
                                  child: TextField(
                                    controller: _searchController,
                                    style: const TextStyle(fontSize: 12),
                                    decoration: InputDecoration(
                                      hintText: 'Search categories...',
                                      hintStyle: const TextStyle(fontSize: 12),
                                      prefixIcon: const Icon(
                                        Icons.search,
                                        size: 16,
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      filled: true,
                                      fillColor: Colors.white,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                              SizedBox(
                                height: 28,
                                child: ElevatedButton.icon(
                                  onPressed: exportToPDF,
                                  icon: const Icon(
                                    Icons.picture_as_pdf,
                                    size: 14,
                                  ),
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
                              const SizedBox(width: 6),
                              SizedBox(
                                height: 28,
                                child: ElevatedButton.icon(
                                  onPressed: exportToExcel,
                                  icon: const Icon(Icons.table_chart, size: 14),
                                  label: const Text(
                                    'Excel',
                                    style: TextStyle(fontSize: 11),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
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
                          if (_isFilterActive) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0D1845).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.filter_list,
                                    size: 12,
                                    color: Color(0xFF0D1845),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Filters applied',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: Color(0xFF0D1845),
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  InkWell(
                                    onTap: () {
                                      setState(() {
                                        _searchController.clear();
                                        _isFilterActive = false;
                                      });
                                      _applyFilters();
                                    },
                                    child: const Icon(
                                      Icons.close,
                                      size: 12,
                                      color: Color(0xFF0D1845),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
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
                          // Category Name Column
                          Expanded(
                            flex: 3,
                            child: Text('Category Name', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          // Category Code Column
                          Expanded(
                            flex: 2,
                            child: Center(
                              child: Text(
                                'Category Code',
                                style: _headerStyle(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Actions Column - Fixed width
                          SizedBox(
                            width: 120,
                            child: Text('Actions', style: _headerStyle()),
                          ),
                        ],
                      ),
                    ),

                    // Table Body
                    Expanded(
                      child: isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : errorMessage != null
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
                                    onPressed: () =>
                                        _fetchCategories(page: currentPage),
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : categories.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.category_outlined,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No categories found',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: categories.length,
                              itemExtent: 32, // compact row height
                              physics: const AlwaysScrollableScrollPhysics(),
                              itemBuilder: (context, index) {
                                final category = categories[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 0,
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
                                      // Category Name Column
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          category.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0D1845),
                                            fontSize: 10,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Category Code Column
                                      Expanded(
                                        flex: 2,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 4,
                                              vertical: 1,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey[100],
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              category.categoryCode,
                                              style: const TextStyle(
                                                fontFamily: 'monospace',
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF495057),
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      // Actions Column
                                      SizedBox(
                                        width: 120,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.visibility,
                                                color: const Color(0xFF17A2B8),
                                                size: 14,
                                              ),
                                              onPressed: () =>
                                                  _showCategoryDetailsDialog(
                                                    category.id,
                                                  ),
                                              tooltip: 'View Details',
                                              padding: const EdgeInsets.only(
                                                right: 4,
                                              ),
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                            const SizedBox(width: 2),
                                            IconButton(
                                              icon: Icon(
                                                Icons.edit,
                                                color: Colors.blue,
                                                size: 14,
                                              ),
                                              onPressed: () =>
                                                  _showEditCategoryDialog(
                                                    category,
                                                  ),
                                              tooltip: 'Edit',
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                            const SizedBox(width: 2),
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                                size: 14,
                                              ),
                                              onPressed: () =>
                                                  deleteCategory(category),
                                              tooltip: 'Delete',
                                              padding: EdgeInsets.zero,
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                          ],
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
            if (categories.isNotEmpty && !isLoading) ...[
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
                    // Previous button
                    ElevatedButton.icon(
                      onPressed: currentPage > 1
                          ? () => _changePage(currentPage - 1)
                          : null,
                      icon: Icon(Icons.chevron_left, size: 14),
                      label: Text('Previous', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: currentPage > 1
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

                    // Page numbers
                    ..._buildPageButtons(),

                    const SizedBox(width: 8),

                    // Next button
                    ElevatedButton.icon(
                      onPressed: currentPage < totalPages
                          ? () => _changePage(currentPage + 1)
                          : null,
                      icon: Icon(Icons.chevron_right, size: 14),
                      label: Text('Next', style: TextStyle(fontSize: 11)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: currentPage < totalPages
                            ? const Color(0xFF0D1845)
                            : Colors.grey.shade300,
                        foregroundColor: currentPage < totalPages
                            ? Colors.white
                            : Colors.grey.shade600,
                        elevation: currentPage < totalPages ? 2 : 0,
                        side: currentPage < totalPages
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

                    // Page info
                    const SizedBox(width: 16),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        'Page $currentPage of $totalPages (${totalCategories} total)',
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

  List<Widget> _buildPageButtons() {
    // Show max 5 page buttons centered around current page
    const maxButtons = 5;
    final halfRange = maxButtons ~/ 2; // 2

    // Calculate desired start and end
    int startPage = (currentPage - halfRange).clamp(1, totalPages);
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
            onPressed: i == currentPage ? null : () => _changePage(i),
            style: ElevatedButton.styleFrom(
              backgroundColor: i == currentPage
                  ? const Color(0xFF0D1845)
                  : Colors.white,
              foregroundColor: i == currentPage
                  ? Colors.white
                  : const Color(0xFF6C757D),
              elevation: i == currentPage ? 2 : 0,
              side: i == currentPage
                  ? null
                  : const BorderSide(color: Color(0xFFDEE2E6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(28, 28),
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
