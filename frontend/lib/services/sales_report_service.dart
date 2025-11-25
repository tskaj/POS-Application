import '../services/services.dart';

class SalesReport {
  final int posInvNo;
  final String productName;
  final String vendor;
  final String category;
  final String qty;
  final String salePrice;
  final double amount;
  final String openingStockQty;
  final String newStockQty;
  final String soldStockQty;
  final String instockQty;
  final DateTime? date; // Add date field for filtering

  SalesReport({
    required this.posInvNo,
    required this.productName,
    required this.vendor,
    required this.category,
    required this.qty,
    required this.salePrice,
    required this.amount,
    required this.openingStockQty,
    required this.newStockQty,
    required this.soldStockQty,
    required this.instockQty,
    this.date,
  });

  factory SalesReport.fromJson(Map<String, dynamic> json) {
    return SalesReport(
      posInvNo:
          int.tryParse(
            (json['pos_inv_no'] ?? json['posInvNo'] ?? json['invoice_no'])
                    ?.toString() ??
                '0',
          ) ??
          0,
      productName: json['product_name'] ?? json['productName'] ?? '',
      vendor: json['vendor'] ?? json['vendor_name'] ?? '',
      category: json['category'] ?? json['category_name'] ?? '',
      qty: (json['qty'] ?? json['quantity'])?.toString() ?? '0',
      salePrice: (json['sale_price'] ?? json['salePrice'])?.toString() ?? '0',
      amount:
          double.tryParse(
            (json['amount'] ?? json['total'])?.toString() ?? '0',
          ) ??
          0.0,
      openingStockQty:
          (json['opening_stock_qty'] ?? json['openingStockQty'])?.toString() ??
          '0',
      newStockQty:
          (json['new_stock_qty'] ?? json['newStockQty'])?.toString() ?? '0',
      soldStockQty:
          (json['sold_stock_qty'] ?? json['soldStockQty'])?.toString() ?? '0',
      instockQty:
          (json['instock_qty'] ?? json['instockQty'])?.toString() ?? '0',
      date: json['date'] != null ? DateTime.tryParse(json['date']) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'pos_inv_no': posInvNo,
      'product_name': productName,
      'vendor': vendor,
      'category': category,
      'qty': qty,
      'sale_price': salePrice,
      'amount': amount,
      'opening_stock_qty': openingStockQty,
      'new_stock_qty': newStockQty,
      'sold_stock_qty': soldStockQty,
      'instock_qty': instockQty,
      'date': date?.toIso8601String(),
    };
  }
}

class SalesReportResponse {
  final List<SalesReport> data;

  SalesReportResponse({required this.data});

  factory SalesReportResponse.fromJson(Map<String, dynamic> json) {
    return SalesReportResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => SalesReport.fromJson(item))
              .toList() ??
          [],
    );
  }
}

// Product-level sales report (from /productSalesRep)
class ProductSalesReport {
  final int productId;
  final String productName;
  final String vendorName;
  final String categoryName;
  final int soldQuantity;
  final double totalSaleAmount;
  final int inStockQty;

  ProductSalesReport({
    required this.productId,
    required this.productName,
    required this.vendorName,
    required this.categoryName,
    required this.soldQuantity,
    required this.totalSaleAmount,
    required this.inStockQty,
  });

  factory ProductSalesReport.fromJson(Map<String, dynamic> json) {
    return ProductSalesReport(
      productId: json['product_id'] is int
          ? json['product_id']
          : int.tryParse(json['product_id']?.toString() ?? '0') ?? 0,
      productName:
          json['product_name']?.toString() ??
          json['productName']?.toString() ??
          '',
      vendorName:
          json['vendor_name']?.toString() ??
          json['vendorName']?.toString() ??
          '',
      categoryName:
          json['category_name']?.toString() ??
          json['categoryName']?.toString() ??
          '',
      soldQuantity: json['sold_quantity'] is int
          ? json['sold_quantity']
          : int.tryParse(json['sold_quantity']?.toString() ?? '0') ?? 0,
      totalSaleAmount: json['total_sale_amount'] is double
          ? json['total_sale_amount']
          : double.tryParse(json['total_sale_amount']?.toString() ?? '0.0') ??
                0.0,
      inStockQty: json['in_stock_qty'] is int
          ? json['in_stock_qty']
          : int.tryParse(json['in_stock_qty']?.toString() ?? '0') ?? 0,
    );
  }
}

class ProductSalesReportResponse {
  final List<ProductSalesReport> data;

  ProductSalesReportResponse({required this.data});

  factory ProductSalesReportResponse.fromJson(Map<String, dynamic> json) {
    return ProductSalesReportResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => ProductSalesReport.fromJson(item))
              .toList() ??
          [],
    );
  }
}

// Provide product-level sales report API on the SalesReportService class so callers
// can invoke SalesReportService.getProductSalesReport().

class SalesReportService {
  static const String salesReportEndpoint = '/salesRep';

  static const String productSalesEndpoint = '/productSalesRep';

  static Future<ProductSalesReportResponse> getProductSalesReport() async {
    try {
      final response = await ApiService.get(productSalesEndpoint);
      if (response.containsKey('data')) {
        return ProductSalesReportResponse.fromJson(response);
      } else {
        return ProductSalesReportResponse(data: []);
      }
    } catch (e) {
      throw Exception('Failed to load product sales report: $e');
    }
  }

  static Future<SalesReportResponse> getSalesReport() async {
    try {
      final response = await ApiService.get(salesReportEndpoint);

      if (response.containsKey('data')) {
        final salesReportResponse = SalesReportResponse.fromJson(response);
        return salesReportResponse;
      } else {
        return SalesReportResponse(data: []);
      }
    } catch (e) {
      throw Exception('Failed to load sales report: $e');
    }
  }
}
