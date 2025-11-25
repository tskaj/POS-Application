import '../services/services.dart';
import '../models/models.dart';

// Response models
class UsersResponse {
  final List<User> data;
  final Links links;
  final Meta meta;

  UsersResponse({required this.data, required this.links, required this.meta});

  factory UsersResponse.fromJson(Map<String, dynamic> json) {
    return UsersResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => User.fromJson(item))
              .toList() ??
          [],
      links: Links.fromJson(json['links'] ?? {}),
      meta: Meta.fromJson(json['meta'] ?? {}),
    );
  }
}

class Links {
  final String? first;
  final String? last;
  final String? prev;
  final String? next;

  Links({this.first, this.last, this.prev, this.next});

  factory Links.fromJson(Map<String, dynamic> json) {
    return Links(
      first: json['first'],
      last: json['last'],
      prev: json['prev'],
      next: json['next'],
    );
  }
}

class Meta {
  final int currentPage;
  final int? from;
  final int lastPage;
  final List<Link> links;
  final String path;
  final int perPage;
  final int? to;
  final int total;

  Meta({
    required this.currentPage,
    this.from,
    required this.lastPage,
    required this.links,
    required this.path,
    required this.perPage,
    this.to,
    required this.total,
  });

  factory Meta.fromJson(Map<String, dynamic> json) {
    return Meta(
      currentPage: json['current_page'] ?? 1,
      from: json['from'],
      lastPage: json['last_page'] ?? 1,
      links:
          (json['links'] as List<dynamic>?)
              ?.map((item) => Link.fromJson(item))
              .toList() ??
          [],
      path: json['path'] ?? '',
      perPage: json['per_page'] ?? 10,
      to: json['to'],
      total: json['total'] ?? 0,
    );
  }
}

class Link {
  final String? url;
  final String label;
  final int? page;
  final bool active;

  Link({this.url, required this.label, this.page, required this.active});

  factory Link.fromJson(Map<String, dynamic> json) {
    return Link(
      url: json['url'],
      label: json['label'] ?? '',
      page: json['page'],
      active: json['active'] ?? false,
    );
  }
}

// Service class
class UserService {
  static const String usersEndpoint = '/users';

  static Future<UsersResponse> getUsers({
    int page = 1,
    int perPage = 10,
  }) async {
    try {
      final queryParams = '?page=$page&per_page=$perPage';
      final response = await ApiService.get('$usersEndpoint$queryParams');

      if (response.containsKey('data')) {
        final usersResponse = UsersResponse.fromJson(response);
        return usersResponse;
      } else {
        return UsersResponse(
          data: [],
          links: Links(),
          meta: Meta(
            currentPage: 1,
            lastPage: 1,
            links: [],
            path: '',
            perPage: perPage,
            total: 0,
          ),
        );
      }
    } catch (e) {
      throw Exception('Failed to load users: $e');
    }
  }

  static Future<User> getUser(int userId) async {
    try {
      final response = await ApiService.get('$usersEndpoint/$userId');

      if (response.containsKey('data')) {
        return User.fromJson(response['data']);
      } else {
        throw Exception('User data not found');
      }
    } catch (e) {
      throw Exception('Failed to load user: $e');
    }
  }

  static Future<User> createUser(Map<String, dynamic> userData) async {
    try {
      final response = await ApiService.post(usersEndpoint, userData);

      if (response.containsKey('data')) {
        return User.fromJson(response['data']);
      } else {
        throw Exception('User creation failed');
      }
    } catch (e) {
      throw Exception('Failed to create user: $e');
    }
  }

  static Future<User> updateUser(
    int userId,
    Map<String, dynamic> userData,
  ) async {
    try {
      final response = await ApiService.put('$usersEndpoint/$userId', userData);

      if (response.containsKey('data')) {
        return User.fromJson(response['data']);
      } else {
        throw Exception('User update failed');
      }
    } catch (e) {
      throw Exception('Failed to update user: $e');
    }
  }

  static Future<void> deleteUser(int userId) async {
    try {
      await ApiService.post('$usersEndpoint/$userId/delete', {});
    } catch (e) {
      throw Exception('Failed to delete user: $e');
    }
  }
}
