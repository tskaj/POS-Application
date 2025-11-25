import 'package:flutter/material.dart';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import '../../services/inventory_reporting_service.dart';
import '../../utils/string_extensions.dart';

enum InventoryReportType { inHand, history, sold }

class InventoryReportPage extends StatefulWidget {
  const InventoryReportPage({super.key});

  @override
  State<InventoryReportPage> createState() => _InventoryReportPageState();
}

class _InventoryReportPageState extends State<InventoryReportPage> {
  // Report type state
  InventoryReportType _currentReportType = InventoryReportType.inHand;

  // Data states
  List<InHandProduct> _inHandProducts = [];
  List<HistoryProduct> _historyProducts = [];
  List<SoldProduct> _soldProducts = [];
  List<dynamic> _selectedReports = [];
  bool _selectAll = false;
  bool _isLoading = true;
  String? _errorMessage;

  // Pagination
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  int _totalPages = 1;

  // Search
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  // Table scroll controller
  final ScrollController _tableScrollController = ScrollController();

  Future<void> _showProductDetailDialog(int productId) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          content: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.grey[600]!),
              ),
              SizedBox(width: 16),
              Text(
                'Loading product details...',
                style: TextStyle(color: Colors.black),
              ),
            ],
          ),
        );
      },
    );

    try {
      final productDetail = await InventoryReportingService.getProductDetail(
        productId,
      );

      // Close loading dialog
      Navigator.of(context).pop();

      // Show product detail dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 8,
            backgroundColor: Colors.white,
            child: Container(
              width: 700,
              // Keep a sane maximum height for the dialog, but make the
              // body scrollable so long content doesn't overflow the screen.
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.9,
              ),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey[200]!, width: 1),
              ),
              // Wrap the whole content in a scrollable area. Use a
              // ConstrainedBox to allow Column to size naturally while
              // staying within the dialog maxHeight.
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    // Ensure the inner column won't exceed this dialog
                    // maximum; this works nicely with the outer
                    // Container's maxHeight as well.
                    maxHeight: MediaQuery.of(context).size.height * 0.9,
                  ),
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
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[300]!),
                            ),
                            child: Icon(
                              Icons.inventory_2,
                              color: Colors.grey[700],
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Product Details',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                                Text(
                                  'ID: ${productDetail.product.id}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: Icon(Icons.close, color: Colors.grey[600]),
                            onPressed: () => Navigator.of(context).pop(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Product Info Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Text(
                            //   productDetail.product.title,
                            //   style: TextStyle(
                            //     fontSize: 18,
                            //     fontWeight: FontWeight.bold,
                            //     color: Colors.black87,
                            //   ),
                            // ),
                            Text(
                              productDetail.product.title
                                  .split(' ')
                                  .map(
                                    (word) => word.isNotEmpty
                                        ? '${word[0].toUpperCase()}${word.substring(1).toLowerCase()}'
                                        : '',
                                  )
                                  .join(' '),
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildInfoItem(
                                    'Vendor',
                                    productDetail.product.vendor.name
                                        .toTitleCase(),
                                    // productDetail.product.vendor.name,
                                    Icons.business,
                                  ),
                                ),
                                Expanded(
                                  child: _buildInfoItem(
                                    'Created',
                                    productDetail.product.createdAt,
                                    Icons.calendar_today,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Summary Cards
                      Row(
                        children: [
                          Expanded(
                            child: _buildSummaryDetailCard(
                              'Opening Stock',
                              productDetail.totals.openingStockQuantity,
                              Icons.inventory,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryDetailCard(
                              'Qty In',
                              productDetail.totals.qtyIn.toString(),
                              Icons.add_circle,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryDetailCard(
                              'Qty Out',
                              productDetail.totals.qtyOut.toString(),
                              Icons.remove_circle,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildSummaryDetailCard(
                              'Balance',
                              productDetail.totals.balanceQty.toString(),
                              Icons.balance,
                              Colors.purple,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Transactions Section
                      Text(
                        "Transaction's Detail",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Combined Transactions Table
                      Container(
                        constraints: BoxConstraints(maxHeight: 300),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Colors.grey[300]!,
                            width: 1,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: SingleChildScrollView(
                          child: DataTable(
                            headingRowColor: MaterialStateProperty.all(
                              Colors.grey[50],
                            ),
                            dataRowColor:
                                MaterialStateProperty.resolveWith<Color>((
                                  Set<MaterialState> states,
                                ) {
                                  if (states.contains(MaterialState.selected)) {
                                    return Colors.grey[100]!;
                                  }
                                  return Colors.white;
                                }),
                            columns: const [
                              DataColumn(
                                label: Text(
                                  'Date',
                                  // 'Transaction Date',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Transaction Type',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Qty In',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: Text(
                                  'Qty Out',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ],
                            rows: [
                              // All transactions from productDetails array
                              ...productDetail.productDetails.map((
                                transaction,
                              ) {
                                // Parse qty_in and qty_out to check which one has value
                                // Color based on transaction type
                                Color bgColor;
                                Color textColor;
                                if (transaction.transactionType
                                    .toLowerCase()
                                    .contains('purchase')) {
                                  bgColor = Colors.green[100]!;
                                  textColor = Colors.green[800]!;
                                } else if (transaction.transactionType
                                    .toLowerCase()
                                    .contains('sale')) {
                                  bgColor = Colors.orange[100]!;
                                  textColor = Colors.orange[800]!;
                                } else if (transaction.transactionType
                                    .toLowerCase()
                                    .contains('return')) {
                                  bgColor = Colors.red[100]!;
                                  textColor = Colors.red[800]!;
                                } else {
                                  bgColor = Colors.blue[100]!;
                                  textColor = Colors.blue[800]!;
                                }

                                return DataRow(
                                  cells: [
                                    DataCell(
                                      Text(
                                        transaction.createdAt,
                                        style: const TextStyle(fontSize: 12),
                                      ),
                                    ),
                                    DataCell(
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: bgColor,
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                        ),
                                        child: Text(
                                          transaction.transactionType,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // DataCell(
                                    //   Row(
                                    //     children: [
                                    //       Container(
                                    //         padding: const EdgeInsets.symmetric(
                                    //           horizontal: 8,
                                    //           vertical: 4,
                                    //         ),
                                    //         decoration: BoxDecoration(
                                    //           color: Colors.purple[100],
                                    //           borderRadius:
                                    //               BorderRadius.circular(4),
                                    //         ),
                                    //         child: Text(
                                    //           transaction.qtyIn,
                                    //           // style: TextStyle(
                                    //           //   fontWeight: FontWeight.bold,
                                    //           //   color: Colors.purple[800],
                                    //           //   fontSize: 12,
                                    //           // ),
                                    //         ),
                                    //       ),
                                    //     ],
                                    //   ),
                                    // ),
                                    DataCell(
                                      (transaction.qtyIn != "0" &&
                                              transaction.qtyIn != 0)
                                          ? Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  child: Text(
                                                    // remove decimals
                                                    double.tryParse(
                                                          transaction.qtyIn
                                                              .toString(),
                                                        )?.toInt().toString() ??
                                                        transaction.qtyIn
                                                            .toString(),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : const SizedBox.shrink(),
                                    ),

                                    DataCell(
                                      (transaction.qtyOut != "0" &&
                                              transaction.qtyOut != 0)
                                          ? Row(
                                              children: [
                                                Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  child: Text(
                                                    // remove decimals
                                                    double.tryParse(
                                                          transaction.qtyOut
                                                              .toString(),
                                                        )?.toInt().toString() ??
                                                        transaction.qtyOut
                                                            .toString(),
                                                  ),
                                                ),
                                              ],
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ],
                                );
                              }),
                            ],
                          ),
                        ),
                      ),

                      // Show message if no transactions
                      if (productDetail.productDetails.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            'No transactions found',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Error loading product details: $e')),
            ],
          ),
          backgroundColor: Color(0xFFDC3545),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryDetailCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.grey[700],
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportToPDF() async {
    try {
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

      final filteredReports = _getFilteredReports();

      if (filteredReports.isEmpty) {
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
      final PdfColor tableHeaderColor = PdfColor(248, 249, 250);

      final PdfPage page = document.pages.add();
      final PdfGraphics graphics = page.graphics;

      String reportTitle = '';
      switch (_currentReportType) {
        case InventoryReportType.inHand:
          reportTitle = 'Inventory Report - In Hand';
          break;
        case InventoryReportType.history:
          reportTitle = 'Inventory Report - History';
          break;
        case InventoryReportType.sold:
          reportTitle = 'Inventory Report - Stock Out';
          break;
      }

      graphics.drawString(
        reportTitle,
        titleFont,
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 30),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );

      graphics.drawString(
        'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
        smallFont,
        bounds: Rect.fromLTWH(0, 30, page.getClientSize().width, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      final PdfGrid grid = PdfGrid();

      switch (_currentReportType) {
        case InventoryReportType.inHand:
          grid.columns.add(count: 5);
          final double pageWidth = page.getClientSize().width;
          final double tableWidth = pageWidth * 0.95;
          grid.columns[0].width = tableWidth * 0.12; // ID
          grid.columns[1].width = tableWidth * 0.35; // Product Name
          grid.columns[2].width = tableWidth * 0.25; // Vendor
          grid.columns[3].width = tableWidth * 0.20; // Sub Category
          grid.columns[4].width = tableWidth * 0.08; // Quantity

          grid.style = PdfGridStyle(
            cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
            font: smallFont,
          );

          final PdfGridRow headerRow = grid.headers.add(1)[0];
          headerRow.cells[0].value = 'ID';
          headerRow.cells[1].value = 'Product Name';
          headerRow.cells[2].value = 'Vendor';
          headerRow.cells[3].value = 'Sub Category';
          headerRow.cells[4].value = 'Quantity';

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

          for (var product in filteredReports as List<InHandProduct>) {
            final PdfGridRow row = grid.rows.add();
            row.cells[0].value = product.id.toString();
            row.cells[1].value = _sanitizeProductName(product.productName);
            row.cells[2].value = product.vendor.vendorName;
            row.cells[3].value = product.subCategory.subCatName;
            row.cells[4].value = product.balanceStock;

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
          break;

        case InventoryReportType.history:
          grid.columns.add(count: 8);
          final double pageWidth = page.getClientSize().width;
          final double tableWidth = pageWidth * 0.95;
          grid.columns[0].width = tableWidth * 0.09; // ID
          grid.columns[1].width = tableWidth * 0.25; // Product Name
          grid.columns[2].width = tableWidth * 0.20; // Vendor
          grid.columns[3].width = tableWidth * 0.16; // Sub Category
          grid.columns[4].width = tableWidth * 0.09; // Opening
          grid.columns[5].width = tableWidth * 0.09; // Stock In
          grid.columns[6].width = tableWidth * 0.09; // Stock Out
          grid.columns[7].width = tableWidth * 0.03; // Balance

          grid.style = PdfGridStyle(
            cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
            font: smallFont,
          );

          final PdfGridRow headerRow = grid.headers.add(1)[0];
          headerRow.cells[0].value = 'ID';
          headerRow.cells[1].value = 'Product Name';
          headerRow.cells[2].value = 'Vendor';
          headerRow.cells[3].value = 'Sub Category';
          headerRow.cells[4].value = 'Opening';
          headerRow.cells[5].value = 'Stock In';
          headerRow.cells[6].value = 'Stock Out';
          headerRow.cells[7].value = 'Balance';

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

          for (var product in filteredReports as List<HistoryProduct>) {
            final PdfGridRow row = grid.rows.add();
            row.cells[0].value = product.id.toString();
            row.cells[1].value = _sanitizeProductName(product.productName);
            row.cells[2].value = product.vendor.vendorName;
            row.cells[3].value = product.subCategory.subCatName;
            row.cells[4].value = product.openingStock;
            row.cells[5].value = product.newStock;
            row.cells[6].value = product.soldStock;
            row.cells[7].value = product.balanceStock;

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
          break;

        case InventoryReportType.sold:
          grid.columns.add(count: 6);
          final double pageWidth = page.getClientSize().width;
          final double tableWidth = pageWidth * 0.95;
          grid.columns[0].width = tableWidth * 0.12; // ID
          grid.columns[1].width = tableWidth * 0.32; // Product Name
          grid.columns[2].width = tableWidth * 0.25; // Vendor
          grid.columns[3].width = tableWidth * 0.20; // Sub Category
          grid.columns[4].width = tableWidth * 0.08; // Stock Out
          grid.columns[5].width = tableWidth * 0.03; // Selling Price

          grid.style = PdfGridStyle(
            cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
            font: smallFont,
          );

          final PdfGridRow headerRow = grid.headers.add(1)[0];
          headerRow.cells[0].value = 'ID';
          headerRow.cells[1].value = 'Product Name';
          headerRow.cells[2].value = 'Vendor';
          headerRow.cells[3].value = 'Sub Category';
          headerRow.cells[4].value = 'Stock Out';
          headerRow.cells[5].value = 'Selling Price';

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

          for (var product in filteredReports as List<SoldProduct>) {
            final PdfGridRow row = grid.rows.add();
            row.cells[0].value = product.id.toString();
            row.cells[1].value = _sanitizeProductName(product.productName);
            row.cells[2].value = product.vendor.vendorName;
            row.cells[3].value = product.subCategory.subCatName;
            row.cells[4].value = product.stockOut;
            row.cells[5].value = 'Rs. ${product.salePrice}';

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
          break;
      }

      grid.draw(
        page: page,
        bounds: Rect.fromLTWH(
          0,
          60,
          page.getClientSize().width,
          page.getClientSize().height - 60,
        ),
      );

      final List<int> bytes = await document.save();
      document.dispose();

      // Close generating dialog
      Navigator.of(context).pop();

      // Show message to minimize application
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Minimize application to save PDF',
                  style: TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
          backgroundColor: Color(0xFF0D1845),
          duration: Duration(seconds: 4),
          behavior: SnackBarBehavior.floating,
        ),
      );

      String? outputPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Inventory Report PDF',
        fileName:
            'inventory_report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      if (outputPath != null) {
        final File file = File(outputPath);
        await file.writeAsBytes(bytes);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('PDF exported successfully'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(child: Text('Error exporting PDF: $e')),
            ],
          ),
          backgroundColor: Color(0xFFDC3545),
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _loadInventoryReport();
  }

  @override
  void dispose() {
    _searchController.dispose();
    _tableScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadInventoryReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      switch (_currentReportType) {
        case InventoryReportType.inHand:
          final response = await InventoryReportingService.getInHandProducts();
          _inHandProducts = response.data;
          break;
        case InventoryReportType.history:
          final response = await InventoryReportingService.getHistoryProducts();
          _historyProducts = response.data;
          break;
        case InventoryReportType.sold:
          final response = await InventoryReportingService.getSoldProducts();
          _soldProducts = response.data;
          break;
      }
      // Calculate total pages and reset pagination
      final totalItems = _getTotalItems();
      _totalPages = (totalItems / _itemsPerPage).ceil();
      _currentPage = 1;
      _selectedReports.clear();
      _selectAll = false;
      _updateSelectAllState(); // Recalculate based on current filters
    } catch (e) {
      _errorMessage = 'Failed to load inventory report: $e';
      // Set mock data for testing
      _setMockData();
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _changeReportType(InventoryReportType reportType) {
    if (_currentReportType != reportType) {
      setState(() {
        _currentReportType = reportType;
        _isLoading = true; // Show loading while switching report types
        _selectedReports.clear();
        _selectAll = false;
        _currentPage = 1; // Reset to first page when changing report type
      });
      // Reset table scroll position
      _tableScrollController.jumpTo(0.0);
      _loadInventoryReport();
    }
  }

  void _toggleReportSelection(dynamic report) {
    setState(() {
      final reportId = _getReportId(report);
      final existingIndex = _selectedReports.indexWhere(
        (r) => _getReportId(r) == reportId,
      );

      if (existingIndex >= 0) {
        _selectedReports.removeAt(existingIndex);
      } else {
        _selectedReports.add(report);
      }

      _updateSelectAllState();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectAll) {
        _selectedReports.clear();
      } else {
        _selectedReports = List.from(_getFilteredReports());
      }
      _selectAll = !_selectAll;
    });
  }

  void _updateSelectAllState() {
    final filteredReports = _getFilteredReports();
    final paginatedReports = _getPaginatedReports(filteredReports);
    _selectAll =
        paginatedReports.isNotEmpty &&
        _selectedReports.length == paginatedReports.length;

    // Recalculate total pages based on filtered reports
    _totalPages = (filteredReports.length / _itemsPerPage).ceil();
    if (_currentPage > _totalPages && _totalPages > 0) {
      _currentPage = _totalPages;
    }
  }

  int _getTotalItems() {
    switch (_currentReportType) {
      case InventoryReportType.inHand:
        return _inHandProducts.length;
      case InventoryReportType.history:
        return _historyProducts.length;
      case InventoryReportType.sold:
        return _soldProducts.length;
    }
  }

  void _setMockData() {
    // Generate mock data for testing pagination
    _inHandProducts = List.generate(
      25,
      (index) => InHandProduct(
        id: index + 1,
        productName: 'Product ${index + 1}',
        barcode: 'BAR${(index + 1).toString().padLeft(6, '0')}',
        designCode: 'DC${(index + 1).toString().padLeft(3, '0')}',
        imagePath: null,
        category: Category(
          id: (index % 3) + 1,
          categoryName: index % 3 == 0
              ? 'Bridal'
              : index % 3 == 1
              ? 'Fancy'
              : 'Traditional',
        ),
        subCategory: SubCategory(
          id: (index % 5) + 1,
          subCatName: 'Sub${(index % 5) + 1}',
        ),
        balanceStock: '${50 + index}',
        vendor: Vendor(
          id: (index % 4) + 1,
          vendorName: 'Vendor ${(index % 4) + 1}',
        ),
        productStatus: index % 4 == 0 ? 'Inactive' : 'Active',
      ),
    );

    _historyProducts = List.generate(
      25,
      (index) => HistoryProduct(
        id: index + 1,
        productName: 'Product ${index + 1}',
        barcode: 'BAR${(index + 1).toString().padLeft(6, '0')}',
        designCode: 'DC${(index + 1).toString().padLeft(3, '0')}',
        imagePath: null,
        category: Category(
          id: (index % 3) + 1,
          categoryName: index % 3 == 0
              ? 'Bridal'
              : index % 3 == 1
              ? 'Fancy'
              : 'Traditional',
        ),
        subCategory: SubCategory(
          id: (index % 5) + 1,
          subCatName: 'Sub${(index % 5) + 1}',
        ),
        salePrice: '${(index + 1) * 100}.00',
        openingStock: '${100 + index}',
        newStock: '${20 + index}',
        soldStock: '${15 + index}',
        balanceStock: '${105 + index}',
        vendor: Vendor(
          id: (index % 4) + 1,
          vendorName: 'Vendor ${(index % 4) + 1}',
        ),
        productStatus: index % 4 == 0 ? 'Inactive' : 'Active',
      ),
    );

    _soldProducts = List.generate(
      25,
      (index) => SoldProduct(
        id: index + 1,
        productName: 'Product ${index + 1}',
        barcode: 'BAR${(index + 1).toString().padLeft(6, '0')}',
        designCode: 'DC${(index + 1).toString().padLeft(3, '0')}',
        imagePath: null,
        category: Category(
          id: (index % 3) + 1,
          categoryName: index % 3 == 0
              ? 'Bridal'
              : index % 3 == 1
              ? 'Fancy'
              : 'Traditional',
        ),
        subCategory: SubCategory(
          id: (index % 5) + 1,
          subCatName: 'Sub${(index % 5) + 1}',
        ),
        salePrice: '${(index + 1) * 100}.00',
        stockOut: '${10 + index}',
        vendor: Vendor(
          id: (index % 4) + 1,
          vendorName: 'Vendor ${(index % 4) + 1}',
        ),
        productStatus: index % 4 == 0 ? 'Inactive' : 'Active',
      ),
    );

    final totalItems = _getTotalItems();
    _totalPages = (totalItems / _itemsPerPage).ceil();
    _currentPage = 1;
    _selectedReports.clear();
    _selectAll = false;
    _updateSelectAllState(); // Recalculate based on current filters
  }

  dynamic _getReportId(dynamic report) {
    switch (_currentReportType) {
      case InventoryReportType.inHand:
        return (report as InHandProduct).id;
      case InventoryReportType.history:
        return (report as HistoryProduct).id;
      case InventoryReportType.sold:
        return (report as SoldProduct).id;
    }
  }

  List<dynamic> _getFilteredReports() {
    List<dynamic> reports;
    switch (_currentReportType) {
      case InventoryReportType.inHand:
        reports = _inHandProducts;
        break;
      case InventoryReportType.history:
        reports = _historyProducts;
        break;
      case InventoryReportType.sold:
        reports = _soldProducts;
        break;
    }

    // Apply filtering
    return reports.where((report) {
      bool searchMatch = _searchQuery.isEmpty;
      if (!searchMatch) {
        searchMatch = report.productName.toLowerCase().contains(_searchQuery);
      }

      return searchMatch;
    }).toList();
  }

  List<dynamic> _getPaginatedReports(List<dynamic> reports) {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return reports.sublist(
      startIndex,
      endIndex > reports.length ? reports.length : endIndex,
    );
  }

  String _getReportTitle() {
    switch (_currentReportType) {
      case InventoryReportType.inHand:
        return 'In Hand Inventory';
      case InventoryReportType.history:
        return 'Inventory History';
      case InventoryReportType.sold:
        return 'Stock Out Items';
    }
  }

  String _getReportDescription() {
    switch (_currentReportType) {
      case InventoryReportType.inHand:
        return 'Current stock levels and inventory status';
      case InventoryReportType.history:
        return 'Stock movement history and transactions';
      case InventoryReportType.sold:
        return 'Items that have been moved out of stock';
    }
  }

  IconData _getReportIcon() {
    switch (_currentReportType) {
      case InventoryReportType.inHand:
        return Icons.inventory_2;
      case InventoryReportType.history:
        return Icons.history;
      case InventoryReportType.sold:
        return Icons.shopping_cart;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadInventoryReport,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final filteredReports = _getFilteredReports();
    final paginatedReports = _getPaginatedReports(filteredReports);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Report'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Inventory Report',
            onPressed: () async {
              setState(() => _isLoading = true);
              await _loadInventoryReport();
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
                        child: Icon(
                          _getReportIcon(),
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
                              _getReportTitle(),
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              _getReportDescription(),
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
                        'Total Products',
                        '${filteredReports.length}',
                        Icons.inventory_2,
                        Colors.blue,
                      ),
                      _buildSummaryCard(
                        'Total Stock',
                        '${_calculateTotalStock(filteredReports)}',
                        Icons.warehouse,
                        Colors.green,
                      ),
                      _buildSummaryCard(
                        'Out of Stock',
                        '${_calculateOutOfStockItems(filteredReports)}',
                        Icons.cancel,
                        Colors.red,
                      ),
                      _buildSummaryCard(
                        'Low Stock',
                        '${_calculateLowStockItems(filteredReports)}',
                        Icons.warning,
                        Colors.orange,
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
                          // Report Type Tabs
                          _buildTabButton(
                            'In Hand',
                            InventoryReportType.inHand,
                          ),
                          const SizedBox(width: 8),
                          _buildTabButton(
                            'History',
                            InventoryReportType.history,
                          ),
                          const SizedBox(width: 8),
                          _buildTabButton(
                            'Stock Out',
                            InventoryReportType.sold,
                          ),
                          const SizedBox(width: 16),
                          // Search Bar
                          SizedBox(
                            width: 200,
                            height: 28,
                            child: TextField(
                              controller: _searchController,
                              style: const TextStyle(fontSize: 12),
                              decoration: InputDecoration(
                                hintText: 'Search products...',
                                hintStyle: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                ),
                                prefixIcon: const Icon(Icons.search, size: 16),
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
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value.toLowerCase();
                                  _currentPage = 1;
                                  _updateSelectAllState();
                                });
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
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

                    // Table Section
                    Expanded(child: _buildTableSection(paginatedReports)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, InventoryReportType reportType) {
    final isSelected = _currentReportType == reportType;
    return ElevatedButton(
      onPressed: () => _changeReportType(reportType),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? const Color(0xFF0D1845) : Colors.white,
        foregroundColor: isSelected ? Colors.white : const Color(0xFF0D1845),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
        elevation: isSelected ? 2 : 0,
        side: BorderSide(
          color: isSelected ? const Color(0xFF0D1845) : Colors.grey.shade300,
          width: 1,
        ),
      ),
      child: Text(title, style: const TextStyle(fontSize: 12)),
    );
  }

  Widget _buildTableSection(List<dynamic> paginatedReports) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F9FA),
              border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
            ),
            child: Row(
              children: [
                // Select Column
                SizedBox(
                  width: 40,
                  child: Checkbox(
                    value: _selectAll,
                    onChanged: (value) => _toggleSelectAll(),
                    activeColor: Color(0xFF0D1845),
                  ),
                ),
                const SizedBox(width: 16),
                // Dynamic columns based on report type
                ..._getTableHeaderColumns(),
              ],
            ),
          ),

          // Table Body
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : paginatedReports.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(_getReportIcon(), size: 48, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(
                          'No inventory records found',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: _tableScrollController,
                    itemCount: paginatedReports.length,
                    itemBuilder: (context, index) {
                      final report = paginatedReports[index];
                      final isSelected = _selectedReports.any(
                        (r) => _getReportId(r) == _getReportId(report),
                      );
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
                            bottom: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Select Column
                            SizedBox(
                              width: 40,
                              child: Checkbox(
                                value: isSelected,
                                onChanged: (value) =>
                                    _toggleReportSelection(report),
                                activeColor: Color(0xFF0D1845),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Dynamic row content based on report type
                            ..._getTableRowColumns(report, isSelected),
                          ],
                        ),
                      );
                    },
                  ),
          ),

          // Pagination Controls within table
          _buildPaginationControls(),
        ],
      ),
    );
  }

  TextStyle _headerStyle() {
    return const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      color: Color(0xFF0D1845),
    );
  }

  List<Widget> _getTableHeaderColumns() {
    switch (_currentReportType) {
      case InventoryReportType.inHand:
        return [
          // Product ID Column
          Expanded(
            flex: 1,
            child: Center(child: Text('ID', style: _headerStyle())),
          ),
          const SizedBox(width: 16),
          // Product Name Column
          Expanded(flex: 2, child: Text('Product Name', style: _headerStyle())),
          const SizedBox(width: 16),
          // Vendor Column
          Expanded(flex: 2, child: Text('Vendor', style: _headerStyle())),
          const SizedBox(width: 16),
          // Sub Category Column
          Expanded(flex: 2, child: Text('Sub Category', style: _headerStyle())),
          const SizedBox(width: 16),
          // Quantity Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: Text('Quantity', style: _headerStyle())),
          ),
          const SizedBox(width: 16),
          // Action Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: Text('Action', style: _headerStyle())),
          ),
        ];
      case InventoryReportType.history:
        return [
          // Product ID Column
          Expanded(
            flex: 1,
            child: Center(child: Text('ID', style: _headerStyle())),
          ),
          const SizedBox(width: 16),
          // Product Name Column
          Expanded(flex: 2, child: Text('Product Name', style: _headerStyle())),
          const SizedBox(width: 16),
          // Vendor Column
          Expanded(flex: 2, child: Text('Vendor', style: _headerStyle())),
          const SizedBox(width: 16),
          // Sub Category Column
          Expanded(flex: 2, child: Text('Sub Category', style: _headerStyle())),
          const SizedBox(width: 16),
          // Opening Stock Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: Text('Opening', style: _headerStyle())),
          ),
          const SizedBox(width: 16),
          // Stock In Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: Text('Stock In', style: _headerStyle())),
          ),
          const SizedBox(width: 16),
          // Stock Out Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: Text('Stock Out', style: _headerStyle())),
          ),
          const SizedBox(width: 16),
          // Balance Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: Text('Balance', style: _headerStyle())),
          ),
          const SizedBox(width: 16),
          // Action Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: Text('Action', style: _headerStyle())),
          ),
        ];
      case InventoryReportType.sold:
        return [
          // Product ID Column
          Expanded(
            flex: 1,
            child: Center(child: Text('ID', style: _headerStyle())),
          ),
          const SizedBox(width: 16),
          // Product Name Column
          Expanded(flex: 2, child: Text('Product Name', style: _headerStyle())),
          const SizedBox(width: 16),
          // Vendor Column
          Expanded(flex: 2, child: Text('Vendor', style: _headerStyle())),
          const SizedBox(width: 16),
          // Sub Category Column
          Expanded(flex: 2, child: Text('Sub Category', style: _headerStyle())),
          const SizedBox(width: 16),
          // Stock Out Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: Text('Stock Out', style: _headerStyle())),
          ),
          const SizedBox(width: 16),
          // Selling Price Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: Text('Selling Price', style: _headerStyle())),
          ),
          const SizedBox(width: 16),
          // Action Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: Text('Action', style: _headerStyle())),
          ),
        ];
    }
  }

  List<Widget> _getTableRowColumns(dynamic report, bool isSelected) {
    switch (_currentReportType) {
      case InventoryReportType.inHand:
        final product = report as InHandProduct;
        return [
          // Product ID Column
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                product.id.toString(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D1845),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Product Name Column
          Expanded(
            flex: 2,
            child: Text(
              _sanitizeProductName(product.productName),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF495057),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          // Vendor Column
          Expanded(
            flex: 2,
            child: Text(
              product.vendor.vendorName,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF495057),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          // Sub Category Column
          Expanded(
            flex: 2,
            child: _buildSubCategoryCell(product.subCategory.subCatName),
          ),
          const SizedBox(width: 16),
          // Quantity Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: _buildStockCell(product.balanceStock)),
          ),
          const SizedBox(width: 16),
          // Action Column - Centered
          Expanded(
            flex: 1,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.visibility, color: Color(0xFF0D1845)),
                iconSize: 18,
                tooltip: 'View Details',
                onPressed: () => _showProductDetailDialog(product.id),
              ),
            ),
          ),
        ];
      case InventoryReportType.history:
        final product = report as HistoryProduct;
        return [
          // Product ID Column
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                product.id.toString(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D1845),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Product Name Column
          Expanded(
            flex: 2,
            child: Text(
              _sanitizeProductName(product.productName),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF495057),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          // Vendor Column
          Expanded(
            flex: 2,
            child: Text(
              product.vendor.vendorName,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF495057),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          // Sub Category Column
          Expanded(
            flex: 2,
            child: _buildSubCategoryCell(product.subCategory.subCatName),
          ),
          const SizedBox(width: 16),
          // Opening Stock Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: _buildStockCell(product.openingStock)),
          ),
          const SizedBox(width: 16),
          // Stock In Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: _buildStockCell(product.newStock)),
          ),
          const SizedBox(width: 16),
          // Stock Out Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: _buildStockCell(product.soldStock)),
          ),
          const SizedBox(width: 16),
          // Balance Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: _buildStockCell(product.balanceStock)),
          ),
          const SizedBox(width: 16),
          // Action Column - Centered
          Expanded(
            flex: 1,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.visibility, color: Color(0xFF0D1845)),
                iconSize: 18,
                tooltip: 'View Details',
                onPressed: () => _showProductDetailDialog(product.id),
              ),
            ),
          ),
        ];
      case InventoryReportType.sold:
        final product = report as SoldProduct;
        return [
          // Product ID Column
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                product.id.toString(),
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D1845),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Product Name Column
          Expanded(
            flex: 2,
            child: Text(
              _sanitizeProductName(product.productName),
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF495057),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          // Vendor Column
          Expanded(
            flex: 2,
            child: Text(
              product.vendor.vendorName,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w500,
                color: Color(0xFF495057),
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          // Sub Category Column
          Expanded(
            flex: 2,
            child: _buildSubCategoryCell(product.subCategory.subCatName),
          ),
          const SizedBox(width: 16),
          // Stock Out Column - Centered
          Expanded(
            flex: 1,
            child: Center(child: _buildStockCell(product.stockOut)),
          ),
          const SizedBox(width: 16),
          // Selling Price Column - Centered
          Expanded(
            flex: 1,
            child: Center(
              child: Text(
                'Rs. ${product.salePrice}',
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0D1845),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Action Column - Centered
          Expanded(
            flex: 1,
            child: Center(
              child: IconButton(
                icon: const Icon(Icons.visibility, color: Color(0xFF0D1845)),
                iconSize: 18,
                tooltip: 'View Details',
                onPressed: () => _showProductDetailDialog(product.id),
              ),
            ),
          ),
        ];
    }
  }

  // Normalize product name to avoid showing appended ids or map-like strings.
  // If the API sometimes returns names like "Product Name (123)" or
  // "Product Name - 123", this will strip the trailing id part and return
  // only the human-readable name.
  String _sanitizeProductName(String name) {
    if (name.isEmpty) return name;

    // If the name looks like a Dart Map string (contains '{' or '}'),
    // try to extract a 'name' or 'title' token via simple heuristics.
    if (name.contains('{') && name.contains('}')) {
      // remove braces and try to find "name: ..." or "title: ..."
      final inner = name.replaceAll('{', '').replaceAll('}', '');
      final parts = inner.split(',');
      for (var part in parts) {
        final kv = part.split(':');
        if (kv.length >= 2) {
          final key = kv[0].trim().toLowerCase();
          final value = kv.sublist(1).join(':').trim();
          if (key.contains('name') || key.contains('title')) {
            var cleaned = value;
            if (cleaned.startsWith('"') || cleaned.startsWith("'")) {
              cleaned = cleaned.substring(1);
            }
            if (cleaned.endsWith('"') || cleaned.endsWith("'")) {
              cleaned = cleaned.substring(0, cleaned.length - 1);
            }
            return _capitalizeFirstWord(cleaned.trim());
          }
        }
      }
      // fallback to removing braces
      return _capitalizeFirstWord(inner.trim());
    }

    // common separators that precede ids: ' (', ' - ', ' #', ' [', ':'
    final separators = [' (', ' - ', ' #', ' [', ': '];
    for (var sep in separators) {
      if (name.contains(sep)) {
        return _capitalizeFirstWord(name.split(sep)[0].trim());
      }
    }

    return _capitalizeFirstWord(name.trim());
  }

  // Capitalize the first word of a string
  String _capitalizeFirstWord(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1).toLowerCase();
  }

  Widget _buildSubCategoryCell(String subCategoryName) {
    return Text(
      subCategoryName,
      style: const TextStyle(
        color: Color(0xFF558B2F),
        fontSize: 12,
        fontWeight: FontWeight.w600,
      ),
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildStockCell(String stock) {
    final stockInt = int.tryParse(stock) ?? 0;
    final color = stockInt <= 0
        ? Colors.red
        : stockInt <= 10
        ? Colors.orange
        : Colors.green;
    return Text(
      stock,
      style: TextStyle(fontWeight: FontWeight.bold, color: color),
    );
  }

  Widget _buildPaginationControls() {
    // Show pagination controls even with 1 page for testing
    // if (_totalPages <= 1) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Previous button
          IconButton(
            onPressed: _currentPage > 1
                ? () {
                    setState(() {
                      _currentPage--;
                      _updateSelectAllState();
                    });
                    // Reset table scroll position
                    _tableScrollController.jumpTo(0.0);
                  }
                : null,
            icon: const Icon(Icons.chevron_left),
            color: _currentPage > 1 ? Color(0xFF0D1845) : Colors.grey,
            tooltip: 'Previous Page',
          ),

          // Page numbers
          ..._buildPageNumbers(),

          // Next button
          IconButton(
            onPressed: _currentPage < _totalPages
                ? () {
                    setState(() {
                      _currentPage++;
                      _updateSelectAllState();
                    });
                    // Reset table scroll position
                    _tableScrollController.jumpTo(0.0);
                  }
                : null,
            icon: const Icon(Icons.chevron_right),
            color: _currentPage < _totalPages ? Color(0xFF0D1845) : Colors.grey,
            tooltip: 'Next Page',
          ),

          // Page info
          const SizedBox(width: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Color(0xFF0D1845).withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Page $_currentPage of $_totalPages',
              style: TextStyle(
                color: Color(0xFF0D1845),
                fontWeight: FontWeight.w500,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildPageNumbers() {
    List<Widget> pageNumbers = [];
    int startPage = 1;
    int endPage = _totalPages;

    // Show max 5 page numbers at a time
    if (_totalPages > 5) {
      if (_currentPage <= 3) {
        endPage = 5;
      } else if (_currentPage >= _totalPages - 2) {
        startPage = _totalPages - 4;
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
              _updateSelectAllState();
            });
            // Reset table scroll position
            _tableScrollController.jumpTo(0.0);
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _currentPage == i ? Color(0xFF0D1845) : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: _currentPage == i
                    ? Color(0xFF0D1845)
                    : Colors.grey.shade300,
                width: 1,
              ),
            ),
            child: Text(
              i.toString(),
              style: TextStyle(
                color: _currentPage == i ? Colors.white : Color(0xFF0D1845),
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

  int _calculateTotalStock(List<dynamic> reports) {
    return reports.fold(0, (sum, report) {
      switch (_currentReportType) {
        case InventoryReportType.inHand:
          return sum +
              (int.tryParse((report as InHandProduct).balanceStock) ?? 0);
        case InventoryReportType.history:
          return sum +
              (int.tryParse((report as HistoryProduct).balanceStock) ?? 0);
        case InventoryReportType.sold:
          // Sold products don't have balance, use stock out quantity
          return sum +
              (int.tryParse(
                    (report as SoldProduct).stockOut.replaceAll('-', ''),
                  ) ??
                  0);
      }
    });
  }

  int _calculateOutOfStockItems(List<dynamic> reports) {
    return reports.where((report) {
      int stock;
      switch (_currentReportType) {
        case InventoryReportType.inHand:
          stock = int.tryParse((report as InHandProduct).balanceStock) ?? 0;
          break;
        case InventoryReportType.history:
          stock = int.tryParse((report as HistoryProduct).balanceStock) ?? 0;
          break;
        case InventoryReportType.sold:
          // Sold products don't track stock levels
          stock = 0;
          break;
      }
      return stock <= 0;
    }).length;
  }

  int _calculateLowStockItems(List<dynamic> reports) {
    return reports.where((report) {
      int stock;
      switch (_currentReportType) {
        case InventoryReportType.inHand:
          stock = int.tryParse((report as InHandProduct).balanceStock) ?? 0;
          break;
        case InventoryReportType.history:
          stock = int.tryParse((report as HistoryProduct).balanceStock) ?? 0;
          break;
        case InventoryReportType.sold:
          // Sold products don't track low stock
          stock = 0;
          break;
      }
      return stock <= 10 && stock > 0;
    }).length;
  }
}
