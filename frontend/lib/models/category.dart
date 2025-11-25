import 'sub_category.dart';

class Category {
  final int id;
  final String title;
  final String? imgPath;
  final String status;
  final String createdAt;
  final String updatedAt;

  Category({
    required this.id,
    required this.title,
    this.imgPath,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      imgPath:
          json['img_url'] ??
          json['img_path'], // Handle both img_url and img_path
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
    );
  }

  String get categoryCode => 'C${id.toString().padLeft(3, '0')}';
}

class CategoryDetails {
  final int id;
  final String title;
  final String? imgPath;
  final String status;
  final String createdAt;
  final String updatedAt;
  final List<SubCategory> subcategories;

  CategoryDetails({
    required this.id,
    required this.title,
    this.imgPath,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    required this.subcategories,
  });

  factory CategoryDetails.fromJson(Map<String, dynamic> json) {
    return CategoryDetails(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      imgPath: json['img_url'], // Note: API uses img_url instead of img_path
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      subcategories: (json['subcategories'] as List? ?? [])
          .map((item) => SubCategory.fromJson(item))
          .toList(),
    );
  }

  String get categoryCode => 'C${id.toString().padLeft(3, '0')}';
}

class CategoryResponse {
  final List<Category> data;
  final Links links;
  final Meta meta;

  CategoryResponse({
    required this.data,
    required this.links,
    required this.meta,
  });

  factory CategoryResponse.fromJson(Map<String, dynamic> json) {
    return CategoryResponse(
      data: (json['data'] as List)
          .map((item) => Category.fromJson(item))
          .toList(),
      links: Links.fromJson(json['links']),
      meta: Meta.fromJson(json['meta']),
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
          (json['links'] as List?)
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
