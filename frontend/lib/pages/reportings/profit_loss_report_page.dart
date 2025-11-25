import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProfitLossReportPage extends StatefulWidget {
  const ProfitLossReportPage({super.key});

  @override
  State<ProfitLossReportPage> createState() => _ProfitLossReportPageState();
}

class _ProfitLossReportPageState extends State<ProfitLossReportPage> {
  String _selectedPeriod = 'This Month';
  String _selectedYear = '2024';

  final List<String> _periods = [
    'This Month',
    'Last Month',
    'This Quarter',
    'Last Quarter',
    'This Year',
    'Last Year',
    'Custom Range',
  ];
  final List<String> _years = ['2024', '2023', '2022', '2021', '2020'];

  final Map<String, dynamic> _profitLossData = {
    'revenue': {
      'sales': 1545000.00,
      'serviceIncome': 245000.00,
      'otherIncome': 89000.00,
      'totalRevenue': 1879000.00,
    },
    'costOfGoodsSold': {
      'openingStock': 125000.00,
      'purchases': 875000.00,
      'closingStock': 98000.00,
      'totalCOGS': 1098000.00,
    },
    'grossProfit': 781000.00,
    'operatingExpenses': {
      'salaries': 245000.00,
      'rent': 45000.00,
      'utilities': 18000.00,
      'marketing': 35000.00,
      'insurance': 12000.00,
      'depreciation': 25000.00,
      'otherExpenses': 28000.00,
      'totalOperatingExpenses': 408000.00,
    },
    'operatingProfit': 373000.00,
    'otherIncomeExpenses': {
      'interestIncome': 15000.00,
      'interestExpense': 28000.00,
      'otherIncome': 5000.00,
      'otherExpense': 8000.00,
      'netOtherIncomeExpenses': -8000.00,
    },
    'profitBeforeTax': 365000.00,
    'taxExpense': 109500.00,
    'netProfit': 255500.00,
  };

  @override
  Widget build(BuildContext context) {
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
            // Enhanced Header
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
                      Icons.account_balance_wallet,
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
                          'Profit & Loss Report',
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Comprehensive financial performance analysis and profitability tracking',
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
                      // TODO: Implement export functionality
                    },
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Export Report'),
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

            // Enhanced Filters Section
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
              child: Row(
                children: [
                  // Period Filter
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.date_range,
                                size: 16,
                                color: Color(0xFF0D1845),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Time Period',
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
                            value: _selectedPeriod,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
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
                            items: _periods
                                .map(
                                  (period) => DropdownMenuItem(
                                    value: period,
                                    child: Row(
                                      children: [
                                        Icon(
                                          period == 'Custom Range'
                                              ? Icons.calendar_today
                                              : Icons.schedule,
                                          color: Color(0xFF0D1845),
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          period,
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
                                  _selectedPeriod = value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Year Filter
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 6),
                          child: Row(
                            children: [
                              Icon(
                                Icons.calendar_view_month,
                                size: 16,
                                color: Color(0xFF0D1845),
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Year',
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
                            value: _selectedYear,
                            decoration: InputDecoration(
                              filled: true,
                              fillColor: Colors.white,
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
                            items: _years
                                .map(
                                  (year) => DropdownMenuItem(
                                    value: year,
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today,
                                          color: Color(0xFF0D1845),
                                          size: 18,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          year,
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
                                  _selectedYear = value;
                                });
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  // Export Button
                  Container(
                    margin: const EdgeInsets.only(top: 24),
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // TODO: Implement export functionality
                      },
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Export Report'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0D1845),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Summary Cards
            Row(
              children: [
                _buildSummaryCard(
                  'Total Revenue',
                  'Rs. ${NumberFormat('#,##0.00').format(_profitLossData['revenue']['totalRevenue'])}',
                  Icons.trending_up,
                  Colors.green,
                ),
                _buildSummaryCard(
                  'Total Expenses',
                  'Rs. ${NumberFormat('#,##0.00').format(_profitLossData['operatingExpenses']['totalOperatingExpenses'])}',
                  Icons.trending_down,
                  Colors.red,
                ),
                _buildSummaryCard(
                  'Net Profit',
                  'Rs. ${NumberFormat('#,##0.00').format(_profitLossData['netProfit'])}',
                  Icons.account_balance_wallet,
                  Colors.blue,
                ),
                _buildSummaryCard(
                  'Profit Margin',
                  '${((_profitLossData['netProfit'] / _profitLossData['revenue']['totalRevenue']) * 100).toStringAsFixed(1)}%',
                  Icons.percent,
                  Colors.orange,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Enhanced Profit & Loss Statement
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
                        Icon(
                          Icons.account_balance_wallet,
                          color: Color(0xFF0D1845),
                          size: 18,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Profit & Loss Statement',
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
                                Icons.analytics,
                                color: Color(0xFF1976D2),
                                size: 12,
                              ),
                              SizedBox(width: 3),
                              Text(
                                'Financial Overview',
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
                  // Revenue Section
                  _buildSectionHeader('Revenue'),
                  _buildDataRow('Sales', _profitLossData['revenue']['sales']),
                  _buildDataRow(
                    'Service Income',
                    _profitLossData['revenue']['serviceIncome'],
                  ),
                  _buildDataRow(
                    'Other Income',
                    _profitLossData['revenue']['otherIncome'],
                  ),
                  _buildTotalRow(
                    'Total Revenue',
                    _profitLossData['revenue']['totalRevenue'],
                    isRevenue: true,
                  ),

                  // Cost of Goods Sold Section
                  _buildSectionHeader('Cost of Goods Sold'),
                  _buildDataRow(
                    'Opening Stock',
                    _profitLossData['costOfGoodsSold']['openingStock'],
                  ),
                  _buildDataRow(
                    'Purchases',
                    _profitLossData['costOfGoodsSold']['purchases'],
                  ),
                  _buildDataRow(
                    '(-) Closing Stock',
                    -_profitLossData['costOfGoodsSold']['closingStock'],
                  ),
                  _buildTotalRow(
                    'Total Cost of Goods Sold',
                    _profitLossData['costOfGoodsSold']['totalCOGS'],
                    isExpense: true,
                  ),

                  // Gross Profit
                  _buildTotalRow(
                    'Gross Profit',
                    _profitLossData['grossProfit'],
                    isGrossProfit: true,
                  ),

                  // Operating Expenses Section
                  _buildSectionHeader('Operating Expenses'),
                  _buildDataRow(
                    'Salaries & Wages',
                    _profitLossData['operatingExpenses']['salaries'],
                  ),
                  _buildDataRow(
                    'Rent',
                    _profitLossData['operatingExpenses']['rent'],
                  ),
                  _buildDataRow(
                    'Utilities',
                    _profitLossData['operatingExpenses']['utilities'],
                  ),
                  _buildDataRow(
                    'Marketing',
                    _profitLossData['operatingExpenses']['marketing'],
                  ),
                  _buildDataRow(
                    'Insurance',
                    _profitLossData['operatingExpenses']['insurance'],
                  ),
                  _buildDataRow(
                    'Depreciation',
                    _profitLossData['operatingExpenses']['depreciation'],
                  ),
                  _buildDataRow(
                    'Other Expenses',
                    _profitLossData['operatingExpenses']['otherExpenses'],
                  ),
                  _buildTotalRow(
                    'Total Operating Expenses',
                    _profitLossData['operatingExpenses']['totalOperatingExpenses'],
                    isExpense: true,
                  ),

                  // Operating Profit
                  _buildTotalRow(
                    'Operating Profit',
                    _profitLossData['operatingProfit'],
                    isOperatingProfit: true,
                  ),

                  // Other Income/Expenses Section
                  _buildSectionHeader('Other Income & Expenses'),
                  _buildDataRow(
                    'Interest Income',
                    _profitLossData['otherIncomeExpenses']['interestIncome'],
                    isPositive: true,
                  ),
                  _buildDataRow(
                    '(-) Interest Expense',
                    -_profitLossData['otherIncomeExpenses']['interestExpense'],
                  ),
                  _buildDataRow(
                    'Other Income',
                    _profitLossData['otherIncomeExpenses']['otherIncome'],
                    isPositive: true,
                  ),
                  _buildDataRow(
                    '(-) Other Expense',
                    -_profitLossData['otherIncomeExpenses']['otherExpense'],
                  ),
                  _buildTotalRow(
                    'Net Other Income/Expenses',
                    _profitLossData['otherIncomeExpenses']['netOtherIncomeExpenses'],
                    isNetOther: true,
                  ),

                  // Profit Before Tax
                  _buildTotalRow(
                    'Profit Before Tax',
                    _profitLossData['profitBeforeTax'],
                    isProfitBeforeTax: true,
                  ),

                  // Tax Expense
                  _buildDataRow('Tax Expense', _profitLossData['taxExpense']),

                  // Net Profit
                  _buildTotalRow(
                    'Net Profit',
                    _profitLossData['netProfit'],
                    isNetProfit: true,
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
        margin: const EdgeInsets.only(right: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.1), color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
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
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                const Spacer(),
                Icon(Icons.trending_up, color: color, size: 16),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        border: Border(bottom: BorderSide(color: Colors.grey[300]!)),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF1a237e),
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataRow(
    String description,
    double amount, {
    bool isPositive = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              description,
              style: TextStyle(
                color: isPositive ? Colors.green[700] : Colors.black87,
                fontWeight: isPositive ? FontWeight.w500 : FontWeight.normal,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              amount < 0
                  ? '(Rs. ${NumberFormat('#,##0.00').format(amount.abs())})'
                  : 'Rs. ${NumberFormat('#,##0.00').format(amount)}',
              style: TextStyle(
                color: amount < 0
                    ? Colors.red
                    : (isPositive ? Colors.green[700] : Colors.black87),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalRow(
    String description,
    double amount, {
    bool isRevenue = false,
    bool isExpense = false,
    bool isGrossProfit = false,
    bool isOperatingProfit = false,
    bool isNetOther = false,
    bool isProfitBeforeTax = false,
    bool isNetProfit = false,
  }) {
    Color bgColor = Colors.transparent;
    Color textColor = Colors.black87;
    FontWeight fontWeight = FontWeight.bold;

    if (isRevenue ||
        isGrossProfit ||
        isOperatingProfit ||
        isProfitBeforeTax ||
        isNetProfit) {
      bgColor = Colors.green[50]!;
      textColor = Colors.green[800]!;
    } else if (isExpense) {
      bgColor = Colors.red[50]!;
      textColor = Colors.red[800]!;
    } else if (isNetOther && amount < 0) {
      bgColor = Colors.red[50]!;
      textColor = Colors.red[800]!;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(bottom: BorderSide(color: Colors.grey[300]!, width: 2)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              description,
              style: TextStyle(
                color: textColor,
                fontWeight: fontWeight,
                fontSize: 15,
              ),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              amount < 0
                  ? '(Rs. ${NumberFormat('#,##0.00').format(amount.abs())})'
                  : 'Rs. ${NumberFormat('#,##0.00').format(amount)}',
              style: TextStyle(
                color: amount < 0 ? Colors.red[800] : textColor,
                fontWeight: fontWeight,
                fontSize: 15,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
