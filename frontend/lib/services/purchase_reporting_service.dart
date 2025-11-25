import '../services/services.dart';

// Purchase Detail Model
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
      productId: (json['product_id'] ?? json['productId'])?.toString() ?? '',
      productName: json['productName'] ?? json['product_name'] ?? '',
      quantity: (json['quantity'] ?? json['qty'])?.toString() ?? '0',
      unitPrice:
          (json['unit_price'] ?? json['unitPrice'])?.toString() ?? '0.00',
      discPer:
          (json['discPer'] ?? json['disc_per'] ?? json['discount_percent'])
              ?.toString() ??
          '0.00',
      discAmount:
          (json['discAmount'] ?? json['disc_amount'] ?? json['discount_amount'])
              ?.toString() ??
          '0.00',
      amount: (json['amount'] ?? json['total'])?.toString() ?? '0.00',
    );
  }
}

// Purchase Report Model
class PurchaseReport {
  final int purInvId;
  final String purInvBarcode;
  final String purDate;
  final String vendorId;
  final String vendorName;
  final String vendorStatus;
  final String venInvNo;
  final String venInvDate;
  final String venInvRef;
  final String? description;
  final String invDiscPer;
  final String invDiscAmount;
  final String invAmount;
  final String paymentStatus;
  final String createdAt;
  final List<PurchaseDetail> purDetails;

  PurchaseReport({
    required this.purInvId,
    required this.purInvBarcode,
    required this.purDate,
    required this.vendorId,
    required this.vendorName,
    required this.vendorStatus,
    required this.venInvNo,
    required this.venInvDate,
    required this.venInvRef,
    this.description,
    required this.invDiscPer,
    required this.invDiscAmount,
    required this.invAmount,
    required this.paymentStatus,
    required this.createdAt,
    required this.purDetails,
  });

  factory PurchaseReport.fromJson(Map<String, dynamic> json) {
    return PurchaseReport(
      purInvId:
          int.tryParse(
            (json['Pur_Inv_id'] ?? json['pur_inv_id'] ?? json['id'])
                    ?.toString() ??
                '0',
          ) ??
          0,
      purInvBarcode: json['pur_inv_barcode'] ?? json['purInvBarcode'] ?? '',
      purDate:
          json['pur_date'] ?? json['purDate'] ?? json['purchase_date'] ?? '',
      vendorId: (json['vendor_id'] ?? json['vendorId'])?.toString() ?? '',
      // vendor may be nested as an object with first_name/last_name/status
      vendorName: (json['vendor'] is Map)
          ? (((json['vendor']['first_name']?.toString() ?? '') +
                    ' ' +
                    (json['vendor']['last_name']?.toString() ?? ''))
                .trim())
          : (json['vendorName'] ?? json['vendor_name'] ?? ''),
      vendorStatus: (json['vendor'] is Map)
          ? (json['vendor']['status']?.toString() ?? '')
          : (json['vendor_status']?.toString() ?? ''),
      venInvNo:
          json['ven_inv_no'] ??
          json['venInvNo'] ??
          json['invoice_number'] ??
          '',
      venInvDate:
          json['ven_inv_date'] ??
          json['venInvDate'] ??
          json['invoice_date'] ??
          '',
      venInvRef:
          json['ven_inv_ref'] ?? json['venInvRef'] ?? json['reference'] ?? '',
      description: json['description'],
      invDiscPer:
          (json['invDiscPer'] ??
                  json['inv_disc_per'] ??
                  json['discount_percent'])
              ?.toString() ??
          '0.00',
      invDiscAmount:
          (json['invDiscAmount'] ??
                  json['inv_disc_amount'] ??
                  json['discount_amount'])
              ?.toString() ??
          '0.00',
      invAmount:
          (json['inv_amount'] ?? json['invAmount'] ?? json['total_amount'])
              ?.toString() ??
          '0.00',
      paymentStatus: json['payment_status'] ?? json['paymentStatus'] ?? '',
      createdAt: json['created_at'] ?? json['createdAt'] ?? '',
      purDetails: _parsePurchaseDetails(
        json['PurDetails'] ??
            json['purDetails'] ??
            json['pur_details'] ??
            json['details'],
      ),
    );
  }

  static List<PurchaseDetail> _parsePurchaseDetails(dynamic details) {
    if (details == null) return [];
    if (details is! List) return [];

    return details
        .map((item) {
          if (item is Map<String, dynamic>) {
            return PurchaseDetail.fromJson(item);
          }
          return null;
        })
        .whereType<PurchaseDetail>()
        .toList();
  }
}

// Response models
class PurchaseReportsResponse {
  final List<PurchaseReport> data;

  PurchaseReportsResponse({required this.data});

  factory PurchaseReportsResponse.fromJson(Map<String, dynamic> json) {
    return PurchaseReportsResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => PurchaseReport.fromJson(item))
              .toList() ??
          [],
    );
  }
}

// Service class
class PurchaseReportingService {
  static const String purchaseReportEndpoint = '/purReport';

  static Future<PurchaseReportsResponse> getPurchaseReports() async {
    try {
      final response = await ApiService.get(purchaseReportEndpoint);

      if (response.containsKey('data')) {
        final purchaseReportsResponse = PurchaseReportsResponse.fromJson(
          response,
        );
        return purchaseReportsResponse;
      } else {
        return PurchaseReportsResponse(data: []);
      }
    } catch (e) {
      throw Exception('Failed to load purchase reports: $e');
    }
  }
}
