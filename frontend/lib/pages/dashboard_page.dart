import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:io';
import 'dart:typed_data';
import '../providers/providers.dart';
import '../models/product.dart';
import 'inventory/product_list_page.dart';
import 'inventory/add_product_page.dart';
import 'inventory/category_list_page.dart';
import 'inventory/sub_category_list_page.dart';
import 'inventory/color_list_page.dart';
import 'inventory/size_list_page.dart';
import 'inventory/season_list_page.dart';
import 'inventory/material_list_page.dart';
import 'inventory/low_stock_products_page.dart';
import 'inventory/vendors_page.dart';
import 'inventory/print_barcode_page.dart';
import 'profile/user_profile_page.dart';
import 'sales/sales_return_page.dart';
import 'sales/sales_page.dart';
import 'sales/invoices_page.dart';
import 'sales/pos_page.dart';
import 'purchase/purchase_listing_page.dart';
import 'purchase/purchase_return_page.dart';
import '../services/dashboard_service.dart';
import '../services/sales_service.dart';
import '../services/purchases_service.dart';
import '../services/income_services.dart';
import '../services/payout_service.dart';
import '../services/services.dart';
import '../services/inventory_service.dart';
import 'reportings/sales_report_page.dart';
import 'reportings/best_seller_report_page.dart';
import 'reportings/purchase_report_page.dart';
import 'reportings/inventory_report_page.dart';
import 'reportings/vendor_report_page.dart';
import 'reportings/salesman_report_page.dart';
import 'reportings/customer_report_page.dart';
import 'reportings/invoice_report_page.dart';
import 'reportings/daily_transaction_report_page.dart';
import 'reportings/expense_report_page.dart';
import 'reportings/income_report_page.dart';
import 'reportings/tax_report_page.dart';
import 'reportings/profit_loss_report_page.dart';
import 'reportings/annual_report_page.dart';
import 'peoples/credit_customer_page.dart';
import 'peoples/employees_page.dart';
import 'peoples/attendance_page.dart';
import 'users/users_page.dart';
import 'users/roles_permissions_page.dart';
import 'finance & accounts/bank_account_page.dart';
import 'finance & accounts/chart_of_accounts_page.dart';
import 'finance & accounts/account_statement_page.dart';
import 'finance & accounts/payout_page.dart';
import 'finance & accounts/payin_page.dart';
import 'cashflow_page.dart';
import 'package:fl_chart/fl_chart.dart';
import '../utils/unsaved_guard.dart';
import 'dart:async';
import 'package:intl/intl.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();

  /// Open POS inside the dashboard content area and optionally pass an [Invoice]
  /// to edit. This is a convenience helper so other pages can request the
  /// dashboard to show POS (instead of pushing a separate route on top).
  static void openPos(
    BuildContext context, {
    Invoice? invoice,
    bool openCustomTab = false,
  }) {
    final state = context.findAncestorStateOfType<_DashboardPageState>();
    if (state != null) {
      state.openPosWithInvoice(invoice, openCustomTab: openCustomTab);
    } else {
      // If Dashboard state is not in the widget tree (page opened directly),
      // fall back to pushing the POS route so behavior remains compatible.
      // NOTE: fallback route doesn't support the openCustomTab flag; pass invoice only.
      Navigator.pushNamed(context, '/pos', arguments: invoice);
    }
  }
}

class _DashboardPageState extends State<DashboardPage>
    with TickerProviderStateMixin, WindowListener {
  // If non-null, this Invoice will be forwarded to the PosPage when the
  // dashboard switches to 'POS' content. _posOpenCustomTab indicates whether
  // the POS should open the Custom Order tab for editing bridals.
  Invoice? _posInvoiceToEdit;
  bool _posOpenCustomTab = false;
  String currentContent = 'Admin Dashboard';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  bool _isSidebarOpen = true;
  Map<String, AnimationController> _animationControllers = {};
  String selectedTimeRange = '1M'; // Default time range
  String selectedTopSellingPeriod = 'Today'; // Default period for top selling

  // Date and Time state
  late Timer _dateTimeTimer;
  String _currentTime = '';
  String _currentDate = '';

  // Global keys for page state access
  Key _invoicesPageKey = UniqueKey();
  Key _salesReturnPageKey = UniqueKey();

  // Section expansion states
  Map<String, bool> _sectionExpanded = {
    'Inventory': false,
    'Sales': false,
    'Purchase': false,
    'Finance & Accounts': false,
    'Peoples': false,
    'Reports': false,
    'Users': false,
    'Payout (Expenses)': false,
    'Payin (Income)': false,
  };

  // Dashboard data
  DashboardMetrics? _metrics;
  OverallInformation? _overallInfo;
  List<TopSellingProduct> _topSellingProducts = [];
  List<LowStockProduct> _lowStockProducts = [];
  List<RecentSale> _recentSales = [];
  SalesStatics? _salesStatics;
  List<TopCategory> _topCategories = [];
  OrderStatistics? _orderStatistics;
  Map<String, double>? _dailySalesAndReturns;
  List<Purchase> _recentPurchases = [];
  double _totalIncome = 0.0;
  double _totalExpense = 0.0;

  bool _isLoading = true;

  Future<Uint8List?> _loadImageBytes(String path) async {
    try {
      return await File('${Directory.current.path}/$path').readAsBytes();
    } catch (e) {
      return null;
    }
  }

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );
    _animationController.forward();

    // Initialize date/time display
    _updateDateTime();
    _dateTimeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        _updateDateTime();
      }
    });

    // Load user profile and dashboard data after ensuring auth is initialized
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);

      // Wait for auth initialization to complete
      await authProvider.initAuth();

      if (authProvider.userProfile == null) {
        authProvider.getUserProfile();
      }
      _loadDashboardData();
    });
  }

  Future<void> _loadDashboardData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      // Load all dashboard data in parallel with error handling
      final results = await Future.wait([
        DashboardService.getDashboardMetrics(),
        DashboardService.getOverallInformation(),
        // Fetch real low stock products from inventory service
        InventoryService.getLowStockProducts(page: 1, limit: 5),
        // Fetch recent invoices to calculate top selling and recent sales
        SalesService.getInvoices(page: 1, limit: 20),
        DashboardService.getSalesStatics(),
        DashboardService.getRecentTransactions(),
        DashboardService.getTopCategories(),
        DashboardService.getOrderStatistics(),
        DashboardService.getDailySalesAndReturns(),
        // Fetch recent purchases
        PurchaseService.getPurchases(page: 1, perPage: 5),
        // Fetch daily invoices
        SalesService.getInvoices(page: 1, limit: 50),
        // Fetch pay-ins and payouts (with error handling for 404)
        IncomeService.getPayIns().catchError((e) {
          print('⚠️ PayIns not available (likely empty): $e');
          return PayInResponse(
            status: true,
            message: 'No records found',
            data: [],
          );
        }),
        PayoutService.getAllPayouts().catchError((e) {
          print('⚠️ Payouts not available (likely empty): $e');
          return <Payout>[];
        }),
        // Fetch sales returns for daily returns calculation
        SalesService.getSalesReturns().catchError((e) {
          print('⚠️ Sales returns not available: $e');
          return SalesReturnResponse(status: true, data: []);
        }),
      ]);

      if (!mounted) return; // Avoid calling setState after dispose

      // --- Safe parsing helpers ---
      List _ensureList(dynamic possible) {
        try {
          if (possible == null) return [];
          if (possible is List) return possible;
          if (possible is Map && possible.containsKey('data')) {
            return (possible['data'] as List?) ?? [];
          }
        } catch (_) {}
        return [];
      }

      // Process low stock products (accept Map, List or typed response)
      final lowStockRaw = results.length > 2 ? results[2] : null;
      final lowStockData = _ensureList(lowStockRaw);
      final lowStockList = lowStockData
          .map<Product?>((item) {
            try {
              return Product.fromJson(item);
            } catch (e) {
              return null;
            }
          })
          .where((p) => p != null)
          .cast<Product>()
          .toList();

      // Process invoices for top selling and recent sales
      List<Invoice> recentInvoicesList = [];
      final recentInvoicesRaw = results.length > 3 ? results[3] : null;
      if (recentInvoicesRaw is InvoiceResponse) {
        recentInvoicesList = recentInvoicesRaw.data ?? [];
      }

      // Calculate daily sales and returns from invoices (results[10])
      List<Invoice> invoicesList = [];
      final invoiceResponseRaw = results.length > 10 ? results[10] : null;
      if (invoiceResponseRaw is InvoiceResponse) {
        invoicesList = invoiceResponseRaw.data ?? [];
      }

      final today = DateTime.now();
      final todayStr =
          '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      double dailySales = 0.0;
      double dailyReturns = 0.0;
      for (var invoice in invoicesList) {
        try {
          if (invoice.invDate.startsWith(todayStr)) {
            dailySales += invoice.invAmount;
          }
        } catch (_) {}
      }

      // Calculate daily returns from sales returns (results[13])
      final salesReturnsRaw = results.length > 13 ? results[13] : null;
      if (salesReturnsRaw is SalesReturnResponse) {
        for (var salesReturn in salesReturnsRaw.data ?? []) {
          try {
            if (salesReturn.invRetDate.startsWith(todayStr)) {
              dailyReturns +=
                  double.tryParse(salesReturn.returnInvAmount) ?? 0.0;
            }
          } catch (_) {}
        }
      }

      // Calculate total income from PayIns
      double totalIncome = 0.0;
      PayInResponse? payInResponse;
      final payInRaw = results.length > 11 ? results[11] : null;
      if (payInRaw is PayInResponse) {
        payInResponse = payInRaw;
        try {
          totalIncome = (payInResponse.data ?? []).fold<double>(
            0.0,
            (sum, payIn) => sum + (double.tryParse(payIn.amount) ?? 0.0),
          );
        } catch (e) {
          totalIncome = 0.0;
        }
      } else {
        totalIncome = 0.0;
      }

      // Calculate total expense from Payouts
      double totalExpense = 0.0;
      final payoutsRaw = results.length > 12 ? results[12] : null;
      List<Payout> payouts = [];
      if (payoutsRaw is List<Payout>) {
        payouts = payoutsRaw;
      } else if (payoutsRaw is Map && payoutsRaw.containsKey('data')) {
        try {
          payouts = (payoutsRaw['data'] as List)
              .map((p) => Payout.fromJson(p))
              .toList();
        } catch (_) {
          payouts = [];
        }
      }
      totalExpense = payouts.fold<double>(
        0.0,
        (sum, payout) => sum + (double.tryParse(payout.amount) ?? 0.0),
      );

      // Process purchases
      List<Purchase> purchasesList = [];
      final purchaseRaw = results.length > 9 ? results[9] : null;
      if (purchaseRaw is PurchaseResponse) {
        purchasesList = purchaseRaw.data ?? [];
      }

      // Debug/telemetry logs (kept concise)
      print('📊 Dashboard Data Loaded:');
      print('   - Low Stock Products: ${lowStockList.length}');
      print('   - Recent Invoices: ${recentInvoicesList.length}');
      print('   - Recent Purchases: ${purchasesList.length}');
      print('   - Total Income (PayIns): $totalIncome');
      print('   - Total Expense (Payouts): $totalExpense');
      print(
        '   - Daily Sales: $dailySales (from ${invoicesList.length} invoices)',
      );
      print('   - Daily Returns: $dailyReturns');

      if (!mounted) return; // final mounted check before updating UI
      setState(() {
        _metrics = results[0] is DashboardMetrics
            ? results[0] as DashboardMetrics
            : null;
        _overallInfo = results[1] is OverallInformation
            ? results[1] as OverallInformation
            : null;

        // Convert real data to dashboard format
        _lowStockProducts = lowStockList.take(5).map((product) {
          return LowStockProduct(
            name: product.title,
            id: product.id.toString(),
            stock: product.openingStockQuantity,
          );
        }).toList();

        // Convert recent invoices to top selling (top 5 by amount)
        if (recentInvoicesList.isNotEmpty) {
          final sortedInvoices = List<Invoice>.from(recentInvoicesList)
            ..sort((a, b) => b.invAmount.compareTo(a.invAmount));
          _topSellingProducts = sortedInvoices.take(5).map((invoice) {
            return TopSellingProduct(
              name: invoice.customerName,
              price: 'Rs ${invoice.invAmount.toStringAsFixed(0)}',
              sales: invoice.invAmount.toStringAsFixed(0),
              change: '+0%',
            );
          }).toList();

          // Convert recent invoices to recent sales (last 5)
          _recentSales = recentInvoicesList.take(5).map((invoice) {
            return RecentSale(
              productName: 'Invoice #${invoice.invId}',
              category: invoice.customerName,
              price: 'Rs ${invoice.invAmount.toStringAsFixed(0)}',
              date: invoice.invDate,
              status: invoice.paymentMode,
            );
          }).toList();
        } else {
          _topSellingProducts = [];
          _recentSales = [];
        }

        _salesStatics = results[4] is SalesStatics
            ? results[4] as SalesStatics
            : null;
        _topCategories = results[6] is List<TopCategory>
            ? results[6] as List<TopCategory>
            : [];
        _orderStatistics = results[7] is OrderStatistics
            ? results[7] as OrderStatistics
            : null;
        _dailySalesAndReturns = {'sales': dailySales, 'returns': dailyReturns};
        _recentPurchases = purchasesList;
        _totalIncome = totalIncome;
        _totalExpense = totalExpense;
        _isLoading = false;
      });
    } catch (e, st) {
      print('Error loading dashboard data: $e');
      print(st);
      if (!mounted) return;
      setState(() => _isLoading = false);
      // Show error snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load dashboard data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _dateTimeTimer.cancel();
    windowManager.removeListener(this);
    _animationController.dispose();
    for (var controller in _animationControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateDateTime() {
    final now = DateTime.now();
    final newTime = DateFormat('hh:mm:ss a').format(now);
    final newDate = DateFormat('EEEE, dd MMM yyyy').format(now);

    if (mounted && (newTime != _currentTime || newDate != _currentDate)) {
      setState(() {
        _currentTime = newTime;
        _currentDate = newDate;
      });
    }
  }

  Widget _buildDateTimeDisplay() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1845), Color(0xFF1A237E), Color(0xFF283593)],
        ),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0D1845).withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Date
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.calendar_today_rounded,
                color: Colors.white70,
                size: 12,
              ),
              const SizedBox(width: 6),
              Text(
                _currentDate,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
          // Separator
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 10),
            width: 1,
            height: 16,
            color: Colors.white.withOpacity(0.3),
          ),
          // Time
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.access_time_rounded,
                color: Color(0xFF4CAF50),
                size: 12,
              ),
              const SizedBox(width: 6),
              Text(
                _currentTime,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.0,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void onWindowRestore() {
    // When window is restored from minimized state, simply restore and focus.
    print('🔼 Window restored — using window_manager to restore/focus');
    try {
      windowManager.restore();
      windowManager.focus();
    } catch (e) {
      print('❌ Error restoring/focusing window: $e');
    }
  }

  @override
  void onWindowFocus() {
    // When window gains focus, do not force Win32 fullscreen — keep native chrome.
    print('🎯 Window focused');
  }

  @override
  Future<void> onWindowClose() async {
    print('❌ Window close button clicked - showing confirmation dialog');
    // Show confirmation dialog when user clicks the window close button
    final shouldExit =
        await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            title: const Text(
              'Exit Application',
              style: TextStyle(color: Colors.black),
            ),
            content: const Text(
              'Are you sure you want to exit?',
              style: TextStyle(color: Colors.black),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.black),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Exit', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
        ) ??
        false;

    if (shouldExit) {
      print('✅ User confirmed exit - closing application');
      await windowManager.destroy();
    } else {
      print('🚫 User cancelled exit');
    }
  }

  void updateContent(String content) {
    setState(() {
      currentContent = content;
      // If user navigates to POS via the normal sidebar/button flow,
      // ensure we don't accidentally retain a previously-set invoice
      // that was meant only for an explicit "edit invoice" flow.
      // The helper `openPosWithInvoice(...)` will set `_posInvoiceToEdit`
      // when an edit is requested, so only clear it for normal navigation.
      if (content == 'POS') {
        _posInvoiceToEdit = null;
        // Ensure normal navigation (e.g. sidebar -> POS) opens the
        // Regular Orders tab by clearing any previously-set custom flag.
        _posOpenCustomTab = false;
      }
      // Force refresh of invoices page when navigating to it
      if (content == 'Invoices') {
        _invoicesPageKey = UniqueKey();
      }
      // Force refresh of sales return page when navigating to it
      if (content == 'Sales Return') {
        _salesReturnPageKey = UniqueKey();
      }
      // Reload dashboard data when navigating back to Admin Dashboard
      if (content == 'Admin Dashboard') {
        _loadDashboardData();
      }
    });
    _animationController.reset();
    _animationController.forward();
  }

  void toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
      // When collapsing sidebar, collapse all sections
      if (!_isSidebarOpen) {
        _sectionExpanded.updateAll((key, value) => false);
      }
    });
  }

  void toggleSection(String sectionName) {
    setState(() {
      _sectionExpanded[sectionName] = !(_sectionExpanded[sectionName] ?? true);
    });
  }

  void updateTimeRange(String range) {
    setState(() {
      selectedTimeRange = range;
    });
    // Here you would typically fetch new data based on the selected time range
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Time range updated to $range'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void updateTopSellingPeriod(String period) {
    setState(() {
      selectedTopSellingPeriod = period;
    });
    // Here you would typically fetch new data for the selected period
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Top selling period updated to $period'),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  Widget _buildMainContent() {
    switch (currentContent) {
      case 'Products':
        return ProductListPage();
      case 'Create Product':
        return AddProductPage(onProductAdded: () => updateContent('Products'));
      case 'Low Stock Products':
        return LowStockProductsPage();
      case 'Category':
        return CategoryListPage();
      case 'Sub Category':
        return SubCategoryListPage();
      case 'Color':
        return ColorListPage();
      case 'Sizes':
        return SizeListPage();
      case 'Seasons':
        return SeasonListPage();
      case 'Material':
        return MaterialListPage();
      case 'Vendor':
        return VendorsPage();
      case 'Vendor\'s Profile':
        return VendorsPage();
      case 'Print Barcode / QR Code':
        return PrintBarcodePage();
      case 'Sales Return':
        return SalesReturnPage(key: _salesReturnPageKey);
      case 'Sales':
        return const SalesPage();
      case 'Invoices':
        return InvoicesPage(key: _invoicesPageKey);
      case 'Purchase Listing':
        return const PurchaseListingPage();
      case 'Purchase Return':
        return const PurchaseReturnPage();
      case 'Credit Customer':
        return const CreditCustomerPage();
      case 'Employees Profile':
        return const EmployeesPage();
      case 'Employee\'s Attendance':
        return const AttendancePage();
      case 'Sale Invoice\'s Report':
        return const SalesReportPage();
      case 'Best Selling Products':
        return const BestSellerReportPage();
      case 'Product Sale Report':
        return const SalesReportPage();
      case 'Salesman Report':
        return const SalesmanReportPage();
      case 'Purchase Report':
        return const PurchaseReportPage();
      case 'Inventory Report':
        return const InventoryReportPage();
      case 'Vendor Report':
        return const VendorReportPage();
      case 'Customer Report':
      case 'Credit Customer Report':
        return const CustomerReportPage();
      case 'Daily Transaction Report':
        return const DailyTransactionReportPage();
      case 'Invoice Report':
        return const InvoiceReportPage();
      // case 'Product Report':
      //   return const ProductReportPage();
      case 'Expense Report':
        return const ExpenseReportPage();
      case 'Income Report':
        return const IncomeReportPage();
      case 'Tax Report':
        return const TaxReportPage();
      case 'Profit & Loss':
        return const ProfitLossReportPage();
      case 'Annual Report':
        return const AnnualReportPage();
      case 'Payout (Expenses)':
        return const PayoutPage();
      case 'Payin (Income)':
        return const PayInPage();
      case 'Bank Accounts':
        return const BankAccountPage();
      case 'Chart of Accounts':
        return const ChartOfAccountsPage();
      case 'Account Statement':
        return const AccountStatementPage();
      case 'Cashflow':
        return const CashflowPage();
      case 'Users':
        return const UsersPage();
      case 'Roles & Permissions':
        return const RolesPermissionsPage();
      case 'POS':
        // Show POS page content directly in dashboard. If an invoice has been
        // requested for editing, pass it to PosPage via the invoiceToEdit param.
        return PosPage(
          invoiceToEdit: _posInvoiceToEdit,
          openCustomTab: _posOpenCustomTab,
          onBackToDashboard: () {
            setState(() {
              currentContent = 'Admin Dashboard';
              // Clear the edit invoice and flag after returning
              _posInvoiceToEdit = null;
              _posOpenCustomTab = false;
            });
            // Reload dashboard data when returning from POS
            _loadDashboardData();
          },
          onNavigateToContent: updateContent,
        );
      default:
        return _buildDashboardContent();
    }
  }

  // Public instance method invoked by DashboardPage.openPos(...) helper.
  void openPosWithInvoice(Invoice? invoice, {bool openCustomTab = false}) {
    setState(() {
      _posInvoiceToEdit = invoice;
      _posOpenCustomTab = openCustomTab;
      currentContent = 'POS';
    });
  }

  Widget _buildDashboardContent() {
    final authProvider = Provider.of<AuthProvider>(context);
    final user = authProvider.user;

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFFF8F9FA), Color(0xFFEFF3F7)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome message with user name (compact and sleek)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 24),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.18),
                    blurRadius: 14,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome back, ${user?.firstName ?? 'Admin'}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Overview of your store performance',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 260,
                    height: 64,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 8,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 8,
                              height: 48,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.85),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 8,
                              height: 36,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 8,
                              height: 56,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.9),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 8,
                              height: 44,
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.8),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Metrics Cards - Small & Elegant Layout
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // More responsive breakpoints for smaller cards
                  final width = constraints.maxWidth;
                  final int crossAxisCount;
                  final double childAspectRatio;

                  if (width > 1400) {
                    crossAxisCount = 7; // All in one row on large screens
                    childAspectRatio = 1.4;
                  } else if (width > 1100) {
                    crossAxisCount = 4;
                    childAspectRatio = 1.5;
                  } else if (width > 800) {
                    crossAxisCount = 3;
                    childAspectRatio = 1.4;
                  } else if (width > 600) {
                    crossAxisCount = 2;
                    childAspectRatio = 1.6;
                  } else {
                    crossAxisCount = 1;
                    childAspectRatio = 2.2;
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      crossAxisSpacing: 10,
                      mainAxisSpacing: 10,
                      childAspectRatio: childAspectRatio,
                    ),
                    itemCount: 7,
                    itemBuilder: (context, index) {
                      switch (index) {
                        case 0:
                          return _buildMetricCard(
                            'Total Purchase',
                            'Rs ${_metrics?.totalPurchase.toStringAsFixed(0) ?? '0'}',
                            Icons.shopping_cart,
                            const Color(0xFF667EEA), // Vibrant purple-blue
                            '+25%',
                          );
                        case 1:
                          return _buildMetricCard(
                            'Purchase Return',
                            'Rs ${_metrics?.totalPurchaseReturn.toStringAsFixed(0) ?? '0'}',
                            Icons.assignment_return,
                            const Color(0xFFF6AD55), // Warm orange
                            '+15%',
                          );
                        case 2:
                          return _buildMetricCard(
                            'Total Sales',
                            'Rs ${_metrics?.totalSales.toStringAsFixed(0) ?? '0'}',
                            Icons.point_of_sale,
                            const Color(0xFF48BB78), // Fresh green
                            '+35%',
                          );
                        case 3:
                          return _buildMetricCard(
                            'Sales Return',
                            'Rs ${_metrics?.totalSalesReturn.toStringAsFixed(0) ?? '0'}',
                            Icons.undo,
                            const Color(0xFFF56565), // Bold red
                            '-10%',
                          );
                        case 4:
                          // Total Expense from loaded payouts
                          return _buildMetricCard(
                            'Total Expense',
                            'Rs ${_totalExpense.toStringAsFixed(0)}',
                            Icons.money_off,
                            const Color(0xFF9F7AEA), // Rich purple
                            '+20%',
                          );
                        case 5:
                          // Total Income from loaded pay-ins
                          return _buildMetricCard(
                            'Total Income',
                            'Rs ${_totalIncome.toStringAsFixed(0)}',
                            Icons.trending_up,
                            const Color(0xFF38B2AC), // Teal
                            '+30%',
                          );
                        case 6:
                          return _buildMetricCard(
                            'Profit',
                            'Rs ${_metrics?.profit.toStringAsFixed(0) ?? '0'}',
                            Icons.show_chart,
                            const Color(0xFF4299E1), // Bright blue
                            '+45%',
                          );
                        default:
                          return const SizedBox.shrink();
                      }
                    },
                  );
                },
              ),
            ),

            // Info Cards - Compact Horizontal Layout
            Container(
              margin: const EdgeInsets.only(bottom: 20),
              child: Row(
                children: [
                  Expanded(
                    child: _buildInfoCard(
                      'Total Vendors',
                      _overallInfo?.totalVendors.toString() ?? '0',
                      Icons.business,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      'Credit Customers',
                      _overallInfo?.customers.toString() ?? '0',
                      Icons.people,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildInfoCard(
                      'Products',
                      _orderStatistics?.totalProducts.toString() ?? '0',
                      Icons.inventory,
                    ),
                  ),
                ],
              ),
            ),

            // Data Sections - Improved Layout
            LayoutBuilder(
              builder: (context, constraints) {
                final isWideScreen = constraints.maxWidth > 1000;

                if (isWideScreen) {
                  // Wide screen: Two columns
                  return Column(
                    children: [
                      // First row: Top Selling and Low Stock
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildTopSellingSection()),
                          const SizedBox(width: 20),
                          Expanded(child: _buildLowStockSection()),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Second row: Recent Sales and Sales Statics
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildRecentSalesSection()),
                          const SizedBox(width: 20),
                          Expanded(child: _buildSalesStaticsSection()),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Third row: Top Categories and Sale Overview
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildTopCategoriesSection()),
                          const SizedBox(width: 20),
                          Expanded(child: _buildSaleOverviewSection()),
                        ],
                      ),
                      const SizedBox(height: 24),
                      // Full width: Recent Transactions
                      _buildRecentTransactionsSection(),
                    ],
                  );
                } else {
                  // Narrow screen: Single column
                  return Column(
                    children: [
                      _buildTopSellingSection(),
                      const SizedBox(height: 20),
                      _buildLowStockSection(),
                      const SizedBox(height: 20),
                      _buildRecentSalesSection(),
                      const SizedBox(height: 20),
                      _buildSalesStaticsSection(),
                      const SizedBox(height: 20),
                      _buildTopCategoriesSection(),
                      const SizedBox(height: 20),
                      _buildSaleOverviewSection(),
                      const SizedBox(height: 20),
                      _buildRecentTransactionsSection(),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 70,
        backgroundColor: Colors.white,
        elevation: 0,
        shadowColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(
              bottom: BorderSide(
                color: const Color(0xFF0D1845).withOpacity(0.1),
                width: 1,
              ),
            ),
          ),
        ),
        title: Row(
          children: [
            // Logo/Brand Section with enhanced design
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF0D1845),
                    Color(0xFF1A237E),
                    Color(0xFF283593),
                  ],
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF0D1845).withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Image.asset(
                'assets/logos/logo.png',
                width: 26,
                height: 26,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(width: 16),
            // App Title
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ShaderMask(
                  shaderCallback: (bounds) => const LinearGradient(
                    colors: [Color(0xFF0D1845), Color(0xFF1A237E)],
                  ).createShader(bounds),
                  child: const Text(
                    'Dhanpuri',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Groote',
                      fontSize: 22,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const Text(
                  'POS Management System',
                  style: TextStyle(
                    color: Color(0xFF6C757D),
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            // Role Badge with enhanced styling
            Consumer<AuthProvider>(
              builder: (context, authProvider, child) {
                final roleName = _getRoleName(authProvider.user?.roleId);
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF0D1845),
                        const Color(0xFF1A237E).withOpacity(0.9),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF0D1845).withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          color: Color(0xFF4CAF50),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        roleName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
            const Spacer(),
            // Date and Time Display
            _buildDateTimeDisplay(),
            const Spacer(),
          ],
        ),
        actions: [
          // Dashboard quick button with enhanced design
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            child: ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  currentContent = 'Admin Dashboard';
                });
                _loadDashboardData();
              },
              icon: const Icon(Icons.dashboard_rounded, size: 18),
              label: const Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF7C4DFF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                shadowColor: const Color(0xFF7C4DFF).withOpacity(0.3),
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Notifications button with badge
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: const Color(0xFF0D1845).withOpacity(0.05),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () {},
                child: Container(
                  padding: const EdgeInsets.all(12),
                  child: Stack(
                    children: [
                      const Icon(
                        Icons.notifications_rounded,
                        color: Color(0xFF6C757D),
                        size: 22,
                      ),
                      Positioned(
                        right: 0,
                        top: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5252),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 1.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          PopupMenuButton<String>(
            onSelected: (value) async {
              switch (value) {
                case 'profile':
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserProfilePage(),
                    ),
                  );
                  break;
                case 'logout':
                  // Clear provider state and redirect immediately
                  final authProvider = Provider.of<AuthProvider>(
                    context,
                    listen: false,
                  );
                  await authProvider.logout();
                  if (mounted) {
                    Navigator.pushNamedAndRemoveUntil(
                      context,
                      '/login',
                      (route) => false,
                    );
                  }
                  break;
              }
            },
            offset: const Offset(20, 50),
            constraints: const BoxConstraints(minWidth: 200, maxWidth: 200),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                margin: const EdgeInsets.only(right: 16),
                child: Consumer<AuthProvider>(
                  builder: (context, authProvider, child) {
                    String? imageUrl;
                    String initial = 'A'; // Default

                    if (authProvider.user != null) {
                      if (authProvider.user!.firstName.isNotEmpty) {
                        initial = authProvider.user!.firstName[0].toUpperCase();
                      }
                      // Check for profile picture in userProfile first, then user imgPath
                      imageUrl =
                          authProvider.userProfile?.profilePicture ??
                          authProvider.user!.imgPath;
                    }

                    return FutureBuilder<Uint8List?>(
                      future: imageUrl != null && !imageUrl.startsWith('http')
                          ? _loadImageBytes(imageUrl)
                          : Future.value(null),
                      builder: (context, snapshot) {
                        Uint8List? bytes = snapshot.data;
                        return CircleAvatar(
                          key: ValueKey(
                            '${imageUrl ?? 'default'}_${authProvider.imageVersion}',
                          ),
                          backgroundColor: const Color(0xFF0D1845),
                          backgroundImage: bytes != null
                              ? MemoryImage(bytes)
                              : null,
                          child: (imageUrl == null || imageUrl.isEmpty)
                              ? Text(
                                  initial,
                                  style: const TextStyle(color: Colors.white),
                                )
                              : null,
                        );
                      },
                    );
                  },
                ),
              ),
            ),
            itemBuilder: (BuildContext context) => [
              PopupMenuItem<String>(
                value: 'profile',
                height: 48,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0D1845).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Color(0xFF0D1845),
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'User Profile',
                        style: TextStyle(
                          color: Color(0xFF343A40),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const PopupMenuDivider(height: 1),
              PopupMenuItem<String>(
                value: 'logout',
                height: 48,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.logout,
                          color: Colors.red,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Logout',
                        style: TextStyle(
                          color: Color(0xFF343A40),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          Row(
            children: [
              // Sidebar - Hide when POS is active
              if (currentContent != 'POS')
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: _isSidebarOpen ? 280 : 60,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                  child: Consumer<AuthProvider>(
                    builder: (context, authProvider, child) {
                      final allowedSections = _getAllowedSections(
                        authProvider.user?.roleId,
                      );
                      return Theme(
                        data: Theme.of(context).copyWith(
                          scrollbarTheme: ScrollbarThemeData(
                            thumbColor: WidgetStateProperty.all(
                              Colors.white.withOpacity(0.5),
                            ),
                            trackColor: WidgetStateProperty.all(
                              Colors.white.withOpacity(0.1),
                            ),
                            thickness: WidgetStateProperty.all(6.0),
                            radius: const Radius.circular(3),
                            thumbVisibility: WidgetStateProperty.all(true),
                            trackVisibility: WidgetStateProperty.all(true),
                          ),
                        ),
                        child: Builder(
                          builder: (context) {
                            final ScrollController scrollController =
                                ScrollController();
                            return Scrollbar(
                              controller: scrollController,
                              thumbVisibility: true,
                              trackVisibility: true,
                              child: ListView(
                                controller: scrollController,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 20,
                                ),
                                physics:
                                    const ClampingScrollPhysics(), // Prevents stuttering
                                children: _buildSidebarChildren(
                                  allowedSections,
                                ),
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                ),
              // Main Content
              Expanded(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: _buildMainContent(),
                ),
              ),
            ],
          ),
          // Toggle Button - Hide when POS is active
          if (currentContent != 'POS')
            Positioned(
              left: (_isSidebarOpen ? 280 : 60) - 15,
              top: 40,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: const Color(0xFF0D1845),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black45,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: AnimatedRotation(
                    turns: _isSidebarOpen ? 0.0 : 0.5,
                    duration: const Duration(milliseconds: 300),
                    child: const Icon(
                      Icons.chevron_left,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  onPressed: toggleSidebar,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDropdownButton(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: DropdownButton<String>(
        value: selectedTopSellingPeriod,
        underline: const SizedBox(),
        icon: const Icon(
          Icons.keyboard_arrow_down,
          color: Color(0xFF64748B),
          size: 18,
        ),
        style: const TextStyle(
          color: Color(0xFF475569),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        items: ['Today', 'This Week', 'This Month', 'This Year']
            .map(
              (period) => DropdownMenuItem(value: period, child: Text(period)),
            )
            .toList(),
        onChanged: (value) {
          if (value != null) {
            updateTopSellingPeriod(value);
          }
        },
      ),
    );
  }

  // New sidebar methods for improved design
  Widget _buildSectionDivider({bool isSubDivider = false}) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: isSubDivider ? 4 : 8),
      height: 1,
      color: Colors.white.withOpacity(isSubDivider ? 0.2 : 0.3),
    );
  }

  Widget _buildMainSectionTile(
    IconData icon,
    String title,
    List<Widget> children,
  ) {
    final bool isExpanded = _sectionExpanded[title] ?? false;
    return Container(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: InkWell(
              onTap: () => toggleSection(title),
              borderRadius: BorderRadius.circular(8),
              child: AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: _isSidebarOpen
                    ? CrossFadeState.showSecond
                    : CrossFadeState.showFirst,
                firstChild: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: Colors.white, size: 16),
                    ),
                  ],
                ),
                secondChild: Row(
                  mainAxisSize: MainAxisSize.max,
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                    AnimatedRotation(
                      turns: isExpanded ? 0.0 : -0.25,
                      duration: const Duration(milliseconds: 300),
                      child: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white.withOpacity(0.7),
                        size: 20,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: SizedBox(
              height: (_isSidebarOpen && isExpanded && children.isNotEmpty)
                  ? null
                  : 0,
              child: Column(
                children: (_isSidebarOpen && isExpanded && children.isNotEmpty)
                    ? children
                    : [],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandablePrimarySubTile(
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    final bool isExpanded = _sectionExpanded[title] ?? false;
    return Container(
      child: Column(
        children: [
          Container(
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
            child: InkWell(
              onTap: () => toggleSection(title),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: _isSidebarOpen
                    ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
                    : const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.white.withOpacity(0.05),
                ),
                child: AnimatedCrossFade(
                  duration: const Duration(milliseconds: 300),
                  crossFadeState: _isSidebarOpen
                      ? CrossFadeState.showSecond
                      : CrossFadeState.showFirst,
                  firstChild: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        icon,
                        color: Colors.white.withOpacity(0.8),
                        size: 12,
                      ),
                    ],
                  ),
                  secondChild: Row(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Icon(
                        icon,
                        color: Colors.white.withOpacity(0.8),
                        size: 16,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      AnimatedRotation(
                        turns: isExpanded ? 0.0 : -0.25,
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white.withOpacity(0.7),
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: SizedBox(
              height: (_isSidebarOpen && isExpanded && children.isNotEmpty)
                  ? null
                  : 0,
              child: Column(
                children: (_isSidebarOpen && isExpanded && children.isNotEmpty)
                    ? children
                    : [],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimarySubTile(String title, IconData icon) {
    final isSelected = currentContent == title;
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
      child: InkWell(
        onTap: () => UnsavedChangesGuard().maybeNavigate(
          context,
          () => updateContent(title),
        ),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: _isSidebarOpen
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
              : const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? Colors.white.withOpacity(0.2)
                : Colors.white.withOpacity(0.05),
            border: isSelected
                ? Border.all(color: Colors.white.withOpacity(0.3), width: 1)
                : null,
          ),
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isSidebarOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.8),
                  size: 12,
                ),
              ],
            ),
            secondChild: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.8),
                  size: 16,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.9),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSecondarySubTile(String title, IconData icon) {
    final isSelected = currentContent == title;
    return Container(
      margin: const EdgeInsets.only(left: 32, right: 16, bottom: 4),
      child: InkWell(
        onTap: () => UnsavedChangesGuard().maybeNavigate(context, () {
          updateContent(title);
        }),
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: _isSidebarOpen
              ? const EdgeInsets.symmetric(horizontal: 8, vertical: 8)
              : const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
          decoration: isSelected
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.white.withOpacity(0.15),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.25),
                    width: 1,
                  ),
                )
              : null,
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isSidebarOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.7),
                  size: 10,
                ),
              ],
            ),
            secondChild: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(
                  icon,
                  color: isSelected
                      ? Colors.white
                      : Colors.white.withOpacity(0.7),
                  size: 14,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? Colors.white
                          : Colors.white.withOpacity(0.8),
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSubHeaderTile(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 6, top: 6),
      child: Container(
        padding: _isSidebarOpen
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8)
            : const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: Colors.white.withOpacity(0.08),
        ),
        child: AnimatedCrossFade(
          duration: const Duration(milliseconds: 300),
          crossFadeState: _isSidebarOpen
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          firstChild: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.9), size: 12),
            ],
          ),
          secondChild: Row(
            mainAxisSize: MainAxisSize.max,
            children: [
              Icon(icon, color: Colors.white.withOpacity(0.9), size: 16),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.white.withOpacity(0.95),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackupTile(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, top: 14, bottom: 7),
      child: InkWell(
        onTap: () async {
          // Show loading dialog
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (BuildContext context) {
              return AlertDialog(
                backgroundColor: Colors.white,
                content: Row(
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF0D1845),
                      ),
                    ),
                    SizedBox(width: 16),
                    Text(
                      'Creating backup...',
                      style: TextStyle(color: Colors.black),
                    ),
                  ],
                ),
              );
            },
          );

          try {
            final response = await ApiService.createDatabaseBackup();

            // Close loading dialog
            if (mounted) Navigator.of(context).pop();

            // Show success dialog with simple message
            if (mounted) {
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
                        Icon(Icons.check_circle, color: Colors.green, size: 32),
                        SizedBox(width: 12),
                        Text(
                          'Success',
                          style: TextStyle(
                            color: Color(0xFF0D1845),
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    content: Text(
                      response['message'] ??
                          'Database backup created successfully!',
                      style: TextStyle(color: Colors.black87, fontSize: 16),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: TextButton.styleFrom(
                          backgroundColor: Color(0xFF0D1845),
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('OK'),
                      ),
                    ],
                  );
                },
              );
            }
          } catch (e) {
            // Close loading dialog
            if (mounted) Navigator.of(context).pop();

            // Show error dialog
            if (mounted) {
              showDialog(
                context: context,
                builder: (BuildContext context) {
                  return AlertDialog(
                    backgroundColor: Colors.white,
                    title: Row(
                      children: [
                        Icon(Icons.error, color: Colors.red, size: 28),
                        SizedBox(width: 12),
                        Text(
                          'Backup Failed',
                          style: TextStyle(
                            color: Color(0xFF0D1845),
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    content: Text(
                      e.toString().replaceAll('Exception: ', ''),
                      style: TextStyle(color: Colors.black87),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          'OK',
                          style: TextStyle(color: Color(0xFF0D1845)),
                        ),
                      ),
                    ],
                  );
                },
              );
            }
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: _isSidebarOpen
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
              : const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.blue.withOpacity(0.1),
          ),
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isSidebarOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.blue.withOpacity(0.8), size: 12),
              ],
            ),
            secondChild: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(icon, color: Colors.blue.withOpacity(0.8), size: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blue.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutTile(String title, IconData icon) {
    return Container(
      margin: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
      child: InkWell(
        onTap: () async {
          final authProvider = Provider.of<AuthProvider>(
            context,
            listen: false,
          );
          await authProvider.logout();
          if (mounted) {
            Navigator.pushReplacementNamed(context, '/login');
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: _isSidebarOpen
              ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
              : const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.red.withOpacity(0.1),
          ),
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isSidebarOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, color: Colors.red.withOpacity(0.8), size: 12),
              ],
            ),
            secondChild: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(icon, color: Colors.red.withOpacity(0.8), size: 16),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.red.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMetricCard(
    String title,
    String value,
    IconData icon,
    Color color,
    String change,
  ) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Small & elegant sizing
        final cardWidth = constraints.maxWidth;
        final isTiny = cardWidth < 150;

        final double padding = isTiny ? 8.0 : 10.0;
        final double iconSize = isTiny ? 14.0 : 16.0;
        final double titleFontSize = isTiny ? 9.0 : 10.0;
        final double valueFontSize = isTiny ? 13.0 : 15.0;

        return Container(
          margin: const EdgeInsets.all(3.0),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [color, color.withOpacity(0.85)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.25),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Subtle background pattern
              Positioned(
                right: -15,
                top: -15,
                child: Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              // Content
              Padding(
                padding: EdgeInsets.all(padding),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: EdgeInsets.all(isTiny ? 5 : 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Icon(
                            icon,
                            color: Colors.white,
                            size: iconSize,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: titleFontSize,
                        color: Colors.white.withOpacity(0.95),
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: valueFontSize,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 5),
                    // Compact sparkline
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildMiniBar(12, Colors.white.withOpacity(0.5)),
                        const SizedBox(width: 2),
                        _buildMiniBar(18, Colors.white.withOpacity(0.6)),
                        const SizedBox(width: 2),
                        _buildMiniBar(15, Colors.white.withOpacity(0.5)),
                        const SizedBox(width: 2),
                        _buildMiniBar(22, Colors.white.withOpacity(0.75)),
                        const SizedBox(width: 2),
                        _buildMiniBar(20, Colors.white.withOpacity(0.7)),
                        const SizedBox(width: 2),
                        _buildMiniBar(24, Colors.white.withOpacity(0.8)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMiniBar(double height, Color color) {
    return Container(
      width: 3,
      height: height,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(1.5),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667EEA).withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(icon, size: 20, color: Colors.white),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF64748B),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProductItem(
    String name,
    String price,
    String sales,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color.withOpacity(0.15), color.withOpacity(0.05)],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.shopping_bag, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$price • $sales',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(Icons.trending_up, color: color, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildLowStockItem(String name, String id, String stock) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFEF3C7), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: Colors.orange[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.2)),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orange,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'ID: $id',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              stock,
              style: const TextStyle(
                color: Colors.orange,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentSaleItem(
    String productName,
    String category,
    String price,
    String date,
    String status,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.15),
                  Colors.blue.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.receipt_long, color: Colors.blue, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  productName,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF1E293B),
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$category • $price',
                  style: const TextStyle(
                    color: Color(0xFF64748B),
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getStatusColor(status).withOpacity(0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _getStatusColor(status).withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: _getStatusColor(status),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSalesStaticItem(
    String label,
    String value,
    String change,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6C757D)),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF343A40),
            ),
          ),
          if (change.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  change.startsWith('+')
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: color,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  change,
                  style: TextStyle(color: color, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSaleOverviewItem(
    String label,
    String value,
    String change,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 14, color: Color(0xFF6C757D)),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF343A40),
            ),
          ),
          if (change.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  change.startsWith('+')
                      ? Icons.trending_up
                      : Icons.trending_down,
                  color: color,
                  size: 16,
                ),
                const SizedBox(width: 4),
                Text(
                  change,
                  style: TextStyle(color: color, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF667EEA).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFF667EEA).withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: Color(0xFF667EEA),
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getStatusColor(status).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: _getStatusColor(status),
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
      ),
    );
  }

  Widget _buildTopCategoryItem(String name, int sales) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
              ),
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF667EEA).withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.category_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF1E293B),
                fontSize: 13,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  const Color(0xFF667EEA).withOpacity(0.15),
                  const Color(0xFF764BA2).withOpacity(0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '$sales',
              style: const TextStyle(
                color: Color(0xFF667EEA),
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildSidebarChildren(List<String> allowedSections) {
    final List<Widget> children = [];

    // Header - Always visible
    children.add(
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: () => UnsavedChangesGuard().maybeNavigate(
            context,
            () => updateContent('Admin Dashboard'),
          ),
          borderRadius: BorderRadius.circular(8),
          child: AnimatedCrossFade(
            duration: const Duration(milliseconds: 300),
            crossFadeState: _isSidebarOpen
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            firstChild: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.dashboard, color: Colors.white, size: 16),
                ),
              ],
            ),
            secondChild: Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.dashboard, color: Colors.white, size: 20),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Admin Dashboard',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    // Section Divider
    if (_isSidebarOpen) children.add(_buildSectionDivider());

    // Inventory Section
    if (allowedSections.contains('Inventory')) {
      children.add(
        _buildMainSectionTile(Icons.inventory_2, 'Inventory Settings', [
          _buildPrimarySubTile('Products', Icons.inventory),
          _buildPrimarySubTile('Create Product', Icons.add_circle),
          _buildSectionDivider(isSubDivider: true),
          _buildPrimarySubTile('Category', Icons.category),
          _buildPrimarySubTile('Sub Category', Icons.subdirectory_arrow_right),
          _buildPrimarySubTile('Vendor', Icons.business_center),
          _buildPrimarySubTile(
            'Print Barcode / QR Code',
            Icons.qr_code_scanner,
          ),
          _buildSectionDivider(isSubDivider: true),
          // Variants Subsection
          _buildSubHeaderTile('Variants', Icons.palette),
          _buildSecondarySubTile('Color', Icons.color_lens),
          _buildSecondarySubTile('Sizes', Icons.straighten),
          _buildSecondarySubTile('Seasons', Icons.wb_sunny),
          _buildSecondarySubTile('Material', Icons.texture),
        ]),
      );
      if (_isSidebarOpen) children.add(_buildSectionDivider());
    }

    // Sales Section
    if (allowedSections.contains('Sales')) {
      children.add(
        _buildMainSectionTile(Icons.shopping_cart, 'Sales', [
          _buildPrimarySubTile('Invoices', Icons.receipt_long),
          _buildPrimarySubTile('Sales Return', Icons.undo),
          _buildPrimarySubTile('POS', Icons.smartphone),
        ]),
      );
      if (_isSidebarOpen) children.add(_buildSectionDivider());
    }

    // Purchase Section
    if (allowedSections.contains('Purchase')) {
      children.add(
        _buildMainSectionTile(Icons.shopping_bag, 'Purchase', [
          _buildPrimarySubTile('Purchase Listing', Icons.list_alt),
          _buildPrimarySubTile('Purchase Return', Icons.assignment_return),
        ]),
      );
      if (_isSidebarOpen) children.add(_buildSectionDivider());
    }

    // Finance Section
    if (allowedSections.contains('Finance & Accounts')) {
      children.add(
        _buildMainSectionTile(
          Icons.account_balance_wallet,
          'Finance & Accounts',
          [
            _buildPrimarySubTile('Payout (Expenses)', Icons.money_off),
            _buildPrimarySubTile('Payin (Income)', Icons.trending_up),
            _buildPrimarySubTile('Bank Accounts', Icons.account_balance),
            _buildPrimarySubTile('Chart of Accounts', Icons.account_tree),
          ],
        ),
      );
      if (_isSidebarOpen) children.add(_buildSectionDivider());
    }

    // People Section
    if (allowedSections.contains('Peoples')) {
      children.add(
        _buildMainSectionTile(Icons.people_alt, 'Peoples', [
          _buildPrimarySubTile('Credit Customer', Icons.people),
          _buildPrimarySubTile('Vendor\'s Profile', Icons.business),
          // Employees primary tile with nested attendance sub-item
          Container(
            margin: const EdgeInsets.only(left: 16, right: 16, bottom: 6),
            child: Column(
              children: [
                // Primary clickable tile
                InkWell(
                  onTap: () => UnsavedChangesGuard().maybeNavigate(
                    context,
                    () => updateContent('Employees Profile'),
                  ),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    padding: _isSidebarOpen
                        ? const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          )
                        : const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 6,
                          ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: currentContent == 'Employees Profile'
                          ? Colors.white.withOpacity(0.2)
                          : Colors.white.withOpacity(0.05),
                      border: currentContent == 'Employees Profile'
                          ? Border.all(
                              color: Colors.white.withOpacity(0.3),
                              width: 1,
                            )
                          : null,
                    ),
                    child: AnimatedCrossFade(
                      duration: const Duration(milliseconds: 300),
                      crossFadeState: _isSidebarOpen
                          ? CrossFadeState.showSecond
                          : CrossFadeState.showFirst,
                      firstChild: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.badge,
                            color: Colors.white.withOpacity(0.8),
                            size: 12,
                          ),
                        ],
                      ),
                      secondChild: Row(
                        mainAxisSize: MainAxisSize.max,
                        children: [
                          Icon(
                            Icons.badge,
                            color: currentContent == 'Employees Profile'
                                ? Colors.white
                                : Colors.white.withOpacity(0.8),
                            size: 16,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Employees Profile',
                              style: TextStyle(
                                fontSize: 13,
                                color: currentContent == 'Employees Profile'
                                    ? Colors.white
                                    : Colors.white.withOpacity(0.9),
                                fontWeight:
                                    currentContent == 'Employees Profile'
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ),
                          // Expand/collapse chevron
                          GestureDetector(
                            onTap: () => toggleSection('Employees Profile'),
                            child: AnimatedRotation(
                              turns:
                                  (_sectionExpanded['Employees Profile'] ??
                                      false)
                                  ? 0.0
                                  : -0.25,
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                Icons.keyboard_arrow_down,
                                color: Colors.white.withOpacity(0.7),
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Nested Attendance sub-item (collapsible)
                AnimatedSize(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  child: SizedBox(
                    height:
                        (_isSidebarOpen &&
                            (_sectionExpanded['Employees Profile'] ?? false))
                        ? null
                        : 0,
                    child: Column(
                      children:
                          (_isSidebarOpen &&
                              (_sectionExpanded['Employees Profile'] ?? false))
                          ? [
                              _buildSecondarySubTile(
                                'Employee\'s Attendance',
                                Icons.access_time,
                              ),
                            ]
                          : [],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ]),
      );
      if (_isSidebarOpen) children.add(_buildSectionDivider());
    }

    // Reports Section
    if (allowedSections.contains('Reports')) {
      children.add(
        _buildMainSectionTile(Icons.analytics, 'Reports', [
          _buildExpandablePrimarySubTile('Sales Reports', Icons.bar_chart, [
            _buildSecondarySubTile('Product Sale Report', Icons.receipt),
            _buildSecondarySubTile('Best Selling Products', Icons.trending_up),
            _buildSecondarySubTile('Salesman Report', Icons.person),
          ]),
          _buildSectionDivider(isSubDivider: true),
          _buildSecondarySubTile('Purchase Report', Icons.bar_chart),
          _buildSecondarySubTile('Inventory Report', Icons.inventory_2),
          _buildSecondarySubTile('Low Stock Products', Icons.warning_amber),
          _buildSecondarySubTile('Vendor Report', Icons.business),
          // _buildSecondarySubTile('Invoice Report', Icons.receipt),
          _buildSecondarySubTile('Credit Customer Report', Icons.group),
          _buildSecondarySubTile(
            'Daily Transaction Report',
            Icons.calendar_today,
          ),
          _buildSecondarySubTile('Account Statement', Icons.description),
          _buildSecondarySubTile('Cashflow', Icons.account_balance_wallet),
          //_buildSecondarySubTile('Product\'s Report', Icons.inventory),
          // _buildSecondarySubTile('Expense Report', Icons.money_off),
          // _buildSecondarySubTile('Income Report', Icons.trending_up),
          // _buildSecondarySubTile('Profit & Loss', Icons.show_chart),
        ]),
      );
      if (_isSidebarOpen) children.add(_buildSectionDivider());
    }

    // Users Section
    if (allowedSections.contains('Users')) {
      children.add(
        _buildMainSectionTile(Icons.admin_panel_settings, 'Users', [
          _buildPrimarySubTile('Users', Icons.group),
          _buildPrimarySubTile('Roles & Permissions', Icons.security),
        ]),
      );
      if (_isSidebarOpen) children.add(_buildSectionDivider());
    }

    // Backup button above logout
    children.add(_buildBackupTile('Backup', Icons.backup));

    // Logout always visible in the sidebar (keep only logout, remove Settings)
    children.add(_buildLogoutTile('Logout', Icons.logout));
    if (_isSidebarOpen) children.add(_buildSectionDivider());

    return children;
  }

  String _getRoleName(String? roleId) {
    switch (roleId) {
      case '1':
        return 'Super Admin';
      case '2':
        return 'Admin';
      case '3':
        return 'Manager';
      case '4':
        return 'Cashier';
      case '5':
        return 'Inventory Officer';
      case '6':
        return 'Salesman';
      default:
        return 'User';
    }
  }

  List<String> _getAllowedSections(String? roleId) {
    switch (roleId) {
      case '1': // Super Admin - all access (same as Admin)
      case '2': // Admin - all access
        return [
          'Inventory',
          'Sales',
          'Purchase',
          'Finance & Accounts',
          'Peoples',
          'Reports',
          'Users',
        ];
      case '3': // Manager - Reports + Inventory
        return ['Inventory', 'Reports'];
      case '4': // Cashier - Finance
        return ['Finance & Accounts'];
      case '5': // Inventory Officer - Inventory only
        return ['Inventory'];
      case '6': // Salesman - Sales section
        return ['Sales'];
      default:
        return [];
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'processing':
        return Colors.blue;
      case 'pending':
        return Colors.orange;
      case 'cancelled':
        return Colors.red;
      case 'draft':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  // Section builder methods for improved layout
  Widget _buildTopSellingSection() {
    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF48BB78), Color(0xFF38A169)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.trending_up,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Top Selling Products',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                _buildDropdownButton('Today'),
              ],
            ),
            const SizedBox(height: 14),
            ..._topSellingProducts.map(
              (product) => _buildProductItem(
                product.name,
                product.price,
                product.sales,
                product.change == '+25%' ? Colors.green : Colors.orange,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLowStockSection() {
    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: const Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.orange,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Low Stock Products',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ..._lowStockProducts.map(
              (product) =>
                  _buildLowStockItem(product.name, product.id, product.stock),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LowStockProductsPage(),
                  ),
                ),
                icon: const Icon(Icons.arrow_forward, size: 14),
                label: const Text('View All'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.orange,
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSalesSection() {
    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4299E1), Color(0xFF3182CE)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.receipt_long,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Recent Sales',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                _buildDropdownButton('Weekly'),
              ],
            ),
            const SizedBox(height: 14),
            ..._recentSales.map(
              (sale) => _buildRecentSaleItem(
                sale.productName,
                sale.category,
                sale.price,
                sale.date,
                sale.status,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSalesStaticsSection() {
    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF9F7AEA), Color(0xFF805AD5)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.bar_chart,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Sales Statistics',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                _buildDropdownButton('2025'),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSalesStaticItem(
                    'Revenue',
                    'Rs ${_salesStatics?.revenue.toStringAsFixed(0) ?? '0'}',
                    '',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSalesStaticItem(
                    'Expense',
                    'Rs ${_salesStatics?.expense.toStringAsFixed(0) ?? '0'}',
                    '',
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Sales Statistics Bar Chart
            Container(
              height: 150,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY:
                      (_salesStatics?.revenue ?? 0) >
                          (_salesStatics?.expense ?? 0)
                      ? (_salesStatics?.revenue ?? 0) * 1.2
                      : (_salesStatics?.expense ?? 0) * 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String label = rodIndex == 0 ? 'Revenue' : 'Expense';
                        return BarTooltipItem(
                          '$label\nRs ${rod.toY.toStringAsFixed(0)}',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          switch (value.toInt()) {
                            case 0:
                              return const Text(
                                'Revenue',
                                style: TextStyle(fontSize: 12),
                              );
                            case 1:
                              return const Text(
                                'Expense',
                                style: TextStyle(fontSize: 12),
                              );
                            default:
                              return const Text('');
                          }
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            'Rs ${value.toInt()}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: _salesStatics?.revenue ?? 0,
                          color: Colors.green,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: _salesStatics?.expense ?? 0,
                          color: Colors.red,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
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

  Widget _buildTopCategoriesSection() {
    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.category_rounded,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Top Categories',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
                _buildDropdownButton('Weekly'),
              ],
            ),
            const SizedBox(height: 14),
            ..._topCategories.map(
              (category) =>
                  _buildTopCategoryItem(category.name, category.sales),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSaleOverviewSection() {
    return Card(
      elevation: 0,
      shadowColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF38B2AC), Color(0xFF319795)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.show_chart,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Sale Overview',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E293B),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSaleOverviewItem(
                    'Daily Sales',
                    'Rs ${_dailySalesAndReturns?['sales']?.toStringAsFixed(0) ?? '0'}',
                    '',
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildSaleOverviewItem(
                    'Daily Returns',
                    'Rs ${_dailySalesAndReturns?['returns']?.toStringAsFixed(0) ?? '0'}',
                    '',
                    Colors.red,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Sale Overview Bar Chart
            Container(
              height: 150,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY:
                      (_dailySalesAndReturns?['sales'] ?? 0) >
                          (_dailySalesAndReturns?['returns'] ?? 0)
                      ? (_dailySalesAndReturns?['sales'] ?? 0) * 1.2
                      : (_dailySalesAndReturns?['returns'] ?? 0) * 1.2,
                  barTouchData: BarTouchData(
                    enabled: true,
                    touchTooltipData: BarTouchTooltipData(
                      tooltipBgColor: Colors.blueGrey,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        String label = rodIndex == 0
                            ? 'Daily Sales'
                            : 'Daily Returns';
                        return BarTooltipItem(
                          '$label\nRs ${rod.toY.toStringAsFixed(0)}',
                          const TextStyle(color: Colors.white),
                        );
                      },
                    ),
                  ),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          switch (value.toInt()) {
                            case 0:
                              return const Text(
                                'Sales',
                                style: TextStyle(fontSize: 12),
                              );
                            case 1:
                              return const Text(
                                'Returns',
                                style: TextStyle(fontSize: 12),
                              );
                            default:
                              return const Text('');
                          }
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            'Rs ${value.toInt()}',
                            style: const TextStyle(fontSize: 10),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  barGroups: [
                    BarChartGroupData(
                      x: 0,
                      barRods: [
                        BarChartRodData(
                          toY: _dailySalesAndReturns?['sales'] ?? 0,
                          color: Colors.green,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
                    ),
                    BarChartGroupData(
                      x: 1,
                      barRods: [
                        BarChartRodData(
                          toY: _dailySalesAndReturns?['returns'] ?? 0,
                          color: Colors.red,
                          width: 20,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ],
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

  Widget _buildRecentTransactionsSection() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Card(
        elevation: 0,
        shadowColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 12,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Section
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF0D1845), Color(0xFF1A237E)],
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.shopping_bag,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'Recent Purchases',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1E293B),
                        ),
                      ),
                    ],
                  ),
                  // Filter Chips
                  Wrap(
                    spacing: 6,
                    children: [
                      _buildFilterChip('All'),
                      _buildFilterChip('Today'),
                      _buildFilterChip('Week'),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Table Container
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: const Color(0xFFFAFBFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isWideScreen = constraints.maxWidth > 900;
                      return SingleChildScrollView(
                        scrollDirection: isWideScreen
                            ? Axis.vertical
                            : Axis.horizontal,
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minWidth: isWideScreen ? constraints.maxWidth : 800,
                          ),
                          child: DataTable(
                            columnSpacing: isWideScreen ? 24 : 12,
                            horizontalMargin: 16,
                            headingRowHeight: 44,
                            dataRowHeight: 52,
                            headingTextStyle: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF64748B),
                              letterSpacing: 0.3,
                            ),
                            dataTextStyle: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF1E293B),
                              fontWeight: FontWeight.w500,
                            ),
                            border: TableBorder(
                              horizontalInside: BorderSide(
                                color: const Color(0xFFE2E8F0),
                                width: 1,
                              ),
                            ),
                            columns: [
                              DataColumn(
                                label: SizedBox(
                                  width: isWideScreen ? 60 : 50,
                                  child: const Text(
                                    'ID',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: SizedBox(
                                  width: isWideScreen ? 100 : 80,
                                  child: const Text(
                                    'Date',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: SizedBox(
                                  width: isWideScreen ? 150 : 120,
                                  child: const Text(
                                    'Vendor',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: SizedBox(
                                  width: isWideScreen ? 120 : 100,
                                  child: const Text(
                                    'Invoice No',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: SizedBox(
                                  width: isWideScreen ? 100 : 80,
                                  child: const Text(
                                    'Amount',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                              DataColumn(
                                label: SizedBox(
                                  width: isWideScreen ? 120 : 100,
                                  child: const Text(
                                    'Payment Status',
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                            ],
                            rows: _recentPurchases.map((purchase) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    SizedBox(
                                      width: isWideScreen ? 60 : 50,
                                      child: Text(
                                        purchase.purInvId,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF667EEA),
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: isWideScreen ? 100 : 80,
                                      child: Text(
                                        purchase.purDate,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: isWideScreen ? 150 : 120,
                                      child: Text(
                                        purchase.vendorName,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: isWideScreen ? 120 : 100,
                                      child: Text(
                                        purchase.venInvNo,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: isWideScreen ? 100 : 80,
                                      child: Text(
                                        'Rs ${double.tryParse(purchase.invAmount)?.toStringAsFixed(0) ?? '0'}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF28A745),
                                          fontSize: 14,
                                        ),
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: isWideScreen ? 120 : 100,
                                      child: Center(
                                        child: _buildStatusChip(
                                          purchase.paymentStatus,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // Footer with total count or empty message
              if (_recentPurchases.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFDEE2E6),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: const Color(0xFF6C757D),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Showing ${_recentPurchases.length} recent purchases',
                        style: const TextStyle(
                          color: Color(0xFF6C757D),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                )
              else
                Container(
                  margin: const EdgeInsets.only(top: 16),
                  padding: const EdgeInsets.symmetric(
                    vertical: 24,
                    horizontal: 24,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFDEE2E6),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.inbox_outlined,
                          color: const Color(0xFF9CA3AF),
                          size: 48,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'No recent purchases found',
                          style: const TextStyle(
                            color: Color(0xFF6C757D),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
