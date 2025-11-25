import 'services.dart';

// Data models for Payout API
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
      // API may return the transaction type under 'name' or 'transType'
      transType:
          json['transType']?.toString() ?? json['name']?.toString() ?? '',
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

class Coa {
  final int id;
  final String coaSubId;
  final String code;
  final String title;
  final String type;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  Coa({
    required this.id,
    required this.coaSubId,
    required this.code,
    required this.title,
    required this.type,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory Coa.fromJson(Map<String, dynamic> json) {
    return Coa(
      id: json['id'] ?? 0,
      coaSubId: json['coa_sub_id']?.toString() ?? '',
      // Some API responses omit 'code' and only provide 'title' (or id).
      code: json['code']?.toString() ?? json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
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
  final String cellNo1;
  final String? cellNo2;
  final String? imgPath;
  final String roleId;
  final String? emailVerifiedAt;
  final String? twoFactorSecret;
  final String? twoFactorRecoveryCodes;
  final String? twoFactorConfirmedAt;
  final String status;
  final String? createdAt;
  final String? updatedAt;

  User({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.cellNo1,
    this.cellNo2,
    this.imgPath,
    required this.roleId,
    this.emailVerifiedAt,
    this.twoFactorSecret,
    this.twoFactorRecoveryCodes,
    this.twoFactorConfirmedAt,
    required this.status,
    this.createdAt,
    this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] ?? 0,
      // API may return a single 'name' field instead of first_name/last_name
      firstName:
          json['first_name']?.toString() ?? json['name']?.toString() ?? '',
      lastName:
          json['last_name']?.toString() ??
          (json['name'] is String
              ? (json['name'].toString().contains(' ')
                    ? json['name'].toString().split(' ').skip(1).join(' ')
                    : '')
              : ''),
      email: json['email']?.toString() ?? '',
      cellNo1: json['cell_no1']?.toString() ?? '',
      cellNo2: json['cell_no2'],
      imgPath: json['img_path'],
      roleId: json['role_id']?.toString() ?? '',
      emailVerifiedAt: json['email_verified_at'],
      twoFactorSecret: json['two_factor_secret'],
      twoFactorRecoveryCodes: json['two_factor_recovery_codes'],
      twoFactorConfirmedAt: json['two_factor_confirmed_at'],
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

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
      'two_factor_secret': twoFactorSecret,
      'two_factor_recovery_codes': twoFactorRecoveryCodes,
      'two_factor_confirmed_at': twoFactorConfirmedAt,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }

  String get fullName => '$firstName $lastName'.trim();
}

class Payout {
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

  Payout({
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

  factory Payout.fromJson(Map<String, dynamic> json) {
    return Payout(
      id: json['id'] ?? 0,
      date: json['date']?.toString() ?? '',
      transactionTypesId: json['transaction_types_id']?.toString() ?? '',
      coasId: json['coas_id']?.toString() ?? '',
      usersId: json['users_id']?.toString() ?? '',
      naration: json['naration']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      amount: json['amount']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
      transactionType: TransactionType.fromJson(json['transaction_type'] ?? {}),
      coa: Coa.fromJson(json['coa'] ?? {}),
      user: User.fromJson(json['user'] ?? {}),
    );
  }

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

  double get amountAsDouble => double.tryParse(amount) ?? 0.0;
}

class PayoutResponse {
  final bool status;
  final String message;
  final List<Payout> data;

  PayoutResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory PayoutResponse.fromJson(Map<String, dynamic> json) {
    return PayoutResponse(
      status: json['status'] ?? false,
      message: json['message']?.toString() ?? '',
      data:
          (json['data'] as List<dynamic>?)
              ?.map((payout) => Payout.fromJson(payout))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'status': status,
      'message': message,
      'data': data.map((payout) => payout.toJson()).toList(),
    };
  }
}

class PayoutService {
  static const String payoutsEndpoint = '/expenses';

  // Get all payouts with pagination support
  static Future<PayoutResponse> getPayouts({
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final response = await ApiService.get(
        '$payoutsEndpoint?page=$page&per_page=$perPage',
      );

      if (response['status'] == true) {
        final payoutResponse = PayoutResponse.fromJson(response);
        return payoutResponse;
      } else {
        return PayoutResponse(
          status: false,
          message: response['message']?.toString() ?? 'Failed to load payouts',
          data: [],
        );
      }
    } catch (e) {
      throw Exception('Failed to load payouts: $e');
    }
  }

  // Get all payouts by fetching all pages (for client-side caching)
  static Future<List<Payout>> getAllPayouts() async {
    try {
      List<Payout> allPayouts = [];
      int currentPage = 1;
      bool hasMorePages = true;

      while (hasMorePages) {
        final response = await getPayouts(page: currentPage, perPage: 100);

        if (response.status && response.data.isNotEmpty) {
          allPayouts.addAll(response.data);
          currentPage++;

          // If we got fewer results than requested, we've reached the last page
          if (response.data.length < 100) {
            hasMorePages = false;
          }
        } else {
          hasMorePages = false;
        }
      }

      return allPayouts;
    } catch (e) {
      throw Exception('Failed to load all payouts: $e');
    }
  }
}
