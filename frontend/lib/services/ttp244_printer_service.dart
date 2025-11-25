import 'dart:async';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class Ttp244PrinterService {
  Ttp244PrinterService._privateConstructor();

  static final Ttp244PrinterService instance =
      Ttp244PrinterService._privateConstructor();

  // Platform channel name - native implementation can listen on this
  static const MethodChannel _channel = MethodChannel('ttp244_printer');

  // Default dots-per-inch for common thermal printers (dots per inch).
  // Many desktop/USB thermal printers use 203 DPI (8 dots/mm). If your
  // printer uses a different DPI (e.g., 300), change this value to match
  // for more accurate TSPL sizing.
  static const int defaultDpi = 203;

  // Debug settings (can be toggled from UI)
  bool debugEnabled = false;
  String? debugDirectory; // when set, saves files here instead of temp
  bool debugOpenAfterSave = false;

  /// Configure debug behavior. When [enabled] is true, TSPL output will
  /// be written to [debugDirectory] (if provided) or system temp. If
  /// [openAfterSave] is true, the saved file will be opened automatically
  /// by the OS viewer (explorer/open/xdg-open).
  void setDebug({
    required bool enabled,
    String? directory,
    bool openAfterSave = false,
  }) {
    debugEnabled = enabled;
    debugDirectory = directory;
    debugOpenAfterSave = openAfterSave;
  }

  /// Print a 2x1 label for the given barcode and optional product details.
  ///
  /// This method composes a TSPL-like command string and attempts to send
  /// it to the native side via a MethodChannel. If no native handler is
  /// available during development, it will write the generated commands to
  /// a temp file (useful for debugging and verifying output). When debug
  /// is enabled the file will be written to [debugDirectory] if set.
  Future<void> printBarcode2x1({
    required String barcode,
    String? productName,
    String? price,
    String companyName = 'Dhanpuri by Get Going',
    int copies = 1,
    String?
    symbology, // optional: 'code128','code39','ean13','upca','codabar','itf'
  }) async {
    if (barcode.isEmpty) throw Exception('Barcode is empty');

    // Compose a simple TSPL command sequence for a 2x1 label.
    final buffer = StringBuffer();
    buffer.writeln('SIZE 2,1'); // 2x1 inches label
    // Use a small physical gap between labels. GAP 0,0 causes continuous
    // printing with no separation and can make multi-label prints overlap or
    // be cut at the cutter/gap. A small gap (2 dots) is a safe default for
    // many 2x1" label rolls — adjust if your printer uses different units.
    buffer.writeln('GAP 2,0');
    buffer.writeln('SPEED 4');
    buffer.writeln('DENSITY 8');
    buffer.writeln('CLS');

    // Layout: Top - Product Name, Middle - Barcode, Below - Price, Bottom - Company Name
    // Determine TSPL barcode type. Use explicit symbology if provided, otherwise
    // infer from numeric length (common for EAN13/UPCA) and fallback to CODE128.
    String tsplBarcodeType = '128';
    // Fix regex: match digits-only
    final numericOnly = RegExp(r'^\d+$');
    // Note: some TSPL/TSC printers support a TEAR mode which helps when using
    // die-cut labels with gaps. Enable TEAR in the command stream to help
    // ensure each label is separated cleanly.
    if (symbology != null) {
      final s = symbology.toLowerCase();
      switch (s) {
        case 'ean13':
          tsplBarcodeType = 'EAN13';
          break;
        case 'upca':
          tsplBarcodeType = 'UPCA';
          break;
        case 'code39':
          tsplBarcodeType = '39';
          break;
        case 'codabar':
          tsplBarcodeType = 'CODABAR';
          break;
        case 'itf':
        case 'itf14':
          tsplBarcodeType = 'ITF';
          break;
        case 'code128':
        default:
          tsplBarcodeType = '128';
      }
    } else {
      if (barcode.length == 13 && numericOnly.hasMatch(barcode)) {
        tsplBarcodeType = 'EAN13';
      } else if (barcode.length == 12 && numericOnly.hasMatch(barcode)) {
        tsplBarcodeType = 'UPCA';
      }
    }

    // Map the PDF-based sizes used in PrintBarcodePage to printer dots.
    // Assumption: printer uses `defaultDpi` (203 dpi). If your printer is
    // different, set `defaultDpi` above accordingly.
    final int dpi = defaultDpi;
    final int pageWidthDots = (2 * dpi).round(); // 2 inches
    final int pageHeightDots = (1 * dpi).round(); // 1 inch

    // PDF generation used barcode width ~= 85% of page width and height ~= 38%
    // of page height. Convert those to dots for TSPL height calculation.
    final int barcodeHeightDots = (pageHeightDots * 0.38).round();
    final int desiredBarcodeWidthDots = (pageWidthDots * 0.85).round();

    // Center barcode horizontally by computing an X offset in dots.
    final int barcodeX = ((pageWidthDots - desiredBarcodeWidthDots) / 2)
        .round();

    // Y positions (dots): leave room for product name at top and company/price at bottom
    final int prodY = (dpi * 0.08).round(); // ~8% down from top
    final int barcodeY = (dpi * 0.18).round(); // barcode starts slightly lower
    final int priceY = (dpi * 0.7).round(); // below barcode
    final int companyY = (dpi * 0.85).round(); // bottom-ish

    if (productName != null && productName.isNotEmpty) {
      buffer.writeln('TEXT 10,$prodY,"0",0,1,1,"${_escapeTspl(productName)}"');
    }

    // Use detected barcode type for TSPL. Compute height (in dots) from
    // the PDF layout and center horizontally. The TSPL BARCODE command
    // doesn't accept an explicit width, only module narrow/wide values,
    // so we center and control height. For pixel-perfect width control
    // consider generating a bitmap and printing it with PUTBMP.
    final int narrow = 2;
    final int wide = 2;
    buffer.writeln(
      'BARCODE $barcodeX,$barcodeY,"$tsplBarcodeType",$barcodeHeightDots,1,0,$narrow,$wide,"${_escapeTspl(barcode)}"',
    );

    if (price != null && price.isNotEmpty) {
      buffer.writeln(
        'TEXT 10,$priceY,"0",0,1,1,"Price: ${_escapeTspl(price)}"',
      );
    }

    if (companyName.isNotEmpty) {
      buffer.writeln(
        'TEXT 10,$companyY,"0",0,1,1,"${_escapeTspl(companyName)}"',
      );
    }

    // Ensure copies is at least 1
    if (copies < 1) copies = 1;

    // Some printers benefit from TEAR mode for die-cut labels with gaps. Add
    // SET TEAR ON before printing to ensure proper handling of label gaps.
    buffer.writeln('SET TEAR ON');
    buffer.writeln('PRINT $copies');

    final tsplCommands = buffer.toString();

    try {
      // Try calling native code first; native side should write to USB
      await _channel.invokeMethod('printTspl', {'commands': tsplCommands});
    } on MissingPluginException catch (_) {
      // No native implementation registered - fall back to writing a file
      final dir = (debugEnabled && debugDirectory != null)
          ? Directory(debugDirectory!)
          : Directory.systemTemp;

      if (!(await dir.exists())) {
        try {
          await dir.create(recursive: true);
        } catch (_) {
          // If directory creation fails, fall back to system temp
        }
      }

      final file = File(
        '${dir.path}${Platform.pathSeparator}ttp244_print_${DateTime.now().millisecondsSinceEpoch}.tspl',
      );
      await file.writeAsString(tsplCommands);

      if (debugOpenAfterSave || (debugEnabled && debugOpenAfterSave)) {
        await _openFile(file);
      }

      // For debugging, keep the file and return successfully.
      return;
    } catch (e) {
      // Re-throw to let caller display a meaningful error
      rethrow;
    }
  }

  /// Print a 3x1 inch label for the given barcode and optional product details.
  ///
  /// This is similar to [printBarcode2x1] but targets 3" x 1" labels. It maps
  /// the PDF reference proportions (barcode width ~= 85% and height ~= 38% of
  /// the page) into TSPL dots using [defaultDpi] and centers the barcode.
  Future<void> printBarcode3x1({
    required String barcode,
    String? productName,
    String? price,
    String companyName = 'Dhanpuri by Get Going',
    int copies = 1,
    String? symbology,
  }) async {
    if (barcode.isEmpty) throw Exception('Barcode is empty');

    final buffer = StringBuffer();
    buffer.writeln('SIZE 3,1'); // 3x1 inches label
    buffer.writeln('GAP 2,0');
    buffer.writeln('SPEED 4');
    buffer.writeln('DENSITY 8');
    buffer.writeln('CLS');

    String tsplBarcodeType = '128';
    final numericOnly = RegExp(r'^\d+\$');
    if (symbology != null) {
      final s = symbology.toLowerCase();
      switch (s) {
        case 'ean13':
          tsplBarcodeType = 'EAN13';
          break;
        case 'upca':
          tsplBarcodeType = 'UPCA';
          break;
        case 'code39':
          tsplBarcodeType = '39';
          break;
        case 'codabar':
          tsplBarcodeType = 'CODABAR';
          break;
        case 'itf':
        case 'itf14':
          tsplBarcodeType = 'ITF';
          break;
        case 'code128':
        default:
          tsplBarcodeType = '128';
      }
    } else {
      if (barcode.length == 13 && numericOnly.hasMatch(barcode)) {
        tsplBarcodeType = 'EAN13';
      } else if (barcode.length == 12 && numericOnly.hasMatch(barcode)) {
        tsplBarcodeType = 'UPCA';
      }
    }

    final int dpi = defaultDpi;
    final int pageWidthDots = (3 * dpi).round(); // 3 inches
    final int pageHeightDots = (1 * dpi).round(); // 1 inch

    final int barcodeHeightDots = (pageHeightDots * 0.38).round();
    final int desiredBarcodeWidthDots = (pageWidthDots * 0.85).round();
    final int barcodeX = ((pageWidthDots - desiredBarcodeWidthDots) / 2)
        .round();

    final int prodY = (dpi * 0.06).round();
    final int barcodeY = (dpi * 0.18).round();
    final int priceY = (dpi * 0.7).round();
    final int companyY = (dpi * 0.85).round();

    if (productName != null && productName.isNotEmpty) {
      buffer.writeln('TEXT 10,$prodY,"0",0,1,1,"${_escapeTspl(productName)}"');
    }

    final int narrow = 2;
    final int wide = 2;
    buffer.writeln(
      'BARCODE $barcodeX,$barcodeY,"$tsplBarcodeType",$barcodeHeightDots,1,0,$narrow,$wide,"${_escapeTspl(barcode)}"',
    );

    if (price != null && price.isNotEmpty) {
      buffer.writeln(
        'TEXT 10,$priceY,"0",0,1,1,"Price: ${_escapeTspl(price)}"',
      );
    }

    if (companyName.isNotEmpty) {
      buffer.writeln(
        'TEXT 10,$companyY,"0",0,1,1,"${_escapeTspl(companyName)}"',
      );
    }

    if (copies < 1) copies = 1;
    buffer.writeln('SET TEAR ON');
    buffer.writeln('PRINT $copies');

    final tsplCommands = buffer.toString();

    try {
      await _channel.invokeMethod('printTspl', {'commands': tsplCommands});
    } on MissingPluginException catch (_) {
      final dir = (debugEnabled && debugDirectory != null)
          ? Directory(debugDirectory!)
          : Directory.systemTemp;

      if (!(await dir.exists())) {
        try {
          await dir.create(recursive: true);
        } catch (_) {}
      }

      final file = File(
        '${dir.path}${Platform.pathSeparator}ttp244_print_3x1_${DateTime.now().millisecondsSinceEpoch}.tspl',
      );
      await file.writeAsString(tsplCommands);

      if (debugOpenAfterSave || (debugEnabled && debugOpenAfterSave)) {
        await _openFile(file);
      }

      return;
    } catch (e) {
      rethrow;
    }
  }

  /// Print a 1x1 inch label containing a QR code (and optional label text).
  ///
  /// [data] is the string encoded into the QR code. [label] will be printed
  /// as a short text either above or below the QR code depending on space.
  Future<void> printQr1x1({
    required String data,
    String? label,
    String companyName = 'Dhanpuri by Get Going',
    int copies = 1,
  }) async {
    if (data.isEmpty) throw Exception('QR data is empty');

    final buffer = StringBuffer();
    buffer.writeln('SIZE 1,1'); // 1x1 inch label
    // Use a small gap so multiple QR labels are separated and not cut at the
    // label gaps. Adjust as needed per your label stock/printer.
    buffer.writeln('GAP 2,0');
    buffer.writeln('SPEED 4');
    buffer.writeln('DENSITY 8');
    buffer.writeln('CLS');

    // Positions tuned for 1x1 inch label (may need adjustment per printer)
    final labelY = 8;
    final qrY = 28; // QR area
    final companyY = 130;

    if (label != null && label.isNotEmpty) {
      buffer.writeln('TEXT 10,${labelY},"0",0,1,1,"${_escapeTspl(label)}"');
    }

    // TSPL QRCODE syntax (TSC/TSPL): QRCODE x,y,<model>,<cellWidth>,<errorLevel>,<rotation>,"data"
    // Use model L (auto) and a moderate cell width. Reduce cell width slightly
    // so QR doesn't vertically touch the gap on small labels when printing
    // multiple copies.
    buffer.writeln('QRCODE 10,${qrY},L,3,A,0,"${_escapeTspl(data)}"');

    if (companyName.isNotEmpty) {
      buffer.writeln(
        'TEXT 10,${companyY},"0",0,1,1,"${_escapeTspl(companyName)}"',
      );
    }

    if (copies < 1) copies = 1;
    // Enable TEAR to assist printers with die-cut labels/gaps so each label
    // is separated correctly when printing multiple copies.
    buffer.writeln('SET TEAR ON');
    buffer.writeln('PRINT $copies');

    final tsplCommands = buffer.toString();

    try {
      await _channel.invokeMethod('printTspl', {'commands': tsplCommands});
    } on MissingPluginException catch (_) {
      final dir = (debugEnabled && debugDirectory != null)
          ? Directory(debugDirectory!)
          : Directory.systemTemp;

      if (!(await dir.exists())) {
        try {
          await dir.create(recursive: true);
        } catch (_) {}
      }

      final file = File(
        '${dir.path}${Platform.pathSeparator}ttp244_qr_${DateTime.now().millisecondsSinceEpoch}.tspl',
      );
      await file.writeAsString(tsplCommands);

      if (debugOpenAfterSave || (debugEnabled && debugOpenAfterSave)) {
        await _openFile(file);
      }

      return;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> _openFile(File file) async {
    try {
      if (Platform.isWindows) {
        await Process.run('explorer', [file.path]);
      } else if (Platform.isMacOS) {
        await Process.run('open', [file.path]);
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [file.path]);
      }
    } catch (e) {
      // Ignore open errors in debug flow
    }
  }

  /// Generate and save a PDF containing the label (2"x1") and return the saved file path.
  Future<File> savePdfLabel({
    required String barcode,
    String? productName,
    String? price,
    String companyName = 'Dhanpuri by Get Going',
    String? outputPath,
    int copies = 1,
    String? symbology, // optional
  }) async {
    final pdf = pw.Document();

    // 2in x 1in in PDF points
    final pageWidth = 2 * PdfPageFormat.inch;
    final pageHeight = 1 * PdfPageFormat.inch;

    // Choose PDF barcode widget type based on requested symbology or numeric length
    pw.Barcode pdfBarcode = pw.Barcode.code128();
    final numericOnly = RegExp(r'^\d+$');
    if (symbology != null) {
      final s = symbology.toLowerCase();
      try {
        if (s == 'code39') {
          pdfBarcode = pw.Barcode.code39();
        } else if (s == 'itf') {
          pdfBarcode = pw.Barcode.itf();
        } else if (s == 'codabar') {
          // Not all pdf libraries expose codabar; try and fallback
          pdfBarcode = pw.Barcode.codabar();
        } else if (s == 'ean13') {
          pdfBarcode = pw.Barcode.ean13();
        } else if (s == 'upca') {
          pdfBarcode = pw.Barcode.upcA();
        } else {
          pdfBarcode = pw.Barcode.code128();
        }
      } catch (_) {
        pdfBarcode = pw.Barcode.code128();
      }
    } else {
      if (barcode.length == 13 && numericOnly.hasMatch(barcode)) {
        pdfBarcode = pw.Barcode.ean13();
      } else if (barcode.length == 12 && numericOnly.hasMatch(barcode)) {
        try {
          pdfBarcode = pw.Barcode.upcA();
        } catch (_) {
          pdfBarcode = pw.Barcode.code128();
        }
      }
    }

    // Add requested number of pages (one label per page)
    if (copies < 1) copies = 1;
    for (int i = 0; i < copies; i++) {
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat(pageWidth, pageHeight),
          build: (pw.Context context) {
            return pw.Container(
              // Add extra vertical padding to prevent barcode from being
              // clipped at the top/bottom when printing.
              padding: const pw.EdgeInsets.symmetric(
                vertical: 8,
                horizontal: 6,
              ),
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  if (productName != null && productName.isNotEmpty)
                    pw.Text(
                      productName,
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(vertical: 4),
                    child: pw.Center(
                      child: pw.BarcodeWidget(
                        barcode: pdfBarcode,
                        data: barcode,
                        width: pageWidth * 0.85,
                        // Reduce barcode height to leave breathing room top/bottom
                        height: pageHeight * 0.38,
                      ),
                    ),
                  ),
                  if (price != null && price.isNotEmpty)
                    pw.Text('Price: $price', style: pw.TextStyle(fontSize: 8)),
                  pw.Text(companyName, style: pw.TextStyle(fontSize: 7)),
                ],
              ),
            );
          },
        ),
      );
    }

    final bytes = await pdf.save();

    File file;
    if (outputPath != null && outputPath.isNotEmpty) {
      file = File(outputPath);
      await file.writeAsBytes(bytes, flush: true);
    } else {
      final dir = (debugEnabled && debugDirectory != null)
          ? Directory(debugDirectory!)
          : Directory.systemTemp;

      if (!(await dir.exists())) {
        try {
          await dir.create(recursive: true);
        } catch (_) {}
      }

      file = File(
        '${dir.path}${Platform.pathSeparator}label_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(bytes, flush: true);
    }

    if (debugOpenAfterSave) {
      await _openFile(file);
    }

    return file;
  }

  String _escapeTspl(String input) {
    // Escape double-quotes for TSPL text fields
    return input.replaceAll('"', '\\"');
  }
}
