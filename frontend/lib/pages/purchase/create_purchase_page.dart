import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:typed_data';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:printing/printing.dart';
import '../../services/inventory_service.dart';
import '../../services/purchases_service.dart';
import '../../models/vendor.dart' as vendor;
import '../../models/product.dart';

class CreatePurchasePage extends StatefulWidget {
  const CreatePurchasePage({super.key});

  @override
  State<CreatePurchasePage> createState() => _CreatePurchasePageState();
}

class _CreatePurchasePageState extends State<CreatePurchasePage> {
  final _formKey = GlobalKey<FormState>();
  final _referenceController = TextEditingController();
  final _shippingPriceController = TextEditingController();
  final _orderTaxController = TextEditingController();
  final _orderDiscountController = TextEditingController();
  final _notesController = TextEditingController();

  // Vendor search
  List<vendor.Vendor> _filteredVendors = [];
  final TextEditingController _vendorSearchController = TextEditingController();

  // Product search
  List<Product> _filteredProducts = [];
  final TextEditingController _productSearchController =
      TextEditingController();

  DateTime _selectedDate = DateTime.now();
  int? _selectedVendorId;
  List<vendor.Vendor> vendors = [];
  List<Product> products = [];
  List<PurchaseItem> purchaseItems = [];
  bool isSubmitting = false;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchVendors();
    // Remove initial product fetch - products will be loaded when vendor is selected

    // Add listeners to update calculations in real-time
    _orderTaxController.addListener(() => setState(() {}));
    _orderDiscountController.addListener(() => setState(() {}));
    _shippingPriceController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _referenceController.dispose();
    _shippingPriceController.dispose();
    _orderTaxController.dispose();
    _orderDiscountController.dispose();
    _notesController.dispose();
    _vendorSearchController.dispose();
    _productSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchVendors() async {
    try {
      // Fetch all vendors from all pages (similar to vendors page)
      List<vendor.Vendor> allVendors = [];
      int currentFetchPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        try {
          print('📡 Fetching vendors page $currentFetchPage');
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
          print('❌ Error fetching vendors page $currentFetchPage: $e');
          hasMorePages = false; // Stop fetching on error
        }
      }

      setState(() {
        vendors = allVendors;
      });

      print('✅ Fetched ${vendors.length} total vendors for purchase page');
    } catch (e) {
      setState(() {
        vendors = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load vendors: $e'),
          backgroundColor: Color(0xFFDC3545),
        ),
      );
    }
  }

  Future<void> _fetchProductsByVendor(int vendorId) async {
    try {
      // Try to fetch a large page of products so we include products for the
      // selected vendor (backend paginates results). If the backend supports
      // server-side vendor filtering in the future we should use that.
      final productResponse = await InventoryService.getProducts(
        page: 1,
        limit: 1000,
      );

      // Filter products by the selected vendor. Product.vendorId is stored
      // as a String in the model; also check nested vendor.id when available.
      final filteredProducts = productResponse.data.where((product) {
        final prodVendorId = product.vendorId.toString();
        final prodVendorObjId = product.vendor.id;
        return prodVendorId == vendorId.toString() ||
            prodVendorObjId == vendorId;
      }).toList();

      setState(() {
        products = filteredProducts;
      });
    } catch (e) {
      setState(() {
        products = [];
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load products for selected vendor: $e'),
          backgroundColor: Color(0xFFDC3545),
        ),
      );
    }
  }

  void _addPurchaseItem() {
    setState(() {
      purchaseItems.add(PurchaseItem());
    });
  }

  void _removePurchaseItem(int index) {
    setState(() {
      purchaseItems.removeAt(index);
    });
  }

  void _updatePurchaseItem(int index, PurchaseItem item) {
    setState(() {
      purchaseItems[index] = item;
    });
  }

  double _calculateGrandTotal() {
    double subtotal = 0;
    for (var item in purchaseItems) {
      subtotal += item.unitCost * item.quantity;
    }

    // Get values from controllers (default to 0 if empty or invalid)
    double orderTaxPercent = double.tryParse(_orderTaxController.text) ?? 0;
    double orderDiscountPercent =
        double.tryParse(_orderDiscountController.text) ?? 0;
    double shippingPrice = double.tryParse(_shippingPriceController.text) ?? 0;

    // Calculate order discount as percentage of subtotal
    double orderDiscountAmount = subtotal * (orderDiscountPercent / 100);

    // Apply discount first
    double totalAfterDiscount = subtotal - orderDiscountAmount;

    // Then add order tax as percentage of discounted total
    double orderTaxAmount = totalAfterDiscount * (orderTaxPercent / 100);

    // Add shipping to get grand total
    return totalAfterDiscount + orderTaxAmount + shippingPrice;
  }

  double _calculateSubtotal() {
    double subtotal = 0;
    for (var item in purchaseItems) {
      subtotal += item.unitCost * item.quantity;
    }
    return subtotal;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF0D1845),
              onPrimary: Colors.white,
              onSurface: Color(0xFF343A40),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (purchaseItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please add at least one product to the purchase'),
          backgroundColor: Color(0xFFDC3545),
        ),
      );
      return;
    }

    // Validate all purchase items
    for (int i = 0; i < purchaseItems.length; i++) {
      if (purchaseItems[i].productId == null ||
          purchaseItems[i].quantity <= 0 ||
          purchaseItems[i].purchasePrice <= 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Please complete all product details for item ${i + 1}',
            ),
            backgroundColor: Color(0xFFDC3545),
          ),
        );
        return;
      }
    }

    setState(() => isSubmitting = true);

    try {
      // Prepare purchase data for API
      final purchaseData = {
        'pur_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'transaction_type_id': 1, // Purchase Transaction
        'payment_mode_id': 3, // Credit
        'user_id': 1,
        'vendor_id': _selectedVendorId,
        'ven_inv_no': _referenceController.text,
        'ven_inv_date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'ven_inv_ref': _referenceController.text,
        'pur_inv_barcode': _referenceController.text.isNotEmpty
            ? _referenceController.text
            : 'AUTO-${DateTime.now().millisecondsSinceEpoch}',
        'description': _notesController.text,
        'discount_percent':
            (double.tryParse(_orderDiscountController.text) ?? 0).toString(),
        'discount_amt':
            (_calculateSubtotal() *
                    ((double.tryParse(_orderDiscountController.text) ?? 0) /
                        100))
                .toString(),
        'tax_percent': (double.tryParse(_orderTaxController.text) ?? 0)
            .toString(),
        'tax_amt':
            ((_calculateSubtotal() -
                        (_calculateSubtotal() *
                            ((double.tryParse(_orderDiscountController.text) ??
                                    0) /
                                100))) *
                    ((double.tryParse(_orderTaxController.text) ?? 0) / 100))
                .toString(),
        'paid_amount': 0.0.toString(),
        'shipping_amt': (double.tryParse(_shippingPriceController.text) ?? 0)
            .toString(),
        'payment_status': 'unpaid',
        'details': purchaseItems.map((item) {
          return {
            'product_id': item.productId.toString(),
            'qty': item.quantity.toString(),
            'unit_price': item.purchasePrice.toString(),
            'discPer': item.discount.toString(),
            'discAmount':
                ((item.purchasePrice * item.quantity * item.discount / 100))
                    .toString(),
          };
        }).toList(),
      };

      // Debug: Print the purchase data being sent
      print('Purchase data being sent: $purchaseData');

      // Call API to create purchase
      final createdPurchase = await PurchaseService.createPurchase(
        purchaseData,
      );

      // Show success dialog with option to generate invoice
      if (mounted) {
        final result = await showDialog<String>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Color(0xFF28A745).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.check_circle,
                      color: Color(0xFF28A745),
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Purchase Created!',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Purchase #PUR-${createdPurchase.purInvId} has been created successfully.',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Total Amount: Rs. ${_calculateGrandTotal().toStringAsFixed(2)}',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Would you like to generate a PDF invoice?',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop('close'),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text('Close', style: TextStyle(fontSize: 16)),
                ),
                ElevatedButton.icon(
                  onPressed: () => Navigator.of(dialogContext).pop('generate'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0D1845),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text(
                    'Generate Invoice',
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ],
            );
          },
        );

        // Handle the result after dialog is closed
        if (result == 'generate' && mounted) {
          await _generatePurchaseInvoice(createdPurchase);
        }
      }

      // Navigate back to purchase listing page with success result
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Failed to create purchase: $e')),
            ],
          ),
          backgroundColor: Color(0xFFDC3545),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  Future<void> _generatePurchaseInvoice(Purchase purchase) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return const AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(),
                SizedBox(width: 16),
                Text('Generating PDF...'),
              ],
            ),
          );
        },
      );

      // Create PDF document with custom page size (80mm width, flexible height)
      // 80mm = 226.77 points (80mm / 25.4mm per inch * 72 points per inch)
      const double pageWidthInPoints = 226.77; // Exactly 80mm
      const double initialPageHeightInPoints =
          1000; // Will be resized to fit content
      const double receiptWidthPx =
          pageWidthInPoints; // Drawing width matches page width
      const double leftMarginPx = 10.0; // left margin for spacing
      const double rightMarginPx = 10.0; // Right margin for spacing

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

      final double printableWidth =
          receiptWidthPx - leftMarginPx - rightMarginPx;
      double yPos = 6.0; // Minimal top margin

      // Header - compact spacing for narrow width
      graphics.drawString(
        'PURCHASE INVOICE',
        boldFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 12),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );
      yPos += 10;

      graphics.drawString(
        'Dhanpuri By Get Going',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.top,
        ),
      );
      yPos += 8;

      graphics.drawString(
        'Civil line road opposite MCB Bank Jhelum',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.top,
        ),
      );
      yPos += 8;

      graphics.drawString(
        'Phone # 0544 276590',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.top,
        ),
      );
      yPos += 10;

      // Separator line
      graphics.drawLine(
        PdfPen(PdfColor(0, 0, 0), width: 0.5),
        Offset(leftMarginPx, yPos),
        Offset(receiptWidthPx - rightMarginPx, yPos),
      );
      yPos += 6;

      // Purchase Info - tight spacing for narrow width
      graphics.drawString(
        'PUR-${purchase.purInvId}',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
      );
      yPos += 8;

      graphics.drawString(
        'Date: ${DateFormat('dd/MM/yy').format(DateTime.parse(purchase.purDate))} ${DateFormat('HH:mm').format(DateTime.now())}',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
      );
      yPos += 8;

      // Vendor info - tight spacing
      graphics.drawString(
        'Vendor: ${purchase.vendorName}',
        regularFont,
        bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
      );
      yPos += 8;

      if (purchase.venInvNo.isNotEmpty) {
        graphics.drawString(
          'Ven Inv: ${purchase.venInvNo}',
          regularFont,
          bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
        );
        yPos += 8;
      }

      if (purchase.venInvRef.isNotEmpty) {
        graphics.drawString(
          'Ref: ${purchase.venInvRef}',
          regularFont,
          bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 10),
        );
        yPos += 8;
      }

      // Separator line
      graphics.drawLine(
        PdfPen(PdfColor(0, 0, 0), width: 0.5),
        Offset(leftMarginPx, yPos),
        Offset(receiptWidthPx - rightMarginPx, yPos),
      );
      yPos += 6;

      // Items Header - optimized column widths for narrow printable area
      final double itemWidth = printableWidth * 0.45; // Item name
      final double qtyWidth = printableWidth * 0.15; // Quantity
      final double priceWidth = printableWidth * 0.20; // Price
      final double totalWidth = printableWidth * 0.20; // Total

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
        Offset(leftMarginPx, yPos),
        Offset(receiptWidthPx - rightMarginPx, yPos),
      );
      yPos += 5;

      // Items list - very tight spacing for narrow width
      const double itemHeight = 9.0; // Reduced for narrow width
      const double extraLineHeight = 6.0; // For discount lines

      for (var item in purchaseItems) {
        final String name = item.description;
        final int qty = item.quantity;
        final double price = item.purchasePrice;
        final double itemTotal = qty * price;

        graphics.drawString(
          name,
          regularFont,
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
        if (item.discount > 0) {
          final double discountPercent = item.discount; // Already a percentage
          final double discountAmount = (item.discount / 100) * price * qty;
          final String discountText = discountPercent > 0
              ? '- Discount: ${discountPercent.toStringAsFixed(0)}% (Rs ${discountAmount.toStringAsFixed(2)})'
              : '- Discount: Rs ${discountAmount.toStringAsFixed(2)}';

          final double bulletIndent = 3.0;
          graphics.drawString(
            discountText,
            smallFont,
            bounds: Rect.fromLTWH(
              colItemX + bulletIndent,
              yPos,
              itemWidth + qtyWidth + priceWidth - bulletIndent,
              7,
            ),
          );
          graphics.drawString(
            '- Rs ${discountAmount.toStringAsFixed(2)}',
            smallFont,
            bounds: Rect.fromLTWH(colTotalX, yPos, totalWidth, 7),
            format: PdfStringFormat(alignment: PdfTextAlignment.right),
          );
          yPos += extraLineHeight;
        }
      }

      yPos += 3; // Minimal spacing

      // Separator line
      graphics.drawLine(
        PdfPen(PdfColor(0, 0, 0), width: 0.5),
        Offset(leftMarginPx, yPos),
        Offset(receiptWidthPx - rightMarginPx, yPos),
      );
      yPos += 6;

      // Totals Section - tight spacing for narrow width
      final double totalsLabelWidth = printableWidth * 0.50;
      final double totalsValueWidth = printableWidth - totalsLabelWidth;

      // Subtotal - tight layout
      double subtotal = 0;
      for (var item in purchaseItems) {
        final double price = item.purchasePrice;
        final int qty = item.quantity;
        final double discountAmount =
            (price * qty * item.discount / 100); // item.discount is percent
        subtotal += (price * qty) - discountAmount;
      }
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
      yPos += 8;

      // Discount - use stored value to align with API
      double discountAmount = double.tryParse(purchase.discountAmt) ?? 0;
      if (discountAmount > 0) {
        double discountPercent = double.tryParse(purchase.discountPercent) ?? 0;
        final String discountLabel =
            'Discount (${discountPercent.toStringAsFixed(0)}%):';
        graphics.drawString(
          discountLabel,
          regularFont,
          bounds: Rect.fromLTWH(leftMarginPx, yPos, totalsLabelWidth, 10),
        );
        graphics.drawString(
          '- Rs ${discountAmount.toStringAsFixed(2)}',
          regularFont,
          bounds: Rect.fromLTWH(
            leftMarginPx + totalsLabelWidth,
            yPos,
            totalsValueWidth,
            10,
          ),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        yPos += 8;
      }

      // Tax - use stored value to align with API
      double taxAmount = double.tryParse(purchase.taxAmt) ?? 0;
      if (taxAmount > 0) {
        double taxPercent = double.tryParse(purchase.taxPercent) ?? 0;
        graphics.drawString(
          'Tax (${taxPercent.toStringAsFixed(0)}%):',
          regularFont,
          bounds: Rect.fromLTWH(leftMarginPx, yPos, totalsLabelWidth, 10),
        );
        graphics.drawString(
          'Rs ${taxAmount.toStringAsFixed(2)}',
          regularFont,
          bounds: Rect.fromLTWH(
            leftMarginPx + totalsLabelWidth,
            yPos,
            totalsValueWidth,
            10,
          ),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        yPos += 8;
      }

      // Shipping
      double shipping = double.tryParse(_shippingPriceController.text) ?? 0;
      if (shipping > 0) {
        graphics.drawString(
          'Shipping:',
          regularFont,
          bounds: Rect.fromLTWH(leftMarginPx, yPos, totalsLabelWidth, 10),
        );
        graphics.drawString(
          'Rs ${shipping.toStringAsFixed(2)}',
          regularFont,
          bounds: Rect.fromLTWH(
            leftMarginPx + totalsLabelWidth,
            yPos,
            totalsValueWidth,
            10,
          ),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
        yPos += 8;
      }

      // Separator
      graphics.drawLine(
        PdfPen(PdfColor(0, 0, 0), width: 1.0),
        Offset(leftMarginPx, yPos),
        Offset(receiptWidthPx - rightMarginPx, yPos),
      );
      yPos += 6;

      // Grand Total - use stored value to align with API
      double total = double.tryParse(purchase.invAmount) ?? 0;

      graphics.drawString(
        'TOTAL:',
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
      yPos += 10;

      // Notes
      if (_notesController.text.isNotEmpty) {
        graphics.drawString(
          'Notes: ${_notesController.text}',
          smallFont,
          bounds: Rect.fromLTWH(leftMarginPx, yPos, printableWidth, 20),
        );
        yPos += 16;
      }

      // Separator
      graphics.drawLine(
        PdfPen(PdfColor(0, 0, 0), width: 0.5),
        Offset(leftMarginPx, yPos),
        Offset(receiptWidthPx - rightMarginPx, yPos),
      );
      yPos += 6;

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
      yPos += 8;

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

      // Save PDF
      final List<int> bytes = await document.save();
      document.dispose();

      // Close loading dialog
      if (mounted) {
        Navigator.of(context).pop();
      }

      // Save and share the PDF directly (80mm thermal receipt, flexible height)
      // No print dialog - directly saves like barcode printing
      await Printing.sharePdf(
        bytes: Uint8List.fromList(bytes),
        filename:
            'purchase_invoice_${purchase.purInvId}_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Invoice saved successfully')),
              ],
            ),
            backgroundColor: Color(0xFF28A745),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text('Failed to generate invoice: $e')),
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
    }
  }

  List<PurchaseItem> _getPaginatedItems() {
    int startIndex = _currentPage * 10;
    int endIndex = startIndex + 10;
    if (endIndex > purchaseItems.length) {
      endIndex = purchaseItems.length;
    }
    return purchaseItems.sublist(startIndex, endIndex);
  }

  int _getTotalPages() {
    return (purchaseItems.length / 10).ceil();
  }

  // Returns true if any form field or selection indicates unsaved changes
  bool _hasUnsavedChanges() {
    if (_referenceController.text.trim().isNotEmpty) return true;
    if (_shippingPriceController.text.trim().isNotEmpty) return true;
    if (_orderTaxController.text.trim().isNotEmpty) return true;
    if (_orderDiscountController.text.trim().isNotEmpty) return true;
    if (_notesController.text.trim().isNotEmpty) return true;
    if (_selectedVendorId != null) return true;
    if (purchaseItems.isNotEmpty) return true;
    return false;
  }

  // Shows confirmation dialog and returns true when user confirms leaving
  Future<bool> _confirmLeave() async {
    if (!_hasUnsavedChanges()) return true;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Text(
            'Are you sure you want to leave?',
            style: TextStyle(color: Colors.black87),
          ),
          content: const Text(
            'Unsaved changes will be lost.',
            style: TextStyle(color: Colors.black87),
          ),
          actions: [
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.black87),
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Leave'),
            ),
          ],
        );
      },
    );

    return result == true;
  }

  // Vendor Search Dialog
  void _showVendorSearchDialog() {
    _filteredVendors = List.from(vendors);
    _vendorSearchController.clear();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void filterVendors(String query) {
              setDialogState(() {
                if (query.isEmpty) {
                  _filteredVendors = List.from(vendors);
                } else {
                  _filteredVendors = vendors.where((v) {
                    final name = v.fullName.toLowerCase();
                    final code = v.vendorCode.toLowerCase();
                    final q = query.toLowerCase();
                    return name.contains(q) || code.contains(q);
                  }).toList();
                }
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.5,
                constraints: BoxConstraints(maxHeight: 600, maxWidth: 500),
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xFF0D1845).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.business,
                            color: Color(0xFF0D1845),
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Select Vendor',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _vendorSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name or code...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onChanged: filterVendors,
                    ),
                    SizedBox(height: 16),
                    Flexible(
                      child: _filteredVendors.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No vendors found',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _filteredVendors.length,
                              itemBuilder: (context, index) {
                                final v = _filteredVendors[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Color(
                                      0xFF0D1845,
                                    ).withOpacity(0.1),
                                    child: Icon(
                                      Icons.business,
                                      color: Color(0xFF0D1845),
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    v.fullName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text('Code: ${v.vendorCode}'),
                                  onTap: () {
                                    setState(() {
                                      _selectedVendorId = v.id;
                                      products = [];
                                      purchaseItems = [];
                                    });
                                    _fetchProductsByVendor(v.id);
                                    Navigator.of(dialogContext).pop();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  // Product Search Dialog for adding items
  void _showProductSearchDialog(int itemIndex) {
    _filteredProducts = List.from(products);
    _productSearchController.clear();

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            void filterProducts(String query) {
              setDialogState(() {
                if (query.isEmpty) {
                  _filteredProducts = List.from(products);
                } else {
                  _filteredProducts = products.where((p) {
                    final title = p.title.toLowerCase();
                    final code = p.designCode.toLowerCase();
                    final q = query.toLowerCase();
                    return title.contains(q) || code.contains(q);
                  }).toList();
                }
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.5,
                constraints: BoxConstraints(maxHeight: 600, maxWidth: 500),
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Color(0xFF0D1845).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.inventory_2,
                            color: Color(0xFF0D1845),
                            size: 24,
                          ),
                        ),
                        SizedBox(width: 12),
                        Text(
                          'Select Product',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 20),
                    TextField(
                      controller: _productSearchController,
                      decoration: InputDecoration(
                        hintText: 'Search by name or code...',
                        prefixIcon: Icon(Icons.search, size: 20),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                      ),
                      onChanged: filterProducts,
                    ),
                    SizedBox(height: 16),
                    Flexible(
                      child: _filteredProducts.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.search_off,
                                    size: 48,
                                    color: Colors.grey,
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    _selectedVendorId == null
                                        ? 'Please select a vendor first'
                                        : 'No products found',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              shrinkWrap: true,
                              itemCount: _filteredProducts.length,
                              itemBuilder: (context, index) {
                                final p = _filteredProducts[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: Color(
                                      0xFF0D1845,
                                    ).withOpacity(0.1),
                                    child: Icon(
                                      Icons.inventory_2,
                                      color: Color(0xFF0D1845),
                                      size: 20,
                                    ),
                                  ),
                                  title: Text(
                                    p.title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  subtitle: Text(
                                    'Code: ${p.designCode} | Rs. ${p.salePrice}',
                                  ),
                                  onTap: () {
                                    PurchaseItem updatedItem =
                                        purchaseItems[itemIndex].copyWith(
                                          productId: p.id,
                                          description: p.title,
                                          purchasePrice:
                                              double.tryParse(
                                                p.buyingPrice ?? '0',
                                              ) ??
                                              0,
                                        );
                                    _updatePurchaseItem(itemIndex, updatedItem);
                                    Navigator.of(dialogContext).pop();
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(56),
        child: AppBar(
          backgroundColor: const Color(0xFF0D1845),
          foregroundColor: Colors.white,
          elevation: 2,
          shadowColor: const Color(0xFF0D1845).withOpacity(0.3),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.add_shopping_cart,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Create Purchase Order',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: () async {
              if (await _confirmLeave()) {
                Navigator.of(context).pop();
              }
            },
            tooltip: 'Back',
          ),
        ),
      ),
      backgroundColor: const Color(0xFFF8F9FA),
      body: WillPopScope(
        onWillPop: () => _confirmLeave(),
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Container(
                      padding: const EdgeInsets.all(16),
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
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.add_shopping_cart,
                              color: Colors.white,
                              size: 24,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Create Purchase Order',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Add new purchase order transaction',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.white.withOpacity(0.8),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Form Container
                    Container(
                      padding: const EdgeInsets.all(20),
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
                          // Basic Information Section
                          _buildSectionHeader('Basic Information', Icons.info),
                          const SizedBox(height: 12),

                          // Row 1: Vendor & Date
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 4,
                                        bottom: 4,
                                      ),
                                      child: Text(
                                        'Vendor *',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: _showVendorSearchDialog,
                                      child: Container(
                                        height: 38,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.business,
                                              color: Color(0xFF0D1845),
                                              size: 16,
                                            ),
                                            SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                _selectedVendorId != null
                                                    ? vendors
                                                          .firstWhere(
                                                            (v) =>
                                                                v.id ==
                                                                _selectedVendorId,
                                                          )
                                                          .fullName
                                                    : 'Select vendor',
                                                style: TextStyle(fontSize: 12),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            Icon(
                                              Icons.arrow_drop_down,
                                              size: 16,
                                              color: Colors.grey,
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 4,
                                        bottom: 4,
                                      ),
                                      child: Text(
                                        'Date *',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () => _selectDate(context),
                                      child: Container(
                                        height: 38,
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.calendar_today,
                                              size: 16,
                                              color: Color(0xFF0D1845),
                                            ),
                                            SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                DateFormat(
                                                  'dd MMM yyyy',
                                                ).format(_selectedDate),
                                                style: TextStyle(fontSize: 12),
                                              ),
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
                          const SizedBox(height: 12),

                          // Row 2: Reference
                          Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        left: 4,
                                        bottom: 4,
                                      ),
                                      child: Text(
                                        'Reference',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    TextFormField(
                                      controller: _referenceController,
                                      decoration: InputDecoration(
                                        hintText: 'PO number',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        contentPadding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        hintStyle: TextStyle(fontSize: 12),
                                      ),
                                      style: TextStyle(fontSize: 12),
                                      validator: (value) =>
                                          value?.isEmpty ?? true
                                          ? 'Required'
                                          : null,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Products Section
                          _buildSectionHeader('Products', Icons.inventory),
                          const SizedBox(height: 12),

                          // Add Product Button
                          Row(
                            children: [
                              ElevatedButton.icon(
                                onPressed: _addPurchaseItem,
                                icon: Icon(Icons.add, size: 18),
                                label: Text('Add Product'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Color(0xFF0D1845),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${purchaseItems.length} products added',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6C757D),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12), // Products Table
                          if (purchaseItems.isNotEmpty) ...[
                            Container(
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
                              child: Column(
                                children: [
                                  // Table Header
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Color(0xFF0D1845),
                                      borderRadius: BorderRadius.only(
                                        topLeft: Radius.circular(12),
                                        topRight: Radius.circular(12),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.inventory,
                                          color: Colors.white,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Purchase Items',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Table Content
                                  SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      headingRowColor:
                                          MaterialStateProperty.all(
                                            Color(0xFFF8F9FA),
                                          ),
                                      dataRowColor:
                                          MaterialStateProperty.resolveWith<
                                            Color
                                          >((Set<MaterialState> states) {
                                            if (states.contains(
                                              MaterialState.selected,
                                            )) {
                                              return Color(
                                                0xFF0D1845,
                                              ).withOpacity(0.1);
                                            }
                                            return Colors.white;
                                          }),
                                      columnSpacing: 16.0,
                                      dataRowMinHeight: 60.0,
                                      dataRowMaxHeight: 80.0,
                                      headingRowHeight: 50.0,
                                      columns: const [
                                        DataColumn(
                                          label: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                            ),
                                            child: Text(
                                              'Product',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                            ),
                                            child: Text(
                                              'Qty',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                            ),
                                            child: Text(
                                              'Purchase Price',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                            ),
                                            child: Text(
                                              'Discount',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                            ),
                                            child: Text(
                                              'Discount %',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                            ),
                                            child: Text(
                                              'Discount Amount',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                            ),
                                            child: Text(
                                              'Unit Cost',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                            ),
                                            child: Text(
                                              'Total Cost',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                        DataColumn(
                                          label: Padding(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 8.0,
                                            ),
                                            child: Text(
                                              'Actions',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                      rows: _getPaginatedItems().map((item) {
                                        int index = purchaseItems.indexOf(item);
                                        bool isIncomplete =
                                            item.productId == null ||
                                            item.quantity <= 0 ||
                                            item.purchasePrice <= 0;

                                        return DataRow(
                                          color:
                                              MaterialStateProperty.resolveWith<
                                                Color
                                              >((states) {
                                                if (isIncomplete) {
                                                  return Color(
                                                    0xFFFFF3CD,
                                                  ); // Light yellow for incomplete items
                                                }
                                                if (states.contains(
                                                  MaterialState.selected,
                                                )) {
                                                  return Color(
                                                    0xFF0D1845,
                                                  ).withOpacity(0.1);
                                                }
                                                return Colors.white;
                                              }),
                                          cells: [
                                            DataCell(
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: SizedBox(
                                                  width: 180,
                                                  child: InkWell(
                                                    onTap:
                                                        _selectedVendorId ==
                                                            null
                                                        ? null
                                                        : () =>
                                                              _showProductSearchDialog(
                                                                index,
                                                              ),
                                                    child: Container(
                                                      padding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 10,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: isIncomplete
                                                            ? Color(0xFFFFF3CD)
                                                            : Colors.white,
                                                        border: Border.all(
                                                          color: Colors
                                                              .grey
                                                              .shade300,
                                                        ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      child: Row(
                                                        children: [
                                                          Icon(
                                                            Icons.inventory_2,
                                                            size: 16,
                                                            color: Color(
                                                              0xFF0D1845,
                                                            ),
                                                          ),
                                                          SizedBox(width: 8),
                                                          Expanded(
                                                            child: Text(
                                                              item.productId !=
                                                                      null
                                                                  ? products
                                                                        .firstWhere(
                                                                          (p) =>
                                                                              p.id ==
                                                                              item.productId,
                                                                          orElse: () =>
                                                                              products.first,
                                                                        )
                                                                        .title
                                                                  : _selectedVendorId ==
                                                                        null
                                                                  ? 'Select vendor'
                                                                  : 'Select product',
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color:
                                                                    item.productId !=
                                                                        null
                                                                    ? Colors
                                                                          .black87
                                                                    : Colors
                                                                          .grey[600],
                                                              ),
                                                              overflow:
                                                                  TextOverflow
                                                                      .ellipsis,
                                                            ),
                                                          ),
                                                          Icon(
                                                            Icons
                                                                .arrow_drop_down,
                                                            size: 18,
                                                            color: Colors
                                                                .grey
                                                                .shade600,
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: SizedBox(
                                                  width: 70,
                                                  child: TextFormField(
                                                    initialValue: item.quantity
                                                        .toString(),
                                                    decoration: InputDecoration(
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 8,
                                                          ),
                                                      filled: true,
                                                      fillColor: isIncomplete
                                                          ? Color(0xFFFFF3CD)
                                                          : Colors.white,
                                                    ),
                                                    keyboardType:
                                                        TextInputType.number,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                    onChanged: (value) {
                                                      int qty =
                                                          int.tryParse(value) ??
                                                          0;
                                                      PurchaseItem updatedItem =
                                                          item.copyWith(
                                                            quantity: qty,
                                                          );
                                                      _updatePurchaseItem(
                                                        index,
                                                        updatedItem,
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: SizedBox(
                                                  width: 100,
                                                  child: TextFormField(
                                                    initialValue:
                                                        item.purchasePrice == 0
                                                        ? ''
                                                        : item.purchasePrice
                                                              .toString(),
                                                    decoration: InputDecoration(
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 8,
                                                          ),
                                                      filled: true,
                                                      fillColor: isIncomplete
                                                          ? Color(0xFFFFF3CD)
                                                          : Colors.white,
                                                      hintText: '0',
                                                    ),
                                                    keyboardType:
                                                        TextInputType.numberWithOptions(
                                                          decimal: true,
                                                        ),
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                    onChanged: (value) {
                                                      double price =
                                                          double.tryParse(
                                                            value,
                                                          ) ??
                                                          0;
                                                      PurchaseItem updatedItem =
                                                          item.copyWith(
                                                            purchasePrice:
                                                                price,
                                                          );
                                                      _updatePurchaseItem(
                                                        index,
                                                        updatedItem,
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: SizedBox(
                                                  width: 90,
                                                  child: TextFormField(
                                                    initialValue:
                                                        item.discount == 0
                                                        ? ''
                                                        : item.discount
                                                              .toString(),
                                                    decoration: InputDecoration(
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              6,
                                                            ),
                                                      ),
                                                      contentPadding:
                                                          EdgeInsets.symmetric(
                                                            horizontal: 12,
                                                            vertical: 8,
                                                          ),
                                                      filled: true,
                                                      fillColor: isIncomplete
                                                          ? Color(0xFFFFF3CD)
                                                          : Colors.white,
                                                      prefixText: 'Rs. ',
                                                      hintText: '0',
                                                    ),
                                                    keyboardType:
                                                        TextInputType.numberWithOptions(
                                                          decimal: true,
                                                        ),
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                    onChanged: (value) {
                                                      double discount =
                                                          double.tryParse(
                                                            value,
                                                          ) ??
                                                          0;
                                                      PurchaseItem updatedItem =
                                                          item.copyWith(
                                                            discount: discount,
                                                          );
                                                      _updatePurchaseItem(
                                                        index,
                                                        updatedItem,
                                                      );
                                                    },
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: Container(
                                                  width: 70,
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    '${(item.purchasePrice > 0 ? (item.discount / item.purchasePrice * 100) : 0).toStringAsFixed(1)}%',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Color(0xFF6C757D),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: Container(
                                                  width: 90,
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    'Rs. ${(item.discount * item.quantity).toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Color(0xFFDC3545),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: Container(
                                                  width: 90,
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    'Rs. ${item.unitCost.toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Color(0xFF28A745),
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: Container(
                                                  width: 100,
                                                  alignment: Alignment.center,
                                                  child: Text(
                                                    'Rs. ${(item.unitCost * item.quantity).toStringAsFixed(2)}',
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Color(0xFF343A40),
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Padding(
                                                padding: const EdgeInsets.all(
                                                  8.0,
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    if (isIncomplete)
                                                      Container(
                                                        padding:
                                                            EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 4,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Color(
                                                            0xFF856404,
                                                          ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                4,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          'Incomplete',
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ),
                                                    SizedBox(width: 8),
                                                    IconButton(
                                                      icon: Icon(
                                                        Icons.delete,
                                                        color: Color(
                                                          0xFFDC3545,
                                                        ),
                                                        size: 20,
                                                      ),
                                                      onPressed: () =>
                                                          _removePurchaseItem(
                                                            index,
                                                          ),
                                                      tooltip: 'Remove Product',
                                                      style:
                                                          IconButton.styleFrom(
                                                            backgroundColor:
                                                                Color(
                                                                  0xFFF8F9FA,
                                                                ),
                                                            padding:
                                                                EdgeInsets.all(
                                                                  8,
                                                                ),
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        );
                                      }).toList(),
                                    ),
                                  ),

                                  // Pagination
                                  if (purchaseItems.length > 10) ...[
                                    Container(
                                      padding: const EdgeInsets.all(16),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          IconButton(
                                            icon: Icon(Icons.chevron_left),
                                            onPressed: _currentPage > 0
                                                ? () => setState(
                                                    () => _currentPage--,
                                                  )
                                                : null,
                                          ),
                                          Text(
                                            'Page ${_currentPage + 1} of ${_getTotalPages()}',
                                            style: TextStyle(
                                              color: Color(0xFF6C757D),
                                            ),
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.chevron_right),
                                            onPressed:
                                                _currentPage <
                                                    _getTotalPages() - 1
                                                ? () => setState(
                                                    () => _currentPage++,
                                                  )
                                                : null,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],

                          // Invoice Summary
                          if (purchaseItems.isNotEmpty &&
                              _selectedVendorId != null) ...[
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Order Details (Left Side)
                                Expanded(
                                  flex: 1,
                                  child: Container(
                                    padding: const EdgeInsets.all(20),
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Header
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(8),
                                              decoration: BoxDecoration(
                                                color: Color(
                                                  0xFF0D1845,
                                                ).withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              child: const Icon(
                                                Icons.settings,
                                                color: Color(0xFF0D1845),
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            Text(
                                              'Order Details',
                                              style: TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w600,
                                                color: Color(0xFF343A40),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 20),

                                        // Discount
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 4,
                                                bottom: 4,
                                              ),
                                              child: Text(
                                                'Discount %',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            TextFormField(
                                              controller:
                                                  _orderDiscountController,
                                              decoration: InputDecoration(
                                                hintText: '0',
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                              ),
                                              keyboardType:
                                                  TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Tax
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 4,
                                                bottom: 4,
                                              ),
                                              child: Text(
                                                'Tax %',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            TextFormField(
                                              controller: _orderTaxController,
                                              decoration: InputDecoration(
                                                hintText: '0',
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                              ),
                                              keyboardType:
                                                  TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Shipping
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 4,
                                                bottom: 4,
                                              ),
                                              child: Text(
                                                'Shipping',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            TextFormField(
                                              controller:
                                                  _shippingPriceController,
                                              decoration: InputDecoration(
                                                hintText: '0.00',
                                                prefix: Text(
                                                  'Rs. ',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                              ),
                                              keyboardType:
                                                  TextInputType.numberWithOptions(
                                                    decimal: true,
                                                  ),
                                              style: TextStyle(fontSize: 12),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 12),

                                        // Notes
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Padding(
                                              padding: const EdgeInsets.only(
                                                left: 4,
                                                bottom: 4,
                                              ),
                                              child: Text(
                                                'Notes',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            TextFormField(
                                              controller: _notesController,
                                              decoration: InputDecoration(
                                                hintText: 'Add notes',
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                contentPadding:
                                                    EdgeInsets.symmetric(
                                                      horizontal: 10,
                                                      vertical: 8,
                                                    ),
                                                hintStyle: TextStyle(
                                                  fontSize: 11,
                                                ),
                                              ),
                                              style: TextStyle(fontSize: 12),
                                              maxLines: 2,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Invoice Summary (Right Side)
                                Expanded(
                                  flex: 1,
                                  child: _buildInvoiceSummary(),
                                ),
                              ],
                            ),
                            const SizedBox(height: 32),
                          ],

                          // Submit Button
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: isSubmitting ? null : _submitForm,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color(0xFF28A745),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              child: isSubmitting
                                  ? SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    )
                                  : Text('Save Changes'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: Color(0xFF0D1845), size: 20),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: Color(0xFF343A40),
          ),
        ),
      ],
    );
  }

  Widget _buildInvoiceSummary() {
    double subtotal = _calculateSubtotal();
    double orderDiscountPercent =
        double.tryParse(_orderDiscountController.text) ?? 0;
    double orderTaxPercent = double.tryParse(_orderTaxController.text) ?? 0;
    double shippingPrice = double.tryParse(_shippingPriceController.text) ?? 0;

    double orderDiscountAmount = subtotal * (orderDiscountPercent / 100);
    double totalAfterDiscount = subtotal - orderDiscountAmount;
    double orderTaxAmount = totalAfterDiscount * (orderTaxPercent / 100);
    double grandTotal = _calculateGrandTotal();

    return Container(
      padding: const EdgeInsets.all(20),
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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Color(0xFF0D1845).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.receipt_long,
                  color: Color(0xFF0D1845),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Purchase Invoice Summary',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF343A40),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Summary Items
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Color(0xFFF8F9FA),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                // Subtotal
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Subtotal (${purchaseItems.length} items)',
                      style: TextStyle(fontSize: 14, color: Color(0xFF6C757D)),
                    ),
                    Text(
                      'Rs. ${subtotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF343A40),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Order Discount
                if (orderDiscountPercent > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order Discount (${orderDiscountPercent.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFFDC3545),
                        ),
                      ),
                      Text(
                        '- Rs. ${orderDiscountAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFFDC3545),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Order Tax
                if (orderTaxPercent > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Order Tax (${orderTaxPercent.toStringAsFixed(1)}%)',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF28A745),
                        ),
                      ),
                      Text(
                        '+ Rs. ${orderTaxAmount.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF28A745),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],

                // Shipping
                if (shippingPrice > 0) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Shipping',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF17A2B8),
                        ),
                      ),
                      Text(
                        '+ Rs. ${shippingPrice.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF17A2B8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                ] else ...[
                  const SizedBox(height: 4),
                ],

                // Divider
                Divider(color: Color(0xFFE9ECEF), thickness: 1),

                // Grand Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Grand Total',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF343A40),
                      ),
                    ),
                    Text(
                      'Rs. ${grandTotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D1845),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PurchaseItem {
  int? productId;
  int quantity;
  double purchasePrice;
  double discount;
  double taxPercentage;
  double pendingPayment;
  String description;

  PurchaseItem({
    this.productId,
    this.quantity = 1,
    this.purchasePrice = 0,
    this.discount = 0,
    this.taxPercentage = 0,
    this.pendingPayment = 0,
    this.description = '',
  });

  double get taxAmount {
    double priceAfterDiscount = purchasePrice - discount;
    return priceAfterDiscount * (taxPercentage / 100);
  }

  double get unitCost {
    double priceAfterDiscount = purchasePrice - discount;
    return priceAfterDiscount + taxAmount;
  }

  PurchaseItem copyWith({
    int? productId,
    int? quantity,
    double? purchasePrice,
    double? discount,
    double? taxPercentage,
    double? pendingPayment,
    String? description,
  }) {
    return PurchaseItem(
      productId: productId ?? this.productId,
      quantity: quantity ?? this.quantity,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      discount: discount ?? this.discount,
      taxPercentage: taxPercentage ?? this.taxPercentage,
      pendingPayment: pendingPayment ?? this.pendingPayment,
      description: description ?? this.description,
    );
  }
}
