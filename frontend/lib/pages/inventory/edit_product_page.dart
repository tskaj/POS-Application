import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import '../../models/vendor.dart' as vendor;
import '../../models/category.dart';
import '../../models/sub_category.dart';
import '../../models/product.dart';
import '../../models/color.dart' as colorModel;
import '../../models/size.dart' as sizeModel;
import '../../models/material.dart' as materialModel;
import '../../models/season.dart' as seasonModel;
import 'package:barcode_widget/barcode_widget.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../utils/barcode_utils.dart';

class EditProductPage extends StatefulWidget {
  final Product product;
  final VoidCallback? onProductUpdated;

  const EditProductPage({
    super.key,
    required this.product,
    this.onProductUpdated,
  });

  @override
  State<EditProductPage> createState() => _EditProductPageState();
}

class _EditProductPageState extends State<EditProductPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _designCodeController;
  late final TextEditingController _salePriceController;
  late final TextEditingController _inStockQuantityController;
  late final TextEditingController _barcodeController;

  late String _selectedStatus;
  int? _selectedVendorId;
  int? _selectedCategoryId;
  int? _selectedSubCategoryId;

  // Multiple variant selections
  List<int> _selectedSizeIds = [];
  List<int> _selectedColorIds = [];
  List<int> _selectedMaterialIds = [];
  List<int> _selectedSeasonIds = [];

  // Variant data
  List<colorModel.Color> colors = [];
  List<sizeModel.Size> sizes = [];
  List<materialModel.Material> materials = [];
  List<seasonModel.Season> seasons = [];

  List<Category> categories = [];
  List<SubCategory> subCategories = [];
  List<vendor.Vendor> vendors = [];
  bool isSubmitting = false;

  @override
  void initState() {
    super.initState();

    // Initialize controllers with existing product data
    _titleController = TextEditingController(text: widget.product.title);
    _designCodeController = TextEditingController(
      text: widget.product.designCode,
    );
    _salePriceController = TextEditingController(
      text: widget.product.salePrice.toString(),
    );
    _inStockQuantityController = TextEditingController(
      text: widget.product.inStockQuantity.toString(),
    );
    _barcodeController = TextEditingController(text: widget.product.barcode);

    _selectedStatus = widget.product.status;
    _selectedVendorId = widget.product.vendor.id;

    _fetchCategories();
    _fetchVendors();
    _fetchSubCategoriesForProduct();
    _fetchCompleteProductDetails(); // Fetch complete product with variants
    // Add listener to design code controller to auto-generate barcode
    _designCodeController.addListener(_generateBarcodeFromDesignCode);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _designCodeController.dispose();
    _designCodeController.removeListener(_generateBarcodeFromDesignCode);
    _salePriceController.dispose();
    _inStockQuantityController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  // Helper method to create clean InputDecoration
  InputDecoration _buildCleanInputDecoration(
    String label, {
    bool isRequired = false,
    String? hint,
  }) {
    return InputDecoration(
      labelText: isRequired ? '$label *' : label,
      hintText: hint,
      labelStyle: TextStyle(
        color: isRequired ? Colors.black87 : Colors.grey[700],
        fontWeight: isRequired ? FontWeight.w500 : FontWeight.w400,
        fontSize: 14,
      ),
      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF0D1845), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade600, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      floatingLabelBehavior: FloatingLabelBehavior.always,
    );
  }

  // Helper method to create clean DropdownButtonFormField decoration
  InputDecoration _buildCleanDropdownDecoration(
    String label, {
    bool isRequired = false,
  }) {
    return InputDecoration(
      labelText: isRequired ? '$label *' : label,
      labelStyle: TextStyle(
        color: isRequired ? Colors.black87 : Colors.grey[700],
        fontWeight: isRequired ? FontWeight.w500 : FontWeight.w400,
        fontSize: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF0D1845), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade400),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.red.shade600, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      floatingLabelBehavior: FloatingLabelBehavior.always,
    );
  }

  void _showCategorySearchDialog() {
    // Initialize filtered categories and subcategories
    List<Category> filteredCategories = List.from(categories);
    List<SubCategory> filteredSubCategories = List.from(subCategories);
    final TextEditingController searchController = TextEditingController();
    bool showCategories = true; // Toggle between categories and subcategories

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void _filterItems(String query) {
              setState(() {
                if (query.isEmpty) {
                  filteredCategories = List.from(categories);
                  filteredSubCategories = List.from(subCategories);
                } else {
                  final searchQuery = query.toLowerCase();
                  filteredCategories = categories.where((category) {
                    final title = category.title.toLowerCase();
                    final code = category.categoryCode.toLowerCase();
                    return title.contains(searchQuery) ||
                        code.contains(searchQuery);
                  }).toList();
                  filteredSubCategories = subCategories.where((subCategory) {
                    final title = subCategory.title.toLowerCase();
                    final code = subCategory.subCategoryCode.toLowerCase();
                    return title.contains(searchQuery) ||
                        code.contains(searchQuery);
                  }).toList();
                }
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 600,
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header with toggle buttons
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1845).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.category,
                            color: Color(0xFF0D1845),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            showCategories
                                ? 'Select Category'
                                : 'Select Sub Category',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Toggle buttons for Category/Subcategory
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: showCategories
                                  ? const Color(0xFF0D1845)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextButton(
                              onPressed: () {
                                setState(() {
                                  showCategories = true;
                                  searchController.clear();
                                  _filterItems('');
                                });
                              },
                              style: TextButton.styleFrom(
                                foregroundColor: showCategories
                                    ? Colors.white
                                    : Colors.grey.shade700,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Categories'),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: !showCategories
                                  ? const Color(0xFF0D1845)
                                  : Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextButton(
                              onPressed: _selectedCategoryId != null
                                  ? () {
                                      setState(() {
                                        showCategories = false;
                                        searchController.clear();
                                        _filterItems('');
                                      });
                                    }
                                  : null,
                              style: TextButton.styleFrom(
                                foregroundColor: !showCategories
                                    ? Colors.white
                                    : Colors.grey.shade500,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                              ),
                              child: const Text('Sub Categories'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Search Field
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: showCategories
                              ? 'Search by category name or code...'
                              : 'Search by sub category name or code...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF0D1845),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                        onChanged: _filterItems,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Items List
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 300),
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
                        child: showCategories
                            ? (filteredCategories.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(32),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.search_off,
                                              size: 48,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No categories found',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.copyWith(
                                                    color: Colors.grey.shade600,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: filteredCategories.length,
                                      itemBuilder: (context, index) {
                                        final category =
                                            filteredCategories[index];
                                        final isSelected =
                                            category.id == _selectedCategoryId;

                                        return InkWell(
                                          onTap: () {
                                            setState(() {
                                              this.setState(() {
                                                _selectedCategoryId =
                                                    category.id;
                                                _selectedSubCategoryId = null;
                                              });
                                              _fetchSubCategories(category.id);
                                            });
                                            // Don't close dialog, let user select subcategory
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(
                                                      0xFF0D1845,
                                                    ).withOpacity(0.1)
                                                  : Colors.transparent,
                                              border:
                                                  index <
                                                      filteredCategories
                                                              .length -
                                                          1
                                                  ? Border(
                                                      bottom: BorderSide(
                                                        color: Colors
                                                            .grey
                                                            .shade100,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        category.title,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: isSelected
                                                                  ? const Color(
                                                                      0xFF0D1845,
                                                                    )
                                                                  : Colors
                                                                        .black87,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Code: ${category.categoryCode}',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: Colors
                                                                  .grey
                                                                  .shade600,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (isSelected)
                                                  const Icon(
                                                    Icons.check_circle,
                                                    color: Color(0xFF0D1845),
                                                    size: 20,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ))
                            : (filteredSubCategories.isEmpty
                                  ? Center(
                                      child: Padding(
                                        padding: const EdgeInsets.all(32),
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.search_off,
                                              size: 48,
                                              color: Colors.grey.shade400,
                                            ),
                                            const SizedBox(height: 16),
                                            Text(
                                              'No sub categories found',
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyLarge
                                                  ?.copyWith(
                                                    color: Colors.grey.shade600,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: filteredSubCategories.length,
                                      itemBuilder: (context, index) {
                                        final subCategory =
                                            filteredSubCategories[index];
                                        final isSelected =
                                            subCategory.id ==
                                            _selectedSubCategoryId;

                                        return InkWell(
                                          onTap: () {
                                            setState(() {
                                              this.setState(() {
                                                _selectedSubCategoryId =
                                                    subCategory.id;
                                              });
                                            });
                                            Navigator.of(context).pop();
                                          },
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 12,
                                            ),
                                            decoration: BoxDecoration(
                                              color: isSelected
                                                  ? const Color(
                                                      0xFF0D1845,
                                                    ).withOpacity(0.1)
                                                  : Colors.transparent,
                                              border:
                                                  index <
                                                      filteredSubCategories
                                                              .length -
                                                          1
                                                  ? Border(
                                                      bottom: BorderSide(
                                                        color: Colors
                                                            .grey
                                                            .shade100,
                                                      ),
                                                    )
                                                  : null,
                                            ),
                                            child: Row(
                                              children: [
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        subCategory.title,
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodyMedium
                                                            ?.copyWith(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                              color: isSelected
                                                                  ? const Color(
                                                                      0xFF0D1845,
                                                                    )
                                                                  : Colors
                                                                        .black87,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        'Code: ${subCategory.subCategoryCode}',
                                                        style: Theme.of(context)
                                                            .textTheme
                                                            .bodySmall
                                                            ?.copyWith(
                                                              color: Colors
                                                                  .grey
                                                                  .shade600,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                if (isSelected)
                                                  const Icon(
                                                    Icons.check_circle,
                                                    color: Color(0xFF0D1845),
                                                    size: 20,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    )),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Row(
                      children: [
                        // Select Button (only show when category is selected and we're on subcategories)
                        if (!showCategories && _selectedCategoryId != null)
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    const Color(0xFF28A745),
                                    const Color(0xFF20B545),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(
                                      0xFF28A745,
                                    ).withOpacity(0.4),
                                    blurRadius: 8,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                ),
                                child: const Text('Done'),
                              ),
                            ),
                          )
                        else
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.grey.shade300,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: ElevatedButton(
                                onPressed: () => Navigator.of(context).pop(),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  foregroundColor: Colors.grey.shade700,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 0,
                                  shadowColor: Colors.transparent,
                                ),
                                child: const Text('Close'),
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
      },
    );
  }

  void _showBarcodeDialog() {
    if (_barcodeController.text.isEmpty) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          backgroundColor: Colors.white,
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 400, maxHeight: 500),
            padding: const EdgeInsets.all(24),
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
                      'Product Barcode',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Barcode Display
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      BarcodeWidget(
                        // show numeric EAN-13 barcode (derived from barcode text)
                        barcode: Barcode.ean13(),
                        data: getNumericBarcodeFromString(
                          _barcodeController.text,
                        ),
                        width: double.infinity,
                        height: 80,
                        drawText: true,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _barcodeController.text,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                          color: Colors.black87,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Close'),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              const Color(0xFF28A745),
                              const Color(0xFF20B545),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF28A745).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: TextButton(
                          onPressed: () async {
                            final doc = pw.Document();

                            doc.addPage(
                              pw.Page(
                                pageFormat: PdfPageFormat.a4,
                                build: (pw.Context context) {
                                  return pw.Center(
                                    child: pw.Column(
                                      mainAxisAlignment:
                                          pw.MainAxisAlignment.center,
                                      children: [
                                        pw.Text(
                                          'Product Barcode',
                                          style: pw.TextStyle(
                                            fontSize: 24,
                                            fontWeight: pw.FontWeight.bold,
                                          ),
                                        ),
                                        pw.SizedBox(height: 20),
                                        pw.BarcodeWidget(
                                          // print numeric EAN-13 barcode
                                          barcode: pw.Barcode.ean13(),
                                          data: getNumericBarcodeFromString(
                                            _barcodeController.text,
                                          ),
                                          width: 300,
                                          height: 100,
                                        ),
                                        pw.SizedBox(height: 20),
                                        pw.Text(
                                          _barcodeController.text,
                                          style: pw.TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            );

                            await Printing.layoutPdf(
                              onLayout: (PdfPageFormat format) async =>
                                  doc.save(),
                            );
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Print'),
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

  void _generateBarcodeFromDesignCode() {
    final designCode = _designCodeController.text.trim();
    if (designCode.isNotEmpty) {
      // Generate barcode by converting design code to a numerical representation
      // Use a simple hash-like approach to create a consistent numerical barcode
      int barcodeValue = 0;
      for (int i = 0; i < designCode.length; i++) {
        barcodeValue = barcodeValue * 31 + designCode.codeUnitAt(i);
      }
      // Ensure it's positive and within reasonable barcode length
      barcodeValue = barcodeValue.abs() % 999999999;
      // Pad with zeros to ensure consistent length
      final barcodeString = barcodeValue.toString().padLeft(9, '0');
      _barcodeController.text = barcodeString;
    } else {
      _barcodeController.text = '';
    }
  }

  void _generateDesignCode() {
    final randomCode =
        'DC${DateTime.now().millisecondsSinceEpoch.toString().substring(5, 10)}';
    _designCodeController.text = randomCode;
    _generateBarcodeFromDesignCode();
  }

  Future<void> _fetchVendors() async {
    try {
      final vendorResponse = await InventoryService.getVendors();
      setState(() {
        vendors = vendorResponse.data;
        // Only set selected vendor if it exists in the fetched list
        if (_selectedVendorId != null &&
            !vendors.any((v) => v.id == _selectedVendorId)) {
          _selectedVendorId = null; // Reset if vendor no longer exists
        }
      });
    } catch (e) {
      setState(() {
        vendors = [];
        _selectedVendorId = null; // Reset on error
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load vendors: $e'),
            backgroundColor: Color(0xFFDC3545),
          ),
        );
      }
    }
  }

  Future<void> _fetchCategories() async {
    try {
      final categoryResponse = await InventoryService.getCategories();
      setState(() {
        categories = categoryResponse.data;
      });
    } catch (e) {
      setState(() {
        categories = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load categories: $e'),
            backgroundColor: Color(0xFFDC3545),
          ),
        );
      }
    }
  }

  Future<void> _fetchSubCategoriesForProduct() async {
    try {
      final subCategoryResponse = await InventoryService.getSubCategories();
      setState(() {
        subCategories = subCategoryResponse.data;
        // Find the category for the current product's sub category
        final productSubCategory = subCategories.firstWhere(
          (sc) => sc.id == int.tryParse(widget.product.subCategoryId),
          orElse: () => subCategories.first,
        );
        _selectedCategoryId = productSubCategory.categoryId;
        _selectedSubCategoryId = int.tryParse(widget.product.subCategoryId);
      });
    } catch (e) {
      setState(() {
        subCategories = [];
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load sub categories: $e'),
            backgroundColor: Color(0xFFDC3545),
          ),
        );
      }
    }
  }

  Future<void> _fetchSubCategories(int categoryId) async {
    try {
      final subCategoryResponse = await InventoryService.getSubCategories();
      setState(() {
        // Filter sub categories by selected category
        subCategories = subCategoryResponse.data
            .where((subCategory) => subCategory.categoryId == categoryId)
            .toList();
        // Reset selected sub category when category changes
        _selectedSubCategoryId = null;
      });
    } catch (e) {
      setState(() {
        subCategories = [];
        _selectedSubCategoryId = null;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load sub categories: $e'),
            backgroundColor: Color(0xFFDC3545),
          ),
        );
      }
    }
  }

  Future<void> _fetchCompleteProductDetails() async {
    try {
      print(
        '🔍 Fetching complete product details for product ID: ${widget.product.id}',
      );

      // Fetch complete product details with variants
      final completeProduct = await InventoryService.getProduct(
        widget.product.id,
      );

      print('✅ Received complete product data');
      print('Colors: ${completeProduct.colors}');
      print('Sizes: ${completeProduct.sizes}');
      print('Materials: ${completeProduct.materials}');
      print('Seasons: ${completeProduct.seasons}');

      // Fetch variants list
      await _fetchVariants();

      // Load product variants using the complete product data
      _loadProductVariantsFromProduct(completeProduct);
    } catch (e) {
      print('❌ Error fetching complete product details: $e');
      // Fallback to fetching variants without pre-selection
      await _fetchVariants();
    }
  }

  void _loadProductVariantsFromProduct(Product product) {
    print('🔍 Loading product variants from complete product...');
    print('Colors from product: ${product.colors}');
    print('Sizes from product: ${product.sizes}');
    print('Materials from product: ${product.materials}');
    print('Seasons from product: ${product.seasons}');

    // Parse colors
    if (product.colors != null && product.colors!.isNotEmpty) {
      final colorNames = product.colors!
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      print('Parsed color names: $colorNames');
      print('Available colors: ${colors.map((c) => c.title).toList()}');

      for (var colorName in colorNames) {
        try {
          final matchedColor = colors.firstWhere(
            (c) => c.title.toLowerCase() == colorName.toLowerCase(),
            orElse: () {
              // Try matching by ID if name doesn't work
              final colorId = int.tryParse(colorName);
              if (colorId != null) {
                return colors.firstWhere(
                  (c) => c.id == colorId,
                  orElse: () => throw Exception('Not found'),
                );
              }
              throw Exception('Not found');
            },
          );
          if (!_selectedColorIds.contains(matchedColor.id)) {
            _selectedColorIds.add(matchedColor.id);
            print(
              '✅ Added color: ${matchedColor.title} (ID: ${matchedColor.id})',
            );
          }
        } catch (e) {
          print('❌ Could not match color: $colorName');
        }
      }
    }

    // Parse sizes
    if (product.sizes != null && product.sizes!.isNotEmpty) {
      final sizeNames = product.sizes!
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      print('Parsed size names: $sizeNames');

      for (var sizeName in sizeNames) {
        try {
          final matchedSize = sizes.firstWhere(
            (s) => s.title.toLowerCase() == sizeName.toLowerCase(),
            orElse: () {
              final sizeId = int.tryParse(sizeName);
              if (sizeId != null) {
                return sizes.firstWhere(
                  (s) => s.id == sizeId,
                  orElse: () => throw Exception('Not found'),
                );
              }
              throw Exception('Not found');
            },
          );
          if (!_selectedSizeIds.contains(matchedSize.id)) {
            _selectedSizeIds.add(matchedSize.id);
            print('✅ Added size: ${matchedSize.title} (ID: ${matchedSize.id})');
          }
        } catch (e) {
          print('❌ Could not match size: $sizeName');
        }
      }
    }

    // Parse materials
    if (product.materials != null && product.materials!.isNotEmpty) {
      final materialNames = product.materials!
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      print('Parsed material names: $materialNames');

      for (var materialName in materialNames) {
        try {
          final matchedMaterial = materials.firstWhere(
            (m) => m.title.toLowerCase() == materialName.toLowerCase(),
            orElse: () {
              final materialId = int.tryParse(materialName);
              if (materialId != null) {
                return materials.firstWhere(
                  (m) => m.id == materialId,
                  orElse: () => throw Exception('Not found'),
                );
              }
              throw Exception('Not found');
            },
          );
          if (!_selectedMaterialIds.contains(matchedMaterial.id)) {
            _selectedMaterialIds.add(matchedMaterial.id);
            print(
              '✅ Added material: ${matchedMaterial.title} (ID: ${matchedMaterial.id})',
            );
          }
        } catch (e) {
          print('❌ Could not match material: $materialName');
        }
      }
    }

    // Parse seasons
    if (product.seasons != null && product.seasons!.isNotEmpty) {
      final seasonNames = product.seasons!
          .split(',')
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
      print('Parsed season names: $seasonNames');

      for (var seasonName in seasonNames) {
        try {
          final matchedSeason = seasons.firstWhere(
            (s) => s.title.toLowerCase() == seasonName.toLowerCase(),
            orElse: () {
              final seasonId = int.tryParse(seasonName);
              if (seasonId != null) {
                return seasons.firstWhere(
                  (s) => s.id == seasonId,
                  orElse: () => throw Exception('Not found'),
                );
              }
              throw Exception('Not found');
            },
          );
          if (!_selectedSeasonIds.contains(matchedSeason.id)) {
            _selectedSeasonIds.add(matchedSeason.id);
            print(
              '✅ Added season: ${matchedSeason.title} (ID: ${matchedSeason.id})',
            );
          }
        } catch (e) {
          print('❌ Could not match season: $seasonName');
        }
      }
    }

    print('Final selected IDs:');
    print('Colors: $_selectedColorIds');
    print('Sizes: $_selectedSizeIds');
    print('Materials: $_selectedMaterialIds');
    print('Seasons: $_selectedSeasonIds');

    // Trigger UI update
    setState(() {});
  }

  Future<void> _fetchVariants() async {
    try {
      // Fetch all variants in parallel with high limit to get all items
      final results = await Future.wait([
        InventoryService.getColors(limit: 1000),
        InventoryService.getSizes(limit: 1000),
        InventoryService.getMaterials(limit: 1000),
        InventoryService.getSeasons(limit: 1000),
      ]);

      setState(() {
        colors = (results[0] as colorModel.ColorResponse).data;
        sizes = (results[1] as sizeModel.SizeResponse).data;
        materials = (results[2] as materialModel.MaterialResponse).data;
        seasons = (results[3] as seasonModel.SeasonResponse).data;
      });

      print(
        '✅ Fetched ${colors.length} colors, ${sizes.length} sizes, ${materials.length} materials, ${seasons.length} seasons',
      );
    } catch (e) {
      print('Error fetching variants: $e');
      // Set empty lists on error
      setState(() {
        colors = [];
        sizes = [];
        materials = [];
        seasons = [];
      });
    }
  }

  void _showSizeSearchDialog() {
    List<sizeModel.Size> filteredSizes = List.from(sizes);
    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void _filterSizes(String query) {
              setState(() {
                if (query.isEmpty) {
                  filteredSizes = List.from(sizes);
                } else {
                  final searchQuery = query.toLowerCase();
                  filteredSizes = sizes.where((size) {
                    final title = size.title.toLowerCase();
                    return title.contains(searchQuery);
                  }).toList();
                }
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 600,
                ),
                padding: const EdgeInsets.all(24),
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
                            Icons.straighten,
                            color: Color(0xFF0D1845),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Select Sizes',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Search Field
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by size name...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF0D1845),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                        onChanged: _filterSizes,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Size List
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 300),
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
                        child: filteredSizes.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No sizes found',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: Colors.grey.shade600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredSizes.length,
                                itemBuilder: (context, index) {
                                  final size = filteredSizes[index];
                                  final isSelected = _selectedSizeIds.contains(
                                    size.id,
                                  );

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        this.setState(() {
                                          if (isSelected) {
                                            _selectedSizeIds.remove(size.id);
                                          } else {
                                            _selectedSizeIds.add(size.id);
                                          }
                                        });
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(
                                                0xFF0D1845,
                                              ).withOpacity(0.1)
                                            : Colors.transparent,
                                        border: index < filteredSizes.length - 1
                                            ? Border(
                                                bottom: BorderSide(
                                                  color: Colors.grey.shade100,
                                                ),
                                              )
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              size.title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                    color: isSelected
                                                        ? const Color(
                                                            0xFF0D1845,
                                                          )
                                                        : Colors.black87,
                                                  ),
                                            ),
                                          ),
                                          if (isSelected)
                                            const Icon(
                                              Icons.check_circle,
                                              color: Color(0xFF0D1845),
                                              size: 20,
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Close Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF28A745),
                            const Color(0xFF20B545),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF28A745).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: const Text('Close'),
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

  void _showColorSearchDialog() {
    List<colorModel.Color> filteredColors = List.from(colors);
    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void _filterColors(String query) {
              setState(() {
                if (query.isEmpty) {
                  filteredColors = List.from(colors);
                } else {
                  final searchQuery = query.toLowerCase();
                  filteredColors = colors.where((color) {
                    final title = color.title.toLowerCase();
                    return title.contains(searchQuery);
                  }).toList();
                }
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 600,
                ),
                padding: const EdgeInsets.all(24),
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
                            Icons.color_lens,
                            color: Color(0xFF0D1845),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Select Colors',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Search Field
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by color name...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF0D1845),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                        onChanged: _filterColors,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Color List
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 300),
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
                        child: filteredColors.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No colors found',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: Colors.grey.shade600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredColors.length,
                                itemBuilder: (context, index) {
                                  final color = filteredColors[index];
                                  final isSelected = _selectedColorIds.contains(
                                    color.id,
                                  );

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        this.setState(() {
                                          if (isSelected) {
                                            _selectedColorIds.remove(color.id);
                                          } else {
                                            _selectedColorIds.add(color.id);
                                          }
                                        });
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(
                                                0xFF0D1845,
                                              ).withOpacity(0.1)
                                            : Colors.transparent,
                                        border:
                                            index < filteredColors.length - 1
                                            ? Border(
                                                bottom: BorderSide(
                                                  color: Colors.grey.shade100,
                                                ),
                                              )
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              color.title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                    color: isSelected
                                                        ? const Color(
                                                            0xFF0D1845,
                                                          )
                                                        : Colors.black87,
                                                  ),
                                            ),
                                          ),
                                          if (isSelected)
                                            const Icon(
                                              Icons.check_circle,
                                              color: Color(0xFF0D1845),
                                              size: 20,
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Close Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF28A745),
                            const Color(0xFF20B545),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF28A745).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: const Text('Close'),
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

  void _showMaterialSearchDialog() {
    List<materialModel.Material> filteredMaterials = List.from(materials);
    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void _filterMaterials(String query) {
              setState(() {
                if (query.isEmpty) {
                  filteredMaterials = List.from(materials);
                } else {
                  final searchQuery = query.toLowerCase();
                  filteredMaterials = materials.where((material) {
                    final title = material.title.toLowerCase();
                    return title.contains(searchQuery);
                  }).toList();
                }
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 600,
                ),
                padding: const EdgeInsets.all(24),
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
                            Icons.texture,
                            color: Color(0xFF0D1845),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Select Materials',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Search Field
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by material name...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF0D1845),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                        onChanged: _filterMaterials,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Material List
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 300),
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
                        child: filteredMaterials.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No materials found',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: Colors.grey.shade600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredMaterials.length,
                                itemBuilder: (context, index) {
                                  final material = filteredMaterials[index];
                                  final isSelected = _selectedMaterialIds
                                      .contains(material.id);

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        this.setState(() {
                                          if (isSelected) {
                                            _selectedMaterialIds.remove(
                                              material.id,
                                            );
                                          } else {
                                            _selectedMaterialIds.add(
                                              material.id,
                                            );
                                          }
                                        });
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(
                                                0xFF0D1845,
                                              ).withOpacity(0.1)
                                            : Colors.transparent,
                                        border:
                                            index < filteredMaterials.length - 1
                                            ? Border(
                                                bottom: BorderSide(
                                                  color: Colors.grey.shade100,
                                                ),
                                              )
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              material.title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                    color: isSelected
                                                        ? const Color(
                                                            0xFF0D1845,
                                                          )
                                                        : Colors.black87,
                                                  ),
                                            ),
                                          ),
                                          if (isSelected)
                                            const Icon(
                                              Icons.check_circle,
                                              color: Color(0xFF0D1845),
                                              size: 20,
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Close Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF28A745),
                            const Color(0xFF20B545),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF28A745).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: const Text('Close'),
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

  void _showSeasonSearchDialog() {
    List<seasonModel.Season> filteredSeasons = List.from(seasons);
    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void _filterSeasons(String query) {
              setState(() {
                if (query.isEmpty) {
                  filteredSeasons = List.from(seasons);
                } else {
                  final searchQuery = query.toLowerCase();
                  filteredSeasons = seasons.where((season) {
                    final title = season.title.toLowerCase();
                    return title.contains(searchQuery);
                  }).toList();
                }
              });
            }

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              backgroundColor: Colors.white,
              child: Container(
                width: MediaQuery.of(context).size.width * 0.9,
                constraints: const BoxConstraints(
                  maxWidth: 500,
                  maxHeight: 600,
                ),
                padding: const EdgeInsets.all(24),
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
                            Icons.wb_sunny,
                            color: Color(0xFF0D1845),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Select Seasons',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // Search Field
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by season name...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF0D1845),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                        onChanged: _filterSeasons,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Season List
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(maxHeight: 300),
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
                        child: filteredSeasons.isEmpty
                            ? Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(32),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        size: 48,
                                        color: Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No seasons found',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodyLarge
                                            ?.copyWith(
                                              color: Colors.grey.shade600,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                itemCount: filteredSeasons.length,
                                itemBuilder: (context, index) {
                                  final season = filteredSeasons[index];
                                  final isSelected = _selectedSeasonIds
                                      .contains(season.id);

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        this.setState(() {
                                          if (isSelected) {
                                            _selectedSeasonIds.remove(
                                              season.id,
                                            );
                                          } else {
                                            _selectedSeasonIds.add(season.id);
                                          }
                                        });
                                      });
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? const Color(
                                                0xFF0D1845,
                                              ).withOpacity(0.1)
                                            : Colors.transparent,
                                        border:
                                            index < filteredSeasons.length - 1
                                            ? Border(
                                                bottom: BorderSide(
                                                  color: Colors.grey.shade100,
                                                ),
                                              )
                                            : null,
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              season.title,
                                              style: Theme.of(context)
                                                  .textTheme
                                                  .bodyMedium
                                                  ?.copyWith(
                                                    fontWeight: FontWeight.w500,
                                                    color: isSelected
                                                        ? const Color(
                                                            0xFF0D1845,
                                                          )
                                                        : Colors.black87,
                                                  ),
                                            ),
                                          ),
                                          if (isSelected)
                                            const Icon(
                                              Icons.check_circle,
                                              color: Color(0xFF0D1845),
                                              size: 20,
                                            ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Close Button
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF28A745),
                            const Color(0xFF20B545),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF28A745).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 0,
                          shadowColor: Colors.transparent,
                        ),
                        child: const Text('Close'),
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => isSubmitting = true);

    try {
      final productData = {
        'title': _titleController.text,
        'design_code': _designCodeController.text,
        'sub_category_id': _selectedSubCategoryId,
        'sale_price': double.parse(_salePriceController.text),
        'opening_stock_quantity': int.parse(_inStockQuantityController.text),
        'stock_in_quantity': 0, // Required by API
        'stock_out_quantity': 0, // Required by API
        'in_stock_quantity': int.parse(
          _inStockQuantityController.text,
        ), // Required by API
        'vendor_id': _selectedVendorId,
        'user_id': 1,
        'barcode': _barcodeController.text,
        'status': _selectedStatus,
        'sizes': _selectedSizeIds,
        'colors': _selectedColorIds,
        'materials': _selectedMaterialIds,
        'seasons': _selectedSeasonIds,
      };

      await InventoryService.updateProduct(widget.product.id, productData);

      // Call the callback to notify parent that product was updated
      widget.onProductUpdated?.call();

      if (mounted) {
        // Show success dialog with options
        await showDialog(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.check_circle, color: Color(0xFF28A745)),
                  SizedBox(width: 12),
                  Text('Product Updated Successfully!'),
                ],
              ),
              content: Text(
                'The product has been updated in your inventory. What would you like to do next?',
                style: TextStyle(color: Color(0xFF6C757D)),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    Navigator.of(context).pop(); // Go back to product list
                  },
                  child: Text(
                    'View Product List',
                    style: TextStyle(color: Color(0xFF0D1845)),
                  ),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop(); // Close dialog
                    // Stay on page to make more edits if needed
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF28A745),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Continue Editing'),
                ),
              ],
            );
          },
        );
      }
    } catch (e) {
      String errorMessage = 'Failed to update product';
      if (e.toString().contains('No query results for model')) {
        errorMessage = 'Product no longer exists. It may have been deleted.';
      } else if (e.toString().contains('sub_category_id')) {
        errorMessage =
            'Invalid sub category selection. Please select a valid sub category.';
      } else if (e.toString().contains('vendor_id')) {
        errorMessage =
            'Invalid vendor selection. Please select a valid vendor.';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Expanded(child: Text(errorMessage)),
              ],
            ),
            backgroundColor: Color(0xFFDC3545),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => isSubmitting = false);
      }
    }
  }

  Future<bool> _confirmLeave() async {
    if (_formKey.currentState?.validate() ?? false) {
      return true;
    }

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Discard Changes?'),
        content: const Text(
          'You have unsaved changes. Are you sure you want to leave?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Discard'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
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
                child: const Icon(Icons.edit, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Edit Product',
                style: theme.textTheme.titleLarge?.copyWith(
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
            tooltip: 'Back to Products',
          ),
        ),
      ),
      body: WillPopScope(
        onWillPop: () => _confirmLeave(),
        child: SafeArea(
          child: GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isWideScreen ? 32 : 20,
                vertical: 8,
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Product Information Section
                    _buildProductInformationSection(theme),

                    const SizedBox(height: 12),

                    // Pricing & Stocks Section
                    _buildPricingStocksSection(theme),

                    const SizedBox(height: 12),

                    // Variants Section (Custom Fields equivalent)
                    _buildVariantsSection(theme),

                    const SizedBox(height: 16),

                    // Submit Button
                    _buildSubmitSection(theme),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Product Information Section
  Widget _buildProductInformationSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1845).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.info,
                    color: Color(0xFF0D1845),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Product Information',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Product Name
            TextFormField(
              controller: _titleController,
              decoration: _buildCleanInputDecoration(
                'Product Name',
                isRequired: true,
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter product name';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),

            // Category and Barcode
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _showCategorySearchDialog,
                    child: InputDecorator(
                      decoration: _buildCleanDropdownDecoration(
                        'Category',
                        isRequired: true,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _selectedCategoryId != null
                                ? categories
                                      .firstWhere(
                                        (c) => c.id == _selectedCategoryId,
                                        orElse: () => Category(
                                          id: 0,
                                          title: '',
                                          status: '',
                                          createdAt: '',
                                          updatedAt: '',
                                        ),
                                      )
                                      .title
                                : 'Select Category',
                            style: TextStyle(
                              color: _selectedCategoryId != null
                                  ? Colors.black87
                                  : Colors.grey[600],
                            ),
                          ),
                          const Icon(Icons.search, color: Color(0xFF0D1845)),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _barcodeController,
                    decoration: _buildCleanInputDecoration(
                      'Barcode (Auto-generated)',
                      isRequired: true,
                      hint: 'Generated from design code',
                    ),
                    readOnly: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Barcode is required';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Design Code
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _designCodeController,
                    decoration: _buildCleanInputDecoration(
                      'Design Code',
                      isRequired: true,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter design code';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF0D1845),
                        const Color(0xFF0A1238),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    onPressed: _generateDesignCode,
                    icon: const Icon(
                      Icons.refresh,
                      color: Colors.white,
                      size: 20,
                    ),
                    tooltip: 'Auto Generate',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // QR Code Button
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [const Color(0xFF0D1845), const Color(0xFF0A1238)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: _showBarcodeDialog,
                  icon: const Icon(
                    Icons.qr_code_scanner,
                    color: Colors.white,
                    size: 20,
                  ),
                  tooltip: 'View QR Code',
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Sub Category
            InkWell(
              onTap: _selectedCategoryId != null
                  ? _showCategorySearchDialog
                  : null,
              child: InputDecorator(
                decoration: _buildCleanDropdownDecoration(
                  'Sub Category',
                  isRequired: true,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _selectedSubCategoryId != null
                          ? subCategories
                                .firstWhere(
                                  (sc) => sc.id == _selectedSubCategoryId,
                                  orElse: () => SubCategory(
                                    id: 0,
                                    title: '',
                                    categoryId: 0,
                                    status: '',
                                    createdAt: '',
                                    updatedAt: '',
                                  ),
                                )
                                .title
                          : 'Select Sub Category',
                      style: TextStyle(
                        color: _selectedSubCategoryId != null
                            ? Colors.black87
                            : Colors.grey[600],
                      ),
                    ),
                    Icon(
                      Icons.search,
                      color: _selectedCategoryId != null
                          ? const Color(0xFF0D1845)
                          : Colors.grey[400],
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

  // Pricing & Stocks Section
  Widget _buildPricingStocksSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1845).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.attach_money,
                    color: Color(0xFF0D1845),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Pricing & Stocks',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Sale Price and Opening Stock
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _salePriceController,
                    decoration: _buildCleanInputDecoration(
                      'Sale Price (PKR)',
                      isRequired: true,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter sale price';
                      }
                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: _inStockQuantityController,
                    decoration: _buildCleanInputDecoration(
                      'In Stock Quantity',
                      isRequired: true,
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter in stock quantity';
                      }
                      if (int.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Variants Section
  Widget _buildVariantsSection(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1845).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.palette_outlined,
                    color: Color(0xFF0D1845),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Variants & Attributes',
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(
              'Select product variants (optional)',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),

            // Row with 4 variant buttons
            Row(
              children: [
                // Size
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Size',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: InkWell(
                          onTap: _showSizeSearchDialog,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedSizeIds.isEmpty
                                        ? 'Select'
                                        : _selectedSizeIds.isNotEmpty &&
                                              sizes.isNotEmpty
                                        ? (() {
                                            try {
                                              final selectedSizes = sizes
                                                  .where(
                                                    (s) => _selectedSizeIds
                                                        .contains(s.id),
                                                  )
                                                  .toList();
                                              return selectedSizes.length <= 2
                                                  ? selectedSizes
                                                        .map((s) => s.title)
                                                        .join(', ')
                                                  : '${selectedSizes.length} selected';
                                            } catch (e) {
                                              return '${_selectedSizeIds.length} selected';
                                            }
                                          })()
                                        : '${_selectedSizeIds.length} selected',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _selectedSizeIds.isEmpty
                                          ? Colors.grey.shade600
                                          : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Color
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Color',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: InkWell(
                          onTap: _showColorSearchDialog,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedColorIds.isEmpty
                                        ? 'Select'
                                        : _selectedColorIds.isNotEmpty &&
                                              colors.isNotEmpty
                                        ? (() {
                                            try {
                                              final selectedColors = colors
                                                  .where(
                                                    (c) => _selectedColorIds
                                                        .contains(c.id),
                                                  )
                                                  .toList();
                                              return selectedColors.length <= 2
                                                  ? selectedColors
                                                        .map((c) => c.title)
                                                        .join(', ')
                                                  : '${selectedColors.length} selected';
                                            } catch (e) {
                                              return '${_selectedColorIds.length} selected';
                                            }
                                          })()
                                        : '${_selectedColorIds.length} selected',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _selectedColorIds.isEmpty
                                          ? Colors.grey.shade600
                                          : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Material
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Material',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: InkWell(
                          onTap: _showMaterialSearchDialog,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedMaterialIds.isEmpty
                                        ? 'Select'
                                        : _selectedMaterialIds.isNotEmpty &&
                                              materials.isNotEmpty
                                        ? (() {
                                            try {
                                              final selectedMaterials =
                                                  materials
                                                      .where(
                                                        (m) =>
                                                            _selectedMaterialIds
                                                                .contains(m.id),
                                                      )
                                                      .toList();
                                              return selectedMaterials.length <=
                                                      2
                                                  ? selectedMaterials
                                                        .map((m) => m.title)
                                                        .join(', ')
                                                  : '${selectedMaterials.length} selected';
                                            } catch (e) {
                                              return '${_selectedMaterialIds.length} selected';
                                            }
                                          })()
                                        : '${_selectedMaterialIds.length} selected',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _selectedMaterialIds.isEmpty
                                          ? Colors.grey.shade600
                                          : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Season
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Season',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: InkWell(
                          onTap: _showSeasonSearchDialog,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedSeasonIds.isEmpty
                                        ? 'Select'
                                        : _selectedSeasonIds.isNotEmpty &&
                                              seasons.isNotEmpty
                                        ? (() {
                                            try {
                                              final selectedSeasons = seasons
                                                  .where(
                                                    (s) => _selectedSeasonIds
                                                        .contains(s.id),
                                                  )
                                                  .toList();
                                              return selectedSeasons.length <= 2
                                                  ? selectedSeasons
                                                        .map((s) => s.title)
                                                        .join(', ')
                                                  : '${selectedSeasons.length} selected';
                                            } catch (e) {
                                              return '${_selectedSeasonIds.length} selected';
                                            }
                                          })()
                                        : '${_selectedSeasonIds.length} selected',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: _selectedSeasonIds.isEmpty
                                          ? Colors.grey.shade600
                                          : Colors.black87,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  size: 18,
                                  color: Colors.grey.shade600,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Submit Section
  Widget _buildSubmitSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SizedBox(
        width: double.infinity,
        child: ElevatedButton(
          onPressed: isSubmitting ? null : _submitForm,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF28A745),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            elevation: 4,
            shadowColor: const Color(0xFF28A745).withOpacity(0.4),
          ),
          child: isSubmitting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : const Text(
                  'Update Product',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
        ),
      ),
    );
  }
}
