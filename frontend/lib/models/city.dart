class Country {
  final int id;
  final String title;
  final String code;
  final String currency;
  final String status;
  final String createdAt;
  final String updatedAt;

  Country({
    required this.id,
    required this.title,
    required this.code,
    required this.currency,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      code: json['code'] ?? '',
      currency: json['currency'] ?? '',
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'code': code,
      'currency': currency,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class State {
  final int id;
  final String title;
  final String countryId;
  final String status;
  final String createdAt;
  final String updatedAt;
  final Country country;

  State({
    required this.id,
    required this.title,
    required this.countryId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.country,
  });

  factory State.fromJson(Map<String, dynamic> json) {
    return State(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      countryId: json['country_id']?.toString() ?? '',
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      country: json['country'] != null
          ? Country.fromJson(json['country'])
          : Country(
              id: 0,
              title: '',
              code: '',
              currency: '',
              status: '',
              createdAt: '',
              updatedAt: '',
            ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'country_id': countryId,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'country': country.toJson(),
    };
  }
}

class City {
  final int id;
  final String title;
  final String stateId;
  final String status;
  final String createdAt;
  final String updatedAt;
  final State state;

  City({
    required this.id,
    required this.title,
    required this.stateId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.state,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'] ?? 0,
      title:
          json['title'] ??
          json['city'] ??
          '', // Support both 'title' and 'city' fields
      stateId: json['state_id']?.toString() ?? '',
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      state: json['state'] != null && json['state'] is Map
          ? State.fromJson(json['state'])
          : State(
              id: 0,
              title:
                  json['state'] ?? '', // Use string if state is not an object
              countryId: '',
              status: '',
              createdAt: '',
              updatedAt: '',
              country: Country(
                id: 0,
                title: json['country'] ?? '',
                code: '',
                currency: '',
                status: '',
                createdAt: '',
                updatedAt: '',
              ),
            ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'state_id': stateId,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
      'state': state.toJson(),
    };
  }
}

class CityPagination {
  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;

  CityPagination({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  factory CityPagination.fromJson(Map<String, dynamic> json) {
    return CityPagination(
      currentPage: json['current_page'] ?? 1,
      perPage: json['per_page'] ?? 10,
      total: json['total'] ?? 0,
      lastPage: json['last_page'] ?? 1,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'current_page': currentPage,
      'per_page': perPage,
      'total': total,
      'last_page': lastPage,
    };
  }
}

class CityResponse {
  final bool success;
  final List<City> data;
  final CityPagination pagination;

  CityResponse({
    required this.success,
    required this.data,
    required this.pagination,
  });

  factory CityResponse.fromJson(Map<String, dynamic> json) {
    return CityResponse(
      success:
          json['success'] ??
          json['status'] ??
          false, // Support both 'success' and 'status' fields
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => City.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      pagination: json['pagination'] != null
          ? CityPagination.fromJson(json['pagination'])
          : CityPagination(currentPage: 1, perPage: 10, total: 0, lastPage: 1),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'success': success,
      'data': data.map((city) => city.toJson()).toList(),
      'pagination': pagination.toJson(),
    };
  }
}

class SingleCityResponse {
  final bool success;
  final City data;

  SingleCityResponse({required this.success, required this.data});

  factory SingleCityResponse.fromJson(Map<String, dynamic> json) {
    return SingleCityResponse(
      success: json['success'] ?? false,
      data: json['data'] != null
          ? City.fromJson(json['data'])
          : City(
              id: 0,
              title: '',
              stateId: '',
              status: '',
              createdAt: '',
              updatedAt: '',
              state: State(
                id: 0,
                title: '',
                countryId: '',
                status: '',
                createdAt: '',
                updatedAt: '',
                country: Country(
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
  }

  Map<String, dynamic> toJson() {
    return {'success': success, 'data': data.toJson()};
  }
}

class CreateCityResponse {
  final bool success;
  final String message;
  final City data;

  CreateCityResponse({
    required this.success,
    required this.message,
    required this.data,
  });

  factory CreateCityResponse.fromJson(Map<String, dynamic> json) {
    return CreateCityResponse(
      success: json['success'] ?? false,
      message: json['message'] ?? '',
      data: json['data'] != null
          ? City.fromJson(json['data'])
          : City(
              id: 0,
              title: '',
              stateId: '',
              status: '',
              createdAt: '',
              updatedAt: '',
              state: State(
                id: 0,
                title: '',
                countryId: '',
                status: '',
                createdAt: '',
                updatedAt: '',
                country: Country(
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
  }

  Map<String, dynamic> toJson() {
    return {'success': success, 'message': message, 'data': data.toJson()};
  }
}
