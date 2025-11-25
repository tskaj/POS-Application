class Size {
  final int id;
  final String title;
  final String status;
  final String createdAt;
  final String updatedAt;

  Size({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Size.fromJson(Map<String, dynamic> json) {
    return Size(
      id: json['id'],
      title: json['title'],
      status: json['status'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'status': status,
      'created_at': createdAt,
      'updated_at': updatedAt,
    };
  }
}

class SizeResponse {
  final List<Size> data;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  SizeResponse({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory SizeResponse.fromJson(Map<String, dynamic> json) {
    return SizeResponse(
      data: (json['data'] as List).map((item) => Size.fromJson(item)).toList(),
      currentPage: json['current_page'],
      lastPage: json['last_page'],
      perPage: json['per_page'],
      total: json['total'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data.map((item) => item.toJson()).toList(),
      'current_page': currentPage,
      'last_page': lastPage,
      'per_page': perPage,
      'total': total,
    };
  }
}
