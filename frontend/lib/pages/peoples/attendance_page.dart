import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dhanpuri_by_get_going/services/attendance_service.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({super.key});

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final AttendanceService _attendanceService = AttendanceService();
  final TextEditingController _searchController = TextEditingController();

  // API data
  List<EmployeeWithAttendance> _allEmployeesData = [];
  List<AttendanceRecord> _allAttendanceRecords = [];
  List<AttendanceRecord> _filteredRecords = [];
  bool _isLoading = false;

  // Pagination
  int _currentPage = 1;
  int _itemsPerPage = 12;

  // Filters
  String _searchQuery = '';
  String _statusFilter = 'All';
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _fetchAttendances();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
      _currentPage = 1;
    });
    _applyFilters();
  }

  void _applyFilters() {
    setState(() {
      _filteredRecords = _allAttendanceRecords.where((record) {
        final employee = _getEmployeeForAttendance(record);
        if (employee == null) return false;

        // Search filter
        final matchesSearch =
            _searchQuery.isEmpty ||
            employee.employeeName.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            employee.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            'EMP${employee.id}'.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            );

        // Status filter
        final matchesStatus =
            _statusFilter == 'All' ||
            record.status.toLowerCase() == _statusFilter.toLowerCase();

        // Date filter
        bool matchesDate = true;
        if (_startDate != null || _endDate != null) {
          try {
            final recordDate = DateTime.parse(record.date);
            if (_startDate != null && recordDate.isBefore(_startDate!)) {
              matchesDate = false;
            }
            if (_endDate != null &&
                recordDate.isAfter(_endDate!.add(Duration(days: 1)))) {
              matchesDate = false;
            }
          } catch (e) {
            matchesDate = false;
          }
        }

        return matchesSearch && matchesStatus && matchesDate;
      }).toList();
    });
  }

  Future<void> _fetchAttendances() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final employeesData = await _attendanceService.getAllAttendances();

      // Flatten all attendance records from all employees
      List<AttendanceRecord> allRecords = [];

      for (var employee in employeesData) {
        allRecords.addAll(employee.attendances);
      }

      // Sort by date descending (newest first)
      allRecords.sort((a, b) {
        try {
          final dateA = DateTime.parse(a.date);
          final dateB = DateTime.parse(b.date);
          return dateB.compareTo(dateA);
        } catch (e) {
          return 0;
        }
      });

      setState(() {
        _allEmployeesData = employeesData;
        _allAttendanceRecords = allRecords;
        _filteredRecords = allRecords;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading attendances: $e'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  // Pagination helper
  List<AttendanceRecord> get _paginatedRecords {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = startIndex + _itemsPerPage;
    return _filteredRecords.sublist(
      startIndex,
      endIndex > _filteredRecords.length ? _filteredRecords.length : endIndex,
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Color(0xFF28A745);
      case 'absent':
        return Color(0xFFDC3545);
      case 'leave':
      case 'half-day':
        return Color(0xFFFFC107);
      case 'late':
        return Color(0xFFFF6B6B);
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Icons.check_circle;
      case 'absent':
        return Icons.cancel;
      case 'leave':
      case 'half-day':
        return Icons.event_note;
      case 'late':
        return Icons.access_time;
      default:
        return Icons.help;
    }
  }

  String _extractTimeFromDateTime(String dateTimeString) {
    try {
      // Try to parse as ISO 8601 datetime
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('HH:mm').format(dateTime);
    } catch (e) {
      // If parsing fails, assume it's already in HH:mm format
      return dateTimeString;
    }
  }

  // Helper method to find employee info for an attendance record
  EmployeeWithAttendance? _getEmployeeForAttendance(AttendanceRecord record) {
    for (var employee in _allEmployeesData) {
      if (employee.attendances.any((a) => a.id == record.id)) {
        return employee;
      }
    }
    return null;
  }

  // Show add attendance dialog
  void _showAddAttendanceDialog() {
    showDialog(
      context: context,
      builder: (context) => _AddAttendanceDialog(
        allEmployees: _allEmployeesData,
        onAttendanceAdded: (newAttendance) {
          // Refresh the list
          _fetchAttendances();
        },
      ),
    );
  }

  // View attendance details
  void _viewAttendance(AttendanceRecord record) {
    // Find employee by the record's employeeId
    final employee = _allEmployeesData.firstWhere(
      (emp) => emp.id == record.employeeId,
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

    if (employee.id == 0) return;

    showDialog(
      context: context,
      builder: (context) =>
          _ViewAttendanceDialog(employee: employee, attendance: record),
    );
  }

  // Edit attendance
  void _editAttendance(AttendanceRecord record) {
    // Find employee by the record's attendance id
    final employee = _getEmployeeForAttendance(record);
    if (employee == null) return;

    showDialog(
      context: context,
      builder: (context) => _EditAttendanceDialog(
        employee: employee,
        attendance: record,
        onAttendanceUpdated: (updatedAttendance) {
          // Refresh the list
          _fetchAttendances();
        },
      ),
    );
  }

  // Delete attendance
  Future<void> _deleteAttendance(AttendanceRecord record) async {
    final employee = _getEmployeeForAttendance(record);
    if (employee == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 12),
            Text('Confirm Delete'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete this attendance record for ${employee.employeeName} on ${DateFormat('MMM dd, yyyy').format(DateTime.parse(record.date))}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _attendanceService.deleteAttendance(
        employeeId: employee.id,
        attendanceId: record.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance deleted successfully'),
            backgroundColor: Colors.green,
          ),
        );
        _fetchAttendances();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting attendance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Management'),
        backgroundColor: const Color(0xFF0D1845),
        foregroundColor: Colors.white,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Colors.white, const Color(0xFFF8F9FA)],
          ),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF0D1845).withValues(alpha: 0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              margin: const EdgeInsets.fromLTRB(24, 12, 24, 16),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.access_time,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance Records',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Total Records: ${_filteredRecords.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _showAddAttendanceDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Attendance'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Color(0xFF0D1845),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar and Status Filter
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: Row(
                children: [
                  // Search Bar
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search by employee name, email, or ID...',
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 13,
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Colors.grey[400],
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isNotEmpty
                              ? IconButton(
                                  icon: Icon(
                                    Icons.clear,
                                    color: Colors.grey[400],
                                    size: 20,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                  },
                                )
                              : null,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Status Filter
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButton<String>(
                      value: _statusFilter,
                      underline: const SizedBox(),
                      icon: Icon(Icons.arrow_drop_down, size: 20),
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black87,
                      ),
                      items: ['All', 'Present', 'Absent', 'Late', 'Half-day']
                          .map((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          })
                          .toList(),
                      onChanged: (String? newValue) {
                        setState(() {
                          _statusFilter = newValue ?? 'All';
                          _currentPage = 1;
                        });
                        _applyFilters();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Date Filter
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        // Start Date
                        TextButton.icon(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _startDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: Color(0xFF0D1845),
                                      onPrimary: Colors.white,
                                      onSurface: Colors.black,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() {
                                _startDate = picked;
                                _currentPage = 1;
                              });
                              _applyFilters();
                            }
                          },
                          icon: Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            _startDate == null
                                ? 'Start Date'
                                : DateFormat('MMM dd').format(_startDate!),
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        Text('-', style: TextStyle(color: Colors.grey)),
                        // End Date
                        TextButton.icon(
                          onPressed: () async {
                            final DateTime? picked = await showDatePicker(
                              context: context,
                              initialDate: _endDate ?? DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                              builder: (context, child) {
                                return Theme(
                                  data: Theme.of(context).copyWith(
                                    colorScheme: ColorScheme.light(
                                      primary: Color(0xFF0D1845),
                                      onPrimary: Colors.white,
                                      onSurface: Colors.black,
                                    ),
                                  ),
                                  child: child!,
                                );
                              },
                            );
                            if (picked != null) {
                              setState(() {
                                _endDate = picked;
                                _currentPage = 1;
                              });
                              _applyFilters();
                            }
                          },
                          icon: Icon(Icons.calendar_today, size: 16),
                          label: Text(
                            _endDate == null
                                ? 'End Date'
                                : DateFormat('MMM dd').format(_endDate!),
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        if (_startDate != null || _endDate != null)
                          IconButton(
                            icon: Icon(Icons.clear, size: 18),
                            onPressed: () {
                              setState(() {
                                _startDate = null;
                                _endDate = null;
                                _currentPage = 1;
                              });
                              _applyFilters();
                            },
                            padding: EdgeInsets.zero,
                            constraints: BoxConstraints(),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Table
            Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.08),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Date',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Employee ID',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              'Employee Name',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Check-in Time',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Check-out Time',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Status',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Actions',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Body
                    Expanded(
                      child: _isLoading
                          ? const Center(child: CircularProgressIndicator())
                          : _filteredRecords.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.event_busy,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No attendance records found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'Try adjusting your search or filters',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[500],
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _paginatedRecords.length,
                              itemBuilder: (context, index) {
                                final record = _paginatedRecords[index];
                                final employee = _getEmployeeForAttendance(
                                  record,
                                );
                                final status = record.status;
                                final statusColor = _getStatusColor(status);

                                if (employee == null) {
                                  return SizedBox.shrink();
                                }

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: index % 2 == 0
                                        ? Colors.white
                                        : Color(0xFFF8F9FA),
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey[200]!,
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      // Date
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          DateFormat(
                                            'MMM dd, yyyy',
                                          ).format(DateTime.parse(record.date)),
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      // Employee ID
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 3,
                                              ),
                                              decoration: BoxDecoration(
                                                color: Color(
                                                  0xFF0D1845,
                                                ).withOpacity(0.1),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                'EMP${employee.id}',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF0D1845),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Employee Name
                                      Expanded(
                                        flex: 3,
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 14,
                                              backgroundColor: Color(
                                                0xFF0D1845,
                                              ),
                                              foregroundColor: Colors.white,
                                              child: Text(
                                                employee.employeeName
                                                    .split(' ')
                                                    .map(
                                                      (n) => n.isNotEmpty
                                                          ? n[0]
                                                          : '',
                                                    )
                                                    .take(2)
                                                    .join(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                employee.employeeName,
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      // Check-in Time
                                      Expanded(
                                        flex: 2,
                                        child:
                                            status.toLowerCase() == 'present' ||
                                                status.toLowerCase() ==
                                                    'late' ||
                                                status.toLowerCase() ==
                                                    'half-day'
                                            ? Row(
                                                children: [
                                                  Icon(
                                                    Icons.login,
                                                    size: 12,
                                                    color: Color(0xFF28A745),
                                                  ),
                                                  SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      _extractTimeFromDateTime(
                                                        record.checkIn,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Color(
                                                          0xFF28A745,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Text(
                                                '-',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                      ),
                                      // Check-out Time
                                      Expanded(
                                        flex: 2,
                                        child:
                                            status.toLowerCase() == 'present' ||
                                                status.toLowerCase() ==
                                                    'late' ||
                                                status.toLowerCase() ==
                                                    'half-day'
                                            ? Row(
                                                children: [
                                                  Icon(
                                                    Icons.logout,
                                                    size: 12,
                                                    color: Color(0xFFDC3545),
                                                  ),
                                                  SizedBox(width: 4),
                                                  Expanded(
                                                    child: Text(
                                                      _extractTimeFromDateTime(
                                                        record.checkOut,
                                                      ),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Color(
                                                          0xFFDC3545,
                                                        ),
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : Text(
                                                '-',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                      ),
                                      // Status
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: statusColor.withOpacity(
                                                0.1,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(
                                                  _getStatusIcon(status),
                                                  size: 12,
                                                  color: statusColor,
                                                ),
                                                SizedBox(width: 4),
                                                Text(
                                                  status,
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    color: statusColor,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                      // Actions
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            // View Button
                                            Tooltip(
                                              message: 'View Details',
                                              child: InkWell(
                                                onTap: () =>
                                                    _viewAttendance(record),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: Container(
                                                  padding: EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.blue
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.visibility,
                                                    size: 14,
                                                    color: Colors.blue,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            SizedBox(width: 4),
                                            // Edit Button
                                            /*
                                            Tooltip(
                                              message: 'Edit',
                                              child: InkWell(
                                                onTap: () =>
                                                    _editAttendance(record),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: Container(
                                                  padding: EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.orange
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.edit,
                                                    size: 14,
                                                    color: Colors.orange,
                                                  ),
                                                ),
                                              ),
                                            ),
                                            */
                                            SizedBox(width: 4),
                                            // Delete Button
                                            Tooltip(
                                              message: 'Delete',
                                              child: InkWell(
                                                onTap: () =>
                                                    _deleteAttendance(record),
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                                child: Container(
                                                  padding: EdgeInsets.all(6),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red
                                                        .withOpacity(0.1),
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          4,
                                                        ),
                                                  ),
                                                  child: Icon(
                                                    Icons.delete,
                                                    size: 14,
                                                    color: Colors.red,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                    ),

                    // Pagination
                    if (_filteredRecords.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8F9FA),
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                          border: Border(
                            top: BorderSide(color: Colors.grey[300]!),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Showing ${(_currentPage - 1) * _itemsPerPage + 1} to ${(_currentPage * _itemsPerPage) > _filteredRecords.length ? _filteredRecords.length : (_currentPage * _itemsPerPage)} of ${_filteredRecords.length}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.chevron_left, size: 20),
                                  onPressed: _currentPage > 1
                                      ? () {
                                          setState(() {
                                            _currentPage--;
                                          });
                                        }
                                      : null,
                                  padding: EdgeInsets.all(4),
                                  constraints: BoxConstraints(),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Page $_currentPage of ${(_filteredRecords.length / _itemsPerPage).ceil()}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.chevron_right, size: 20),
                                  onPressed:
                                      _currentPage <
                                          (_filteredRecords.length /
                                                  _itemsPerPage)
                                              .ceil()
                                      ? () {
                                          setState(() {
                                            _currentPage++;
                                          });
                                        }
                                      : null,
                                  padding: EdgeInsets.all(4),
                                  constraints: BoxConstraints(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// Add Attendance Dialog Widget
class _AddAttendanceDialog extends StatefulWidget {
  final List<EmployeeWithAttendance> allEmployees;
  final Function(Map<String, dynamic>) onAttendanceAdded;

  const _AddAttendanceDialog({
    required this.allEmployees,
    required this.onAttendanceAdded,
  });

  @override
  State<_AddAttendanceDialog> createState() => _AddAttendanceDialogState();
}

class _AddAttendanceDialogState extends State<_AddAttendanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final AttendanceService _attendanceService = AttendanceService();
  final TextEditingController _employeeSearchController =
      TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _checkInController = TextEditingController();
  final TextEditingController _checkOutController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  EmployeeWithAttendance? _selectedEmployee;
  String _selectedStatus = 'present';
  bool _isSubmitting = false;

  final List<Map<String, String>> _statusOptions = [
    {'value': 'present', 'label': 'Present'},
    {'value': 'absent', 'label': 'Absent'},
    {'value': 'late', 'label': 'Late'},
    {'value': 'half-day', 'label': 'Half-day'},
    {'value': 'leave', 'label': 'Leave'},
  ];

  @override
  void dispose() {
    _employeeSearchController.dispose();
    _dateController.dispose();
    _checkInController.dispose();
    _checkOutController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _selectEmployee() async {
    final selected = await showDialog<EmployeeWithAttendance>(
      context: context,
      builder: (context) =>
          _EmployeeSelectionDialog(employees: widget.allEmployees),
    );

    if (selected != null) {
      setState(() {
        _selectedEmployee = selected;
        _employeeSearchController.text =
            '${selected.employeeName} (ID: ${selected.id})';
      });
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF0D1845),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF0D1845),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        controller.text = formattedTime;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedEmployee == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select an employee'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await _attendanceService.createAttendance(
        employeeId: _selectedEmployee!.id,
        date: _dateController.text,
        checkIn: _checkInController.text,
        checkOut: _checkOutController.text,
        status: _selectedStatus,
        remarks: _remarksController.text.isEmpty
            ? null
            : _remarksController.text,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'Attendance added successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onAttendanceAdded(response);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1845), Color(0xFF1a2980)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.add_task, color: Colors.white, size: 24),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Add Attendance',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          'Record employee attendance',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Employee Selection
                        Text(
                          'Employee *',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF0D1845),
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _employeeSearchController,
                          readOnly: true,
                          decoration: InputDecoration(
                            hintText: 'Select employee',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Color(0xFF0D1845),
                                width: 2,
                              ),
                            ),
                            suffixIcon: Icon(Icons.search),
                          ),
                          onTap: _selectEmployee,
                          validator: (value) {
                            if (_selectedEmployee == null) {
                              return 'Please select an employee';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),

                        // Date
                        Text(
                          'Date *',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF0D1845),
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _dateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            hintText: 'Select date',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Color(0xFF0D1845),
                                width: 2,
                              ),
                            ),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          onTap: _selectDate,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a date';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),

                        // Check In Time
                        Text(
                          'Check-in Time *',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF0D1845),
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _checkInController,
                          readOnly: true,
                          decoration: InputDecoration(
                            hintText: 'Select check-in time',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Color(0xFF0D1845),
                                width: 2,
                              ),
                            ),
                            suffixIcon: Icon(Icons.access_time),
                          ),
                          onTap: () => _selectTime(_checkInController),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select check-in time';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),

                        // Check Out Time
                        Text(
                          'Check-out Time *',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF0D1845),
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _checkOutController,
                          readOnly: true,
                          decoration: InputDecoration(
                            hintText: 'Select check-out time',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Color(0xFF0D1845),
                                width: 2,
                              ),
                            ),
                            suffixIcon: Icon(Icons.access_time),
                          ),
                          onTap: () => _selectTime(_checkOutController),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select check-out time';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),

                        // Status
                        Text(
                          'Status *',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF0D1845),
                          ),
                        ),
                        SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Color(0xFF0D1845),
                                width: 2,
                              ),
                            ),
                          ),
                          items: _statusOptions.map((status) {
                            return DropdownMenuItem<String>(
                              value: status['value'],
                              child: Text(status['label']!),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStatus = value!;
                            });
                          },
                        ),
                        SizedBox(height: 20),

                        // Remarks
                        Text(
                          'Remarks',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF0D1845),
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _remarksController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Enter remarks (optional)',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Color(0xFF0D1845),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF0D1845),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Add Attendance',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Employee Selection Dialog
class _EmployeeSelectionDialog extends StatefulWidget {
  final List<EmployeeWithAttendance> employees;

  const _EmployeeSelectionDialog({required this.employees});

  @override
  State<_EmployeeSelectionDialog> createState() =>
      _EmployeeSelectionDialogState();
}

class _EmployeeSelectionDialogState extends State<_EmployeeSelectionDialog> {
  final TextEditingController _searchController = TextEditingController();
  List<EmployeeWithAttendance> _filteredEmployees = [];

  @override
  void initState() {
    super.initState();
    _filteredEmployees = widget.employees;
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredEmployees = widget.employees;
      } else {
        _filteredEmployees = widget.employees.where((emp) {
          return emp.employeeName.toLowerCase().contains(query) ||
              emp.email.toLowerCase().contains(query) ||
              emp.id.toString().contains(query) ||
              emp.role.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 500,
        height: 600,
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.people, color: Color(0xFF0D1845)),
                SizedBox(width: 12),
                Text(
                  'Select Employee',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0D1845),
                  ),
                ),
                Spacer(),
                IconButton(
                  icon: Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Search Bar
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name, email, or ID...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
            SizedBox(height: 16),

            // Employee List
            Expanded(
              child: _filteredEmployees.isEmpty
                  ? Center(
                      child: Text(
                        'No employees found',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredEmployees.length,
                      itemBuilder: (context, index) {
                        final employee = _filteredEmployees[index];
                        return Card(
                          margin: EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Color(0xFF0D1845),
                              foregroundColor: Colors.white,
                              child: Text(
                                employee.employeeName
                                    .split(' ')
                                    .map((n) => n.isNotEmpty ? n[0] : '')
                                    .take(2)
                                    .join(),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            title: Text(
                              employee.employeeName,
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('ID: ${employee.id}'),
                                Text('Role: ${employee.role}'),
                                Text('Email: ${employee.email}'),
                              ],
                            ),
                            onTap: () {
                              Navigator.of(context).pop(employee);
                            },
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// View Attendance Dialog
class _ViewAttendanceDialog extends StatelessWidget {
  final EmployeeWithAttendance employee;
  final AttendanceRecord attendance;

  const _ViewAttendanceDialog({
    required this.employee,
    required this.attendance,
  });

  static String _extractTimeFromDateTime(String dateTimeString) {
    try {
      // Try to parse as ISO 8601 datetime
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('HH:mm').format(dateTime);
    } catch (e) {
      // If parsing fails, assume it's already in HH:mm format
      return dateTimeString;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'present':
        return Color(0xFF28A745);
      case 'absent':
        return Color(0xFFDC3545);
      case 'leave':
      case 'half-day':
        return Color(0xFFFFC107);
      case 'late':
        return Color(0xFFFF6B6B);
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 500,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1845), Color(0xFF1a2980)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.visibility,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Attendance Details',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          employee.employeeName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Content
            Container(
              decoration: BoxDecoration(
                color: Color(0xFFF8F9FA),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
              ),
              padding: EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildInfoRow('Employee', employee.employeeName),
                  _buildInfoRow('Employee ID', 'EMP${employee.id}'),
                  _buildInfoRow('Email', employee.email),
                  _buildInfoRow('Role', employee.role),
                  _buildInfoRow(
                    'Date',
                    DateFormat(
                      'MMMM dd, yyyy',
                    ).format(DateTime.parse(attendance.date)),
                  ),
                  _buildInfoRow(
                    'Check-in Time',
                    _extractTimeFromDateTime(attendance.checkIn),
                  ),
                  _buildInfoRow(
                    'Check-out Time',
                    _extractTimeFromDateTime(attendance.checkOut),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Status',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: _getStatusColor(
                        attendance.status,
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _getStatusColor(attendance.status),
                      ),
                    ),
                    child: Text(
                      attendance.status,
                      style: TextStyle(
                        fontSize: 14,
                        color: _getStatusColor(attendance.status),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (attendance.remarks.isNotEmpty &&
                      attendance.remarks != '-') ...[
                    SizedBox(height: 16),
                    Text(
                      'Remarks',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Text(
                        attendance.remarks,
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

// Edit Attendance Dialog
class _EditAttendanceDialog extends StatefulWidget {
  final EmployeeWithAttendance employee;
  final AttendanceRecord attendance;
  final Function(Map<String, dynamic>) onAttendanceUpdated;

  const _EditAttendanceDialog({
    required this.employee,
    required this.attendance,
    required this.onAttendanceUpdated,
  });

  @override
  State<_EditAttendanceDialog> createState() => _EditAttendanceDialogState();
}

class _EditAttendanceDialogState extends State<_EditAttendanceDialog> {
  final _formKey = GlobalKey<FormState>();
  final AttendanceService _attendanceService = AttendanceService();
  final TextEditingController _dateController = TextEditingController();
  final TextEditingController _checkInController = TextEditingController();
  final TextEditingController _checkOutController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();

  String _selectedStatus = 'present';
  bool _isSubmitting = false;

  final List<Map<String, String>> _statusOptions = [
    {'value': 'present', 'label': 'Present'},
    {'value': 'absent', 'label': 'Absent'},
    {'value': 'late', 'label': 'Late'},
    {'value': 'half-day', 'label': 'Half-day'},
    {'value': 'leave', 'label': 'Leave'},
  ];

  @override
  void initState() {
    super.initState();
    _dateController.text = widget.attendance.date;
    _checkInController.text = _extractTimeFromDateTime(
      widget.attendance.checkIn,
    );
    _checkOutController.text = _extractTimeFromDateTime(
      widget.attendance.checkOut,
    );
    _remarksController.text = widget.attendance.remarks == '-'
        ? ''
        : widget.attendance.remarks;
    _selectedStatus = widget.attendance.status.toLowerCase();
  }

  String _extractTimeFromDateTime(String dateTimeString) {
    try {
      // Try to parse as ISO 8601 datetime
      final dateTime = DateTime.parse(dateTimeString);
      return DateFormat('HH:mm').format(dateTime);
    } catch (e) {
      // If parsing fails, assume it's already in HH:mm format
      return dateTimeString;
    }
  }

  @override
  void dispose() {
    _dateController.dispose();
    _checkInController.dispose();
    _checkOutController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.parse(_dateController.text),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF0D1845),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  Future<void> _selectTime(TextEditingController controller) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Color(0xFF0D1845),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final formattedTime =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      setState(() {
        controller.text = formattedTime;
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      final response = await _attendanceService.updateAttendance(
        employeeId: widget.employee.id,
        attendanceId: widget.attendance.id,
        date: _dateController.text,
        checkIn: _checkInController.text,
        checkOut: _checkOutController.text,
        status: _selectedStatus,
        remarks: _remarksController.text.isEmpty
            ? null
            : _remarksController.text,
      );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              response['message'] ?? 'Attendance updated successfully',
            ),
            backgroundColor: Colors.green,
          ),
        );
        widget.onAttendanceUpdated(response);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: 600,
        constraints: BoxConstraints(maxHeight: 700),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0D1845), Color(0xFF1a2980)],
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.edit, color: Colors.white, size: 24),
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Edit Attendance',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        Text(
                          widget.employee.employeeName,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // Form
            Flexible(
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20),
                  ),
                ),
                child: SingleChildScrollView(
                  padding: EdgeInsets.all(24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Date
                        Text(
                          'Date *',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF0D1845),
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _dateController,
                          readOnly: true,
                          decoration: InputDecoration(
                            hintText: 'Select date',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Color(0xFF0D1845),
                                width: 2,
                              ),
                            ),
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          onTap: _selectDate,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a date';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),

                        // Check In Time
                        Text(
                          'Check-in Time *',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF0D1845),
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _checkInController,
                          readOnly: true,
                          decoration: InputDecoration(
                            hintText: 'Select check-in time',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Color(0xFF0D1845),
                                width: 2,
                              ),
                            ),
                            suffixIcon: Icon(Icons.access_time),
                          ),
                          onTap: () => _selectTime(_checkInController),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select check-in time';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),

                        // Check Out Time
                        Text(
                          'Check-out Time *',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF0D1845),
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _checkOutController,
                          readOnly: true,
                          decoration: InputDecoration(
                            hintText: 'Select check-out time',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Color(0xFF0D1845),
                                width: 2,
                              ),
                            ),
                            suffixIcon: Icon(Icons.access_time),
                          ),
                          onTap: () => _selectTime(_checkOutController),
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select check-out time';
                            }
                            return null;
                          },
                        ),
                        SizedBox(height: 20),

                        // Status
                        Text(
                          'Status *',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF0D1845),
                          ),
                        ),
                        SizedBox(height: 8),
                        DropdownButtonFormField<String>(
                          value: _selectedStatus,
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Color(0xFF0D1845),
                                width: 2,
                              ),
                            ),
                          ),
                          items: _statusOptions.map((status) {
                            return DropdownMenuItem<String>(
                              value: status['value'],
                              child: Text(status['label']!),
                            );
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedStatus = value!;
                            });
                          },
                        ),
                        SizedBox(height: 20),

                        // Remarks
                        Text(
                          'Remarks',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: Color(0xFF0D1845),
                          ),
                        ),
                        SizedBox(height: 8),
                        TextFormField(
                          controller: _remarksController,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Enter remarks (optional)',
                            filled: true,
                            fillColor: Colors.white,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: Color(0xFF0D1845),
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(height: 24),

                        // Submit Button
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitForm,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Color(0xFF0D1845),
                              foregroundColor: Colors.white,
                              padding: EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        Colors.white,
                                      ),
                                    ),
                                  )
                                : Text(
                                    'Update Attendance',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
