import 'dart:convert';
import 'package:http/http.dart' as http;
import 'services.dart';

// Data models for Expense API
class ExpenseCategory {
  final int id;
  final String category;
  final String description;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  ExpenseCategory({
    required this.id,
    required this.category,
    required this.description,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory ExpenseCategory.fromJson(Map<String, dynamic> json) {
    return ExpenseCategory(
      id: json['id'] ?? 0,
      category: json['category']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'category': category,
      'description': description,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class TransactionType {
  final int id;
  final String transType;
  final String code;
  final String? createdAt;
  final String? updatedAt;

  TransactionType({
    required this.id,
    required this.transType,
    required this.code,
    this.createdAt,
    this.updatedAt,
  });

  factory TransactionType.fromJson(Map<String, dynamic> json) {
    return TransactionType(
      id: json['id'] ?? 0,
      transType: json['transType']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transType': transType,
      'code': code,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class Expense {
  final int id;
  final String transactionTypeId;
  final String name;
  final String expenseCategoryId;
  final String description;
  final String date;
  final double amount;
  final String createdAt;
  final String updatedAt;
  final ExpenseCategory category;
  final TransactionType transactionType;

  Expense({
    required this.id,
    required this.transactionTypeId,
    required this.name,
    required this.expenseCategoryId,
    required this.description,
    required this.date,
    required this.amount,
    required this.createdAt,
    required this.updatedAt,
    required this.category,
    required this.transactionType,
  });

  factory Expense.fromJson(Map<String, dynamic> json) {
    return Expense(
      id: json['id'] ?? 0,
      transactionTypeId: json['transaction_type_id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      expenseCategoryId: json['expense_category_id']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      category: ExpenseCategory.fromJson(json['category'] ?? {}),
      transactionType: TransactionType.fromJson(json['transaction_type'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_type_id': transactionTypeId,
      'name': name,
      'expense_category_id': expenseCategoryId,
      'description': description,
      'date': date,
      'amount': amount,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'category': category.toJson(),
      'transaction_type': transactionType.toJson(),
    };
  }

  // For creating/updating expenses (without nested objects)
  Map<String, dynamic> toCreateJson() {
    return {
      'name': name,
      'expense_category_id': int.tryParse(expenseCategoryId) ?? 0,
      'description': description,
      'date': date,
      'amount': amount,
    };
  }
}

class ExpenseResponse {
  final bool status;
  final String message;
  final List<Expense> data;

  ExpenseResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory ExpenseResponse.fromJson(Map<String, dynamic> json) {
    return ExpenseResponse(
      status: json['status'] ?? false,
      message: json['message']?.toString() ?? '',
      data:
          (json['data'] as List<dynamic>?)
              ?.map((expense) => Expense.fromJson(expense))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'data': data.map((expense) => expense.toJson()).toList(),
    };
  }
}

class SingleExpenseResponse {
  final bool status;
  final String message;
  final Expense data;

  SingleExpenseResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory SingleExpenseResponse.fromJson(Map<String, dynamic> json) {
    return SingleExpenseResponse(
      status: json['status'] ?? false,
      message: json['message']?.toString() ?? '',
      data: Expense.fromJson(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {'status': status, 'message': message, 'data': data.toJson()};
  }
}

class SingleExpenseCategoryResponse {
  final bool status;
  final String message;
  final ExpenseCategory data;

  SingleExpenseCategoryResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory SingleExpenseCategoryResponse.fromJson(Map<String, dynamic> json) {
    return SingleExpenseCategoryResponse(
      status: json['status'] ?? false,
      message: json['message']?.toString() ?? '',
      data: ExpenseCategory.fromJson(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {'status': status, 'message': message, 'data': data.toJson()};
  }
}

class ExpenseCategoriesResponse {
  final bool status;
  final String message;
  final List<ExpenseCategory> data;

  ExpenseCategoriesResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory ExpenseCategoriesResponse.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoriesResponse(
      status: json['status'] ?? false,
      message: json['message']?.toString() ?? '',
      data:
          (json['data'] as List<dynamic>?)
              ?.map((category) => ExpenseCategory.fromJson(category))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'data': data.map((category) => category.toJson()).toList(),
    };
  }
}

class ExpenseService {
  static const String expensesEndpoint = '/expenses';
  static const String expenseCategoriesEndpoint = '/expense-categories';

  // Get all expenses with pagination support
  static Future<ExpenseResponse> getExpenses({
    int page = 1,
    int perPage = 20,
  }) async {
    try {
      final response = await ApiService.get(
        '$expensesEndpoint?page=$page&per_page=$perPage',
      );

      if (response['status'] == true) {
        final expenseResponse = ExpenseResponse.fromJson(response);
        return expenseResponse;
      } else {
        return ExpenseResponse(
          status: false,
          message: response['message']?.toString() ?? 'Failed to load expenses',
          data: [],
        );
      }
    } catch (e) {
      throw Exception('Failed to load expenses: $e');
    }
  }

  // Get all expenses by fetching all pages (for client-side caching)
  static Future<List<Expense>> getAllExpenses() async {
    try {
      List<Expense> allExpenses = [];
      int currentPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        final response = await getExpenses(page: currentPage, perPage: 100);

        if (response.status && response.data.isNotEmpty) {
          allExpenses.addAll(response.data);
          currentPage++;

          // If we got fewer results than requested, we've reached the last page
          if (response.data.length < 100) {
            hasMorePages = false;
          }
        } else {
          hasMorePages = false;
        }
      }

      return allExpenses;
    } catch (e) {
      throw Exception('Failed to load all expenses: $e');
    }
  }

  // Get expense by ID
  static Future<SingleExpenseResponse> getExpenseById(int expenseId) async {
    try {
      final response = await ApiService.get('$expensesEndpoint/$expenseId');

      if (response['status'] == true) {
        final singleExpenseResponse = SingleExpenseResponse.fromJson(response);
        return singleExpenseResponse;
      } else {
        throw Exception(response['message']?.toString() ?? 'Expense not found');
      }
    } catch (e) {
      throw Exception('Failed to load expense: $e');
    }
  }

  // Create new expense
  static Future<SingleExpenseResponse> createExpense(
    Map<String, dynamic> expenseData,
  ) async {
    try {
      final response = await ApiService.post(expensesEndpoint, expenseData);

      if (response['status'] == true) {
        final singleExpenseResponse = SingleExpenseResponse.fromJson(response);
        return singleExpenseResponse;
      } else {
        throw Exception(
          response['message']?.toString() ?? 'Failed to create expense',
        );
      }
    } catch (e) {
      throw Exception('Failed to create expense: $e');
    }
  }

  // Update expense
  static Future<SingleExpenseResponse> updateExpense(
    int expenseId,
    Map<String, dynamic> expenseData,
  ) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.put(
        Uri.parse('${ApiService.baseUrl}$expensesEndpoint/$expenseId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(expenseData),
      );

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        if (decoded['status'] == true) {
          final singleExpenseResponse = SingleExpenseResponse.fromJson(decoded);
          return singleExpenseResponse;
        } else {
          throw Exception(decoded['message']?.toString() ?? 'Update failed');
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

  // Delete expense
  static Future<Map<String, dynamic>> deleteExpense(int expenseId) async {
    final token = await ApiService.getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.delete(
        Uri.parse('${ApiService.baseUrl}$expensesEndpoint/$expenseId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final decoded = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {'status': true, 'message': 'Expense deleted successfully'};
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

  // Get all expense categories
  static Future<ExpenseCategoriesResponse> getExpenseCategories() async {
    try {
      final response = await ApiService.get(expenseCategoriesEndpoint);

      if (response['status'] == true) {
        final categoriesResponse = ExpenseCategoriesResponse.fromJson(response);
        return categoriesResponse;
      } else {
        return ExpenseCategoriesResponse(
          status: false,
          message:
              response['message']?.toString() ??
              'Failed to load expense categories',
          data: [],
        );
      }
    } catch (e) {
      throw Exception('Failed to load expense categories: $e');
    }
  }

  // Get expense category by ID
  static Future<SingleExpenseCategoryResponse> getExpenseCategoryById(
    int categoryId,
  ) async {
    try {
      final response = await ApiService.get(
        '$expenseCategoriesEndpoint/$categoryId',
      );

      if (response['status'] == true) {
        final singleCategoryResponse = SingleExpenseCategoryResponse.fromJson(
          response,
        );
        return singleCategoryResponse;
      } else {
        throw Exception(
          response['message']?.toString() ?? 'Category not found',
        );
      }
    } catch (e) {
      throw Exception('Failed to load expense category: $e');
    }
  }

  // Create new expense category
  static Future<SingleExpenseCategoryResponse> createExpenseCategory(
    Map<String, dynamic> categoryData,
  ) async {
    try {
      final response = await ApiService.post(
        expenseCategoriesEndpoint,
        categoryData,
      );

      if (response['status'] == true) {
        final singleCategoryResponse = SingleExpenseCategoryResponse.fromJson(
          response,
        );
        return singleCategoryResponse;
      } else {
        throw Exception(
          response['message']?.toString() ??
              'Failed to create expense category',
        );
      }
    } catch (e) {
      throw Exception('Failed to create expense category: $e');
    }
  }

  // Update expense category
  static Future<SingleExpenseCategoryResponse> updateExpenseCategory(
    int categoryId,
    Map<String, dynamic> categoryData,
  ) async {
    try {
      final response = await ApiService.put(
        '$expenseCategoriesEndpoint/$categoryId',
        categoryData,
      );

      if (response['status'] == true) {
        final singleCategoryResponse = SingleExpenseCategoryResponse.fromJson(
          response,
        );
        return singleCategoryResponse;
      } else {
        throw Exception(
          response['message']?.toString() ??
              'Failed to update expense category',
        );
      }
    } catch (e) {
      throw Exception('Failed to update expense category: $e');
    }
  }

  // Delete expense category
  static Future<Map<String, dynamic>> deleteExpenseCategory(
    int categoryId,
  ) async {
    try {
      final response = await ApiService.delete(
        '$expenseCategoriesEndpoint/$categoryId',
      );

      if (response['status'] == true) {
        return response;
      } else {
        throw Exception(
          response['message']?.toString() ??
              'Failed to delete expense category',
        );
      }
    } catch (e) {
      throw Exception('Failed to delete expense category: $e');
    }
  }
}
