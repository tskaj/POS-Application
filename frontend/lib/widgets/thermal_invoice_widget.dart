import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'dart:typed_data';

class ThermalInvoiceGenerator {
  // Page size: 80mm width (226.77 points) for thermal paper
  // 80mm = 3.15 inches, 1 inch = 72 points, so 80mm = 226.77 points
  static const double pageWidthInPoints = 226.77;
  // No margins - use full width
  static const double leftMarginPx = 10.0;
  static const double rightMarginPx = 10.0;
  // Header margins - slightly larger to prevent text cutting
  static const double headerLeftMarginPx = 15.0;
  static const double headerRightMarginPx = 15.0;
  // Actual drawing width
  static const double receiptWidthPx = pageWidthInPoints;

  static Future<Uint8List> generateThermalReceipt({
    required int invoiceNumber,
    required DateTime invoiceDate,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
    required String paymentMethod,
    required double paidAmount,
    String? salesmanName,
    double? advance,
    String? dueDate,
    String? paymentStatus,
    double extraFooterSpacing = 20.0,
  }) async {
    // Create PDF document with custom page size (80mm width, flexible height)
    // 80mm = 226.77 points (80mm / 25.4mm per inch * 72 points per inch)
    const double initialPageHeightInPoints =
        1000; // Will be resized to fit content

    final PdfDocument document = PdfDocument();

    // Set custom page size using PdfSection
    final PdfSection section = document.sections!.add();
    section.pageSettings.size = Size(
      pageWidthInPoints,
      initialPageHeightInPoints,
    );
    // Remove all page margins to eliminate white space
    section.pageSettings.margins.all = 0;
    final PdfPage page = section.pages.add();
    final PdfGraphics graphics = page.graphics;

    // Fonts - optimized sizes for narrow printable width
    final PdfFont regularFont = PdfStandardFont(PdfFontFamily.helvetica, 6);
    final PdfFont boldFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      7,
      style: PdfFontStyle.bold,
    );
    final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 5.5);
    final PdfFont extraFont = PdfStandardFont(PdfFontFamily.helvetica, 6);
    final PdfFont boldItemFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      6,
      style: PdfFontStyle.bold,
    );

    // Larger fonts for header text
    final PdfFont largeBoldFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      10,
      style: PdfFontStyle.bold,
    );
    final PdfFont largeRegularFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      8,
    );

    final double printableWidth = receiptWidthPx - leftMarginPx - rightMarginPx;
    final double headerPrintableWidth =
        receiptWidthPx - headerLeftMarginPx - headerRightMarginPx;
    double yPos = 10.0; // Minimal top margin

    // Header - compact spacing for narrow width
    graphics.drawString(
      'Dhanpuri By Get Going',
      largeBoldFont,
      bounds: Rect.fromLTWH(headerLeftMarginPx, yPos, headerPrintableWidth, 15),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    yPos += 15;

    graphics.drawString(
      'Civil line road opposite MCB Bank Jhelum',
      largeRegularFont,
      bounds: Rect.fromLTWH(headerLeftMarginPx, yPos, headerPrintableWidth, 12),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.top,
      ),
    );
    yPos += 12;

    graphics.drawString(
      'Phone # 0544 276590',
      largeRegularFont,
      bounds: Rect.fromLTWH(headerLeftMarginPx, yPos, headerPrintableWidth, 12),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.top,
      ),
    );
    yPos += 12;

    // Separator line
    graphics.drawLine(
      PdfPen(PdfColor(0, 0, 0), width: 0.5),
      Offset(3, yPos),
      Offset(receiptWidthPx - 3, yPos),
    );
    yPos += 10;

    // Invoice Info - tight spacing for narrow width
    graphics.drawString(
      'INV-$invoiceNumber',
      regularFont,
      bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
    );
    yPos += 12;

    graphics.drawString(
      'Date: ${DateFormat('dd/MM/yy').format(invoiceDate)} ${DateFormat('HH:mm').format(invoiceDate)}',
      regularFont,
      bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
    );
    yPos += 12;

    graphics.drawString(
      'Customer: $customerName',
      regularFont,
      bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
    );
    yPos += 12;

    if (salesmanName != null && salesmanName.isNotEmpty) {
      graphics.drawString(
        'Salesman: $salesmanName',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
      );
      yPos += 12;
    }

    // Separator line
    graphics.drawLine(
      PdfPen(PdfColor(0, 0, 0), width: 0.5),
      Offset(3, yPos),
      Offset(receiptWidthPx - 3, yPos),
    );
    yPos += 10;

    // Items Header - optimized column widths for narrow printable area
    final double itemWidth = 100; // Item name
    final double qtyWidth = 30; // Quantity
    final double priceWidth = 40; // Price
    final double totalWidth = 40; // Total

    final double colItemX = leftMarginPx;
    final double colQtyX = colItemX + itemWidth;
    final double colPriceX = colQtyX + qtyWidth;
    final double colTotalX = colPriceX + priceWidth;

    graphics.drawString(
      'Item',
      boldFont,
      bounds: Rect.fromLTWH(colItemX, yPos, itemWidth, 10),
    );
    graphics.drawString(
      'Qty',
      boldFont,
      bounds: Rect.fromLTWH(colQtyX, yPos, qtyWidth, 10),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    graphics.drawString(
      'Price',
      boldFont,
      bounds: Rect.fromLTWH(colPriceX, yPos, priceWidth, 10),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
    graphics.drawString(
      'Total',
      boldFont,
      bounds: Rect.fromLTWH(colTotalX, yPos, totalWidth, 10),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
    yPos += 8;

    // Separator
    graphics.drawLine(
      PdfPen(PdfColor(0, 0, 0), width: 0.5),
      Offset(3, yPos),
      Offset(receiptWidthPx - 3, yPos),
    );
    yPos += 5;

    // Items list with support for extras or flattened extras
    // Very tight spacing for narrow width
    const double itemHeight = 12.0; // Reduced for tighter spacing
    const double extraLineHeight = 10.0; // Reduced for extras and discounts

    for (var item in items) {
      final String name = item['name']?.toString() ?? '';
      final int qty = item['quantity'] as int? ?? 1;
      final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final double itemTotal = qty * price;

      // Detect flattened extra pattern e.g. "Parent - Extra" when upstream
      // expanded extras into separate items. If detected, render as bullet.
      bool isFlattenedExtra = false;
      String flattenedExtraTitle = '';
      try {
        if (!(item.containsKey('extras')) && name.contains(' - ')) {
          final parts = name.split(' - ');
          if (parts.length >= 2) {
            isFlattenedExtra = true;
            flattenedExtraTitle = parts.sublist(1).join(' - ');
          }
        }
      } catch (_) {}

      if (isFlattenedExtra) {
        final double bulletIndent = 3.0; // Minimal indent
        graphics.drawString(
          '• $flattenedExtraTitle',
          extraFont,
          bounds: Rect.fromLTWH(
            colItemX + bulletIndent,
            yPos,
            itemWidth - bulletIndent,
            7,
          ),
        );
        graphics.drawString(
          price.toStringAsFixed(2),
          extraFont,
          bounds: Rect.fromLTWH(colTotalX, yPos, totalWidth, 7),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        yPos += extraLineHeight;
        continue;
      }

      // Normal product row - tight layout
      graphics.drawString(
        name,
        boldItemFont,
        bounds: Rect.fromLTWH(colItemX, yPos, itemWidth, 10),
      );
      graphics.drawString(
        qty.toString(),
        regularFont,
        bounds: Rect.fromLTWH(colQtyX, yPos, qtyWidth, 10),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
      graphics.drawString(
        price.toStringAsFixed(2),
        regularFont,
        bounds: Rect.fromLTWH(colPriceX, yPos, priceWidth, 10),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
      graphics.drawString(
        itemTotal.toStringAsFixed(2),
        regularFont,
        bounds: Rect.fromLTWH(colTotalX, yPos, totalWidth, 10),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
      yPos += itemHeight;

      // Show product-level discount if present
      try {
        final discountPercent =
            (item['discountPercent'] as num?)?.toDouble() ?? 0.0;
        final discountAmount =
            (item['discountAmount'] as num?)?.toDouble() ?? 0.0;

        if (discountAmount > 0 || discountPercent > 0) {
          final discountText = discountPercent > 0
              ? '- Discount: ${discountPercent.toStringAsFixed(0)}% (Rs ${discountAmount.toStringAsFixed(2)})'
              : '- Discount: Rs ${discountAmount.toStringAsFixed(2)}';

          final double bulletIndent = 3.0;
          graphics.drawString(
            discountText,
            extraFont,
            bounds: Rect.fromLTWH(
              colItemX + bulletIndent,
              yPos,
              itemWidth + qtyWidth + priceWidth - bulletIndent,
              7,
            ),
          );
          graphics.drawString(
            '- Rs ${discountAmount.toStringAsFixed(2)}',
            extraFont,
            bounds: Rect.fromLTWH(colTotalX, yPos, totalWidth, 7),
            format: PdfStringFormat(alignment: PdfTextAlignment.right),
          );
          yPos += extraLineHeight;
        }
      } catch (_) {}

      // Render extras if present
      try {
        final extras = item['extras'];
        if (extras is List && extras.isNotEmpty) {
          for (final ex in extras) {
            final String exTitle = (ex['title'] ?? ex['name'] ?? '').toString();
            final double exAmount = (ex['amount'] is num)
                ? (ex['amount'] as num).toDouble()
                : double.tryParse(ex['amount']?.toString() ?? '') ?? 0.0;
            final double bulletIndent = 3.0; // Minimal indent
            graphics.drawString(
              '• $exTitle',
              extraFont,
              bounds: Rect.fromLTWH(
                colItemX + bulletIndent,
                yPos,
                itemWidth - bulletIndent,
                7,
              ),
            );
            graphics.drawString(
              exAmount.toStringAsFixed(2),
              extraFont,
              bounds: Rect.fromLTWH(colTotalX, yPos, totalWidth, 7),
              format: PdfStringFormat(alignment: PdfTextAlignment.right),
            );
            yPos += extraLineHeight;
          }
        }
      } catch (_) {}
    }

    yPos += 10; // Minimal spacing

    // Separator line
    graphics.drawLine(
      PdfPen(PdfColor(0, 0, 0), width: 0.5),
      Offset(3, yPos),
      Offset(receiptWidthPx - 3, yPos),
    );
    yPos += 10;

    // Totals Section - tight spacing for narrow width
    final double totalsLabelWidth = printableWidth * 0.50;
    final double totalsValueWidth = printableWidth - totalsLabelWidth;

    graphics.drawString(
      'Subtotal:',
      regularFont,
      bounds: Rect.fromLTWH(leftMarginPx, yPos, totalsLabelWidth, 10),
    );
    graphics.drawString(
      'Rs ${subtotal.toStringAsFixed(2)}',
      regularFont,
      bounds: Rect.fromLTWH(
        leftMarginPx + totalsLabelWidth,
        yPos,
        totalsValueWidth,
        10,
      ),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
    yPos += 12;

    if (tax > 0) {
      graphics.drawString(
        'Tax:',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, totalsLabelWidth, 10),
      );
      graphics.drawString(
        'Rs ${tax.toStringAsFixed(2)}',
        regularFont,
        bounds: Rect.fromLTWH(
          leftMarginPx + totalsLabelWidth,
          yPos,
          totalsValueWidth,
          10,
        ),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
      yPos += 12;
    }

    if (discount > 0) {
      graphics.drawString(
        'Discount:',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, totalsLabelWidth, 10),
      );
      graphics.drawString(
        '- Rs ${discount.toStringAsFixed(2)}',
        regularFont,
        bounds: Rect.fromLTWH(
          leftMarginPx + totalsLabelWidth,
          yPos,
          totalsValueWidth,
          10,
        ),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
      yPos += 12;
    }

    // Separator
    graphics.drawLine(
      PdfPen(PdfColor(0, 0, 0), width: 1.0),
      Offset(3, yPos),
      Offset(receiptWidthPx - 3, yPos),
    );
    yPos += 6;

    graphics.drawString(
      'Total:',
      boldFont,
      bounds: Rect.fromLTWH(leftMarginPx, yPos, totalsLabelWidth, 10),
    );
    graphics.drawString(
      'Rs ${total.toStringAsFixed(2)}',
      boldFont,
      bounds: Rect.fromLTWH(
        leftMarginPx + totalsLabelWidth,
        yPos,
        totalsValueWidth,
        10,
      ),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
    yPos += 15;

    // Payment Info - tight spacing
    graphics.drawString(
      'Payment: $paymentMethod',
      regularFont,
      bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
    );
    yPos += 8;

    if (advance != null && advance > 0) {
      graphics.drawString(
        'Advance: Rs ${advance.toStringAsFixed(2)}',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
      );
      yPos += 8;
    }

    graphics.drawString(
      'Paid: Rs ${paidAmount.toStringAsFixed(2)}',
      regularFont,
      bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
    );
    yPos += 8;

    // Show due date under paid for custom orders
    if (dueDate != null && dueDate.isNotEmpty) {
      graphics.drawString(
        'Due Date: $dueDate',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
      );
      yPos += 8;
    }

    // Show change for cash/bank or pending for credit
    final double change = paidAmount - total;

    // Debug: Print payment info
    print(
      '🔍 PaymentMethod: $paymentMethod, PaymentStatus: $paymentStatus, Change: $change, PaidAmount: $paidAmount, Total: $total',
    );

    // Determine payment type from method name
    final String methodLower = paymentMethod.toLowerCase();
    final bool isCash = methodLower.contains('cash');
    final bool isBank =
        methodLower.contains('bank') ||
        methodLower.contains('cheque') ||
        methodLower.contains('transfer');
    final bool isCredit = methodLower.contains('credit');

    print('🔍 isCash: $isCash, isBank: $isBank, isCredit: $isCredit');

    // Always show change for cash/bank if change > 0
    if ((isCash || isBank) && change > 0) {
      print('✅ Showing change for cash/bank');
      graphics.drawString(
        'Change: Rs ${change.toStringAsFixed(2)}',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
      );
      yPos += 10;
    }
    // Always show pending for credit if not fully paid
    else if (isCredit && paidAmount < total) {
      print('✅ Showing pending for credit');
      final double pending = total - paidAmount;
      // Separator
      graphics.drawLine(
        PdfPen(PdfColor(0, 0, 0), width: 1.0),
        Offset(3, yPos),
        Offset(receiptWidthPx - 3, yPos),
      );
      yPos += 6;
      graphics.drawString(
        'Payable Amount: Rs ${pending.toStringAsFixed(2)}',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
      );
      yPos += 10;
    }
    // Fallback: check payment status for detection
    else if (!isCash && !isBank && !isCredit) {
      print('🔍 Using fallback payment status detection');
      final String status = paymentStatus?.toLowerCase() ?? '';
      final statusIsCredit =
          status.contains('credit') ||
          status.contains('unpaid') ||
          status.contains('pending');

      print('🔍 Status: $status, statusIsCredit: $statusIsCredit');

      if (statusIsCredit && paidAmount < total) {
        print('✅ Showing pending (fallback)');
        final double pending = total - paidAmount;
        // Separator
        graphics.drawLine(
          PdfPen(PdfColor(0, 0, 0), width: 1.0),
          Offset(3, yPos),
          Offset(receiptWidthPx - 3, yPos),
        );
        yPos += 6;
        graphics.drawString(
          'Payable Amount: Rs ${pending.toStringAsFixed(2)}',
          regularFont,
          bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
        );
        yPos += 10;
      } else if (!statusIsCredit && change > 0) {
        print('✅ Showing change (fallback)');
        graphics.drawString(
          'Change: Rs ${change.toStringAsFixed(2)}',
          regularFont,
          bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
        );
        yPos += 10;
      }
    }

    // Footer - tight spacing
    graphics.drawString(
      'Thank you!',
      regularFont,
      bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.top,
      ),
    );
    yPos += 12;
    graphics.drawString(
      'Visit again!',
      smallFont,
      bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 8),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.top,
      ),
    );
    yPos += 15;
    graphics.drawString(
      'Dhanpuri by Get Going Pos System',
      smallFont,
      bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 8),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.top,
      ),
    );

    // Add minimal bottom margin (3 points) and resize page to fit content exactly
    yPos += 3; // Minimal bottom margin after last text

    // Resize page to actual content height (80mm width, auto height)
    section.pageSettings.size = Size(pageWidthInPoints, yPos);

    // Save
    final List<int> bytes = await document.save();
    document.dispose();
    return Uint8List.fromList(bytes);
  }

  static Future<void> printThermalReceipt({
    required BuildContext context,
    required int invoiceNumber,
    required DateTime invoiceDate,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
    required String paymentMethod,
    required double paidAmount,
    String? salesmanName,
    double? advance,
    String? dueDate,
    String? paymentStatus,
  }) async {
    try {
      final Uint8List pdfBytes = await generateThermalReceipt(
        invoiceNumber: invoiceNumber,
        invoiceDate: invoiceDate,
        customerName: customerName,
        items: items,
        subtotal: subtotal,
        tax: tax,
        discount: discount,
        total: total,
        paymentMethod: paymentMethod,
        paidAmount: paidAmount,
        salesmanName: salesmanName,
        advance: advance,
        dueDate: dueDate,
        paymentStatus: paymentStatus,
      );

      // Show message to minimize app to see print dialog
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.print, color: Colors.white),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Minimize the application window to view the print dialog',
                    style: TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF0D1845),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.all(16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }

      // Save and share the PDF directly (80mm thermal receipt, flexible height)
      // No print dialog - directly saves like barcode printing
      await Printing.sharePdf(
        bytes: pdfBytes,
        filename: 'Invoice_$invoiceNumber.pdf',
      );
    } catch (e) {
      print('Error printing thermal receipt: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  static Future<void> directPrintThermalReceipt({
    required BuildContext context,
    required int invoiceNumber,
    required DateTime invoiceDate,
    required String customerName,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double tax,
    required double discount,
    required double total,
    required String paymentMethod,
    required double paidAmount,
    String? salesmanName,
    double? advance,
    String? dueDate,
    String? paymentStatus,
  }) async {
    try {
      final Uint8List pdfBytes = await generateThermalReceipt(
        invoiceNumber: invoiceNumber,
        invoiceDate: invoiceDate,
        customerName: customerName,
        items: items,
        subtotal: subtotal,
        tax: tax,
        discount: discount,
        total: total,
        paymentMethod: paymentMethod,
        paidAmount: paidAmount,
        salesmanName: salesmanName,
        advance: advance,
        dueDate: dueDate,
        paymentStatus: paymentStatus,
      );

      // List available printers
      final printers = await Printing.listPrinters();

      // Find the Xprinter thermal printer
      Printer? targetPrinter;
      for (final printer in printers) {
        if (printer.name.contains('XP-H200N') ||
            printer.name.contains('Xprinter') ||
            printer.name.contains('Thermal')) {
          targetPrinter = printer;
          break;
        }
      }

      // Fallback to first available printer if specific printer not found
      targetPrinter ??= printers.isNotEmpty ? printers.first : null;

      if (targetPrinter != null) {
        // Print directly to the printer without showing dialog
        await Printing.directPrintPdf(
          onLayout: (pdf.PdfPageFormat format) async => pdfBytes,
          printer: targetPrinter,
        );

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.print, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Invoice sent to printer successfully',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        // No printer found
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('No printer found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('Error direct printing thermal receipt: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to print receipt: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
