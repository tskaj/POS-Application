class Season {
  final int id;
  final String title;
  final String status;
  final String createdAt;
  final String updatedAt;

  Season({
    required this.id,
    required this.title,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Season.fromJson(Map<String, dynamic> json) {
    return Season(
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

class SeasonResponse {
  final List<Season> data;
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  SeasonResponse({
    required this.data,
    required this.currentPage,
    required this.lastPage,
    required this.perPage,
    required this.total,
  });

  factory SeasonResponse.fromJson(Map<String, dynamic> json) {
    return SeasonResponse(
      data: (json['data'] as List)
          .map((item) => Season.fromJson(item))
          .toList(),
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
