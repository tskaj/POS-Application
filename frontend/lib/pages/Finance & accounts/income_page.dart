import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../services/income_services.dart';
import 'add_payment_page.dart';

class IncomePage extends StatefulWidget {
  const IncomePage({super.key});

  @override
  State<IncomePage> createState() => _IncomePageState();
}

class _IncomePageState extends State<IncomePage> {
  // API data
  List<Income> _filteredIncomes = [];
  List<Income> _allFilteredIncomes = [];
  bool _isLoading = true;
  String? _errorMessage;
  int currentPage = 1;
  final int itemsPerPage = 10;

  // Filter states
  String _selectedCategory = 'All';

  @override
  void initState() {
    super.initState();
    _fetchAllIncomesOnInit();
  }

  // Fetch all incomes once when page loads
  Future<void> _fetchAllIncomesOnInit() async {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );

    // Check if incomes are already cached
    if (financeProvider.incomes.isNotEmpty) {
      // Apply initial filters
      _applyFiltersClientSide();
      return;
    }

    try {
      setState(() {
        _errorMessage = null;
      });

      final incomes = await IncomeService.getIncomes();
      financeProvider.setIncomes(incomes.data);

      // Apply initial filters
      _applyFiltersClientSide();
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load incomes. Please refresh the page.';
        _isLoading = false;
      });
    }
  }

  // Client-side only filter application
  void _applyFilters() {
    _applyFiltersClientSide();
  }

  // Pure client-side filtering method
  void _applyFiltersClientSide() {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );

    try {
      // Apply filters to cached incomes
      _allFilteredIncomes = financeProvider.incomes.where((income) {
        final incomeItem = income as Income;
        try {
          // Category filter
          if (_selectedCategory != 'All' &&
              incomeItem.incomeCategoryName != _selectedCategory) {
            return false;
          }

          return true;
        } catch (e) {
          return false;
        }
      }).toList();

      // Apply local pagination to filtered results
      _paginateFilteredIncomes();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search error: Please try a different search term';
        _isLoading = false;
        _filteredIncomes = [];
      });
    }
  }

  // Apply local pagination to filtered incomes
  void _paginateFilteredIncomes() {
    try {
      if (_allFilteredIncomes.isEmpty) {
        setState(() {
          _filteredIncomes = [];
        });
        return;
      }

      final startIndex = (currentPage - 1) * itemsPerPage;
      final endIndex = startIndex + itemsPerPage;

      if (startIndex >= _allFilteredIncomes.length) {
        setState(() {
          currentPage = 1;
        });
        _paginateFilteredIncomes();
        return;
      }

      setState(() {
        _filteredIncomes = _allFilteredIncomes.sublist(
          startIndex,
          endIndex > _allFilteredIncomes.length
              ? _allFilteredIncomes.length
              : endIndex,
        );
      });
    } catch (e) {
      setState(() {
        _filteredIncomes = [];
        currentPage = 1;
      });
    }
  }

  // Handle page changes
  Future<void> _changePage(int newPage) async {
    setState(() {
      currentPage = newPage;
    });
    _paginateFilteredIncomes();
  }

  // View income details
  Future<void> _viewIncomeDetails(int incomeId) async {
    bool isDialogLoading = true;
    Income? income;

    showDialog(
      context: context,
      barrierDismissible: false,
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
                  Icon(
                    Icons.receipt_long,
                    color: const Color(0xFF0D1845),
                    size: 28,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Income Details',
                    style: TextStyle(
                      color: const Color(0xFF0D1845),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              content: isDialogLoading
                  ? Container(
                      height: 100,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(
                              const Color(0xFF0D1845),
                            ),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'Loading income details...',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    )
                  : Container(
                      width: double.maxFinite,
                      constraints: BoxConstraints(maxWidth: 400),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Basic Information Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0D1845).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF0D1845).withOpacity(0.1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: const Color(0xFF0D1845),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Basic Information',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF0D1845),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildDetailRow('ID', income!.id.toString()),
                                const SizedBox(height: 8),
                                _buildDetailRow(
                                  'Category',
                                  income.incomeCategoryName,
                                ),
                                const SizedBox(height: 8),
                                _buildDetailRow(
                                  'Date',
                                  DateFormat(
                                    'dd MMM yyyy',
                                  ).format(DateTime.parse(income.date)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Financial Information Section
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50).withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF4CAF50).withOpacity(0.1),
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.attach_money,
                                      color: const Color(0xFF4CAF50),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Financial Details',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: const Color(0xFF4CAF50),
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                _buildDetailRow(
                                  'Amount',
                                  'Rs. ${income.amount.toStringAsFixed(2)}',
                                  valueColor: const Color(0xFF4CAF50),
                                  valueWeight: FontWeight.bold,
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          // Notes Section
                          if (income.notes.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF2196F3,
                                ).withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(
                                    0xFF2196F3,
                                  ).withOpacity(0.1),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.notes,
                                        color: const Color(0xFF2196F3),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'Notes',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: const Color(0xFF2196F3),
                                          fontSize: 16,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    income.notes,
                                    style: TextStyle(
                                      color: Colors.grey[700],
                                      fontSize: 14,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
              actions: isDialogLoading
                  ? null
                  : [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF0D1845),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                        child: const Text(
                          'Close',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
            );
          },
        );
      },
    );

    try {
      final response = await IncomeService.getIncomeById(incomeId);
      income = response.data;

      // Update dialog state
      setState(() {
        isDialogLoading = false;
      });
    } catch (e) {
      Navigator.of(context).pop(); // Close loading dialog
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load income details: $e')),
      );
    }
  }

  Future<void> _editIncome(Income income) async {
    final _formKey = GlobalKey<FormState>();
    final _incmCatNameController = TextEditingController(
      text: income.incomeCategoryName,
    );
    final _notesController = TextEditingController(text: income.notes);
    final _amountController = TextEditingController(
      text: income.amount.toString(),
    );

    DateTime _selectedDate = DateTime.parse(income.date);
    int? _selectedCategoryId = int.tryParse(income.incomeCategoryId);
    List<IncomeCategory> _categories = [];
    bool _isSubmitting = false;

    // Fetch categories for dropdown
    Future<void> _fetchCategories() async {
      try {
        final response = await IncomeService.getIncomeCategories();
        if (response.status) {
          _categories = response.data;
        } else {
          _categories = [];
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        _categories = [];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load categories: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }

    await _fetchCategories();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
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

              if (_selectedCategoryId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please select an income category'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }

              setState(() => _isSubmitting = true);

              try {
                final incomeData = {
                  'transaction_type_id': 8,
                  'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
                  'income_category_id': _selectedCategoryId,
                  'incm_cat_name': _incmCatNameController.text.trim(),
                  'notes': _notesController.text.trim(),
                  'amount': double.tryParse(_amountController.text) ?? 0.0,
                };

                final response = await IncomeService.updateIncome(
                  income.id,
                  incomeData,
                );

                if (response.status) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(response.message),
                      backgroundColor: Colors.green,
                    ),
                  );
                  Navigator.of(context).pop(); // Close dialog
                  _fetchAllIncomesOnInit(); // Refresh the list
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(response.message),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to update income: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setState(() => _isSubmitting = false);
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.edit, color: const Color(0xFFFFA726), size: 28),
                  const SizedBox(width: 12),
                  Text(
                    'Edit Income',
                    style: TextStyle(
                      color: const Color(0xFF0D1845),
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(maxWidth: 500, maxHeight: 600),
                child: Form(
                  key: _formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Income Category Name Field
                        TextFormField(
                          controller: _incmCatNameController,
                          decoration: InputDecoration(
                            labelText: 'Income Category Name *',
                            hintText: 'e.g., Monthly Software Service',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: Icon(
                              Icons.label,
                              color: Color(0xFF0D1845),
                            ),
                          ),
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter income category name';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Category and Date Row
                        Row(
                          children: [
                            Expanded(
                              child: _categories.isEmpty
                                  ? Center(child: CircularProgressIndicator())
                                  : DropdownButtonFormField<int>(
                                      value: _selectedCategoryId,
                                      decoration: InputDecoration(
                                        labelText: 'Income Category *',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.category,
                                          color: Color(0xFF0D1845),
                                        ),
                                      ),
                                      items: _categories.map((category) {
                                        return DropdownMenuItem<int>(
                                          value: category.id,
                                          child: Text(
                                            '${category.incomeCategory}',
                                            style: TextStyle(fontSize: 14),
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (value) {
                                        setState(() {
                                          _selectedCategoryId = value;
                                        });
                                      },
                                      validator: (value) {
                                        if (value == null) {
                                          return 'Please select a category';
                                        }
                                        return null;
                                      },
                                    ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: InkWell(
                                onTap: () => _selectDate(context),
                                child: InputDecorator(
                                  decoration: InputDecoration(
                                    labelText: 'Date *',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    prefixIcon: Icon(
                                      Icons.calendar_today,
                                      color: Color(0xFF0D1845),
                                    ),
                                  ),
                                  child: Text(
                                    DateFormat(
                                      'dd MMM yyyy',
                                    ).format(_selectedDate),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Amount Field
                        TextFormField(
                          controller: _amountController,
                          decoration: InputDecoration(
                            labelText: 'Amount (PKR) *',
                            hintText: 'e.g., 120000.00',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: Icon(
                              Icons.attach_money,
                              color: Color(0xFF0D1845),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter amount';
                            }
                            double? amount = double.tryParse(value);
                            if (amount == null || amount <= 0) {
                              return 'Please enter a valid amount greater than 0';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Notes Field
                        TextFormField(
                          controller: _notesController,
                          decoration: InputDecoration(
                            labelText: 'Notes',
                            hintText: 'Additional details about the income',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            prefixIcon: Icon(
                              Icons.description,
                              color: Color(0xFF0D1845),
                            ),
                          ),
                          maxLines: 3,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  style: TextButton.styleFrom(
                    foregroundColor: const Color(0xFF6C757D),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submitForm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFA726),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isSubmitting
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.save, size: 18),
                            const SizedBox(width: 8),
                            Text('Update Income'),
                          ],
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteIncome(Income income) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: const Color(0xFFDC3545), size: 28),
              const SizedBox(width: 12),
              Text(
                'Delete Income',
                style: TextStyle(
                  color: const Color(0xFFDC3545),
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to delete this income?',
                style: TextStyle(color: Colors.grey[700], fontSize: 16),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFDC3545).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFFDC3545).withOpacity(0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Income Details:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFDC3545),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('ID: ${income.id}'),
                    Text('Category: ${income.incomeCategoryName}'),
                    Text('Amount: Rs. ${income.amount.toStringAsFixed(2)}'),
                    Text(
                      'Date: ${DateFormat('dd MMM yyyy').format(DateTime.parse(income.date))}',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'This action cannot be undone.',
                style: TextStyle(
                  color: const Color(0xFFDC3545),
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey[600],
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text(
                'Cancel',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFDC3545),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.delete, size: 18),
                  const SizedBox(width: 8),
                  Text('Delete Income'),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {
        setState(() => _isLoading = true);

        final response = await IncomeService.deleteIncome(income.id);

        if (response.status) {
          // Update provider cache
          final financeProvider = Provider.of<FinanceProvider>(
            context,
            listen: false,
          );
          financeProvider.setIncomes(
            financeProvider.incomes
                .where((i) => (i as Income).id != income.id)
                .toList(),
          );

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.green,
            ),
          );
          // Refresh the incomes list
          _fetchAllIncomesOnInit();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete income: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  bool _canGoToNextPage() {
    final totalPages = _getTotalPages();
    return currentPage < totalPages;
  }

  int _getTotalPages() {
    if (_allFilteredIncomes.isEmpty) return 1;
    return (_allFilteredIncomes.length / itemsPerPage).ceil();
  }

  List<Widget> _buildPageButtons() {
    final totalPages = _getTotalPages();
    final current = currentPage;

    const maxButtons = 5;
    final halfRange = maxButtons ~/ 2;

    int startPage = (current - halfRange).clamp(1, totalPages);
    int endPage = (startPage + maxButtons - 1).clamp(1, totalPages);

    if (endPage > totalPages) {
      endPage = totalPages;
      startPage = (endPage - maxButtons + 1).clamp(1, totalPages);
    }

    List<Widget> buttons = [];

    for (int i = startPage; i <= endPage; i++) {
      buttons.add(
        Container(
          margin: EdgeInsets.symmetric(horizontal: 1),
          child: ElevatedButton(
            onPressed: i == current ? null : () => _changePage(i),
            style: ElevatedButton.styleFrom(
              backgroundColor: i == current ? Color(0xFF17A2B8) : Colors.white,
              foregroundColor: i == current ? Colors.white : Color(0xFF6C757D),
              elevation: i == current ? 2 : 0,
              side: i == current ? null : BorderSide(color: Color(0xFFDEE2E6)),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(5),
              ),
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: Size(32, 32),
            ),
            child: Text(
              i.toString(),
              style: TextStyle(fontWeight: FontWeight.w500, fontSize: 11),
            ),
          ),
        ),
      );
    }

    return buttons;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Incomes'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, const Color(0xFFF8F9FA)],
          ),
        ),
        child: Column(
          children: [
            // Header with Summary Cards
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
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.trending_up,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    'Income Management',
                                    style: TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final result = await Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const AddPaymentPage(),
                                      ),
                                    );
                                    if (result == true) {
                                      // Refresh the incomes list
                                      _fetchAllIncomesOnInit();
                                    }
                                  },
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Payment'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.white,
                                    foregroundColor: const Color(0xFF0D1845),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 2,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Track and manage all business incomes',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Summary Cards
                  Row(
                    children: [
                      Consumer<FinanceProvider>(
                        builder: (context, financeProvider, child) {
                          return _buildSummaryCard(
                            'Total Incomes',
                            '${financeProvider.incomes.length}',
                            Icons.receipt,
                            const Color(0xFF4CAF50),
                          );
                        },
                      ),
                      Consumer<FinanceProvider>(
                        builder: (context, financeProvider, child) {
                          return _buildSummaryCard(
                            'Total Amount',
                            'Rs. ${_getTotalIncomes(financeProvider.incomes).toStringAsFixed(2)}',
                            Icons.attach_money,
                            const Color(0xFF2196F3),
                          );
                        },
                      ),
                      Consumer<FinanceProvider>(
                        builder: (context, financeProvider, child) {
                          return _buildSummaryCard(
                            'This Month',
                            '${_getThisMonthIncomes(financeProvider.incomes)}',
                            Icons.calendar_today,
                            const Color(0xFF8BC34A),
                          );
                        },
                      ),
                      Consumer<FinanceProvider>(
                        builder: (context, financeProvider, child) {
                          return _buildSummaryCard(
                            'Avg. Income',
                            'Rs. ${_getAverageIncome(financeProvider.incomes).toStringAsFixed(2)}',
                            Icons.trending_up,
                            const Color(0xFFFF9800),
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Search and Table
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
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
                  children: [
                    // Filters Section
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          // Category Filter
                          Expanded(
                            flex: 2,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: 4,
                                    bottom: 6,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.category,
                                        size: 16,
                                        color: Color(0xFF0D1845),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Category',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF343A40),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Consumer<FinanceProvider>(
                                    builder: (context, financeProvider, child) {
                                      return DropdownButtonFormField<String>(
                                        value: _selectedCategory,
                                        decoration: InputDecoration(
                                          filled: true,
                                          fillColor: Colors.white,
                                          hintText: 'Select category',
                                          hintStyle: TextStyle(
                                            color: Color(0xFFADB5BD),
                                            fontSize: 14,
                                          ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: Color(0xFFDEE2E6),
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: Color(0xFFDEE2E6),
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            borderSide: BorderSide(
                                              color: Color(0xFF0D1845),
                                              width: 2,
                                            ),
                                          ),
                                          contentPadding: EdgeInsets.symmetric(
                                            horizontal: 16,
                                            vertical: 16,
                                          ),
                                        ),
                                        items:
                                            [
                                                  'All',
                                                  ...financeProvider.incomes
                                                      .map(
                                                        (
                                                          income,
                                                        ) => (income as Income)
                                                            .incomeCategoryName,
                                                      )
                                                      .toSet()
                                                      .toList(),
                                                ]
                                                .map(
                                                  (
                                                    category,
                                                  ) => DropdownMenuItem(
                                                    value: category,
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          category == 'All'
                                                              ? Icons
                                                                    .inventory_2_rounded
                                                              : Icons.category,
                                                          color:
                                                              category == 'All'
                                                              ? Color(
                                                                  0xFF6C757D,
                                                                )
                                                              : Color(
                                                                  0xFF0D1845,
                                                                ),
                                                          size: 18,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          category,
                                                          style: TextStyle(
                                                            color: Color(
                                                              0xFF343A40,
                                                            ),
                                                            fontSize: 14,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                )
                                                .toList(),
                                        onChanged: (value) {
                                          if (value != null) {
                                            setState(() {
                                              _selectedCategory = value;
                                              currentPage = 1;
                                            });
                                            _applyFilters();
                                          }
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 1,
                            child: Text('ID', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text('Date', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text('Category', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text('Amount', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 3,
                            child: Text('Notes', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text('Actions', style: _headerStyle()),
                          ),
                        ],
                      ),
                    ),

                    // Table Body
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(
                                    Icons.error_outline,
                                    size: 48,
                                    color: Colors.red,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: Colors.red,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  ElevatedButton(
                                    onPressed: _fetchAllIncomesOnInit,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _filteredIncomes.isEmpty
                          ? const Center(
                              child: Text(
                                'No incomes found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredIncomes.length,
                              itemBuilder: (context, index) {
                                final income = _filteredIncomes[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey[200]!,
                                        width: 1,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          income.id.toString(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF0D1845),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          DateFormat(
                                            'dd MMM yyyy',
                                          ).format(DateTime.parse(income.date)),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Color(
                                              0xFF0D1845,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            income.incomeCategoryName,
                                            style: TextStyle(
                                              color: Color(0xFF0D1845),
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Rs. ${income.amount.toStringAsFixed(2)}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF28A745),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 3,
                                        child: Text(
                                          income.notes,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.visibility,
                                                color: Color(0xFF17A2B8),
                                                size: 18,
                                              ),
                                              onPressed: () =>
                                                  _viewIncomeDetails(income.id),
                                              tooltip: 'View Details',
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.edit,
                                                color: Color(0xFFFFA726),
                                                size: 18,
                                              ),
                                              onPressed: () =>
                                                  _editIncome(income),
                                              tooltip: 'Edit',
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete,
                                                color: Color(0xFFDC3545),
                                                size: 18,
                                              ),
                                              onPressed: () =>
                                                  _deleteIncome(income),
                                              tooltip: 'Delete',
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    // Pagination Controls
                    Container(
                      padding: const EdgeInsets.symmetric(
                        vertical: 16,
                        horizontal: 24,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border(
                          top: BorderSide(
                            color: Colors.grey.shade200,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Previous button
                          ElevatedButton.icon(
                            onPressed: currentPage > 1
                                ? () {
                                    setState(() {
                                      currentPage--;
                                      _paginateFilteredIncomes();
                                    });
                                  }
                                : null,
                            icon: Icon(Icons.chevron_left, size: 14),
                            label: Text(
                              'Previous',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: currentPage > 1
                                  ? const Color(0xFF0D1845)
                                  : const Color(0xFF6C757D),
                              elevation: 0,
                              side: const BorderSide(color: Color(0xFFDEE2E6)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Page numbers
                          ..._buildPageButtons(),

                          const SizedBox(width: 8),

                          // Next button
                          ElevatedButton.icon(
                            onPressed: _canGoToNextPage()
                                ? () {
                                    setState(() {
                                      currentPage++;
                                      _paginateFilteredIncomes();
                                    });
                                  }
                                : null,
                            icon: Icon(Icons.chevron_right, size: 14),
                            label: Text('Next', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _canGoToNextPage()
                                  ? const Color(0xFF0D1845)
                                  : Colors.grey.shade300,
                              foregroundColor: _canGoToNextPage()
                                  ? Colors.white
                                  : Colors.grey.shade600,
                              elevation: _canGoToNextPage() ? 2 : 0,
                              side: _canGoToNextPage()
                                  ? null
                                  : const BorderSide(color: Color(0xFFDEE2E6)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                            ),
                          ),

                          // Page info
                          const SizedBox(width: 16),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Page $currentPage of ${_getTotalPages()} (${_allFilteredIncomes.length} total)',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6C757D),
                                fontWeight: FontWeight.w500,
                              ),
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
    );
  }

  double _getTotalIncomes(List<dynamic> incomes) {
    return incomes.fold(0.0, (sum, income) => sum + (income as Income).amount);
  }

  int _getThisMonthIncomes(List<dynamic> incomes) {
    final now = DateTime.now();
    final thisMonth = DateTime(now.year, now.month);
    return incomes.where((income) {
      final incomeItem = income as Income;
      try {
        final incomeDate = DateTime.parse(incomeItem.date);
        return incomeDate.year == thisMonth.year &&
            incomeDate.month == thisMonth.month;
      } catch (e) {
        return false;
      }
    }).length;
  }

  double _getAverageIncome(List<dynamic> incomes) {
    if (incomes.isEmpty) return 0.0;
    return _getTotalIncomes(incomes) / incomes.length;
  }

  TextStyle _headerStyle() {
    return const TextStyle(
      fontWeight: FontWeight.w600,
      color: Color(0xFF343A40),
      fontSize: 13,
    );
  }

  Widget _buildSummaryCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: Colors.white, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(
    String label,
    String value, {
    Color? valueColor,
    FontWeight? valueWeight,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            '$label:',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: valueColor ?? Colors.grey[800],
              fontWeight: valueWeight ?? FontWeight.normal,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }
}
