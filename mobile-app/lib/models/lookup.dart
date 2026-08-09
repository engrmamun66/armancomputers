class RoleModel {
  final int id;
  final String name;
  final String slug;

  RoleModel({required this.id, required this.name, required this.slug});

  factory RoleModel.fromJson(Map<String, dynamic> json) =>
      RoleModel(id: json['id'] as int, name: json['name'] as String, slug: json['slug'] as String);
}

class StatusModel {
  final int id;
  final String name;
  final String slug;
  final String type;

  StatusModel({required this.id, required this.name, required this.slug, required this.type});

  factory StatusModel.fromJson(Map<String, dynamic> json) => StatusModel(
        id: json['id'] as int,
        name: json['name'] as String,
        slug: json['slug'] as String,
        type: json['type'] as String,
      );
}
