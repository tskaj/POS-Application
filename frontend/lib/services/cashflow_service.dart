import 'dart:convert';
import 'package:http/http.dart' as http;
import 'services.dart'; // Import the main ApiService

// Cashflow model
class Cashflow {
  final int id;
  final String date;
  final String invRef;
  final String coasId;
  final String coaRefId;
  final String usersId;
  final String description;
  final String debit;
  final String credit;

  Cashflow({
    required this.id,
    required this.date,
    required this.invRef,
    required this.coasId,
    required this.coaRefId,
    required this.usersId,
    required this.description,
    required this.debit,
    required this.credit,
  });

  factory Cashflow.fromJson(Map<String, dynamic> json) {
    return Cashflow(
      id: json['id'] ?? 0,
      date: json['date'] ?? '',
      invRef: json['inv_ref'] ?? '',
      coasId: json['coas_id'] ?? '',
      coaRefId: json['coaRef_id'] ?? '',
      usersId: json['users_id'] ?? '',
      description: json['description'] ?? '',
      debit: json['debit'] ?? '0.00',
      credit: json['credit'] ?? '0.00',
    );
  }
}

// Cashflow response model
class CashflowResponse {
  final bool status;
  final String message;
  final List<Cashflow> data;

  CashflowResponse({
    required this.status,
    required this.message,
    required this.data,
  });

  factory CashflowResponse.fromJson(Map<String, dynamic> json) {
    return CashflowResponse(
      status: json['status'] ?? false,
      message: json['message'] ?? '',
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => Cashflow.fromJson(item))
              .toList() ??
          [],
    );
  }
}

class CashflowService {
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

      print('📡 CASHFLOW $method Response Status: ${response.statusCode}');
      print('📨 CASHFLOW $method Response Body: ${response.body}');

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final decoded = jsonDecode(response.body);
        print('📄 CASHFLOW $method Decoded Response: $decoded');
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          print(
            '⚠️ CASHFLOW $method Response is not a Map, returning empty Map',
          );
          return {};
        }
      } else if (response.statusCode == 401) {
        await ApiService.logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Cashflow API failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('💥 CASHFLOW $method error: $e');
      throw Exception('Network error: $e');
    }
  }

  // Get all cashflow data
  static Future<CashflowResponse> getAllCashflow() async {
    print('💰 CASHFLOW: Getting all cashflow data');
    final response = await _authenticatedRequest('GET', '/cashflow');

    return CashflowResponse.fromJson(response);
  }
}
