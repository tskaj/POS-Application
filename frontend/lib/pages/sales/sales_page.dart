import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class SalesPage extends StatefulWidget {
  const SalesPage({super.key});

  @override
  State<SalesPage> createState() => _SalesPageState();
}

class _SalesPageState extends State<SalesPage> {
  // Mock data for demonstration - in real app this would come from API
  List<Map<String, dynamic>> _sales = [];
  List<Map<String, dynamic>> _selectedSales = [];
  bool _selectAll = false;

  // Filter states
  String _selectedCustomer = 'All';
  String _selectedStatus = 'All';
  String _selectedPaymentStatus = 'All';
  String _selectedBiller = 'All';
  String _sortBy = 'Last 7 Days';

  @override
  void initState() {
    super.initState();
    _loadMockSales();
  }

  void _loadMockSales() {
    // Mock sales data with comprehensive dummy data
    _sales = [
      {
        'id': '1',
        'reference': 'SALE-2025-001',
        'date': DateTime(2025, 10, 8),
        'customer': 'Carl Evans',
        'status': 'Completed',
        'grandTotal': 2500.0,
        'paidAmount': 2500.0,
        'dueAmount': 0.0,
        'paymentStatus': 'Paid',
        'biller': 'John Smith',
      },
      {
        'id': '2',
        'reference': 'SALE-2025-002',
        'date': DateTime(2025, 10, 7),
        'customer': 'Minerva Rameriz',
        'status': 'Pending',
        'grandTotal': 1800.0,
        'paidAmount': 900.0,
        'dueAmount': 900.0,
        'paymentStatus': 'Partial',
        'biller': 'Sarah Johnson',
      },
      {
        'id': '3',
        'reference': 'SALE-2025-003',
        'date': DateTime(2025, 10, 6),
        'customer': 'Robert Lamon',
        'status': 'Completed',
        'grandTotal': 3200.0,
        'paidAmount': 3200.0,
        'dueAmount': 0.0,
        'paymentStatus': 'Paid',
        'biller': 'Mike Davis',
      },
      {
        'id': '4',
        'reference': 'SALE-2025-004',
        'date': DateTime(2025, 10, 5),
        'customer': 'Mark Joslyn',
        'status': 'Cancelled',
        'grandTotal': 1500.0,
        'paidAmount': 0.0,
        'dueAmount': 1500.0,
        'paymentStatus': 'Unpaid',
        'biller': 'Lisa Wilson',
      },
      {
        'id': '5',
        'reference': 'SALE-2025-005',
        'date': DateTime(2025, 10, 4),
        'customer': 'Patricia Lewis',
        'status': 'Completed',
        'grandTotal': 950.0,
        'paidAmount': 950.0,
        'dueAmount': 0.0,
        'paymentStatus': 'Paid',
        'biller': 'Tom Brown',
      },
      {
        'id': '6',
        'reference': 'SALE-2025-006',
        'date': DateTime(2025, 10, 3),
        'customer': 'Daniel Jude',
        'status': 'Pending',
        'grandTotal': 2100.0,
        'paidAmount': 1050.0,
        'dueAmount': 1050.0,
        'paymentStatus': 'Partial',
        'biller': 'Alex Chen',
      },
      {
        'id': '7',
        'reference': 'SALE-2025-007',
        'date': DateTime(2025, 10, 2),
        'customer': 'Emma Bates',
        'status': 'Completed',
        'grandTotal': 1750.0,
        'paidAmount': 1750.0,
        'dueAmount': 0.0,
        'paymentStatus': 'Paid',
        'biller': 'Jessica Taylor',
      },
      {
        'id': '8',
        'reference': 'SALE-2025-008',
        'date': DateTime(2025, 10, 1),
        'customer': 'Richard Fralick',
        'status': 'Processing',
        'grandTotal': 2800.0,
        'paidAmount': 1400.0,
        'dueAmount': 1400.0,
        'paymentStatus': 'Partial',
        'biller': 'Kevin Martinez',
      },
      {
        'id': '9',
        'reference': 'SALE-2025-009',
        'date': DateTime(2025, 9, 30),
        'customer': 'Michelle Robison',
        'status': 'Completed',
        'grandTotal': 1200.0,
        'paidAmount': 1200.0,
        'dueAmount': 0.0,
        'paymentStatus': 'Paid',
        'biller': 'Amanda Garcia',
      },
      {
        'id': '10',
        'reference': 'SALE-2025-010',
        'date': DateTime(2025, 9, 29),
        'customer': 'Marsha Betts',
        'status': 'Pending',
        'grandTotal': 850.0,
        'paidAmount': 0.0,
        'dueAmount': 850.0,
        'paymentStatus': 'Unpaid',
        'biller': 'David Rodriguez',
      },
      {
        'id': '11',
        'reference': 'SALE-2025-011',
        'date': DateTime(2025, 9, 28),
        'customer': 'John Smith',
        'status': 'Completed',
        'grandTotal': 1950.0,
        'paidAmount': 1950.0,
        'dueAmount': 0.0,
        'paymentStatus': 'Paid',
        'biller': 'John Smith',
      },
      {
        'id': '12',
        'reference': 'SALE-2025-012',
        'date': DateTime(2025, 9, 27),
        'customer': 'Sarah Johnson',
        'status': 'Cancelled',
        'grandTotal': 750.0,
        'paidAmount': 0.0,
        'dueAmount': 750.0,
        'paymentStatus': 'Unpaid',
        'biller': 'Sarah Johnson',
      },
    ];
  }

  void _toggleSaleSelection(Map<String, dynamic> sale) {
    setState(() {
      final saleId = sale['id'];
      final existingIndex = _selectedSales.indexWhere((s) => s['id'] == saleId);

      if (existingIndex >= 0) {
        _selectedSales.removeAt(existingIndex);
      } else {
        _selectedSales.add(Map<String, dynamic>.from(sale));
      }

      _updateSelectAllState();
    });
  }

  void _toggleSelectAll() {
    setState(() {
      if (_selectAll) {
        _selectedSales.clear();
      } else {
        _selectedSales = List.from(_getFilteredSales());
      }
      _selectAll = !_selectAll;
    });
  }

  void _updateSelectAllState() {
    final filteredSales = _getFilteredSales();
    _selectAll =
        filteredSales.isNotEmpty &&
        _selectedSales.length == filteredSales.length;
  }

  List<Map<String, dynamic>> _getFilteredSales() {
    return _sales.where((sale) {
      final customerMatch =
          _selectedCustomer == 'All' || sale['customer'] == _selectedCustomer;
      final statusMatch =
          _selectedStatus == 'All' || sale['status'] == _selectedStatus;
      final paymentMatch =
          _selectedPaymentStatus == 'All' ||
          sale['paymentStatus'] == _selectedPaymentStatus;
      final billerMatch =
          _selectedBiller == 'All' || sale['biller'] == _selectedBiller;

      // Date filtering based on sortBy
      bool dateMatch = true;
      if (_sortBy == 'Last 7 Days') {
        final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
        dateMatch = sale['date'].isAfter(sevenDaysAgo);
      }

      return customerMatch &&
          statusMatch &&
          paymentMatch &&
          billerMatch &&
          dateMatch;
    }).toList();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Completed':
        return Colors.green;
      case 'Pending':
        return Colors.orange;
      case 'Processing':
        return Colors.blue;
      case 'Cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getPaymentStatusColor(String status) {
    switch (status) {
      case 'Paid':
        return Colors.green;
      case 'Unpaid':
        return Colors.red;
      case 'Partial':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredSales = _getFilteredSales();

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, const Color(0xFFF8F9FA)],
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Header - Matching Product List Page Design
            Container(
              padding: const EdgeInsets.all(24),
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
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.shopping_cart,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sales',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Manage and track all sales transactions',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      // TODO: Implement add sale functionality
                    },
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('New Sale'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D1845),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Enhanced Filters Section - Matching Product List Page Design
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.08),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Customer Filter
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
                                    Icons.person,
                                    size: 16,
                                    color: Color(0xFF0D1845),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Filter by Customer',
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
                              child: DropdownButtonFormField<String>(
                                value: _selectedCustomer,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText: 'Select customer',
                                  hintStyle: TextStyle(
                                    color: Color(0xFFADB5BD),
                                    fontSize: 14,
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
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                items:
                                    [
                                          'All',
                                          'Carl Evans',
                                          'Minerva Rameriz',
                                          'Robert Lamon',
                                          'Mark Joslyn',
                                          'Patricia Lewis',
                                          'Daniel Jude',
                                          'Emma Bates',
                                          'Richard Fralick',
                                          'Michelle Robison',
                                          'Marsha Betts',
                                          'John Smith',
                                          'Sarah Johnson',
                                        ]
                                        .map(
                                          (customer) => DropdownMenuItem(
                                            value: customer,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  customer == 'All'
                                                      ? Icons.group
                                                      : Icons.person,
                                                  color: customer == 'All'
                                                      ? Color(0xFF6C757D)
                                                      : Color(0xFF0D1845),
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  customer,
                                                  style: TextStyle(
                                                    color: Color(0xFF343A40),
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
                                      _selectedCustomer = value;
                                      _updateSelectAllState();
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Status Filter
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
                                    Icons.info,
                                    size: 16,
                                    color: Color(0xFF0D1845),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Filter by Status',
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
                              child: DropdownButtonFormField<String>(
                                value: _selectedStatus,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText: 'Select status',
                                  hintStyle: TextStyle(
                                    color: Color(0xFFADB5BD),
                                    fontSize: 14,
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
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                items:
                                    [
                                          'All',
                                          'Completed',
                                          'Pending',
                                          'Processing',
                                          'Cancelled',
                                        ]
                                        .map(
                                          (status) => DropdownMenuItem(
                                            value: status,
                                            child: Row(
                                              children: [
                                                Icon(
                                                  status == 'All'
                                                      ? Icons
                                                            .inventory_2_rounded
                                                      : status == 'Completed'
                                                      ? Icons
                                                            .check_circle_rounded
                                                      : status == 'Pending'
                                                      ? Icons.pending
                                                      : status == 'Processing'
                                                      ? Icons.hourglass_top
                                                      : Icons.cancel_rounded,
                                                  color: status == 'All'
                                                      ? Color(0xFF6C757D)
                                                      : status == 'Completed'
                                                      ? Color(0xFF28A745)
                                                      : status == 'Pending'
                                                      ? Color(0xFFFFA726)
                                                      : status == 'Processing'
                                                      ? Color(0xFF007BFF)
                                                      : Color(0xFFDC3545),
                                                  size: 18,
                                                ),
                                                SizedBox(width: 8),
                                                Text(
                                                  status,
                                                  style: TextStyle(
                                                    color: Color(0xFF343A40),
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
                                      _selectedStatus = value;
                                      _updateSelectAllState();
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 20),
                      // Payment Status Filter
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
                                    Icons.payment,
                                    size: 16,
                                    color: Color(0xFF0D1845),
                                  ),
                                  SizedBox(width: 6),
                                  Text(
                                    'Payment Status',
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
                              child: DropdownButtonFormField<String>(
                                value: _selectedPaymentStatus,
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: Colors.white,
                                  hintText: 'Select payment status',
                                  hintStyle: TextStyle(
                                    color: Color(0xFFADB5BD),
                                    fontSize: 14,
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
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 16,
                                  ),
                                ),
                                items: ['All', 'Paid', 'Unpaid', 'Partial']
                                    .map(
                                      (status) => DropdownMenuItem(
                                        value: status,
                                        child: Row(
                                          children: [
                                            Icon(
                                              status == 'All'
                                                  ? Icons.account_balance_wallet
                                                  : status == 'Paid'
                                                  ? Icons.check_circle
                                                  : status == 'Unpaid'
                                                  ? Icons.cancel
                                                  : Icons.pie_chart,
                                              color: status == 'All'
                                                  ? Color(0xFF6C757D)
                                                  : status == 'Paid'
                                                  ? Color(0xFF28A745)
                                                  : status == 'Unpaid'
                                                  ? Color(0xFFDC3545)
                                                  : Color(0xFFFFA726),
                                              size: 18,
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              status,
                                              style: TextStyle(
                                                color: Color(0xFF343A40),
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
                                      _selectedPaymentStatus = value;
                                      _updateSelectAllState();
                                    });
                                  }
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
            const SizedBox(height: 24),

            // Enhanced Table Section - Matching Product List Page Design
            Container(
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
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _selectAll,
                          onChanged: (value) => _toggleSelectAll(),
                          activeColor: Color(0xFF0D1845),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.shopping_cart,
                          color: Color(0xFF0D1845),
                          size: 18,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Sales List',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF343A40),
                          ),
                        ),
                        Spacer(),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Color(0xFFE3F2FD),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.shopping_cart,
                                color: Color(0xFF1976D2),
                                size: 12,
                              ),
                              SizedBox(width: 3),
                              Text(
                                '${filteredSales.length} Sales',
                                style: TextStyle(
                                  color: Color(0xFF1976D2),
                                  fontWeight: FontWeight.w500,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingRowColor: MaterialStateProperty.all(
                        Color(0xFFF8F9FA),
                      ),
                      dataRowColor: MaterialStateProperty.resolveWith<Color>((
                        Set<MaterialState> states,
                      ) {
                        if (states.contains(MaterialState.selected)) {
                          return Color(0xFF0D1845).withOpacity(0.1);
                        }
                        return Colors.white;
                      }),
                      columns: const [
                        DataColumn(label: Text('Select')),
                        DataColumn(label: Text('Customer')),
                        DataColumn(label: Text('Reference')),
                        DataColumn(label: Text('Date')),
                        DataColumn(label: Text('Status')),
                        DataColumn(label: Text('Grand Total')),
                        DataColumn(label: Text('Paid')),
                        DataColumn(label: Text('Due')),
                        DataColumn(label: Text('Payment Status')),
                        DataColumn(label: Text('Biller')),
                        DataColumn(label: Text('Actions')),
                      ],
                      rows: filteredSales.map((sale) {
                        final isSelected = _selectedSales.any(
                          (s) => s['id'] == sale['id'],
                        );
                        return DataRow(
                          selected: isSelected,
                          cells: [
                            DataCell(
                              Checkbox(
                                value: isSelected,
                                onChanged: (value) =>
                                    _toggleSaleSelection(sale),
                                activeColor: Color(0xFF0D1845),
                              ),
                            ),
                            DataCell(
                              Row(
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: Color(0xFF0D1845).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.person,
                                      color: Color(0xFF0D1845),
                                      size: 16,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(sale['customer']),
                                ],
                              ),
                            ),
                            DataCell(Text(sale['reference'])),
                            DataCell(
                              Text(
                                DateFormat('dd MMM yyyy').format(sale['date']),
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(
                                    sale['status'],
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  sale['status'],
                                  style: TextStyle(
                                    color: _getStatusColor(sale['status']),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(
                              Text(
                                'Rs. ${sale['grandTotal'].toStringAsFixed(2)}',
                              ),
                            ),
                            DataCell(
                              Text(
                                'Rs. ${sale['paidAmount'].toStringAsFixed(2)}',
                              ),
                            ),
                            DataCell(
                              Text(
                                'Rs. ${sale['dueAmount'].toStringAsFixed(2)}',
                              ),
                            ),
                            DataCell(
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getPaymentStatusColor(
                                    sale['paymentStatus'],
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  sale['paymentStatus'],
                                  style: TextStyle(
                                    color: _getPaymentStatusColor(
                                      sale['paymentStatus'],
                                    ),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ),
                            DataCell(Text(sale['biller'])),
                            DataCell(
                              Row(
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.visibility,
                                      color: Color(0xFF0D1845),
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      // TODO: Implement view sale details
                                    },
                                    tooltip: 'View Details',
                                  ),
                                  // IconButton(
                                  //   icon: Icon(
                                  //     Icons.edit,
                                  //     color: Color(0xFF007BFF),
                                  //     size: 18,
                                  //   ),
                                  //   onPressed: () {
                                  //     // TODO: Implement edit sale
                                  //   },
                                  //   tooltip: 'Edit',
                                  // ),
                                  IconButton(
                                    icon: Icon(
                                      Icons.print,
                                      color: Color(0xFF28A745),
                                      size: 18,
                                    ),
                                    onPressed: () {
                                      // TODO: Implement print sale
                                    },
                                    tooltip: 'Print',
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      }).toList(),
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
}
