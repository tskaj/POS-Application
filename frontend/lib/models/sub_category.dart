import 'category.dart';

class SubCategory {
  final int id;
  final String title;
  final String? imgPath;
  final int categoryId;
  final String status;
  final String createdAt;
  final String updatedAt;
  final Category? category;

  SubCategory({
    required this.id,
    required this.title,
    this.imgPath,
    required this.categoryId,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.category,
  });

  factory SubCategory.fromJson(Map<String, dynamic> json) {
    return SubCategory(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      imgPath:
          json['img_url'] ??
          json['img_path'], // Handle both img_url and img_path
      categoryId: int.tryParse(json['category_id'].toString()) ?? 0,
      status: json['status'] ?? '',
      createdAt: json['created_at'] ?? '',
      updatedAt: json['updated_at'] ?? '',
      category: json['category'] != null
          ? Category.fromJson(json['category'])
          : null,
    );
  }

  String get subCategoryCode => 'SC${id.toString().padLeft(3, '0')}';
}

class SubCategoryResponse {
  final List<SubCategory> data;
  final Links links;
  final Meta meta;

  SubCategoryResponse({
    required this.data,
    required this.links,
    required this.meta,
  });

  factory SubCategoryResponse.fromJson(Map<String, dynamic> json) {
    return SubCategoryResponse(
      data: (json['data'] as List? ?? [])
          .map((item) => SubCategory.fromJson(item))
          .toList(),
      links: Links.fromJson(json['links'] ?? {}),
      meta: Meta.fromJson(json['meta'] ?? {}),
    );
  }
}
