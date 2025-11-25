import 'services.dart';

// Data models for Income API
class IncomeCategory {
  final int id;
  final String incomeCategory;
  final String date;

  IncomeCategory({
    required this.id,
    required this.incomeCategory,
    required this.date,
  });

  factory IncomeCategory.fromJson(Map<String, dynamic> json) {
    return IncomeCategory(
      id: json['id'] ?? 0,
      incomeCategory: json['income_category']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'income_category': incomeCategory, 'date': date};
  }
}

class IncomeCategoriesResponse {
  final bool status;
  final String message;
  final List<IncomeCategory> data;

  IncomeCategoriesResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory IncomeCategoriesResponse.fromJson(Map<String, dynamic> json) {
    return IncomeCategoriesResponse(
      status: json['status'] ?? false,
      message: json['message']?.toString() ?? '',
      data:
          (json['data'] as List<dynamic>?)
              ?.map((category) => IncomeCategory.fromJson(category))
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

class SingleIncomeCategoryResponse {
  final bool status;
  final String message;
  final IncomeCategory data;

  SingleIncomeCategoryResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory SingleIncomeCategoryResponse.fromJson(Map<String, dynamic> json) {
    return SingleIncomeCategoryResponse(
      status: json['status'] ?? false,
      message: json['message']?.toString() ?? '',
      data: IncomeCategory.fromJson(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {'status': status, 'message': message, 'data': data.toJson()};
  }
}

class DeleteResponse {
  final bool status;
  final String message;

  DeleteResponse({required this.status, required this.message});

  factory DeleteResponse.fromJson(Map<String, dynamic> json) {
    return DeleteResponse(
      status: json['status'] ?? false,
      message: json['message']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {'status': status, 'message': message};
  }
}

class Income {
  final int id;
  final String transactionTypeId;
  final String date;
  final String incomeCategoryId;
  final String incomeCategoryName;
  final String notes;
  final double amount;

  Income({
    required this.id,
    required this.transactionTypeId,
    required this.date,
    required this.incomeCategoryId,
    required this.incomeCategoryName,
    required this.notes,
    required this.amount,
  });

  factory Income.fromJson(Map<String, dynamic> json) {
    return Income(
      id: json['id'] ?? 0,
      transactionTypeId: json['transaction_type_id']?.toString() ?? '',
      date: json['date']?.toString() ?? '',
      incomeCategoryId: json['income_category_id']?.toString() ?? '',
      incomeCategoryName: json['income_category_name']?.toString() ?? '',
      notes: json['notes']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'transaction_type_id': transactionTypeId,
      'date': date,
      'income_category_id': incomeCategoryId,
      'income_category_name': incomeCategoryName,
      'notes': notes,
      'amount': amount,
    };
  }
}

class IncomesResponse {
  final bool status;
  final List<Income> data;

  IncomesResponse({required this.status, required this.data});

  factory IncomesResponse.fromJson(Map<String, dynamic> json) {
    return IncomesResponse(
      status: json['status'] ?? false,
      data:
          (json['data'] as List<dynamic>?)
              ?.map((income) => Income.fromJson(income))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'data': data.map((income) => income.toJson()).toList(),
    };
  }
}

class SingleIncomeResponse {
  final bool status;
  final String message;
  final Income data;

  SingleIncomeResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory SingleIncomeResponse.fromJson(Map<String, dynamic> json) {
    return SingleIncomeResponse(
      status: json['status'] ?? false,
      message: json['message']?.toString() ?? '',
      data: Income.fromJson(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {'status': status, 'message': message, 'data': data.toJson()};
  }
}

class IncomeService {
  // Get all income categories
  static Future<IncomeCategoriesResponse> getIncomeCategories() async {
    try {
      final response = await ApiService.get('/income-categories');

      if (response['status'] == true) {
        final categoriesResponse = IncomeCategoriesResponse.fromJson(response);
        return categoriesResponse;
      } else {
        return IncomeCategoriesResponse(
          status: false,
          message:
              response['message']?.toString() ??
              'Failed to load income categories',
          data: [],
        );
      }
    } catch (e) {
      throw Exception('Failed to load income categories: $e');
    }
  }

  // Create new income category
  static Future<SingleIncomeCategoryResponse> createIncomeCategory(
    Map<String, dynamic> categoryData,
  ) async {
    try {
      final response = await ApiService.post(
        '/income-categories',
        categoryData,
      );

      if (response['status'] == true) {
        final singleCategoryResponse = SingleIncomeCategoryResponse.fromJson(
          response,
        );
        return singleCategoryResponse;
      } else {
        throw Exception(
          response['message']?.toString() ?? 'Failed to create income category',
        );
      }
    } catch (e) {
      throw Exception('Failed to create income category: $e');
    }
  }

  // Get income category by ID
  static Future<SingleIncomeCategoryResponse> getIncomeCategoryById(
    int categoryId,
  ) async {
    try {
      final response = await ApiService.get('/income-categories/$categoryId');

      if (response['status'] == true) {
        final singleCategoryResponse = SingleIncomeCategoryResponse.fromJson(
          response,
        );
        return singleCategoryResponse;
      } else {
        throw Exception(
          response['message']?.toString() ?? 'Income category not found',
        );
      }
    } catch (e) {
      throw Exception('Failed to load income category: $e');
    }
  }

  // Update income category
  static Future<SingleIncomeCategoryResponse> updateIncomeCategory(
    int categoryId,
    Map<String, dynamic> categoryData,
  ) async {
    try {
      final response = await ApiService.put(
        '/income-categories/$categoryId',
        categoryData,
      );

      if (response['status'] == true) {
        final singleCategoryResponse = SingleIncomeCategoryResponse.fromJson(
          response,
        );
        return singleCategoryResponse;
      } else {
        throw Exception(
          response['message']?.toString() ?? 'Failed to update income category',
        );
      }
    } catch (e) {
      throw Exception('Failed to update income category: $e');
    }
  }

  // Delete income category
  static Future<DeleteResponse> deleteIncomeCategory(int categoryId) async {
    try {
      final response = await ApiService.delete(
        '/income-categories/$categoryId',
      );

      if (response['status'] == true) {
        return DeleteResponse.fromJson(response);
      } else {
        throw Exception(
          response['message']?.toString() ?? 'Failed to delete income category',
        );
      }
    } catch (e) {
      throw Exception('Failed to delete income category: $e');
    }
  }

  // Get all incomes
  static Future<IncomesResponse> getIncomes() async {
    try {
      final response = await ApiService.get('/incomes');

      if (response['status'] == true) {
        final incomesResponse = IncomesResponse.fromJson(response);
        return incomesResponse;
      } else {
        return IncomesResponse(status: false, data: []);
      }
    } catch (e) {
      throw Exception('Failed to load incomes: $e');
    }
  }

  // Create new income
  static Future<SingleIncomeResponse> createIncome(
    Map<String, dynamic> incomeData,
  ) async {
    try {
      final response = await ApiService.post('/incomes', incomeData);

      if (response['status'] == true) {
        final singleIncomeResponse = SingleIncomeResponse.fromJson(response);
        return singleIncomeResponse;
      } else {
        throw Exception(
          response['message']?.toString() ?? 'Failed to create income',
        );
      }
    } catch (e) {
      throw Exception('Failed to create income: $e');
    }
  }

  // Get income by ID
  static Future<SingleIncomeResponse> getIncomeById(int incomeId) async {
    try {
      final response = await ApiService.get('/incomes/$incomeId');

      if (response['status'] == true) {
        final singleIncomeResponse = SingleIncomeResponse.fromJson(response);
        return singleIncomeResponse;
      } else {
        throw Exception(response['message']?.toString() ?? 'Income not found');
      }
    } catch (e) {
      throw Exception('Failed to load income: $e');
    }
  }

  // Update income
  static Future<SingleIncomeResponse> updateIncome(
    int incomeId,
    Map<String, dynamic> incomeData,
  ) async {
    try {
      final response = await ApiService.put('/incomes/$incomeId', incomeData);

      if (response['status'] == true) {
        final singleIncomeResponse = SingleIncomeResponse.fromJson(response);
        return singleIncomeResponse;
      } else {
        throw Exception(
          response['message']?.toString() ?? 'Failed to update income',
        );
      }
    } catch (e) {
      throw Exception('Failed to update income: $e');
    }
  }

  // Delete income
  static Future<DeleteResponse> deleteIncome(int incomeId) async {
    try {
      final response = await ApiService.delete('/incomes/$incomeId');

      if (response['status'] == true) {
        return DeleteResponse.fromJson(response);
      } else {
        throw Exception(
          response['message']?.toString() ?? 'Failed to delete income',
        );
      }
    } catch (e) {
      throw Exception('Failed to delete income: $e');
    }
  }

  // Get all pay-ins (uses the same /incomes endpoint)
  static Future<PayInResponse> getPayIns() async {
    try {
      final response = await ApiService.get('/incomes');

      if (response['status'] == true) {
        final payInsResponse = PayInResponse.fromJson(response);
        return payInsResponse;
      } else {
        return PayInResponse(
          status: false,
          message: 'Failed to load pay-ins',
          data: [],
        );
      }
    } catch (e) {
      throw Exception('Failed to load pay-ins: $e');
    }
  }

  // Get pay-in by ID (uses the same /incomes/{id} endpoint)
  static Future<SinglePayInResponse> getPayInById(int payInId) async {
    try {
      final response = await ApiService.get('/incomes/$payInId');

      if (response['status'] == true) {
        final singlePayInResponse = SinglePayInResponse.fromJson(response);
        return singlePayInResponse;
      } else {
        throw Exception(response['message']?.toString() ?? 'Pay-in not found');
      }
    } catch (e) {
      throw Exception('Failed to load pay-in: $e');
    }
  }
}

// Add the missing response classes for PayIn
class SinglePayInResponse {
  final bool status;
  final String message;
  final PayIn data;

  SinglePayInResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory SinglePayInResponse.fromJson(Map<String, dynamic> json) {
    return SinglePayInResponse(
      status: json['status'] ?? false,
      message: json['message']?.toString() ?? '',
      data: PayIn.fromJson(json['data'] ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {'status': status, 'message': message, 'data': data.toJson()};
  }
}

// PayIn model and response classes (moved from payin_page.dart for consistency)
class PayIn {
  final int id;
  final String date;
  final String transactionTypesId;
  final String coasId;
  final String usersId;
  final String naration;
  final String description;
  final String amount;
  final String createdAt;
  final String updatedAt;
  final TransactionType transactionType;
  final Coa coa;
  final User user;

  PayIn({
    required this.id,
    required this.date,
    required this.transactionTypesId,
    required this.coasId,
    required this.usersId,
    required this.naration,
    required this.description,
    required this.amount,
    required this.createdAt,
    required this.updatedAt,
    required this.transactionType,
    required this.coa,
    required this.user,
  });

  factory PayIn.fromJson(Map<String, dynamic> json) {
    return PayIn(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      transactionTypesId: json['transaction_types_id']?.toString() ?? '',
      coasId: json['coas_id']?.toString() ?? '',
      usersId: json['users_id']?.toString() ?? '',
      naration: json['naration'] ?? '',
      description: json['description'] ?? '',
      amount: json['amount']?.toString() ?? '0.00',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      transactionType: TransactionType.fromJson(json['transaction_type'] ?? {}),
      coa: Coa.fromJson(json['coa'] ?? {}),
      user: User.fromJson(json['user'] ?? {}),
    );
  }

  double get amountValue => double.tryParse(amount) ?? 0.0;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'date': date,
      'transaction_types_id': transactionTypesId,
      'coas_id': coasId,
      'users_id': usersId,
      'naration': naration,
      'description': description,
      'amount': amount,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'transaction_type': transactionType.toJson(),
      'coa': coa.toJson(),
      'user': user.toJson(),
    };
  }
}

class TransactionType {
  final int id;
  final String transType;
  final String code;
  final String createdAt;
  final String updatedAt;

  TransactionType({
    required this.id,
    required this.transType,
    required this.code,
    required this.createdAt,
    required this.updatedAt,
  });

  factory TransactionType.fromJson(Map<String, dynamic> json) {
    return TransactionType(
      id: json['id'] ?? 0,
      transType: json['transType'] ?? '',
      code: json['code'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
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

class Coa {
  final int id;
  final String coaSubId;
  final String code;
  final String title;
  final String type;
  final String status;
  final String createdAt;
  final String updatedAt;

  Coa({
    required this.id,
    required this.coaSubId,
    required this.code,
    required this.title,
    required this.type,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Coa.fromJson(Map<String, dynamic> json) {
    return Coa(
      id: json['id'] ?? 0,
      coaSubId: json['coa_sub_id']?.toString() ?? '',
      code: json['code'] ?? '',
      title: json['title'] ?? '',
      type: json['type'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'coa_sub_id': coaSubId,
      'code': code,
      'title': title,
      'type': type,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class User {
  final int id;
  final String firstName;
  final String lastName;
  final String email;
  final String? cellNo1;
  final String? cellNo2;
  final String? imgPath;
  final String roleId;
  final String? emailVerifiedAt;
  final String status;
  final String createdAt;
  final String updatedAt;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.cellNo1,
    this.cellNo2,
    this.imgPath,
    required this.roleId,
    this.emailVerifiedAt,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      email: json['email'] ?? '',
      cellNo1: json['cell_no1'],
      cellNo2: json['cell_no2'],
      imgPath: json['img_path'],
      roleId: json['role_id']?.toString() ?? '',
      emailVerifiedAt: json['email_verified_at'],
      status: json['status'] ?? 'active',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  String get fullName => '$firstName $lastName';

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'first_name': firstName,
      'last_name': lastName,
      'email': email,
      'cell_no1': cellNo1,
      'cell_no2': cellNo2,
      'img_path': imgPath,
      'role_id': roleId,
      'email_verified_at': emailVerifiedAt,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class PayInResponse {
  final bool status;
  final String message;
  final List<PayIn> data;

  PayInResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory PayInResponse.fromJson(Map<String, dynamic> json) {
    return PayInResponse(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => PayIn.fromJson(item))
              .toList() ??
          [],
    );
  }
}
