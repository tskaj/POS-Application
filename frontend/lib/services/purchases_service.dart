import 'dart:convert';
import 'package:http/http.dart' as http;
import 'services.dart';

// Data models for Purchase API
class PurchaseDetail {
  final String productId;
  final String productName;
  final String quantity;
  final String unitPrice;
  final String discPer;
  final String discAmount;
  final String amount;

  PurchaseDetail({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.discPer,
    required this.discAmount,
    required this.amount,
  });

  factory PurchaseDetail.fromJson(Map<String, dynamic> json) {
    return PurchaseDetail(
      productId: json['product_id']?.toString() ?? '',
      productName: json['productName']?.toString() ?? '',
      quantity: json['quantity']?.toString() ?? '',
      unitPrice: json['unit_price']?.toString() ?? '',
      discPer: json['discPer']?.toString() ?? '',
      discAmount: json['discAmount']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'product_id': productId,
      'productName': productName,
      'quantity': quantity,
      'unit_price': unitPrice,
      'discPer': discPer,
      'discAmount': discAmount,
      'amount': amount,
    };
  }
}

class Purchase {
  final String purInvId;
  final String purInvBarcode;
  final String purDate;
  final String vendorId;
  final String vendorName;
  final String vendorStatus;
  final String venInvNo;
  final String venInvDate;
  final String venInvRef;
  final String description;
  final String discountPercent;
  final String discountAmt;
  final String taxPercent;
  final String taxAmt;
  final String shippingAmt;
  final String invAmount;
  final String paymentStatus;
  final String createdAt;
  final List<PurchaseDetail> purDetails;

  Purchase({
    required this.purInvId,
    required this.purInvBarcode,
    required this.purDate,
    required this.vendorId,
    required this.vendorName,
    required this.vendorStatus,
    required this.venInvNo,
    required this.venInvDate,
    required this.venInvRef,
    required this.description,
    required this.discountPercent,
    required this.discountAmt,
    required this.taxPercent,
    required this.taxAmt,
    required this.shippingAmt,
    required this.invAmount,
    required this.paymentStatus,
    required this.createdAt,
    required this.purDetails,
  });

  factory Purchase.fromJson(Map<String, dynamic> json) {
    return Purchase(
      // API sometimes returns different key casings/structures. Try multiple fallbacks.
      purInvId:
          json['purInv_id']?.toString() ??
          json['Pur_Inv_id']?.toString() ??
          json['pur_inv_id']?.toString() ??
          '',
      purInvBarcode: json['pur_inv_barcode']?.toString() ?? '',
      purDate: json['pur_date']?.toString() ?? '',
      // vendor can be an object with first_name/last_name or simple fields
      vendorId: (json['vendor'] is Map)
          ? (json['vendor']['id']?.toString() ?? '')
          : (json['vendor_id']?.toString() ?? ''),
      vendorName: (json['vendor'] is Map)
          ? ((json['vendor']['first_name']?.toString() ?? '') +
                    ' ' +
                    (json['vendor']['last_name']?.toString() ?? ''))
                .trim()
          : (json['vendorName']?.toString() ??
                json['vendor_name']?.toString() ??
                ''),
      vendorStatus: (json['vendor'] is Map)
          ? (json['vendor']['status']?.toString() ?? '')
          : (json['vendor_status']?.toString() ?? ''),
      venInvNo: json['ven_inv_no']?.toString() ?? '',
      venInvDate: json['ven_inv_date']?.toString() ?? '',
      venInvRef: json['ven_inv_ref']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      discountPercent: json['discount_percent']?.toString() ?? '',
      discountAmt: json['discount_amt']?.toString() ?? '',
      taxPercent: json['tax_percent']?.toString() ?? '',
      taxAmt: json['tax_amt']?.toString() ?? '',
      shippingAmt: json['shipping_amt']?.toString() ?? '',
      invAmount: json['inv_amount']?.toString() ?? '',
      // payment status may be provided via payment_mode.title or payment_status
      paymentStatus: (json['payment_mode'] is Map)
          ? (json['payment_mode']['title']?.toString() ??
                json['payment_mode']['description']?.toString() ??
                '')
          : (json['payment_status']?.toString() ?? ''),
      createdAt: json['created_at']?.toString() ?? '',
      // details array key may be 'details' or 'PurDetails'
      purDetails:
          ((json['details'] as List<dynamic>?)
              ?.map((detail) => PurchaseDetail.fromJson(detail))
              .toList()) ??
          ((json['PurDetails'] as List<dynamic>?)
              ?.map((detail) => PurchaseDetail.fromJson(detail))
              .toList()) ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Pur_Inv_id': purInvId,
      'pur_inv_barcode': purInvBarcode,
      'pur_date': purDate,
      'vendor_id': vendorId,
      'vendorName': vendorName,
      'vendor_status': vendorStatus,
      'ven_inv_no': venInvNo,
      'ven_inv_date': venInvDate,
      'ven_inv_ref': venInvRef,
      'description': description,
      'discount_percent': discountPercent,
      'discount_amt': discountAmt,
      'tax_percent': taxPercent,
      'tax_amt': taxAmt,
      'shipping_amt': shippingAmt,
      'inv_amount': invAmount,
      'payment_status': paymentStatus,
      'created_at': createdAt,
      'PurDetails': purDetails.map((detail) => detail.toJson()).toList(),
    };
  }
}

class PurchaseResponse {
  final List<Purchase> data;
  final Links links;
  final Meta meta;

  PurchaseResponse({
    required this.data,
    required this.links,
    required this.meta,
  });

  factory PurchaseResponse.fromJson(Map<String, dynamic> json) {
    return PurchaseResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((purchase) => Purchase.fromJson(purchase))
              .toList() ??
          [],
      links: Links.fromJson(json['links'] ?? {}),
      meta: Meta.fromJson(json['meta'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data.map((purchase) => purchase.toJson()).toList(),
      'links': links.toJson(),
      'meta': meta.toJson(),
    };
  }
}

// Purchase Return Data Models
class Vendor {
  final int id;
  final String firstName;
  final String lastName;
  final String cnic;
  final String address;
  final String cityId;
  final String email;
  final String phone;
  final String status;

  Vendor({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.cnic,
    required this.address,
    required this.cityId,
    required this.email,
    required this.phone,
    required this.status,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id'] ?? 0,
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      cnic: json['cnic']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      cityId: json['city_id']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'cnic': cnic,
      'address': address,
      'city_id': cityId,
      'email': email,
      'phone': phone,
      'status': status,
    };
  }

  String get fullName => '$firstName $lastName';
}

class PurchaseReturnDetail {
  final int id;
  final String productId;
  final String qty;
  final String unitPrice;
  final String discPer;
  final String discAmount;

  PurchaseReturnDetail({
    required this.id,
    required this.productId,
    required this.qty,
    required this.unitPrice,
    required this.discPer,
    required this.discAmount,
  });

  factory PurchaseReturnDetail.fromJson(Map<String, dynamic> json) {
    return PurchaseReturnDetail(
      id: json['id'] ?? 0,
      productId: json['product_id']?.toString() ?? '',
      qty: json['qty']?.toString() ?? '',
      unitPrice: json['unit_price']?.toString() ?? '',
      discPer: json['discPer']?.toString() ?? '',
      discAmount: json['discAmount']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'qty': qty,
      'unit_price': unitPrice,
      'discPer': discPer,
      'discAmount': discAmount,
    };
  }
}

class PurchaseReturn {
  final int purchaseReturnId;
  final String returnDate;
  final String returnInvNo;
  final String reason;
  final String discountPercent;
  final String returnAmount;
  final Vendor vendor;
  final dynamic purchase; // Can be null
  final List<PurchaseReturnDetail> details;

  PurchaseReturn({
    required this.purchaseReturnId,
    required this.returnDate,
    required this.returnInvNo,
    required this.reason,
    required this.discountPercent,
    required this.returnAmount,
    required this.vendor,
    this.purchase,
    required this.details,
  });

  factory PurchaseReturn.fromJson(Map<String, dynamic> json) {
    return PurchaseReturn(
      purchaseReturnId: json['purchase_return_id'] ?? 0,
      returnDate: json['return_date']?.toString() ?? '',
      returnInvNo: json['return_inv_no']?.toString() ?? '',
      reason: json['reason']?.toString() ?? '',
      discountPercent: json['discount_percent']?.toString() ?? '',
      returnAmount: json['return_amount']?.toString() ?? '',
      vendor: Vendor.fromJson(json['vendor'] ?? {}),
      purchase: json['purchase'],
      details:
          (json['details'] as List<dynamic>?)
              ?.map((detail) => PurchaseReturnDetail.fromJson(detail))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'purchase_return_id': purchaseReturnId,
      'return_date': returnDate,
      'return_inv_no': returnInvNo,
      'reason': reason,
      'discount_percent': discountPercent,
      'return_amount': returnAmount,
      'vendor': vendor.toJson(),
      'purchase': purchase,
      'details': details.map((detail) => detail.toJson()).toList(),
    };
  }
}

class PurchaseReturnResponse {
  final List<PurchaseReturn> data;

  PurchaseReturnResponse({required this.data});

  factory PurchaseReturnResponse.fromJson(Map<String, dynamic> json) {
    return PurchaseReturnResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((purchaseReturn) => PurchaseReturn.fromJson(purchaseReturn))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data.map((purchaseReturn) => purchaseReturn.toJson()).toList(),
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

class PurchaseService {
  static const String purchasesEndpoint = '/purchases';

  // Get all purchases
  static Future<PurchaseResponse> getPurchases({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await ApiService.get(
        '$purchasesEndpoint?page=$page&per_page=$perPage',
      );

      if (response.containsKey('data')) {
        final purchaseResponse = PurchaseResponse.fromJson(response);
        return purchaseResponse;
      } else {
        return PurchaseResponse(
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
    } catch (e) {
      throw Exception('Failed to load purchases: $e');
    }
  }

  // Get purchase by ID
  static Future<Purchase> getPurchaseById(String purchaseId) async {
    try {
      final response = await ApiService.get('$purchasesEndpoint/$purchaseId');

      if (response.containsKey('data')) {
        final purchase = Purchase.fromJson(response['data']);
        return purchase;
      } else {
        throw Exception('Purchase data not found in response');
      }
    } catch (e) {
      throw Exception('Failed to load purchase: $e');
    }
  }

  // Create new purchase
  static Future<Purchase> createPurchase(
    Map<String, dynamic> purchaseData,
  ) async {
    try {
      final response = await ApiService.post(purchasesEndpoint, purchaseData);

      if (response.containsKey('data')) {
        final purchase = Purchase.fromJson(response['data']);
        return purchase;
      } else {
        throw Exception('Purchase data not found in response');
      }
    } catch (e) {
      throw Exception('Failed to create purchase: $e');
    }
  }

  // Update purchase
  static Future<Purchase> updatePurchase(
    String purchaseId,
    Map<String, dynamic> purchaseData,
  ) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}$purchasesEndpoint/$purchaseId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(purchaseData),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded.containsKey('data')) {
          final purchase = Purchase.fromJson(decoded['data']);
          return purchase;
        } else {
          throw Exception('Purchase data not found in response');
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

  // Delete purchase
  static Future<Map<String, dynamic>> deletePurchase(String purchaseId) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.delete(
        Uri.parse('${ApiService.baseUrl}$purchasesEndpoint/$purchaseId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200 || response.statusCode == 204) {
        final decoded = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {'message': 'Purchase deleted successfully'};
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
}

class PurchaseReturnService {
  static const String purchaseReturnsEndpoint = '/purchase-returns';

  // Get all purchase returns
  static Future<PurchaseReturnResponse> getPurchaseReturns({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await ApiService.get(
        '$purchaseReturnsEndpoint?page=$page&per_page=$perPage',
      );

      if (response.containsKey('data')) {
        final purchaseReturnResponse = PurchaseReturnResponse.fromJson(
          response,
        );
        return purchaseReturnResponse;
      } else {
        return PurchaseReturnResponse(data: []);
      }
    } catch (e) {
      throw Exception('Failed to load purchase returns: $e');
    }
  }

  // Get purchase return by ID
  static Future<PurchaseReturn> getPurchaseReturnById(
    int purchaseReturnId,
  ) async {
    try {
      final response = await ApiService.get(
        '$purchaseReturnsEndpoint/$purchaseReturnId',
      );

      if (response.containsKey('data')) {
        final purchaseReturn = PurchaseReturn.fromJson(response['data']);
        return purchaseReturn;
      } else {
        throw Exception('Purchase return data not found in response');
      }
    } catch (e) {
      throw Exception('Failed to load purchase return: $e');
    }
  }

  // Create new purchase return
  static Future<PurchaseReturn> createPurchaseReturn(
    Map<String, dynamic> purchaseReturnData,
  ) async {
    try {
      final response = await ApiService.post(
        purchaseReturnsEndpoint,
        purchaseReturnData,
      );

      if (response.containsKey('data')) {
        final purchaseReturn = PurchaseReturn.fromJson(response['data']);
        return purchaseReturn;
      } else {
        throw Exception('Purchase return data not found in response');
      }
    } catch (e) {
      throw Exception('Failed to create purchase return: $e');
    }
  }

  // Update purchase return
  static Future<PurchaseReturn> updatePurchaseReturn(
    int purchaseReturnId,
    Map<String, dynamic> purchaseReturnData,
  ) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.put(
        Uri.parse(
          '${ApiService.baseUrl}$purchaseReturnsEndpoint/$purchaseReturnId',
        ),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(purchaseReturnData),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded.containsKey('data')) {
          final purchaseReturn = PurchaseReturn.fromJson(decoded['data']);
          return purchaseReturn;
        } else {
          throw Exception('Purchase return data not found in response');
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

  // Delete purchase return
  static Future<Map<String, dynamic>> deletePurchaseReturn(
    int purchaseReturnId,
  ) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.delete(
        Uri.parse(
          '${ApiService.baseUrl}$purchaseReturnsEndpoint/$purchaseReturnId',
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
            : {'message': 'Purchase return deleted successfully'};
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
}
