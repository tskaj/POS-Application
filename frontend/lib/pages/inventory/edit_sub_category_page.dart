import 'package:flutter/material.dart';
import 'dart:async';
import '../../services/inventory_service.dart';
import '../../models/sub_category.dart';
import '../../models/category.dart';

class EditSubCategoryPage extends StatefulWidget {
  final SubCategory subCategory;

  const EditSubCategoryPage({super.key, required this.subCategory});

  @override
  State<EditSubCategoryPage> createState() => _EditSubCategoryPageState();

  // Static method to show the dialog
  static Future<bool?> show(BuildContext context, SubCategory subCategory) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return EditSubCategoryPage(subCategory: subCategory);
      },
    );
  }
}

class _EditSubCategoryPageState extends State<EditSubCategoryPage> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  int? _selectedCategoryId;
  String _selectedStatus = 'active';
  bool _isLoading = false;
  bool _isSubmitting = false;

  List<Category> _categories = [];
  List<Category> _filteredCategories = [];
  bool _isCategoryDropdownExpanded = false;
  final TextEditingController _categorySearchController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeData();
    _fetchCategories();
  }

  void _initializeData() {
    _titleController = TextEditingController(text: widget.subCategory.title);
    _selectedCategoryId = widget.subCategory.categoryId;
    _selectedStatus = widget.subCategory.status;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categorySearchController.dispose();
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

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final updateData = {
        'title': _titleController.text.trim(),
        'category_id': _selectedCategoryId,
        'status': _selectedStatus.toLowerCase(),
      };

      final response = await InventoryService.updateSubCategory(
        widget.subCategory.id,
        updateData,
      );

      if (mounted) {
        // Check if the response indicates success
        if (response['status'] == true) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.white),
                  SizedBox(width: 8),
                  Text(
                    response['message'] ?? 'Sub category updated successfully',
                  ),
                ],
              ),
              backgroundColor: Color(0xFF28A745),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
          Navigator.of(context).pop(true); // Return true to indicate success
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  Icon(Icons.error, color: Colors.white),
                  SizedBox(width: 8),
                  Text(response['message'] ?? 'Failed to update sub category'),
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error, color: Colors.white),
                SizedBox(width: 8),
                Text('Failed to update sub category: ${e.toString()}'),
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
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
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
                      Icons.edit,
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
                          'Edit Sub Category',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Update details for "${widget.subCategory.title}"',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  if (_isSubmitting)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  else
                    TextButton(
                      onPressed: _submitForm,
                      child: const Text(
                        'Update',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
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
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Color(0xFF0D1845),
                          ),
                        ),
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Form Fields
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: Colors.grey.shade200,
                                  ),
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
                                    // Title Field
                                    TextFormField(
                                      controller: _titleController,
                                      decoration: InputDecoration(
                                        labelText: 'Sub Category Title *',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                        prefixIcon: const Icon(Icons.title),
                                      ),
                                      validator: (value) {
                                        if (value == null ||
                                            value.trim().isEmpty) {
                                          return 'Please enter a sub category title';
                                        }
                                        return null;
                                      },
                                    ),

                                    const SizedBox(height: 20),

                                    // Category Dropdown
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        // Dropdown Button
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              8,
                                            ),
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                          child: OutlinedButton(
                                            onPressed: _toggleCategoryDropdown,
                                            style: OutlinedButton.styleFrom(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 16,
                                                  ),
                                              backgroundColor: Colors.white,
                                              side: BorderSide.none,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              alignment: Alignment.centerLeft,
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  Icons.category,
                                                  color: Colors.grey.shade600,
                                                ),
                                                const SizedBox(width: 12),
                                                Expanded(
                                                  child: Text(
                                                    _selectedCategoryId !=
                                                                null &&
                                                            _categories
                                                                .isNotEmpty
                                                        ? _categories
                                                              .firstWhere(
                                                                (cat) =>
                                                                    cat.id ==
                                                                    _selectedCategoryId,
                                                                orElse: () => Category(
                                                                  id: 0,
                                                                  title:
                                                                      'Unknown Category',
                                                                  status:
                                                                      'active',
                                                                  imgPath: null,
                                                                  createdAt: '',
                                                                  updatedAt: '',
                                                                ),
                                                              )
                                                              .title
                                                        : 'Select Parent Category *',
                                                    style: TextStyle(
                                                      color:
                                                          _selectedCategoryId !=
                                                              null
                                                          ? Colors.black87
                                                          : Colors.grey[700],
                                                      fontSize: 14,
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
                                            margin: const EdgeInsets.only(
                                              top: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              border: Border.all(
                                                color: Colors.grey.shade200,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.1),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 4),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              children: [
                                                // Search Field
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  child: TextField(
                                                    controller:
                                                        _categorySearchController,
                                                    decoration: InputDecoration(
                                                      hintText:
                                                          'Search categories...',
                                                      prefixIcon: const Icon(
                                                        Icons.search,
                                                        size: 20,
                                                      ),
                                                      border: OutlineInputBorder(
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        borderSide: BorderSide(
                                                          color: Colors
                                                              .grey
                                                              .shade300,
                                                        ),
                                                      ),
                                                      enabledBorder:
                                                          OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            borderSide:
                                                                BorderSide(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade300,
                                                                ),
                                                          ),
                                                      focusedBorder:
                                                          OutlineInputBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  8,
                                                                ),
                                                            borderSide:
                                                                const BorderSide(
                                                                  color: Color(
                                                                    0xFF0D1845,
                                                                  ),
                                                                  width: 2,
                                                                ),
                                                          ),
                                                      contentPadding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 16,
                                                            vertical: 12,
                                                          ),
                                                      filled: true,
                                                      fillColor:
                                                          Colors.grey.shade50,
                                                    ),
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                    ),
                                                    onChanged:
                                                        _filterCategories,
                                                  ),
                                                ),

                                                // Category List
                                                Container(
                                                  constraints:
                                                      const BoxConstraints(
                                                        maxHeight: 200,
                                                      ),
                                                  child:
                                                      _filteredCategories
                                                          .isEmpty
                                                      ? Padding(
                                                          padding:
                                                              const EdgeInsets.all(
                                                                16,
                                                              ),
                                                          child: Text(
                                                            'No categories found',
                                                            style: TextStyle(
                                                              color: Colors
                                                                  .grey
                                                                  .shade600,
                                                              fontSize: 14,
                                                            ),
                                                            textAlign: TextAlign
                                                                .center,
                                                          ),
                                                        )
                                                      : ListView.builder(
                                                          shrinkWrap: true,
                                                          itemCount:
                                                              _filteredCategories
                                                                  .length,
                                                          itemBuilder: (context, index) {
                                                            final category =
                                                                _filteredCategories[index];
                                                            final isSelected =
                                                                category.id ==
                                                                _selectedCategoryId;
                                                            return InkWell(
                                                              onTap: () =>
                                                                  _selectCategory(
                                                                    category,
                                                                  ),
                                                              child: Container(
                                                                padding:
                                                                    const EdgeInsets.symmetric(
                                                                      horizontal:
                                                                          16,
                                                                      vertical:
                                                                          12,
                                                                    ),
                                                                decoration: BoxDecoration(
                                                                  color:
                                                                      isSelected
                                                                      ? const Color(
                                                                          0xFF0D1845,
                                                                        ).withOpacity(
                                                                          0.1,
                                                                        )
                                                                      : Colors
                                                                            .transparent,
                                                                  border: Border(
                                                                    bottom: BorderSide(
                                                                      color:
                                                                          index <
                                                                              _filteredCategories.length -
                                                                                  1
                                                                          ? Colors.grey.shade200
                                                                          : Colors.transparent,
                                                                    ),
                                                                  ),
                                                                ),
                                                                child: Row(
                                                                  children: [
                                                                    Expanded(
                                                                      child: Text(
                                                                        category
                                                                            .title,
                                                                        style: TextStyle(
                                                                          color:
                                                                              isSelected
                                                                              ? const Color(
                                                                                  0xFF0D1845,
                                                                                )
                                                                              : Colors.black87,
                                                                          fontWeight:
                                                                              isSelected
                                                                              ? FontWeight.w600
                                                                              : FontWeight.w400,
                                                                          fontSize:
                                                                              14,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    if (isSelected)
                                                                      Icon(
                                                                        Icons
                                                                            .check,
                                                                        color: const Color(
                                                                          0xFF0D1845,
                                                                        ),
                                                                        size:
                                                                            18,
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

                                    const SizedBox(height: 20),

                                    // Status Dropdown
                                    DropdownButtonFormField<String>(
                                      value: _selectedStatus,
                                      decoration: InputDecoration(
                                        labelText: 'Status *',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 16,
                                            ),
                                        prefixIcon: const Icon(Icons.toggle_on),
                                      ),
                                      items: ['Active', 'Inactive']
                                          .map(
                                            (status) =>
                                                DropdownMenuItem<String>(
                                                  value: status,
                                                  child: Text(status),
                                                ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(
                                            () => _selectedStatus = value,
                                          );
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 20),

                              // Action Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _isSubmitting
                                          ? null
                                          : () => Navigator.of(
                                              context,
                                            ).pop(false),
                                      style: OutlinedButton.styleFrom(
                                        side: BorderSide(
                                          color: Color(0xFF6C757D),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                      ),
                                      child: const Text('Cancel'),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isSubmitting
                                          ? null
                                          : _submitForm,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Color(0xFF28A745),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                      ),
                                      child: _isSubmitting
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                valueColor:
                                                    AlwaysStoppedAnimation<
                                                      Color
                                                    >(Colors.white),
                                              ),
                                            )
                                          : const Text('Update Sub Category'),
                                    ),
                                  ),
                                ],
                              ),
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
