import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'dart:typed_data';

class ThermalInvoiceGenerator {
  static const double mmToPx = 2.83465; // 1mm = 2.83465 pixels at 72 DPI
  static const double receiptWidthMm = 80; // 8cm = 80mm
  static const double receiptWidthPx = receiptWidthMm * mmToPx;

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
  }) async {
    // Create a new PDF document
    final PdfDocument document = PdfDocument();

    // Calculate dynamic height based on content
    final int itemCount = items.length;
    final double baseHeight = 400; // Base height for header, footer, etc.
    final double itemHeight = 20; // Height per item line
    final double dynamicHeight = baseHeight + (itemCount * itemHeight);

    // Add a page with thermal receipt dimensions (80mm width, dynamic height)
    final PdfPage page = document.pages.add();
    page.graphics.drawRectangle(
      bounds: Rect.fromLTWH(0, 0, receiptWidthPx, dynamicHeight),
    );

    // Get graphics and fonts
    final PdfGraphics graphics = page.graphics;
    final PdfFont boldFont = PdfStandardFont(
      PdfFontFamily.helvetica,
      10,
      style: PdfFontStyle.bold,
    );
    final PdfFont regularFont = PdfStandardFont(PdfFontFamily.helvetica, 8);
    final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 7);

    double yPos = 10;

    // Business Header (Centered)
    graphics.drawString(
      'YOUR BUSINESS NAME',
      boldFont,
      bounds: Rect.fromLTWH(0, yPos, receiptWidthPx, 20),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.top,
      ),
    );
    yPos += 15;

    graphics.drawString(
      'Address Line 1, City',
      regularFont,
      bounds: Rect.fromLTWH(0, yPos, receiptWidthPx, 15),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.top,
      ),
    );
    yPos += 12;

    graphics.drawString(
      'Phone: +92 XXX XXXXXXX',
      regularFont,
      bounds: Rect.fromLTWH(0, yPos, receiptWidthPx, 15),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.top,
      ),
    );
    yPos += 15;

    // Separator line
    graphics.drawLine(
      PdfPen(PdfColor(0, 0, 0), width: 0.5),
      Offset(10, yPos),
      Offset(receiptWidthPx - 10, yPos),
    );
    yPos += 10;

    // Invoice Info
    graphics.drawString(
      'Invoice #: INV-$invoiceNumber',
      regularFont,
      bounds: Rect.fromLTWH(10, yPos, receiptWidthPx - 20, 15),
    );
    yPos += 12;

    graphics.drawString(
      'Date: ${DateFormat('dd/MM/yyyy HH:mm').format(invoiceDate)}',
      regularFont,
      bounds: Rect.fromLTWH(10, yPos, receiptWidthPx - 20, 15),
    );
    yPos += 12;

    graphics.drawString(
      'Customer: $customerName',
      regularFont,
      bounds: Rect.fromLTWH(10, yPos, receiptWidthPx - 20, 15),
    );
    yPos += 12;

    if (salesmanName != null && salesmanName.isNotEmpty) {
      graphics.drawString(
        'Salesman: $salesmanName',
        regularFont,
        bounds: Rect.fromLTWH(10, yPos, receiptWidthPx - 20, 15),
      );
      yPos += 12;
    }

    // Separator line
    graphics.drawLine(
      PdfPen(PdfColor(0, 0, 0), width: 0.5),
      Offset(10, yPos),
      Offset(receiptWidthPx - 10, yPos),
    );
    yPos += 10;

    // Items Header
    graphics.drawString(
      'Item',
      boldFont,
      bounds: Rect.fromLTWH(10, yPos, 100, 15),
    );
    graphics.drawString(
      'Qty',
      boldFont,
      bounds: Rect.fromLTWH(110, yPos, 30, 15),
      format: PdfStringFormat(alignment: PdfTextAlignment.center),
    );
    graphics.drawString(
      'Price',
      boldFont,
      bounds: Rect.fromLTWH(140, yPos, 40, 15),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
    graphics.drawString(
      'Total',
      boldFont,
      bounds: Rect.fromLTWH(180, yPos, 40, 15),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
    yPos += 12;

    // Separator line
    graphics.drawLine(
      PdfPen(PdfColor(0, 0, 0), width: 0.5),
      Offset(10, yPos),
      Offset(receiptWidthPx - 10, yPos),
    );
    yPos += 8;

    // Items List
    for (var item in items) {
      final String name = item['name']?.toString() ?? '';
      final int qty = item['quantity'] as int? ?? 1;
      final double price = (item['price'] as num?)?.toDouble() ?? 0.0;
      final double itemTotal = qty * price;

      // Product name (may wrap to multiple lines)
      graphics.drawString(
        name,
        regularFont,
        bounds: Rect.fromLTWH(10, yPos, 100, 30),
      );

      graphics.drawString(
        qty.toString(),
        regularFont,
        bounds: Rect.fromLTWH(110, yPos, 30, 15),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      graphics.drawString(
        price.toStringAsFixed(2),
        regularFont,
        bounds: Rect.fromLTWH(140, yPos, 40, 15),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );

      graphics.drawString(
        itemTotal.toStringAsFixed(2),
        regularFont,
        bounds: Rect.fromLTWH(180, yPos, 40, 15),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );

      yPos += itemHeight;
    }

    yPos += 5;

    // Separator line
    graphics.drawLine(
      PdfPen(PdfColor(0, 0, 0), width: 0.5),
      Offset(10, yPos),
      Offset(receiptWidthPx - 10, yPos),
    );
    yPos += 10;

    // Totals Section
    graphics.drawString(
      'Subtotal:',
      regularFont,
      bounds: Rect.fromLTWH(10, yPos, 150, 15),
    );
    graphics.drawString(
      'Rs ${subtotal.toStringAsFixed(2)}',
      regularFont,
      bounds: Rect.fromLTWH(160, yPos, 60, 15),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
    yPos += 12;

    if (tax > 0) {
      graphics.drawString(
        'Tax:',
        regularFont,
        bounds: Rect.fromLTWH(10, yPos, 150, 15),
      );
      graphics.drawString(
        'Rs ${tax.toStringAsFixed(2)}',
        regularFont,
        bounds: Rect.fromLTWH(160, yPos, 60, 15),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
      yPos += 12;
    }

    if (discount > 0) {
      graphics.drawString(
        'Discount:',
        regularFont,
        bounds: Rect.fromLTWH(10, yPos, 150, 15),
      );
      graphics.drawString(
        '- Rs ${discount.toStringAsFixed(2)}',
        regularFont,
        bounds: Rect.fromLTWH(160, yPos, 60, 15),
        format: PdfStringFormat(alignment: PdfTextAlignment.right),
      );
      yPos += 12;
    }

    // Separator line
    graphics.drawLine(
      PdfPen(PdfColor(0, 0, 0), width: 1.0),
      Offset(10, yPos),
      Offset(receiptWidthPx - 10, yPos),
    );
    yPos += 10;

    // Total (Bold)
    graphics.drawString(
      'TOTAL:',
      boldFont,
      bounds: Rect.fromLTWH(10, yPos, 150, 15),
    );
    graphics.drawString(
      'Rs ${total.toStringAsFixed(2)}',
      boldFont,
      bounds: Rect.fromLTWH(160, yPos, 60, 15),
      format: PdfStringFormat(alignment: PdfTextAlignment.right),
    );
    yPos += 15;

    // Payment Info
    graphics.drawString(
      'Payment Method: $paymentMethod',
      regularFont,
      bounds: Rect.fromLTWH(10, yPos, receiptWidthPx - 20, 15),
    );
    yPos += 12;

    graphics.drawString(
      'Paid Amount: Rs ${paidAmount.toStringAsFixed(2)}',
      regularFont,
      bounds: Rect.fromLTWH(10, yPos, receiptWidthPx - 20, 15),
    );
    yPos += 12;

    final double change = paidAmount - total;
    if (change > 0) {
      graphics.drawString(
        'Change: Rs ${change.toStringAsFixed(2)}',
        regularFont,
        bounds: Rect.fromLTWH(10, yPos, receiptWidthPx - 20, 15),
      );
      yPos += 15;
    }

    // Separator line
    graphics.drawLine(
      PdfPen(PdfColor(0, 0, 0), width: 0.5),
      Offset(10, yPos),
      Offset(receiptWidthPx - 10, yPos),
    );
    yPos += 10;

    // Footer
    graphics.drawString(
      'Thank you for your business!',
      regularFont,
      bounds: Rect.fromLTWH(0, yPos, receiptWidthPx, 15),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.top,
      ),
    );
    yPos += 12;

    graphics.drawString(
      'Visit us again!',
      smallFont,
      bounds: Rect.fromLTWH(0, yPos, receiptWidthPx, 15),
      format: PdfStringFormat(
        alignment: PdfTextAlignment.center,
        lineAlignment: PdfVerticalAlignment.top,
      ),
    );

    // Save the document
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

      // Print the PDF - this will open in native print dialog
      await Printing.layoutPdf(
        onLayout: (format) async => pdfBytes,
        name: 'Invoice_$invoiceNumber.pdf',
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
}
