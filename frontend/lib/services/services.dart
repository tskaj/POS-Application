import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/environment_config.dart';
import '../utils/utils.dart';

// Export finance services
export 'bank_services.dart';
export 'income_services.dart'
    show
        Income,
        IncomeCategory,
        IncomesResponse,
        IncomeService,
        PayIn,
        PayInResponse,
        Coa,
        SinglePayInResponse,
        IncomeCategoriesResponse,
        SingleIncomeCategoryResponse,
        DeleteResponse,
        SingleIncomeResponse;
export 'income_services.dart' hide TransactionType, User;
export 'chart_of_accounts_service.dart';
export 'account_statement_service.dart';
export 'payout_service.dart' hide User, TransactionType, Coa;
export 'cashflow_service.dart';

class ApiService {
  static String get baseUrl => EnvironmentConfig.apiBaseUrl;
  static const String loginEndpoint = '/login';
  static const String profileEndpoint = '/profile';
  static const String profilesEndpoint = '/profiles';

  // Check for duplicate phone numbers across vendors, customers, and employees
  static Future<Map<String, dynamic>> checkDuplicatePhone(
    String phoneNumber, {
    int? excludeEmployeeId,
    int? excludeCustomerId,
    int? excludeVendorId,
  }) async {
    // Import the utils function here to avoid circular imports
    final result = await checkDuplicatePhoneNumber(
      phoneNumber,
      excludeEmployeeId: excludeEmployeeId,
      excludeCustomerId: excludeCustomerId,
      excludeVendorId: excludeVendorId,
    );
    // If duplicate found, throw exception to match existing API pattern
    if (result['isDuplicate'] == true) {
      throw Exception('Phone number already exists');
    }
    return {'status': 'success'};
  }

  // Get user profile
  static Future<Map<String, dynamic>> getProfile(int userId) async {
    print('👤 API PROFILE: Getting user profile for user $userId');
    return await get('/users/$userId');
  }

  // Create user profile
  static Future<Map<String, dynamic>> createProfile(
    Map<String, dynamic> profileData,
  ) async {
    print('📝 API PROFILE: Creating profile');
    print('📤 Profile data: $profileData');
    return await post(profilesEndpoint, profileData);
  }

  // Login method
  static Future<Map<String, dynamic>> login(
    String email,
    String password,
  ) async {
    print('🔐 API LOGIN: Making login request to $baseUrl$loginEndpoint');
    print('📧 Email: $email');

    try {
      final requestBody = jsonEncode({'email': email, 'password': password});
      print('📤 Request Body: $requestBody');

      final response = await http.post(
        Uri.parse('$baseUrl$loginEndpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      );

      print('📡 Response Status: ${response.statusCode}');
      print('📨 Response Headers: ${response.headers}');
      print('📨 Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print(
          '✅ Login successful! Token: ${data['token']?.substring(0, 20)}...',
        );
        // Store token
        await _saveToken(data['token']);
        return data;
      } else {
        print('❌ Login failed with status ${response.statusCode}');
        // Try to parse error response
        try {
          final errorData = jsonDecode(response.body);
          print('📄 Error response: $errorData');
          if (errorData.containsKey('message')) {
            throw Exception('Login failed: ${errorData['message']}');
          } else if (errorData.containsKey('error')) {
            throw Exception('Login failed: ${errorData['error']}');
          }
        } catch (parseError) {
          print('📄 Could not parse error response: $parseError');
        }
        throw Exception(
          'Login failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('💥 Login error: $e');
      throw Exception('Network error: $e');
    }
  }

  // Save token to shared preferences
  static Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  // Get stored token
  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_token');
  }

  // Remove token (logout)
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  // Check if user is logged in
  static Future<bool> isLoggedIn() async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  // Generic GET request with auth token
  static Future<Map<String, dynamic>> get(String endpoint) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 GET Response Status: ${response.statusCode}');
      print('📨 GET Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        print('📄 GET Decoded Response: $decoded');
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          print('⚠️ GET Response is not a Map, returning empty Map');
          return {};
        }
      } else if (response.statusCode == 401) {
        // Token expired, logout
        await logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Request failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('💥 GET error: $e');
      throw Exception('Network error: $e');
    }
  }

  // Generic POST request with auth token
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      print('📡 POST Response Status: ${response.statusCode}');
      print('📨 POST Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        print('📄 POST Decoded Response: $decoded');
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          print('⚠️ POST Response is not a Map, returning empty Map');
          return {};
        }
      } else if (response.statusCode == 401) {
        // Token expired, logout
        await logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Request failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('💥 POST error: $e');
      throw Exception('Network error: $e');
    }
  }

  // Generic PUT request with auth token
  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.put(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(data),
      );

      print('📡 PUT Response Status: ${response.statusCode}');
      print('📨 PUT Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        print('📄 PUT Decoded Response: $decoded');
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          print('⚠️ PUT Response is not a Map, returning empty Map');
          return {};
        }
      } else if (response.statusCode == 401) {
        // Token expired, logout
        await logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Request failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('💥 PUT error: $e');
      throw Exception('Network error: $e');
    }
  }

  // Update user profile
  static Future<Map<String, dynamic>> updateProfile(
    int userId,
    Map<String, dynamic> profileData,
  ) async {
    print('📝 API PROFILE: Updating profile for user $userId');
    print('📤 Profile data: $profileData');

    final token = await getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.put(
        Uri.parse('$baseUrl$profilesEndpoint/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(profileData),
      );

      print('📡 PUT Response Status: ${response.statusCode}');
      print('📨 PUT Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        print('📄 PUT Decoded Response: $decoded');
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          print('⚠️ PUT Response is not a Map, returning empty Map');
          return {};
        }
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Profile update failed: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Profile update error: $e');
      throw Exception('Network error: $e');
    }
  }

  // Upload profile picture
  static Future<Map<String, dynamic>> uploadProfilePicture(
    int userId,
    String imagePath,
  ) async {
    print('🖼️ API PROFILE: Uploading profile picture for user $userId');

    final token = await getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$profilesEndpoint/$userId/upload-picture'),
      );

      request.headers.addAll({
        'Authorization': 'Bearer $token',
        'Accept': 'application/json',
      });

      request.files.add(
        await http.MultipartFile.fromPath('profile_picture', imagePath),
      );

      var response = await request.send();
      var responseData = await response.stream.bytesToString();

      print('📡 UPLOAD Response Status: ${response.statusCode}');
      print('📨 UPLOAD Response Body: $responseData');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(responseData);
        print('📄 UPLOAD Decoded Response: $decoded');
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          print('⚠️ UPLOAD Response is not a Map, returning empty Map');
          return {};
        }
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception('Upload failed: ${response.statusCode}');
      }
    } catch (e) {
      print('💥 Upload error: $e');
      throw Exception('Network error: $e');
    }
  }

  // Generic DELETE request with auth token
  static Future<Map<String, dynamic>> delete(String endpoint) async {
    final token = await getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl$endpoint'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 DELETE Response Status: ${response.statusCode}');
      print('📨 DELETE Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        final decoded = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {'status': true, 'message': 'Deleted successfully'};
        print('📄 DELETE Decoded Response: $decoded');
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          print('⚠️ DELETE Response is not a Map, returning empty Map');
          return {};
        }
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Delete failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('💥 Delete error: $e');
      throw Exception('Network error: $e');
    }
  }

  // Delete user
  static Future<Map<String, dynamic>> deleteUser(int userId) async {
    print('�️ API USER: Deleting user $userId');

    final token = await getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/users/$userId'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 DELETE Response Status: ${response.statusCode}');
      print('📨 DELETE Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 204) {
        final decoded = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {};
        print('📄 DELETE Decoded Response: $decoded');
        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          print('⚠️ DELETE Response is not a Map, returning empty Map');
          return {};
        }
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Session expired. Please login again.');
      } else {
        throw Exception(
          'Delete failed: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      print('💥 Delete error: $e');
      throw Exception('Network error: $e');
    }
  }

  // Logout API call
  static Future<Map<String, dynamic>> logoutUser() async {
    print('🚪 API LOGOUT: Making logout request to $baseUrl/logout');

    final token = await getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 LOGOUT Response Status: ${response.statusCode}');
      print('📨 LOGOUT Response Body: ${response.body}');

      if (response.statusCode == 200) {
        final decoded = jsonDecode(response.body);
        print('📄 LOGOUT Decoded Response: $decoded');

        // Always logout locally after API call, regardless of response content
        await logout();

        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          print('⚠️ LOGOUT Response is not a Map, returning empty Map');
          return {};
        }
      } else {
        // Even if API call fails, logout locally
        print(
          '⚠️ LOGOUT API failed with status ${response.statusCode}, but logging out locally',
        );
        await logout();
        throw Exception('Logout API failed, but logged out locally');
      }
    } catch (e) {
      print('💥 LOGOUT error: $e');
      // Even if there's an error, logout locally
      await logout();
      throw Exception(
        'Network error during logout, but logged out locally: $e',
      );
    }
  }

  // Database Backup API call
  static Future<Map<String, dynamic>> createDatabaseBackup() async {
    print(
      '💾 API BACKUP: Making database backup request to $baseUrl/admin/db-backup',
    );

    final token = await getToken();
    if (token == null) {
      throw Exception('No authentication token found');
    }

    try {
      final response = await http.get(
        Uri.parse('$baseUrl/admin/db-backup'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      );

      print('📡 BACKUP Response Status: ${response.statusCode}');
      print('📨 BACKUP Response Body: ${response.body}');

      if (response.statusCode == 200 || response.statusCode == 201) {
        final decoded = jsonDecode(response.body);
        print('📄 BACKUP Decoded Response: $decoded');

        if (decoded is Map<String, dynamic>) {
          return decoded;
        } else {
          print('⚠️ BACKUP Response is not a Map, returning empty Map');
          return {};
        }
      } else if (response.statusCode == 401) {
        await logout();
        throw Exception('Session expired. Please login again.');
      } else {
        final errorBody = response.body.isNotEmpty
            ? jsonDecode(response.body)
            : {'message': 'Backup failed'};
        throw Exception(
          errorBody['message'] ??
              'Backup failed with status ${response.statusCode}',
        );
      }
    } catch (e) {
      print('💥 BACKUP error: $e');
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error during backup: $e');
    }
  }

  // Register new user
  static Future<Map<String, dynamic>> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    required String passwordConfirmation,
  }) async {
    print('👤 API REGISTER: Making registration request to $baseUrl/register');
    print('📧 Email: $email');
    print('👤 Name: $firstName $lastName');

    try {
      final requestBody = jsonEncode({
        'first_name': firstName,
        'last_name': lastName,
        'email': email,
        'password': password,
        'password_confirmation': passwordConfirmation,
      });
      print('📤 Request Body: $requestBody');

      final response = await http.post(
        Uri.parse('$baseUrl/register'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: requestBody,
      );

      print('📡 REGISTER Response Status: ${response.statusCode}');
      print('📨 REGISTER Response Body: ${response.body}');

      if (response.statusCode == 201 || response.statusCode == 200) {
        final data = jsonDecode(response.body);
        print('✅ Registration successful! Message: ${data['message']}');

        // Store token if provided
        if (data['token'] != null) {
          await _saveToken(data['token']);
        }

        return data;
      } else {
        print('❌ Registration failed with status ${response.statusCode}');
        // Try to parse error response
        try {
          final errorData = jsonDecode(response.body);
          print('📄 Error response: $errorData');
          if (errorData.containsKey('message')) {
            throw Exception(errorData['message']);
          } else if (errorData.containsKey('error')) {
            throw Exception(errorData['error']);
          } else if (errorData.containsKey('errors')) {
            // Handle validation errors
            final errors = errorData['errors'] as Map<String, dynamic>;
            final errorMessages = errors.values.expand((e) => e).toList();
            throw Exception(errorMessages.join(', '));
          } else {
            throw Exception(
              'Registration failed with status ${response.statusCode}',
            );
          }
        } catch (parseError) {
          print('📄 Could not parse error response: $parseError');
          throw Exception(
            'Registration failed: ${response.statusCode} - ${response.body}',
          );
        }
      }
    } catch (e) {
      print('💥 Registration error: $e');
      throw Exception('Network error: $e');
    }
  }
}
