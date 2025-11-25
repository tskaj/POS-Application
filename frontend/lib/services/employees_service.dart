import 'services.dart';

// Employee model
class Employee {
  final int id;
  final String name;
  final String email;
  final String position;
  final String cnic;
  final String address;
  final String city;
  final int? cityId;
  final String cellNo1;
  final String cellNo2;
  final String status;
  final String createdAt;
  final String updatedAt;

  Employee({
    required this.id,
    required this.name,
    required this.email,
    required this.position,
    required this.cnic,
    required this.address,
    required this.city,
    this.cityId,
    required this.cellNo1,
    required this.cellNo2,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      id: json['id'] ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      position: json['position']?.toString() ?? '',
      cnic: json['cnic #: ']?.toString() ?? '',
      address: json['address']?.toString() ?? '',
      city: json['city'] is Map
          ? (json['city']['title']?.toString() ?? '')
          : json['city']?.toString() ?? '',
      cityId: json['city_id'] != null
          ? (int.tryParse(json['city_id'].toString()) ?? 0)
          : (json['city'] is Map && json['city']['id'] != null
                ? (int.tryParse(json['city']['id'].toString()) ?? 0)
                : null),
      cellNo1: json['cell_no1']?.toString() ?? '',
      cellNo2: json['cell_no2']?.toString() ?? 'N/A',
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at']?.toString() ?? '',
      updatedAt: json['updated_at']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'position': position,
      'cnic #: ': cnic,
      'address': address,
      'city': city,
      'city_id': cityId,
      'cell_no1': cellNo1,
      'cell_no2': cellNo2,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

// Response model for employees list
class EmployeesResponse {
  final List<Employee> data;

  EmployeesResponse({required this.data});

  factory EmployeesResponse.fromJson(Map<String, dynamic> json) {
    return EmployeesResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => Employee.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

// Employee Service
class EmployeeService {
  static const String employeesEndpoint = '/employees';

  static Future<EmployeesResponse> getEmployees() async {
    try {
      final response = await ApiService.get(employeesEndpoint);

      if (response.containsKey('data')) {
        return EmployeesResponse.fromJson(response);
      } else {
        return EmployeesResponse(data: []);
      }
    } catch (e) {
      throw Exception('Failed to load employees: $e');
    }
  }

  static Future<Employee> getEmployeeById(int id) async {
    try {
      final response = await ApiService.get('$employeesEndpoint/$id');

      if (response.containsKey('data')) {
        return Employee.fromJson(response['data']);
      } else {
        throw Exception('Employee data not found in response');
      }
    } catch (e) {
      throw Exception('Failed to load employee: $e');
    }
  }

  static Future<Employee> createEmployee(
    Map<String, dynamic> employeeData,
  ) async {
    try {
      final response = await ApiService.post(employeesEndpoint, employeeData);

      if (response.containsKey('data')) {
        return Employee.fromJson(response['data']);
      } else {
        throw Exception('Employee data not found in response');
      }
    } catch (e) {
      throw Exception('Failed to create employee: $e');
    }
  }

  static Future<Employee> updateEmployee(
    int id,
    Map<String, dynamic> employeeData,
  ) async {
    try {
      final response = await ApiService.put(
        '$employeesEndpoint/$id',
        employeeData,
      );

      if (response.containsKey('data')) {
        return Employee.fromJson(response['data']);
      } else {
        throw Exception('Employee data not found in response');
      }
    } catch (e) {
      throw Exception('Failed to update employee: $e');
    }
  }

  static Future<void> deleteEmployee(int id) async {
    try {
      await ApiService.delete('$employeesEndpoint/$id');
    } catch (e) {
      throw Exception('Failed to delete employee: $e');
    }
  }
}
