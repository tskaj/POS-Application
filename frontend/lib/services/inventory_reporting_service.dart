import '../services/services.dart';

// Common models
class Category {
  final int id;
  final String categoryName;

  Category({required this.id, required this.categoryName});

  factory Category.fromJson(dynamic json) {
    // API sometimes returns a plain string for category (e.g., "Casual")
    if (json == null) return Category(id: 0, categoryName: '');
    if (json is String) return Category(id: 0, categoryName: json);

    if (json is Map) {
      // handle nested shapes like { "category": { ... } }
      if (json['category'] != null) return Category.fromJson(json['category']);

      final id = int.tryParse(json['id']?.toString() ?? '0') ?? 0;
      final name =
          (json['CategoryName'] ??
                  json['categoryName'] ??
                  json['category_name'] ??
                  json['name'] ??
                  json['title'] ??
                  json['label'])
              ?.toString();

      return Category(id: id, categoryName: name ?? '');
    }

    // Fallback: convert any other value to string
    return Category(id: 0, categoryName: json.toString());
  }
}

class SubCategory {
  final int id;
  final String subCatName;

  SubCategory({required this.id, required this.subCatName});
  factory SubCategory.fromJson(dynamic json) {
    if (json == null) return SubCategory(id: 0, subCatName: '');
    if (json is String) return SubCategory(id: 0, subCatName: json);

    if (json is Map) {
      if (json['sub_category'] != null)
        return SubCategory.fromJson(json['sub_category']);

      final id = int.tryParse(json['id']?.toString() ?? '0') ?? 0;
      final name =
          (json['subCatName'] ??
                  json['sub_cat_name'] ??
                  json['name'] ??
                  json['title'])
              ?.toString();
      return SubCategory(id: id, subCatName: name ?? '');
    }

    return SubCategory(id: 0, subCatName: json.toString());
  }
}

class Vendor {
  final int id;
  final String vendorName;

  Vendor({required this.id, required this.vendorName});
  factory Vendor.fromJson(dynamic json) {
    if (json == null) return Vendor(id: 0, vendorName: '');
    if (json is String) return Vendor(id: 0, vendorName: json);

    if (json is Map) {
      if (json['vendor'] != null) return Vendor.fromJson(json['vendor']);

      final id = int.tryParse(json['id']?.toString() ?? '0') ?? 0;
      final name =
          (json['vendorName'] ??
                  json['vendor_name'] ??
                  json['name'] ??
                  json['first_name'])
              ?.toString();
      return Vendor(id: id, vendorName: name ?? '');
    }

    return Vendor(id: 0, vendorName: json.toString());
  }
}

// In Hand Product Model
class InHandProduct {
  final int id;
  final String productName;
  final String barcode;
  final String designCode;
  final String? imagePath;
  final Category category;
  final SubCategory subCategory;
  final String balanceStock;
  final Vendor vendor;
  final String productStatus;

  InHandProduct({
    required this.id,
    required this.productName,
    required this.barcode,
    required this.designCode,
    required this.imagePath,
    required this.category,
    required this.subCategory,
    required this.balanceStock,
    required this.vendor,
    required this.productStatus,
  });

  factory InHandProduct.fromJson(Map<String, dynamic> json) {
    return InHandProduct(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      productName:
          (json['title'] ?? json['productName'] ?? json['product_name'] ?? '')
              .toString(),
      barcode: (json['barcode'] ?? '').toString(),
      designCode: (json['design_code'] ?? json['designCode'] ?? '').toString(),
      imagePath: (json['image_path'] ?? json['imagePath'])?.toString(),
      category: Category.fromJson(json['category']),
      subCategory: SubCategory.fromJson(json['sub_category']),
      // API returns 'in_stock_quantity' for quantity
      balanceStock:
          (json['in_stock_quantity'] ??
                  json['balance_stock'] ??
                  json['balanceStock'] ??
                  '0')
              .toString(),
      vendor: Vendor.fromJson(json['vendor']),
      productStatus:
          (json['status'] ??
                  json['productStatus'] ??
                  json['product_status'] ??
                  '')
              .toString(),
    );
  }
}

// History Product Model
class HistoryProduct {
  final int id;
  final String productName;
  final String barcode;
  final String designCode;
  final String? imagePath;
  final Category category;
  final SubCategory subCategory;
  final String salePrice;
  final String openingStock;
  final String newStock;
  final String soldStock;
  final String balanceStock;
  final Vendor vendor;
  final String productStatus;

  HistoryProduct({
    required this.id,
    required this.productName,
    required this.barcode,
    required this.designCode,
    required this.imagePath,
    required this.category,
    required this.subCategory,
    required this.salePrice,
    required this.openingStock,
    required this.newStock,
    required this.soldStock,
    required this.balanceStock,
    required this.vendor,
    required this.productStatus,
  });

  factory HistoryProduct.fromJson(Map<String, dynamic> json) {
    return HistoryProduct(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      productName:
          (json['title'] ?? json['productName'] ?? json['product_name'] ?? '')
              .toString(),
      barcode: (json['barcode'] ?? '').toString(),
      designCode: (json['design_code'] ?? json['designCode'] ?? '').toString(),
      imagePath: (json['image_path'] ?? json['imagePath'])?.toString(),
      category: Category.fromJson(json['category']),
      subCategory: SubCategory.fromJson(json['sub_category']),
      salePrice: (json['sale_price'] ?? json['salePrice'] ?? '0.00').toString(),
      // API returns opening_stock_quantity
      openingStock:
          (json['opening_stock_quantity'] ??
                  json['opening_stock'] ??
                  json['openingStock'] ??
                  '0')
              .toString(),
      // API returns stock_in_quantity
      newStock:
          (json['stock_in_quantity'] ??
                  json['new_stock'] ??
                  json['newStock'] ??
                  json['stock_in_qty'] ??
                  '0')
              .toString(),
      // API returns stock_out_quantity
      soldStock:
          (json['stock_out_quantity'] ??
                  json['sold_stock'] ??
                  json['soldStock'] ??
                  json['stock_out_qty'] ??
                  '0')
              .toString(),
      // API returns in_stock_quantity as balance
      balanceStock:
          (json['in_stock_quantity'] ??
                  json['in_stock_qty'] ??
                  json['balance_stock'] ??
                  json['balanceStock'] ??
                  '0')
              .toString(),
      vendor: Vendor.fromJson(json['vendor']),
      productStatus:
          (json['status'] ??
                  json['productStatus'] ??
                  json['product_status'] ??
                  '')
              .toString(),
    );
  }
}

// Sold Product Model
class SoldProduct {
  final int id;
  final String productName;
  final String barcode;
  final String designCode;
  final String? imagePath;
  final Category category;
  final SubCategory subCategory;
  final String salePrice;
  final String stockOut;
  final Vendor vendor;
  final String productStatus;

  SoldProduct({
    required this.id,
    required this.productName,
    required this.barcode,
    required this.designCode,
    required this.imagePath,
    required this.category,
    required this.subCategory,
    required this.salePrice,
    required this.stockOut,
    required this.vendor,
    required this.productStatus,
  });

  factory SoldProduct.fromJson(Map<String, dynamic> json) {
    return SoldProduct(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      productName:
          (json['title'] ?? json['productName'] ?? json['product_name'] ?? '')
              .toString(),
      barcode: (json['barcode'] ?? '').toString(),
      designCode: (json['design_code'] ?? json['designCode'] ?? '').toString(),
      imagePath: (json['image_path'] ?? json['imagePath'])?.toString(),
      category: Category.fromJson(json['category']),
      subCategory: SubCategory.fromJson(json['sub_category']),
      salePrice: (json['sale_price'] ?? json['salePrice'] ?? '0.00').toString(),
      // API returns stock_out_quantity
      stockOut:
          (json['stock_out_quantity'] ??
                  json['stock_out_qty'] ??
                  json['stock_out'] ??
                  json['stockOut'] ??
                  '0')
              .toString(),
      vendor: Vendor.fromJson(json['vendor']),
      productStatus:
          (json['status'] ??
                  json['productStatus'] ??
                  json['product_status'] ??
                  '')
              .toString(),
    );
  }
}

// Response models
class InHandProductsResponse {
  final List<InHandProduct> data;

  InHandProductsResponse({required this.data});

  factory InHandProductsResponse.fromJson(Map<String, dynamic> json) {
    return InHandProductsResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => InHandProduct.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class HistoryProductsResponse {
  final List<HistoryProduct> data;

  HistoryProductsResponse({required this.data});

  factory HistoryProductsResponse.fromJson(Map<String, dynamic> json) {
    return HistoryProductsResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => HistoryProduct.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class SoldProductsResponse {
  final List<SoldProduct> data;

  SoldProductsResponse({required this.data});

  factory SoldProductsResponse.fromJson(Map<String, dynamic> json) {
    return SoldProductsResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => SoldProduct.fromJson(item))
              .toList() ??
          [],
    );
  }
}

// Product Detail Models
class ProductDetailVendor {
  final int id;
  final String name;

  ProductDetailVendor({required this.id, required this.name});

  factory ProductDetailVendor.fromJson(Map<String, dynamic> json) {
    return ProductDetailVendor(id: json['id'] ?? 0, name: json['name'] ?? '');
  }
}

class ProductDetailInfo {
  final int id;
  final String title;
  final String openingStockQuantity;
  final ProductDetailVendor vendor;
  final String createdAt;

  ProductDetailInfo({
    required this.id,
    required this.title,
    required this.openingStockQuantity,
    required this.vendor,
    required this.createdAt,
  });

  factory ProductDetailInfo.fromJson(Map<String, dynamic> json) {
    return ProductDetailInfo(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      openingStockQuantity: (json['opening_stock_quantity'] ?? '0').toString(),
      vendor: ProductDetailVendor.fromJson(json['vendor'] ?? {}),
      createdAt: json['created_at'] ?? '',
    );
  }
}

class ProductTransactionDetail {
  final String createdAt;
  final String transactionType;
  final String qtyIn;
  final String qtyOut;
  final String balanceQty;
  // final int balanceQty;

  ProductTransactionDetail({
    required this.createdAt,
    required this.transactionType,
    required this.qtyIn,
    required this.qtyOut,
    required this.balanceQty,
  });

  factory ProductTransactionDetail.fromJson(Map<String, dynamic> json) {
    return ProductTransactionDetail(
      createdAt: json['created_at'] ?? '',
      transactionType: json['transaction_type'] ?? '',
      qtyIn: (json['qty_in'] ?? '0').toString(),
      qtyOut: (json['qty_out'] ?? '0').toString(),
      balanceQty: (json['balance_qty'] ?? '0').toString(),
    );
  }
}

class ProductDetailTotals {
  final String openingStockQuantity;
  final int qtyIn;
  final int qtyOut;
  final int balanceQty;

  ProductDetailTotals({
    required this.openingStockQuantity,
    required this.qtyIn,
    required this.qtyOut,
    required this.balanceQty,
  });

  factory ProductDetailTotals.fromJson(Map<String, dynamic> json) {
    return ProductDetailTotals(
      openingStockQuantity: (json['opening_stock_quantity'] ?? '0').toString(),
      qtyIn: json['qty_in'] ?? 0,
      qtyOut: json['qty_out'] ?? 0,
      balanceQty: json['balance_qty'] ?? 0,
    );
  }
}

class ProductDetailResponse {
  final bool status;
  final ProductDetailInfo product;
  final List<ProductTransactionDetail> productDetails;
  final ProductDetailTotals totals;

  ProductDetailResponse({
    required this.status,
    required this.product,
    required this.productDetails,
    required this.totals,
  });

  factory ProductDetailResponse.fromJson(Map<String, dynamic> json) {
    final data = json['data'] ?? {};
    return ProductDetailResponse(
      status: data['status'] ?? false,
      product: ProductDetailInfo.fromJson(data['product'] ?? {}),
      productDetails:
          (data['product_details'] as List<dynamic>?)
              ?.map((item) => ProductTransactionDetail.fromJson(item))
              .toList() ??
          [],
      totals: ProductDetailTotals.fromJson(data['totals'] ?? {}),
    );
  }
}

// Service class
class InventoryReportingService {
  static const String inHandEndpoint = '/InvtoryReport';
  static const String historyEndpoint = '/InvtoryInHistory';
  static const String soldEndpoint = '/InventorySold';

  static Future<InHandProductsResponse> getInHandProducts() async {
    try {
      final response = await ApiService.get(inHandEndpoint);

      if (response.containsKey('data')) {
        final inHandProductsResponse = InHandProductsResponse.fromJson(
          response,
        );
        return inHandProductsResponse;
      } else {
        return InHandProductsResponse(data: []);
      }
    } catch (e) {
      throw Exception('Failed to load in-hand products: $e');
    }
  }

  static Future<HistoryProductsResponse> getHistoryProducts() async {
    try {
      final response = await ApiService.get(historyEndpoint);

      if (response.containsKey('data')) {
        final historyProductsResponse = HistoryProductsResponse.fromJson(
          response,
        );
        return historyProductsResponse;
      } else {
        return HistoryProductsResponse(data: []);
      }
    } catch (e) {
      throw Exception('Failed to load history products: $e');
    }
  }

  static Future<SoldProductsResponse> getSoldProducts() async {
    try {
      final response = await ApiService.get(soldEndpoint);

      if (response.containsKey('data')) {
        final soldProductsResponse = SoldProductsResponse.fromJson(response);
        return soldProductsResponse;
      } else {
        return SoldProductsResponse(data: []);
      }
    } catch (e) {
      throw Exception('Failed to load sold products: $e');
    }
  }

  static Future<ProductDetailResponse> getProductDetail(int productId) async {
    try {
      final response = await ApiService.get(
        '/transactions/showProductDetail/$productId',
      );

      return ProductDetailResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load product details: $e');
    }
  }
}
