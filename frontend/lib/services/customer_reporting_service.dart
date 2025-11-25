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

// Customer Invoice Model
class CustomerInvoice {
  final int id;
  final String customerId;
  final String invDate;
  final String invAmount;
  final String paid;
  final String tax;
  final String discPer;
  final String discAmount;

  CustomerInvoice({
    required this.id,
    required this.customerId,
    required this.invDate,
    required this.invAmount,
    required this.paid,
    required this.tax,
    required this.discPer,
    required this.discAmount,
  });

  factory CustomerInvoice.fromJson(Map<String, dynamic> json) {
    return CustomerInvoice(
      id: _parseInt(json['id']),
      customerId: json['customer_id']?.toString() ?? '',
      invDate: json['inv_date']?.toString() ?? '',
      invAmount: json['inv_amount']?.toString() ?? '0.00',
      paid: json['paid']?.toString() ?? '0.00',
      tax: json['tax']?.toString() ?? '0.00',
      discPer: json['discPer']?.toString() ?? '0.00',
      discAmount: json['discAmount']?.toString() ?? '0.00',
    );
  }
}

// Customer Model
class Customer {
  final int id;
  final String cnic;
  final String name;
  final String email;
  final String address;
  final String cityId;
  final String cellNo1;
  final String? cellNo2;
  final CustomerTotals totals;
  final String imagePath;
  final String status;
  final String? cnic2;
  final String? name2;
  final String? cellNo3;
  final String createdAt;
  final String updatedAt;
  final List<CustomerInvoice> invoices;

  Customer({
    required this.id,
    required this.cnic,
    required this.name,
    required this.email,
    required this.address,
    required this.cityId,
    required this.cellNo1,
    this.cellNo2,
    required this.totals,
    required this.imagePath,
    required this.status,
    this.cnic2,
    this.name2,
    this.cellNo3,
    required this.createdAt,
    required this.updatedAt,
    required this.invoices,
  });

  factory Customer.fromJson(Map<String, dynamic> json) {
    return Customer(
      id: _parseInt(json['id']),
      cnic: json['cnic']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      // API sometimes returns 'city' as a string, or as an object with a 'name' field,
      // or returns 'city_id'. Prefer a readable city name when available.
      cityId: (() {
        final cityField = json['city'];
        if (cityField == null) return json['city_id']?.toString() ?? '';
        if (cityField is String) return cityField;
        if (cityField is Map && cityField.containsKey('name')) {
          return cityField['name']?.toString() ??
              json['city_id']?.toString() ??
              '';
        }
        return json['city_id']?.toString() ?? '';
      })(),
      cellNo1: json['cell_no1']?.toString() ?? '',
      cellNo2: json['cell_no2']?.toString(),
      imagePath: json['image_path']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      totals: json['totals'] != null
          ? CustomerTotals.fromJson(json['totals'])
          : CustomerTotals.empty(),
      cnic2: json['cnic2']?.toString(),
      name2: json['name2']?.toString(),
      cellNo3: json['cell_no3']?.toString(),
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      invoices:
          (json['invoices'] as List<dynamic>?)
              ?.map((item) => CustomerInvoice.fromJson(item))
              .toList() ??
          [],
    );
  }
}

// Totals model present in API under "totals"
class CustomerTotals {
  final int totalInvoices;
  final double totalInvoiceAmount;
  final double totalPaid;
  final double balanceDue;

  CustomerTotals({
    required this.totalInvoices,
    required this.totalInvoiceAmount,
    required this.totalPaid,
    required this.balanceDue,
  });

  factory CustomerTotals.fromJson(Map<String, dynamic> json) {
    return CustomerTotals(
      totalInvoices: _parseInt(json['total_invoices']),
      totalInvoiceAmount: _parseDouble(json['total_invoice_amount']),
      totalPaid: _parseDouble(json['total_paid']),
      balanceDue: _parseDouble(json['balance_due']),
    );
  }

  factory CustomerTotals.empty() => CustomerTotals(
    totalInvoices: 0,
    totalInvoiceAmount: 0.0,
    totalPaid: 0.0,
    balanceDue: 0.0,
  );
}

// Customer Due Model
class CustomerDue {
  final int id;
  final String name;
  final String phoneNumber;
  final double totalInvoice;
  final double totalPaid;
  final double totalDue;

  CustomerDue({
    required this.id,
    required this.name,
    this.phoneNumber = '',
    required this.totalInvoice,
    required this.totalPaid,
    required this.totalDue,
  });

  factory CustomerDue.fromJson(Map<String, dynamic> json) {
    return CustomerDue(
      id: _parseInt(json['id']),
      name: json['name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString() ?? '',
      totalInvoice:
          double.tryParse(json['total_invoice']?.toString() ?? '0.0') ?? 0.0,
      totalPaid:
          double.tryParse(json['total_paid']?.toString() ?? '0.0') ?? 0.0,
      totalDue: double.tryParse(json['total_due']?.toString() ?? '0.0') ?? 0.0,
    );
  }
}

// Response models
class CustomerInvoicesResponse {
  final List<Customer> data;

  CustomerInvoicesResponse({required this.data});

  factory CustomerInvoicesResponse.fromJson(Map<String, dynamic> json) {
    return CustomerInvoicesResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => Customer.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class CustomerDuesResponse {
  final List<CustomerDue> data;

  CustomerDuesResponse({required this.data});

  factory CustomerDuesResponse.fromJson(Map<String, dynamic> json) {
    return CustomerDuesResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => CustomerDue.fromJson(item))
              .toList() ??
          [],
    );
  }
}

// Customer Invoice Detail Models (for single customer invoice view)
class InvoiceExtra {
  final int id;
  final String title;
  final String value;
  final String amount;

  InvoiceExtra({
    required this.id,
    required this.title,
    required this.value,
    required this.amount,
  });

  factory InvoiceExtra.fromJson(Map<String, dynamic> json) {
    return InvoiceExtra(
      id: _parseInt(json['id']),
      title: json['title']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '0.00',
    );
  }
}

class InvoiceDetail {
  final int id;
  final String product;
  final String qty;
  final String discPer;
  final String discAmount;
  final List<InvoiceExtra> extras;

  InvoiceDetail({
    required this.id,
    required this.product,
    required this.qty,
    required this.discPer,
    required this.discAmount,
    required this.extras,
  });

  factory InvoiceDetail.fromJson(Map<String, dynamic> json) {
    return InvoiceDetail(
      id: _parseInt(json['id']),
      product: json['product']?.toString() ?? '',
      qty: json['qty']?.toString() ?? '0',
      discPer: json['discPer']?.toString() ?? '0',
      discAmount: json['discAmount']?.toString() ?? '0',
      extras:
          (json['extras'] as List<dynamic>?)
              ?.map((item) => InvoiceExtra.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class BankDetail {
  final int id;
  final String bankName;
  final String? accountTitle;
  final String accountNumber;
  final String? amount;

  BankDetail({
    required this.id,
    required this.bankName,
    this.accountTitle,
    required this.accountNumber,
    this.amount,
  });

  factory BankDetail.fromJson(Map<String, dynamic> json) {
    return BankDetail(
      id: _parseInt(json['id']),
      bankName: json['bank_name']?.toString() ?? '',
      accountTitle: json['account_title']?.toString(),
      accountNumber: json['account_number']?.toString() ?? '',
      amount: json['amount']?.toString(),
    );
  }
}

class CustomerInvoiceDetailed {
  final int id;
  final String invDate;
  final String invAmount;
  final String paid;
  final String tax;
  final String discPer;
  final String discAmount;
  final String description;
  final List<BankDetail> bankDetails;
  final List<InvoiceDetail> details;

  CustomerInvoiceDetailed({
    required this.id,
    required this.invDate,
    required this.invAmount,
    required this.paid,
    required this.tax,
    required this.discPer,
    required this.discAmount,
    required this.description,
    required this.bankDetails,
    required this.details,
  });

  factory CustomerInvoiceDetailed.fromJson(Map<String, dynamic> json) {
    return CustomerInvoiceDetailed(
      id: _parseInt(json['id']),
      invDate: json['date']?.toString() ?? '',
      invAmount: json['inv_amount']?.toString() ?? '0.00',
      paid: json['paid']?.toString() ?? '0.00',
      tax: json['tax']?.toString() ?? '0.00',
      discPer: json['discPer']?.toString() ?? '0',
      discAmount: json['discAmount']?.toString() ?? '0.00',
      description: json['description']?.toString() ?? '',
      bankDetails:
          (json['bank_details'] as List<dynamic>?)
              ?.map((item) => BankDetail.fromJson(item))
              .toList() ??
          [],
      details:
          (json['details'] as List<dynamic>?)
              ?.map((item) => InvoiceDetail.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class CustomerInvoiceDetailsResponse {
  final int id;
  final String name;
  final int totalInvoices;
  final double totalAmount;
  final double totalPaid;
  final double totalDue;
  final double totalExtras;
  final double totalBankPaid;
  final List<CustomerInvoiceDetailed> invoices;

  CustomerInvoiceDetailsResponse({
    required this.id,
    required this.name,
    required this.totalInvoices,
    required this.totalAmount,
    required this.totalPaid,
    required this.totalDue,
    required this.totalExtras,
    required this.totalBankPaid,
    required this.invoices,
  });

  factory CustomerInvoiceDetailsResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? json;
    final totals = data['totals'] ?? {};
    return CustomerInvoiceDetailsResponse(
      id: _parseInt(data['id']),
      name: data['name']?.toString() ?? '',
      totalInvoices: _parseInt(totals['total_invoices']),
      totalAmount: _parseDouble(totals['total_invoice_amount']),
      totalPaid: _parseDouble(totals['total_paid']),
      totalDue: _parseDouble(totals['balance_due']),
      totalExtras: _parseDouble(totals['total_extras'] ?? 0),
      totalBankPaid: _parseDouble(totals['total_bank_paid'] ?? 0),
      invoices:
          (data['invoices'] as List<dynamic>?)
              ?.map((item) => CustomerInvoiceDetailed.fromJson(item))
              .toList() ??
          [],
    );
  }
}

// Service class
class CustomerReportingService {
  static const String invoicesEndpoint = '/reports/customers/invoices';
  static const String duesEndpoint = '/reports/customers/dues';

  static Future<CustomerInvoicesResponse> getInvoices() async {
    try {
      final response = await ApiService.get(invoicesEndpoint);

      if (response.containsKey('data')) {
        final customerInvoicesResponse = CustomerInvoicesResponse.fromJson(
          response,
        );
        return customerInvoicesResponse;
      } else {
        return CustomerInvoicesResponse(data: []);
      }
    } catch (e) {
      throw Exception('Failed to load customer invoices: $e');
    }
  }

  static Future<CustomerDuesResponse> getDues() async {
    try {
      final response = await ApiService.get(duesEndpoint);

      if (response.containsKey('data')) {
        final customerDuesResponse = CustomerDuesResponse.fromJson(response);
        return customerDuesResponse;
      } else {
        return CustomerDuesResponse(data: []);
      }
    } catch (e) {
      throw Exception('Failed to load customer dues: $e');
    }
  }

  static Future<CustomerInvoiceDetailsResponse> getCustomerInvoiceDetails(
    int customerId,
  ) async {
    try {
      final response = await ApiService.get('/customers/$customerId/invoices');

      return CustomerInvoiceDetailsResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load customer invoice details: $e');
    }
  }
}
