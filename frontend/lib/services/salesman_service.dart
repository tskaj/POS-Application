import '../services/services.dart';

// Salesman model matching API
class Salesman {
  final int id;
  final String name;
  final String email;
  final String position;
  final String cnic;
  final String address;
  final String city;
  final String cellNo1;
  final String? cellNo2;
  final String status;
  final String createdAt;
  final String updatedAt;

  Salesman({
    required this.id,
    required this.name,
    required this.email,
    required this.position,
    required this.cnic,
    required this.address,
    required this.city,
    required this.cellNo1,
    this.cellNo2,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Salesman.fromJson(Map<String, dynamic> json) {
    return Salesman(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      position: json['position']?.toString() ?? '',
      cnic: (json['cnic #'] ?? json['cnic'] ?? '').toString(),
      address: json['address']?.toString() ?? '',
      city: json['city']?.toString() ?? '',
      cellNo1: json['cell_no1']?.toString() ?? '',
      cellNo2: json['cell_no2']?.toString(),
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }
}

class SalesmanResponse {
  final List<Salesman> data;

  SalesmanResponse({required this.data});

  factory SalesmanResponse.fromJson(Map<String, dynamic> json) {
    return SalesmanResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((e) => Salesman.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

class SalesmanService {
  static const String endpoint = '/allSalesman';

  static Future<SalesmanResponse> getAllSalesmen() async {
    try {
      final resp = await ApiService.get(endpoint);
      if (resp.containsKey('data')) {
        return SalesmanResponse.fromJson(resp);
      }
      return SalesmanResponse(data: []);
    } catch (e) {
      throw Exception('Failed to load salesmen: $e');
    }
  }

  /// Fetch detailed salesman report by id
  /// GET /api/pos/salesman/{id}
  static Future<SalesmanDetail> getSalesmanDetail(int id) async {
    try {
      final resp = await ApiService.get('/pos/salesman/$id');
      if (resp.containsKey('status') && resp['status'] == true) {
        return SalesmanDetail.fromJson(resp);
      }
      throw Exception('Failed to fetch salesman detail');
    } catch (e) {
      throw Exception('Failed to fetch salesman detail: $e');
    }
  }
}

class SalesmanDetail {
  final Map<String, dynamic> summary;
  final List<Map<String, dynamic>> data;

  SalesmanDetail({required this.summary, required this.data});

  factory SalesmanDetail.fromJson(Map<String, dynamic> json) {
    final summary = (json['summary'] as Map<String, dynamic>?) ?? {};
    final data =
        (json['data'] as List<dynamic>?)
            ?.map((e) => (e as Map<String, dynamic>))
            .toList() ??
        [];
    return SalesmanDetail(summary: summary, data: data);
  }
}
