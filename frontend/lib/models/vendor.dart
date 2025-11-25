class Vendor {
  final int id;
  final String firstName;
  final String lastName;
  final String? cnic;
  final String? address;
  final String cityId;
  final String status;
  final String createdAt;
  final String updatedAt;
  final City city;
  final String? email;
  final String? phone;

  Vendor({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.cnic,
    this.address,
    required this.cityId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.city,
    this.email,
    this.phone,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      cnic: json['cnic'] as String?,
      address: json['address'] as String?,
      cityId: json['city_id']?.toString() ?? '',
      status: json['status'],
      createdAt: json['created_at'] ?? DateTime.now().toIso8601String(),
      updatedAt: json['updated_at'] ?? DateTime.now().toIso8601String(),
      city: City(
        id: int.tryParse(json['city_id']?.toString() ?? '0') ?? 0,
        title: json['cityName'] ?? 'Unknown City',
        stateId: '0', // Default value since not provided
        status: 'Active', // Default value since not provided
        createdAt: DateTime.now().toIso8601String(),
        updatedAt: DateTime.now().toIso8601String(),
      ),
      email: json['email'] as String?,
      phone: json['phone'] as String?,
    );
  }

  String get fullName => '$firstName $lastName';
  String get vendorCode => 'V${id.toString().padLeft(3, '0')}';
}

class City {
  final int id;
  final String title;
  final String stateId;
  final String status;
  final String createdAt;
  final String updatedAt;

  City({
    required this.id,
    required this.title,
    required this.stateId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory City.fromJson(Map<String, dynamic> json) {
    return City(
      id: json['id'],
      title: json['title'],
      stateId: json['state_id'],
      status: json['status'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }
}

class VendorResponse {
  final List<Vendor> data;
  final Links links;
  final Meta meta;

  VendorResponse({required this.data, required this.links, required this.meta});

  factory VendorResponse.fromJson(Map<String, dynamic> json) {
    return VendorResponse(
      data:
          (json['data'] as List<dynamic>?)
              ?.map((item) => Vendor.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      links: json['links'] != null ? Links.fromJson(json['links']) : Links(),
      meta: json['meta'] != null
          ? Meta.fromJson(json['meta'])
          : Meta(
              currentPage: 1,
              lastPage: 1,
              links: [],
              path: "/vendors",
              perPage: 10,
              total: (json['data'] as List<dynamic>?)?.length ?? 0,
            ),
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
      first: json['first'] as String?,
      last: json['last'] as String?,
      prev: json['prev'] as String?,
      next: json['next'] as String?,
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
              ?.map((item) => Link.fromJson(item as Map<String, dynamic>))
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
      url: json['url'] as String?,
      label: json['label'] as String? ?? '',
      page: json['page'] as int?,
      active: json['active'] as bool? ?? false,
    );
  }
}
