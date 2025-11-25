import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/inventory_service.dart';
import '../../models/category.dart';

class AddSubCategoryPage extends StatefulWidget {
  const AddSubCategoryPage({super.key});

  @override
  State<AddSubCategoryPage> createState() => _AddSubCategoryPageState();

  // Static method to show the dialog
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AddSubCategoryPage();
      },
    );
  }
}

class _AddSubCategoryPageState extends State<AddSubCategoryPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();

  String _selectedStatus = 'active';
  int? _selectedCategoryId;
  bool _isCreating = false;
  List<Category> _categories = [];
  List<Category> _filteredCategories = [];
  bool _isCategoryDropdownExpanded = false;
  final TextEditingController _categorySearchController =
      TextEditingController();

  late AnimationController _submitAnimation;

  @override
  void initState() {
    super.initState();
    _fetchCategories();
    _submitAnimation = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      lowerBound: 0.95,
      upperBound: 1.0,
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categorySearchController.dispose();
    _submitAnimation.dispose();
    super.dispose();
  }

  Future<void> _fetchCategories() async {
    try {
      // Fetch all categories by paginating through all pages
      List<Category> allCategories = [];
      int currentPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        final response = await InventoryService.getCategories(
          page: currentPage,
          limit: 100,
        );
        allCategories.addAll(response.data);

        // Check if there are more pages
        if (response.meta.currentPage >= response.meta.lastPage) {
          hasMorePages = false;
        } else {
          currentPage++;
        }
      }

      setState(() {
        _categories = allCategories;
        _filteredCategories = List.from(_categories);
      });
    } catch (e) {
      // Handle error silently for categories
      _categories = [];
      _filteredCategories = [];
    }
  }

  void _filterCategories(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCategories = List.from(_categories);
      } else {
        _filteredCategories = _categories.where((category) {
          final title = category.title.toLowerCase();
          final searchQuery = query.toLowerCase();
          return title.contains(searchQuery);
        }).toList();
      }
    });
  }

  void _toggleCategoryDropdown() {
    setState(() {
      _isCategoryDropdownExpanded = !_isCategoryDropdownExpanded;
      if (_isCategoryDropdownExpanded) {
        _categorySearchController.clear();
        _filteredCategories = List.from(_categories);
      }
    });
  }

  void _selectCategory(Category category) {
    setState(() {
      _selectedCategoryId = category.id;
      _isCategoryDropdownExpanded = false;
      _categorySearchController.clear();
    });
  }

  Future<void> _createSubCategory() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Additional validation for button-style fields
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a parent category'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isCreating = true);

    try {
      // Create subcategory
      final createData = {
        'title': _titleController.text.trim(),
        'category_id': _selectedCategoryId,
        'status': _selectedStatus,
      };

      await InventoryService.createSubCategory(createData);

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Sub category created successfully'),
            ],
          ),
          backgroundColor: Color(0xFF28A745),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      // Navigate back to sub category list
      Navigator.of(context).pop(true); // Return true to indicate success
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Failed to create sub category: $e')),
            ],
          ),
          backgroundColor: Color(0xFFDC3545),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isCreating = false);
      }
    }
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

  // Subcategory Information Section
  Widget _buildSubcategoryInformationSection(ThemeData theme) {
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
                  'Subcategory Information',
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
            padding: const EdgeInsets.all(
              20,
            ), // Increased padding for taller card
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center, // Center content vertically
              children: [
                // First Row: Title and Status
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Sub Category Title
                    Expanded(
                      flex: 2,
                      child: Container(
                        margin: const EdgeInsets.only(
                          right: 12,
                        ), // Increased margin
                        child: TextFormField(
                          controller: _titleController,
                          decoration: _buildCleanInputDecoration(
                            'Sub Category Title',
                            isRequired: true,
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Sub category title is required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),

                    // Status
                    Expanded(
                      flex: 1,
                      child: Container(
                        margin: const EdgeInsets.only(
                          left: 12,
                        ), // Increased margin
                        child: DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: _buildCleanDropdownDecoration(
                            'Status',
                            isRequired: true,
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                          ),
                          items: ['active', 'inactive'].map((status) {
                            return DropdownMenuItem<String>(
                              value: status,
                              child: Text(
                                status.toUpperCase(),
                                style: TextStyle(
                                  color: status == 'active'
                                      ? Colors.green
                                      : Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (value) {
                            if (value != null) {
                              setState(() => _selectedStatus = value);
                            }
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a status';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20), // Increased spacing
                // Second Row: Parent Category (Full Width)
                Column(
                  children: [
                    // Dropdown Button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey.shade300),
                      ),
                      child: OutlinedButton(
                        onPressed: _toggleCategoryDropdown,
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
                                        _categories.isNotEmpty
                                    ? (() {
                                        try {
                                          final selectedCategory = _categories
                                              .firstWhere(
                                                (c) =>
                                                    c.id == _selectedCategoryId,
                                              );
                                          return selectedCategory.title;
                                        } catch (e) {
                                          return 'Select Parent Category *';
                                        }
                                      })()
                                    : 'Select Parent Category *',
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
                              _isCategoryDropdownExpanded
                                  ? Icons.arrow_drop_up
                                  : Icons.arrow_drop_down,
                              color: Colors.grey.shade600,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expandable Search and List
                    if (_isCategoryDropdownExpanded)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              blurRadius: 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Search Field
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: TextField(
                                controller: _categorySearchController,
                                decoration: InputDecoration(
                                  hintText: 'Search categories...',
                                  prefixIcon: const Icon(
                                    Icons.search,
                                    color: Color(0xFF0D1845),
                                    size: 20,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: BorderSide(
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(6),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF0D1845),
                                      width: 2,
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 10,
                                  ),
                                ),
                                style: const TextStyle(fontSize: 14),
                                onChanged: _filterCategories,
                              ),
                            ),

                            // Category List
                            Container(
                              constraints: const BoxConstraints(maxHeight: 200),
                              child: _filteredCategories.isEmpty
                                  ? Padding(
                                      padding: const EdgeInsets.all(24),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            Icons.search_off,
                                            size: 32,
                                            color: Colors.grey.shade400,
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'No categories found',
                                            style: TextStyle(
                                              color: Colors.grey.shade600,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : ListView.builder(
                                      shrinkWrap: true,
                                      itemCount: _filteredCategories.length,
                                      itemBuilder: (context, index) {
                                        final category =
                                            _filteredCategories[index];
                                        final isSelected =
                                            category.id == _selectedCategoryId;

                                        return InkWell(
                                          onTap: () =>
                                              _selectCategory(category),
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
                                                      _filteredCategories
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
                                                  child: Text(
                                                    category.title,
                                                    style: TextStyle(
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: isSelected
                                                          ? const Color(
                                                              0xFF0D1845,
                                                            )
                                                          : Colors.black87,
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ),
                                                if (isSelected)
                                                  const Icon(
                                                    Icons.check_circle,
                                                    color: Color(0xFF0D1845),
                                                    size: 18,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
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
                  gradient: _isCreating
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
                  boxShadow: _isCreating
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
                  onPressed: _isCreating ? null : _createSubCategory,
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
                  child: _isCreating
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
                              'Create Sub Category',
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.of(context).size.width;
    final isWideScreen = screenWidth > 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: isWideScreen ? 600 : screenWidth * 0.95,
        constraints: const BoxConstraints(maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1845),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
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
                    'Add Sub Category',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(false),
                    tooltip: 'Close',
                  ),
                ],
              ),
            ),

            // Body
            Flexible(
              child: Container(
                color: const Color(0xFFF8F9FA),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Subcategory Information Section
                        _buildSubcategoryInformationSection(theme),

                        const SizedBox(height: 20),

                        // Submit Button
                        _buildSubmitSection(theme),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
