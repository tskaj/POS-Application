import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/employees_service.dart';
import '../../services/city_service.dart';
import '../../models/city.dart' as cityModel;

class EmployeesPage extends StatefulWidget {
  const EmployeesPage({super.key});

  @override
  State<EmployeesPage> createState() => _EmployeesPageState();
}

class _EmployeesPageState extends State<EmployeesPage> {
  // Employees data
  List<Employee> _employees = [];
  List<Employee> _filteredEmployees = [];
  bool _isLoading = false;

  // Pagination
  int currentPage = 1;
  final int itemsPerPage = 12;

  // Filter state
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final response = await EmployeeService.getEmployees();

      setState(() {
        // Reverse the list so newest employees appear first
        _employees = response.data.reversed.toList();
        _filteredEmployees = _employees;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Failed to load employees: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredEmployees = _employees.where((employee) {
        final matchesSearch =
            _searchQuery.isEmpty ||
            employee.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            employee.cnic.contains(_searchQuery) ||
            employee.cellNo1.contains(_searchQuery) ||
            employee.position.toLowerCase().contains(
              _searchQuery.toLowerCase(),
            ) ||
            employee.email.toLowerCase().contains(_searchQuery.toLowerCase());

        return matchesSearch;
      }).toList();
      currentPage = 1;
    });
  }

  List<Employee> _getPaginatedEmployees() {
    final startIndex = (currentPage - 1) * itemsPerPage;
    final endIndex = startIndex + itemsPerPage;

    if (startIndex >= _filteredEmployees.length) {
      return [];
    }

    return _filteredEmployees.sublist(
      startIndex,
      endIndex > _filteredEmployees.length
          ? _filteredEmployees.length
          : endIndex,
    );
  }

  int _getTotalPages() {
    if (_filteredEmployees.isEmpty) return 1;
    return (_filteredEmployees.length / itemsPerPage).ceil();
  }

  void _changePage(int newPage) {
    setState(() {
      currentPage = newPage;
    });
  }

  Future<void> _viewEmployeeDetails(int employeeId) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return Center(
          child: Container(
            padding: EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Loading employee details...'),
              ],
            ),
          ),
        );
      },
    );

    try {
      final employee = await EmployeeService.getEmployeeById(employeeId);

      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        _showEmployeeDetailsDialog(employee);
      }
    } catch (e) {
      if (mounted) {
        Navigator.of(context).pop(); // Close loading dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Failed to load employee details: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  void _showEmployeeDetailsDialog(Employee employee) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.6,
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.85,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF0D1845), Color(0xFF1a2980)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Employee Details',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'ID: ${employee.id}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.white.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, color: Colors.white, size: 24),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.white.withOpacity(0.2),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children:
                          [
                            _buildDetailCard(
                              'Personal Information',
                              Icons.person,
                              Color(0xFF3498DB),
                              [
                                _buildDetailRow('Name', employee.name),
                                _buildDetailRow('Email', employee.email),
                                _buildDetailRow('CNIC', employee.cnic),
                              ],
                            ),
                            SizedBox(height: 16),
                            _buildDetailCard(
                              'Contact Information',
                              Icons.phone,
                              Color(0xFF27AE60),
                              [
                                _buildDetailRow('Phone 1', employee.cellNo1),
                                _buildDetailRow('Phone 2', employee.cellNo2),
                                _buildDetailRow('Address', employee.address),
                                _buildDetailRow('City', employee.city),
                              ],
                            ),
                            SizedBox(height: 16),
                            _buildDetailCard(
                              'Employment Information',
                              Icons.work,
                              Color(0xFFE67E22),
                              [
                                _buildDetailRow('Position', employee.position),
                                _buildDetailRow('Status', employee.status),
                                _buildDetailRow(
                                  'Joined',
                                  DateFormat(
                                    'MMM dd, yyyy',
                                  ).format(DateTime.parse(employee.createdAt)),
                                ),
                              ],
                            ),
                          ],
                    ),
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: Offset(0, -2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(Icons.close, size: 18),
                        label: const Text('Close'),
                        style: TextButton.styleFrom(
                          foregroundColor: Color(0xFF6C757D),
                          padding: EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDetailCard(
    String title,
    IconData icon,
    Color color,
    List<Widget> children,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              SizedBox(width: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ],
          ),
          SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
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
            flex: 3,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF2C3E50),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateEmployeeDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _EmployeeFormDialog(
          isEdit: false,
          employee: null,
          onSuccess: () {
            _fetchEmployees(); // Refresh the list
          },
        );
      },
    );
  }

  void _showEditEmployeeDialog(Employee employee) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return _EmployeeFormDialog(
          isEdit: true,
          employee: employee,
          onSuccess: () {
            _fetchEmployees(); // Refresh the list
          },
        );
      },
    );
  }

  Future<void> _deleteEmployee(int employeeId) async {
    // Show confirmation dialog
    final confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.warning, color: Colors.orange),
              SizedBox(width: 12),
              Text('Confirm Delete'),
            ],
          ),
          content: Text(
            'Are you sure you want to delete this employee? This action cannot be undone.',
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
        );
      },
    );

    if (confirm != true) return;

    try {
      await EmployeeService.deleteEmployee(employeeId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text('Employee deleted successfully'),
              ],
            ),
            backgroundColor: Color(0xFF28A745),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );

        // Refresh the list
        _fetchEmployees();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Failed to delete employee: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    }
  }

  @override
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Employees Management'),
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
            // Header with Summary
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0D1845), Color(0xFF0A1238)],
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Color(0xFF0D1845).withOpacity(0.3),
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
                      Icons.badge,
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
                          'Employee Management',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Total Employees: ${_filteredEmployees.length}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: _showCreateEmployeeDialog,
                    icon: const Icon(Icons.add, size: 14),
                    label: const Text(
                      'Create New Employee',
                      style: TextStyle(fontSize: 12),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0D1845),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search and Table
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
                    // Search Bar
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        border: Border(
                          bottom: BorderSide(
                            color: Colors.grey[200]!,
                            width: 1,
                          ),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              decoration: InputDecoration(
                                hintText: 'Search by name, CNIC, phone...',
                                prefixIcon: Icon(Icons.search),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                                _applyFilters();
                              },
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Table Header
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8F9FA),
                        border: Border(
                          bottom: BorderSide(color: Colors.grey[300]!),
                        ),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            flex: 2,
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
                              'CNIC',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Phone Number',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'City',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              'Designation',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 1,
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
                          : _filteredEmployees.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 64,
                                    color: Colors.grey[400],
                                  ),
                                  SizedBox(height: 16),
                                  Text(
                                    'No employees found',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              itemCount: _getPaginatedEmployees().length,
                              itemBuilder: (context, index) {
                                final employee =
                                    _getPaginatedEmployees()[index];
                                final initials = employee.name
                                    .split(' ')
                                    .take(2)
                                    .map((n) => n.isNotEmpty ? n[0] : '')
                                    .join()
                                    .toUpperCase();

                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: index % 2 == 0
                                        ? Colors.white
                                        : Color(0xFFFAFAFA),
                                    border: Border(
                                      bottom: BorderSide(
                                        color: Colors.grey[200]!,
                                        width: 0.5,
                                      ),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        flex: 2,
                                        child: Row(
                                          children: [
                                            CircleAvatar(
                                              radius: 16,
                                              backgroundColor: Color(
                                                0xFF0D1845,
                                              ),
                                              foregroundColor: Colors.white,
                                              child: Text(
                                                initials,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    employee.name,
                                                    style: TextStyle(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF2C3E50),
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                  SizedBox(height: 2),
                                                  Text(
                                                    employee.email,
                                                    style: TextStyle(
                                                      fontSize: 10,
                                                      color: Colors.grey[600],
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          employee.cnic,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF34495E),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              employee.cellNo1,
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (employee.cellNo2 != 'N/A')
                                              Text(
                                                employee.cellNo2,
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Text(
                                          employee.city,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Color(0xFF34495E),
                                          ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                      Expanded(
                                        flex: 2,
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Color(
                                                0xFF3498DB,
                                              ).withOpacity(0.1),
                                              borderRadius:
                                                  BorderRadius.circular(3),
                                            ),
                                            child: Text(
                                              employee.position,
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Color(0xFF3498DB),
                                                fontWeight: FontWeight.w600,
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ),
                                      ),
                                      Expanded(
                                        flex: 1,
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            IconButton(
                                              icon: Icon(
                                                Icons.visibility_outlined,
                                                size: 16,
                                                color: Color(0xFF17A2B8),
                                              ),
                                              onPressed: () {
                                                _viewEmployeeDetails(
                                                  employee.id,
                                                );
                                              },
                                              tooltip: 'View',
                                              padding: EdgeInsets.all(4),
                                              constraints: BoxConstraints(),
                                            ),
                                            SizedBox(width: 4),
                                            IconButton(
                                              icon: Icon(
                                                Icons.edit_outlined,
                                                size: 16,
                                                color: Color(0xFFFFC107),
                                              ),
                                              onPressed: () {
                                                _showEditEmployeeDialog(
                                                  employee,
                                                );
                                              },
                                              tooltip: 'Edit',
                                              padding: EdgeInsets.all(4),
                                              constraints: BoxConstraints(),
                                            ),
                                            SizedBox(width: 4),
                                            IconButton(
                                              icon: Icon(
                                                Icons.delete_outline,
                                                size: 16,
                                                color: Color(0xFFDC3545),
                                              ),
                                              onPressed: () {
                                                _deleteEmployee(employee.id);
                                              },
                                              tooltip: 'Delete',
                                              padding: EdgeInsets.all(4),
                                              constraints: BoxConstraints(),
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
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 6,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ElevatedButton.icon(
                            onPressed: currentPage > 1
                                ? () => _changePage(currentPage - 1)
                                : null,
                            icon: Icon(Icons.chevron_left, size: 14),
                            label: Text(
                              'Previous',
                              style: TextStyle(fontSize: 11),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: currentPage > 1
                                  ? Color(0xFF17A2B8)
                                  : Color(0xFF6C757D),
                              elevation: 0,
                              side: BorderSide(color: Color(0xFFDEE2E6)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Page $currentPage of ${_getTotalPages()}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Color(0xFF6C757D),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          ElevatedButton.icon(
                            onPressed: currentPage < _getTotalPages()
                                ? () => _changePage(currentPage + 1)
                                : null,
                            icon: Icon(Icons.chevron_right, size: 14),
                            label: Text('Next', style: TextStyle(fontSize: 11)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: currentPage < _getTotalPages()
                                  ? Color(0xFF17A2B8)
                                  : Colors.grey.shade300,
                              foregroundColor: currentPage < _getTotalPages()
                                  ? Colors.white
                                  : Colors.grey.shade600,
                              elevation: currentPage < _getTotalPages() ? 2 : 0,
                              side: currentPage < _getTotalPages()
                                  ? null
                                  : BorderSide(color: Color(0xFFDEE2E6)),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(5),
                              ),
                              padding: EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Stateful Employee Form Dialog
class _EmployeeFormDialog extends StatefulWidget {
  final bool isEdit;
  final Employee? employee;
  final VoidCallback onSuccess;

  const _EmployeeFormDialog({
    required this.isEdit,
    this.employee,
    required this.onSuccess,
  });

  @override
  State<_EmployeeFormDialog> createState() => _EmployeeFormDialogState();
}

class _EmployeeFormDialogState extends State<_EmployeeFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _cnicController = TextEditingController();
  final _addressController = TextEditingController();
  final _cellNo1Controller = TextEditingController();
  final _cellNo2Controller = TextEditingController();

  cityModel.City? _selectedCity;
  String? _selectedStatus; // Will be set in initState
  int _selectedRoleId = 4; // Default to Cashier
  bool _isLoading = false;

  // Role definitions
  final List<Map<String, dynamic>> _roles = [
    {'id': 1, 'name': 'Super Admin'},
    {'id': 2, 'name': 'Admin'},
    {'id': 3, 'name': 'Manager'},
    {'id': 4, 'name': 'Cashier'},
    {'id': 5, 'name': 'Inventory Officer'},
    {'id': 6, 'name': 'Salesman'},
  ];

  // Email validation regex
  final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  // Format CNIC with dashes (13 digits)
  String _formatCNIC(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (digitsOnly.isEmpty) return '';

    if (digitsOnly.length <= 5) {
      return digitsOnly;
    } else if (digitsOnly.length <= 12) {
      return '${digitsOnly.substring(0, 5)}-${digitsOnly.substring(5)}';
    } else {
      return '${digitsOnly.substring(0, 5)}-${digitsOnly.substring(5, 12)}-${digitsOnly.substring(12, 13)}';
    }
  }

  // Format phone number (10 digits after +92)
  String _formatPhoneNumber(String value) {
    final digitsOnly = value.replaceAll(RegExp(r'[^0-9]'), '');
    return digitsOnly.length > 10 ? digitsOnly.substring(0, 10) : digitsOnly;
  }

  @override
  void initState() {
    super.initState();
    // Initialize status first based on mode
    if (widget.isEdit && widget.employee != null) {
      final emp = widget.employee!;

      // Convert status from API format to dropdown value (capitalize) FIRST
      final statusLower = emp.status.toString().toLowerCase();
      if (statusLower == 'active' || statusLower == '1') {
        _selectedStatus = 'Active';
      } else if (statusLower == 'inactive' || statusLower == '0') {
        _selectedStatus = 'Inactive';
      } else {
        // Fallback: capitalize the status string or default to 'Active'
        final s = emp.status.toString();
        if (s.isNotEmpty && s != '1' && s != '0') {
          _selectedStatus = s[0].toUpperCase() + s.substring(1);
        } else {
          _selectedStatus = 'Active';
        }
      }

      // Split name into first and last name
      final nameParts = emp.name.split(' ');
      _firstNameController.text = nameParts.isNotEmpty ? nameParts[0] : '';
      _lastNameController.text = nameParts.length > 1
          ? nameParts.sublist(1).join(' ')
          : '';
      _emailController.text = emp.email;
      _cnicController.text = emp.cnic;
      _addressController.text = emp.address;

      // Remove +92 prefix if present for editing
      String phone1 = emp.cellNo1;
      if (phone1.startsWith('+92')) {
        phone1 = phone1.substring(3).replaceAll(RegExp(r'[^0-9]'), '');
      }
      _cellNo1Controller.text = phone1;

      String phone2 = emp.cellNo2 != 'N/A' ? emp.cellNo2 : '';
      if (phone2.startsWith('+92')) {
        phone2 = phone2.substring(3).replaceAll(RegExp(r'[^0-9]'), '');
      }
      _cellNo2Controller.text = phone2;

      // Try to match position to role ID
      final position = emp.position.toString().toLowerCase();
      if (position.contains('super admin')) {
        _selectedRoleId = 1;
      } else if (position.contains('admin') && !position.contains('super')) {
        _selectedRoleId = 2;
      } else if (position.contains('manager')) {
        _selectedRoleId = 3;
      } else if (position.contains('cashier')) {
        _selectedRoleId = 4;
      } else if (position.contains('inventory')) {
        _selectedRoleId = 5;
      } else if (position.contains('salesman') || position.contains('sales')) {
        _selectedRoleId = 6;
      }
      // Note: city data would need to be loaded if we had city ID
      // Attempt to load and pre-select the employee's city. Prefer using
      // the cityId from the Employee model (if present). If not available,
      // try to match by city title.
      _loadEmployeeCity(emp);
    } else {
      // Default status for new employee
      _selectedStatus = 'Active';
    }

    // Add listeners for auto-formatting
    _cnicController.addListener(() {
      final text = _cnicController.text;
      final formatted = _formatCNIC(text);
      if (text != formatted) {
        _cnicController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    });

    _cellNo1Controller.addListener(() {
      final text = _cellNo1Controller.text;
      final formatted = _formatPhoneNumber(text);
      if (text != formatted) {
        _cellNo1Controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    });

    _cellNo2Controller.addListener(() {
      final text = _cellNo2Controller.text;
      final formatted = _formatPhoneNumber(text);
      if (text != formatted) {
        _cellNo2Controller.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    });

    // Async: load and pre-select city for edit mode
  }

  Future<void> _loadEmployeeCity(Employee emp) async {
    try {
      // Try city by ID first
      if (emp.cityId != null && emp.cityId! > 0) {
        final resp = await CityService.getCityById(emp.cityId!);
        if (mounted && resp.data.id > 0) {
          setState(() {
            _selectedCity = resp.data;
          });
          return;
        }
      }

      // Fallback: load active cities and match by title (case-insensitive)
      if (emp.city.isNotEmpty) {
        final cities = await CityService.getActiveCities();
        final match = cities.firstWhere(
          (c) => c.title.trim().toLowerCase() == emp.city.trim().toLowerCase(),
          orElse: () => cityModel.City(
            id: 0,
            title: '',
            stateId: '',
            status: '',
            createdAt: '',
            updatedAt: '',
            state: cityModel.State(
              id: 0,
              title: '',
              countryId: '',
              status: '',
              createdAt: '',
              updatedAt: '',
              country: cityModel.Country(
                id: 0,
                title: '',
                code: '',
                currency: '',
                status: '',
                createdAt: '',
                updatedAt: '',
              ),
            ),
          ),
        );

        if (mounted && match.id > 0) {
          setState(() {
            _selectedCity = match;
          });
        }
      }
    } catch (e) {
      // Ignore city load failures silently (form still usable)
    }

    // Fallback: if city not loaded but employee has cityId, create a dummy city object
    if (mounted && _selectedCity == null && emp.cityId != null) {
      setState(() {
        _selectedCity = cityModel.City(
          id: emp.cityId!,
          title: emp.city.isNotEmpty ? emp.city : 'Unknown City',
          stateId: '',
          status: '',
          createdAt: '',
          updatedAt: '',
          state: cityModel.State(
            id: 0,
            title: '',
            countryId: '',
            status: '',
            createdAt: '',
            updatedAt: '',
            country: cityModel.Country(
              id: 0,
              title: '',
              code: '',
              currency: '',
              status: '',
              createdAt: '',
              updatedAt: '',
            ),
          ),
        );
      });
    }
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    _emailController.dispose();
    _cnicController.dispose();
    _addressController.dispose();
    _cellNo1Controller.dispose();
    _cellNo2Controller.dispose();
    super.dispose();
  }

  Future<void> _showCitySelection() async {
    final city = await _showCitySelectionDialog();
    if (city != null) {
      setState(() {
        _selectedCity = city;
      });
    }
  }

  Future<cityModel.City?> _showCitySelectionDialog() async {
    return await showDialog<cityModel.City>(
      context: context,
      builder: (BuildContext context) {
        return _CitySelectionDialog();
      },
    );
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    if (_selectedCity == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Text('Please select a city'),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // Prepare phone numbers with +92 prefix
      final phone1 = _cellNo1Controller.text.trim();
      final phone2 = _cellNo2Controller.text.trim();

      final employeeData = <String, dynamic>{
        'first_name': _firstNameController.text.trim(),
        'last_name': _lastNameController.text.trim(),
        'role_id': _selectedRoleId, // Send selected role ID
        'cnic': _cnicController.text.trim(),
        'address': _addressController.text.trim(),
        'city_id': _selectedCity!.id,
        'cell_no1': phone1.isNotEmpty ? '+92$phone1' : '',
        'cell_no2': phone2.isNotEmpty ? '+92$phone2' : '',
        'status':
            _selectedStatus, // Send 'Active' or 'Inactive' as required by API
      };

      // Handle email: always include if creating, or if editing and email is provided and changed
      final emailValue = _emailController.text.trim();
      if (emailValue.isNotEmpty) {
        employeeData['email'] = emailValue;
      } else if (widget.isEdit && widget.employee != null) {
        employeeData['email'] = widget.employee!.email;
      }

      if (widget.isEdit && widget.employee != null) {
        await EmployeeService.updateEmployee(widget.employee!.id, employeeData);
      } else {
        await EmployeeService.createEmployee(employeeData);
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 12),
                Text(
                  'Employee ${widget.isEdit ? 'updated' : 'created'} successfully',
                ),
              ],
            ),
            backgroundColor: Color(0xFF28A745),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
        widget.onSuccess();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Error: $e')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  InputDecoration _buildInputDecoration({
    required String label,
    String? hint,
    required IconData icon,
    bool isRequired = false,
  }) {
    return InputDecoration(
      labelText: isRequired ? '$label *' : label,
      hintText: hint,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      prefixIcon: Icon(icon),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Color(0xFF0D1845), width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.6,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D1845), Color(0xFF1a2980)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      widget.isEdit ? Icons.edit : Icons.person_add,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.isEdit
                              ? 'Edit Employee'
                              : 'Create New Employee',
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          widget.isEdit
                              ? 'Update employee details below'
                              : 'Fill in the employee details below',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.white, size: 24),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Personal Information Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Color(0xFFDEE2E6)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF2196F3).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.person,
                                    color: Color(0xFF2196F3),
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Personal Information',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D1845),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _firstNameController,
                                    decoration: _buildInputDecoration(
                                      label: 'First Name',
                                      icon: Icons.person_outline,
                                      isRequired: true,
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter first name';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _lastNameController,
                                    decoration: _buildInputDecoration(
                                      label: 'Last Name',
                                      icon: Icons.person_outline,
                                      isRequired: true,
                                    ),
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter last name';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              decoration: _buildInputDecoration(
                                label: 'Email',
                                hint: 'employee@example.com',
                                icon: Icons.email_outlined,
                                isRequired:
                                    !widget.isEdit, // Not required when editing
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  if (!widget.isEdit) {
                                    return 'Please enter email';
                                  }
                                  // When editing, email is optional since it's already set
                                  return null;
                                }
                                if (!_emailRegex.hasMatch(value.trim())) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _cnicController,
                              decoration: _buildInputDecoration(
                                label: 'CNIC',
                                hint: '12345-6789012-3',
                                icon: Icons.credit_card,
                                isRequired: true,
                              ),
                              keyboardType: TextInputType.number,
                              maxLength: 15, // 13 digits + 2 dashes
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter CNIC';
                                }
                                final digitsOnly = value.replaceAll(
                                  RegExp(r'[^0-9]'),
                                  '',
                                );
                                if (digitsOnly.length != 13) {
                                  return 'CNIC must be 13 digits';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Contact Information Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Color(0xFFDEE2E6)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF28A745).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.phone,
                                    color: Color(0xFF28A745),
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Contact Information',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D1845),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(
                                  child: TextFormField(
                                    controller: _cellNo1Controller,
                                    decoration:
                                        _buildInputDecoration(
                                          label: 'Primary Phone',
                                          hint: '3001234567',
                                          icon: Icons.phone_android,
                                          isRequired: true,
                                        ).copyWith(
                                          prefixText: '+92 ',
                                          prefixStyle: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    keyboardType: TextInputType.number,
                                    maxLength: 10,
                                    validator: (value) {
                                      if (value == null ||
                                          value.trim().isEmpty) {
                                        return 'Please enter primary phone';
                                      }
                                      final digitsOnly = value.replaceAll(
                                        RegExp(r'[^0-9]'),
                                        '',
                                      );
                                      if (digitsOnly.length != 10) {
                                        return 'Phone must be 10 digits';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: TextFormField(
                                    controller: _cellNo2Controller,
                                    decoration:
                                        _buildInputDecoration(
                                          label: 'Secondary Phone',
                                          hint: '3007654321',
                                          icon: Icons.phone_android,
                                        ).copyWith(
                                          prefixText: '+92 ',
                                          prefixStyle: TextStyle(
                                            color: Colors.black,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                    keyboardType: TextInputType.number,
                                    maxLength: 10,
                                    validator: (value) {
                                      if (value != null &&
                                          value.trim().isNotEmpty) {
                                        final digitsOnly = value.replaceAll(
                                          RegExp(r'[^0-9]'),
                                          '',
                                        );
                                        if (digitsOnly.length != 10) {
                                          return 'Phone must be 10 digits';
                                        }
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Address Information Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Color(0xFFDEE2E6)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Color(0xFFFFA726).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.location_on,
                                    color: Color(0xFFFFA726),
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Address Information',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D1845),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            TextFormField(
                              controller: _addressController,
                              maxLines: 3,
                              decoration: _buildInputDecoration(
                                label: 'Address',
                                hint: 'Street address, building name, etc.',
                                icon: Icons.home,
                                isRequired: true,
                              ),
                              validator: (value) {
                                if (value == null || value.trim().isEmpty) {
                                  return 'Please enter address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 16),
                            InkWell(
                              onTap: _showCitySelection,
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Color(0xFFDEE2E6)),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_city,
                                      color: Color(0xFF6C757D),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        _selectedCity != null
                                            ? _selectedCity!.title
                                            : 'Select City *',
                                        style: TextStyle(
                                          fontSize: 16,
                                          color: _selectedCity != null
                                              ? Colors.black87
                                              : Color(0xFF6C757D),
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.arrow_drop_down,
                                      color: Color(0xFF6C757D),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Role Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Color(0xFFDEE2E6)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF17A2B8).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.badge_outlined,
                                    color: Color(0xFF17A2B8),
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Role',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D1845),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            DropdownButtonFormField<int>(
                              value: _selectedRoleId,
                              decoration: _buildInputDecoration(
                                label: 'Role',
                                icon: Icons.work_outline,
                                isRequired: true,
                              ),
                              items: _roles.map((role) {
                                return DropdownMenuItem<int>(
                                  value: role['id'],
                                  child: Text(
                                    '${role['name']} (ID: ${role['id']})',
                                    style: TextStyle(fontSize: 14),
                                  ),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedRoleId = value);
                                }
                              },
                              validator: (value) {
                                if (value == null) {
                                  return 'Please select a role';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Status Section
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Color(0xFFDEE2E6)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.05),
                              blurRadius: 10,
                              offset: Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Color(0xFF6F42C1).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(
                                    Icons.toggle_on,
                                    color: Color(0xFF6F42C1),
                                    size: 20,
                                  ),
                                ),
                                SizedBox(width: 12),
                                Text(
                                  'Status',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0D1845),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 20),
                            DropdownButtonFormField<String>(
                              value: _selectedStatus,
                              decoration: _buildInputDecoration(
                                label: 'Status',
                                icon: Icons.info_outline,
                                isRequired: true,
                              ),
                              items: [
                                DropdownMenuItem(
                                  value: 'Active',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Active'),
                                    ],
                                  ),
                                ),
                                DropdownMenuItem(
                                  value: 'Inactive',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.cancel,
                                        color: Colors.red,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Inactive'),
                                    ],
                                  ),
                                ),
                              ],
                              onChanged: (value) {
                                if (value != null) {
                                  setState(() => _selectedStatus = value);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Footer
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, size: 18),
                    label: const Text('Cancel'),
                    style: TextButton.styleFrom(
                      foregroundColor: Color(0xFF6C757D),
                      padding: EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _submitForm,
                    icon: _isLoading
                        ? SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : Icon(Icons.save, size: 18),
                    label: Text(
                      _isLoading
                          ? 'Saving...'
                          : (widget.isEdit
                                ? 'Update Employee'
                                : 'Create Employee'),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Color(0xFF0D1845),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// City Selection Dialog Widget
class _CitySelectionDialog extends StatefulWidget {
  @override
  State<_CitySelectionDialog> createState() => _CitySelectionDialogState();
}

class _CitySelectionDialogState extends State<_CitySelectionDialog> {
  List<cityModel.City> _cities = [];
  List<cityModel.City> _filteredCities = [];
  bool _isLoading = true;
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchCities();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchCities() async {
    try {
      final cities = await CityService.getActiveCities();
      setState(() {
        _cities = cities;
        _filteredCities = cities;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to load cities: $e')));
      }
    }
  }

  void _filterCities(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCities = _cities;
      } else {
        _filteredCities = _cities
            .where(
              (city) => city.title.toLowerCase().contains(query.toLowerCase()),
            )
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 400,
        height: 500,
        child: Column(
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0D1845), Color(0xFF1a2980)],
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.location_city, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Select City',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withOpacity(0.2),
                    ),
                  ),
                ],
              ),
            ),

            // Search
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                onChanged: _filterCities,
                decoration: InputDecoration(
                  hintText: 'Search cities...',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),

            // City List
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator())
                  : _filteredCities.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.search_off, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No cities found',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      itemCount: _filteredCities.length,
                      itemBuilder: (context, index) {
                        final city = _filteredCities[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Color(0xFF0D1845).withOpacity(0.1),
                            child: Icon(
                              Icons.location_city,
                              color: Color(0xFF0D1845),
                              size: 20,
                            ),
                          ),
                          title: Text(city.title),
                          onTap: () => Navigator.of(context).pop(city),
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
