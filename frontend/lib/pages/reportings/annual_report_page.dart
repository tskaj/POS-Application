import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AnnualReportPage extends StatefulWidget {
  const AnnualReportPage({super.key});

  @override
  State<AnnualReportPage> createState() => _AnnualReportPageState();
}

class _AnnualReportPageState extends State<AnnualReportPage> {
  String _selectedYear = '2024';

  final List<String> _years = ['2024', '2023', '2022', '2021', '2020'];

  final Map<String, dynamic> _annualData = {
    'summary': {
      'totalSales': 18500000.00,
      'totalPurchases': 12450000.00,
      'totalExpenses': 2450000.00,
      'netProfit': 3605000.00,
      'totalVendors': 2450,
      'totalProducts': 1250,
      'totalSuppliers': 85,
    },
    'monthlyData': [
      {
        'month': 'Jan',
        'sales': 1450000.00,
        'purchases': 980000.00,
        'profit': 245000.00,
      },
      {
        'month': 'Feb',
        'sales': 1520000.00,
        'purchases': 1020000.00,
        'profit': 265000.00,
      },
      {
        'month': 'Mar',
        'sales': 1680000.00,
        'purchases': 1150000.00,
        'profit': 285000.00,
      },
      {
        'month': 'Apr',
        'sales': 1750000.00,
        'purchases': 1180000.00,
        'profit': 295000.00,
      },
      {
        'month': 'May',
        'sales': 1820000.00,
        'purchases': 1220000.00,
        'profit': 310000.00,
      },
      {
        'month': 'Jun',
        'sales': 1890000.00,
        'purchases': 1250000.00,
        'profit': 325000.00,
      },
      {
        'month': 'Jul',
        'sales': 1950000.00,
        'purchases': 1280000.00,
        'profit': 335000.00,
      },
      {
        'month': 'Aug',
        'sales': 2010000.00,
        'purchases': 1320000.00,
        'profit': 345000.00,
      },
      {
        'month': 'Sep',
        'sales': 2080000.00,
        'purchases': 1350000.00,
        'profit': 355000.00,
      },
      {
        'month': 'Oct',
        'sales': 2150000.00,
        'purchases': 1380000.00,
        'profit': 365000.00,
      },
      {
        'month': 'Nov',
        'sales': 2220000.00,
        'purchases': 1420000.00,
        'profit': 375000.00,
      },
      {
        'month': 'Dec',
        'sales': 2280000.00,
        'purchases': 1450000.00,
        'profit': 385000.00,
      },
    ],
    'topProducts': [
      {
        'name': 'iPhone 15 Pro',
        'sales': 1250000.00,
        'quantity': 450,
        'growth': 15.2,
      },
      {
        'name': 'MacBook Air M3',
        'sales': 980000.00,
        'quantity': 180,
        'growth': 22.1,
      },
      {'name': 'iPad Pro', 'sales': 850000.00, 'quantity': 320, 'growth': 18.7},
      {
        'name': 'AirPods Pro',
        'sales': 720000.00,
        'quantity': 890,
        'growth': 12.4,
      },
      {
        'name': 'Apple Watch',
        'sales': 650000.00,
        'quantity': 420,
        'growth': 8.9,
      },
    ],
    'topVendors': [
      {
        'name': 'Tech Solutions Inc',
        'totalPurchase': 2450000.00,
        'orders': 45,
        'lastOrder': '2024-01-15',
      },
      {
        'name': 'Global Enterprises',
        'totalPurchase': 1890000.00,
        'orders': 38,
        'lastOrder': '2024-01-12',
      },
      {
        'name': 'Digital Corp',
        'totalPurchase': 1650000.00,
        'orders': 32,
        'lastOrder': '2024-01-14',
      },
      {
        'name': 'Smart Systems Ltd',
        'totalPurchase': 1420000.00,
        'orders': 28,
        'lastOrder': '2024-01-10',
      },
      {
        'name': 'Future Tech',
        'totalPurchase': 1280000.00,
        'orders': 25,
        'lastOrder': '2024-01-08',
      },
    ],
    'expenseBreakdown': [
      {'category': 'Salaries', 'amount': 1200000.00, 'percentage': 49.0},
      {'category': 'Rent & Utilities', 'amount': 350000.00, 'percentage': 14.3},
      {'category': 'Marketing', 'amount': 280000.00, 'percentage': 11.4},
      {'category': 'Equipment', 'amount': 220000.00, 'percentage': 9.0},
      {'category': 'Insurance', 'amount': 150000.00, 'percentage': 6.1},
      {'category': 'Other', 'amount': 250000.00, 'percentage': 10.2},
    ],
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Enhanced Header - Matching Sales Page Design
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
                      Icons.bar_chart,
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
                          'Annual Report',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Comprehensive annual financial overview',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedYear,
                      underline: const SizedBox(),
                      dropdownColor: const Color(0xFF0D1845),
                      style: const TextStyle(color: Colors.white),
                      icon: const Icon(
                        Icons.arrow_drop_down,
                        color: Colors.white,
                      ),
                      items: _years.map((year) {
                        return DropdownMenuItem(
                          value: year,
                          child: Text('Year $year'),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() => _selectedYear = value!);
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Summary Cards
            Row(
              children: [
                _buildSummaryCard(
                  'Total Sales',
                  'Rs. ${_annualData['summary']?['totalSales'] != null ? NumberFormat('#,##0.00').format(_annualData['summary']['totalSales']) : '0.00'}',
                  Icons.trending_up,
                  Colors.green,
                ),
                const SizedBox(width: 16),
                _buildSummaryCard(
                  'Net Profit',
                  'Rs. ${_annualData['summary']?['netProfit'] != null ? NumberFormat('#,##0.00').format(_annualData['summary']['netProfit']) : '0.00'}',
                  Icons.account_balance_wallet,
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildSummaryCard(
                  'Total Vendors',
                  _annualData['summary']['totalVendors'].toString(),
                  Icons.people,
                  Colors.orange,
                ),
                const SizedBox(width: 16),
                _buildSummaryCard(
                  'Profit Margin',
                  '${_annualData['summary']?['totalSales'] != null && _annualData['summary']['totalSales'] != 0 ? ((_annualData['summary']['netProfit'] / _annualData['summary']['totalSales']) * 100).toStringAsFixed(1) : '0.0'}%',
                  Icons.percent,
                  Colors.purple,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // 2025 Reports Table
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1a237e),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: const Text(
                      '2025 Reports',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                  ),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      columnSpacing: 40,
                      columns: const [
                        DataColumn(
                          label: Text(
                            'Months',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1a237e),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Jan 2025',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1a237e),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Feb 2025',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1a237e),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Mar 2025',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1a237e),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Apr 2025',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1a237e),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'May 2025',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1a237e),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Jun 2025',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1a237e),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Jul 2025',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1a237e),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Aug 2025',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1a237e),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Sep 2025',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1a237e),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Oct 2025',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1a237e),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Nov 2025',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1a237e),
                            ),
                          ),
                        ),
                        DataColumn(
                          label: Text(
                            'Dec 2025',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1a237e),
                            ),
                          ),
                        ),
                      ],
                      rows: const [
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                'January',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            DataCell(Text('Rs. 1,450,000.00')),
                            DataCell(Text('Rs. 1,520,000.00')),
                            DataCell(Text('Rs. 1,680,000.00')),
                            DataCell(Text('Rs. 1,750,000.00')),
                            DataCell(Text('Rs. 1,820,000.00')),
                            DataCell(Text('Rs. 1,890,000.00')),
                            DataCell(Text('Rs. 1,950,000.00')),
                            DataCell(Text('Rs. 2,010,000.00')),
                            DataCell(Text('Rs. 2,080,000.00')),
                            DataCell(Text('Rs. 2,150,000.00')),
                            DataCell(Text('Rs. 2,220,000.00')),
                            DataCell(Text('Rs. 2,280,000.00')),
                          ],
                        ),
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                'February',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            DataCell(Text('Rs. 980,000.00')),
                            DataCell(Text('Rs. 1,020,000.00')),
                            DataCell(Text('Rs. 1,150,000.00')),
                            DataCell(Text('Rs. 1,180,000.00')),
                            DataCell(Text('Rs. 1,220,000.00')),
                            DataCell(Text('Rs. 1,250,000.00')),
                            DataCell(Text('Rs. 1,280,000.00')),
                            DataCell(Text('Rs. 1,320,000.00')),
                            DataCell(Text('Rs. 1,350,000.00')),
                            DataCell(Text('Rs. 1,380,000.00')),
                            DataCell(Text('Rs. 1,420,000.00')),
                            DataCell(Text('Rs. 1,450,000.00')),
                          ],
                        ),
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                'March',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            DataCell(Text('Rs. 245,000.00')),
                            DataCell(Text('Rs. 265,000.00')),
                            DataCell(Text('Rs. 285,000.00')),
                            DataCell(Text('Rs. 295,000.00')),
                            DataCell(Text('Rs. 310,000.00')),
                            DataCell(Text('Rs. 325,000.00')),
                            DataCell(Text('Rs. 335,000.00')),
                            DataCell(Text('Rs. 345,000.00')),
                            DataCell(Text('Rs. 355,000.00')),
                            DataCell(Text('Rs. 365,000.00')),
                            DataCell(Text('Rs. 375,000.00')),
                            DataCell(Text('Rs. 385,000.00')),
                          ],
                        ),
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                'April',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            DataCell(Text('Rs. 2,695,000.00')),
                            DataCell(Text('Rs. 2,785,000.00')),
                            DataCell(Text('Rs. 3,065,000.00')),
                            DataCell(Text('Rs. 3,045,000.00')),
                            DataCell(Text('Rs. 3,130,000.00')),
                            DataCell(Text('Rs. 3,140,000.00')),
                            DataCell(Text('Rs. 3,230,000.00')),
                            DataCell(Text('Rs. 3,330,000.00')),
                            DataCell(Text('Rs. 3,430,000.00')),
                            DataCell(Text('Rs. 3,515,000.00')),
                            DataCell(Text('Rs. 3,595,000.00')),
                            DataCell(Text('Rs. 3,665,000.00')),
                          ],
                        ),
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                'May',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            DataCell(Text('Rs. 1,200,000.00')),
                            DataCell(Text('Rs. 1,300,000.00')),
                            DataCell(Text('Rs. 1,400,000.00')),
                            DataCell(Text('Rs. 1,500,000.00')),
                            DataCell(Text('Rs. 1,600,000.00')),
                            DataCell(Text('Rs. 1,700,000.00')),
                            DataCell(Text('Rs. 1,800,000.00')),
                            DataCell(Text('Rs. 1,900,000.00')),
                            DataCell(Text('Rs. 2,000,000.00')),
                            DataCell(Text('Rs. 2,100,000.00')),
                            DataCell(Text('Rs. 2,200,000.00')),
                            DataCell(Text('Rs. 2,300,000.00')),
                          ],
                        ),
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                'June',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            DataCell(Text('Rs. 850,000.00')),
                            DataCell(Text('Rs. 900,000.00')),
                            DataCell(Text('Rs. 950,000.00')),
                            DataCell(Text('Rs. 1,000,000.00')),
                            DataCell(Text('Rs. 1,050,000.00')),
                            DataCell(Text('Rs. 1,100,000.00')),
                            DataCell(Text('Rs. 1,150,000.00')),
                            DataCell(Text('Rs. 1,200,000.00')),
                            DataCell(Text('Rs. 1,250,000.00')),
                            DataCell(Text('Rs. 1,300,000.00')),
                            DataCell(Text('Rs. 1,350,000.00')),
                            DataCell(Text('Rs. 1,400,000.00')),
                          ],
                        ),
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                'July',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            DataCell(Text('Rs. 750,000.00')),
                            DataCell(Text('Rs. 800,000.00')),
                            DataCell(Text('Rs. 850,000.00')),
                            DataCell(Text('Rs. 900,000.00')),
                            DataCell(Text('Rs. 950,000.00')),
                            DataCell(Text('Rs. 1,000,000.00')),
                            DataCell(Text('Rs. 1,050,000.00')),
                            DataCell(Text('Rs. 1,100,000.00')),
                            DataCell(Text('Rs. 1,150,000.00')),
                            DataCell(Text('Rs. 1,200,000.00')),
                            DataCell(Text('Rs. 1,250,000.00')),
                            DataCell(Text('Rs. 1,300,000.00')),
                          ],
                        ),
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                'August',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            DataCell(Text('Rs. 650,000.00')),
                            DataCell(Text('Rs. 700,000.00')),
                            DataCell(Text('Rs. 750,000.00')),
                            DataCell(Text('Rs. 800,000.00')),
                            DataCell(Text('Rs. 850,000.00')),
                            DataCell(Text('Rs. 900,000.00')),
                            DataCell(Text('Rs. 950,000.00')),
                            DataCell(Text('Rs. 1,000,000.00')),
                            DataCell(Text('Rs. 1,050,000.00')),
                            DataCell(Text('Rs. 1,100,000.00')),
                            DataCell(Text('Rs. 1,150,000.00')),
                            DataCell(Text('Rs. 1,200,000.00')),
                          ],
                        ),
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                'September',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            DataCell(Text('Rs. 550,000.00')),
                            DataCell(Text('Rs. 600,000.00')),
                            DataCell(Text('Rs. 650,000.00')),
                            DataCell(Text('Rs. 700,000.00')),
                            DataCell(Text('Rs. 750,000.00')),
                            DataCell(Text('Rs. 800,000.00')),
                            DataCell(Text('Rs. 850,000.00')),
                            DataCell(Text('Rs. 900,000.00')),
                            DataCell(Text('Rs. 950,000.00')),
                            DataCell(Text('Rs. 1,000,000.00')),
                            DataCell(Text('Rs. 1,050,000.00')),
                            DataCell(Text('Rs. 1,100,000.00')),
                          ],
                        ),
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                'October',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            DataCell(Text('Rs. 450,000.00')),
                            DataCell(Text('Rs. 500,000.00')),
                            DataCell(Text('Rs. 550,000.00')),
                            DataCell(Text('Rs. 600,000.00')),
                            DataCell(Text('Rs. 650,000.00')),
                            DataCell(Text('Rs. 700,000.00')),
                            DataCell(Text('Rs. 750,000.00')),
                            DataCell(Text('Rs. 800,000.00')),
                            DataCell(Text('Rs. 850,000.00')),
                            DataCell(Text('Rs. 900,000.00')),
                            DataCell(Text('Rs. 950,000.00')),
                            DataCell(Text('Rs. 1,000,000.00')),
                          ],
                        ),
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                'November',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            DataCell(Text('Rs. 350,000.00')),
                            DataCell(Text('Rs. 400,000.00')),
                            DataCell(Text('Rs. 450,000.00')),
                            DataCell(Text('Rs. 500,000.00')),
                            DataCell(Text('Rs. 550,000.00')),
                            DataCell(Text('Rs. 600,000.00')),
                            DataCell(Text('Rs. 650,000.00')),
                            DataCell(Text('Rs. 700,000.00')),
                            DataCell(Text('Rs. 750,000.00')),
                            DataCell(Text('Rs. 800,000.00')),
                            DataCell(Text('Rs. 850,000.00')),
                            DataCell(Text('Rs. 900,000.00')),
                          ],
                        ),
                        DataRow(
                          cells: [
                            DataCell(
                              Text(
                                'December',
                                style: TextStyle(fontWeight: FontWeight.w500),
                              ),
                            ),
                            DataCell(Text('Rs. 250,000.00')),
                            DataCell(Text('Rs. 300,000.00')),
                            DataCell(Text('Rs. 350,000.00')),
                            DataCell(Text('Rs. 400,000.00')),
                            DataCell(Text('Rs. 450,000.00')),
                            DataCell(Text('Rs. 500,000.00')),
                            DataCell(Text('Rs. 550,000.00')),
                            DataCell(Text('Rs. 600,000.00')),
                            DataCell(Text('Rs. 650,000.00')),
                            DataCell(Text('Rs. 700,000.00')),
                            DataCell(Text('Rs. 750,000.00')),
                            DataCell(Text('Rs. 800,000.00')),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Top Products and Vendors Row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Products
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Top Products',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1a237e),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._annualData['topProducts'].map<Widget>((product) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        product['name'] ?? 'Unknown Product',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '${product['quantity'] ?? 0} units sold',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Rs. ${product['sales'] != null ? NumberFormat('#,##0.00').format(product['sales']) : '0.00'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      '+${product['growth'] ?? 0}%',
                                      style: const TextStyle(
                                        color: Colors.green,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Top Vendors
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.1),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Top Vendors',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1a237e),
                          ),
                        ),
                        const SizedBox(height: 16),
                        ..._annualData['topVendors'].map<Widget>((vendor) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        vendor['name'] ?? 'Unknown Vendor',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      Text(
                                        '${vendor['orders'] ?? 0} orders',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Rs. ${vendor['totalPurchase'] != null ? NumberFormat('#,##0.00').format(vendor['totalPurchase']) : '0.00'}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      'Last: ${vendor['lastOrder'] != null ? DateFormat('MMM dd').format(DateTime.parse(vendor['lastOrder'])) : 'N/A'}',
                                      style: TextStyle(
                                        color: Colors.grey[600],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Monthly Data Table
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: const BoxDecoration(
                      color: Color(0xFF1a237e),
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                    ),
                    child: const Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: Text(
                            'Month',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Sales',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Purchases',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Expanded(
                          flex: 2,
                          child: Text(
                            'Profit',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _annualData['monthlyData'].length,
                    itemBuilder: (context, index) {
                      final data = _annualData['monthlyData'][index];
                      return Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          border: Border(
                            bottom: BorderSide(color: Colors.grey[200]!),
                          ),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 1,
                              child: Text(
                                data['month'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Rs. ${data['sales'] != null ? NumberFormat('#,##0.00').format(data['sales']) : '0.00'}',
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Rs. ${data['purchases'] != null ? NumberFormat('#,##0.00').format(data['purchases']) : '0.00'}',
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                'Rs. ${data['profit'] != null ? NumberFormat('#,##0.00').format(data['profit']) : '0.00'}',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ],
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
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 24),
                const Spacer(),
                Flexible(
                  child: Text(
                    value,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
