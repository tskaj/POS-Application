import '../services/services.dart';

// Data models for Account Statement API
class AccountStatementTransaction {
  // Support both old and new API shapes. Fields are normalized to strings for UI use.
  final int? transId;
  final String referenceNumber; // from 'reference_number' or 'inv_ref'
  final String date;
  final String code; // new API field
  final String title; // new API field (was category in older API)
  final String description;
  final String debit; // raw debit value
  final String credit; // raw credit value
  final String amount; // computed like '+credit' or '-debit' or from 'amount'
  final String transactionType; // 'Credit' or 'Debit' or from transaction_type
  final String balance;

  AccountStatementTransaction({
    this.transId,
    required this.referenceNumber,
    required this.date,
    required this.code,
    required this.title,
    required this.description,
    required this.debit,
    required this.credit,
    required this.amount,
    required this.transactionType,
    required this.balance,
  });

  factory AccountStatementTransaction.fromJson(Map<String, dynamic> json) {
    // New API returns fields like trans_id, inv_ref, debit, credit, code, title
    final transId = json['trans_id'] is int
        ? json['trans_id'] as int
        : (int.tryParse(json['trans_id']?.toString() ?? ''));
    final invRef = json['inv_ref']?.toString();
    final reference = json['reference_number']?.toString() ?? invRef ?? '';
    final date = json['date']?.toString() ?? '';
    final code = json['code']?.toString() ?? '';
    final title =
        json['title']?.toString() ?? json['category']?.toString() ?? '';
    final description = json['description']?.toString() ?? '';
    final debit =
        json['debit']?.toString() ?? json['debit_amount']?.toString() ?? '0.00';
    final credit =
        json['credit']?.toString() ??
        json['credit_amount']?.toString() ??
        '0.00';
    // Compute amount and transaction type when possible
    String amount;
    String transactionType;
    double dVal = double.tryParse(debit.replaceAll(',', '')) ?? 0.0;
    double cVal = double.tryParse(credit.replaceAll(',', '')) ?? 0.0;
    if (cVal > 0) {
      amount = '+${cVal.toStringAsFixed(2)}';
      transactionType = 'Credit';
    } else if (dVal > 0) {
      amount = '-${dVal.toStringAsFixed(2)}';
      transactionType = 'Debit';
    } else {
      amount = json['amount']?.toString() ?? '';
      transactionType = json['transaction_type']?.toString() ?? '';
    }

    final balance = json['balance']?.toString() ?? '';

    return AccountStatementTransaction(
      transId: transId,
      referenceNumber: reference,
      date: date,
      code: code,
      title: title,
      description: description,
      debit: debit,
      credit: credit,
      amount: amount,
      transactionType: transactionType,
      balance: balance,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'trans_id': transId,
      'reference_number': referenceNumber,
      'date': date,
      'code': code,
      'title': title,
      'description': description,
      'debit': debit,
      'credit': credit,
      'amount': amount,
      'transaction_type': transactionType,
      'balance': balance,
    };
  }
}

class AccountStatement {
  final String accountName;
  final String fromDate;
  final String toDate;
  final int openingBalance;
  final List<AccountStatementTransaction> transactions;

  AccountStatement({
    required this.accountName,
    required this.fromDate,
    required this.toDate,
    required this.openingBalance,
    required this.transactions,
  });

  factory AccountStatement.fromJson(Map<String, dynamic> json) {
    return AccountStatement(
      accountName: json['account_name']?.toString() ?? '',
      fromDate: json['from_date']?.toString() ?? '',
      toDate: json['to_date']?.toString() ?? '',
      openingBalance: json['opening_balance'] ?? 0,
      transactions:
          (json['transactions'] as List<dynamic>?)
              ?.map((item) => AccountStatementTransaction.fromJson(item))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'account_name': accountName,
      'from_date': fromDate,
      'to_date': toDate,
      'opening_balance': openingBalance,
      'transactions': transactions.map((t) => t.toJson()).toList(),
    };
  }
}

class AccountStatementResponse {
  final AccountStatement accountStatement;

  AccountStatementResponse({required this.accountStatement});

  factory AccountStatementResponse.fromJson(Map<String, dynamic> json) {
    return AccountStatementResponse(
      accountStatement: AccountStatement.fromJson(
        json['account_statement'] ?? {},
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {'account_statement': accountStatement.toJson()};
  }
}

// Model representing a single account entry returned by /accountStatementList
class AccountListItem {
  final int id;
  final String title;
  final String code;
  final String type;
  final String status;
  final Map<String, dynamic>? sub;
  final Map<String, dynamic>? main;
  final double balance;

  AccountListItem({
    required this.id,
    required this.title,
    required this.code,
    required this.type,
    required this.status,
    this.sub,
    this.main,
    required this.balance,
  });

  factory AccountListItem.fromJson(Map<String, dynamic> json) {
    return AccountListItem(
      id: json['id'] ?? 0,
      title: json['title']?.toString() ?? '',
      code: json['code']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      sub: json['sub'] is Map<String, dynamic>
          ? json['sub'] as Map<String, dynamic>
          : null,
      main: json['main'] is Map<String, dynamic>
          ? json['main'] as Map<String, dynamic>
          : null,
      balance: (json['balance'] is num)
          ? (json['balance'] as num).toDouble()
          : double.tryParse(json['balance']?.toString() ?? '') ?? 0.0,
    );
  }
}

class AccountStatementService {
  // Get account statement
  static Future<AccountStatementResponse> getAccountStatement() async {
    try {
      final response = await ApiService.get('/accountStatement');

      return AccountStatementResponse.fromJson(response);
    } catch (e) {
      throw Exception('Failed to load account statement: $e');
    }
  }

  // Get account statement list (chart of accounts / account list)
  // Endpoint: /accountStatementList -> returns { data: [ {id,title,code,type,status,sub,main,balance}, ... ] }
  static Future<List<AccountListItem>> getAccountStatementList() async {
    try {
      final response = await ApiService.get('/accountStatementList');

      final data = response['data'] as List<dynamic>? ?? [];
      return data
          .map((e) => AccountListItem.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Failed to load account statement list: $e');
    }
  }

  // Get account statement by ID
  static Future<AccountStatement> getAccountStatementById(int id) async {
    try {
      final response = await ApiService.get('/accountStatement/$id');

      final data = response['data'] as Map<String, dynamic>? ?? {};
      return AccountStatement.fromJson(data);
    } catch (e) {
      throw Exception('Failed to load account statement details: $e');
    }
  }
}
