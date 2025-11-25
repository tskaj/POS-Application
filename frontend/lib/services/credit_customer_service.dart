import '../services/services.dart';

class CreditCustomerService {
  // Get all credit customers with pagination
  static Future<Map<String, dynamic>> getCreditCustomers({
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      print(
        '📊 CREDIT CUSTOMERS: Fetching credit customers from API - page $page, perPage $perPage',
      );
      final response = await ApiService.get(
        '/customers?page=$page&per_page=$perPage',
      );

      if (response.containsKey('success') && response['success'] == true) {
        final data = response['data'] as List<dynamic>;
        final pagination = response['pagination'] as Map<String, dynamic>;
        print(
          '✅ CREDIT CUSTOMERS: Retrieved ${data.length} customers (page ${pagination['current_page']} of ${pagination['last_page']})',
        );
        return {
          'data': data.map((item) => Map<String, dynamic>.from(item)).toList(),
          'pagination': pagination,
        };
      } else {
        print(
          '⚠️ CREDIT CUSTOMERS: No data found in response, returning empty list',
        );
        return {
          'data': [],
          'pagination': {
            'current_page': 1,
            'per_page': perPage,
            'total': 0,
            'last_page': 1,
          },
        };
      }
    } catch (e) {
      print('❌ CREDIT CUSTOMERS: Error fetching customers: $e');
      // Return mock data as fallback
      return _getMockCreditCustomersResponse();
    }
  }

  // Get all credit customers from all pages
  static Future<List<Map<String, dynamic>>> getAllCreditCustomers() async {
    try {
      print('📊 CREDIT CUSTOMERS: Fetching all credit customers from API');

      // Call the API directly without pagination
      final response = await ApiService.get('/customers');

      if (response.containsKey('success') && response['success'] == true) {
        final data = response['data'] as List<dynamic>;
        final customers = data
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        print(
          '✅ CREDIT CUSTOMERS: Retrieved ${customers.length} total customers',
        );
        return customers;
      } else {
        print('⚠️ CREDIT CUSTOMERS: No data found in response');
        return [];
      }
    } catch (e) {
      print('❌ CREDIT CUSTOMERS: Error fetching all customers: $e');
      return _getMockCreditCustomers();
    }
  }

  // Get credit customer by ID
  static Future<Map<String, dynamic>?> getCreditCustomerById(String id) async {
    try {
      print('📊 CREDIT CUSTOMER: Fetching customer $id from API');
      final response = await ApiService.get('/customers/$id');

      if (response.containsKey('success') &&
          response['success'] == true &&
          response.containsKey('data')) {
        print('✅ CREDIT CUSTOMER: Retrieved customer $id');
        return Map<String, dynamic>.from(response['data']);
      } else {
        print('⚠️ CREDIT CUSTOMER: No data found for customer $id');
        return null;
      }
    } catch (e) {
      print('❌ CREDIT CUSTOMER: Error fetching customer $id: $e');
      return null;
    }
  }

  // Create new credit customer
  static Future<Map<String, dynamic>> createCreditCustomer(
    Map<String, dynamic> customerData,
  ) async {
    try {
      print('📝 CREDIT CUSTOMER: Creating new credit customer');
      final response = await ApiService.post('/customers', customerData);

      if (response.containsKey('success') &&
          response['success'] == true &&
          response.containsKey('data')) {
        print('✅ CREDIT CUSTOMER: Created customer successfully');
        return Map<String, dynamic>.from(response['data']);
      } else {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      print('❌ CREDIT CUSTOMER: Error creating customer: $e');
      throw e;
    }
  }

  // Update credit customer
  static Future<Map<String, dynamic>> updateCreditCustomer(
    String id,
    Map<String, dynamic> customerData,
  ) async {
    try {
      print('📝 CREDIT CUSTOMER: Updating customer $id');
      final response = await ApiService.put('/customers/$id', customerData);

      if (response.containsKey('success') &&
          response['success'] == true &&
          response.containsKey('data')) {
        print('✅ CREDIT CUSTOMER: Updated customer $id successfully');
        return Map<String, dynamic>.from(response['data']);
      } else {
        throw Exception('Invalid response format');
      }
    } catch (e) {
      print('❌ CREDIT CUSTOMER: Error updating customer $id: $e');
      throw e;
    }
  }

  // Delete credit customer
  static Future<bool> deleteCreditCustomer(String id) async {
    try {
      print('🗑️ CREDIT CUSTOMER: Deleting customer $id');
      final response = await ApiService.delete('/customers/$id');

      if (response.containsKey('success') && response['success'] == true) {
        print('✅ CREDIT CUSTOMER: Deleted customer $id successfully');
        return true;
      } else {
        return false;
      }
    } catch (e) {
      print('❌ CREDIT CUSTOMER: Error deleting customer $id: $e');
      return false;
    }
  }

  // Mock data fallback
  static List<Map<String, dynamic>> _getMockCreditCustomers() {
    return [
      {
        'id': '1',
        'code': 'CC001',
        'name': 'John Doe',
        'cnic': '12345-6789012-3',
        'phone': '+92-300-1234567',
        'totalPending': 2500.0,
        'paidAmount': 1500.0,
        'address': '123 Main St, Lahore',
        'city': 'Lahore',
        'secondPersonName': 'Jane Doe',
        'secondPersonCnic': '12345-6789012-4',
        'secondPersonPhone': '+92-300-1234568',
        'picture': null,
        'paymentRecords': [
          {
            'invoiceNumber': 'INV-001',
            'date': DateTime(2025, 10, 1),
            'totalAmount': 1000.0,
            'paidAmount': 600.0,
            'pendingAmount': 400.0,
          },
          {
            'invoiceNumber': 'INV-002',
            'date': DateTime(2025, 10, 5),
            'totalAmount': 1500.0,
            'paidAmount': 900.0,
            'pendingAmount': 600.0,
          },
        ],
      },
      {
        'id': '2',
        'code': 'CC002',
        'name': 'Ahmed Khan',
        'cnic': '23456-7890123-4',
        'phone': '+92-301-2345678',
        'totalPending': 1800.0,
        'paidAmount': 1200.0,
        'address': '456 Market Rd, Karachi',
        'city': 'Karachi',
        'secondPersonName': 'Sara Khan',
        'secondPersonCnic': '23456-7890123-5',
        'secondPersonPhone': '+92-301-2345679',
        'picture': null,
        'paymentRecords': [
          {
            'invoiceNumber': 'INV-003',
            'date': DateTime(2025, 9, 28),
            'totalAmount': 1800.0,
            'paidAmount': 1200.0,
            'pendingAmount': 600.0,
          },
        ],
      },
      {
        'id': '3',
        'code': 'CC003',
        'name': 'Maria Santos',
        'cnic': '34567-8901234-5',
        'phone': '+92-302-3456789',
        'totalPending': 3200.0,
        'paidAmount': 800.0,
        'address': '789 Plaza Ave, Islamabad',
        'city': 'Islamabad',
        'secondPersonName': 'Carlos Santos',
        'secondPersonCnic': '34567-8901234-6',
        'secondPersonPhone': '+92-302-3456790',
        'picture': null,
        'paymentRecords': [
          {
            'invoiceNumber': 'INV-004',
            'date': DateTime(2025, 10, 3),
            'totalAmount': 2000.0,
            'paidAmount': 500.0,
            'pendingAmount': 1500.0,
          },
          {
            'invoiceNumber': 'INV-005',
            'date': DateTime(2025, 10, 7),
            'totalAmount': 2000.0,
            'paidAmount': 300.0,
            'pendingAmount': 1700.0,
          },
        ],
      },
    ];
  }

  // Mock response fallback
  static Map<String, dynamic> _getMockCreditCustomersResponse() {
    final customers = _getMockCreditCustomers();
    return {
      'data': customers,
      'pagination': {
        'current_page': 1,
        'per_page': 10,
        'total': customers.length,
        'last_page': 1,
      },
    };
  }
}
