import 'package:flutter/material.dart';
import '../../services/inventory_service.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';

class AddCategoryPage extends StatefulWidget {
  const AddCategoryPage({super.key});

  @override
  State<AddCategoryPage> createState() => _AddCategoryPageState();

  // Static method to show the dialog
  static Future<bool?> show(BuildContext context) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AddCategoryPage();
      },
    );
  }
}

class _AddCategoryPageState extends State<AddCategoryPage>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _categoryCodeController = TextEditingController();

  String _selectedStatus = 'active';
  bool _isCreating = false;

  late AnimationController _submitAnimation;

  @override
  void initState() {
    super.initState();
    _submitAnimation = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
      lowerBound: 0.95,
      upperBound: 1.0,
    );
    // Add listener to auto-generate category code when title changes
    _titleController.addListener(_generateCategoryCode);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _categoryCodeController.dispose();
    _submitAnimation.dispose();
    super.dispose();
  }

  // Generate category code based on title (temporary until we have ID)
  void _generateCategoryCode() {
    // For new categories, don't generate code until we have the actual ID
    // The code will be set after creation with the proper C001 format
    _categoryCodeController.clear();
  }

  Future<void> _createCategory() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isCreating = true);

    try {
      final createData = {
        'title': _titleController.text.trim(),
        'category_code': _categoryCodeController.text.trim(),
        'img_path': '',
        'status': _selectedStatus,
      };

      final response = await InventoryService.createCategory(createData);

      // If the response contains the created category data with ID, update the code
      if (response.containsKey('data') &&
          response['data'] is Map<String, dynamic>) {
        final categoryData = response['data'] as Map<String, dynamic>;
        if (categoryData.containsKey('id')) {
          final categoryId = categoryData['id'] as int;
          final paddedId = categoryId.toString().padLeft(3, '0');
          final properCode = 'C$paddedId';

          // Update the category with the proper code
          await InventoryService.updateCategory(categoryId, {
            'title': _titleController.text.trim(),
            'category_code': properCode,
            'img_path': '',
            'status': _selectedStatus,
          });
        }
      }

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Category created successfully'),
            ],
          ),
          backgroundColor: Color(0xFF28A745),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );

      // Force refresh categories in provider
      final inventoryProvider = Provider.of<InventoryProvider>(
        context,
        listen: false,
      );
      await inventoryProvider.refreshCategories();

      // Navigate back to category list
      Navigator.of(context).pop(true); // Return true to indicate success
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error, color: Colors.white),
              SizedBox(width: 8),
              Expanded(child: Text('Failed to create category: $e')),
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

  // Category Information Section
  Widget _buildCategoryInformationSection(ThemeData theme) {
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
                  'Category Information',
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
                // First Row: Title and Category Code
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Title
                    Expanded(
                      flex: 2,
                      child: Container(
                        margin: const EdgeInsets.only(
                          right: 12,
                        ), // Increased margin
                        child: TextFormField(
                          controller: _titleController,
                          decoration: _buildCleanInputDecoration(
                            'Category Title',
                            isRequired: true,
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Category title is required';
                            }
                            return null;
                          },
                        ),
                      ),
                    ),

                    // Category Code
                    Expanded(
                      flex: 1,
                      child: Container(
                        margin: const EdgeInsets.only(
                          left: 12,
                        ), // Increased margin
                        child: TextFormField(
                          controller: _categoryCodeController,
                          readOnly: true,
                          decoration: _buildCleanInputDecoration(
                            'Category Code (Auto-generated)',
                            hint: 'Auto Generated',
                          ),
                          style: theme.textTheme.bodyLarge?.copyWith(
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20), // Increased spacing
                // Second Row: Status (Full Width)
                Column(
                  children: [
                    // Status Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedStatus,
                      decoration: _buildCleanDropdownDecoration(
                        'Status',
                        isRequired: true,
                      ),
                      style: theme.textTheme.bodyLarge?.copyWith(fontSize: 14),
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
                  onPressed: _isCreating ? null : _createCategory,
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
                              'Create Category',
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
                    'Add Category',
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
                        // Category Information Section
                        _buildCategoryInformationSection(theme),

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
