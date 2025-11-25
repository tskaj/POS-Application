import 'services.dart';

// Data models for Payment API
class PayInResponse {
  final bool status;
  final String message;
  final PayInData data;

  PayInResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory PayInResponse.fromJson(Map<String, dynamic> json) {
    return PayInResponse(
      status: json['status'] ?? false,
      message: json['message']?.toString() ?? '',
      data: PayInData.fromJson(json['data'] ?? {}),
    );
  }
}

class PayInData {
  final PayIn payIn;
  final List<Transaction> transactions;

  PayInData({required this.payIn, required this.transactions});

  factory PayInData.fromJson(Map<String, dynamic> json) {
    return PayInData(
      payIn: PayIn.fromJson(json['pay_in'] ?? {}),
      transactions:
          (json['transactions'] as List<dynamic>?)
              ?.map((item) => Transaction.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class PayIn {
  final String date;
  final int transactionTypesId;
  final int coasId;
  final int usersId;
  final String naration;
  final String description;
  final double amount;
  final String updatedAt;
  final String createdAt;
  final int id;

  PayIn({
    required this.date,
    required this.transactionTypesId,
    required this.coasId,
    required this.usersId,
    required this.naration,
    required this.description,
    required this.amount,
    required this.updatedAt,
    required this.createdAt,
    required this.id,
  });

  factory PayIn.fromJson(Map<String, dynamic> json) {
    return PayIn(
      date: json['date']?.toString() ?? '',
      transactionTypesId: json['transaction_types_id'] ?? 0,
      coasId: json['coas_id'] ?? 0,
      usersId: json['users_id'] ?? 0,
      naration: json['naration']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      amount: double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0,
      updatedAt: json['updated_at']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      id: json['id'] ?? 0,
    );
  }
}

class Transaction {
  final String date;
  final int transactionTypesId;
  final int invRefId;
  final int coasId;
  final int coaRefId;
  final String description;
  final double debit;
  final double credit;
  final int usersId;
  final String updatedAt;
  final String createdAt;
  final int id;

  Transaction({
    required this.date,
    required this.transactionTypesId,
    required this.invRefId,
    required this.coasId,
    required this.coaRefId,
    required this.description,
    required this.debit,
    required this.credit,
    required this.usersId,
    required this.updatedAt,
    required this.createdAt,
    required this.id,
  });

  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      date: json['date']?.toString() ?? '',
      transactionTypesId: json['transaction_types_id'] ?? 0,
      invRefId: json['invRef_id'] ?? 0,
      coasId: json['coas_id'] ?? 0,
      coaRefId: json['coaRef_id'] ?? 0,
      description: json['description']?.toString() ?? '',
      debit: double.tryParse(json['debit']?.toString() ?? '0') ?? 0.0,
      credit: double.tryParse(json['credit']?.toString() ?? '0') ?? 0.0,
      usersId: json['users_id'] ?? 0,
      updatedAt: json['updated_at']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      id: json['id'] ?? 0,
    );
  }
}

class PaymentService {
  // Create new payment/income
  static Future<PayInResponse> createPayment(
    Map<String, dynamic> paymentData,
  ) async {
    try {
      final response = await ApiService.post('/incomes', paymentData);

      if (response['status'] == true) {
        final payInResponse = PayInResponse.fromJson(response);
        return payInResponse;
      } else {
        throw Exception(
          response['message']?.toString() ?? 'Failed to create payment',
        );
      }
    } catch (e) {
      throw Exception('Failed to create payment: $e');
    }
  }
}
