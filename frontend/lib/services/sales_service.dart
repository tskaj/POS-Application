import 'dart:convert';
import 'package:http/http.dart' as http;
import 'services.dart';

class Invoice {
  final int invId;
  final String invDate;
  final String customerName;
  final double invAmount;
  final double paidAmount;
  final double dueAmount;
  final String paymentMode; // Cash, Bank, Credit
  final bool isCreditCustomer; // true for credit customers, false for walk-in
  final String? salesmanName; // Name of the salesman who handled the sale
  final String?
  dueDate; // optional due date from API (bridals may provide this)
  final double? totalExtraExpenses; // For custom orders
  final double? netProfit; // For custom orders

  Invoice({
    required this.invId,
    required this.invDate,
    required this.customerName,
    required this.invAmount,
    required this.paidAmount,
    required this.dueAmount,
    required this.paymentMode,
    required this.isCreditCustomer,
    this.salesmanName,
    this.dueDate,
    this.totalExtraExpenses,
    this.netProfit,
  });

  factory Invoice.fromJson(Map<String, dynamic> json) {
    // Defensive parsing: many APIs return numbers as ints, doubles or strings
    // Support multiple possible field names coming from different endpoints (invoices vs bridals)
    final invAmount =
        double.tryParse(
          json['inv_amount']?.toString() ??
              json['grand_total']?.toString() ??
              '',
        ) ??
        0.0;
    final paidAmount =
        double.tryParse(
          json['paid_amount']?.toString() ?? json['paid']?.toString() ?? '',
        ) ??
        0.0;

    // due amount: prefer explicit fields or computed.balance_due, otherwise calculate
    double dueAmount = 0.0;
    if (json.containsKey('due_amount')) {
      dueAmount = double.tryParse(json['due_amount']?.toString() ?? '') ?? 0.0;
    } else if (json['computed'] is Map &&
        (json['computed'] as Map).containsKey('balance_due')) {
      dueAmount =
          double.tryParse(
            (json['computed'] as Map)['balance_due']?.toString() ?? '',
          ) ??
          0.0;
    } else {
      dueAmount = invAmount - paidAmount;
    }

    final invId =
        int.tryParse(
          json['inv_id']?.toString() ?? json['id']?.toString() ?? '',
        ) ??
        0;
    final invDate =
        json['inv_date']?.toString() ?? json['created_at']?.toString() ?? '';
    final customerName = (() {
      // Handle multiple possible shapes: nested customer object or top-level fields
      if (json['customer'] is Map) {
        final cust = json['customer'] as Map;
        return cust['name']?.toString() ??
            cust['customerName']?.toString() ??
            cust['customer_name']?.toString() ??
            '';
      }

      return json['customerName']?.toString() ??
          json['customer_name']?.toString() ??
          json['customer']?.toString() ??
          '';
    })();

    // Determine payment mode id from possible locations
    final paymentModeId =
        int.tryParse(
          json['payment_mode_id']?.toString() ??
              (json['payment_mode'] is Map
                  ? (json['payment_mode']['id']?.toString() ?? '')
                  : ''),
        ) ??
        0;
    String paymentMode;
    switch (paymentModeId) {
      case 1:
        paymentMode = 'Cash';
        break;
      case 2:
        paymentMode = 'Bank';
        break;
      case 3:
        paymentMode = 'Credit';
        break;
      default:
        // fallback to title or description if available
        if (json['payment_mode'] is Map) {
          paymentMode =
              (json['payment_mode']['title']?.toString() ??
              json['payment_mode']['description']?.toString() ??
              'Unknown');
        } else {
          paymentMode = json['payment_mode']?.toString() ?? 'Cash';
        }
    }
    final isCredit =
        paymentModeId == 2 || paymentMode.toLowerCase().contains('credit');

    return Invoice(
      invId: invId,
      invDate: invDate,
      customerName: customerName,
      invAmount: invAmount,
      paidAmount: paidAmount,
      dueAmount: dueAmount,
      paymentMode: paymentMode,
      dueDate: json['due_date']?.toString() ?? json['dueDate']?.toString(),
      isCreditCustomer: isCredit,
      // Prefer different possible spellings returned by API: 'salemanName',
      // 'salesmanName', 'salesman_name' or nested employee.name
      salesmanName: (json['employee'] is Map)
          ? (json['employee']['name']?.toString() ??
                json['salemanName']?.toString() ??
                json['saleman_name']?.toString() ??
                json['salesman']?.toString() ??
                json['salesman_name']?.toString())
          : (json['salemanName']?.toString() ??
                json['saleman_name']?.toString() ??
                json['salesman']?.toString() ??
                json['salesman_name']?.toString()),
      totalExtraExpenses: json['total_extra_expenses'] != null
          ? double.tryParse(json['total_extra_expenses'].toString())
          : null,
      netProfit: json['net_profit'] != null
          ? double.tryParse(json['net_profit'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'inv_id': invId,
      'inv_date': invDate,
      'customer_name': customerName,
      'inv_amount': invAmount.toString(),
      'paid_amount': paidAmount.toString(),
      'payment_mode': paymentMode,
      if (dueDate != null && dueDate!.isNotEmpty) 'due_date': dueDate,
      'is_credit_customer': isCreditCustomer,
      if (salesmanName != null) 'salesman_name': salesmanName,
    };
  }
}

class InvoiceDetail {
  final int id;
  final String productId;
  final String productName;
  final String quantity;
  final String price;
  final double subtotal;
  final double? discountPercent;
  final double? discountAmount;
  final String? discountPercentRaw;
  final String? discountAmountRaw;
  // Preserve any extras/add-ons that may be present for this detail row
  final List<Map<String, dynamic>> extras;

  InvoiceDetail({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.price,
    required this.subtotal,
    this.discountPercent,
    this.discountAmount,
    this.discountPercentRaw,
    this.discountAmountRaw,
    this.extras = const [],
  });

  factory InvoiceDetail.fromJson(Map<String, dynamic> json) {
    return InvoiceDetail(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      productId: json['product_id']?.toString() ?? '',
      productName: json['product_name']?.toString() ?? '',
      quantity: json['quantity']?.toString() ?? '',
      price: json['price']?.toString() ?? '',
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      discountPercent: double.tryParse(
        json['discount_percent']?.toString() ??
            json['discountPercent']?.toString() ??
            '',
      ),
      discountAmount: double.tryParse(
        json['discount_amount']?.toString() ??
            json['discountAmount']?.toString() ??
            '',
      ),
      discountPercentRaw:
          json['discount_percent']?.toString() ??
          json['discountPercent']?.toString(),
      discountAmountRaw:
          json['discount_amount']?.toString() ??
          json['discountAmount']?.toString(),
      extras: (json['extras'] is List)
          ? List<Map<String, dynamic>>.from(
              (json['extras'] as List).map(
                (e) => Map<String, dynamic>.from(e as Map),
              ),
            )
          : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'quantity': quantity,
      'price': price,
      'subtotal': subtotal,
      if (discountPercent != null) 'discount_percent': discountPercent,
      if (discountAmount != null) 'discount_amount': discountAmount,
      if (discountPercentRaw != null)
        'discount_percent_raw': discountPercentRaw,
      if (discountAmountRaw != null) 'discount_amount_raw': discountAmountRaw,
      if (extras.isNotEmpty) 'extras': extras,
    };
  }
}

class InvoiceDetailResponse {
  final int invId;
  final String invDate;
  final String customerName;
  final int customerId;
  final int posId;
  final String invAmount;
  final String paidAmount;
  final String? description;
  final String? totalExtraAmount;
  final String? employeeName;
  final String? dueDate;
  final List<InvoiceDetail> details;
  // keep raw data map so callers can access fields not parsed into typed
  // properties (for example: payment_mode, tax, discAmount, extras etc.)
  final Map<String, dynamic> rawData;

  InvoiceDetailResponse({
    required this.invId,
    required this.invDate,
    required this.customerName,
    required this.customerId,
    required this.posId,
    required this.invAmount,
    required this.paidAmount,
    this.description,
    this.totalExtraAmount,
    this.employeeName,
    this.dueDate,
    required this.details,
    required this.rawData,
  });

  factory InvoiceDetailResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    // Invoice detail responses from different endpoints may use different
    // field names for the invoice identifier (e.g. `inv_id`, `id`, `invId`).
    // Try several common fallbacks to ensure the correct invoice number is
    // displayed in the UI.
    final invIdValue =
        data['inv_id'] ??
        data['invoice_no'] ??
        data['id'] ??
        data['invId'] ??
        '';
    // Favor common alternative field names used by bridals endpoint
    final customerName =
        data['customer_name']?.toString() ??
        data['customerName']?.toString() ??
        '';

    final paidAmount =
        data['paid_amount']?.toString() ?? data['paid']?.toString() ?? '';

    final posIdVal =
        int.tryParse(data['pos_id']?.toString() ?? '') ??
        int.tryParse(data['id']?.toString() ?? '') ??
        0;

    return InvoiceDetailResponse(
      invId: int.tryParse(invIdValue?.toString() ?? '') ?? 0,
      invDate: data['inv_date']?.toString() ?? '',
      customerName: customerName,
      customerId: int.tryParse(data['customer_id']?.toString() ?? '') ?? 0,
      posId: posIdVal,
      invAmount:
          data['inv_amount']?.toString() ?? data['invAmount']?.toString() ?? '',
      paidAmount: paidAmount,
      description: data['description']?.toString() ?? data['desc']?.toString(),
      totalExtraAmount: data['total_extra_amount']?.toString(),
      employeeName:
          data['employeeName']?.toString() ??
          data['salemanName']?.toString() ??
          (data['employee'] is Map
              ? (data['employee']['name']?.toString() ?? '')
              : null),
      dueDate: data['due_date']?.toString(),
      details:
          (data['details'] as List<dynamic>?)
              ?.map((detail) => InvoiceDetail.fromJson(detail))
              .toList() ??
          [],
      rawData: Map<String, dynamic>.from(data as Map<String, dynamic>),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Inv_id': invId,
      'InvDate': invDate,
      'customer_name': customerName,
      'customer_id': customerId,
      'pos_id': posId,
      'inv_amount': invAmount,
      'paid_amount': paidAmount,
      if (totalExtraAmount != null) 'total_extra_amount': totalExtraAmount,
      if (employeeName != null) 'employeeName': employeeName,
      if (description != null) 'description': description,
      'details': details.map((detail) => detail.toJson()).toList(),
    };
  }
}

class Links {
  final String? first;
  final String? last;
  final String? prev;
  final String? next;

  Links({this.first, this.last, this.prev, this.next});

  factory Links.fromJson(Map<String, dynamic> json) {
    return Links(
      first: json['first'],
      last: json['last'],
      prev: json['prev'],
      next: json['next'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'first': first, 'last': last, 'prev': prev, 'next': next};
  }
}

class Link {
  final String? url;
  final String label;
  final int? page;
  final bool active;

  Link({this.url, required this.label, this.page, required this.active});

  factory Link.fromJson(Map<String, dynamic> json) {
    return Link(
      url: json['url'],
      label: json['label'] ?? '',
      page: json['page'],
      active: json['active'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {'url': url, 'label': label, 'page': page, 'active': active};
  }
}

class Meta {
  final int currentPage;
  final int? from;
  final int lastPage;
  final List<Link> links;
  final String path;
  final int perPage;
  final int? to;
  final int total;

  Meta({
    required this.currentPage,
    this.from,
    required this.lastPage,
    required this.links,
    required this.path,
    required this.perPage,
    this.to,
    required this.total,
  });

  factory Meta.fromJson(Map<String, dynamic> json) {
    return Meta(
      currentPage: json['current_page'] ?? 1,
      from: json['from'],
      lastPage: json['last_page'] ?? 1,
      links:
          (json['links'] as List<dynamic>?)
              ?.map((item) => Link.fromJson(item))
              .toList() ??
          [],
      path: json['path'] ?? '',
      perPage: json['per_page'] ?? 10,
      to: json['to'],
      total: json['total'] ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_page': currentPage,
      'from': from,
      'last_page': lastPage,
      'links': links.map((link) => link.toJson()).toList(),
      'path': path,
      'per_page': perPage,
      'to': to,
      'total': total,
    };
  }
}

class InvoiceResponse {
  final List<Invoice> data;
  final Links links;
  final Meta meta;

  InvoiceResponse({
    required this.data,
    required this.links,
    required this.meta,
  });

  factory InvoiceResponse.fromJson(Map<String, dynamic> json) {
    // Some endpoints wrap the pagination structure inside an additional 'data' object
    // e.g. { status: true, data: { data: [...], links: {...}, meta: {...} } }
    final topData = json['data'];

    List<dynamic> dataList = [];
    Map<String, dynamic> linksMap = {};
    Map<String, dynamic> metaMap = {};

    if (topData is List) {
      dataList = topData;
      linksMap = json['links'] is Map
          ? Map<String, dynamic>.from(json['links'])
          : {};
      metaMap = json['meta'] is Map
          ? Map<String, dynamic>.from(json['meta'])
          : {};
    } else if (topData is Map) {
      dataList = (topData['data'] as List<dynamic>?) ?? [];
      linksMap = (topData['links'] is Map)
          ? Map<String, dynamic>.from(topData['links'])
          : {};
      metaMap = (topData['meta'] is Map)
          ? Map<String, dynamic>.from(topData['meta'])
          : {};
    }

    return InvoiceResponse(
      data: dataList
          .map(
            (invoice) =>
                Invoice.fromJson(Map<String, dynamic>.from(invoice as Map)),
          )
          .toList(),
      links: Links.fromJson(linksMap),
      meta: Meta.fromJson(metaMap),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data.map((invoice) => invoice.toJson()).toList(),
      'links': links.toJson(),
      'meta': meta.toJson(),
    };
  }
}

class SalesReturnCustomer {
  final int id;
  final String name;

  SalesReturnCustomer({required this.id, required this.name});

  factory SalesReturnCustomer.fromJson(Map<String, dynamic> json) {
    return SalesReturnCustomer(id: json['id'] ?? 0, name: json['name'] ?? '');
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}

class SalesReturnDetail {
  final int id;
  final String productId;
  final String productName;
  final String qty;
  final String returnUnitPrice;
  final double total;

  SalesReturnDetail({
    required this.id,
    required this.productId,
    required this.productName,
    required this.qty,
    required this.returnUnitPrice,
    required this.total,
  });

  factory SalesReturnDetail.fromJson(Map<String, dynamic> json) {
    return SalesReturnDetail(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      productId:
          (json['product_id'] ??
                  json['productId'] ??
                  json['productId'] ??
                  json['productid'] ??
                  json['productID'])
              ?.toString() ??
          '',
      productName: json['product_name']?.toString() ?? '',
      qty: json['qty']?.toString() ?? '',
      returnUnitPrice: json['return_unit_price']?.toString() ?? '',
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'product_name': productName,
      'qty': qty,
      'return_unit_price': returnUnitPrice,
      'total': total,
    };
  }
}

class SalesReturn {
  final int id;
  final String invRetDate;
  final String returnInvAmount;
  final String? posId;
  final String? invId;
  final SalesReturnCustomer customer;
  final List<SalesReturnDetail> details;
  final String createdAt;
  final String? reason;
  final String? tax;
  final String? discPer;
  final String? discAmount;
  final String? paid;
  final String? transactionTypeId;
  final String? paymentModeId;

  SalesReturn({
    required this.id,
    required this.invRetDate,
    required this.returnInvAmount,
    this.posId,
    this.invId,
    required this.customer,
    required this.details,
    required this.createdAt,
    this.reason,
    this.tax,
    this.discPer,
    this.discAmount,
    this.paid,
    this.transactionTypeId,
    this.paymentModeId,
  });

  factory SalesReturn.fromJson(Map<String, dynamic> json) {
    return SalesReturn(
      id: int.tryParse((json['return_id'] ?? json['id'] ?? 0).toString()) ?? 0,
      invRetDate: json['invRet_date']?.toString() ?? '',
      returnInvAmount:
          (json['return_inv_amount'] ?? json['return_inv_amout'])?.toString() ??
          '',
      posId: json['pos_id']?.toString(),
      invId: json['inv_id']?.toString(),
      customer: SalesReturnCustomer.fromJson(
        // Support both nested `customer` object and top-level name fields
        (json['customer'] is Map)
            ? Map<String, dynamic>.from(json['customer'] as Map)
            : {
                'id':
                    int.tryParse(
                      json['customer_id']?.toString() ??
                          json['customerId']?.toString() ??
                          '0',
                    ) ??
                    0,
                'name':
                    json['customerName']?.toString() ??
                    json['customer_name']?.toString() ??
                    'Walk In Customer',
              },
      ),
      details:
          (json['details'] as List<dynamic>?)
              ?.map((detail) => SalesReturnDetail.fromJson(detail))
              .toList() ??
          [],
      createdAt: json['created_at']?.toString() ?? '',
      reason: json['reason'],
      tax: json['tax']?.toString(),
      discPer: json['discPer']?.toString(),
      discAmount: json['discAmount']?.toString(),
      paid: json['paid']?.toString(),
      transactionTypeId: json['transaction_type_id']?.toString(),
      paymentModeId: json['payment_mode_id']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'return_id': id,
      'invRet_date': invRetDate,
      'return_inv_amount': returnInvAmount,
      'pos_id': posId,
      'inv_id': invId,
      'customerName': customer.name,
      'details': details.map((detail) => detail.toJson()).toList(),
      'created_at': createdAt,
      'reason': reason,
      'tax': tax,
      'discPer': discPer,
      'discAmount': discAmount,
      'paid': paid,
      'transaction_type_id': transactionTypeId,
      'payment_mode_id': paymentModeId,
    };
  }
}

class SalesReturnResponse {
  final bool status;
  final List<SalesReturn> data;

  SalesReturnResponse({required this.status, required this.data});

  factory SalesReturnResponse.fromJson(Map<String, dynamic> json) {
    return SalesReturnResponse(
      status: json['status'] ?? false,
      data:
          (json['data'] as List<dynamic>?)
              ?.map((salesReturn) => SalesReturn.fromJson(salesReturn))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'data': data.map((salesReturn) => salesReturn.toJson()).toList(),
    };
  }
}

class SalesService {
  // Get base URL from ApiService
  static String get baseUrl => ApiService.baseUrl;

  static const String invoicesEndpoint = '/pos';
  static const String salesReturnsEndpoint = '/posReturn';
  static const String posEndpoint = '/pos';

  // Create POS invoice
  static Future<Map<String, dynamic>> createPosInvoice({
    required String invDate,
    required int customerId,
    required double tax,
    required double discPer,
    required double discAmount,
    required double invAmount,
    required double paid,
    required int paymentModeId, // 1=cash, 2=bank, 3=credit customer
    required int transactionTypeId, // 1=cash, 2=credit, 3=bank
    int? salesmanId,
    required List<Map<String, dynamic>> details,
    int?
    coaId, // COA account ID (3 for cash, bank ID for bank, customer ID for credit)
    int? bankAccId, // Bank account ID (for bank payments)
    int? coaRefId, // Reference COA ID (7 for Sale Account)
    String? description,
    String? dueDate,
  }) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final requestBody = {
      'inv_date': invDate,
      'customer_id': customerId,
      // Include both camelCase and snake_case keys to be defensive
      // since different backend endpoints expect different naming.
      'tax': tax,
      'tax_amount': tax,
      'discPer': discPer,
      'discAmount': discAmount,
      'disc_per': discPer,
      'disc_amount': discAmount,
      'inv_amount': invAmount,
      'paid': paid,
      'payment_mode_id': paymentModeId,
      'transaction_type_id': transactionTypeId,
      'employee_id':
          salesmanId ??
          1, // Always include employee_id, default to 1 if no salesman
      if (coaId != null) 'coa_id': coaId,
      if (bankAccId != null) 'bank_acc_id': bankAccId,
      if (coaRefId != null) 'coaRef_id': coaRefId,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (dueDate != null && dueDate.isNotEmpty) 'due_date': dueDate,
      'details': details,
    };

    print('📤 POS API REQUEST:');
    print('URL: ${ApiService.baseUrl}$posEndpoint');
    print('Method: POST');
    print('Headers: Authorization: Bearer [TOKEN]');
    print('Body: ${jsonEncode(requestBody)}');

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}$posEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      print('📥 POS API RESPONSE:');
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        print('✅ POS API SUCCESS: Invoice created successfully');
        return decoded;
      } else if (response.statusCode == 401) {
        await ApiService.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'POS invoice creation failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ POS API NETWORK ERROR: $e');
      throw Exception('Network error: $e');
    }
  }

  // Create a bridals (custom order) invoice at /pos/pos-bridals
  static Future<Map<String, dynamic>> createBridal({
    required String invDate,
    required int customerId,
    required double tax,
    required double discPer,
    required double discAmount,
    required double invAmount,
    required double paid,
    required int paymentModeId,
    required int transactionTypeId,
    int? salesmanId,
    required List<Map<String, dynamic>> details,
    int? coaId,
    int? bankAccId,
    int? coaRefId,
    String? description,
    String? dueDate,
    Map<String, dynamic>? bankDetail,
    double? totalExtraAmount,
  }) async {
    final token = await ApiService.getToken();
    if (token == null) throw Exception('No authentication token found');

    final requestBody = {
      'inv_date': invDate,
      'customer_id': customerId,
      // Include both camelCase and snake_case keys to be defensive
      'tax': tax,
      'tax_amount': tax,
      'discPer': discPer,
      'discAmount': discAmount,
      'disc_per': discPer,
      'disc_amount': discAmount,
      'inv_amount': invAmount,
      'paid': paid,
      'payment_mode_id': paymentModeId,
      'transaction_type_id': transactionTypeId,
      'employee_id': salesmanId ?? 1,
      if (coaId != null) 'coa_id': coaId,
      if (bankAccId != null) 'bank_acc_id': bankAccId,
      if (coaRefId != null) 'coaRef_id': coaRefId,
      if (description != null && description.isNotEmpty)
        'description': description,
      if (dueDate != null && dueDate.isNotEmpty) 'due_date': dueDate,
      if (bankDetail != null) 'bank_detail': bankDetail,
      if (totalExtraAmount != null) 'total_extra_amount': totalExtraAmount,
      'details': details,
    };

    print('📤 BRIDAL POS API REQUEST:');
    print('URL: ${ApiService.baseUrl}$invoicesEndpoint/pos-bridals');
    print('Method: POST');
    print('Body: ${jsonEncode(requestBody)}');

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}$invoicesEndpoint/pos-bridals'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      print('📥 BRIDAL POS API RESPONSE: ${response.statusCode}');
      print('Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        print('✅ BRIDAL POS API SUCCESS: Invoice created');
        return decoded;
      } else if (response.statusCode == 401) {
        await ApiService.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Bridal POS invoice creation failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ BRIDAL POS API NETWORK ERROR: $e');
      throw Exception('Network error: $e');
    }
  }

  // Get all sales returns
  static Future<SalesReturnResponse> getSalesReturns() async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}$salesReturnsEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true && decoded.containsKey('data')) {
          final salesReturns = SalesReturnResponse.fromJson(decoded);
          return salesReturns;
        } else {
          throw Exception(decoded['message'] ?? 'Failed to load sales returns');
        }
      } else if (response.statusCode == 401) {
        await ApiService.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Failed to load sales returns: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get sales return by ID
  static Future<SalesReturn> getSalesReturnById(String returnId) async {
    try {
      final response = await ApiService.get('$salesReturnsEndpoint/$returnId');

      if (response.containsKey('data')) {
        final salesReturn = SalesReturn.fromJson(response['data']);
        return salesReturn;
      } else {
        throw Exception('Sales return data not found in response');
      }
    } catch (e) {
      throw Exception('Failed to load sales return: $e');
    }
  }

  // Update sales return
  static Future<SalesReturn> updateSalesReturn(
    String returnId,
    Map<String, dynamic> returnData,
  ) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}$salesReturnsEndpoint/$returnId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(returnData),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded.containsKey('data')) {
          final salesReturn = SalesReturn.fromJson(decoded['data']);
          return salesReturn;
        } else {
          throw Exception('Sales return data not found in response');
        }
      } else if (response.statusCode == 401) {
        await ApiService.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Update failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Delete sales return
  static Future<Map<String, dynamic>> deleteSalesReturn(
    String returnId,
    Map<String, dynamic> deleteData,
  ) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.delete(
        Uri.parse('${ApiService.baseUrl}$salesReturnsEndpoint/$returnId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(deleteData),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded;
      } else if (response.statusCode == 401) {
        await ApiService.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Delete failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get all invoices
  static Future<InvoiceResponse> getInvoices({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final url = Uri.parse(
        '$baseUrl$invoicesEndpoint?page=$page&per_page=$limit',
      );
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded.containsKey('data')) {
          final invoiceResponse = InvoiceResponse.fromJson(decoded);
          return invoiceResponse;
        } else {
          return InvoiceResponse(
            data: [],
            links: Links(),
            meta: Meta(
              currentPage: 1,
              lastPage: 1,
              links: [],
              path: '',
              perPage: 10,
              total: 0,
            ),
          );
        }
      } else if (response.statusCode == 401) {
        await ApiService.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Request failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Failed to load invoices: $e');
    }
  }

  // Get custom orders (bridals) from /pos/pos-bridals
  static Future<InvoiceResponse> getBridals({
    int page = 1,
    int limit = 10,
  }) async {
    try {
      final token = await ApiService.getToken();
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final url = Uri.parse(
        '$baseUrl${invoicesEndpoint}/pos-bridals?page=$page&per_page=$limit',
      );
      final headers = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };

      final response = await http.get(url, headers: headers);

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded.containsKey('data')) {
          final invoiceResponse = InvoiceResponse.fromJson(decoded);
          return invoiceResponse;
        } else {
          return InvoiceResponse(
            data: [],
            links: Links(),
            meta: Meta(
              currentPage: 1,
              lastPage: 1,
              links: [],
              path: '',
              perPage: 10,
              total: 0,
            ),
          );
        }
      } else if (response.statusCode == 401) {
        await ApiService.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Request failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Failed to load custom orders: $e');
    }
  }

  // Get invoice by ID
  static Future<InvoiceDetailResponse> getInvoiceById(int invoiceId) async {
    try {
      final response = await ApiService.get('$invoicesEndpoint/$invoiceId');

      if (response.containsKey('data')) {
        final invoiceDetailResponse = InvoiceDetailResponse.fromJson(response);
        return invoiceDetailResponse;
      } else {
        throw Exception('Invoice data not found in response');
      }
    } catch (e) {
      throw Exception('Failed to load invoice: $e');
    }
  }

  // Get a bridals (custom order) detail by ID
  static Future<InvoiceDetailResponse> getBridalById(int bridalId) async {
    try {
      final response = await ApiService.get(
        '$invoicesEndpoint/pos-bridals/$bridalId',
      );

      if (response.containsKey('data')) {
        final invoiceDetailResponse = InvoiceDetailResponse.fromJson(response);
        return invoiceDetailResponse;
      } else {
        throw Exception('Bridal data not found in response');
      }
    } catch (e) {
      throw Exception('Failed to load bridal detail: $e');
    }
  }

  // Update invoice
  static Future<Map<String, dynamic>> updateInvoice(
    int invoiceId,
    Map<String, dynamic> invoiceData,
  ) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}$invoicesEndpoint/$invoiceId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(invoiceData),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        return decoded;
      } else if (response.statusCode == 401) {
        await ApiService.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Update failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Delete invoice
  static Future<Map<String, dynamic>> deleteInvoice(int invoiceId) async {
    try {
      // Prefer central ApiService.delete which handles token and logs
      print('📡 SalesService: deleting invoice $invoiceId via ApiService');
      final decoded = await ApiService.delete('$invoicesEndpoint/$invoiceId');
      return decoded;
    } catch (e) {
      // Log and try a direct http.delete as a fallback to surface raw response
      print('⚠️ SalesService.deleteInvoice: ApiService.delete failed: $e');
      try {
        final token = await ApiService.getToken();
        if (token == null) throw Exception('No authentication token found');

        final response = await http.delete(
          Uri.parse('${ApiService.baseUrl}$invoicesEndpoint/$invoiceId'),
          headers: {
            'Content-Type': 'application/json',
            'Accept': 'application/json',
            'Authorization': 'Bearer $token',
          },
        );

        print('📡 Direct DELETE status: ${response.statusCode}');
        print('📨 Direct DELETE body: ${response.body}');

        if (response.statusCode == 200 || response.statusCode == 204) {
          final decoded = response.body.isNotEmpty
              ? jsonDecode(response.body)
              : {'message': 'Invoice deleted successfully'};
          return decoded;
        } else if (response.statusCode == 401) {
          await ApiService.logout();
          throw Exception('Session expired. Please login again.');
        } else {
          throw Exception(
            'Delete failed: ${response.statusCode} - ${response.body}',
          );
        }
      } catch (e2) {
        print('💥 SalesService.deleteInvoice fallback failed: $e2');
        throw Exception('Failed to delete invoice: $e; fallback error: $e2');
      }
    }
  }

  // Delete a bridals (custom order) by ID
  static Future<Map<String, dynamic>> deleteBridal(int bridalId) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.delete(
        Uri.parse(
          '${ApiService.baseUrl}${invoicesEndpoint}/pos-bridals/$bridalId',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        final decoded = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {'message': 'Bridal deleted successfully'};
        return decoded;
      } else if (response.statusCode == 401) {
        await ApiService.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Delete failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Update a bridals (custom order) by ID (PUT /pos/pos-bridals/{id})
  static Future<Map<String, dynamic>> updateBridal(
    int bridalId,
    Map<String, dynamic> bridalData,
  ) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.put(
        Uri.parse(
          '${ApiService.baseUrl}${invoicesEndpoint}/pos-bridals/$bridalId',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(bridalData),
      );

      print('📡 BRIDAL UPDATE RESPONSE: ${response.statusCode}');
      print('📨 Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return decoded;
      } else if (response.statusCode == 401) {
        await ApiService.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Bridal update failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('❌ BRIDAL UPDATE NETWORK ERROR: $e');
      throw Exception('Network error: $e');
    }
  }

  // Create sales return
  static Future<SalesReturn> createSalesReturn(
    Map<String, dynamic> returnData,
  ) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    // Add required payment_mode_id and transaction_type_id only if not already provided
    final requestBody = {
      ...returnData,
      if (!returnData.containsKey('payment_mode_id')) 'payment_mode_id': 1,
      if (!returnData.containsKey('transaction_type_id'))
        'transaction_type_id': 3, // Use 3 for sales returns
    };

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}$salesReturnsEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(requestBody),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true && decoded.containsKey('data')) {
          final salesReturn = SalesReturn.fromJson(decoded['data']);
          return salesReturn;
        } else {
          throw Exception(
            decoded['message'] ?? 'Failed to create sales return',
          );
        }
      } else if (response.statusCode == 401) {
        await ApiService.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Create failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get invoice details by invoice number
  static Future<InvoiceDetailResponse> getInvoiceByNumber(
    String invoiceNumber, {
    String? cnic,
  }) async {
    try {
      // Be tolerant with invoice number formats. Many UIs show labels like
      // 'INV-000123' or 'INV123' while backend expects numeric ID. Extract
      // the first numeric sequence found in the string and use it as ID.
      int? invoiceId;

      // Try fast parse first
      invoiceId = int.tryParse(invoiceNumber);

      if (invoiceId == null) {
        // Extract first run of digits from the input (e.g. 'INV-000123' -> '000123')
        final digitMatch = RegExp(r"(\d+)").firstMatch(invoiceNumber);
        if (digitMatch != null) {
          invoiceId = int.tryParse(digitMatch.group(0) ?? '');
        }
      }

      if (invoiceId == null) {
        throw Exception('Invalid invoice number format: $invoiceNumber');
      }

      // Try fetching from the regular invoices endpoint first (/pos/{id}).
      // If that fails (for example the invoice is a 'bridal' custom order),
      // fall back to the bridals endpoint (/pos/pos-bridals/{id}).
      try {
        print(
          '📡 getInvoiceByNumber: fetching invoice id $invoiceId from $invoicesEndpoint/$invoiceId',
        );
        final response = await getInvoiceById(invoiceId);
        return response;
      } catch (e) {
        print(
          '⚠️ getInvoiceByNumber: regular invoice fetch failed for id $invoiceId: $e',
        );
        try {
          print(
            '📡 getInvoiceByNumber: trying bridals endpoint for id $invoiceId',
          );
          final bridalResponse = await getBridalById(invoiceId);
          return bridalResponse;
        } catch (e2) {
          print(
            '❌ getInvoiceByNumber: bridals fetch also failed for id $invoiceId: $e2',
          );

          // As a last resort, try to locate the invoice in the invoice lists
          // (All / Regular) and bridals list (Custom orders). This covers the
          // cases where the invoice exists but detail endpoints are restricted
          // by transaction type. We fetch a reasonably large page and search
          // for matching IDs.
          try {
            print(
              '🔎 getInvoiceByNumber: searching invoices list for id $invoiceId',
            );
            final invoicesList = await getInvoices(page: 1, limit: 1000);
            final match = invoicesList.data.firstWhere(
              (inv) => inv.invId == invoiceId,
              orElse: () => Invoice(
                invId: 0,
                invDate: '',
                customerName: '',
                invAmount: 0.0,
                paidAmount: 0.0,
                dueAmount: 0.0,
                paymentMode: '',
                isCreditCustomer: false,
              ),
            );
            if (match.invId > 0) {
              print(
                '🔎 Found invoice in invoices list with id ${match.invId}, fetching detail',
              );
              return await getInvoiceById(match.invId);
            }
          } catch (listErr) {
            print(
              '⚠️ getInvoiceByNumber: invoices list search failed: $listErr',
            );
          }

          try {
            print(
              '🔎 getInvoiceByNumber: searching bridals list for id $invoiceId',
            );
            final bridalsList = await getBridals(page: 1, limit: 1000);
            final matchBridal = bridalsList.data.firstWhere(
              (inv) => inv.invId == invoiceId,
              orElse: () => Invoice(
                invId: 0,
                invDate: '',
                customerName: '',
                invAmount: 0.0,
                paidAmount: 0.0,
                dueAmount: 0.0,
                paymentMode: '',
                isCreditCustomer: false,
              ),
            );
            if (matchBridal.invId > 0) {
              print(
                '🔎 Found invoice in bridals list with id ${matchBridal.invId}, fetching bridal detail',
              );
              return await getBridalById(matchBridal.invId);
            }
          } catch (bridalListErr) {
            print(
              '⚠️ getInvoiceByNumber: bridals list search failed: $bridalListErr',
            );
          }

          throw Exception('Invoice not found by id $invoiceId: $e / $e2');
        }
      }
    } catch (e) {
      throw Exception('Failed to load invoice: $e');
    }
  }

  // Get custom extra expenses for an invoice
  static Future<Map<String, dynamic>> getCustomExtraExpenses(int invId) async {
    try {
      final response = await ApiService.get('/pos/customExtraExp/$invId');
      return response;
    } catch (e) {
      throw Exception('Failed to load custom extra expenses: $e');
    }
  }

  // Save custom extra expenses for an invoice
  static Future<Map<String, dynamic>> saveCustomExtraExpenses(
    Map<String, dynamic> expenseData,
  ) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiService.baseUrl}/pos/customExtraExp'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(expenseData),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return decoded;
      } else if (response.statusCode == 401) {
        await ApiService.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Save failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Save extras (add-on items) for a specific custom order (bridal)
  // PUT /pos/customExtraExp/{id}
  static Future<Map<String, dynamic>> saveCustomExtras(
    int invId,
    Map<String, dynamic> payload,
  ) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/pos/customExtraExp/$invId');
      final response = await http.put(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        return decoded;
      } else if (response.statusCode == 401) {
        await ApiService.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Save extras failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Delete a custom extra expense by expense id
  static Future<Map<String, dynamic>> deleteCustomExtraExpense(
    int expenseId,
  ) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final uri = Uri.parse(
        '${ApiService.baseUrl}/pos/customExtraExp/$expenseId',
      );
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        final decoded = jsonDecode(response.body);
        return decoded;
      } else if (response.statusCode == 401) {
        await ApiService.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Delete expense failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }

  // Get POS extras for an invoice
  static Future<Map<String, dynamic>> getPosExtras(int invId) async {
    try {
      final response = await ApiService.get('/pos/pos-extras/$invId');
      return response;
    } catch (e) {
      throw Exception('Failed to load POS extras: $e');
    }
  }

  // Delete a POS extra by extra id
  static Future<Map<String, dynamic>> deletePosExtra(int extraId) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final uri = Uri.parse('${ApiService.baseUrl}/pos/pos-extras/$extraId');
      final response = await http.delete(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        final decoded = jsonDecode(response.body);
        return decoded;
      } else if (response.statusCode == 401) {
        await ApiService.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Delete extra failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Network error: $e');
    }
  }
}
