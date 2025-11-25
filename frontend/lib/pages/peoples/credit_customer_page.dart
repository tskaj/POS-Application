import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/credit_customer_service.dart';
import '../../services/city_service.dart';
import 'package:provider/provider.dart';
import '../../providers/providers.dart';

// CNIC Formatter - Automatically adds dashes (XXXXX-XXXXXXX-X)
class CnicInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digit characters
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Limit to 13 digits
    final digitsOnly = text.substring(0, text.length > 13 ? 13 : text.length);

    // Format with dashes
    String formatted = '';
    for (int i = 0; i < digitsOnly.length; i++) {
      if (i == 5 || i == 12) {
        formatted += '-';
      }
      formatted += digitsOnly[i];
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

// Phone Number Formatter - Limits to 11 digits for Pakistani numbers
class PhoneInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Remove all non-digit characters
    final text = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');

    // Limit to 11 digits (Pakistani phone number format)
    final digitsOnly = text.substring(0, text.length > 11 ? 11 : text.length);

    return TextEditingValue(
      text: digitsOnly,
      selection: TextSelection.collapsed(offset: digitsOnly.length),
    );
  }
}

// Validation Helpers
class FormValidators {
  // Validate CNIC format (13 digits with dashes)
  static String? validateCnic(String? value, {bool isOptional = false}) {
    if (value?.isEmpty ?? true) {
      return isOptional ? null : 'CNIC is required';
    }

    // Remove dashes and check if we have exactly 13 digits
    final digitsOnly = value!.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.length != 13) {
      return 'CNIC must be 13 digits (e.g., 12345-6789012-3)';
    }

    return null;
  }

  // Validate email format
  static String? validateEmail(String? value, {bool isOptional = false}) {
    if (value?.isEmpty ?? true) {
      return isOptional ? null : 'Email is required';
    }

    // Basic email validation regex
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(value!)) {
      return 'Please enter a valid email address';
    }

    return null;
  }

  // Validate Pakistani phone number (11 digits, starting with 0)
  static String? validatePhone(String? value, {bool isOptional = false}) {
    if (value?.isEmpty ?? true) {
      return isOptional ? null : 'Phone number is required';
    }

    // Remove any non-digit characters
    final digitsOnly = value!.replaceAll(RegExp(r'[^0-9]'), '');

    if (digitsOnly.length < 10 || digitsOnly.length > 11) {
      return 'Phone must be 10-11 digits';
    }

    // Pakistani numbers typically start with 0
    if (digitsOnly.length == 11 && !digitsOnly.startsWith('0')) {
      return 'Pakistani numbers should start with 0';
    }

    return null;
  }

  // Validate name (no numbers or special characters)
  static String? validateName(String? value, {bool isOptional = false}) {
    if (value?.isEmpty ?? true) {
      return isOptional ? null : 'Name is required';
    }

    if (value!.length < 3) {
      return 'Name must be at least 3 characters';
    }

    // Check for invalid characters (numbers and most special chars)
    final nameRegex = RegExp(r'^[a-zA-Z\s\-\.]+$');
    if (!nameRegex.hasMatch(value)) {
      return 'Name can only contain letters, spaces, hyphens, and periods';
    }

    return null;
  }

  // Validate address
  static String? validateAddress(String? value) {
    if (value?.isEmpty ?? true) {
      return 'Address is required';
    }

    if (value!.length < 10) {
      return 'Address must be at least 10 characters';
    }

    return null;
  }
}

class CreditCustomerPage extends StatefulWidget {
  const CreditCustomerPage({super.key});

  @override
  State<CreditCustomerPage> createState() => _CreditCustomerPageState();
}

class _CreditCustomerPageState extends State<CreditCustomerPage> {
  // Provider reference
  late PeopleProvider _peopleProvider;

  // API data
  List<Map<String, dynamic>> _creditCustomers = [];
  List<Map<String, dynamic>> _filteredCustomers = [];
  List<Map<String, dynamic>> _allFilteredCustomers =
      []; // Store all filtered customers for local pagination

  // Cities data for resolving city IDs to names
  List<Map<String, dynamic>> _cities = [];

  // Pagination
  int _currentPage = 1;
  final int _itemsPerPage = 10;
  int _totalPages = 1;

  // Loading and error states
  bool _isLoading = true;
  String? _errorMessage;
  bool _isRetrying = false;

  // Search and filter
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _peopleProvider = Provider.of<PeopleProvider>(context, listen: false);
    _loadCreditCustomers();
    _loadCities();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.toLowerCase();
      _currentPage = 1; // Reset to first page when searching
      _applyFiltersClientSide();
    });
  }

  Future<void> _loadCreditCustomers() async {
    // Check if data is already cached
    if (_peopleProvider.creditCustomers.isNotEmpty) {
      setState(() {
        _creditCustomers = _peopleProvider.creditCustomers;
        _applyFiltersClientSide();
        _isLoading = false;
      });
      return;
    }

    // If not cached, fetch from API
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final allCustomers = await CreditCustomerService.getAllCreditCustomers();
      setState(() {
        _creditCustomers = allCustomers;
        _peopleProvider.setCreditCustomers(allCustomers); // Cache the data
        _applyFiltersClientSide();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load customers: ' + e.toString();
        _isLoading = false;
        // Load mock data as fallback
        _loadMockData();
      });
    }
  }

  void _loadMockData() {
    _creditCustomers = [
      {
        'id': 1,
        'name': 'John Doe',
        'cnic': '12345-6789012-3',
        'phone': '+92-300-1234567',
        'email': 'john.doe@example.com',
        'city': 'Lahore',
      },
      {
        'id': 2,
        'name': 'Jane Smith',
        'cnic': '23456-7890123-4',
        'phone': '+92-301-2345678',
        'email': 'jane.smith@example.com',
        'city': 'Karachi',
      },
      {
        'id': 3,
        'name': 'Ahmed Khan',
        'cnic': '34567-8901234-5',
        'phone': '+92-302-3456789',
        'email': 'ahmed.khan@example.com',
        'city': 'Islamabad',
      },
    ];
    _peopleProvider.setCreditCustomers(_creditCustomers); // Cache mock data
    _applyFiltersClientSide();
  }

  Future<void> _loadCities() async {
    try {
      final cityResponse = await CityService.getAllCities(
        page: 1,
        perPage: 1000,
      );
      setState(() {
        _cities = cityResponse.data
            .map((c) => {"id": c.id, "title": c.title})
            .toList();
      });
    } catch (e) {
      print('Error loading cities: $e');
      // Fallback cities
      setState(() {
        _cities = const [
          {"id": 1, "title": "Hermannhaven"},
          {"id": 2, "title": "North Maraton"},
          {"id": 3, "title": "New Ashton"},
          {"id": 4, "title": "Lake Gussieborough"},
          {"id": 5, "title": "East Vidal"},
        ];
      });
    }
  }

  void _applyFiltersClientSide() {
    if (_searchQuery.isEmpty) {
      _allFilteredCustomers = List.from(_creditCustomers);
    } else {
      _allFilteredCustomers = _creditCustomers.where((customer) {
        final name = customer['name']?.toString().toLowerCase() ?? '';
        final cnic = customer['cnic']?.toString().toLowerCase() ?? '';
        final phone = customer['phone']?.toString().toLowerCase() ?? '';
        final email = customer['email']?.toString().toLowerCase() ?? '';
        final city = customer['city']?.toString().toLowerCase() ?? '';

        return name.contains(_searchQuery) ||
            cnic.contains(_searchQuery) ||
            phone.contains(_searchQuery) ||
            email.contains(_searchQuery) ||
            city.contains(_searchQuery);
      }).toList();
    }

    _totalPages = (_allFilteredCustomers.length / _itemsPerPage).ceil();
    if (_totalPages == 0) _totalPages = 1;
    _paginateFilteredCustomers();
  }

  void _paginateFilteredCustomers() {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;

    setState(() {
      if (startIndex >= _allFilteredCustomers.length) {
        _filteredCustomers = [];
      } else {
        _filteredCustomers = _allFilteredCustomers.sublist(
          startIndex,
          endIndex > _allFilteredCustomers.length
              ? _allFilteredCustomers.length
              : endIndex,
        );
      }
    });
  }

  void _changePage(int page) {
    if (page >= 1 && page <= _totalPages) {
      setState(() {
        _currentPage = page;
        _paginateFilteredCustomers();
      });
    }
  }

  Future<void> _retryFetch() async {
    setState(() {
      _isRetrying = true;
    });
    await _loadCreditCustomers();
    setState(() {
      _isRetrying = false;
    });
  }

  Future<void> _showCreateCustomerDialog() async {
    final cities = await _fetchAvailableCities();
    showDialog(
      context: context,
      builder: (context) => CustomerFormDialog(cities: cities),
    ).then((result) {
      // CustomerFormDialog now returns the created customer Map on success
      if (result == true || result is Map<String, dynamic>) {
        // Clear cache and refresh the list
        _peopleProvider.setCreditCustomers([]);
        _loadCreditCustomers();
      }
    });
  }

  void _showViewCustomerDialog(Map<String, dynamic> customer) {
    showDialog(
      context: context,
      builder: (context) =>
          CustomerDetailDialog(customer: customer, cities: _cities),
    );
  }

  Future<void> _showEditCustomerDialog(Map<String, dynamic> customer) async {
    final cities = await _fetchAvailableCities();
    showDialog(
      context: context,
      builder: (context) =>
          CustomerFormDialog(customer: customer, cities: cities),
    ).then((result) {
      // Accept both the legacy boolean and the new Map return value
      if (result == true || result is Map<String, dynamic>) {
        // Clear cache and refresh the list
        _peopleProvider.setCreditCustomers([]);
        _loadCreditCustomers();
      }
    });
  }

  Future<void> _deleteCustomer(Map<String, dynamic> customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text(
          'Are you sure you want to delete ${customer['name']?.toString() ?? 'this customer'}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        final success = await CreditCustomerService.deleteCreditCustomer(
          customer['id'].toString(),
        );

        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Customer deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        // Parse error message
        String errorMessage = e.toString();
        if (errorMessage.contains('404') ||
            errorMessage.contains('No query results')) {
          errorMessage = 'Customer not found or already deleted';
        } else {
          errorMessage = 'Error: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.orange),
        );
      } finally {
        // Always refresh the list after delete attempt (success or failure)
        // Clear cached data to force fresh API call
        _peopleProvider.setCreditCustomers([]);
        await _loadCreditCustomers();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Credit Customers'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _showCreateCustomerDialog,
            tooltip: 'Add Customer',
          ),
        ],
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
                          Icons.people,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 18),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Credit Customer Management',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Manage credit customers and their information',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showCreateCustomerDialog,
                        icon: const Icon(Icons.add, size: 15),
                        label: const Text('Add Customer'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0D1845),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Summary Cards
                  Row(
                    children: [
                      _buildSummaryCard(
                        'Total Customers',
                        '${_creditCustomers.length}',
                        Icons.people,
                        const Color(0xFF2196F3),
                      ),
                      _buildSummaryCard(
                        'Filtered Results',
                        '${_allFilteredCustomers.length}',
                        Icons.filter_list,
                        const Color(0xFF8BC34A),
                      ),
                      _buildSummaryCard(
                        'Current Page',
                        '$_currentPage of $_totalPages',
                        Icons.pageview,
                        const Color(0xFFFF9800),
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
                    // Search Section
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
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              decoration: InputDecoration(
                                hintText:
                                    'Search by name, CNIC, phone, email, or city...',
                                prefixIcon: const Icon(
                                  Icons.search,
                                  color: Color(0xFF0D1845),
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Color(0xFFDEE2E6),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Color(0xFFDEE2E6),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(
                                    color: Color(0xFF0D1845),
                                    width: 2,
                                  ),
                                ),
                                filled: true,
                                fillColor: Colors.white,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                              ),
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
                            flex: 2,
                            child: Text('Customer Name', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text('CNIC', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text('Phone', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text('Email', style: _headerStyle()),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            flex: 2,
                            child: Text('City', style: _headerStyle()),
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
                                    onPressed: _isRetrying ? null : _retryFetch,
                                    child: _isRetrying
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                        : const Text('Retry'),
                                  ),
                                ],
                              ),
                            )
                          : _filteredCustomers.isEmpty
                          ? const Center(
                              child: Text(
                                'No customers found',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey,
                                ),
                              ),
                            )
                          : ListView.builder(
                              itemCount: _filteredCustomers.length,
                              itemBuilder: (context, index) {
                                final customer = _filteredCustomers[index];
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey[200]!,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            Container(
                                              width: 32,
                                              height: 32,
                                              decoration: BoxDecoration(
                                                color: Color(
                                                  0xFF0D1845,
                                                ).withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Icon(
                                                Icons.person,
                                                color: Color(0xFF0D1845),
                                                size: 16,
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Expanded(
                                              child: Text(
                                                customer['name']?.toString() ??
                                                    'N/A',
                                                style: _cellStyle(),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          customer['cnic']?.toString() ?? 'N/A',
                                          style: _cellStyle(),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          customer['cell_no1']?.toString() ??
                                              'N/A',
                                          style: _cellStyle(),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          customer['email']?.toString() ??
                                              'N/A',
                                          style: _cellStyle(),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          _getCityDisplayText(customer['city']),
                                          style: _cellStyle(),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.start,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.visibility,
                                                color: const Color(0xFF0D1845),
                                                size: 18,
                                              ),
                                              onPressed: () =>
                                                  _showViewCustomerDialog(
                                                    customer,
                                                  ),
                                              tooltip: 'View Details',
                                              padding: const EdgeInsets.all(6),
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.edit,
                                                color: Colors.blue,
                                                size: 18,
                                              ),
                                              onPressed: () =>
                                                  _showEditCustomerDialog(
                                                    customer,
                                                  ),
                                              tooltip: 'Edit',
                                              padding: const EdgeInsets.all(6),
                                              constraints:
                                                  const BoxConstraints(),
                                            ),
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete,
                                                color: Colors.red,
                                                size: 18,
                                              ),
                                              onPressed: () =>
                                                  _deleteCustomer(customer),
                                              tooltip: 'Delete',
                                              padding: const EdgeInsets.all(6),
                                              constraints:
                                                  const BoxConstraints(),
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

                    // Enhanced Pagination
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Previous button
                          ElevatedButton.icon(
                            onPressed: _currentPage > 1
                                ? () => _changePage(_currentPage - 1)
                                : null,
                            icon: Icon(Icons.chevron_left, size: 14),
                            label: Text(
                              'Previous',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: _currentPage > 1
                                  ? Color(0xFF17A2B8)
                                  : Color(0xFF6C757D),
                              elevation: 0,
                              side: BorderSide(color: Color(0xFFDEE2E6)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),

                          // Page numbers
                          ..._buildPageButtons(),

                          const SizedBox(width: 8),

                          // Next button
                          ElevatedButton.icon(
                            onPressed: _currentPage < _totalPages
                                ? () => _changePage(_currentPage + 1)
                                : null,
                            icon: Icon(Icons.chevron_right, size: 14),
                            label: Text('Next', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _currentPage < _totalPages
                                  ? Color(0xFF17A2B8)
                                  : Colors.grey.shade300,
                              foregroundColor: _currentPage < _totalPages
                                  ? Colors.white
                                  : Colors.grey.shade600,
                              elevation: _currentPage < _totalPages ? 2 : 0,
                              side: _currentPage < _totalPages
                                  ? null
                                  : BorderSide(color: Color(0xFFDEE2E6)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                          ),

                          // Page info
                          const SizedBox(width: 16),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Page $_currentPage of $_totalPages (${_allFilteredCustomers.length} total)',
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

  List<Widget> _buildPageButtons() {
    final totalPages = _totalPages;
    final current = _currentPage;

    // Show max 5 page buttons centered around current page
    const maxButtons = 5;
    final halfRange = maxButtons ~/ 2; // 2

    // Calculate desired start and end
    int startPage = (current - halfRange).clamp(1, totalPages);
    int endPage = (startPage + maxButtons - 1).clamp(1, totalPages);

    // If endPage exceeds totalPages, adjust startPage
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

  TextStyle _headerStyle() {
    return const TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.bold,
      color: Color(0xFF343A40),
    );
  }

  TextStyle _cellStyle() {
    return const TextStyle(fontSize: 13, color: Color(0xFF6C757D));
  }

  String _getCityDisplayText(dynamic city) {
    if (city == null) return 'N/A';

    // If city is a Map/object, extract the 'title' or 'name' field
    if (city is Map<String, dynamic>) {
      return city['title']?.toString() ?? city['name']?.toString() ?? 'N/A';
    }

    // If city is a string or int (likely an ID), try to resolve it to a name
    if (city is String || city is int) {
      final cityId = city.toString();
      final found = _cities.firstWhere(
        (c) => c['id'].toString() == cityId,
        orElse: () => {},
      );
      if (found.isNotEmpty) {
        return found['title']?.toString() ?? 'N/A';
      }
    }

    // If city is already a string (name), return it as is
    return city.toString();
  }

  // Fetch available cities from CityService with a fallback to a small sample list
  Future<List<Map<String, dynamic>>> _fetchAvailableCities() async {
    try {
      final cityResponse = await CityService.getAllCities(
        page: 1,
        perPage: 1000,
      );
      // CityResponse.data is a List<City>
      final cities = cityResponse.data
          .map((c) => {"id": c.id, "title": c.title})
          .toList();
      if (cities.isNotEmpty) return cities;
    } catch (e) {
      print('Error fetching cities for customer form: $e');
    }

    // Fallback sample list if API fails or returns empty
    return const [
      {"id": 1, "title": "Hermannhaven"},
      {"id": 2, "title": "North Maraton"},
      {"id": 3, "title": "New Ashton"},
      {"id": 4, "title": "Lake Gussieborough"},
      {"id": 5, "title": "East Vidal"},
    ];
  }
}

// Customer Detail Dialog
class CustomerDetailDialog extends StatelessWidget {
  final Map<String, dynamic> customer;
  final List<Map<String, dynamic>> cities;

  const CustomerDetailDialog({
    super.key,
    required this.customer,
    required this.cities,
  });

  String _getCityDisplayText(dynamic city) {
    if (city == null) return 'N/A';

    // If city is a Map/object, extract the 'title' or 'name' field
    if (city is Map<String, dynamic>) {
      return city['title']?.toString() ?? city['name']?.toString() ?? 'N/A';
    }

    // If city is a string or int (likely an ID), try to resolve it to a name
    if (city is String || city is int) {
      final cityId = city.toString();
      final found = cities.firstWhere(
        (c) => c['id'].toString() == cityId,
        orElse: () => {},
      );
      if (found.isNotEmpty) {
        return found['title']?.toString() ?? 'N/A';
      }
    }

    // If city is already a string (name), return it as is
    return city.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, const Color(0xFFF8F9FA)],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.blue.shade400, Colors.blue.shade600],
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.blue.shade400.withOpacity(0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Icon(Icons.person, color: Colors.white, size: 30),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer['name']?.toString() ?? 'Unknown Customer',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.badge,
                              color: Colors.white.withOpacity(0.8),
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'ID: ${customer['id']?.toString() ?? 'N/A'}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close, color: Colors.white),
                      tooltip: 'Close',
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Basic Information Section
                    _buildSectionHeader(
                      'Basic Information',
                      Icons.info,
                      Colors.blue,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildDetailCard(
                                  'CNIC',
                                  customer['cnic']?.toString() ?? 'N/A',
                                  Icons.credit_card,
                                  Colors.orange,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDetailCard(
                                  'Primary Phone',
                                  customer['cell_no1']?.toString() ?? 'N/A',
                                  Icons.phone,
                                  Colors.green,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDetailCard(
                                  'Secondary Phone',
                                  customer['cell_no2']?.toString() ?? 'N/A',
                                  Icons.phone_android,
                                  Colors.blue,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDetailCard(
                                  'Email',
                                  customer['email']?.toString() ?? 'N/A',
                                  Icons.email,
                                  Colors.purple,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildDetailCard(
                            'Address',
                            customer['address']?.toString() ?? 'N/A',
                            Icons.location_on,
                            Colors.red,
                            isFullWidth: true,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildDetailCard(
                                  'City',
                                  _getCityDisplayText(customer['city']),
                                  Icons.location_city,
                                  Colors.teal,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // Security Person Section
                    _buildSectionHeader(
                      'Security Person Details',
                      Icons.security,
                      Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: _buildDetailCard(
                                  'Name',
                                  customer['RefName']?.toString() ??
                                      customer['name2']?.toString() ??
                                      'N/A',
                                  Icons.person_outline,
                                  Colors.indigo,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildDetailCard(
                                  'CNIC',
                                  customer['RefCnic']?.toString() ??
                                      customer['cnic2']?.toString() ??
                                      'N/A',
                                  Icons.badge,
                                  Colors.amber,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildDetailCard(
                            'Phone',
                            customer['cell_no3']?.toString() ?? 'N/A',
                            Icons.phone_in_talk,
                            Colors.cyan,
                            isFullWidth: true,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Close'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF343A40),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCard(
    String label,
    String value,
    IconData icon,
    Color color, {
    bool isFullWidth = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.2), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Color(0xFF343A40),
              fontWeight: FontWeight.w500,
            ),
            maxLines: isFullWidth ? 3 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// Customer Form Dialog (Create/Edit)
class CustomerFormDialog extends StatefulWidget {
  final Map<String, dynamic>? customer; // null for create, populated for edit
  final List<Map<String, dynamic>> cities; // List of available cities

  const CustomerFormDialog({super.key, this.customer, required this.cities});

  @override
  State<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends State<CustomerFormDialog> {
  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _cnicController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  String? _selectedCityId; // Changed from TextEditingController to String
  final _cellNo1Controller = TextEditingController();
  final _cellNo2Controller = TextEditingController();
  final _name2Controller = TextEditingController();
  final _cnic2Controller = TextEditingController();
  final _cellNo3Controller = TextEditingController();
  final _statusController = TextEditingController();

  bool _isLoading = false;
  bool _isEdit = false;

  @override
  void initState() {
    super.initState();

    // Initialize local mutable city list from the passed cities so we can
    // add newly-created cities locally (without requiring parent refresh).
    _localCities = List<Map<String, dynamic>>.from(widget.cities);

    _isEdit = widget.customer != null;

    if (_isEdit && widget.customer != null) {
      // Populate form with existing data
      final customer = widget.customer!;
      _cnicController.text = customer['cnic']?.toString() ?? '';
      _nameController.text = customer['name']?.toString() ?? '';
      _emailController.text = customer['email']?.toString() ?? '';
      _addressController.text = customer['address']?.toString() ?? '';

      // Handle city selection - check both city_id field and city object
      if (customer['city_id'] != null) {
        _selectedCityId = customer['city_id'].toString();
      } else if (customer['city'] is Map<String, dynamic> &&
          customer['city']['id'] != null) {
        _selectedCityId = customer['city']['id'].toString();
        // Ensure the city is in the local cities list for proper display
        final cityData = customer['city'];
        final cityExists = _localCities.any(
          (c) => c['id'].toString() == _selectedCityId,
        );
        if (!cityExists) {
          _localCities.insert(0, {
            'id': cityData['id'],
            'title': cityData['name'] ?? cityData['title'] ?? 'Unknown City',
          });
        }
      } else {
        _selectedCityId = null;
      }

      _cellNo1Controller.text = customer['cell_no1']?.toString() ?? '';
      _cellNo2Controller.text = customer['cell_no2']?.toString() ?? '';
      // Handle both API response format (RefName, RefCnic) and form format (name2, cnic2)
      _name2Controller.text =
          customer['RefName']?.toString() ??
          customer['name2']?.toString() ??
          '';
      _cnic2Controller.text =
          customer['RefCnic']?.toString() ??
          customer['cnic2']?.toString() ??
          '';
      _cellNo3Controller.text = customer['cell_no3']?.toString() ?? '';
      _statusController.text = customer['status']?.toString() ?? 'active';
    } else {
      // Default values for create
      _statusController.text = 'active';
      _selectedCityId = null; // No default city selected
    }
  }

  @override
  void dispose() {
    _cnicController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _cellNo1Controller.dispose();
    _cellNo2Controller.dispose();
    _name2Controller.dispose();
    _cnic2Controller.dispose();
    _cellNo3Controller.dispose();
    _statusController.dispose();
    super.dispose();
  }

  // Local mutable copy of cities passed from parent
  late List<Map<String, dynamic>> _localCities;

  // Show a searchable city selection dialog that matches the Add Vendor UI
  Future<void> _showCitySearchDialog() async {
    List<Map<String, dynamic>> filteredCities = List.from(_localCities);
    final TextEditingController searchController = TextEditingController();

    final selectedCity = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            void _filterCities(String query) {
              setState(() {
                if (query.isEmpty) {
                  filteredCities = List.from(_localCities);
                } else {
                  final searchQuery = query.toLowerCase();
                  filteredCities = _localCities.where((city) {
                    final title = (city['title'] ?? '')
                        .toString()
                        .toLowerCase();
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
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0D1845).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            Icons.location_city,
                            color: Color(0xFF0D1845),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Select City',
                            style: Theme.of(context).textTheme.titleLarge
                                ?.copyWith(
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black87,
                                ),
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF28A745),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: IconButton(
                            onPressed: () async {
                              final created = await _showAddCityDialog();
                              if (created != null) {
                                Navigator.of(context).pop(created);
                              }
                            },
                            icon: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 20,
                            ),
                            tooltip: 'Add New City',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

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
                          hintText: 'Search by city name...',
                          prefixIcon: const Icon(
                            Icons.search,
                            color: Color(0xFF0D1845),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                        onChanged: _filterCities,
                      ),
                    ),
                    const SizedBox(height: 20),

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
                        child: filteredCities.isEmpty
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
                                        'No cities found',
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
                                itemCount: filteredCities.length,
                                itemBuilder: (context, index) {
                                  final city = filteredCities[index];
                                  final isSelected =
                                      city['id'].toString() == _selectedCityId;

                                  return InkWell(
                                    onTap: () {
                                      Navigator.of(context).pop(city);
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
                                            index < filteredCities.length - 1
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
                                                  city['title']?.toString() ??
                                                      'Untitled',
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
                                                  city.containsKey('state') &&
                                                          city['state'] is Map
                                                      ? '${city['state']['title'] ?? ''}, ${city['state']['country']?['title'] ?? ''}'
                                                      : '',
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

    if (selectedCity != null && mounted) {
      setState(() {
        // Ensure the city is present in local list
        final exists = _localCities.any((c) => c['id'] == selectedCity['id']);
        if (!exists) _localCities.insert(0, selectedCity);
        _selectedCityId = selectedCity['id'].toString();
      });
    }
  }

  // Show a small dialog to add a new city (calls CityService.createCity)
  Future<Map<String, dynamic>?> _showAddCityDialog() async {
    final TextEditingController cityController = TextEditingController();
    final GlobalKey<FormState> cityFormKey = GlobalKey<FormState>();
    bool isAdding = false;

    final created = await showDialog<Map<String, dynamic>?>(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              title: const Text('Add New City'),
              content: Form(
                key: cityFormKey,
                child: TextFormField(
                  controller: cityController,
                  decoration: const InputDecoration(
                    labelText: 'City Name',
                    hintText: 'Enter city name',
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Please enter city name'
                      : null,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isAdding
                      ? null
                      : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: isAdding
                      ? null
                      : () async {
                          if (!cityFormKey.currentState!.validate()) return;
                          setState(() => isAdding = true);
                          try {
                            final response = await CityService.createCity(
                              title: cityController.text.trim(),
                              stateId: 1,
                              status: 'active',
                            );
                            if (response.success) {
                              final city = response.data;
                              final cityMap = {
                                'id': city.id,
                                'title': city.title,
                                'state': {
                                  'title': city.state.title,
                                  'country': {
                                    'title': city.state.country.title,
                                  },
                                },
                              };
                              // Insert locally so the search dialog can show it
                              if (mounted) {
                                setState(() {
                                  _localCities.insert(0, cityMap);
                                });
                                Navigator.of(context).pop(cityMap);
                              }
                            } else {
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Failed to create city'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                              }
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Failed to create city: $e'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } finally {
                            if (mounted) setState(() => isAdding = false);
                          }
                        },
                  child: isAdding
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Add City'),
                ),
              ],
            );
          },
        );
      },
    );

    return created;
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    // Validate that security person CNIC is different from primary CNIC
    final primaryCnicTrim = _cnicController.text.trim();
    final secCnicTrim = _cnic2Controller.text.trim();
    if (secCnicTrim.isNotEmpty && secCnicTrim == primaryCnicTrim) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '❌ Security person CNIC must be different from primary CNIC',
          ),
          backgroundColor: Colors.orange,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      // Build customer data - send null for empty optional fields
      final String? cnicToSend = _cnicController.text.trim().isNotEmpty
          ? _cnicController.text.trim()
          : null;
      final String nameToSend = _nameController.text.trim();
      final String? emailToSend = _emailController.text.trim().isNotEmpty
          ? _emailController.text.trim().toLowerCase()
          : null;
      final String? addressToSend = _addressController.text.trim().isNotEmpty
          ? _addressController.text.trim()
          : null;
      final int? cityIdToSend = _selectedCityId == null
          ? null
          : int.tryParse(_selectedCityId!);
      final String? cell1ToSend =
          _cellNo1Controller.text.replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty
          ? _cellNo1Controller.text.replaceAll(RegExp(r'[^0-9]'), '')
          : null;
      final String? cell2ToSend =
          _cellNo2Controller.text.replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty
          ? _cellNo2Controller.text.replaceAll(RegExp(r'[^0-9]'), '')
          : null;
      final String name2ToSend = _name2Controller.text.trim();
      final String? cnic2ToSend = _cnic2Controller.text.trim().isNotEmpty
          ? _cnic2Controller.text.trim()
          : null;
      final String? cell3ToSend =
          _cellNo3Controller.text.replaceAll(RegExp(r'[^0-9]'), '').isNotEmpty
          ? _cellNo3Controller.text.replaceAll(RegExp(r'[^0-9]'), '')
          : null;

      final Map<String, dynamic> customerData = {
        'cnic': cnicToSend,
        'name': nameToSend,
        'email': emailToSend,
        'address': addressToSend,
        'city_id': cityIdToSend,
        'cell_no1': cell1ToSend,
        'cell_no2': cell2ToSend,
        'image_path': 'default.png',
        'status': _statusController.text,
        'name2': name2ToSend.isNotEmpty ? name2ToSend : null,
        'cnic2': cnic2ToSend,
        'cell_no3': cell3ToSend,
      };

      if (_isEdit) {
        final updated = await CreditCustomerService.updateCreditCustomer(
          widget.customer!['id'].toString(),
          customerData,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Customer updated successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          // Return the updated customer map so callers can use it if needed
          Navigator.of(context).pop(updated);
        }
      } else {
        final created = await CreditCustomerService.createCreditCustomer(
          customerData,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✓ Customer created successfully'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
          // Return the created customer map so callers (e.g., POS) can auto-select it
          Navigator.of(context).pop(created);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });

        // Parse error message
        String errorMessage = _parseErrorMessage(e.toString());

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Dismiss',
              textColor: Colors.white,
              onPressed: () {},
            ),
          ),
        );

        // Don't close dialog on error, let user fix the issue
      }
    }
  }

  String _parseErrorMessage(String errorString) {
    // Check for common database errors
    if (errorString.contains('Data too long for column')) {
      if (errorString.contains("'cell_no1'")) {
        return '❌ Primary phone number is too long. Maximum 11 digits allowed.';
      } else if (errorString.contains("'cell_no2'")) {
        return '❌ Secondary phone number is too long. Maximum 11 digits allowed.';
      } else if (errorString.contains("'cell_no3'")) {
        return '❌ Security person phone is too long. Maximum 11 digits allowed.';
      } else if (errorString.contains("'cnic'")) {
        return '❌ CNIC is too long. Must be 13 digits with dashes.';
      } else if (errorString.contains("'cnic2'")) {
        return '❌ Security person CNIC is too long. Must be 13 digits with dashes.';
      } else if (errorString.contains("'name'")) {
        return '❌ Name is too long. Please shorten the name.';
      } else if (errorString.contains("'name2'")) {
        return '❌ Security person name is too long. Please shorten the name.';
      } else if (errorString.contains("'email'")) {
        return '❌ Email is too long. Please use a shorter email.';
      } else if (errorString.contains("'address'")) {
        return '❌ Address is too long. Please shorten the address.';
      }
      return '❌ One or more fields exceed maximum length. Please check your input.';
    }

    if (errorString.contains('Duplicate entry')) {
      if (errorString.contains('customers_cnic_unique') ||
          errorString.contains("for key 'cnic'")) {
        return '❌ This CNIC has already been taken. Please use a different CNIC.';
      } else if (errorString.contains('customers_cnic2_unique') ||
          errorString.contains("for key 'cnic2'")) {
        return '❌ This security person CNIC has already been taken. Please use a different CNIC.';
      } else if (errorString.contains('customers_email_unique') ||
          errorString.contains("for key 'email'")) {
        return '❌ This email has already been taken. Please use a different email.';
      }
      return '❌ Duplicate entry detected. This CNIC or email has already been taken.';
    }

    if (errorString.contains('Cannot add or update a child row') ||
        errorString.contains('foreign key constraint')) {
      return '❌ Invalid city selected. Please select a valid city from the dropdown.';
    }

    if (errorString.contains('Connection') ||
        errorString.contains('timeout') ||
        errorString.contains('Network')) {
      return '❌ Network error. Please check your internet connection and try again.';
    }

    if (errorString.contains('500')) {
      return '❌ Server error. Please try again later or contact support.';
    }

    if (errorString.contains('401') ||
        errorString.contains('Unauthenticated')) {
      return '❌ Session expired. Please login again.';
    }

    if (errorString.contains('403') || errorString.contains('Forbidden')) {
      return '❌ You do not have permission to perform this action.';
    }

    // Generic error with first 100 characters
    if (errorString.length > 100) {
      return '❌ Error: ${errorString.substring(0, 100)}...';
    }

    return '❌ Error: $errorString';
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 800,
        height: 700,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _isEdit ? Icons.edit : Icons.person_add,
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
                          _isEdit ? 'Edit Customer' : 'Create New Customer',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          _isEdit
                              ? 'Update customer information'
                              : 'Add a new customer to the system',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                      padding: const EdgeInsets.all(8),
                    ),
                  ),
                ],
              ),
            ),

            // Form Content
            Expanded(
              child: Form(
                key: _formKey,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Basic Information Section
                      _buildSectionHeader(
                        'Basic Information',
                        Icons.person,
                        Colors.blue,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.blue.shade200,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildFormField(
                                    controller: _cnicController,
                                    label: 'CNIC',
                                    hint: '12345-6789012-3',
                                    icon: Icons.badge,
                                    color: Colors.blue,
                                    inputFormatters: [CnicInputFormatter()],
                                    validator: (v) =>
                                        FormValidators.validateCnic(
                                          v,
                                          isOptional: true,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildFormField(
                                    controller: _nameController,
                                    label: 'Full Name *',
                                    hint: 'Enter full name',
                                    icon: Icons.person_outline,
                                    color: Colors.blue,
                                    validator: FormValidators.validateName,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: _buildFormField(
                                    controller: _emailController,
                                    label: 'Email Address',
                                    hint: 'email@example.com',
                                    icon: Icons.email,
                                    color: Colors.blue,
                                    keyboardType: TextInputType.emailAddress,
                                    validator: (v) =>
                                        FormValidators.validateEmail(
                                          v,
                                          isOptional: true,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(child: _buildCityDropdown()),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildFormField(
                              controller: _addressController,
                              label: 'Address',
                              hint: 'Enter full address',
                              icon: Icons.home,
                              color: Colors.blue,
                              maxLines: 3,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty)
                                  return null;
                                if (value.trim().length < 10)
                                  return 'Address must be at least 10 characters';
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Contact Information Section
                      _buildSectionHeader(
                        'Contact Information',
                        Icons.phone,
                        Colors.green,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.green.shade200,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildFormField(
                                    controller: _cellNo1Controller,
                                    label: 'Primary Phone *',
                                    hint: '03001234567',
                                    icon: Icons.phone_in_talk,
                                    color: Colors.green,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [PhoneInputFormatter()],
                                    validator: FormValidators.validatePhone,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildFormField(
                                    controller: _cellNo2Controller,
                                    label: 'Secondary Phone',
                                    hint: '03012345678',
                                    icon: Icons.phone_android,
                                    color: Colors.green,
                                    keyboardType: TextInputType.phone,
                                    inputFormatters: [PhoneInputFormatter()],
                                    validator: (v) =>
                                        FormValidators.validatePhone(
                                          v,
                                          isOptional: true,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Security Person Section
                      _buildSectionHeader(
                        'Security Person Details (Optional)',
                        Icons.security,
                        Colors.purple,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.purple.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.purple.shade200,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: _buildFormField(
                                    controller: _name2Controller,
                                    label: 'Security Person Name',
                                    hint: 'Enter security person name',
                                    icon: Icons.person_pin,
                                    color: Colors.purple,
                                    validator: (v) =>
                                        FormValidators.validateName(
                                          v,
                                          isOptional: true,
                                        ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: _buildFormField(
                                    controller: _cnic2Controller,
                                    label: 'Security Person CNIC',
                                    hint: '13345-1234567-1',
                                    icon: Icons.badge,
                                    color: Colors.purple,
                                    inputFormatters: [CnicInputFormatter()],
                                    validator: (v) =>
                                        FormValidators.validateCnic(
                                          v,
                                          isOptional: true,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            _buildFormField(
                              controller: _cellNo3Controller,
                              label: 'Security Person Phone',
                              hint: '03023456789',
                              icon: Icons.phone,
                              color: Colors.purple,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [PhoneInputFormatter()],
                              validator: (v) => FormValidators.validatePhone(
                                v,
                                isOptional: true,
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Additional Settings Section
                      _buildSectionHeader(
                        'Additional Settings',
                        Icons.settings,
                        Colors.amber,
                      ),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.amber.shade200,
                            width: 1,
                          ),
                        ),
                        child: DropdownButtonFormField<String>(
                          value: _statusController.text.isEmpty
                              ? 'active'
                              : _statusController.text,
                          decoration: InputDecoration(
                            labelText: 'Status',
                            prefixIcon: Icon(
                              Icons.toggle_on,
                              color: Colors.amber,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.amber.withOpacity(0.3),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.amber.withOpacity(0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Colors.amber,
                                width: 2,
                              ),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 16,
                            ),
                          ),
                          items: const ['active', 'inactive'].map((
                            String value,
                          ) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value.toUpperCase()),
                            );
                          }).toList(),
                          onChanged: (String? newValue) {
                            if (newValue != null) {
                              _statusController.text = newValue;
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitForm,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Icon(_isEdit ? Icons.save : Icons.add),
                    label: Text(
                      _isEdit ? 'Update Customer' : 'Create Customer',
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      backgroundColor: const Color(0xFF0D1845),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
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

  Widget _buildSectionHeader(String title, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF343A40),
          ),
        ),
      ],
    );
  }

  Widget _buildFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required Color color,
    TextInputType? keyboardType,
    int maxLines = 1,
    String? Function(String?)? validator,
    List<TextInputFormatter>? inputFormatters,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      maxLines: maxLines,
      validator: validator,
      inputFormatters: inputFormatters,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(icon, color: color),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color.withOpacity(0.3)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color.withOpacity(0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: color, width: 2),
        ),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
      ),
    );
  }

  Widget _buildCityDropdown() {
    // Use a FormField wrapper so we can validate the city selection while
    // using a vendor-style searchable dialog for selection.
    return FormField<String>(
      initialValue: _selectedCityId,
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please select a city';
        return null;
      },
      builder: (field) {
        // Find selected city title from the local list
        String displayText = 'Select City *';
        try {
          final found = _localCities.firstWhere(
            (c) => c['id'].toString() == _selectedCityId,
            orElse: () => {},
          );
          if (found.isNotEmpty) {
            displayText =
                '${found['title']}${found.containsKey('state') && found['state'] is Map ? ', ${found['state']['title'] ?? ''}' : ''}';
          }
        } catch (e) {
          // ignore
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: OutlinedButton(
                onPressed: () async {
                  await _showCitySearchDialog();
                  // Notify the FormField about the change so validation updates
                  field.didChange(_selectedCityId);
                },
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  backgroundColor: Colors.white,
                  side: BorderSide.none,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  alignment: Alignment.centerLeft,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        displayText,
                        style: TextStyle(
                          color: _selectedCityId != null
                              ? Colors.black87
                              : Colors.grey[700],
                          fontSize: 14,
                          fontWeight: _selectedCityId != null
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
            if (field.errorText != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  field.errorText!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 12),
                ),
              ),
          ],
        );
      },
    );
  }
}
