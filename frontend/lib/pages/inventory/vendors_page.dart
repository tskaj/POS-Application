import 'package:flutter/material.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:excel/excel.dart' as excel_pkg;
import '../../services/inventory_service.dart';
import '../../models/vendor.dart' as vendor;
import 'add_vendor_page.dart';
import 'view_vendor_page.dart';
import 'edit_vendor_page.dart';

class VendorsPage extends StatefulWidget {
  const VendorsPage({super.key});

  @override
  State<VendorsPage> createState() => _VendorsPageState();
}

class _VendorsPageState extends State<VendorsPage> {
  vendor.VendorResponse? vendorResponse;
  List<vendor.Vendor> _filteredVendors = [];
  List<vendor.Vendor> _allFilteredVendors =
      []; // Store all filtered vendors for local pagination
  List<vendor.Vendor> _allVendorsCache =
      []; // Cache for all vendors to avoid refetching
  bool isLoading = false; // Start with false to show UI immediately
  String? errorMessage;
  int currentPage = 1;
  final int itemsPerPage = 17;
  bool _isDeletingVendor = false; // Add this flag for delete loading state
  Timer? _searchDebounceTimer; // Add debounce timer for search
  bool _isFilterActive = false; // Track if any filter is currently active

  // Search and filter controllers
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchAllVendorsOnInit(); // Fetch all vendors once on page load
    _setupSearchListener();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchDebounceTimer?.cancel(); // Cancel timer on dispose
    super.dispose();
  }

  // Fetch all vendors once when page loads
  Future<void> _fetchAllVendorsOnInit() async {
    try {
      print('🚀 Initial load: Fetching all vendors');
      setState(() {
        errorMessage = null;
      });

      // Fetch all vendors from all pages
      List<vendor.Vendor> allVendors = [];
      int currentFetchPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        try {
          print('📡 Fetching page $currentFetchPage');
          final response = await InventoryService.getVendors(
            page: currentFetchPage,
            limit: 50, // Use larger page size for efficiency
          );

          allVendors.addAll(response.data);
          print(
            '📦 Page $currentFetchPage: ${response.data.length} vendors (total: ${allVendors.length})',
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

      _allVendorsCache = allVendors;
      print('💾 Cached ${_allVendorsCache.length} total vendors');

      // Sort vendors by creation date descending (newest first)
      _allVendorsCache.sort((a, b) {
        try {
          final dateA = DateTime.parse(a.createdAt);
          final dateB = DateTime.parse(b.createdAt);
          return dateB.compareTo(dateA); // Descending order (newest first)
        } catch (e) {
          // If parsing fails, maintain original order
          return 0;
        }
      });

      print('🔄 Sorted vendors by creation date (newest first)');

      // Apply initial filters (which will be no filters, showing all vendors)
      _applyFiltersClientSide();
    } catch (e) {
      print('❌ Critical error in _fetchAllVendorsOnInit: $e');
      setState(() {
        errorMessage = 'Failed to load vendors. Please refresh the page.';
        isLoading = false;
      });
    }
  }

  Future<void> _refreshVendorsAfterChange() async {
    print('🔄 Force refreshing vendors from API after change');
    try {
      setState(() {
        errorMessage = null;
      });

      // Store the current order (vendor IDs in order)
      final currentOrder = _allVendorsCache.map((v) => v.id).toList();

      // Fetch all vendors from all pages (force fresh data)
      List<vendor.Vendor> allVendors = [];
      int currentFetchPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        try {
          print('📡 Force fetching page $currentFetchPage');
          final response = await InventoryService.getVendors(
            page: currentFetchPage,
            limit: 50, // Use larger page size for efficiency
          );

          allVendors.addAll(response.data);
          print(
            '📦 Force fetch page $currentFetchPage: ${response.data.length} vendors (total: ${allVendors.length})',
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

      print('💾 Force cached ${allVendors.length} total vendors');

      // If we have a current order, maintain it; otherwise sort by creation date
      if (currentOrder.isNotEmpty) {
        // Create a map for quick lookup
        final vendorMap = {for (var v in allVendors) v.id: v};

        // Rebuild cache in the same order as before
        _allVendorsCache = [];
        for (var id in currentOrder) {
          if (vendorMap.containsKey(id)) {
            _allVendorsCache.add(vendorMap[id]!);
            vendorMap.remove(id); // Remove to track which are new
          }
        }

        // Add any new vendors at the top (not in the previous list)
        if (vendorMap.isNotEmpty) {
          final newVendors = vendorMap.values.toList();
          // Sort new vendors by creation date
          newVendors.sort((a, b) {
            try {
              final dateA = DateTime.parse(a.createdAt);
              final dateB = DateTime.parse(b.createdAt);
              return dateB.compareTo(dateA);
            } catch (e) {
              return 0;
            }
          });
          _allVendorsCache.insertAll(0, newVendors);
        }

        print(
          '🔄 Maintained vendor order with ${_allVendorsCache.length} vendors',
        );
      } else {
        // First load - sort by creation date descending (newest first)
        _allVendorsCache = allVendors;
        _allVendorsCache.sort((a, b) {
          try {
            final dateA = DateTime.parse(a.createdAt);
            final dateB = DateTime.parse(b.createdAt);
            return dateB.compareTo(dateA); // Descending order (newest first)
          } catch (e) {
            // If parsing fails, maintain original order
            return 0;
          }
        });
        print('🔄 Sorted vendors by creation date (newest first)');
      }

      // Apply current filters to the fresh data
      _applyFiltersClientSide();
    } catch (e) {
      print('❌ Critical error in _refreshVendorsAfterChange: $e');
      setState(() {
        errorMessage = 'Failed to refresh vendors. Please try again.';
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

  // Pure client-side filtering method
  void _applyFiltersClientSide() {
    try {
      final searchText = _searchController.text.toLowerCase().trim();

      print('🎯 Client-side filtering - search: "$searchText"');

      setState(() {
        _isFilterActive = searchText.isNotEmpty;
      });

      // Apply filters to cached vendors (no API calls)
      _filterCachedVendors(searchText);

      print('🔄 _isFilterActive: $_isFilterActive');
      print('📦 _allVendorsCache.length: ${_allVendorsCache.length}');
      print('🎯 _allFilteredVendors.length: ${_allFilteredVendors.length}');
      print('👀 _filteredVendors.length: ${_filteredVendors.length}');
    } catch (e) {
      print('❌ Error in _applyFiltersClientSide: $e');
      setState(() {
        errorMessage = 'Search error: Please try a different search term';
        isLoading = false;
        _filteredVendors = [];
      });
    }
  }

  // Filter cached vendors without any API calls
  void _filterCachedVendors(String searchText) {
    try {
      // Apply filters to cached vendors with enhanced error handling
      _allFilteredVendors = _allVendorsCache.where((vendor) {
        try {
          // Search filter
          if (searchText.isEmpty) {
            return true;
          }

          // Search in multiple fields with better null safety and error handling
          final vendorFullName = vendor.fullName.toLowerCase();
          final vendorCode = vendor.vendorCode.toLowerCase();
          final vendorFirstName = vendor.firstName.toLowerCase();
          final vendorLastName = vendor.lastName.toLowerCase();
          final vendorPhone = (vendor.phone ?? '').toLowerCase();
          final vendorAddress = vendor.address?.toLowerCase() ?? '';
          final vendorCity = vendor.city.title.toLowerCase();

          return vendorFullName.contains(searchText) ||
              vendorCode.contains(searchText) ||
              vendorFirstName.contains(searchText) ||
              vendorLastName.contains(searchText) ||
              vendorPhone.contains(searchText) ||
              vendorAddress.contains(searchText) ||
              vendorCity.contains(searchText);
        } catch (e) {
          // If there's any error during filtering, exclude this vendor
          print('⚠️ Error filtering vendor ${vendor.id}: $e');
          return false;
        }
      }).toList();

      print(
        '🔍 After filtering: ${_allFilteredVendors.length} vendors match criteria',
      );
      print('📝 Search text: "$searchText"');

      // Apply local pagination to filtered results
      _paginateFilteredVendors();

      setState(() {
        isLoading = false;
      });
    } catch (e) {
      print('❌ Critical error in _filterCachedVendors: $e');
      setState(() {
        errorMessage =
            'Search failed. Please try again with a simpler search term.';
        isLoading = false;
        // Fallback: show empty results instead of crashing
        _filteredVendors = [];
        _allFilteredVendors = [];
      });
    }
  }

  // NOTE: older duplicate sections may reference vendor.cnic; ensure other filters below use phone where appropriate.

  // Apply local pagination to filtered vendors
  void _paginateFilteredVendors() {
    try {
      // Handle empty results case
      if (_allFilteredVendors.isEmpty) {
        setState(() {
          _filteredVendors = [];
          // Update vendorResponse meta for pagination controls
          vendorResponse = vendor.VendorResponse(
            data: [],
            links: vendor.Links(),
            meta: vendor.Meta(
              currentPage: 1,
              lastPage: 1,
              links: [],
              path: "/vendors",
              perPage: itemsPerPage,
              total: 0,
            ),
          );
        });
        return;
      }

      final startIndex = (currentPage - 1) * itemsPerPage;
      final endIndex = startIndex + itemsPerPage;

      // Ensure startIndex is not greater than the list length
      if (startIndex >= _allFilteredVendors.length) {
        // Reset to page 1 if current page is out of bounds
        setState(() {
          currentPage = 1;
        });
        _paginateFilteredVendors(); // Recursive call with corrected page
        return;
      }

      setState(() {
        _filteredVendors = _allFilteredVendors.sublist(
          startIndex,
          endIndex > _allFilteredVendors.length
              ? _allFilteredVendors.length
              : endIndex,
        );

        // Update vendorResponse meta for pagination controls
        final totalPages = (_allFilteredVendors.length / itemsPerPage).ceil();
        print('📄 Pagination calculation:');
        print(
          '   📊 _allFilteredVendors.length: ${_allFilteredVendors.length}',
        );
        print('   📝 itemsPerPage: $itemsPerPage');
        print('   🔢 totalPages: $totalPages');
        print('   📍 currentPage: $currentPage');

        vendorResponse = vendor.VendorResponse(
          data: _filteredVendors,
          links: vendor.Links(), // Empty links for local pagination
          meta: vendor.Meta(
            currentPage: currentPage,
            lastPage: totalPages,
            links: [], // Empty links array for local pagination
            path: "/vendors", // Default path
            perPage: itemsPerPage,
            total: _allFilteredVendors.length,
          ),
        );
      });
    } catch (e) {
      print('❌ Error in _paginateFilteredVendors: $e');
      setState(() {
        _filteredVendors = [];
        currentPage = 1;
      });
    }
  }

  // Handle page changes for both filtered and normal pagination
  Future<void> _changePage(int newPage) async {
    setState(() {
      currentPage = newPage;
    });

    // Always use client-side pagination when we have cached vendors
    if (_allVendorsCache.isNotEmpty) {
      _paginateFilteredVendors();
    } else {
      // Fallback to server pagination only if no cached data
      await _fetchVendors(page: newPage);
    }
  }

  Future<void> _fetchVendors({int page = 1}) async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final response = await InventoryService.getVendors(
        page: page,
        limit: itemsPerPage,
      );
      setState(() {
        vendorResponse = response;
        currentPage = page;
        isLoading = false;
        _filteredVendors = response.data;
      });
    } catch (e) {
      setState(() {
        errorMessage = e.toString();
        isLoading = false;
      });
    }
  }

  Future<void> exportToPDF() async {
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
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF17A2B8)),
                ),
                SizedBox(width: 16),
                Text('Preparing export...'),
              ],
            ),
          );
        },
      );

      // Use cached vendors for export, apply current filters
      List<vendor.Vendor> allVendorsForExport = List.from(_allVendorsCache);

      // Apply filters if any are active
      if (_searchController.text.isNotEmpty) {
        final searchText = _searchController.text.toLowerCase().trim();
        allVendorsForExport = allVendorsForExport.where((vendor) {
          // Search filter
          if (searchText.isEmpty) {
            return true;
          }

          // Search in multiple fields
          return vendor.fullName.toLowerCase().contains(searchText) ||
              vendor.vendorCode.toLowerCase().contains(searchText) ||
              vendor.firstName.toLowerCase().contains(searchText) ||
              vendor.lastName.toLowerCase().contains(searchText) ||
              (vendor.phone ?? '').toLowerCase().contains(searchText) ||
              (vendor.address?.toLowerCase().contains(searchText) ?? false) ||
              vendor.city.title.toLowerCase().contains(searchText);
        }).toList();
      }

      if (allVendorsForExport.isEmpty) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No vendors to export'),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF17A2B8)),
                ),
                SizedBox(width: 16),
                Text(
                  'Generating PDF with ${allVendorsForExport.length} vendors...',
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
      final PdfColor headerColor = PdfColor(23, 162, 184);
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

      // Balanced column widths - remove status column
      grid.columns[0].width = tableWidth * 0.18; // Vendor Code
      grid.columns[1].width = tableWidth * 0.45; // Vendor Name
      grid.columns[2].width = tableWidth * 0.18; // Phone
      grid.columns[3].width = tableWidth * 0.19; // City

      // Enable automatic page breaking and row splitting
      grid.allowRowBreakingAcrossPages = true;

      // Set grid style with better padding for readability
      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 4, right: 4, top: 4, bottom: 4),
        font: smallFont,
      );

      // Add header row
      final PdfGridRow headerRow = grid.headers.add(1)[0];
      headerRow.cells[0].value = 'Vendor Code';
      headerRow.cells[1].value = 'Vendor Name';
      headerRow.cells[2].value = 'Phone';
      headerRow.cells[3].value = 'City';

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

      // Add all vendor data rows
      for (var vendorItem in allVendorsForExport) {
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = vendorItem.vendorCode;
        row.cells[1].value = vendorItem.fullName;
        row.cells[2].value = _formatPhoneDisplay(vendorItem.phone);
        row.cells[3].value = vendorItem.city.title;

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
        'Complete Vendors Database Export',
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
        'Total Vendors: ${allVendorsForExport.length} | Generated: ${DateTime.now().toString().substring(0, 19)} | Filters: ${_searchController.text.isNotEmpty ? 'Search="${_searchController.text}"' : 'None'}',
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
        'Page \$PAGE of \$TOTAL | ${allVendorsForExport.length} Total Vendors | Generated from POS System',
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
        'PDF generated with $pageCount page(s) for ${allVendorsForExport.length} vendors',
      );

      // Save PDF
      final List<int> bytes = await document.save();
      document.dispose();

      // Close loading dialog
      Navigator.of(context).pop();

      // Let user choose save location
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Complete Vendors Database PDF',
        fileName:
            'complete_vendors_${DateTime.now().millisecondsSinceEpoch}.pdf',
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
                '✅ Complete Database Exported!\n📊 ${allVendorsForExport.length} vendors across $pageCount pages\n📄 Landscape format for better visibility',
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
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF17A2B8)),
                ),
                SizedBox(width: 16),
                Text('Preparing export...'),
              ],
            ),
          );
        },
      );

      // Use cached vendors for export, apply current filters
      List<vendor.Vendor> allVendorsForExport = List.from(_allVendorsCache);

      // Apply filters if any are active
      if (_searchController.text.isNotEmpty) {
        final searchText = _searchController.text.toLowerCase().trim();
        allVendorsForExport = allVendorsForExport.where((vendor) {
          // Search filter
          if (searchText.isEmpty) {
            return true;
          }

          // Search in multiple fields
          return vendor.fullName.toLowerCase().contains(searchText) ||
              vendor.vendorCode.toLowerCase().contains(searchText) ||
              vendor.firstName.toLowerCase().contains(searchText) ||
              vendor.lastName.toLowerCase().contains(searchText) ||
              (vendor.phone ?? '').toLowerCase().contains(searchText) ||
              (vendor.address?.toLowerCase().contains(searchText) ?? false) ||
              vendor.city.title.toLowerCase().contains(searchText);
        }).toList();
      }

      if (allVendorsForExport.isEmpty) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No vendors to export'),
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
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF17A2B8)),
                ),
                SizedBox(width: 16),
                Text(
                  'Generating Excel with ${allVendorsForExport.length} vendors...',
                ),
              ],
            ),
          );
        },
      );

      // Create Excel document
      final excel_pkg.Excel excel = excel_pkg.Excel.createExcel();
      final excel_pkg.Sheet sheet = excel['Vendors'];

      // Add header row (Address removed)
      sheet.appendRow([
        excel_pkg.TextCellValue('Vendor Code'),
        excel_pkg.TextCellValue('Vendor Name'),
        excel_pkg.TextCellValue('Phone'),
        excel_pkg.TextCellValue('City'),
      ]);

      // Add data rows
      for (var vendorItem in allVendorsForExport) {
        sheet.appendRow([
          excel_pkg.TextCellValue(vendorItem.vendorCode),
          excel_pkg.TextCellValue(vendorItem.fullName),
          excel_pkg.TextCellValue(_formatPhoneDisplay(vendorItem.phone)),
          excel_pkg.TextCellValue(vendorItem.city.title),
        ]);
      }

      // Generate filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'vendors_export_$timestamp.xlsx';

      // Close loading dialog
      Navigator.of(context).pop();

      // Let user choose save location
      String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Vendors Excel Export',
        fileName: fileName,
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (outputFile != null) {
        // Save Excel file
        final List<int>? bytes = excel.encode();
        if (bytes != null) {
          final file = File(outputFile);
          await file.writeAsBytes(bytes);

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '✅ Excel Export Complete!\n📊 ${allVendorsForExport.length} vendors exported\n📄 File saved as: ${fileName.split('_').last}',
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

  void addNewVendor() async {
    final result = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => const AddVendorPage(),
    );

    if (result != null) {
      // Reset to first page to show newly added vendor at the top
      setState(() {
        currentPage = 1;
      });
      // Refresh the vendor cache after adding
      await _refreshVendorsAfterChange();
    }
  }

  void viewVendor(vendor.Vendor vendor) async {
    // Navigate to view vendor page
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ViewVendorPage(vendorData: vendor),
      ),
    );
  }

  void editVendor(vendor.Vendor vendorToEdit) async {
    final result = await EditVendorPage.show(context, vendorToEdit);

    if (result == true) {
      // Vendor was updated, refresh the full list to get updated data
      await _refreshVendorsAfterChange();
    }
  }

  void deleteVendor(vendor.Vendor vendor) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.warning, color: Color(0xFFDC3545), size: 24),
              SizedBox(width: 8),
              Text(
                'Delete Vendor',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF343A40),
                ),
              ),
            ],
          ),
          content: Text(
            'Are you sure you want to delete "${vendor.fullName}"?\n\nThis action cannot be undone.',
            style: TextStyle(color: Color(0xFF6C757D), fontSize: 14),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: Color(0xFF6C757D),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop(); // Close confirmation dialog

                // Set loading state
                setState(() {
                  _isDeletingVendor = true;
                });

                try {
                  await InventoryService.deleteVendor(vendor.id);

                  if (mounted) {
                    // Remove from cache and update UI in real-time
                    setState(() {
                      _allVendorsCache.removeWhere((v) => v.id == vendor.id);
                    });

                    // Re-apply current filters to update the display
                    _applyFiltersClientSide();

                    // If current page is now empty and we're not on page 1, go to previous page
                    if (_filteredVendors.isEmpty && currentPage > 1) {
                      setState(() {
                        currentPage = currentPage - 1;
                      });
                      _paginateFilteredVendors();
                    }

                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle, color: Colors.white),
                            SizedBox(width: 8),
                            Text(
                              'Vendor "${vendor.fullName}" deleted successfully',
                            ),
                          ],
                        ),
                        backgroundColor: Color(0xFF28A745),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    // Error occurred, but we'll just refresh the cache to show current state
                    _fetchAllVendorsOnInit();
                  }
                } finally {
                  if (mounted) {
                    setState(() {
                      _isDeletingVendor = false;
                    });
                  }
                }
              },
              child: Text(
                'Delete',
                style: TextStyle(
                  color: Color(0xFFDC3545),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: EdgeInsets.all(24),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('Vendors'),
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
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.business,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Vendors',
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Manage your supplier relationships and vendor information',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: addNewVendor,
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Add Vendor'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF0D1845),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Summary Cards
                      Row(
                        children: [
                          _buildSummaryCard(
                            'Total Vendors',
                            _allVendorsCache.length.toString(),
                            Icons.business,
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
                          padding: const EdgeInsets.all(16),
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
                                      height: 36,
                                      child: TextField(
                                        controller: _searchController,
                                        style: const TextStyle(fontSize: 13),
                                        decoration: InputDecoration(
                                          hintText:
                                              'Search by vendor name, code...',
                                          hintStyle: const TextStyle(
                                            fontSize: 12,
                                          ),
                                          prefixIcon: const Icon(
                                            Icons.search,
                                            size: 16,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
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
                                  const SizedBox(width: 8),
                                  SizedBox(
                                    height: 32,
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
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  SizedBox(
                                    height: 32,
                                    child: ElevatedButton.icon(
                                      onPressed: exportToExcel,
                                      icon: const Icon(
                                        Icons.table_chart,
                                        size: 14,
                                      ),
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
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
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
                              // Vendor Details Column
                              Expanded(
                                flex: 4,
                                child: Text(
                                  'Vendor Details',
                                  style: _headerStyle(),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Phone Column - Centered
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: Text('Phone', style: _headerStyle()),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // City Column
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: Text('City', style: _headerStyle()),
                                ),
                              ),
                              const SizedBox(width: 16),
                              // Actions Column - Fixed width to match body
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
                                        style: const TextStyle(
                                          color: Colors.grey,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                      const SizedBox(height: 16),
                                      ElevatedButton(
                                        onPressed: _fetchAllVendorsOnInit,
                                        child: const Text('Retry'),
                                      ),
                                    ],
                                  ),
                                )
                              : _filteredVendors.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.business,
                                        size: 48,
                                        color: Colors.grey,
                                      ),
                                      const SizedBox(height: 16),
                                      const Text(
                                        'No vendors found',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _filteredVendors.length,
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemExtent: 32,
                                  itemBuilder: (context, index) {
                                    final vendor = _filteredVendors[index];
                                    return Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
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
                                          // Vendor Details Column
                                          Expanded(
                                            flex: 4,
                                            child: Column(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  vendor.fullName,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w600,
                                                    color: Color(0xFF0D1845),
                                                    fontSize: 10,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                                Text(
                                                  'Code: ${vendor.vendorCode}',
                                                  style: TextStyle(
                                                    fontSize: 8,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          // Phone Column - Centered
                                          Expanded(
                                            flex: 1,
                                            child: Center(
                                              child: Text(
                                                _formatPhoneDisplay(
                                                  vendor.phone,
                                                ),
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w600,
                                                  color: Color(0xFF495057),
                                                  fontSize: 10,
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          // City Column
                                          Expanded(
                                            flex: 1,
                                            child: Center(
                                              child: Text(
                                                vendor.city.title,
                                                style: const TextStyle(
                                                  fontSize: 9,
                                                  color: Color(0xFF6C757D),
                                                ),
                                                textAlign: TextAlign.center,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
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
                                                  icon: const Icon(
                                                    Icons.visibility,
                                                    color: Color(0xFF17A2B8),
                                                    size: 14,
                                                  ),
                                                  onPressed: () =>
                                                      viewVendor(vendor),
                                                  tooltip: 'View Details',
                                                  padding:
                                                      const EdgeInsets.only(
                                                        right: 4,
                                                      ),
                                                  constraints:
                                                      const BoxConstraints(),
                                                ),
                                                const SizedBox(width: 2),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.edit,
                                                    color: Colors.blue,
                                                    size: 14,
                                                  ),
                                                  onPressed: () =>
                                                      editVendor(vendor),
                                                  tooltip: 'Edit',
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                ),
                                                const SizedBox(width: 2),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.delete,
                                                    color: Colors.red,
                                                    size: 14,
                                                  ),
                                                  onPressed: () =>
                                                      deleteVendor(vendor),
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
                if (_filteredVendors.isNotEmpty) ...[
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
                          label: Text(
                            'Previous',
                            style: TextStyle(fontSize: 11),
                          ),
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
                          onPressed:
                              (vendorResponse?.meta != null &&
                                  currentPage < vendorResponse!.meta.lastPage)
                              ? () => _changePage(currentPage + 1)
                              : null,
                          icon: Icon(Icons.chevron_right, size: 14),
                          label: Text('Next', style: TextStyle(fontSize: 11)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                (vendorResponse?.meta != null &&
                                    currentPage < vendorResponse!.meta.lastPage)
                                ? const Color(0xFF0D1845)
                                : Colors.grey.shade300,
                            foregroundColor:
                                (vendorResponse?.meta != null &&
                                    currentPage < vendorResponse!.meta.lastPage)
                                ? Colors.white
                                : Colors.grey.shade600,
                            elevation:
                                (vendorResponse?.meta != null &&
                                    currentPage < vendorResponse!.meta.lastPage)
                                ? 2
                                : 0,
                            side:
                                (vendorResponse?.meta != null &&
                                    currentPage < vendorResponse!.meta.lastPage)
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
                            'Page $currentPage of ${(vendorResponse?.meta != null ? vendorResponse!.meta.lastPage : 1)} (${vendorResponse?.meta != null ? vendorResponse!.meta.total : _filteredVendors.length} total)',
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
        ),

        // Loading overlay for delete operation
        if (_isDeletingVendor)
          Container(
            color: Colors.black.withOpacity(0.5),
            child: Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF17A2B8),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Deleting vendor...',
                      style: TextStyle(
                        color: const Color(0xFF343A40),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
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
    if (vendorResponse?.meta == null) {
      return [];
    }

    final meta = vendorResponse!.meta;
    final totalPages = meta.lastPage;
    final current = meta.currentPage;

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
            onPressed: i == current ? null : () => _changePage(i),
            style: ElevatedButton.styleFrom(
              backgroundColor: i == current
                  ? const Color(0xFF0D1845)
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

  // Format phone for display in table/export. Attempts to normalize common formats.
  String _formatPhoneDisplay(String? phone) {
    if (phone == null || phone.trim().isEmpty) return 'N/A';
    final p = phone.trim();
    if (p.startsWith('+')) return p;
    final digits = p.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length == 10) return '+92 $digits';
    if (digits.length == 11 && digits.startsWith('0'))
      return '+92 ${digits.substring(1)}';
    return p;
  }
}

class AddVendorDialog extends StatefulWidget {
  final VoidCallback onVendorAdded;

  const AddVendorDialog({super.key, required this.onVendorAdded});

  @override
  State<AddVendorDialog> createState() => _AddVendorDialogState();
}

class _AddVendorDialogState extends State<AddVendorDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _cnicController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _openingBalanceController = TextEditingController();
  String _selectedStatus = 'Active';
  int _selectedCityId = 1; // Default city ID
  bool _isLoading = false;
  Map<String, String> _fieldErrors = {}; // Store field-specific errors

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _cnicController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _openingBalanceController.dispose();
    super.dispose();
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
      _fieldErrors.clear(); // Clear previous field errors
    });

    try {
      final vendorData = {
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'cnic': _cnicController.text.trim(),
        'city_id': _selectedCityId,
        'email': _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        'phone': _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        'address': _addressController.text.trim().isNotEmpty
            ? _addressController.text.trim()
            : null,
        'status': _selectedStatus,
        'opening_balance': double.parse(_openingBalanceController.text.trim()),
      };

      // Remove null values
      vendorData.removeWhere((key, value) => value == null);

      await InventoryService.createVendor(vendorData);

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vendor added successfully!'),
            backgroundColor: Color(0xFF28A745),
            duration: Duration(seconds: 2),
          ),
        );
        widget.onVendorAdded();
      }
    } catch (e) {
      if (mounted) {
        String errorMessage = 'Failed to add vendor';
        bool hasFieldErrors = false;

        // Try to parse validation errors from the API response
        if (e.toString().contains('Inventory API failed')) {
          try {
            // Extract the response body from the error message
            final errorParts = e.toString().split(' - ');
            if (errorParts.length >= 2) {
              final responseBody = errorParts[1];
              final errorData = jsonDecode(responseBody);

              if (errorData is Map<String, dynamic>) {
                // Check for Laravel validation errors
                if (errorData.containsKey('errors') &&
                    errorData['errors'] is Map) {
                  final errors = errorData['errors'] as Map<String, dynamic>;
                  setState(() {
                    _fieldErrors.clear();
                    errors.forEach((field, messages) {
                      if (messages is List && messages.isNotEmpty) {
                        // Map API field names to form field names
                        String formField = field;
                        if (field == 'city_id') formField = 'city';
                        _fieldErrors[formField] = messages.first.toString();
                      }
                    });
                  });
                  hasFieldErrors = true;

                  // Clear CNIC field if there's a CNIC validation error
                  if (_fieldErrors.containsKey('cnic')) {
                    _cnicController.clear();
                  }

                  // Re-validate form to show field errors
                  _formKey.currentState!.validate();
                } else if (errorData.containsKey('message')) {
                  errorMessage = errorData['message'].toString();
                }
              }
            }
          } catch (parseError) {
            // If parsing fails, use the original error
            errorMessage = e.toString();
          }
        } else {
          errorMessage = e.toString();
        }

        // Only show snackbar if there are no field-specific errors
        if (!hasFieldErrors) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage),
              backgroundColor: Color(0xFFDC3545),
              duration: Duration(seconds: 4),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
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
                    color: Color(0xFF17A2B8).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.business,
                    color: Color(0xFF17A2B8),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Add New Vendor',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF343A40),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close, color: Color(0xFF6C757D), size: 20),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Form
            Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // First Name and Last Name Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _firstNameController,
                            decoration: InputDecoration(
                              labelText: 'First Name *',
                              hintText: 'Enter first name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (value) {
                              if (_fieldErrors.containsKey('first_name')) {
                                setState(() {
                                  _fieldErrors.remove('first_name');
                                });
                              }
                            },
                            validator: (value) {
                              if (_fieldErrors.containsKey('first_name')) {
                                return _fieldErrors['first_name'];
                              }
                              if (value == null || value.trim().isEmpty) {
                                return 'First name is required';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _lastNameController,
                            decoration: InputDecoration(
                              labelText: 'Last Name *',
                              hintText: 'Enter last name',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (value) {
                              if (_fieldErrors.containsKey('last_name')) {
                                setState(() {
                                  _fieldErrors.remove('last_name');
                                });
                              }
                            },
                            validator: (value) {
                              if (_fieldErrors.containsKey('last_name')) {
                                return _fieldErrors['last_name'];
                              }
                              if (value == null || value.trim().isEmpty) {
                                return 'Last name is required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // CNIC and Email Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _cnicController,
                            decoration: InputDecoration(
                              labelText: 'CNIC *',
                              hintText: '12345-1234567-1',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (value) {
                              if (_fieldErrors.containsKey('cnic')) {
                                setState(() {
                                  _fieldErrors.remove('cnic');
                                });
                              }
                            },
                            validator: (value) {
                              if (_fieldErrors.containsKey('cnic')) {
                                return _fieldErrors['cnic'];
                              }
                              if (value == null || value.trim().isEmpty) {
                                return 'CNIC is required';
                              }
                              // Basic CNIC format validation
                              final cnicRegex = RegExp(r'^\d{5}-\d{7}-\d{1}$');
                              if (!cnicRegex.hasMatch(value.trim())) {
                                return 'Invalid CNIC format';
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _emailController,
                            decoration: InputDecoration(
                              labelText: 'Email',
                              hintText: 'vendor@example.com',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            onChanged: (value) {
                              if (_fieldErrors.containsKey('email')) {
                                setState(() {
                                  _fieldErrors.remove('email');
                                });
                              }
                            },
                            validator: (value) {
                              if (_fieldErrors.containsKey('email')) {
                                return _fieldErrors['email'];
                              }
                              if (value != null && value.trim().isNotEmpty) {
                                final emailRegex = RegExp(
                                  r'^[a-zA-Z0-9.]+@[a-zA-Z0-9]+\.[a-zA-Z]+',
                                );
                                if (!emailRegex.hasMatch(value.trim())) {
                                  return 'Invalid email format';
                                }
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Phone and Status Row
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _phoneController,
                            decoration: InputDecoration(
                              labelText: 'Phone',
                              hintText: '+923001234567',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            keyboardType: TextInputType.phone,
                            onChanged: (value) {
                              if (_fieldErrors.containsKey('phone')) {
                                setState(() {
                                  _fieldErrors.remove('phone');
                                });
                              }
                            },
                            validator: (value) {
                              if (_fieldErrors.containsKey('phone')) {
                                return _fieldErrors['phone'];
                              }
                              return null;
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _selectedStatus,
                            decoration: InputDecoration(
                              labelText: 'Status *',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 12,
                              ),
                            ),
                            items: ['Active', 'Inactive'].map((status) {
                              return DropdownMenuItem(
                                value: status,
                                child: Text(status),
                              );
                            }).toList(),
                            onChanged: (value) {
                              if (value != null) {
                                setState(() {
                                  _selectedStatus = value;
                                  if (_fieldErrors.containsKey('status')) {
                                    _fieldErrors.remove('status');
                                  }
                                });
                              }
                            },
                            validator: (value) {
                              if (_fieldErrors.containsKey('status')) {
                                return _fieldErrors['status'];
                              }
                              if (value == null || value.isEmpty) {
                                return 'Status is required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Address
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: 'Address',
                        hintText: 'Enter vendor address',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      maxLines: 3,
                      onChanged: (value) {
                        if (_fieldErrors.containsKey('address')) {
                          setState(() {
                            _fieldErrors.remove('address');
                          });
                        }
                      },
                      validator: (value) {
                        if (_fieldErrors.containsKey('address')) {
                          return _fieldErrors['address'];
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),

                    // Opening Balance
                    TextFormField(
                      controller: _openingBalanceController,
                      decoration: InputDecoration(
                        labelText: 'Opening Balance *',
                        hintText: '0.00',
                        prefixText: 'Rs ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      keyboardType: TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      onChanged: (value) {
                        if (_fieldErrors.containsKey('opening_balance')) {
                          setState(() {
                            _fieldErrors.remove('opening_balance');
                          });
                        }
                      },
                      validator: (value) {
                        if (_fieldErrors.containsKey('opening_balance')) {
                          return _fieldErrors['opening_balance'];
                        }
                        if (value == null || value.trim().isEmpty) {
                          return 'Opening balance is required';
                        }
                        final balance = double.tryParse(value.trim());
                        if (balance == null) {
                          return 'Please enter a valid number';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),

                    // Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: _isLoading
                              ? null
                              : () => Navigator.of(context).pop(),
                          child: Text(
                            'Cancel',
                            style: TextStyle(
                              color: Color(0xFF6C757D),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton(
                          onPressed: _isLoading ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Color(0xFF17A2B8),
                            foregroundColor: Colors.white,
                            padding: EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Colors.white,
                                    ),
                                  ),
                                )
                              : Text('Add Vendor'),
                        ),
                      ],
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
}
