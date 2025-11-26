// Utils will be defined here

import '../services/inventory_service.dart';
import '../services/employees_service.dart';
import '../services/credit_customer_service.dart';
import '../models/vendor.dart' as vendor;

/// Checks for duplicate phone numbers across vendors, customers, and employees
/// Returns a map with 'isDuplicate' boolean and 'entityType' string if duplicate found
Future<Map<String, dynamic>> checkDuplicatePhoneNumber(
  String phoneNumber, {
  int? excludeEmployeeId,
  int? excludeCustomerId,
  int? excludeVendorId,
}) async {
  if (phoneNumber.trim().isEmpty) {
    return {'isDuplicate': false, 'entityType': null};
  }

  final normalizedPhone = _normalizePhoneNumber(phoneNumber);

  try {
    // Fetch all vendors
    final vendorResponse = await InventoryService.getVendors(limit: 1000);
    final vendors = vendorResponse.data;

    // Check vendors for duplicate phone
    for (final vendor in vendors) {
      // Skip the current vendor if editing
      if (excludeVendorId != null && vendor.id == excludeVendorId) {
        continue;
      }
      if (vendor.phone != null &&
          _normalizePhoneNumber(vendor.phone!) == normalizedPhone) {
        return {
          'isDuplicate': true,
          'entityType': 'vendor',
          'entityName': vendor.fullName,
        };
      }
    }

    // Fetch all employees
    final employeeResponse = await EmployeeService.getEmployees();
    final employees = employeeResponse.data;

    // Check employees for duplicate phone (check both cell numbers)
    for (final employee in employees) {
      // Skip the current employee if editing
      if (excludeEmployeeId != null && employee.id == excludeEmployeeId) {
        continue;
      }
      if (employee.cellNo1.isNotEmpty &&
          _normalizePhoneNumber(employee.cellNo1) == normalizedPhone) {
        return {
          'isDuplicate': true,
          'entityType': 'employee',
          'entityName': employee.name,
        };
      }
      if (employee.cellNo2.isNotEmpty &&
          employee.cellNo2 != 'N/A' &&
          _normalizePhoneNumber(employee.cellNo2) == normalizedPhone) {
        return {
          'isDuplicate': true,
          'entityType': 'employee',
          'entityName': employee.name,
        };
      }
    }

    // Fetch all customers
    final customers = await CreditCustomerService.getAllCreditCustomers();

    // Check customers for duplicate phone
    for (final customer in customers) {
      // Skip the current customer if editing
      if (excludeCustomerId != null && customer['id'] == excludeCustomerId) {
        continue;
      }
      if (customer['phone'] != null &&
          _normalizePhoneNumber(customer['phone'] as String) ==
              normalizedPhone) {
        return {
          'isDuplicate': true,
          'entityType': 'customer',
          'entityName': customer['name'],
        };
      }
    }

    return {'isDuplicate': false, 'entityType': null};
  } catch (e) {
    print('❌ Error checking duplicate phone number: $e');
    // On error, assume no duplicate to allow submission
    return {'isDuplicate': false, 'entityType': null};
  }
}

/// Normalizes phone number for comparison by removing spaces, dashes, and +92 prefix
String _normalizePhoneNumber(String phone) {
  return phone
      .replaceAll(' ', '')
      .replaceAll('-', '')
      .replaceAll('+92', '')
      .replaceAll('+', '');
}
