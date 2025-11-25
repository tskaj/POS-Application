import 'dart:convert';
import 'package:http/http.dart' as http;
import 'services.dart'; // Import the main ApiService
import '../models/product.dart'; // Import the Product model
import '../models/vendor.dart' as vendor; // Import the Vendor model with prefix
import '../models/category.dart'
    as category; // Import the Category model with prefix
import '../models/sub_category.dart'
    as subCategory; // Import the SubCategory model with prefix
import '../models/color.dart'
    as colorModel; // Import the Color model with prefix
import '../models/size.dart' as sizeModel; // Import the Size model with prefix
import '../models/season.dart'
    as seasonModel; // Import the Season model with prefix
import '../models/material.dart'
    as materialModel; // Import the Material model with prefix

class InventoryService {
  // Get base URL from ApiService
  static String get baseUrl => ApiService.baseUrl;

  // Get authentication token from ApiService
  static Future<String?> _getToken() async {
    return await ApiService.getToken();
  }

  // Generic authenticated request method
  static Future<Map<String, dynamic>> _authenticatedRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final url = Uri.parse('$baseUrl$endpoint');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    http.Response response;
    try {
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(url, headers: headers);
          break;
        case 'POST':
          response = await http.post(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PUT':
          response = await http.put(
            url,
            headers: headers,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          response = await http.delete(url, headers: headers);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      print('📡 INVENTORY $method Response Status: ${response.statusCode}');
      print('📨 INVENTORY $method Response Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        print('📄 INVENTORY $method Decoded Response: $decoded');
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          print(
            '⚠️ INVENTORY $method Response is not a Map, returning empty Map',
          );
          return {};
        }
      } else if (response.statusCode == 401) {
        await ApiService.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Inventory API failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('💥 INVENTORY $method error: $e');
      throw Exception('Network error: $e');
    }
  }

  // Get products from API with pagination
  static Future<ProductResponse> getProducts({
    int page = 1,
    int limit = 10,
  }) async {
    print('📦 INVENTORY: Getting products (page: $page, limit: $limit)');
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final url = Uri.parse('$baseUrl/products?page=$page&per_page=$limit');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http.get(url, headers: headers);
    print('📡 INVENTORY GET Response Status: ${response.statusCode}');
    print('📨 INVENTORY GET Response Body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      print('📄 INVENTORY GET Decoded Response: $decoded');

      // Handle both paginated and non-paginated responses
      if (decoded is List) {
        // API returns direct list - create pagination metadata and slice data
        final allProducts = decoded
            .map((item) => Product.fromJson(item))
            .toList();
        final totalItems = allProducts.length;
        final totalPages = (totalItems / limit).ceil();
        final startIndex = (page - 1) * limit;
        final endIndex = (startIndex + limit).clamp(0, totalItems);
        final pageData = allProducts.sublist(startIndex, endIndex);
        final from = startIndex + 1;
        final to = endIndex;

        return ProductResponse(
          data: pageData,
          links: Links(
            first: totalPages > 0
                ? '$baseUrl/products?page=1&per_page=$limit'
                : null,
            last: totalPages > 0
                ? '$baseUrl/products?page=$totalPages&per_page=$limit'
                : null,
            prev: page > 1
                ? '$baseUrl/products?page=${page - 1}&per_page=$limit'
                : null,
            next: page < totalPages
                ? '$baseUrl/products?page=${page + 1}&per_page=$limit'
                : null,
          ),
          meta: Meta(
            currentPage: page,
            from: from,
            lastPage: totalPages,
            links: [],
            path: '$baseUrl/products',
            perPage: limit,
            to: to,
            total: totalItems,
          ),
        );
      } else if (decoded is Map<String, dynamic>) {
        // Standard paginated response
        return ProductResponse.fromJson(decoded);
      } else {
        throw Exception('Unexpected response format');
      }
    } else if (response.statusCode == 401) {
      await ApiService.logout();
      throw Exception('Session expired. Please login again.');
    } else {
      throw Exception(
        'Inventory API failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Get vendors from API with pagination
  static Future<vendor.VendorResponse> getVendors({
    int page = 1,
    int limit = 10,
  }) async {
    print('🏪 INVENTORY: Getting vendors (page: $page, limit: $limit)');
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final url = Uri.parse(
      '$baseUrl/vendors?page=$page&per_page=$limit&sort=created_at&order=desc',
    );
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http.get(url, headers: headers);
    print('📡 INVENTORY GET Response Status: ${response.statusCode}');
    print('📨 INVENTORY GET Response Body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      print('📄 INVENTORY GET Decoded Response: $decoded');

      // Handle both paginated and non-paginated responses
      if (decoded is List) {
        // API returns direct list - create pagination metadata and slice data
        final allVendors = decoded
            .map((item) => vendor.Vendor.fromJson(item))
            .toList();
        final totalItems = allVendors.length;
        final totalPages = (totalItems / limit).ceil();
        final startIndex = (page - 1) * limit;
        final endIndex = (startIndex + limit).clamp(0, totalItems);
        final pageData = allVendors.sublist(startIndex, endIndex);
        final from = startIndex + 1;
        final to = endIndex;

        return vendor.VendorResponse(
          data: pageData,
          links: vendor.Links(
            first: totalPages > 0
                ? '$baseUrl/vendors?page=1&per_page=$limit&sort=created_at&order=desc'
                : null,
            last: totalPages > 0
                ? '$baseUrl/vendors?page=$totalPages&per_page=$limit&sort=created_at&order=desc'
                : null,
            prev: page > 1
                ? '$baseUrl/vendors?page=${page - 1}&per_page=$limit&sort=created_at&order=desc'
                : null,
            next: page < totalPages
                ? '$baseUrl/vendors?page=${page + 1}&per_page=$limit&sort=created_at&order=desc'
                : null,
          ),
          meta: vendor.Meta(
            currentPage: page,
            from: from,
            lastPage: totalPages,
            links: [], // Empty for now since we don't have detailed link info
            path: '$baseUrl/vendors',
            perPage: limit,
            to: to,
            total: totalItems,
          ),
        );
      } else if (decoded is Map<String, dynamic>) {
        // Standard paginated response
        return vendor.VendorResponse.fromJson(decoded);
      } else {
        throw Exception('Unexpected response format');
      }
    } else if (response.statusCode == 401) {
      await ApiService.logout();
      throw Exception('Session expired. Please login again.');
    } else {
      throw Exception(
        'Inventory API failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Get categories from API with pagination
  static Future<category.CategoryResponse> getCategories({
    int page = 1,
    int limit = 10,
  }) async {
    print('📂 INVENTORY: Getting categories (page: $page, limit: $limit)');
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final url = Uri.parse('$baseUrl/categories?page=$page&per_page=$limit');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http.get(url, headers: headers);
    print('📡 INVENTORY GET Response Status: ${response.statusCode}');
    print('📨 INVENTORY GET Response Body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      print('📄 INVENTORY GET Decoded Response: $decoded');

      // Handle both paginated and non-paginated responses
      if (decoded is List) {
        // API returns direct list - create pagination metadata and slice data
        final allCategories = decoded
            .map((item) => category.Category.fromJson(item))
            .toList();
        final totalItems = allCategories.length;
        final totalPages = (totalItems / limit).ceil();
        final startIndex = (page - 1) * limit;
        final endIndex = (startIndex + limit).clamp(0, totalItems);
        final pageData = allCategories.sublist(startIndex, endIndex);
        final from = startIndex + 1;
        final to = endIndex;

        return category.CategoryResponse(
          data: pageData,
          links: category.Links(
            first: totalPages > 0
                ? '$baseUrl/categories?page=1&per_page=$limit'
                : null,
            last: totalPages > 0
                ? '$baseUrl/categories?page=$totalPages&per_page=$limit'
                : null,
            prev: page > 1
                ? '$baseUrl/categories?page=${page - 1}&per_page=$limit'
                : null,
            next: page < totalPages
                ? '$baseUrl/categories?page=${page + 1}&per_page=$limit'
                : null,
          ),
          meta: category.Meta(
            currentPage: page,
            from: from,
            lastPage: totalPages,
            links: [],
            path: '$baseUrl/categories',
            perPage: limit,
            to: to,
            total: totalItems,
          ),
        );
      } else if (decoded is Map<String, dynamic>) {
        // Check if response has success/message/data structure
        if (decoded.containsKey('data') && decoded['data'] is List) {
          // API returns wrapped response - extract data array
          final dataList = decoded['data'] as List;
          final allCategories = dataList
              .map((item) => category.Category.fromJson(item))
              .toList();
          final totalItems = allCategories.length;
          final totalPages = (totalItems / limit).ceil();
          final startIndex = (page - 1) * limit;
          final endIndex = (startIndex + limit).clamp(0, totalItems);
          final pageData = allCategories.sublist(startIndex, endIndex);
          final from = startIndex + 1;
          final to = endIndex;

          return category.CategoryResponse(
            data: pageData,
            links: category.Links(
              first: totalPages > 0
                  ? '$baseUrl/categories?page=1&per_page=$limit'
                  : null,
              last: totalPages > 0
                  ? '$baseUrl/categories?page=$totalPages&per_page=$limit'
                  : null,
              prev: page > 1
                  ? '$baseUrl/categories?page=${page - 1}&per_page=$limit'
                  : null,
              next: page < totalPages
                  ? '$baseUrl/categories?page=${page + 1}&per_page=$limit'
                  : null,
            ),
            meta: category.Meta(
              currentPage: page,
              from: from,
              lastPage: totalPages,
              links: [],
              path: '$baseUrl/categories',
              perPage: limit,
              to: to,
              total: totalItems,
            ),
          );
        } else {
          // Standard paginated response
          return category.CategoryResponse.fromJson(decoded);
        }
      } else {
        throw Exception('Unexpected response format');
      }
    } else if (response.statusCode == 401) {
      await ApiService.logout();
      throw Exception('Session expired. Please login again.');
    } else {
      throw Exception(
        'Inventory API failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Get single vendor by ID from API
  static Future<vendor.Vendor> getVendor(int vendorId) async {
    print('🏪 INVENTORY: Getting vendor $vendorId');
    final response = await _authenticatedRequest('GET', '/vendors/$vendorId');
    return vendor.Vendor.fromJson(response);
  }

  // Get single product by ID from API
  static Future<Product> getProduct(int productId) async {
    print('📦 INVENTORY: Getting product $productId');
    final response = await _authenticatedRequest('GET', '/products/$productId');
    // API returns data wrapped in "data" key
    if (response.containsKey('data')) {
      return Product.fromJson(response['data']);
    } else {
      // Fallback for direct response
      return Product.fromJson(response);
    }
  }

  // Create vendor via API
  static Future<Map<String, dynamic>> createVendor(
    Map<String, dynamic> vendorData,
  ) async {
    print('🏪 INVENTORY: Creating vendor');
    print('📤 Vendor data: $vendorData');
    return await _authenticatedRequest('POST', '/vendors', body: vendorData);
  }

  // Update vendor via API
  static Future<Map<String, dynamic>> updateVendor(
    int vendorId,
    Map<String, dynamic> vendorData,
  ) async {
    print('🏪 INVENTORY: Updating vendor $vendorId');
    print('📤 Vendor data: $vendorData');
    return await _authenticatedRequest(
      'PUT',
      '/vendors/$vendorId',
      body: vendorData,
    );
  }

  // Delete vendor via API
  static Future<Map<String, dynamic>> deleteVendor(int vendorId) async {
    print('🏪 INVENTORY: Deleting vendor $vendorId');
    return await _authenticatedRequest('DELETE', '/vendors/$vendorId');
  }

  static Future<Map<String, dynamic>> createProduct(
    Map<String, dynamic> productData,
  ) async {
    print('📦 INVENTORY: Creating product');
    print('📤 Product data keys: ${productData.keys.toList()}');
    print('📤 Product data: $productData');
    print('🚀 About to call _authenticatedRequest...');
    final result = await _authenticatedRequest(
      'POST',
      '/products',
      body: productData,
    );
    print('✅ INVENTORY: createProduct completed successfully');
    return result;
  }

  static Future<Map<String, dynamic>> updateProduct(
    int productId,
    Map<String, dynamic> productData,
  ) async {
    print('📦 INVENTORY: Updating product $productId');
    print('📤 Product data: $productData');
    return await _authenticatedRequest(
      'PUT',
      '/products/$productId',
      body: productData,
    );
  }

  static Future<Map<String, dynamic>> deleteProduct(int productId) async {
    print('📦 INVENTORY: Deleting product $productId');
    return await _authenticatedRequest('DELETE', '/products/$productId');
  }

  // Get single category by ID from API
  static Future<category.CategoryDetails> getCategory(int categoryId) async {
    print('📂 INVENTORY: Getting category $categoryId');
    final response = await _authenticatedRequest(
      'GET',
      '/categories/$categoryId',
    );
    // API returns data wrapped in "data" key
    if (response.containsKey('data')) {
      return category.CategoryDetails.fromJson(response['data']);
    } else {
      // Fallback for direct response
      return category.CategoryDetails.fromJson(response);
    }
  }

  // Create category via API
  static Future<Map<String, dynamic>> createCategory(
    Map<String, dynamic> categoryData,
  ) async {
    print('📂 INVENTORY: Creating category');
    print('� Category data: $categoryData');
    return await _authenticatedRequest(
      'POST',
      '/categories',
      body: categoryData,
    );
  }

  // Update category via API
  static Future<Map<String, dynamic>> updateCategory(
    int categoryId,
    Map<String, dynamic> categoryData,
  ) async {
    print('� INVENTORY: Updating category $categoryId');
    print('📤 Category data: $categoryData');
    return await _authenticatedRequest(
      'PUT',
      '/categories/$categoryId',
      body: categoryData,
    );
  }

  // Delete category via API
  static Future<Map<String, dynamic>> deleteCategory(int categoryId) async {
    print('📂 INVENTORY: Deleting category $categoryId');
    return await _authenticatedRequest('DELETE', '/categories/$categoryId');
  }

  // Get subcategories from API with pagination
  static Future<subCategory.SubCategoryResponse> getSubCategories({
    int page = 1,
    int limit = 10,
  }) async {
    print('📂 INVENTORY: Getting subcategories (page: $page, limit: $limit)');
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final url = Uri.parse('$baseUrl/subcategories?page=$page&per_page=$limit');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http.get(url, headers: headers);
    print('📡 INVENTORY GET Response Status: ${response.statusCode}');
    print('📨 INVENTORY GET Response Body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      print('📄 INVENTORY GET Decoded Response: $decoded');

      // Handle both paginated and non-paginated responses
      if (decoded is List) {
        // API returns direct list - create pagination metadata and slice data
        final allSubCategories = decoded
            .map((item) => subCategory.SubCategory.fromJson(item))
            .toList();
        final totalItems = allSubCategories.length;
        final totalPages = (totalItems / limit).ceil();
        final startIndex = (page - 1) * limit;
        final endIndex = (startIndex + limit).clamp(0, totalItems);
        final pageData = allSubCategories.sublist(startIndex, endIndex);
        final from = startIndex + 1;
        final to = endIndex;

        return subCategory.SubCategoryResponse(
          data: pageData,
          links: category.Links(
            first: totalPages > 0
                ? '$baseUrl/subcategories?page=1&per_page=$limit'
                : null,
            last: totalPages > 0
                ? '$baseUrl/subcategories?page=$totalPages&per_page=$limit'
                : null,
            prev: page > 1
                ? '$baseUrl/subcategories?page=${page - 1}&per_page=$limit'
                : null,
            next: page < totalPages
                ? '$baseUrl/subcategories?page=${page + 1}&per_page=$limit'
                : null,
          ),
          meta: category.Meta(
            currentPage: page,
            from: from,
            lastPage: totalPages,
            links: [],
            path: '$baseUrl/subcategories',
            perPage: limit,
            to: to,
            total: totalItems,
          ),
        );
      } else if (decoded is Map<String, dynamic>) {
        // Standard paginated response
        return subCategory.SubCategoryResponse.fromJson(decoded);
      } else {
        throw Exception('Unexpected response format');
      }
    } else if (response.statusCode == 401) {
      await ApiService.logout();
      throw Exception('Session expired. Please login again.');
    } else {
      throw Exception(
        'Inventory API failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Get single subcategory by ID from API
  static Future<subCategory.SubCategory> getSubCategory(
    int subCategoryId,
  ) async {
    print('📂 INVENTORY: Getting subcategory $subCategoryId');
    final response = await _authenticatedRequest(
      'GET',
      '/subcategories/$subCategoryId',
    );
    // API returns data wrapped in "data" key
    if (response.containsKey('data')) {
      return subCategory.SubCategory.fromJson(response['data']);
    } else {
      // Fallback for direct response
      return subCategory.SubCategory.fromJson(response);
    }
  }

  // Create subcategory via API
  static Future<Map<String, dynamic>> createSubCategory(
    Map<String, dynamic> subCategoryData,
  ) async {
    print('📂 INVENTORY: Creating subcategory');
    print('📤 SubCategory data: $subCategoryData');
    return await _authenticatedRequest(
      'POST',
      '/subcategories',
      body: subCategoryData,
    );
  }

  // Update subcategory via API
  static Future<Map<String, dynamic>> updateSubCategory(
    int subCategoryId,
    Map<String, dynamic> subCategoryData,
  ) async {
    print('📂 INVENTORY: Updating subcategory $subCategoryId');
    print('📤 SubCategory data: $subCategoryData');
    return await _authenticatedRequest(
      'PUT',
      '/subcategories/$subCategoryId',
      body: subCategoryData,
    );
  }

  // Delete subcategory via API
  static Future<Map<String, dynamic>> deleteSubCategory(
    int subCategoryId,
  ) async {
    print('📂 INVENTORY: Deleting subcategory $subCategoryId');
    return await _authenticatedRequest(
      'DELETE',
      '/subcategories/$subCategoryId',
    );
  }

  // Get low stock products from API with pagination
  static Future<Map<String, dynamic>> getLowStockProducts({
    int page = 1,
    int limit = 10,
    int? categoryId,
    int? subCategoryId,
  }) async {
    print(
      '📦 INVENTORY: Getting low stock products (page: $page, limit: $limit, categoryId: $categoryId, subCategoryId: $subCategoryId)',
    );
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    // Build query parameters
    final queryParams = <String, String>{
      'page': page.toString(),
      'per_page': limit.toString(),
    };

    if (categoryId != null) {
      queryParams['category_id'] = categoryId.toString();
    }

    if (subCategoryId != null) {
      queryParams['sub_category_id'] = subCategoryId.toString();
    }

    final uri = Uri.parse(
      '$baseUrl/products/low-stock',
    ).replace(queryParameters: queryParams);
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http.get(uri, headers: headers);
    print('📡 INVENTORY GET Low Stock Response Status: ${response.statusCode}');
    print('📨 INVENTORY GET Low Stock Response Body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      print('📄 INVENTORY GET Low Stock Decoded Response: $decoded');
      return decoded;
    } else if (response.statusCode == 401) {
      await ApiService.logout();
      throw Exception('Session expired. Please login again.');
    } else {
      throw Exception(
        'Low stock products API failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Get colors from API with pagination
  static Future<colorModel.ColorResponse> getColors({
    int page = 1,
    int limit = 10,
  }) async {
    print('🎨 INVENTORY: Getting colors (page: $page, limit: $limit)');
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final url = Uri.parse('$baseUrl/colors?page=$page&per_page=$limit');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http.get(url, headers: headers);
    print('📡 INVENTORY GET Colors Response Status: ${response.statusCode}');
    print('📨 INVENTORY GET Colors Response Body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      print('📄 INVENTORY GET Colors Decoded Response: $decoded');

      // Handle both paginated and non-paginated responses
      if (decoded is List) {
        // API returns direct list - create pagination metadata and slice data
        final allColors = decoded
            .map((item) => colorModel.Color.fromJson(item))
            .toList();
        final totalItems = allColors.length;
        final totalPages = (totalItems / limit).ceil();
        final startIndex = (page - 1) * limit;
        final endIndex = (startIndex + limit).clamp(0, totalItems);
        final pageData = allColors.sublist(startIndex, endIndex);

        return colorModel.ColorResponse(
          data: pageData,
          currentPage: page,
          lastPage: totalPages,
          perPage: limit,
          total: totalItems,
        );
      } else if (decoded is Map<String, dynamic>) {
        // Standard paginated response
        return colorModel.ColorResponse.fromJson(decoded);
      } else {
        throw Exception('Unexpected response format');
      }
    } else if (response.statusCode == 401) {
      await ApiService.logout();
      throw Exception('Session expired. Please login again.');
    } else {
      throw Exception(
        'Colors API failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Get single color by ID from API
  static Future<colorModel.Color> getColor(int colorId) async {
    print('🎨 INVENTORY: Getting color $colorId');
    final response = await _authenticatedRequest('GET', '/colors/$colorId');
    return colorModel.Color.fromJson(response);
  }

  // Create color via API
  static Future<Map<String, dynamic>> createColor(
    Map<String, dynamic> colorData,
  ) async {
    print('🎨 INVENTORY: Creating color');
    print('📤 Color data: $colorData');
    return await _authenticatedRequest('POST', '/colors', body: colorData);
  }

  // Update color via API
  static Future<Map<String, dynamic>> updateColor(
    int colorId,
    Map<String, dynamic> colorData,
  ) async {
    print('🎨 INVENTORY: Updating color $colorId');
    print('📤 Color data: $colorData');
    return await _authenticatedRequest(
      'PUT',
      '/colors/$colorId',
      body: colorData,
    );
  }

  // Delete color via API
  static Future<Map<String, dynamic>> deleteColor(int colorId) async {
    print('🎨 INVENTORY: Deleting color $colorId');
    return await _authenticatedRequest('DELETE', '/colors/$colorId');
  }

  // Get sizes from API with pagination
  static Future<sizeModel.SizeResponse> getSizes({
    int page = 1,
    int limit = 10,
  }) async {
    print('📏 INVENTORY: Getting sizes (page: $page, limit: $limit)');
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final url = Uri.parse('$baseUrl/sizes?page=$page&per_page=$limit');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http.get(url, headers: headers);
    print('📡 INVENTORY GET Sizes Response Status: ${response.statusCode}');
    print('📨 INVENTORY GET Sizes Response Body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      print('📄 INVENTORY GET Sizes Decoded Response: $decoded');

      // Handle both paginated and non-paginated responses
      if (decoded is List) {
        // API returns direct list - create pagination metadata and slice data
        final allSizes = decoded
            .map((item) => sizeModel.Size.fromJson(item))
            .toList();
        final totalItems = allSizes.length;
        final totalPages = (totalItems / limit).ceil();
        final startIndex = (page - 1) * limit;
        final endIndex = (startIndex + limit).clamp(0, totalItems);
        final pageData = allSizes.sublist(startIndex, endIndex);

        return sizeModel.SizeResponse(
          data: pageData,
          currentPage: page,
          lastPage: totalPages,
          perPage: limit,
          total: totalItems,
        );
      } else if (decoded is Map<String, dynamic>) {
        // Standard paginated response
        return sizeModel.SizeResponse.fromJson(decoded);
      } else {
        throw Exception('Unexpected response format');
      }
    } else if (response.statusCode == 401) {
      await ApiService.logout();
      throw Exception('Session expired. Please login again.');
    } else {
      throw Exception(
        'Sizes API failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Get single size by ID from API
  static Future<sizeModel.Size> getSize(int sizeId) async {
    print('📏 INVENTORY: Getting size $sizeId');
    final response = await _authenticatedRequest('GET', '/sizes/$sizeId');
    return sizeModel.Size.fromJson(response);
  }

  // Create size via API
  static Future<Map<String, dynamic>> createSize(
    Map<String, dynamic> sizeData,
  ) async {
    print('📏 INVENTORY: Creating size');
    print('📤 Size data: $sizeData');
    return await _authenticatedRequest('POST', '/sizes', body: sizeData);
  }

  // Update size via API
  static Future<Map<String, dynamic>> updateSize(
    int sizeId,
    Map<String, dynamic> sizeData,
  ) async {
    print('📏 INVENTORY: Updating size $sizeId');
    print('📤 Size data: $sizeData');
    return await _authenticatedRequest('PUT', '/sizes/$sizeId', body: sizeData);
  }

  // Delete size via API
  static Future<Map<String, dynamic>> deleteSize(int sizeId) async {
    print('📏 INVENTORY: Deleting size $sizeId');
    return await _authenticatedRequest('DELETE', '/sizes/$sizeId');
  }

  // Get seasons from API with pagination
  static Future<seasonModel.SeasonResponse> getSeasons({
    int page = 1,
    int limit = 10,
  }) async {
    print('🌤️ INVENTORY: Getting seasons (page: $page, limit: $limit)');
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final url = Uri.parse('$baseUrl/seasons?page=$page&per_page=$limit');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http.get(url, headers: headers);
    print('📡 INVENTORY GET Seasons Response Status: ${response.statusCode}');
    print('📨 INVENTORY GET Seasons Response Body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      print('📄 INVENTORY GET Seasons Decoded Response: $decoded');

      // Handle both paginated and non-paginated responses
      if (decoded is List) {
        // API returns direct list - create pagination metadata and slice data
        final allSeasons = decoded
            .map((item) => seasonModel.Season.fromJson(item))
            .toList();
        final totalItems = allSeasons.length;
        final totalPages = (totalItems / limit).ceil();
        final startIndex = (page - 1) * limit;
        final endIndex = (startIndex + limit).clamp(0, totalItems);
        final pageData = allSeasons.sublist(startIndex, endIndex);

        return seasonModel.SeasonResponse(
          data: pageData,
          currentPage: page,
          lastPage: totalPages,
          perPage: limit,
          total: totalItems,
        );
      } else if (decoded is Map<String, dynamic>) {
        // Standard paginated response
        return seasonModel.SeasonResponse.fromJson(decoded);
      } else {
        throw Exception('Unexpected response format');
      }
    } else if (response.statusCode == 401) {
      await ApiService.logout();
      throw Exception('Session expired. Please login again.');
    } else {
      throw Exception(
        'Seasons API failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Get single season by ID from API
  static Future<seasonModel.Season> getSeason(int seasonId) async {
    print('🌤️ INVENTORY: Getting season $seasonId');
    final response = await _authenticatedRequest('GET', '/seasons/$seasonId');
    return seasonModel.Season.fromJson(response);
  }

  // Create season via API
  static Future<Map<String, dynamic>> createSeason(
    Map<String, dynamic> seasonData,
  ) async {
    print('🌤️ INVENTORY: Creating season');
    print('📤 Season data: $seasonData');
    return await _authenticatedRequest('POST', '/seasons', body: seasonData);
  }

  // Update season via API
  static Future<Map<String, dynamic>> updateSeason(
    int seasonId,
    Map<String, dynamic> seasonData,
  ) async {
    print('🌤️ INVENTORY: Updating season $seasonId');
    print('📤 Season data: $seasonData');
    return await _authenticatedRequest(
      'PUT',
      '/seasons/$seasonId',
      body: seasonData,
    );
  }

  // Delete season via API
  static Future<Map<String, dynamic>> deleteSeason(int seasonId) async {
    print('🌤️ INVENTORY: Deleting season $seasonId');
    return await _authenticatedRequest('DELETE', '/seasons/$seasonId');
  }

  // Get materials from API with pagination
  static Future<materialModel.MaterialResponse> getMaterials({
    int page = 1,
    int limit = 10,
  }) async {
    print('🧵 INVENTORY: Getting materials (page: $page, limit: $limit)');
    final token = await _getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    final url = Uri.parse('$baseUrl/materials?page=$page&per_page=$limit');
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };

    final response = await http.get(url, headers: headers);
    print('📡 INVENTORY GET Materials Response Status: ${response.statusCode}');
    print('📨 INVENTORY GET Materials Response Body: ${response.body}');

    if (response.statusCode >= 200 && response.statusCode < 300) {
      final decoded = jsonDecode(response.body);
      print('📄 INVENTORY GET Materials Decoded Response: $decoded');

      // Handle both paginated and non-paginated responses
      if (decoded is List) {
        // API returns direct list - create pagination metadata and slice data
        final allMaterials = decoded
            .map((item) => materialModel.Material.fromJson(item))
            .toList();
        final totalItems = allMaterials.length;
        final totalPages = (totalItems / limit).ceil();
        final startIndex = (page - 1) * limit;
        final endIndex = (startIndex + limit).clamp(0, totalItems);
        final pageData = allMaterials.sublist(startIndex, endIndex);

        return materialModel.MaterialResponse(
          data: pageData,
          currentPage: page,
          lastPage: totalPages,
          perPage: limit,
          total: totalItems,
        );
      } else if (decoded is Map<String, dynamic>) {
        // Standard paginated response
        return materialModel.MaterialResponse.fromJson(decoded);
      } else {
        throw Exception('Unexpected response format');
      }
    } else if (response.statusCode == 401) {
      await ApiService.logout();
      throw Exception('Session expired. Please login again.');
    } else {
      throw Exception(
        'Materials API failed: ${response.statusCode} - ${response.body}',
      );
    }
  }

  // Get single material by ID from API
  static Future<materialModel.Material> getMaterial(int materialId) async {
    print('🧵 INVENTORY: Getting material $materialId');
    final response = await _authenticatedRequest(
      'GET',
      '/materials/$materialId',
    );
    return materialModel.Material.fromJson(response);
  }

  // Create material via API
  static Future<Map<String, dynamic>> createMaterial(
    Map<String, dynamic> materialData,
  ) async {
    print('🧵 INVENTORY: Creating material');
    print('📤 Material data: $materialData');
    return await _authenticatedRequest(
      'POST',
      '/materials',
      body: materialData,
    );
  }

  // Update material via API
  static Future<Map<String, dynamic>> updateMaterial(
    int materialId,
    Map<String, dynamic> materialData,
  ) async {
    print('🧵 INVENTORY: Updating material $materialId');
    print('📤 Material data: $materialData');
    return await _authenticatedRequest(
      'PUT',
      '/materials/$materialId',
      body: materialData,
    );
  }

  // Delete material via API
  static Future<Map<String, dynamic>> deleteMaterial(int materialId) async {
    print('🧵 INVENTORY: Deleting material $materialId');
    return await _authenticatedRequest('DELETE', '/materials/$materialId');
  }
}
