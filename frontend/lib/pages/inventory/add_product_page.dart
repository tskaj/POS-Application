import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/inventory_service.dart';
import '../../models/vendor.dart' as vendor;
import '../../models/category.dart';
import '../../models/sub_category.dart';
import '../../models/color.dart' as colorModel;
import '../../models/size.dart' as sizeModel;
import '../../models/material.dart' as materialModel;
import '../../models/season.dart' as seasonModel;
import 'dart:io';
import 'dart:async';
import 'package:qr_flutter/qr_flutter.dart';
import 'dart:convert';
import 'package:barcode_widget/barcode_widget.dart';
// PDF generation and printing: use native print dialog via `printing` package
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../utils/unsaved_guard.dart';
import '../../utils/barcode_utils.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart' as pdf_pkg;
// Add-page dialogs used by selection popups
import 'add_vendor_page.dart';
import 'add_category_page.dart';
import 'add_sub_category_page.dart';

class AddProductPage extends StatefulWidget {
  final VoidCallback? onProductAdded;
  final bool showBackButton;

  const AddProductPage({
    super.key,
    this.onProductAdded,
    this.showBackButton = false,
  });

  @override
  State<AddProductPage> createState() => _AddProductPageState();
}

class _AddProductPageState extends State<AddProductPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _designCodeController = TextEditingController();
  final _salePriceController = TextEditingController();
  final _buyingPriceController = TextEditingController();
  final _openingStockQuantityController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _qrCodeController = TextEditingController();

  // Vendor search
  List<vendor.Vendor> _filteredVendors = [];

  // Focus nodes for smooth transitions
  final _titleFocusNode = FocusNode();
  final _designCodeFocusNode = FocusNode();
  final _salePriceFocusNode = FocusNode();
  final _stockFocusNode = FocusNode();

  String _selectedStatus = 'Active';
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

  // Existing data
  List<Category> categories = [];
  List<SubCategory> subCategories = [];
  List<vendor.Vendor> vendors = [];

  bool isSubmitting = false;
  String? _qrCodeData;
  String? _qrCodeImagePath;
  // Product name uniqueness check
  Timer? _nameDebounce;
  bool _isDuplicateName = false;

  // Validation error messages
  String? _titleError;
  String? _designCodeError;
  String? _salePriceError;

  // Predefined colors for color dialog
  final List<String> predefinedColors = [
    'Red',
    'Blue',
    'Green',
    'Yellow',
    'Black',
    'White',
    'Orange',
    'Purple',
    'Pink',
    'Brown',
    'Grey',
    'Navy',
    'Maroon',
  ];

  // Predefined materials for material dialog
  final List<String> predefinedMaterials = [
    'Cotton',
    'Silk',
    'Linen',
    'Wool',
    'Denim',
    'Polyester',
    'Fabric',
    'Khaddar',
    'Chiffon',
    'Georgette',
    'Velvet',
    'Satin',
    'Nylon',
    'Rayon',
    'Spandex',
    'Leather',
    'Synthetic',
    'Blended',
  ];

  // Predefined sizes for size dialog
  final List<String> predefinedSizes = [
    'XS',
    'Small',
    'Medium',
    'Large',
    'XL',
    'XXL',
  ];

  // Predefined seasons for season dialog
  final List<String> predefinedSeasons = [
    'Winter',
    'Summer',
    'Spring',
    'Fall',
    'Autumn',
    'Mid-Season',
    'All Seasons',
  ];

  // Animation controllers
  late AnimationController _submitAnimationController;
  late Animation<double> _submitAnimation;

  @override
  void initState() {
    super.initState();
    print('🏗️ AddProductPage initialized');

    // Initialize animation controllers
    _submitAnimationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _submitAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(
        parent: _submitAnimationController,
        curve: Curves.easeInOut,
      ),
    );

    _fetchCategories();
    _fetchVendors();
    _fetchVariants();

    // Register unsaved-changes guard so external navigation (for example
    // sidebar button handlers) can ask this page whether it's safe to
    // navigate away. Sidebar code should call
    // `UnsavedChangesGuard().maybeNavigate(context, () => Navigator...)`.
    UnsavedChangesGuard().register((ctx) => _confirmLeave());

    // Add listeners to generate barcode when product name, vendor, or design code changes
    _titleController.addListener(_generateBarcodeAndQrFromProductAndVendor);
    // Also watch title changes to validate uniqueness (debounced)
    _titleController.addListener(_onTitleChanged);
    _designCodeController.addListener(
      _generateBarcodeAndQrFromProductAndVendor,
    );

    // Add listeners to clear validation errors when fields become valid
    _titleController.addListener(_clearTitleErrorIfValid);
    _designCodeController.addListener(_clearDesignCodeErrorIfValid);
    _salePriceController.addListener(_clearSalePriceErrorIfValid);
  }

  @override
  void dispose() {
    // Dispose controllers and focus nodes
    _titleController.dispose();
    _designCodeController.dispose();
    _salePriceController.dispose();
    _buyingPriceController.dispose();
    _openingStockQuantityController.dispose();
    _barcodeController.dispose();
    _qrCodeController.dispose();

    _titleFocusNode.dispose();
    _designCodeFocusNode.dispose();
    _salePriceFocusNode.dispose();
    _stockFocusNode.dispose();

    _submitAnimationController.dispose();

    _titleController.removeListener(_generateBarcodeAndQrFromProductAndVendor);
    _titleController.removeListener(_onTitleChanged);
    _designCodeController.removeListener(
      _generateBarcodeAndQrFromProductAndVendor,
    );
    // Cancel any pending debounce timer
    _nameDebounce?.cancel();
    // Unregister the global unsaved-changes guard when the page is disposed
    UnsavedChangesGuard().unregister();
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

  // Product Information Section (combines basic info and categories)
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0D1845).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: Color(0xFF0D1845),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Product Information',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Form Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Card
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(12),
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
                      children: [
                        // Product Name
                        TextFormField(
                          controller: _titleController,
                          focusNode: _titleFocusNode,
                          decoration: _buildCleanInputDecoration(
                            'Product Name',
                            isRequired: true,
                          ).copyWith(errorText: _titleError),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Category
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: OutlinedButton(
                            onPressed: _showCategorySearchDialog,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              backgroundColor: Colors.white,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.centerLeft,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedCategoryId != null &&
                                            categories.isNotEmpty
                                        ? (() {
                                            try {
                                              final selectedCategory =
                                                  categories.firstWhere(
                                                    (c) =>
                                                        c.id ==
                                                        _selectedCategoryId,
                                                  );
                                              return '${selectedCategory.title} (${selectedCategory.categoryCode})';
                                            } catch (e) {
                                              return 'Select Category *';
                                            }
                                          })()
                                        : 'Select Category *',
                                    style: TextStyle(
                                      color: _selectedCategoryId != null
                                          ? Colors.black87
                                          : Colors.grey[700],
                                      fontSize: 14,
                                      fontWeight: _selectedCategoryId != null
                                          ? FontWeight.w400
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Barcode Button
                        _barcodeController.text.isNotEmpty
                            ? Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF0D1845).withOpacity(0.1),
                                      const Color(0xFF0D1845).withOpacity(0.05),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF0D1845,
                                    ).withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: OutlinedButton(
                                  onPressed: _showBarcodeDialog,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 8,
                                    ),
                                    backgroundColor: Colors.transparent,
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF0D1845,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.qr_code,
                                          size: 16,
                                          color: Color(0xFF0D1845),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Barcode',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF0D1845),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.qr_code,
                                      size: 16,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(width: 6),
                                    const Text(
                                      'Barcode',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                      ],
                    ),
                  ),
                ),

                // Right Card
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.all(12),
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
                      children: [
                        // Design Code with Auto Generate button
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: _designCodeController,
                                focusNode: _designCodeFocusNode,
                                decoration: _buildCleanInputDecoration(
                                  'Design Code',
                                  isRequired: true,
                                ).copyWith(errorText: _designCodeError),
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            SizedBox(
                              height: 48,
                              child: OutlinedButton.icon(
                                onPressed: _autoGenerateDesignCode,
                                icon: const Icon(Icons.auto_fix_high, size: 18),
                                label: const Text('Auto Generate'),
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  backgroundColor: Colors.white,
                                  foregroundColor: const Color(0xFF0D1845),
                                  side: BorderSide(color: Colors.grey.shade300),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Sub Category
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: OutlinedButton(
                            onPressed: _selectedCategoryId != null
                                ? () => _showCategorySearchDialog(
                                    startWithCategories: false,
                                  )
                                : null,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              backgroundColor: Colors.white,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.centerLeft,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedSubCategoryId != null &&
                                            subCategories.isNotEmpty
                                        ? (() {
                                            try {
                                              final selectedSubCategory =
                                                  subCategories.firstWhere(
                                                    (s) =>
                                                        s.id ==
                                                        _selectedSubCategoryId,
                                                  );
                                              return '${selectedSubCategory.title} (${selectedSubCategory.subCategoryCode})';
                                            } catch (e) {
                                              return 'Select Sub Category *';
                                            }
                                          })()
                                        : 'Select Sub Category *',
                                    style: TextStyle(
                                      color: _selectedSubCategoryId != null
                                          ? Colors.black87
                                          : Colors.grey[700],
                                      fontSize: 14,
                                      fontWeight: _selectedSubCategoryId != null
                                          ? FontWeight.w400
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: _selectedCategoryId != null
                                      ? Colors.grey.shade600
                                      : Colors.grey.shade400,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // QR Code Button
                        _qrCodeData != null
                            ? Container(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      const Color(0xFF0D1845).withOpacity(0.1),
                                      const Color(0xFF0D1845).withOpacity(0.05),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF0D1845,
                                    ).withOpacity(0.3),
                                    width: 1.5,
                                  ),
                                ),
                                child: OutlinedButton(
                                  onPressed: _showQrCodeDialog,
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                      horizontal: 8,
                                    ),
                                    backgroundColor: Colors.transparent,
                                    side: BorderSide.none,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 0,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF0D1845,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            6,
                                          ),
                                        ),
                                        child: const Icon(
                                          Icons.qr_code_scanner,
                                          size: 16,
                                          color: Color(0xFF0D1845),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'QR Code',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: const Color(0xFF0D1845),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                  horizontal: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade50,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.qr_code,
                                      size: 16,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'QR Code',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade400,
                                      ),
                                    ),
                                  ],
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
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
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),

          // Form Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Card
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(12),
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
                      children: [
                        // Product Type
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade50,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: Row(
                            children: [
                              Text(
                                'Product Type',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                'Single Product',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Price
                        TextFormField(
                          controller: _salePriceController,
                          focusNode: _salePriceFocusNode,
                          decoration: _buildCleanInputDecoration(
                            'Selling Price',
                            isRequired: true,
                          ).copyWith(errorText: _salePriceError),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Status
                        DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: _buildCleanDropdownDecoration(
                            'Status',
                            isRequired: true,
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                          ),
                          items: ['Active', 'Inactive'].map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(
                                status,
                                style: theme.textTheme.bodyMedium,
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStatus = value!;
                            });
                          },
                          validator: (value) {
                            // Status is optional; no required validation.
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Card
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.all(12),
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
                      children: [
                        // Opening stock
                        TextFormField(
                          controller: _openingStockQuantityController,
                          focusNode: _stockFocusNode,
                          decoration: _buildCleanInputDecoration(
                            'Opening Stock',
                            isRequired: true,
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                          ),
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          validator: (value) {
                            // Opening stock is optional. If provided, ensure it's a valid non-negative integer.
                            if (value != null && value.trim().isNotEmpty) {
                              final quantity = int.tryParse(value);
                              if (quantity == null) {
                                return 'Please enter a valid number';
                              }
                              if (quantity < 0) {
                                return 'Opening Stock cannot be negative';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Buying Price
                        TextFormField(
                          controller: _buyingPriceController,
                          decoration: _buildCleanInputDecoration(
                            'Buying Price (PKR)',
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                          ),
                          keyboardType: TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'^\d*\.?\d*'),
                            ),
                          ],
                          validator: (value) {
                            if (value != null && value.isNotEmpty) {
                              final price = double.tryParse(value);
                              if (price == null) {
                                return 'Please enter a valid price';
                              }
                              if (price < 0) {
                                return 'Price cannot be negative';
                              }
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),

                        // Vendor
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: OutlinedButton(
                            onPressed: _showVendorSearchDialog,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              backgroundColor: Colors.white,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.centerLeft,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedVendorId != null &&
                                            vendors.isNotEmpty
                                        ? (() {
                                            try {
                                              final selectedVendor = vendors
                                                  .firstWhere(
                                                    (v) =>
                                                        v.id ==
                                                        _selectedVendorId,
                                                  );
                                              return '${selectedVendor.fullName} (${selectedVendor.vendorCode})';
                                            } catch (e) {
                                              return 'Select Vendor *';
                                            }
                                          })()
                                        : 'Select Vendor *',
                                    style: TextStyle(
                                      color: _selectedVendorId != null
                                          ? Colors.black87
                                          : Colors.grey[700],
                                      fontSize: 14,
                                      fontWeight: _selectedVendorId != null
                                          ? FontWeight.w400
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                              ],
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
        ],
      ),
    );
  }

  // Submit Section
  Widget _buildSubmitSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
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
        child: AnimatedBuilder(
          animation: _submitAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _submitAnimation.value,
              child: Container(
                decoration: BoxDecoration(
                  gradient: isSubmitting
                      ? null
                      : LinearGradient(
                          colors: [
                            const Color(0xFF28A745),
                            const Color(0xFF20B545),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: isSubmitting
                      ? null
                      : [
                          BoxShadow(
                            color: const Color(0xFF28A745).withOpacity(0.4),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                ),
                child: ElevatedButton(
                  onPressed: isSubmitting
                      ? null
                      : () {
                          _submitAnimationController.forward().then((_) {
                            _submitAnimationController.reverse();
                          });
                          _submitForm();
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    elevation: 0,
                    shadowColor: Colors.transparent,
                    textStyle: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
                  child: isSubmitting
                      ? SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: const AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_circle_outline, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Create Product',
                              style: theme.textTheme.labelLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.5,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            );
          },
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Header
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(bottom: BorderSide(color: Colors.grey.shade200)),
            ),
            child: Row(
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
                Expanded(
                  child: Text(
                    'Variants & Attributes',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _showAddVariantDialog,
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Color(0xFF0D1845),
                    size: 24,
                  ),
                  tooltip: 'Add New Variant',
                  style: IconButton.styleFrom(
                    backgroundColor: const Color(0xFF0D1845).withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Form Content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Card
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.all(12),
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
                      children: [
                        // Size
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: OutlinedButton(
                            onPressed: _showSizeSearchDialog,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              backgroundColor: Colors.white,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.centerLeft,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedSizeIds.isNotEmpty &&
                                            sizes.isNotEmpty
                                        ? (() {
                                            try {
                                              final selectedSizes = sizes
                                                  .where(
                                                    (s) => _selectedSizeIds
                                                        .contains(s.id),
                                                  )
                                                  .toList();
                                              return selectedSizes
                                                  .map((s) => s.title)
                                                  .join(', ');
                                            } catch (e) {
                                              return 'Select Sizes';
                                            }
                                          })()
                                        : 'Select Sizes',
                                    style: TextStyle(
                                      color: _selectedSizeIds.isNotEmpty
                                          ? Colors.black87
                                          : Colors.grey[700],
                                      fontSize: 14,
                                      fontWeight: _selectedSizeIds.isNotEmpty
                                          ? FontWeight.w400
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Material/Fabric
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: OutlinedButton(
                            onPressed: _showMaterialSearchDialog,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              backgroundColor: Colors.white,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.centerLeft,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedMaterialIds.isNotEmpty &&
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
                                              return selectedMaterials
                                                  .map((m) => m.title)
                                                  .join(', ');
                                            } catch (e) {
                                              return 'Select Materials/Fabrics';
                                            }
                                          })()
                                        : 'Select Materials/Fabrics',
                                    style: TextStyle(
                                      color: _selectedMaterialIds.isNotEmpty
                                          ? Colors.black87
                                          : Colors.grey[700],
                                      fontSize: 14,
                                      fontWeight:
                                          _selectedMaterialIds.isNotEmpty
                                          ? FontWeight.w400
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Right Card
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    padding: const EdgeInsets.all(12),
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
                      children: [
                        // Color
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: OutlinedButton(
                            onPressed: _showColorSearchDialog,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              backgroundColor: Colors.white,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.centerLeft,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedColorIds.isNotEmpty &&
                                            colors.isNotEmpty
                                        ? (() {
                                            try {
                                              final selectedColors = colors
                                                  .where(
                                                    (c) => _selectedColorIds
                                                        .contains(c.id),
                                                  )
                                                  .toList();
                                              return selectedColors
                                                  .map((c) => c.title)
                                                  .join(', ');
                                            } catch (e) {
                                              return 'Select Colors';
                                            }
                                          })()
                                        : 'Select Colors',
                                    style: TextStyle(
                                      color: _selectedColorIds.isNotEmpty
                                          ? Colors.black87
                                          : Colors.grey[700],
                                      fontSize: 14,
                                      fontWeight: _selectedColorIds.isNotEmpty
                                          ? FontWeight.w400
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Season
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.grey.shade300),
                          ),
                          child: OutlinedButton(
                            onPressed: _showSeasonSearchDialog,
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              backgroundColor: Colors.white,
                              side: BorderSide.none,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              alignment: Alignment.centerLeft,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _selectedSeasonIds.isNotEmpty &&
                                            seasons.isNotEmpty
                                        ? (() {
                                            try {
                                              final selectedSeasons = seasons
                                                  .where(
                                                    (s) => _selectedSeasonIds
                                                        .contains(s.id),
                                                  )
                                                  .toList();
                                              return selectedSeasons
                                                  .map((s) => s.title)
                                                  .join(', ');
                                            } catch (e) {
                                              return 'Select Seasons';
                                            }
                                          })()
                                        : 'Select Seasons',
                                    style: TextStyle(
                                      color: _selectedSeasonIds.isNotEmpty
                                          ? Colors.black87
                                          : Colors.grey[700],
                                      fontSize: 14,
                                      fontWeight: _selectedSeasonIds.isNotEmpty
                                          ? FontWeight.w400
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.grey.shade600,
                                  size: 20,
                                ),
                              ],
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
        ],
      ),
    );
  }

  void _showAddVariantDialog() {
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
                        Icons.add_circle_outline,
                        color: Color(0xFF0D1845),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Add New Variant',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Text(
                  'Choose the type of variant to add:',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Variant Type Buttons
                Column(
                  children: [
                    // Add Color Button
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop(); // Close variant display
                          final created = await _showAddColorDialog();
                          // If color was created, reopen search dialog to show new color
                          if (created == true) {
                            _showColorSearchDialog();
                          }
                        },
                        icon: const Icon(Icons.color_lens, size: 18),
                        label: const Text('Add New Color'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFFDC3545),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    // Add Material Button
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop(); // Close variant display
                          final created = await _showAddMaterialDialog();
                          // If material was created, reopen search dialog to show new material
                          if (created == true) {
                            _showMaterialSearchDialog();
                          }
                        },
                        icon: const Icon(Icons.texture, size: 18),
                        label: const Text('Add New Material'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF28A745),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    // Add Size Button
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop(); // Close variant display
                          final created = await _showAddSizeDialog();
                          // If size was created, reopen search dialog to show new size
                          if (created == true) {
                            _showSizeSearchDialog();
                          }
                        },
                        icon: const Icon(Icons.straighten, size: 18),
                        label: const Text('Add New Size'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF17A2B8),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ),

                    // Add Season Button
                    Container(
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          Navigator.of(context).pop(); // Close variant display
                          final created = await _showAddSeasonDialog();
                          // If season was created, reopen search dialog to show new season
                          if (created == true) {
                            _showSeasonSearchDialog();
                          }
                        },
                        icon: const Icon(Icons.wb_sunny, size: 18),
                        label: const Text('Add New Season'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF6F42C1),
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

                const SizedBox(height: 16),

                // Close Button
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool?> _showAddColorDialog() async {
    String selectedColor = ''; // Start empty
    String selectedStatus = 'Active';
    bool useCustomColor = false;
    String customColorName = '';
    final TextEditingController colorNameController = TextEditingController();

    final parentContext = context; // Store parent context
    bool createdSuccessfully = false; // Track if creation was successful

    await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.color_lens, color: Colors.black87),
                  const SizedBox(width: 12),
                  Text(
                    'Add New Color',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Custom Color Name Input (Primary)
                    TextFormField(
                      controller: colorNameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Color Name *',
                        hintText:
                            'Enter color name (e.g., Sky Blue, Rose Gold)',
                        prefixIcon: Icon(Icons.edit, color: Colors.black54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      onChanged: (value) {
                        if (context.mounted) {
                          setState(() {
                            customColorName = value;
                            if (value.trim().isNotEmpty) {
                              useCustomColor = true;
                              selectedColor = '';
                            }
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Divider with "OR"
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey[300])),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey[300])),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Predefined Colors Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedColor.isEmpty ? null : selectedColor,
                      hint: Text('Select from predefined colors'),
                      decoration: InputDecoration(
                        labelText: 'Select Color',
                        prefixIcon: Icon(Icons.palette, color: Colors.black54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      items: predefinedColors
                          .map(
                            (color) => DropdownMenuItem(
                              value: color,
                              child: Row(
                                children: [
                                  Container(
                                    width: 24,
                                    height: 24,
                                    margin: EdgeInsets.only(right: 12),
                                    decoration: BoxDecoration(
                                      color: _getColorFromName(color),
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: Color(0xFFDEE2E6),
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                  Text(color),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null && context.mounted) {
                          setState(() {
                            selectedColor = value;
                            useCustomColor = false;
                            customColorName = '';
                            colorNameController.clear();
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    // Color Preview
                    if ((useCustomColor && customColorName.trim().isNotEmpty) ||
                        selectedColor.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Color(0xFFDEE2E6)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Preview',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 8),
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: useCustomColor
                                        ? Colors.grey
                                        : _getColorFromName(selectedColor),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Color(0xFFDEE2E6),
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  useCustomColor
                                      ? customColorName
                                      : selectedColor,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),
                    ],

                    // Status Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      decoration: InputDecoration(
                        labelText: 'Status',
                        prefixIcon: Icon(
                          Icons.toggle_on,
                          color: Colors.black54,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'Active',
                          child: Row(
                            children: [
                              Icon(
                                Icons.check_circle,
                                color: Colors.green,
                                size: 20,
                              ),
                              SizedBox(width: 8),
                              Text('Active'),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'Inactive',
                          child: Row(
                            children: [
                              Icon(Icons.cancel, color: Colors.red, size: 20),
                              SizedBox(width: 8),
                              Text('Inactive'),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null && context.mounted) {
                          setState(() {
                            selectedStatus = value;
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Determine color name
                    String colorName;
                    if (useCustomColor && customColorName.trim().isNotEmpty) {
                      colorName = customColorName.trim();
                    } else if (selectedColor.isNotEmpty) {
                      colorName = selectedColor;
                    } else {
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please enter a custom color name or select a predefined color',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Close dialog first
                    Navigator.of(context).pop();

                    try {
                      // Create the color
                      final newColor = await InventoryService.createColor({
                        'title': colorName,
                        'status': selectedStatus,
                      });

                      // Refresh provider
                      if (parentContext.mounted) {
                        await Provider.of<InventoryProvider>(
                          parentContext,
                          listen: false,
                        ).refreshColors();
                      }

                      // Fetch variants to update local lists (on the page widget)
                      await _fetchVariants();

                      print(
                        '🎨 Color created: ${newColor['id']} - ${newColor['title']}',
                      );
                      print('🎨 Total colors after fetch: ${colors.length}');
                      print(
                        '🎨 Color IDs: ${colors.map((c) => c.id).toList()}',
                      );

                      // Auto-select the newly created color (directly modify list, _fetchVariants already called setState)
                      if (!_selectedColorIds.contains(newColor['id'])) {
                        _selectedColorIds.add(newColor['id']);
                        print('🎨 Auto-selected color ID: ${newColor['id']}');
                      } else {
                        print('🎨 Color already selected: ${newColor['id']}');
                      }

                      // Show success message
                      if (parentContext.mounted) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Color "${newColor['title']}" created and added successfully',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }

                      createdSuccessfully =
                          true; // Mark as successfully created
                    } catch (e) {
                      if (parentContext.mounted) {
                        String errorMessage = 'Failed to create color';

                        // Parse error message from API response
                        final errorString = e.toString();
                        if (errorString.contains('Inventory API failed:')) {
                          try {
                            // Extract JSON from error message
                            final jsonStart = errorString.indexOf('{');
                            if (jsonStart != -1) {
                              final jsonString = errorString.substring(
                                jsonStart,
                              );
                              final errorData = jsonDecode(jsonString);

                              // Get the message field
                              if (errorData.containsKey('message')) {
                                errorMessage = errorData['message'];
                              }
                            }
                          } catch (parseError) {
                            // Keep default error message
                          }
                        }

                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0D1845),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );

    return createdSuccessfully; // Return whether color was created successfully
  }

  // Helper method to get Color from color name
  Color _getColorFromName(String name) {
    final colorMap = {
      'Red': Colors.red,
      'Blue': Colors.blue,
      'Green': Colors.green,
      'Yellow': Colors.yellow,
      'Black': Colors.black,
      'White': Colors.white,
      'Orange': Colors.orange,
      'Purple': Colors.purple,
      'Pink': Colors.pink,
      'Brown': const Color(0xFF8B4513),
      'Grey': Colors.grey,
      'Navy': const Color(0xFF000080),
      'Maroon': const Color(0xFF800000),
    };
    return colorMap[name] ?? Colors.grey;
  }

  Future<bool?> _showAddMaterialDialog() async {
    String selectedMaterial = ''; // Start empty
    String selectedStatus = 'Active';
    bool useCustomMaterial = false;
    String customMaterialName = '';
    final TextEditingController materialNameController =
        TextEditingController();
    final parentContext = context; // Store parent context
    bool createdSuccessfully = false; // Track if creation was successful

    await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.texture, color: Colors.black87),
                  const SizedBox(width: 12),
                  Text(
                    'Add New Material',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Custom Material Name Input (Primary)
                    TextFormField(
                      controller: materialNameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Material Name *',
                        hintText:
                            'Enter material name (e.g., Silk Blend, Organic Cotton)',
                        prefixIcon: Icon(Icons.edit, color: Colors.black54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      onChanged: (value) {
                        if (context.mounted) {
                          setState(() {
                            customMaterialName = value;
                            if (value.trim().isNotEmpty) {
                              useCustomMaterial = true;
                              selectedMaterial = '';
                            }
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Divider with "OR"
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey[300])),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey[300])),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Predefined Materials Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedMaterial.isEmpty ? null : selectedMaterial,
                      hint: Text('Select from predefined materials'),
                      decoration: InputDecoration(
                        labelText: 'Select Material',
                        prefixIcon: Icon(Icons.list, color: Colors.black54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      items: predefinedMaterials
                          .map(
                            (material) => DropdownMenuItem(
                              value: material,
                              child: Text(material),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null && context.mounted) {
                          setState(() {
                            selectedMaterial = value;
                            useCustomMaterial = false;
                            customMaterialName = '';
                            materialNameController.clear();
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    // Material Preview
                    if ((useCustomMaterial &&
                            customMaterialName.trim().isNotEmpty) ||
                        selectedMaterial.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Preview:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFFE9ECEF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Color(0xFFDEE2E6)),
                              ),
                              child: Center(
                                child: Text(
                                  useCustomMaterial &&
                                          customMaterialName.trim().isNotEmpty
                                      ? customMaterialName
                                      : selectedMaterial,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 16),

                    // Status Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
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
                      items: ['Active', 'Inactive']
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedStatus = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Determine final material name
                    final materialName = useCustomMaterial
                        ? customMaterialName.trim()
                        : selectedMaterial;

                    // Validate material name
                    if (materialName.isEmpty) {
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please enter a material name or select from the list',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Close dialog first
                    Navigator.of(context).pop();

                    try {
                      // Create the material
                      final newMaterial = await InventoryService.createMaterial(
                        {'title': materialName, 'status': selectedStatus},
                      );

                      // Refresh provider
                      if (parentContext.mounted) {
                        await Provider.of<InventoryProvider>(
                          parentContext,
                          listen: false,
                        ).refreshMaterials();
                      }

                      // Fetch variants to update local lists (on the page widget)
                      await _fetchVariants();

                      // Auto-select the newly created material (directly modify list)
                      if (!_selectedMaterialIds.contains(newMaterial['id'])) {
                        _selectedMaterialIds.add(newMaterial['id']);
                      }

                      // Mark as successfully created
                      createdSuccessfully = true;

                      // Show success message
                      if (parentContext.mounted) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Material "${newMaterial['title']}" created and added successfully',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (parentContext.mounted) {
                        String errorMessage = 'Failed to create material';

                        // Parse error message from API response
                        final errorString = e.toString();
                        if (errorString.contains('Inventory API failed:')) {
                          try {
                            // Extract JSON from error message
                            final jsonStart = errorString.indexOf('{');
                            if (jsonStart != -1) {
                              final jsonString = errorString.substring(
                                jsonStart,
                              );
                              final errorData = jsonDecode(jsonString);

                              // Get the message field
                              if (errorData.containsKey('message')) {
                                errorMessage = errorData['message'];
                              }
                            }
                          } catch (parseError) {
                            // Keep default error message
                          }
                        }

                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0D1845),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
    return createdSuccessfully; // Return whether creation was successful
  }

  Future<bool?> _showAddSizeDialog() async {
    String selectedSize = ''; // Start empty
    String selectedStatus = 'Active';
    bool useCustomSize = false;
    String customSizeName = '';
    final TextEditingController sizeNameController = TextEditingController();
    final parentContext = context; // Store parent context
    bool createdSuccessfully = false; // Track if creation was successful

    await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.straighten, color: Colors.black87),
                  const SizedBox(width: 12),
                  Text(
                    'Add New Size',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Custom Size Name Input (Primary)
                    TextFormField(
                      controller: sizeNameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Size Name *',
                        hintText: 'Enter size name (e.g., XXL, 42, Custom)',
                        prefixIcon: Icon(Icons.edit, color: Colors.black54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      onChanged: (value) {
                        if (context.mounted) {
                          setState(() {
                            customSizeName = value;
                            if (value.trim().isNotEmpty) {
                              useCustomSize = true;
                              selectedSize = '';
                            }
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Divider with "OR"
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey[300])),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey[300])),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Predefined Sizes Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedSize.isEmpty ? null : selectedSize,
                      hint: Text('Select from predefined sizes'),
                      decoration: InputDecoration(
                        labelText: 'Select Size',
                        prefixIcon: Icon(Icons.list, color: Colors.black54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      items: predefinedSizes
                          .map(
                            (size) => DropdownMenuItem(
                              value: size,
                              child: Text(size),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null && context.mounted) {
                          setState(() {
                            selectedSize = value;
                            useCustomSize = false;
                            customSizeName = '';
                            sizeNameController.clear();
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    // Size Preview
                    if ((useCustomSize && customSizeName.trim().isNotEmpty) ||
                        selectedSize.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Preview:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFFE9ECEF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Color(0xFFDEE2E6)),
                              ),
                              child: Center(
                                child: Text(
                                  useCustomSize &&
                                          customSizeName.trim().isNotEmpty
                                      ? customSizeName
                                      : selectedSize,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 16),

                    // Status Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
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
                      items: ['Active', 'Inactive']
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedStatus = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Determine final size name
                    final sizeName = useCustomSize
                        ? customSizeName.trim()
                        : selectedSize;

                    // Validate size name
                    if (sizeName.isEmpty) {
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please enter a size name or select from the list',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Close dialog first
                    Navigator.of(context).pop();

                    try {
                      // Create the size
                      final newSize = await InventoryService.createSize({
                        'title': sizeName,
                        'status': selectedStatus,
                      });

                      // Refresh provider
                      if (parentContext.mounted) {
                        await Provider.of<InventoryProvider>(
                          parentContext,
                          listen: false,
                        ).refreshSizes();
                      }

                      // Fetch variants to update local lists (on the page widget)
                      await _fetchVariants();

                      // Auto-select the newly created size (directly modify list)
                      if (!_selectedSizeIds.contains(newSize['id'])) {
                        _selectedSizeIds.add(newSize['id']);
                      }

                      // Mark as successfully created
                      createdSuccessfully = true;

                      // Show success message
                      if (parentContext.mounted) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Size "${newSize['title']}" created and added successfully',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (parentContext.mounted) {
                        String errorMessage = 'Failed to create size';

                        // Parse error message from API response
                        final errorString = e.toString();
                        if (errorString.contains('Inventory API failed:')) {
                          try {
                            // Extract JSON from error message
                            final jsonStart = errorString.indexOf('{');
                            if (jsonStart != -1) {
                              final jsonString = errorString.substring(
                                jsonStart,
                              );
                              final errorData = jsonDecode(jsonString);

                              // Get the message field
                              if (errorData.containsKey('message')) {
                                errorMessage = errorData['message'];
                              }
                            }
                          } catch (parseError) {
                            // Keep default error message
                          }
                        }

                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0D1845),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
    return createdSuccessfully; // Return whether creation was successful
  }

  Future<bool?> _showAddSeasonDialog() async {
    String selectedSeason = ''; // Start empty
    String selectedStatus = 'Active';
    bool useCustomSeason = false;
    String customSeasonName = '';
    final TextEditingController seasonNameController = TextEditingController();
    final parentContext = context; // Store parent context
    bool createdSuccessfully = false; // Track if creation was successful

    await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.wb_sunny, color: Colors.black87),
                  const SizedBox(width: 12),
                  Text(
                    'Add New Season',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Custom Season Name Input (Primary)
                    TextFormField(
                      controller: seasonNameController,
                      autofocus: true,
                      decoration: InputDecoration(
                        labelText: 'Season Name *',
                        hintText: 'Enter season name (e.g., Pre-Fall, Monsoon)',
                        prefixIcon: Icon(Icons.edit, color: Colors.black54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      onChanged: (value) {
                        if (context.mounted) {
                          setState(() {
                            customSeasonName = value;
                            if (value.trim().isNotEmpty) {
                              useCustomSeason = true;
                              selectedSeason = '';
                            }
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 16),

                    // Divider with "OR"
                    Row(
                      children: [
                        Expanded(child: Divider(color: Colors.grey[300])),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            'OR',
                            style: TextStyle(
                              color: Colors.black54,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        Expanded(child: Divider(color: Colors.grey[300])),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Predefined Seasons Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedSeason.isEmpty ? null : selectedSeason,
                      hint: Text('Select from predefined seasons'),
                      decoration: InputDecoration(
                        labelText: 'Select Season',
                        prefixIcon: Icon(Icons.list, color: Colors.black54),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 12,
                        ),
                        fillColor: Colors.white,
                        filled: true,
                      ),
                      items: predefinedSeasons
                          .map(
                            (season) => DropdownMenuItem(
                              value: season,
                              child: Text(season),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null && context.mounted) {
                          setState(() {
                            selectedSeason = value;
                            useCustomSeason = false;
                            customSeasonName = '';
                            seasonNameController.clear();
                          });
                        }
                      },
                    ),

                    const SizedBox(height: 20),

                    // Season Preview
                    if ((useCustomSeason &&
                            customSeasonName.trim().isNotEmpty) ||
                        selectedSeason.isNotEmpty) ...[
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Preview:',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.black54,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: double.infinity,
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Color(0xFFE9ECEF),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Color(0xFFDEE2E6)),
                              ),
                              child: Center(
                                child: Text(
                                  useCustomSeason &&
                                          customSeasonName.trim().isNotEmpty
                                      ? customSeasonName
                                      : selectedSeason,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],

                    const SizedBox(height: 16),

                    // Status Dropdown
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
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
                      items: ['Active', 'Inactive']
                          .map(
                            (status) => DropdownMenuItem(
                              value: status,
                              child: Text(status),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedStatus = value);
                        }
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () async {
                    // Determine final season name
                    final seasonName = useCustomSeason
                        ? customSeasonName.trim()
                        : selectedSeason;

                    // Validate season name
                    if (seasonName.isEmpty) {
                      ScaffoldMessenger.of(parentContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Please enter a season name or select from the list',
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Close dialog first
                    Navigator.of(context).pop();

                    try {
                      // Create the season
                      final newSeason = await InventoryService.createSeason({
                        'title': seasonName,
                        'status': selectedStatus,
                      });

                      // Refresh provider
                      if (parentContext.mounted) {
                        await Provider.of<InventoryProvider>(
                          parentContext,
                          listen: false,
                        ).refreshSeasons();
                      }

                      // Fetch variants to update local lists (on the page widget)
                      await _fetchVariants();

                      // Auto-select the newly created season (directly modify list)
                      if (!_selectedSeasonIds.contains(newSeason['id'])) {
                        _selectedSeasonIds.add(newSeason['id']);
                      }

                      // Mark as successfully created
                      createdSuccessfully = true;

                      // Show success message
                      if (parentContext.mounted) {
                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Season "${newSeason['title']}" created and added successfully',
                            ),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    } catch (e) {
                      if (parentContext.mounted) {
                        String errorMessage = 'Failed to create season';

                        // Parse error message from API response
                        final errorString = e.toString();
                        if (errorString.contains('Inventory API failed:')) {
                          try {
                            // Extract JSON from error message
                            final jsonStart = errorString.indexOf('{');
                            if (jsonStart != -1) {
                              final jsonString = errorString.substring(
                                jsonStart,
                              );
                              final errorData = jsonDecode(jsonString);

                              // Get the message field
                              if (errorData.containsKey('message')) {
                                errorMessage = errorData['message'];
                              }
                            }
                          } catch (parseError) {
                            // Keep default error message
                          }
                        }

                        ScaffoldMessenger.of(parentContext).showSnackBar(
                          SnackBar(
                            content: Text(errorMessage),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF0D1845),
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
    return createdSuccessfully; // Return whether creation was successful
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
                    // show a numeric-only EAN-13 barcode (derived from entered text)
                    barcode: Barcode.ean13(),
                    data: getNumericBarcodeFromString(_barcodeController.text),
                    width: 300,
                    height: 120,
                    drawText: true,
                    style: const TextStyle(fontSize: 14, color: Colors.black),
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
                        'Product: ${_titleController.text}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Barcode: ${_barcodeController.text}',
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
                    // Print Button
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
                              color: const Color(0xFF0D1845).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => _printBarcode(),
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text('Print Barcode'),
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
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Close Button
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
    if (_qrCodeData == null || _qrCodeData!.isEmpty) return;

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
                    data: _qrCodeData!,
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
                        'Product: ${_titleController.text}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Design Code: ${_designCodeController.text}',
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
                    // Print Button
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
                              color: const Color(0xFF0D1845).withOpacity(0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: () => _printQrCode(),
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text('Print QR Code'),
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
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Close Button
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

  Future<void> _printBarcode() async {
    // Ask for quantity to print (default 1)
    final qty = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: '1');
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          title: Row(
            children: [
              Icon(Icons.qr_code_scanner, color: Color(0xFF0D1845), size: 24),
              SizedBox(width: 12),
              Text(
                'Configure Barcode Generation',
                style: TextStyle(
                  color: Color(0xFF0D1845),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quantity (1-1000):',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF343A40),
                  fontSize: 14,
                ),
              ),
              SizedBox(height: 8),
              TextField(
                controller: controller,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  hintText: 'Enter quantity',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
              ),
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Color(0xFFE3F2FD),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Color(0xFF1976D2),
                      size: 16,
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Barcode stickers will be generated as 58mm x 40mm labels',
                        style: TextStyle(
                          color: Color(0xFF1976D2),
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = int.tryParse(controller.text.trim());
                if (val == null || val <= 0 || val > 1000) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(
                      content: Text('Enter a valid quantity (1-1000)'),
                    ),
                  );
                  return;
                }
                Navigator.of(ctx).pop(val);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF0D1845),
                foregroundColor: Colors.white,
              ),
              child: const Text('Generate Barcodes'),
            ),
          ],
        );
      },
    );

    if (qty == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Print cancelled')));
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Generating barcode stickers...')),
      );
    }

    try {
      // Use the same logic as print_barcode_page.dart
      final pdf = pw.Document();

      // Barcode sticker size: 2x1 inches (50.8mm x 25.4mm)
      const double stickerWidthMM = 50.8;
      const double stickerHeightMM =
          25.4; // Convert mm to points (1 mm = 2.83465 points)
      const double mmToPoints = 2.83465;
      final double stickerWidth = stickerWidthMM * mmToPoints;
      final double stickerHeight = stickerHeightMM * mmToPoints;

      // Create custom page format for sticker
      final pageFormat = pdf_pkg.PdfPageFormat(stickerWidth, stickerHeight);

      // Generate one sticker per page for each copy
      for (int i = 0; i < qty; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: pageFormat,
            margin: pw.EdgeInsets.zero,
            build: (pw.Context context) {
              return pw.Container(
                width: stickerWidth,
                height: stickerHeight,
                child: pw.Column(
                  mainAxisAlignment: pw.MainAxisAlignment.center,
                  children: [
                    // Top: Product Name
                    pw.Container(
                      height: stickerHeight * 0.20,
                      child: pw.Center(
                        child: pw.Text(
                          _titleController.text,
                          style: pw.TextStyle(
                            fontSize: 8,
                            fontWeight: pw.FontWeight.bold,
                          ),
                          textAlign: pw.TextAlign.center,
                          maxLines: 2,
                          overflow: pw.TextOverflow.clip,
                        ),
                      ),
                    ),
                    // Middle: Barcode
                    pw.Container(
                      width: stickerWidth * 0.85,
                      height: stickerHeight * 0.40,
                      child: pw.BarcodeWidget(
                        barcode: pw.Barcode.ean13(),
                        data: getNumericBarcodeFromString(
                          _barcodeController.text,
                        ),
                      ),
                    ),
                    pw.SizedBox(height: 1),
                    // Below: Price
                    pw.Text(
                      'Rs. ${_salePriceController.text}',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                    pw.SizedBox(height: 1),
                    // Bottom: Store Name
                    pw.Text(
                      'Dhanpuri by Get Going',
                      style: pw.TextStyle(
                        fontSize: 6,
                        fontWeight: pw.FontWeight.normal,
                      ),
                      textAlign: pw.TextAlign.center,
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }

      // Save PDF to file and use sharePdf like print_barcode_page
      final bytes = await pdf.save();
      await Printing.sharePdf(bytes: bytes, filename: 'barcode_stickers.pdf');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$qty barcode sticker(s) generated successfully!'),
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
  }

  Future<void> _printQrCode() async {
    // Ask for quantity to print (default 1)
    final qty = await showDialog<int>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController(text: '1');
        return AlertDialog(
          title: const Text('How many labels to print?'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Enter quantity'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(null),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                final val = int.tryParse(controller.text.trim());
                if (val == null || val <= 0) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Enter a valid quantity')),
                  );
                  return;
                }
                Navigator.of(ctx).pop(val);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );

    if (qty == null) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Print cancelled')));
      }
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Sending print job...')));
    }

    try {
      final pdf = pw.Document();
      for (int i = 0; i < qty; i++) {
        pdf.addPage(
          pw.Page(
            pageFormat: pdf_pkg.PdfPageFormat.a4,
            build: (pw.Context ctx) {
              return pw.Container(
                padding: pw.EdgeInsets.all(16),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      _titleController.text,
                      style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 8),
                    pw.Text(
                      'QR Data:',
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                      ),
                    ),
                    pw.SizedBox(height: 6),
                    pw.Text(
                      _qrCodeData ?? '',
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      }
      await Printing.layoutPdf(onLayout: (format) async => pdf.save());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Print dialog opened.'),
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
  }

  void _showVendorSearchDialog() {
    // Initialize filtered vendors with all vendors
    _filteredVendors = List.from(vendors);
    final TextEditingController searchController = TextEditingController();
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void _filterVendors(String query) {
              setState(() {
                if (query.isEmpty) {
                  _filteredVendors = List.from(vendors);
                } else {
                  _filteredVendors = vendors.where((vendor) {
                    final fullName = vendor.fullName.toLowerCase();
                    final vendorCode = vendor.vendorCode.toLowerCase();
                    final searchQuery = query.toLowerCase();
                    return fullName.contains(searchQuery) ||
                        vendorCode.contains(searchQuery);
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
                            Icons.business,
                            color: Color(0xFF0D1845),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Select Vendor',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                        ),
                        const Spacer(),
                        // Add Vendor button — opens the AddVendor dialog and auto-selects
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF28A745),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              try {
                                final createdVendor =
                                    await showDialog<Map<String, dynamic>>(
                                      context: context,
                                      builder: (ctx) => const AddVendorPage(),
                                    );
                                if (createdVendor != null) {
                                  // Refresh vendors
                                  await _fetchVendors();
                                  // Select the newly created vendor
                                  setState(() {
                                    this.setState(() {
                                      _selectedVendorId =
                                          createdVendor['id'] as int?;
                                      // Update filtered list
                                      _filterVendors(searchController.text);
                                    });
                                    _generateBarcodeAndQrFromProductAndVendor();
                                  });
                                }
                              } catch (e) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Failed to create vendor: $e',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            },
                            icon: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 20,
                            ),
                            tooltip: 'Add New Vendor',
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
                          hintText: 'Search by name or vendor code...',
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
                        onChanged: _filterVendors,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Vendor List
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
                        child: _filteredVendors.isEmpty
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
                                        'No vendors found',
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
                                itemCount: _filteredVendors.length,
                                itemBuilder: (context, index) {
                                  final vendor = _filteredVendors[index];
                                  final isSelected =
                                      vendor.id == _selectedVendorId;

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        this.setState(() {
                                          _selectedVendorId = vendor.id;
                                          // Generate barcode when vendor is selected
                                          _generateBarcodeAndQrFromProductAndVendor();
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
                                            index < _filteredVendors.length - 1
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
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  vendor.fullName,
                                                  style: Theme.of(context)
                                                      .textTheme
                                                      .bodyMedium
                                                      ?.copyWith(
                                                        fontWeight:
                                                            FontWeight.w500,
                                                        color: isSelected
                                                            ? const Color(
                                                                0xFF0D1845,
                                                              )
                                                            : Colors.black87,
                                                      ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                  'Code: ${vendor.vendorCode}',
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

  void _showCategorySearchDialog({bool startWithCategories = true}) async {
    // Fetch categories if not loaded yet
    if (categories.isEmpty) {
      await _fetchCategories();
    }

    // Initialize filtered categories and subcategories
    List<Category> filteredCategories = List.from(categories);
    List<SubCategory> filteredSubCategories = List.from(subCategories);
    final TextEditingController searchController = TextEditingController();
    bool showCategories =
        startWithCategories; // Toggle between categories and subcategories
    final parentContext = context; // outer context for add dialogs

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
                        const SizedBox(width: 8),
                        // Add Category/Subcategory button
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF28A745),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              // Close current dialog then open appropriate add dialog
                              Navigator.of(context).pop();
                              if (showCategories) {
                                // Add Category
                                final created = await AddCategoryPage.show(
                                  parentContext,
                                );
                                if (created == true) {
                                  // Refresh and auto-select the newly created category (pick highest id)
                                  await _fetchCategories();
                                  if (mounted && categories.isNotEmpty) {
                                    final maxId = categories
                                        .map((c) => c.id)
                                        .reduce((a, b) => a > b ? a : b);
                                    setState(() {
                                      _selectedCategoryId = maxId;
                                      _selectedSubCategoryId = null;
                                    });
                                    // fetch subcategories for new category
                                    await _fetchSubCategories(
                                      _selectedCategoryId!,
                                    );
                                  }
                                }
                              } else {
                                // Add Sub Category — requires a parent category
                                final created = await AddSubCategoryPage.show(
                                  parentContext,
                                );
                                if (created == true) {
                                  // Refresh sub categories for the currently selected category (if any)
                                  if (_selectedCategoryId != null) {
                                    await _fetchSubCategories(
                                      _selectedCategoryId!,
                                    );
                                    if (mounted && subCategories.isNotEmpty) {
                                      final maxId = subCategories
                                          .map((s) => s.id)
                                          .reduce((a, b) => a > b ? a : b);
                                      setState(() {
                                        _selectedSubCategoryId = maxId;
                                      });
                                    }
                                  } else {
                                    // If no category selected, refresh categories too so user can pick
                                    await _fetchCategories();
                                  }
                                }
                              }
                            },
                            icon: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 20,
                            ),
                            tooltip: showCategories
                                ? 'Add New Category'
                                : 'Add New Sub Category',
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
                          'Select Size',
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
                                        _generateQrCode();
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
                          'Select Color',
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
                                        _generateQrCode();
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
                          'Select Material/Fabric',
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
                                        _generateQrCode();
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
                          'Select Season',
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
                                        _generateQrCode();
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

  void _generateBarcodeAndQrFromProductAndVendor() {
    final productName = _titleController.text.trim();
    final designCode = _designCodeController.text.trim();

    // Get selected vendor details
    vendor.Vendor? selectedVendor;
    if (_selectedVendorId != null) {
      try {
        selectedVendor = vendors.firstWhere((v) => v.id == _selectedVendorId);
      } catch (e) {
        // Vendor not found
      }
    }

    if (productName.isNotEmpty &&
        selectedVendor != null &&
        _salePriceController.text.isNotEmpty) {
      // Generate barcode from product name, selling price, and vendor ID combination
      _barcodeController.text =
          '${productName}_${_salePriceController.text}_${_selectedVendorId}';

      // Generate QR code if design code is also available
      if (designCode.isNotEmpty) {
        _generateQrCode();
      }
    } else {
      // Clear barcode and QR code if required fields are missing
      _barcodeController.clear();
      _qrCodeController.clear();
      setState(() {
        _qrCodeData = null;
        _qrCodeImagePath = null;
      });
    }
  }

  /// Auto-generate a design code when user requests it.
  /// Uses product name initials (up to 3 letters) plus a time-based suffix.
  void _autoGenerateDesignCode() {
    final title = _titleController.text.trim();
    String base;
    if (title.isNotEmpty) {
      base = title
          .split(RegExp(r'\s+'))
          .where((s) => s.isNotEmpty)
          .map((s) => s[0].toUpperCase())
          .take(3)
          .join();
    } else {
      base = 'PRD';
    }

    final suffix = (DateTime.now().millisecondsSinceEpoch % 100000)
        .toString()
        .padLeft(5, '0');
    final code = '$base-$suffix';

    setState(() {
      _designCodeController.text = code;
    });

    // Refresh generated barcode/QR if necessary
    _generateBarcodeAndQrFromProductAndVendor();

    // Provide quick feedback
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Design code generated: $code'),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onTitleChanged() {
    // Debounce rapid typing
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 600), () {
      _checkDuplicateProductName(_titleController.text);
    });
  }

  // Methods to clear validation errors when fields become valid
  void _clearTitleErrorIfValid() {
    if (_titleError != null) {
      final value = _titleController.text.trim();
      if (value.length >= 2 && !_isDuplicateName) {
        setState(() => _titleError = null);
      }
    }
  }

  void _clearDesignCodeErrorIfValid() {
    if (_designCodeError != null) {
      final value = _designCodeController.text.trim();
      if (value.isNotEmpty) {
        setState(() => _designCodeError = null);
      }
    }
  }

  void _clearSalePriceErrorIfValid() {
    if (_salePriceError != null) {
      final value = _salePriceController.text.trim();
      if (value.isNotEmpty) {
        final price = double.tryParse(value);
        if (price != null && price > 0) {
          setState(() => _salePriceError = null);
        }
      }
    }
  }

  Future<void> _checkDuplicateProductName(String name) async {
    final query = name.trim();
    if (query.isEmpty) {
      if (_isDuplicateName) {
        setState(() => _isDuplicateName = false);
      }
      return;
    }

    // start check (no UI busy indicator for now)
    try {
      // Fetch products (uses typed ProductResponse)
      final resp = await InventoryService.getProducts(page: 1, limit: 1000);
      final items = resp.data; // List<Product>

      final lowered = query.toLowerCase();
      final found = items.any((p) {
        final title = p.title;
        return title.trim().toLowerCase() == lowered;
      });

      if (mounted) {
        setState(() => _isDuplicateName = found);
        // Trigger form validation so the field shows the error immediately
        _formKey.currentState?.validate();
      }
    } catch (e) {
      // On error, don't block submission; assume unique
      print('❌ Error checking duplicate product name: $e');
      if (mounted) setState(() => _isDuplicateName = false);
    } finally {
      // finished check
    }
  }

  void _generateQrCode() {
    if (_titleController.text.isEmpty || _designCodeController.text.isEmpty) {
      return;
    }

    // Get selected vendor details
    vendor.Vendor? selectedVendor;
    if (_selectedVendorId != null) {
      try {
        selectedVendor = vendors.firstWhere((v) => v.id == _selectedVendorId);
      } catch (e) {
        // Vendor not found
      }
    }

    // Get selected category details
    Category? selectedCategory;
    if (_selectedCategoryId != null) {
      try {
        selectedCategory = categories.firstWhere(
          (c) => c.id == _selectedCategoryId,
        );
      } catch (e) {
        // Category not found
      }
    }

    // Get selected variants (now multiple)
    List<sizeModel.Size> selectedSizes = [];
    List<colorModel.Color> selectedColors = [];
    List<materialModel.Material> selectedMaterials = [];

    if (_selectedSizeIds.isNotEmpty) {
      try {
        selectedSizes = sizes
            .where((s) => _selectedSizeIds.contains(s.id))
            .toList();
      } catch (e) {}
    }
    if (_selectedColorIds.isNotEmpty) {
      try {
        selectedColors = colors
            .where((c) => _selectedColorIds.contains(c.id))
            .toList();
      } catch (e) {}
    }
    if (_selectedMaterialIds.isNotEmpty) {
      try {
        selectedMaterials = materials
            .where((m) => _selectedMaterialIds.contains(m.id))
            .toList();
      } catch (e) {}
    }

    // Create comprehensive QR code data
    final qrData = {
      'vendor_info': selectedVendor != null
          ? {
              'id': selectedVendor.id,
              'name': selectedVendor.fullName,
              'code': selectedVendor.vendorCode,
              'cnic': selectedVendor.cnic,
              'address': selectedVendor.address,
              'city': selectedVendor.city.title,
            }
          : null,
      'vendor_barcode': selectedVendor?.vendorCode ?? '',
      'our_barcode': _barcodeController.text,
      'data_entry_date': DateTime.now().toIso8601String(),
      'buying_price': _buyingPriceController.text,
      'selling_price': _salePriceController.text,
      'product_name': _titleController.text,
      'category': selectedCategory?.title ?? '',
      'sizes': selectedSizes.map((s) => s.title).join(', '),
      'colors': selectedColors.map((c) => c.title).join(', '),
      'materials': selectedMaterials.map((m) => m.title).join(', '),
      'quantity': _openingStockQuantityController.text,
      'design_code': _designCodeController.text,
      'status': _selectedStatus,
    };

    _qrCodeData = jsonEncode(qrData);
    setState(() {});

    // Save QR code as image file
    _saveQrCodeAsImage();
  }

  Future<void> _saveQrCodeAsImage() async {
    try {
      final directory = Directory(
        '${Directory.current.path}/assets/images/products',
      );
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }

      final fileName =
          'qr_${_designCodeController.text}_${DateTime.now().millisecondsSinceEpoch}.png';
      final filePath = '${directory.path}/$fileName';

      // Create QR code image data
      final qrPainter = QrPainter(
        data: _qrCodeData!,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        color: const Color(0xFF000000),
        emptyColor: const Color(0xFFFFFFFF),
      );

      final picData = await qrPainter.toImageData(200);
      if (picData != null) {
        final buffer = picData.buffer.asUint8List();
        final file = File(filePath);
        await file.writeAsBytes(buffer);

        // Store QR code image path
        _qrCodeImagePath =
            'https://zafarcomputers.com/assets/images/products/$fileName';
        print('✅ QR Code saved: $_qrCodeImagePath');
      }
    } catch (e) {
      print('❌ Error saving QR code: $e');
    }
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

  Future<void> _fetchVendors() async {
    try {
      print('🏪 ADD PRODUCT: Fetching all vendors for dropdown');

      // Fetch all vendors from all pages (like vendors page does)
      List<vendor.Vendor> allVendors = [];
      int currentFetchPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        final vendorResponse = await InventoryService.getVendors(
          page: currentFetchPage,
          limit: 50, // Use larger page size for efficiency
        );

        allVendors.addAll(vendorResponse.data);

        // Check if there are more pages
        if (vendorResponse.meta.currentPage >= vendorResponse.meta.lastPage) {
          hasMorePages = false;
        } else {
          currentFetchPage++;
        }

        print(
          '📄 Fetched page $currentFetchPage, total vendors so far: ${allVendors.length}',
        );
      }

      print('✅ ADD PRODUCT: Fetched ${allVendors.length} total vendors');
      setState(() {
        vendors = allVendors;
      });
    } catch (e) {
      print('❌ ADD PRODUCT: Error fetching vendors: $e');
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load categories: $e'),
          backgroundColor: Color(0xFFDC3545),
        ),
      );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load sub categories: $e'),
          backgroundColor: Color(0xFFDC3545),
        ),
      );
    }
  }

  Future<void> _submitForm() async {
    print('🔄 _submitForm called - starting product creation');

    // Manual validation for required fields
    String? titleError;
    String? salePriceError;

    final title = _titleController.text.trim();
    // Title is optional; if provided, validate length and uniqueness.
    if (title.isNotEmpty) {
      if (title.length < 2) {
        titleError = 'Product name must be at least 2 characters';
      } else if (_isDuplicateName) {
        titleError = 'A product with this name already exists';
      }
    }

    final salePrice = _salePriceController.text.trim();
    // Sale price is optional; if provided, it must be a valid positive number.
    if (salePrice.isNotEmpty) {
      final price = double.tryParse(salePrice);
      if (price == null || price <= 0) {
        salePriceError = 'Please enter a valid sale price';
      }
    }

    // Set validation errors
    setState(() {
      _titleError = titleError;
      _salePriceError = salePriceError;
    });

    // Check if there are any validation errors
    if (titleError != null || salePriceError != null) {
      print('❌ Form validation failed');
      return;
    }

    print('✅ Form validation passed');
    print('📊 Form data summary:');
    print('  - Title: "${_titleController.text}"');
    print('  - Design Code: "${_designCodeController.text}"');
    print('  - Category ID: $_selectedCategoryId');
    print('  - Sub Category ID: $_selectedSubCategoryId');
    print('  - Vendor ID: $_selectedVendorId');
    print('  - Sale Price: "${_salePriceController.text}"');
    print('  - Buying Price: "${_buyingPriceController.text}"');
    print('  - Opening Stock: "${_openingStockQuantityController.text}"');
    print('  - Barcode: "${_barcodeController.text}"');
    print('  - Status: $_selectedStatus');
    setState(() => isSubmitting = true);

    try {
      print('📦 Preparing product data...');

      // First, create product with placeholder image path
      final productData = {
        'title': _titleController.text,
        'design_code': _designCodeController.text,
        'image_path':
            'https://zafarcomputers/assets/images/products/placeholder', // Placeholder, will be updated after creation
        'sub_category_id': _selectedSubCategoryId,
        'sale_price': double.parse(_salePriceController.text),
        'buying_price': double.tryParse(_buyingPriceController.text) ?? 0,
        'opening_stock_quantity': int.parse(
          _openingStockQuantityController.text,
        ),
        'stock_in_quantity': int.parse(_openingStockQuantityController.text),
        'stock_out_quantity': 0,
        'in_stock_quantity': int.parse(_openingStockQuantityController.text),
        'vendor_id': _selectedVendorId,
        'user_id': 1,
        'barcode': _barcodeController.text,
        'qr_code_data': _qrCodeData, // Add QR code data
        'status': _selectedStatus,
        // Variant data - now arrays
        'sizes': _selectedSizeIds,
        'colors': _selectedColorIds,
        'materials': _selectedMaterialIds,
        'seasons': _selectedSeasonIds,
      };

      print('📤 Product data prepared: $productData');
      print('🚀 Calling InventoryService.createProduct...');

      final response = await InventoryService.createProduct(productData);
      print('✅ Product creation response: $response');

      // Extract product ID from response
      final productId = response['data']['product_id'];
      print('🆔 Product created with ID: $productId');

      // Note: Skipping image path update since images are stored locally
      // and will be loaded from the local directory in the product list

      print('✅ Product created successfully');

      // Show success dialog with options and get user choice
      // Note: Callback will be triggered from dialog button handlers
      bool shouldClearForm = await _showSuccessDialog();

      // Clear form only if user chose to go to product page
      if (shouldClearForm) {
        _clearForm();
      }
    } catch (e) {
      print('❌ Error in _submitForm: $e');
      String errorMessage = 'Failed to add product';

      // Parse error message from API response
      final errorString = e.toString();
      if (errorString.contains('Inventory API failed:')) {
        try {
          // Extract JSON from error message
          final jsonStart = errorString.indexOf('{');
          if (jsonStart != -1) {
            final jsonString = errorString.substring(jsonStart);
            final errorData = jsonDecode(jsonString);

            // Get the message field
            if (errorData.containsKey('message')) {
              errorMessage = errorData['message'];
            }

            // Handle specific field errors
            if (errorData.containsKey('errors')) {
              final errors = errorData['errors'] as Map<String, dynamic>;

              // Check for title error
              if (errors.containsKey('title')) {
                errorMessage = errors['title'][0];
              }
              // Check for variant/attribute errors
              else if (errors.containsKey('sizes')) {
                errorMessage = 'Invalid size selection: ${errors['sizes'][0]}';
              } else if (errors.containsKey('colors')) {
                errorMessage =
                    'Invalid color selection: ${errors['colors'][0]}';
              } else if (errors.containsKey('materials')) {
                errorMessage =
                    'Invalid material selection: ${errors['materials'][0]}';
              } else if (errors.containsKey('seasons')) {
                errorMessage =
                    'Invalid season selection: ${errors['seasons'][0]}';
              } else if (errors.containsKey('sub_category_id')) {
                errorMessage =
                    'Invalid sub category selection. Please select a valid sub category.';
              } else if (errors.containsKey('vendor_id')) {
                errorMessage =
                    'Invalid vendor selection. Please select a valid vendor.';
              }
            }
          }
        } catch (parseError) {
          print('Failed to parse error JSON: $parseError');
          // Keep default error message
        }
      }

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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => isSubmitting = false);
    }
  }

  Future<bool> _showSuccessDialog() async {
    final pageContext = context; // Save reference to page context
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext dialogContext) {
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
                    // Success Icon and Title
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF28A745).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(50),
                      ),
                      child: const Icon(
                        Icons.check_circle,
                        color: Color(0xFF28A745),
                        size: 48,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Product Created Successfully!',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'What would you like to do next?',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),

                    // Action Buttons
                    Column(
                      children: [
                        // Print Barcode Button
                        if (_barcodeController.text.isNotEmpty)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.of(
                                  dialogContext,
                                ).pop(false); // Don't clear form yet
                                await _printBarcode();
                                // Trigger refresh after printing
                                print(
                                  '🔄 AddProductPage: Print Barcode completed, calling onProductAdded callback',
                                );
                                if (widget.onProductAdded != null) {
                                  widget.onProductAdded!();
                                  print(
                                    '✅ AddProductPage: onProductAdded callback called after barcode print',
                                  );
                                }
                              },
                              icon: const Icon(Icons.qr_code_scanner, size: 18),
                              label: const Text('Print Barcode'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF17A2B8),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),

                        // Print QR Code Button
                        if (_qrCodeData != null)
                          Container(
                            width: double.infinity,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                Navigator.of(
                                  dialogContext,
                                ).pop(false); // Don't clear form yet
                                await _printQrCode();
                                // Trigger refresh after printing
                                widget.onProductAdded?.call();
                              },
                              icon: const Icon(Icons.qr_code, size: 18),
                              label: const Text('Print QR Code'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF6F42C1),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),

                        // Go to Product Page Button
                        Container(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              print(
                                '🔄 AddProductPage: "Go to Product Page" clicked, calling onProductAdded callback',
                              );
                              // First, close the success dialog
                              Navigator.of(dialogContext).pop(
                                true,
                              ); // Close dialog, returns true to clear form

                              // Trigger refresh in the product list
                              if (widget.onProductAdded != null) {
                                print(
                                  '⏳ AddProductPage: Calling onProductAdded callback',
                                );
                                widget.onProductAdded!();
                                print(
                                  '✅ AddProductPage: onProductAdded callback called',
                                );
                              } else {
                                print(
                                  '⚠️ AddProductPage: onProductAdded callback is null',
                                );
                              }

                              // Wait a bit to ensure refresh starts before navigation
                              await Future.delayed(
                                const Duration(milliseconds: 200),
                              );

                              // Now navigate back to product list page using page context
                              Navigator.of(pageContext).pop();
                            },
                            icon: const Icon(Icons.inventory, size: 18),
                            label: const Text('Go to Product Page'),
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

                    const SizedBox(height: 16),

                    // Close Button
                    TextButton(
                      onPressed: () {
                        print(
                          '🔄 AddProductPage: "Stay Here" clicked - clearing form and staying on add product page',
                        );
                        // Close dialog and clear form (return true to clear form)
                        Navigator.of(dialogContext).pop(true);
                      },
                      child: Text(
                        'Stay Here',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ) ??
        false; // Default to false if dialog is dismissed
  }

  void _clearForm() {
    _titleController.clear();
    _designCodeController.clear();
    _salePriceController.clear();
    _buyingPriceController.clear();
    _openingStockQuantityController.clear();
    _barcodeController.clear();
    _qrCodeController.clear();

    setState(() {
      _selectedStatus = 'Active';
      _selectedVendorId = null;
      _selectedCategoryId = null;
      _selectedSubCategoryId = null;
      _selectedSizeIds.clear();
      _selectedColorIds.clear();
      _selectedMaterialIds.clear();
      _selectedSeasonIds.clear();
      _qrCodeData = null;
      _qrCodeImagePath = null;
      // Clear validation errors
      _titleError = null;
      _designCodeError = null;
      _salePriceError = null;
      subCategories = []; // Clear sub categories when category is cleared
    });
  }

  // Returns true if there are unsaved changes on the form
  bool _hasUnsavedChanges() {
    if (_titleController.text.trim().isNotEmpty) return true;
    if (_designCodeController.text.trim().isNotEmpty) return true;
    if (_salePriceController.text.trim().isNotEmpty) return true;
    if (_buyingPriceController.text.trim().isNotEmpty) return true;
    if (_openingStockQuantityController.text.trim().isNotEmpty) return true;
    if (_barcodeController.text.trim().isNotEmpty) return true;
    if (_qrCodeController.text.trim().isNotEmpty) return true;
    if (_selectedVendorId != null) return true;
    if (_selectedCategoryId != null) return true;
    if (_selectedSubCategoryId != null) return true;
    if (_selectedSizeIds.isNotEmpty) return true;
    if (_selectedColorIds.isNotEmpty) return true;
    if (_selectedMaterialIds.isNotEmpty) return true;
    if (_selectedSeasonIds.isNotEmpty) return true;
    if (_selectedStatus != 'Active') return true;
    return false;
  }

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
                child: const Icon(
                  Icons.add_circle_outline,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Create Product',
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
}
