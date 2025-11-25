import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';
import '../../services/income_services.dart';
import '../../services/chart_of_accounts_service.dart';
import '../../services/bank_services.dart';

enum PaymentMode { cash, bank }

class AddIncomePage extends StatefulWidget {
  const AddIncomePage({super.key});

  @override
  State<AddIncomePage> createState() => _AddIncomePageState();
}

class _AddIncomePageState extends State<AddIncomePage> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  final _amountController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  PaymentMode _selectedPaymentMode = PaymentMode.cash;
  int? _selectedCoaId;

  // Chart of Accounts data
  List<MainHeadOfAccountWithSubs> _mainHeads = [];
  List<AccountOfSubHead> _allAccounts =
      []; // For both Cash and Bank modes - direct head selection

  // Bank Accounts data
  List<BankAccount> _bankAccounts = [];
  BankAccount? _selectedBankAccount;

  bool _isSubmitting = false;

  // Helper method to create clean InputDecoration
  InputDecoration _buildCleanInputDecoration(
    String label, {
    bool isRequired = false,
    String? hint,
    Widget? prefixIcon,
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
      prefixIcon: prefixIcon,
    );
  }

  void _showChartOfAccountsSearchDialog() {
    List<AccountOfSubHead> filteredAccounts = List.from(_allAccounts);
    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void _filterAccounts(String query) {
              setState(() {
                if (query.isEmpty) {
                  filteredAccounts = List.from(_allAccounts);
                } else {
                  final searchQuery = query.toLowerCase();
                  filteredAccounts = _allAccounts.where((account) {
                    final code = account.code.toLowerCase();
                    final title = account.title.toLowerCase();
                    return code.contains(searchQuery) ||
                        title.contains(searchQuery);
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
                            Icons.account_balance_wallet,
                            color: Color(0xFF0D1845),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Select Head of Account',
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
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by account code or title...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF0D1845),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                        onChanged: _filterAccounts,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Account List
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
                        child: filteredAccounts.isEmpty
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
                                        'No accounts found',
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
                                itemCount: filteredAccounts.length,
                                itemBuilder: (context, index) {
                                  final account = filteredAccounts[index];
                                  final isSelected =
                                      account.id == _selectedCoaId;

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        this.setState(() {
                                          _selectedCoaId = account.id;
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
                                            index < filteredAccounts.length - 1
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
                                                  '${account.code} - ${account.title}',
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

  void _showBankAccountSearchDialog() {
    List<BankAccount> filteredBankAccounts = List.from(_bankAccounts);
    final TextEditingController searchController = TextEditingController();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void _filterBankAccounts(String query) {
              setState(() {
                if (query.isEmpty) {
                  filteredBankAccounts = List.from(_bankAccounts);
                } else {
                  final searchQuery = query.toLowerCase();
                  filteredBankAccounts = _bankAccounts.where((bankAccount) {
                    final holderName = bankAccount.accHolderName.toLowerCase();
                    final accNo = bankAccount.accNo.toLowerCase();
                    final accType = bankAccount.accType.toLowerCase();
                    return holderName.contains(searchQuery) ||
                        accNo.contains(searchQuery) ||
                        accType.contains(searchQuery);
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
                            Icons.account_balance,
                            color: Color(0xFF0D1845),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Select Bank Account',
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
                      child: TextField(
                        controller: searchController,
                        decoration: InputDecoration(
                          hintText:
                              'Search by holder name, account number, or type...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF0D1845),
                          ),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                        ),
                        onChanged: _filterBankAccounts,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Bank Account List
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
                        child: filteredBankAccounts.isEmpty
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
                                        'No bank accounts found',
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
                                itemCount: filteredBankAccounts.length,
                                itemBuilder: (context, index) {
                                  final bankAccount =
                                      filteredBankAccounts[index];
                                  final isSelected =
                                      bankAccount.id ==
                                      _selectedBankAccount?.id;

                                  return InkWell(
                                    onTap: () {
                                      setState(() {
                                        this.setState(() {
                                          _selectedBankAccount = bankAccount;
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
                                                filteredBankAccounts.length - 1
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
                                                  '${bankAccount.accHolderName} - ${bankAccount.accNo}',
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
                                                  'Type: ${bankAccount.accType}',
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

  @override
  void initState() {
    super.initState();
    _fetchChartOfAccounts();
    if (_selectedPaymentMode == PaymentMode.bank) {
      _fetchBankAccounts();
    }
  }

  Future<void> _fetchChartOfAccounts() async {
    try {
      final mainHeads = await ChartOfAccountsService.getAllMainHeadAccounts();
      setState(() {
        _mainHeads = mainHeads;
        // Extract all accounts for Cash mode dropdown
        _allAccounts = mainHeads.expand((mainHead) {
          return mainHead.subs.expand((subHead) => subHead.accounts);
        }).toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load chart of accounts: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _fetchBankAccounts() async {
    try {
      final response = await BankAccountService.getBankAccounts();
      setState(() {
        _bankAccounts = response.data
            .where((account) => account.status == 'Active')
            .toList();
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to load bank accounts: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
      setState(() => _selectedDate = picked);
    }
  }

  void _onPaymentModeChanged(PaymentMode mode) {
    setState(() {
      _selectedPaymentMode = mode;
      _selectedCoaId = null;
      _selectedBankAccount = null;
    });

    if (mode == PaymentMode.bank && _bankAccounts.isEmpty) {
      _fetchBankAccounts();
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate COA selection based on payment mode
    if (_selectedPaymentMode == PaymentMode.cash && _selectedCoaId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a head of account'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_selectedPaymentMode == PaymentMode.bank) {
      if (_selectedCoaId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a head of account'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (_selectedBankAccount == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select a bank account'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (authProvider.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('User not authenticated'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      // Prepare payload expected by backend
      // Required keys:
      // - transaction_type_id: 10 (Income)
      // - payment_mode_id: 1 for Cash, 2 for Bank
      // - income_category_id: comes from selected COA (fallback to 1)
      final incomeData = {
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'transaction_type_id': 10,
        'payment_mode_id': _selectedPaymentMode == PaymentMode.cash ? 1 : 2,
        'income_category_id': _selectedCoaId ?? 1,

        // Keep legacy/coexisting fields for backward compatibility
        'coas_id': _selectedCoaId,
        'ccoas_id': _selectedPaymentMode == PaymentMode.cash
            ? 3
            : int.tryParse(_selectedBankAccount?.coaId ?? ''),

        'users_id': authProvider.user!.id,
        'naration': '',
        'description': _descriptionController.text.trim(),
        'amount': double.tryParse(_amountController.text) ?? 0.0,
      };

      final response = await IncomeService.createIncome(incomeData);

      if (response.status) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(response.message),
            backgroundColor: Colors.green,
          ),
        );
        // Clear cached pay-ins so PayIn page will fetch fresh data when it returns
        final financeProvider = Provider.of<FinanceProvider>(
          context,
          listen: false,
        );
        financeProvider.clearPayIns();

        Navigator.of(context).pop(true); // Return true to indicate success
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
          content: Text('Failed to create income: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Add Income'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Header Section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D1845).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.add_circle,
                      color: Color(0xFF0D1845),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Create New Income',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0D1845),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Record a new income transaction',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Form Container
            Container(
              padding: const EdgeInsets.all(24.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Payment Mode Selection
                    Text(
                      'Payment Mode',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF0D1845),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                _onPaymentModeChanged(PaymentMode.cash),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _selectedPaymentMode == PaymentMode.cash
                                  ? Color(0xFF28A745)
                                  : Colors.grey[300],
                              foregroundColor:
                                  _selectedPaymentMode == PaymentMode.cash
                                  ? Colors.white
                                  : Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.money, size: 20),
                                const SizedBox(width: 8),
                                Text('Cash'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () =>
                                _onPaymentModeChanged(PaymentMode.bank),
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  _selectedPaymentMode == PaymentMode.bank
                                  ? Color(0xFF007BFF)
                                  : Colors.grey[300],
                              foregroundColor:
                                  _selectedPaymentMode == PaymentMode.bank
                                  ? Colors.white
                                  : Colors.black,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.account_balance, size: 20),
                                const SizedBox(width: 8),
                                Text('Bank'),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Chart of Accounts Selection
                    if (_selectedPaymentMode == PaymentMode.cash) ...[
                      // For Cash - Direct Head of Account selection
                      Text(
                        'Head of Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D1845),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _showChartOfAccountsSearchDialog,
                        child: InputDecorator(
                          decoration: _buildCleanInputDecoration(
                            'Select Head of Account',
                            isRequired: true,
                            prefixIcon: Icon(
                              Icons.account_balance_wallet,
                              color: Color(0xFF0D1845),
                            ),
                          ),
                          child: _selectedCoaId != null
                              ? Builder(
                                  builder: (context) {
                                    final selectedAccount = _allAccounts
                                        .firstWhere(
                                          (acc) => acc.id == _selectedCoaId,
                                          orElse: () => AccountOfSubHead(
                                            id: -1,
                                            code: '',
                                            title: '',
                                            type: '',
                                            status: '',
                                          ),
                                        );
                                    return Text(
                                      selectedAccount.id != -1
                                          ? '${selectedAccount.code} - ${selectedAccount.title}'
                                          : 'Select Head of Account',
                                      style: TextStyle(
                                        color: selectedAccount.id != -1
                                            ? Colors.black87
                                            : Colors.grey[500],
                                      ),
                                    );
                                  },
                                )
                              : Text(
                                  'Select Head of Account',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                        ),
                      ),
                      // Show Main Head and Sub Head automatically when account is selected
                      if (_selectedCoaId != null) ...[
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            // Find the selected account in the nested structure
                            MainHeadOfAccountWithSubs? foundMainHead;
                            SubHeadOfAccountWithAccounts? foundSubHead;
                            AccountOfSubHead? foundAccount;

                            for (final mainHead in _mainHeads) {
                              for (final subHead in mainHead.subs) {
                                final account = subHead.accounts.firstWhere(
                                  (acc) => acc.id == _selectedCoaId,
                                  orElse: () => AccountOfSubHead(
                                    id: -1,
                                    code: '',
                                    title: '',
                                    type: '',
                                    status: '',
                                  ),
                                );
                                if (account.id != -1) {
                                  foundMainHead = mainHead;
                                  foundSubHead = subHead;
                                  foundAccount = account;
                                  break;
                                }
                              }
                              if (foundMainHead != null) break;
                            }

                            if (foundMainHead != null &&
                                foundSubHead != null &&
                                foundAccount != null) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Account Hierarchy:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0D1845),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Main Head: ${foundMainHead.code} - ${foundMainHead.title}',
                                    ),
                                    Text(
                                      'Sub Head: ${foundSubHead.code} - ${foundSubHead.title}',
                                    ),
                                    Text(
                                      'Head: ${foundAccount.code} - ${foundAccount.title}',
                                    ),
                                  ],
                                ),
                              );
                            }
                            return SizedBox.shrink();
                          },
                        ),
                      ],
                    ] else ...[
                      // For Bank - Head of Account selection (like Cash mode)
                      Text(
                        'Head of Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D1845),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _showChartOfAccountsSearchDialog,
                        child: InputDecorator(
                          decoration: _buildCleanInputDecoration(
                            'Select Head of Account',
                            isRequired: true,
                            prefixIcon: Icon(
                              Icons.account_balance_wallet,
                              color: Color(0xFF0D1845),
                            ),
                          ),
                          child: _selectedCoaId != null
                              ? Builder(
                                  builder: (context) {
                                    final selectedAccount = _allAccounts
                                        .firstWhere(
                                          (acc) => acc.id == _selectedCoaId,
                                          orElse: () => AccountOfSubHead(
                                            id: -1,
                                            code: '',
                                            title: '',
                                            type: '',
                                            status: '',
                                          ),
                                        );
                                    return Text(
                                      selectedAccount.id != -1
                                          ? '${selectedAccount.code} - ${selectedAccount.title}'
                                          : 'Select Head of Account',
                                      style: TextStyle(
                                        color: selectedAccount.id != -1
                                            ? Colors.black87
                                            : Colors.grey[500],
                                      ),
                                    );
                                  },
                                )
                              : Text(
                                  'Select Head of Account',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                        ),
                      ),
                      // Show Account Hierarchy when account is selected
                      if (_selectedCoaId != null) ...[
                        const SizedBox(height: 16),
                        Builder(
                          builder: (context) {
                            // Find the selected account in the nested structure
                            MainHeadOfAccountWithSubs? foundMainHead;
                            SubHeadOfAccountWithAccounts? foundSubHead;
                            AccountOfSubHead? foundAccount;

                            for (final mainHead in _mainHeads) {
                              for (final subHead in mainHead.subs) {
                                final account = subHead.accounts.firstWhere(
                                  (acc) => acc.id == _selectedCoaId,
                                  orElse: () => AccountOfSubHead(
                                    id: -1,
                                    code: '',
                                    title: '',
                                    type: '',
                                    status: '',
                                  ),
                                );
                                if (account.id != -1) {
                                  foundMainHead = mainHead;
                                  foundSubHead = subHead;
                                  foundAccount = account;
                                  break;
                                }
                              }
                              if (foundMainHead != null) break;
                            }

                            if (foundMainHead != null &&
                                foundSubHead != null &&
                                foundAccount != null) {
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[300]!),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Account Hierarchy:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF0D1845),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Main Head: ${foundMainHead.code} - ${foundMainHead.title}',
                                    ),
                                    Text(
                                      'Sub Head: ${foundSubHead.code} - ${foundSubHead.title}',
                                    ),
                                    Text(
                                      'Head: ${foundAccount.code} - ${foundAccount.title}',
                                    ),
                                  ],
                                ),
                              );
                            }
                            return SizedBox.shrink();
                          },
                        ),
                      ],
                      const SizedBox(height: 16),

                      // Bank Account Selection
                      Text(
                        'Bank Account',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0D1845),
                        ),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: _showBankAccountSearchDialog,
                        child: InputDecorator(
                          decoration: _buildCleanInputDecoration(
                            'Select Bank Account',
                            isRequired: true,
                            prefixIcon: Icon(
                              Icons.account_balance,
                              color: Color(0xFF0D1845),
                            ),
                          ),
                          child: _selectedBankAccount != null
                              ? Builder(
                                  builder: (context) {
                                    final selectedBankAccount = _bankAccounts
                                        .firstWhere(
                                          (bank) =>
                                              bank.id ==
                                              _selectedBankAccount?.id,
                                          orElse: () => BankAccount(
                                            id: -1,
                                            coaId: '',
                                            transactionType: '',
                                            accHolderName: '',
                                            accNo: '',
                                            accType: '',
                                            opBalance: '',
                                            note: '',
                                            status: '',
                                          ),
                                        );
                                    return Text(
                                      selectedBankAccount.id != -1
                                          ? '${selectedBankAccount.accHolderName} - ${selectedBankAccount.accNo} (${selectedBankAccount.accType})'
                                          : 'Select Bank Account',
                                      style: TextStyle(
                                        color: selectedBankAccount.id != -1
                                            ? Colors.black87
                                            : Colors.grey[500],
                                      ),
                                    );
                                  },
                                )
                              : Text(
                                  'Select Bank Account',
                                  style: TextStyle(color: Colors.grey[500]),
                                ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Date Field
                    InkWell(
                      onTap: () => _selectDate(context),
                      child: InputDecorator(
                        decoration: _buildCleanInputDecoration(
                          'Date',
                          isRequired: true,
                          prefixIcon: Icon(
                            Icons.calendar_today,
                            color: Color(0xFF0D1845),
                          ),
                        ),
                        child: Text(
                          DateFormat('dd MMM yyyy').format(_selectedDate),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Description Field
                    TextFormField(
                      controller: _descriptionController,
                      decoration: _buildCleanInputDecoration(
                        'Description',
                        hint: 'Additional details about the income',
                        prefixIcon: Icon(
                          Icons.info_outline,
                          color: Color(0xFF0D1845),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 20),

                    const SizedBox(height: 16),

                    // Amount Field
                    TextFormField(
                      controller: _amountController,
                      decoration: _buildCleanInputDecoration(
                        'Amount (PKR)',
                        isRequired: true,
                        hint: 'e.g., 120000.00',
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
                    const SizedBox(height: 32),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _selectedPaymentMode == PaymentMode.cash
                              ? Color(0xFF28A745)
                              : Color(0xFF007BFF),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save, size: 20),
                                  SizedBox(width: 8),
                                  Text('Create Income'),
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
    );
  }
}
