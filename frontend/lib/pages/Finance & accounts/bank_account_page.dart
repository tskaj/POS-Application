import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:intl/intl.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../services/bank_services.dart';
import '../../providers/providers.dart';
import 'add_bank_account_page.dart';

class BankAccountPage extends StatefulWidget {
  const BankAccountPage({super.key});

  @override
  State<BankAccountPage> createState() => _BankAccountPageState();
}

class _BankAccountPageState extends State<BankAccountPage> {
  // API data
  List<BankAccount> _filteredAccounts = [];
  List<BankAccount> _allFilteredAccounts = [];
  bool _isLoading = true;
  String? _errorMessage;
  int currentPage = 1;
  final int itemsPerPage = 10;

  // Filter states
  final TextEditingController _bankNameSearchController =
      TextEditingController();
  String _bankNameSearch = '';

  // Checkbox selection
  Set<int> _selectedAccountIds = {};
  bool _selectAll = false;

  @override
  void initState() {
    super.initState();
    _bankNameSearchController.addListener(() {
      setState(() {
        _bankNameSearch = _bankNameSearchController.text;
        currentPage = 1;
      });
      _applyFilters();
    });
    _fetchAllAccountsOnInit();
  }

  @override
  void dispose() {
    _bankNameSearchController.dispose();
    super.dispose();
  }

  // Fetch all bank accounts once when page loads
  Future<void> _fetchAllAccountsOnInit() async {
    final financeProvider = Provider.of<FinanceProvider>(
      context,
      listen: false,
    );

    try {
      setState(() {
        _errorMessage = null;
      });

      // Check if data is already cached
      if (financeProvider.bankAccounts.isNotEmpty) {
        // Use cached data
        _applyFiltersClientSide();
        return;
      }

      // Fetch from API if not cached
      final accounts = await BankAccountService.getBankAccounts();
      financeProvider.setBankAccounts(accounts.data);

      // Apply initial filters
      _applyFiltersClientSide();
    } catch (e) {
      setState(() {
        _errorMessage =
            'Failed to load bank accounts. Please refresh the page.';
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
      // Apply filters to cached accounts
      _allFilteredAccounts = financeProvider.bankAccounts.where((account) {
        try {
          // Bank name search filter (searches account holder name and account number)
          if (_bankNameSearch.isNotEmpty) {
            final holderName = account.accHolderName.toLowerCase();
            final accNo = account.accNo.toLowerCase();
            final search = _bankNameSearch.toLowerCase();
            if (!holderName.contains(search) && !accNo.contains(search)) {
              return false;
            }
          }

          return true;
        } catch (e) {
          return false;
        }
      }).toList();

      // Apply local pagination to filtered results
      _paginateFilteredAccounts();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Search error: Please try a different search term';
        _isLoading = false;
        _filteredAccounts = [];
      });
    }
  }

  // Apply local pagination to filtered accounts
  void _paginateFilteredAccounts() {
    try {
      if (_allFilteredAccounts.isEmpty) {
        setState(() {
          _filteredAccounts = [];
        });
        return;
      }

      final startIndex = (currentPage - 1) * itemsPerPage;
      final endIndex = startIndex + itemsPerPage;

      if (startIndex >= _allFilteredAccounts.length) {
        setState(() {
          currentPage = 1;
        });
        _paginateFilteredAccounts();
        return;
      }

      setState(() {
        _filteredAccounts = _allFilteredAccounts.sublist(
          startIndex,
          endIndex > _allFilteredAccounts.length
              ? _allFilteredAccounts.length
              : endIndex,
        );
      });
    } catch (e) {
      setState(() {
        _filteredAccounts = [];
        currentPage = 1;
      });
    }
  }

  // Handle page changes
  Future<void> _changePage(int newPage) async {
    setState(() {
      currentPage = newPage;
    });
    _paginateFilteredAccounts();
  }

  // View account details
  Future<void> _viewAccountDetails(BankAccount account) async {
    // Show loading dialog first
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(),
              SizedBox(width: 16),
              Text('Loading account details...'),
            ],
          ),
        );
      },
    );

    try {
      // Fetch fresh account details from API
      final accountResponse = await BankAccountService.getBankAccountById(
        account.id,
      );
      final freshAccount = accountResponse.data;

      // Close loading dialog
      Navigator.of(context).pop();

      // Show account details dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Row(
              children: [
                Icon(
                  Icons.account_balance,
                  color: const Color(0xFF0D1845),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Bank Account Details',
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
                        _buildDetailRow('ID', freshAccount.id.toString()),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Transaction Type',
                          freshAccount.transactionType,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Account Holder',
                          freshAccount.accHolderName,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow('Account Number', freshAccount.accNo),
                        const SizedBox(height: 8),
                        _buildDetailRow('Account Type', freshAccount.accType),
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
                          'Opening Balance',
                          'Rs. ${double.tryParse(freshAccount.opBalance)?.toStringAsFixed(2) ?? freshAccount.opBalance}',
                          valueColor: const Color(0xFF4CAF50),
                          valueWeight: FontWeight.bold,
                        ),
                        const SizedBox(height: 8),
                        _buildDetailRow(
                          'Status',
                          freshAccount.status,
                          valueColor: freshAccount.status == 'Active'
                              ? const Color(0xFF4CAF50)
                              : const Color(0xFFDC3545),
                          valueWeight: FontWeight.w600,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Notes Section
                  if (freshAccount.note.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2196F3).withOpacity(0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFF2196F3).withOpacity(0.1),
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
                            freshAccount.note,
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
            actions: [
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
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();

      // Show error dialog
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: const Text('Error'),
            content: Text('Failed to load account details: $e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('OK'),
              ),
            ],
          );
        },
      );
    }
  }

  // Delete bank account
  Future<void> _deleteBankAccount(BankAccount account) async {
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
                'Delete Bank Account',
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
                'Are you sure you want to delete this bank account?',
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
                      'Account Details:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFDC3545),
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('ID: ${account.id}'),
                    Text('Account Holder: ${account.accHolderName}'),
                    Text('Account Number: ${account.accNo}'),
                    Text('Account Type: ${account.accType}'),
                    Text(
                      'Balance: Rs. ${double.tryParse(account.opBalance)?.toStringAsFixed(2) ?? account.opBalance}',
                    ),
                    Text('Status: ${account.status}'),
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
                  Text('Delete Account'),
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

        final response = await BankAccountService.deleteBankAccount(account.id);

        if (response.status) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(response.message),
              backgroundColor: Colors.green,
            ),
          );
          // Clear cached bank accounts so the next fetch will call the API
          final financeProvider = Provider.of<FinanceProvider>(
            context,
            listen: false,
          );
          financeProvider.clearBankAccounts();

          // Refresh the accounts list (will fetch from API because cache was cleared)
          await _fetchAllAccountsOnInit();
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
            content: Text('Failed to delete bank account: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        setState(() => _isLoading = false);
      }
    }
  }

  // Show edit account dialog
  Future<void> _showEditAccountDialog(BankAccount account) async {
    final _formKey = GlobalKey<FormState>();
    final _accHolderNameController = TextEditingController(
      text: account.accHolderName,
    );
    final _accNoController = TextEditingController(text: account.accNo);
    final _opBalanceController = TextEditingController(text: account.opBalance);
    final _noteController = TextEditingController(text: account.note);

    String _selectedAccType = account.accType;
    String _selectedStatus = account.status;
    bool _isSubmitting = false;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            Future<void> _submitForm() async {
              if (!_formKey.currentState!.validate()) return;

              setState(() => _isSubmitting = true);

              try {
                final bankAccountData = {
                  'transaction_type_id': 6,
                  'acc_holder_name': _accHolderNameController.text.trim(),
                  'acc_no': _accNoController.text.trim(),
                  'acc_type': _selectedAccType,
                  'op_balance':
                      double.tryParse(_opBalanceController.text) ?? 0.0,
                  'note': _noteController.text.trim(),
                  'status': _selectedStatus,
                };

                final response = await BankAccountService.updateBankAccount(
                  account.id,
                  bankAccountData,
                );

                if (response.status) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Bank account updated successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  // Clear cached bank accounts so the next fetch will call the API
                  final financeProvider = Provider.of<FinanceProvider>(
                    context,
                    listen: false,
                  );
                  financeProvider.clearBankAccounts();

                  Navigator.of(context).pop(); // Close dialog
                  await _fetchAllAccountsOnInit(); // Refresh the list (will fetch from API)
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to update bank account'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Failed to update bank account: $e'),
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                setState(() => _isSubmitting = false);
              }
            }

            return Dialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Container(
                width: MediaQuery.of(context).size.width * 0.8,
                constraints: BoxConstraints(
                  maxWidth: 600,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
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
                          const Icon(Icons.edit, color: Colors.white, size: 28),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Edit Bank Account',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 20,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: const Icon(Icons.close, color: Colors.white),
                          ),
                        ],
                      ),
                    ),

                    // Form Content
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Account Holder Name Field
                              TextFormField(
                                controller: _accHolderNameController,
                                decoration: InputDecoration(
                                  labelText: 'Account Holder Name *',
                                  hintText: 'e.g., John Doe',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.person,
                                    color: Color(0xFF0D1845),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter account holder name';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Account Number Field
                              TextFormField(
                                controller: _accNoController,
                                decoration: InputDecoration(
                                  labelText: 'Account Number *',
                                  hintText: 'e.g., ACC-123456789',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  prefixIcon: Icon(
                                    Icons.credit_card,
                                    color: Color(0xFF0D1845),
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null || value.trim().isEmpty) {
                                    return 'Please enter account number';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Account Type and Status Row
                              Row(
                                children: [
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedAccType,
                                      decoration: InputDecoration(
                                        labelText: 'Account Type *',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.account_balance_wallet,
                                          color: Color(0xFF0D1845),
                                        ),
                                      ),
                                      items: ['Current', 'Saving']
                                          .map(
                                            (type) => DropdownMenuItem(
                                              value: type,
                                              child: Text(type),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _selectedAccType = value;
                                          });
                                        }
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select account type';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: DropdownButtonFormField<String>(
                                      value: _selectedStatus,
                                      decoration: InputDecoration(
                                        labelText: 'Status *',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        prefixIcon: Icon(
                                          Icons.info,
                                          color: Color(0xFF0D1845),
                                        ),
                                      ),
                                      items: ['Active', 'Closed']
                                          .map(
                                            (status) => DropdownMenuItem(
                                              value: status,
                                              child: Text(status),
                                            ),
                                          )
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _selectedStatus = value;
                                          });
                                        }
                                      },
                                      validator: (value) {
                                        if (value == null || value.isEmpty) {
                                          return 'Please select status';
                                        }
                                        return null;
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),

                              // Opening Balance Field
                              TextFormField(
                                controller: _opBalanceController,
                                decoration: InputDecoration(
                                  labelText: 'Opening Balance (PKR) *',
                                  hintText: 'e.g., 25000.50',
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
                                    return 'Please enter opening balance';
                                  }
                                  double? balance = double.tryParse(value);
                                  if (balance == null || balance < 0) {
                                    return 'Please enter a valid balance';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Notes Field
                              TextFormField(
                                controller: _noteController,
                                decoration: InputDecoration(
                                  labelText: 'Notes',
                                  hintText:
                                      'Additional details about the account',
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
                              const SizedBox(height: 24),

                              // Buttons
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _isSubmitting
                                          ? null
                                          : () => Navigator.of(context).pop(),
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        side: BorderSide(
                                          color: Color(0xFF6C757D),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        'Cancel',
                                        style: TextStyle(
                                          color: Color(0xFF6C757D),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: _isSubmitting
                                          ? null
                                          : _submitForm,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF0D1845,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 16,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                      child: _isSubmitting
                                          ? SizedBox(
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
                                          : Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Icon(Icons.save, size: 18),
                                                const SizedBox(width: 8),
                                                Text('Update Account'),
                                              ],
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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

  bool _canGoToNextPage() {
    final totalPages = _getTotalPages();
    return currentPage < totalPages;
  }

  int _getTotalPages() {
    if (_allFilteredAccounts.isEmpty) return 1;
    return (_allFilteredAccounts.length / itemsPerPage).ceil();
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
                borderRadius: BorderRadius.circular(4),
              ),
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: Size(28, 28),
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

  double _getTotalBalance() {
    return _allFilteredAccounts.fold(
      0.0,
      (sum, account) => sum + (double.tryParse(account.opBalance) ?? 0.0),
    );
  }

  // Export selected accounts to PDF
  Future<void> _exportToPDF() async {
    if (_selectedAccountIds.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select at least one account to export'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Filter selected accounts
      final selectedAccounts = _allFilteredAccounts
          .where((account) => _selectedAccountIds.contains(account.id))
          .toList();

      // Create PDF document
      final PdfDocument document = PdfDocument();
      final PdfFont titleFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        18,
        style: PdfFontStyle.bold,
      );
      final PdfFont headerFont = PdfStandardFont(
        PdfFontFamily.helvetica,
        10,
        style: PdfFontStyle.bold,
      );
      final PdfFont smallFont = PdfStandardFont(PdfFontFamily.helvetica, 9);

      final PdfPage page = document.pages.add();
      final PdfGraphics graphics = page.graphics;

      // Draw title
      graphics.drawString(
        'Bank Accounts Report',
        titleFont,
        bounds: Rect.fromLTWH(0, 0, page.getClientSize().width, 30),
        format: PdfStringFormat(
          alignment: PdfTextAlignment.center,
          lineAlignment: PdfVerticalAlignment.middle,
        ),
      );

      // Draw generation info
      String filterInfo =
          'Generated on: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}';
      filterInfo += ' | Selected: ${selectedAccounts.length} accounts';

      graphics.drawString(
        filterInfo,
        smallFont,
        bounds: Rect.fromLTWH(0, 30, page.getClientSize().width, 20),
        format: PdfStringFormat(alignment: PdfTextAlignment.center),
      );

      // Create table
      final PdfGrid grid = PdfGrid();
      grid.columns.add(count: 5);

      final double pageWidth = page.getClientSize().width;
      final double tableWidth = pageWidth * 0.95;

      grid.columns[0].width = tableWidth * 0.12; // ID
      grid.columns[1].width = tableWidth * 0.30; // Account Holder
      grid.columns[2].width = tableWidth * 0.24; // Account Number
      grid.columns[3].width = tableWidth * 0.18; // Type
      grid.columns[4].width = tableWidth * 0.16; // Balance

      grid.style = PdfGridStyle(
        cellPadding: PdfPaddings(left: 3, right: 3, top: 3, bottom: 3),
        font: smallFont,
      );

      // Add header row
      final PdfGridRow headerRow = grid.headers.add(1)[0];
      headerRow.cells[0].value = 'ID';
      headerRow.cells[1].value = 'Account Holder';
      headerRow.cells[2].value = 'Account Number';
      headerRow.cells[3].value = 'Type';
      headerRow.cells[4].value = 'Balance';

      final PdfColor tableHeaderColor = PdfColor(248, 249, 250);
      for (int i = 0; i < headerRow.cells.count; i++) {
        headerRow.cells[i].style = PdfGridCellStyle(
          backgroundBrush: PdfSolidBrush(tableHeaderColor),
          textBrush: PdfSolidBrush(PdfColor(73, 80, 87)),
          font: headerFont,
          format: PdfStringFormat(
            alignment: PdfTextAlignment.center,
            lineAlignment: PdfVerticalAlignment.middle,
          ),
        );
      }

      // Add data rows
      double totalBalance = 0.0;
      for (final account in selectedAccounts) {
        final PdfGridRow row = grid.rows.add();
        row.cells[0].value = account.id.toString();
        row.cells[1].value = account.accHolderName;
        row.cells[2].value = account.accNo;
        row.cells[3].value = account.accType;

        final balance = double.tryParse(account.opBalance) ?? 0.0;
        totalBalance += balance;
        row.cells[4].value = 'Rs. ${balance.toStringAsFixed(2)}';

        // Center align cells
        for (int i = 0; i < row.cells.count; i++) {
          row.cells[i].style = PdfGridCellStyle(
            format: PdfStringFormat(
              alignment: i == 1
                  ? PdfTextAlignment.left
                  : PdfTextAlignment.center,
              lineAlignment: PdfVerticalAlignment.middle,
            ),
          );
        }
      }

      // Draw grid
      grid.draw(
        page: page,
        bounds: Rect.fromLTWH(
          0,
          60,
          page.getClientSize().width,
          page.getClientSize().height - 100,
        ),
      );

      // Add total at the bottom
      final double yPosition = grid.rows.count * 20 + 80;
      if (yPosition < page.getClientSize().height - 40) {
        graphics.drawString(
          'Total Balance: Rs. ${totalBalance.toStringAsFixed(2)}',
          PdfStandardFont(
            PdfFontFamily.helvetica,
            12,
            style: PdfFontStyle.bold,
          ),
          bounds: Rect.fromLTWH(
            page.getClientSize().width - 200,
            yPosition,
            200,
            20,
          ),
          format: PdfStringFormat(alignment: PdfTextAlignment.right),
        );
      }

      // Save the document
      final List<int> bytes = await document.save();
      document.dispose();

      // Get directory and save file
      final directory = await getApplicationDocumentsDirectory();
      final path =
          '${directory.path}/bank_accounts_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final file = File(path);
      await file.writeAsBytes(bytes);

      // Close loading dialog
      Navigator.of(context).pop();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('PDF exported successfully to:\n$path'),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      // Close loading dialog if still open
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error exporting PDF: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Accounts'),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF0D1845).withOpacity(0.22),
                    blurRadius: 10,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.account_balance,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Bank Account Management',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.25,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Manage and monitor all bank accounts',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.white.withOpacity(0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddBankAccountPage(),
                            ),
                          );
                          if (result == true) {
                            // Refresh the bank accounts list
                            _fetchAllAccountsOnInit();
                          }
                        },
                        icon: const Icon(Icons.add, size: 12),
                        label: const Text(
                          'Add Bank Account',
                          style: TextStyle(fontSize: 11),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0D1845),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 1,
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _exportToPDF,
                        icon: const Icon(Icons.picture_as_pdf, size: 12),
                        label: Text(
                          'Export PDF${_selectedAccountIds.isNotEmpty ? ' (${_selectedAccountIds.length})' : ''}',
                          style: TextStyle(fontSize: 11),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0D1845),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 6,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6),
                          ),
                          elevation: 2,
                          textStyle: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Summary Cards
                  Consumer<FinanceProvider>(
                    builder: (context, financeProvider, child) => Row(
                      children: [
                        _buildSummaryCard(
                          'Total Accounts',
                          '${financeProvider.bankAccounts.length}',
                          Icons.account_balance_wallet,
                          const Color(0xFF4CAF50),
                        ),
                        const SizedBox(width: 6),
                        _buildSummaryCard(
                          'Total Balance',
                          'Rs. ${_getTotalBalance().toStringAsFixed(2)}',
                          Icons.receipt_long,
                          const Color(0xFF2196F3),
                        ),
                        const SizedBox(width: 6),
                        _buildSummaryCard(
                          'Avg. Balance',
                          'Rs. ${financeProvider.bankAccounts.isEmpty ? "0.00" : (_getTotalBalance() / financeProvider.bankAccounts.length).toStringAsFixed(2)}',
                          Icons.trending_up,
                          const Color(0xFFFF9800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Search and Table
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 6),
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
                    // Filters Section
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
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
                          // Bank Name Search Filter
                          Expanded(
                            flex: 1,
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
                                        Icons.search,
                                        size: 14,
                                        color: Color(0xFF0D1845),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Search Bank',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF343A40),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  height: 34,
                                  decoration: BoxDecoration(
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 4,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: TextField(
                                    controller: _bankNameSearchController,
                                    decoration: InputDecoration(
                                      filled: true,
                                      fillColor: Colors.white,
                                      hintText:
                                          'Search by holder name or account number...',
                                      hintStyle: TextStyle(
                                        color: Color(0xFFADB5BD),
                                        fontSize: 13,
                                      ),
                                      prefixIcon: Icon(
                                        Icons.search,
                                        size: 18,
                                        color: Color(0xFF6C757D),
                                      ),
                                      suffixIcon: _bankNameSearch.isNotEmpty
                                          ? IconButton(
                                              icon: Icon(
                                                Icons.clear,
                                                size: 18,
                                                color: Color(0xFF6C757D),
                                              ),
                                              onPressed: () {
                                                _bankNameSearchController
                                                    .clear();
                                              },
                                              padding: EdgeInsets.zero,
                                              constraints: BoxConstraints(),
                                            )
                                          : null,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Color(0xFFDEE2E6),
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Color(0xFFDEE2E6),
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                        borderSide: BorderSide(
                                          color: Color(0xFF0D1845),
                                          width: 2,
                                        ),
                                      ),
                                      contentPadding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 8,
                                      ),
                                    ),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Color(0xFF343A40),
                                    ),
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
                        horizontal: 8,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 45,
                            child: Checkbox(
                              value: _selectAll,
                              onChanged: (value) {
                                setState(() {
                                  _selectAll = value ?? false;
                                  if (_selectAll) {
                                    _selectedAccountIds = _allFilteredAccounts
                                        .map((account) => account.id)
                                        .toSet();
                                  } else {
                                    _selectedAccountIds.clear();
                                  }
                                });
                              },
                              activeColor: const Color(0xFF0D1845),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 1,
                            child: Text('ID', style: _headerStyle()),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Account Holder',
                              style: _headerStyle(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Account Number',
                              style: _headerStyle(),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: Text(
                              'Type',
                              style: _headerStyle(),
                              textAlign: TextAlign.center,
                            ),
                          ),
                          const SizedBox(width: 28),
                          Expanded(
                            flex: 2,
                            child: Text('Balance', style: _headerStyle()),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Actions',
                              style: _headerStyle(),
                              textAlign: TextAlign.center,
                            ),
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
                                    onPressed: _fetchAllAccountsOnInit,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _filteredAccounts.isEmpty
                          ? const Center(
                              child: Text(
                                'No bank accounts found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredAccounts.length,
                              itemBuilder: (context, index) {
                                final account = _filteredAccounts[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
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
                                      SizedBox(
                                        width: 45,
                                        child: Checkbox(
                                          value: _selectedAccountIds.contains(
                                            account.id,
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              if (value == true) {
                                                _selectedAccountIds.add(
                                                  account.id,
                                                );
                                              } else {
                                                _selectedAccountIds.remove(
                                                  account.id,
                                                );
                                                _selectAll = false;
                                              }
                                            });
                                          },
                                          activeColor: const Color(0xFF0D1845),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 1,
                                        child: Text(
                                          account.id.toString(),
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF0D1845),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          account.accHolderName,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          account.accNo,
                                          style: TextStyle(
                                            fontFamily: 'monospace',
                                            fontSize: 12,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 1,
                                        child: Center(
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color:
                                                  account.accType == 'Current'
                                                  ? Color(
                                                      0xFF2196F3,
                                                    ).withOpacity(0.1)
                                                  : Color(
                                                      0xFF8BC34A,
                                                    ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Text(
                                              account.accType,
                                              style: TextStyle(
                                                color:
                                                    account.accType == 'Current'
                                                    ? Color(0xFF2196F3)
                                                    : Color(0xFF8BC34A),
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                              textAlign: TextAlign.center,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 28),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          'Rs. ${double.tryParse(account.opBalance)?.toStringAsFixed(2) ?? account.opBalance}',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF28A745),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.visibility,
                                                color: Color(0xFF17A2B8),
                                                size: 16,
                                              ),
                                              onPressed: () =>
                                                  _viewAccountDetails(account),
                                              tooltip: 'View Details',
                                              padding: EdgeInsets.all(4),
                                              constraints: BoxConstraints(),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.edit,
                                                color: Color(0xFFFFA726),
                                                size: 16,
                                              ),
                                              onPressed: () =>
                                                  _showEditAccountDialog(
                                                    account,
                                                  ),
                                              tooltip: 'Edit',
                                              padding: EdgeInsets.all(4),
                                              constraints: BoxConstraints(),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete,
                                                color: Color(0xFFDC3545),
                                                size: 16,
                                              ),
                                              onPressed: () =>
                                                  _deleteBankAccount(account),
                                              tooltip: 'Delete',
                                              padding: EdgeInsets.all(4),
                                              constraints: BoxConstraints(),
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
                        vertical: 8,
                        horizontal: 12,
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
                                      _paginateFilteredAccounts();
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
                                      _paginateFilteredAccounts();
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
                              'Page $currentPage of ${_getTotalPages()} (${_allFilteredAccounts.length} total)',
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

  TextStyle _headerStyle() {
    return const TextStyle(
      fontWeight: FontWeight.w600,
      color: Color(0xFF343A40),
      fontSize: 12,
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
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Icon(icon, color: Colors.white, size: 14),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 8,
                      color: Colors.white.withOpacity(0.8),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 12,
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
          width: 100,
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
