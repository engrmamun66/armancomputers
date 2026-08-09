import 'lookup.dart';

class BrandModel {
  final int id;
  final String name;
  final String slug;
  final String? description;
  final StatusModel? status;
  final int? productsCount;
  final String? createdAt;

  BrandModel({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.status,
    this.productsCount,
    this.createdAt,
  });

  factory BrandModel.fromJson(Map<String, dynamic> json) => BrandModel(
        id: json['id'] as int,
        name: json['name'] as String,
        slug: json['slug'] as String? ?? '',
        description: json['description'] as String?,
        status: json['status'] != null ? StatusModel.fromJson(json['status'] as Map<String, dynamic>) : null,
        productsCount: (json['products_count'] as num?)?.toInt(),
        createdAt: json['created_at'] as String?,
      );
}
