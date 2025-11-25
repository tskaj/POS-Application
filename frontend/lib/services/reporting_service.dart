import '../services/services.dart';

class BestSellingProduct {
  final int productId;
  final String productName;
  final String designCode;
  final String imagePath;
  final String subCategoryId;
  final String salePrice;
  final String openingStockQuantity;
  final String stockInQuantity;
  final String stockOutQuantity;
  final String inStockQuantity;
  final String vendorId;
  final Vendor vendor;
  final String barcode;
  final String status;
  final String createdAt;
  final String updatedAt;
  final int totalSold;
  final double totalRevenue;

  BestSellingProduct({
    required this.productId,
    required this.productName,
    required this.designCode,
    required this.imagePath,
    required this.subCategoryId,
    required this.salePrice,
    required this.openingStockQuantity,
    required this.stockInQuantity,
    required this.stockOutQuantity,
    required this.inStockQuantity,
    required this.vendorId,
    required this.vendor,
    required this.barcode,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.totalSold,
    required this.totalRevenue,
  });

  factory BestSellingProduct.fromJson(Map<String, dynamic> json) {
    return BestSellingProduct(
      productId:
          int.tryParse(
            (json['product_id'] ?? json['productId'] ?? json['id'])
                    ?.toString() ??
                '0',
          ) ??
          0,
      productName:
          json['productName'] ?? json['product_name'] ?? json['title'] ?? '',
      designCode: json['design_code'] ?? json['designCode'] ?? '',
      imagePath: json['image_path'] ?? json['imagePath'] ?? '',
      subCategoryId:
          (json['sub_category_id'] ??
                  json['subCategoryId'] ??
                  json['sub_category_id'])
              ?.toString() ??
          '',
      salePrice: (json['sale_price'] ?? json['salePrice'])?.toString() ?? '',
      openingStockQuantity:
          (json['opening_stock_quantity'] ?? json['openingStockQuantity'])
              ?.toString() ??
          '',
      stockInQuantity:
          (json['stock_in_quantity'] ?? json['stockInQuantity'])?.toString() ??
          '',
      stockOutQuantity:
          (json['stock_out_quantity'] ?? json['stockOutQuantity'])
              ?.toString() ??
          '',
      inStockQuantity:
          (json['in_stock_quantity'] ?? json['inStockQuantity'])?.toString() ??
          '',
      vendorId: (json['vendor_id'] ?? json['vendorId'])?.toString() ?? '',
      vendor: json['vendor'] is String
          ? Vendor.fromName(json['vendor'])
          : Vendor.fromJson(json['vendor'] ?? {}),
      barcode: json['barcode'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? json['createdAt'] ?? '',
      updatedAt: json['updated_at'] ?? json['updatedAt'] ?? '',
      totalSold:
          int.tryParse(
            (json['total_sold'] ?? json['totalSold'])?.toString() ?? '0',
          ) ??
          0,
      totalRevenue:
          double.tryParse(
            (json['total_revenue'] ?? json['totalRevenue'])?.toString() ?? '0',
          ) ??
          0.0,
    );
  }
}

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
      id:
          int.tryParse((json['id'] ?? json['vendor_id'])?.toString() ?? '0') ??
          0,
      firstName:
          json['first_name'] ?? json['firstName'] ?? json['vendorName'] ?? '',
      lastName: json['last_name'] ?? json['lastName'] ?? '',
      cnic: json['cnic'] ?? '',
      address: json['address'] ?? '',
      cityId: (json['city_id'] ?? json['cityId'])?.toString() ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      status: json['status'] ?? '',
    );
  }

  factory Vendor.fromName(String name) {
    return Vendor(
      id: 0,
      firstName: name,
      lastName: '',
      cnic: '',
      address: '',
      cityId: '',
      email: '',
      phone: '',
      status: '',
    );
  }
}

class BestSellingProductsResponse {
  final List<BestSellingProduct> data;

  BestSellingProductsResponse({required this.data});

  factory BestSellingProductsResponse.fromJson(Map<String, dynamic> json) {
    return BestSellingProductsResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => BestSellingProduct.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class ReportingService {
  static const String bestSellingProductsEndpoint =
      '/reports/best-selling-products';

  static Future<BestSellingProductsResponse> getBestSellingProducts() async {
    try {
      final response = await ApiService.get(bestSellingProductsEndpoint);

      if (response.containsKey('data')) {
        final bestSellingProductsResponse =
            BestSellingProductsResponse.fromJson(response);
        return bestSellingProductsResponse;
      } else {
        return BestSellingProductsResponse(data: []);
      }
    } catch (e) {
      throw Exception('Failed to load best selling products: $e');
    }
  }
}
