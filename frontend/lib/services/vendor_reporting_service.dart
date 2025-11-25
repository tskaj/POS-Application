import '../services/services.dart';

// Safe parsing helpers to handle APIs that return numbers as strings
int _parseInt(dynamic value) {
  if (value == null) return 0;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? 0;
}

double _parseDouble(dynamic value) {
  if (value == null) return 0.0;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? 0.0;
}

// Vendor Report Model
class VendorReport {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String cnic;
  final String city;
  final int totalInvoices;
  final double debit;
  final double credit;
  final double balance;

  VendorReport({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.cnic,
    required this.city,
    required this.totalInvoices,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  factory VendorReport.fromJson(Map<String, dynamic> json) {
    return VendorReport(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      cnic: json['cnic']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      totalInvoices: _parseInt(json['total_invoices']),
      debit: _parseDouble(json['debit']),
      credit: _parseDouble(json['credit']),
      balance: _parseDouble(json['balance']),
    );
  }
}

// Vendor Transaction Model
class VendorTransaction {
  final String transId;
  final String invRefId;
  final String date;
  final String description;
  final String debit;
  final String credit;

  VendorTransaction({
    required this.transId,
    required this.invRefId,
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
  });

  factory VendorTransaction.fromJson(Map<String, dynamic> json) {
    // API sometimes returns different keys for transaction id and invoice ref.
    // Try a list of possible keys and fall back to sensible defaults.
    String pickFirstString(
      Map<String, dynamic> map,
      List<String> keys, [
      String fallback = '',
    ]) {
      for (final k in keys) {
        if (map.containsKey(k) && map[k] != null) {
          final v = map[k].toString();
          if (v.isNotEmpty) return v;
        }
      }
      return fallback;
    }

    final transId = pickFirstString(json, [
      'trans_id',
      'id',
      'transaction_id',
    ], '');
    final invRefId = pickFirstString(json, [
      'invRef_id',
      'inv_ref',
      'invoice_id',
      'inv_id',
      'reference',
    ], '-');

    return VendorTransaction(
      transId: transId,
      invRefId: invRefId,
      date: json['date']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      debit: json['debit']?.toString() ?? '0.00',
      credit: json['credit']?.toString() ?? '0.00',
    );
  }
}

// Vendor Details Response Model
class VendorDetailsResponse {
  final int id;
  final String name;
  final String email;
  final String phone;
  final String city;
  final String address;
  final String status;
  final double totalDebit;
  final double totalCredit;
  final double balance;
  final int totalTransactions;
  final List<VendorTransaction> transactions;

  VendorDetailsResponse({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.city,
    required this.address,
    required this.status,
    required this.totalDebit,
    required this.totalCredit,
    required this.balance,
    required this.totalTransactions,
    required this.transactions,
  });

  factory VendorDetailsResponse.fromJson(Map<String, dynamic> json) {
    final vendor = json['vendor'] ?? {};
    final transactions = json['transactions'] ?? [];

    return VendorDetailsResponse(
      id: _parseInt(vendor['id']),
      name: vendor['name']?.toString() ?? '',
      email: vendor['email']?.toString() ?? '',
      phone: vendor['phone']?.toString() ?? '',
      city: vendor['city']?.toString() ?? '',
      address: vendor['address']?.toString() ?? 'N/A',
      status: vendor['status']?.toString() ?? 'Active',
      totalDebit: _parseDouble(vendor['total_debit']),
      totalCredit: _parseDouble(vendor['total_credit']),
      balance: _parseDouble(vendor['balance']),
      totalTransactions: _parseInt(vendor['total_transactions']),
      transactions: (transactions as List<dynamic>)
          .map((item) => VendorTransaction.fromJson(item))
          .toList(),
    );
  }
}

// Overall Totals Model
class VendorOverallTotals {
  final int invoices;
  final double debit;
  final double credit;
  final double balance;

  VendorOverallTotals({
    required this.invoices,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  factory VendorOverallTotals.fromJson(Map<String, dynamic> json) {
    return VendorOverallTotals(
      invoices: _parseInt(json['invoices']),
      debit: _parseDouble(json['debit']),
      credit: _parseDouble(json['credit']),
      balance: _parseDouble(json['balance']),
    );
  }
}

// Response models
class VendorReportsResponse {
  final String status;
  final String message;
  final VendorOverallTotals overallTotals;
  final List<VendorReport> data;

  VendorReportsResponse({
    required this.status,
    required this.message,
    required this.overallTotals,
    required this.data,
  });

  factory VendorReportsResponse.fromJson(Map<String, dynamic> json) {
    return VendorReportsResponse(
      status: json['status']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      overallTotals: VendorOverallTotals.fromJson(json['overall_totals'] ?? {}),
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => VendorReport.fromJson(item))
              .toList() ??
          [],
    );
  }
}

// Service class
class VendorReportingService {
  static const String allVendorsReportEndpoint = '/allVendorsReport';

  static Future<VendorReportsResponse> getAllVendorsReport() async {
    try {
      final response = await ApiService.get(allVendorsReportEndpoint);

      if (response.containsKey('data')) {
        final vendorReportsResponse = VendorReportsResponse.fromJson(response);
        return vendorReportsResponse;
      } else {
        return VendorReportsResponse(
          status: 'error',
          message: 'No data found',
          overallTotals: VendorOverallTotals(
            invoices: 0,
            debit: 0.0,
            credit: 0.0,
            balance: 0.0,
          ),
          data: [],
        );
      }
    } catch (e) {
      throw Exception('Failed to load vendor reports: $e');
    }
  }

  static Future<VendorDetailsResponse> getVendorTransactions(
    String vendorId,
  ) async {
    try {
      // Some APIs return vendor codes like "VNDR-4" in the vendor list.
      // The transactions endpoint expects the numeric DB id, so extract digits.
      final numericId = RegExp(r"\d+").firstMatch(vendorId)?.group(0);
      if (numericId == null) {
        throw Exception('Invalid vendor id: $vendorId');
      }
      final response = await ApiService.get('/vendors/$numericId/transactions');
      return VendorDetailsResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load vendor transactions: $e');
    }
  }
}
