import 'services.dart';

// Transaction data models
class TransactionEntry {
  final int tranId;
  final String date;
  final String description;
  final String debit;
  final String credit;
  final double balance;

  TransactionEntry({
    required this.tranId,
    required this.date,
    required this.description,
    required this.debit,
    required this.credit,
    required this.balance,
  });

  factory TransactionEntry.fromJson(Map<String, dynamic> json) {
    return TransactionEntry(
      tranId: json['tran_id'] ?? 0,
      date: json['date']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      debit: json['debit']?.toString() ?? '0.00',
      credit: json['credit']?.toString() ?? '0.00',
      balance: double.tryParse(json['balance']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class TransactionSummary {
  final String description;
  final double debit;
  final double credit;
  final double closingBalance;

  TransactionSummary({
    required this.description,
    required this.debit,
    required this.credit,
    required this.closingBalance,
  });

  factory TransactionSummary.fromJson(Map<String, dynamic> json) {
    return TransactionSummary(
      description: json['description']?.toString() ?? 'Summary',
      debit: double.tryParse(json['debit']?.toString() ?? '0') ?? 0.0,
      credit: double.tryParse(json['credit']?.toString() ?? '0') ?? 0.0,
      closingBalance:
          double.tryParse(json['closing_balance']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class DailyTransactionReport {
  final String from;
  final String to;
  final String openingBalance;
  final List<TransactionEntry> transactions;
  final TransactionSummary summary;

  DailyTransactionReport({
    required this.from,
    required this.to,
    required this.openingBalance,
    required this.transactions,
    required this.summary,
  });

  factory DailyTransactionReport.fromJson(Map<String, dynamic> json) {
    var transactionsJson = json['transactions'] as List? ?? [];
    List<TransactionEntry> transactions = transactionsJson
        .map((item) => TransactionEntry.fromJson(item))
        .toList();

    var summaryJson = json['summary'] as Map<String, dynamic>? ?? {};

    return DailyTransactionReport(
      from: json['from']?.toString() ?? '',
      to: json['to']?.toString() ?? '',
      openingBalance: json['opening_balance']?.toString() ?? '0.00',
      transactions: transactions,
      summary: TransactionSummary.fromJson(summaryJson),
    );
  }
}

class TransactionService {
  static const String baseEndpoint = '/transactions';

  /// Get transactions for a date range
  static Future<DailyTransactionReport> getTransactionsByDateRange({
    required String startDate,
    required String endDate,
  }) async {
    try {
      final response = await ApiService.get(
        '$baseEndpoint/date-range?start_date=$startDate&end_date=$endDate',
      );

      if (response['status'] == true && response['data'] != null) {
        return DailyTransactionReport.fromJson(response['data']);
      } else {
        throw Exception(response['message'] ?? 'Failed to load transactions');
      }
    } catch (e) {
      print('Error fetching transactions: $e');
      rethrow;
    }
  }
}
