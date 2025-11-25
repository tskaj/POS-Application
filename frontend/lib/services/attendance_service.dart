import 'services.dart';

class AttendanceRecord {
  final int id;
  final int employeeId;
  final String date;
  final String checkIn;
  final String checkOut;
  final String status;
  final String remarks;

  AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.checkIn,
    required this.checkOut,
    required this.status,
    required this.remarks,
  });

  factory AttendanceRecord.fromJson(
    Map<String, dynamic> json, {
    int? employeeId,
  }) {
    return AttendanceRecord(
      id: json['id'] ?? 0,
      employeeId: employeeId ?? json['employee_id'] ?? 0,
      date: json['date'] ?? '',
      checkIn: json['check_in'] ?? '',
      checkOut: json['check_out'] ?? '',
      status: json['status'] ?? '',
      remarks: json['remarks'] ?? '-',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_id': employeeId,
      'date': date,
      'check_in': checkIn,
      'check_out': checkOut,
      'status': status,
      'remarks': remarks,
    };
  }
}

class EmployeeWithAttendance {
  final int id;
  final String employeeName;
  final String email;
  final String cnic;
  final String role;
  final String city;
  final String status;
  final List<AttendanceRecord> attendances;

  EmployeeWithAttendance({
    required this.id,
    required this.employeeName,
    required this.email,
    required this.cnic,
    required this.role,
    required this.city,
    required this.status,
    required this.attendances,
  });

  factory EmployeeWithAttendance.fromJson(Map<String, dynamic> json) {
    final employeeId = json['id'] ?? 0;
    return EmployeeWithAttendance(
      id: employeeId,
      employeeName: json['employee_name'] ?? '',
      email: json['email'] ?? '',
      cnic: json['cnic'] ?? '',
      role: json['role'] ?? '',
      city: json['city'] ?? '',
      status: json['status'] ?? '',
      attendances:
          (json['attendances'] as List<dynamic>?)
              ?.map(
                (a) => AttendanceRecord.fromJson(
                  a as Map<String, dynamic>,
                  employeeId: employeeId,
                ),
              )
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'employee_name': employeeName,
      'email': email,
      'cnic': cnic,
      'role': role,
      'city': city,
      'status': status,
      'attendances': attendances.map((a) => a.toJson()).toList(),
    };
  }
}

class AttendanceService {
  /// Get all employees with their attendance records
  Future<List<EmployeeWithAttendance>> getAllAttendances() async {
    try {
      final response = await ApiService.get('/attendances/all');

      if (response['success'] == true || response['status'] == true) {
        final List<dynamic> data = response['data'] ?? [];
        return data
            .map(
              (json) =>
                  EmployeeWithAttendance.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      } else {
        throw Exception(response['message'] ?? 'Failed to fetch attendances');
      }
    } catch (e) {
      throw Exception('Error fetching attendances: $e');
    }
  }

  /// Get attendance records for a specific employee from loaded data
  List<AttendanceRecord> getEmployeeAttendancesFromList(
    List<EmployeeWithAttendance> allData,
    int employeeId,
  ) {
    final employee = allData.firstWhere(
      (emp) => emp.id == employeeId,
      orElse: () => EmployeeWithAttendance(
        id: 0,
        employeeName: '',
        email: '',
        cnic: '',
        role: '',
        city: '',
        status: '',
        attendances: [],
      ),
    );
    return employee.attendances;
  }

  /// Filter attendances by date range
  List<AttendanceRecord> filterByDateRange(
    List<AttendanceRecord> attendances,
    DateTime startDate,
    DateTime endDate,
  ) {
    return attendances.where((attendance) {
      try {
        final date = DateTime.parse(attendance.date);
        return date.isAfter(startDate.subtract(Duration(days: 1))) &&
            date.isBefore(endDate.add(Duration(days: 1)));
      } catch (e) {
        return false;
      }
    }).toList();
  }

  /// Filter attendances by status
  List<AttendanceRecord> filterByStatus(
    List<AttendanceRecord> attendances,
    String status,
  ) {
    return attendances
        .where(
          (attendance) =>
              attendance.status.toLowerCase() == status.toLowerCase(),
        )
        .toList();
  }

  /// Create attendance for an employee
  Future<Map<String, dynamic>> createAttendance({
    required int employeeId,
    required String date,
    required String checkIn,
    required String checkOut,
    required String status,
    String? remarks,
  }) async {
    try {
      final attendanceData = {
        'date': date,
        'check_in': checkIn,
        'check_out': checkOut,
        'status': status.toLowerCase(),
        'remarks': remarks ?? '',
      };

      final response = await ApiService.post(
        '/employees/$employeeId/attendances',
        attendanceData,
      );

      if (response['success'] == true || response['status'] == true) {
        return response;
      } else {
        throw Exception(response['message'] ?? 'Failed to create attendance');
      }
    } catch (e) {
      throw Exception('Error creating attendance: $e');
    }
  }

  /// Get employee attendances (for view)
  Future<EmployeeWithAttendance> getEmployeeAttendances(int employeeId) async {
    try {
      final response = await ApiService.get(
        '/employees/$employeeId/attendances',
      );

      if (response['success'] == true || response['status'] == true) {
        final data = response['data'];
        return EmployeeWithAttendance.fromJson(data as Map<String, dynamic>);
      } else {
        throw Exception(
          response['message'] ?? 'Failed to fetch employee attendances',
        );
      }
    } catch (e) {
      throw Exception('Error fetching employee attendances: $e');
    }
  }

  /// Update attendance for an employee
  Future<Map<String, dynamic>> updateAttendance({
    required int employeeId,
    required int attendanceId,
    required String date,
    required String checkIn,
    required String checkOut,
    required String status,
    String? remarks,
  }) async {
    try {
      final attendanceData = {
        'date': date,
        'check_in': checkIn,
        'check_out': checkOut,
        'status': status.toLowerCase(),
        'remarks': remarks ?? '',
      };

      final response = await ApiService.put(
        '/employees/$employeeId/attendances/$attendanceId',
        attendanceData,
      );

      if (response['success'] == true || response['status'] == true) {
        return response;
      } else {
        throw Exception(response['message'] ?? 'Failed to update attendance');
      }
    } catch (e) {
      throw Exception('Error updating attendance: $e');
    }
  }

  /// Delete attendance for an employee
  Future<Map<String, dynamic>> deleteAttendance({
    required int employeeId,
    required int attendanceId,
  }) async {
    try {
      final response = await ApiService.delete(
        '/employees/$employeeId/attendances/$attendanceId',
      );

      if (response['success'] == true || response['status'] == true) {
        return response;
      } else {
        throw Exception(response['message'] ?? 'Failed to delete attendance');
      }
    } catch (e) {
      throw Exception('Error deleting attendance: $e');
    }
  }
}
