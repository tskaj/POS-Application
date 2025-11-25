import 'services.dart'; // Import the main ApiService
import '../models/city.dart'; // Import the City models

class CityService {
  // Get base URL from ApiService
  static String get baseUrl => ApiService.baseUrl;

  // Get all cities
  static Future<CityResponse> getAllCities({
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final response = await ApiService.get(
        '/cities?page=$page&per_page=$perPage',
      );

      // Handle both 'success' and 'status' fields in response
      final bool isSuccess =
          response['success'] == true || response['status'] == true;

      if (isSuccess) {
        return CityResponse.fromJson(response);
      } else {
        throw Exception(
          'Failed to fetch cities: ${response['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      print('Error fetching cities: $e');
      throw Exception('Failed to fetch cities: $e');
    }
  }

  // Get cities by state
  static Future<List<City>> getCitiesByState(int stateId) async {
    try {
      final response = await ApiService.get('/cities?state_id=$stateId');

      // Handle both 'success' and 'status' fields in response
      final bool isSuccess =
          response['success'] == true || response['status'] == true;

      if (isSuccess) {
        final cityResponse = CityResponse.fromJson(response);
        return cityResponse.data;
      } else {
        throw Exception(
          'Failed to fetch cities by state: ${response['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      print('Error fetching cities by state: $e');
      throw Exception('Failed to fetch cities by state: $e');
    }
  }

  // Get active cities only
  static Future<List<City>> getActiveCities() async {
    try {
      final response = await ApiService.get('/cities?status=active');

      // Handle both 'success' and 'status' fields in response
      final bool isSuccess =
          response['success'] == true || response['status'] == true;

      if (isSuccess) {
        final cityResponse = CityResponse.fromJson(response);
        return cityResponse.data
            .where((city) => city.status.toLowerCase() == 'active')
            .toList();
      } else {
        throw Exception(
          'Failed to fetch active cities: ${response['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      print('Error fetching active cities: $e');
      throw Exception('Failed to fetch active cities: $e');
    }
  }

  // Search cities by name
  static Future<List<City>> searchCities(String query) async {
    try {
      final response = await ApiService.get('/cities?search=$query');

      // Handle both 'success' and 'status' fields in response
      final bool isSuccess =
          response['success'] == true || response['status'] == true;

      if (isSuccess) {
        final cityResponse = CityResponse.fromJson(response);
        return cityResponse.data;
      } else {
        throw Exception(
          'Failed to search cities: ${response['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      print('Error searching cities: $e');
      throw Exception('Failed to search cities: $e');
    }
  }

  // Get specific city by ID
  static Future<SingleCityResponse> getCityById(int cityId) async {
    try {
      final response = await ApiService.get('/cities/$cityId');

      // Handle both 'success' and 'status' fields in response
      final bool isSuccess =
          response['success'] == true || response['status'] == true;

      if (isSuccess) {
        return SingleCityResponse.fromJson(response);
      } else {
        throw Exception(
          'Failed to fetch city: ${response['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      print('Error fetching city by ID: $e');
      throw Exception('Failed to fetch city: $e');
    }
  }

  // Create a new city
  static Future<CreateCityResponse> createCity({
    required String title,
    required int stateId,
    required String status,
  }) async {
    try {
      final requestBody = {
        'title': title,
        'state_id': stateId,
        'status': status,
      };

      final response = await ApiService.post('/cities', requestBody);

      // Handle both 'success' and 'status' fields in response
      final bool isSuccess =
          response['success'] == true || response['status'] == true;

      if (isSuccess) {
        return CreateCityResponse.fromJson(response);
      } else {
        throw Exception(
          'Failed to create city: ${response['message'] ?? 'Unknown error'}',
        );
      }
    } catch (e) {
      print('Error creating city: $e');
      throw Exception('Failed to create city: $e');
    }
  }
}
