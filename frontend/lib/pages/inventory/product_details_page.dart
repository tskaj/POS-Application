import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'package:barcode_widget/barcode_widget.dart';
import '../../models/product.dart';
import '../../models/sub_category.dart';
import '../../models/vendor.dart' as vendor;
import '../../services/inventory_service.dart';
import '../../services/ttp244_printer_service.dart';
import '../../utils/barcode_utils.dart';

class ProductDetailsPage extends StatefulWidget {
  final Product product;
  final List<SubCategory> subCategories;
  final List<vendor.Vendor> vendors;

  const ProductDetailsPage({
    super.key,
    required this.product,
    required this.subCategories,
    required this.vendors,
  });

  @override
  State<ProductDetailsPage> createState() => _ProductDetailsPageState();
}

class _ProductDetailsPageState extends State<ProductDetailsPage> {
  Product? _completeProduct;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchCompleteProduct();
  }

  // Debug controls for printer output (local only)
  bool _printerDebugEnabled = false;
  bool _printerDebugOpen = false;

  Future<void> _fetchCompleteProduct() async {
    try {
      print(
        '🔍 Fetching complete product details for product ID: ${widget.product.id}',
      );
      final completeProduct = await InventoryService.getProduct(
        widget.product.id,
      );

      print('📦 Complete product data received:');
      print('  - ID: ${completeProduct.id}');
      print('  - Title: ${completeProduct.title}');
      print('  - Barcode: ${completeProduct.barcode}');
      print('  - QR Code Data: ${completeProduct.qrCodeData}');
      print('  - QR Code Data is null: ${completeProduct.qrCodeData == null}');
      print(
        '  - QR Code Data is empty: ${completeProduct.qrCodeData?.isEmpty ?? true}',
      );

      setState(() {
        _completeProduct = completeProduct;
        _isLoading = false;
      });

      print('✅ Product details loaded');
      print('Colors: ${completeProduct.colors}');
      print('Sizes: ${completeProduct.sizes}');
      print('Materials: ${completeProduct.materials}');
      print('Seasons: ${completeProduct.seasons}');
    } catch (e) {
      print('❌ Error fetching complete product: $e');
      setState(() {
        _completeProduct = widget.product; // Fallback to passed product
        _isLoading = false;
      });
    }
  }

  Product get _displayProduct => _completeProduct ?? widget.product;

  String _getCategoryName() {
    final subCategoryId = int.tryParse(_displayProduct.subCategoryId);
    final subCategory = subCategoryId != null
        ? widget.subCategories.cast<SubCategory?>().firstWhere(
            (sc) => sc?.id == subCategoryId,
            orElse: () => null,
          )
        : null;
    return subCategory?.category?.title ?? 'N/A';
  }

  String _getSubCategoryName() {
    final subCategoryId = int.tryParse(_displayProduct.subCategoryId);
    final subCategory = subCategoryId != null
        ? widget.subCategories.cast<SubCategory?>().firstWhere(
            (sc) => sc?.id == subCategoryId,
            orElse: () => null,
          )
        : null;
    return subCategory?.title ?? 'N/A';
  }

  Widget _buildDetailRow(String label, String value, {bool isStatus = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade200, width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '$label:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF343A40),
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: isStatus
                ? Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: value == 'Active'
                          ? Color(0xFFD4EDDA)
                          : Color(0xFFF8D7DA),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      value,
                      style: TextStyle(
                        color: value == 'Active'
                            ? Color(0xFF155724)
                            : Color(0xFF721C24),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                : Text(
                    value,
                    style: TextStyle(color: Color(0xFF6C757D), fontSize: 14),
                  ),
          ),
        ],
      ),
    );
  }

  void _showBarcodeDialog() {
    if (_displayProduct.barcode.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                      child: const Icon(
                        Icons.qr_code_scanner,
                        color: Color(0xFF0D1845),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Product Barcode',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Barcode
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: BarcodeWidget(
                    // render numeric EAN-13 derived from product
                    barcode: Barcode.ean13(),
                    data: getNumericBarcode(_displayProduct),
                    width: 300,
                    height: 120,
                    drawText: false,
                  ),
                ),

                const SizedBox(height: 20),

                // Product Info
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Product: ${_displayProduct.title}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Barcode: ${getNumericBarcode(_displayProduct)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons: Close | Preview Label | View Barcode | Print Barcode
                Row(
                  children: [
                    // Close Button
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF0D1845),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0D1845),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Close'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Preview Label Button (elegant gradient)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D1845), Color(0xFF1A237E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.12),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: _showLabelPreview,
                          icon: const Icon(
                            Icons.preview,
                            size: 18,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Preview Label',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                            shadowColor: Colors.transparent,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _showBarcodeDialog,
                        icon: const Icon(Icons.qr_code_scanner, size: 18),
                        label: const Text('View Barcode'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Print Button (keeps existing behavior)
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Sending print job...'),
                            ),
                          );
                          try {
                            await Ttp244PrinterService.instance.printBarcode3x1(
                              barcode: getNumericBarcode(_displayProduct),
                              productName: _displayProduct.title,
                              price: _displayProduct.salePrice.toString(),
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Print job queued (or written to temp file).',
                                  ),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Print failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.print, size: 18),
                        label: const Text('Print Barcode'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.12),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showQrCodeDialog() {
    if (_displayProduct.qrCodeData == null ||
        _displayProduct.qrCodeData!.isEmpty)
      return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Container(
            padding: const EdgeInsets.all(24),
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
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
                      child: const Icon(
                        Icons.qr_code,
                        color: Color(0xFF0D1845),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Product QR Code',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // QR Code
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: QrImageView(
                    data: _displayProduct.qrCodeData!,
                    version: QrVersions.auto,
                    size: 200.0,
                  ),
                ),

                const SizedBox(height: 20),

                // Product Info
                Container(
                  padding: const EdgeInsets.all(16),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Product: ${_displayProduct.title}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Design Code: ${_displayProduct.designCode}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    // Close Button
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: const Color(0xFF0D1845),
                            width: 1.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: ElevatedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF0D1845),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 0,
                          ),
                          child: const Text('Close'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Preview Label Button (elegant)
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D1845), Color(0xFF1A237E)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.08),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () {
                            Navigator.of(context).pop();
                            // show preview after closing QR dialog
                            WidgetsBinding.instance.addPostFrameCallback((_) {
                              _showLabelPreview();
                            });
                          },
                          icon: const Icon(
                            Icons.preview,
                            size: 16,
                            color: Colors.white,
                          ),
                          label: const Text(
                            'Preview Label',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 0,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showLabelPreview() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        final product = _displayProduct;
        // A dialog that mimics the 2x1 label layout
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Container(
            padding: const EdgeInsets.all(12),
            width: 320,
            // Height approximates 2" x 1" scaled on screen
            height: 220,
            color: Colors.white,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Product name (top)
                Text(
                  product.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),

                // Barcode (middle)
                Expanded(
                  child: Center(
                    child: BarcodeWidget(
                      // render numeric EAN-13 for the preview label
                      barcode: Barcode.ean13(),
                      data: getNumericBarcode(product),
                      width: 240,
                      height: 80,
                      drawText: false,
                    ),
                  ),
                ),

                // Price and company (bottom)
                Column(
                  children: [
                    Text(
                      'Price: ${product.salePrice}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Dhanpuri by Get Going',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Actions: Save PDF | Send to Printer
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop();

                          // Ask user where to save the PDF
                          final safeName = product.title.replaceAll(
                            RegExp(r'[\\/:*?"<>|]'),
                            '_',
                          );
                          final defaultName =
                              '${safeName}_${DateTime.now().millisecondsSinceEpoch}.pdf';
                          String? savePath;
                          try {
                            savePath = await FilePicker.platform.saveFile(
                              dialogTitle: 'Save label as PDF',
                              fileName: defaultName,
                              type: FileType.custom,
                              allowedExtensions: ['pdf'],
                            );
                          } catch (e) {
                            // fall back to no path
                            savePath = null;
                          }

                          if (savePath == null) {
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(content: Text('Save cancelled')),
                              );
                            }
                            return;
                          }

                          if (mounted) {
                            ScaffoldMessenger.of(this.context).showSnackBar(
                              const SnackBar(
                                content: Text('Generating PDF...'),
                              ),
                            );
                          }

                          try {
                            // Ask how many copies/pages the user wants
                            final qty = await _askQuantityDialog(initial: 1);
                            if (qty == null) {
                              if (mounted) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Save cancelled'),
                                  ),
                                );
                              }
                              return;
                            }

                            final file = await Ttp244PrinterService.instance
                                .savePdfLabel(
                                  barcode: getNumericBarcode(product),
                                  productName: product.title,
                                  price: product.salePrice.toString(),
                                  outputPath: savePath,
                                  copies: qty,
                                );
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('Saved PDF: ${file.path}'),
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to generate PDF: $e'),
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.picture_as_pdf),
                        label: const Text('Save as PDF'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop();
                          ScaffoldMessenger.of(this.context).showSnackBar(
                            const SnackBar(
                              content: Text('Sending to printer...'),
                            ),
                          );
                          try {
                            // Ask for quantity to print
                            final qty = await _askQuantityDialog(initial: 1);
                            if (qty == null) {
                              if (mounted) {
                                ScaffoldMessenger.of(this.context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Print cancelled'),
                                  ),
                                );
                              }
                              return;
                            }

                            await Ttp244PrinterService.instance.printBarcode3x1(
                              barcode: getNumericBarcode(product),
                              productName: product.title,
                              price: product.salePrice.toString(),
                              copies: qty,
                            );
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                const SnackBar(
                                  content: Text('Print job queued'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(this.context).showSnackBar(
                                SnackBar(
                                  content: Text('Print failed: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.print),
                        label: const Text('Send to Printer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D1845),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<int?> _askQuantityDialog({int initial = 1}) async {
    final TextEditingController controller = TextEditingController(
      text: initial.toString(),
    );
    return showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('How many labels to print?'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Enter quantity'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final value = int.tryParse(controller.text.trim());
                if (value == null || value <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please enter a valid quantity'),
                    ),
                  );
                  return;
                }
                Navigator.of(context).pop(value);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Color(0xFFF8F9FA),
        appBar: AppBar(
          backgroundColor: Colors.white,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: Color(0xFF0D1845)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            'Product Details',
            style: TextStyle(
              color: Color(0xFF0D1845),
              fontWeight: FontWeight.w600,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: Center(
          child: CircularProgressIndicator(color: Color(0xFF0D1845)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Color(0xFFF8F9FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Color(0xFF0D1845)),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Product Details',
          style: TextStyle(
            color: Color(0xFF0D1845),
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        actions: [
          // View Barcode button
          IconButton(
            tooltip: 'View Barcode',
            icon: Icon(Icons.qr_code_scanner, color: Color(0xFF0D1845)),
            onPressed: _showBarcodeDialog,
          ),
          // View QR Code button
          IconButton(
            tooltip: 'View QR Code',
            icon: Icon(Icons.qr_code, color: Color(0xFF0D1845)),
            onPressed: _showQrCodeDialog,
          ),
        ],
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          width: double.infinity,
          child: Container(
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.inventory_2,
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
                              _displayProduct.title,
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Product Code: ${_displayProduct.designCode}',
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
                ),

                // Product Details
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Product Information',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF343A40),
                        ),
                      ),
                      const SizedBox(height: 16),

                      _buildDetailRow('Product Name', _displayProduct.title),
                      _buildDetailRow(
                        'Design Code',
                        _displayProduct.designCode,
                      ),
                      // Barcode Button
                      if (_displayProduct.barcode.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 140,
                                child: Text(
                                  'Barcode:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF343A40),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF0D1845),
                                        const Color(0xFF1A237E),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF0D1845,
                                        ).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: _showBarcodeDialog,
                                          icon: const Icon(
                                            Icons.qr_code_scanner,
                                            size: 18,
                                          ),
                                          label: const Text('View Barcode'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.transparent,
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                              horizontal: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            elevation: 0,
                                            shadowColor: Colors.transparent,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      // Print button
                                      Expanded(
                                        child: ElevatedButton.icon(
                                          onPressed: () async {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              const SnackBar(
                                                content: Text(
                                                  'Sending print job...',
                                                ),
                                              ),
                                            );
                                            try {
                                              await Ttp244PrinterService
                                                  .instance
                                                  .printBarcode3x1(
                                                    barcode: getNumericBarcode(
                                                      _displayProduct,
                                                    ),
                                                    productName:
                                                        _displayProduct.title,
                                                    price: _displayProduct
                                                        .salePrice
                                                        .toString(),
                                                  );
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  const SnackBar(
                                                    content: Text(
                                                      'Print job queued (or written to temp file).',
                                                    ),
                                                    backgroundColor:
                                                        Colors.green,
                                                  ),
                                                );
                                              }
                                            } catch (e) {
                                              if (mounted) {
                                                ScaffoldMessenger.of(
                                                  context,
                                                ).showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      'Print failed: $e',
                                                    ),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                              }
                                            }
                                          },
                                          icon: const Icon(
                                            Icons.print,
                                            size: 18,
                                          ),
                                          label: const Text('Print Barcode'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: Colors.white
                                                .withOpacity(0.12),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 12,
                                              horizontal: 16,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            elevation: 0,
                                            shadowColor: Colors.transparent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      // QR Code Button
                      if (_displayProduct.qrCodeData != null &&
                          _displayProduct.qrCodeData!.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(
                                color: Colors.grey.shade200,
                                width: 1,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 140,
                                child: Text(
                                  'QR Code:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF343A40),
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              Expanded(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        const Color(0xFF0D1845),
                                        const Color(0xFF1A237E),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF0D1845,
                                        ).withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton.icon(
                                    onPressed: _showQrCodeDialog,
                                    icon: const Icon(Icons.qr_code, size: 18),
                                    label: const Text('View QR Code'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      elevation: 0,
                                      shadowColor: Colors.transparent,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      _buildDetailRow('Category', _getCategoryName()),
                      _buildDetailRow('Sub Category', _getSubCategoryName()),
                      _buildDetailRow(
                        'Vendor',
                        _displayProduct.vendor.name ?? 'N/A',
                      ),
                      _buildDetailRow(
                        'Sale Price',
                        'PKR ${_displayProduct.salePrice}',
                      ),
                      _buildDetailRow(
                        'In Stock Quantity',
                        _displayProduct.inStockQuantity,
                      ),
                      // Variants section
                      if (_displayProduct.colors != null &&
                          _displayProduct.colors!.isNotEmpty)
                        _buildDetailRow('Colors', _displayProduct.colors!),
                      if (_displayProduct.sizes != null &&
                          _displayProduct.sizes!.isNotEmpty)
                        _buildDetailRow('Sizes', _displayProduct.sizes!),
                      if (_displayProduct.materials != null &&
                          _displayProduct.materials!.isNotEmpty)
                        _buildDetailRow(
                          'Materials',
                          _displayProduct.materials!,
                        ),
                      if (_displayProduct.seasons != null &&
                          _displayProduct.seasons!.isNotEmpty)
                        _buildDetailRow('Seasons', _displayProduct.seasons!),
                      _buildDetailRow(
                        'Status',
                        _displayProduct.status,
                        isStatus: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
