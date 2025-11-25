import 'package:flutter/material.dart';
import '../pages/login_page.dart';
import '../pages/dashboard_page.dart';
import '../pages/sales/pos_page.dart';
import '../pages/Finance & accounts/chart_of_accounts_page.dart';
import '../pages/cashflow_page.dart';
import '../pages/inventory/product_list_page.dart';
import '../pages/reportings/customer_report_page.dart';
import '../services/sales_service.dart';

class AppRoutes {
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String pos = '/pos';
  static const String chartOfAccounts = '/chart-of-accounts';
  static const String cashflow = '/cashflow';
  static const String products = '/products';
  static const String customerReport = '/customer-report';

  static Map<String, WidgetBuilder> getRoutes() {
    return {
      login: (context) => const LoginPage(),
      dashboard: (context) => const DashboardPage(),
      pos: (context) {
        final args = ModalRoute.of(context)?.settings.arguments as Invoice?;
        return PosPage(invoiceToEdit: args);
      },
      chartOfAccounts: (context) => const ChartOfAccountsPage(),
      cashflow: (context) => const CashflowPage(),
      products: (context) => const ProductListPage(),
      customerReport: (context) => const CustomerReportPage(),
    };
  }
}
