class PageMeta {
  final int currentPage;
  final int lastPage;
  final int perPage;
  final int total;

  PageMeta({required this.currentPage, required this.lastPage, required this.perPage, required this.total});

  factory PageMeta.fromJson(Map<String, dynamic> json) => PageMeta(
        currentPage: (json['current_page'] as num?)?.toInt() ?? 1,
        lastPage: (json['last_page'] as num?)?.toInt() ?? 1,
        perPage: (json['per_page'] as num?)?.toInt() ?? 15,
        total: (json['total'] as num?)?.toInt() ?? 0,
      );

  bool get hasMore => currentPage < lastPage;
}

class PaginatedResponse<T> {
  final List<T> data;
  final PageMeta meta;
  final Map<String, dynamic>? totals;

  PaginatedResponse({required this.data, required this.meta, this.totals});

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) fromJson,
  ) {
    return PaginatedResponse(
      data: (json['data'] as List).map((e) => fromJson(e as Map<String, dynamic>)).toList(),
      meta: PageMeta.fromJson(json['meta'] as Map<String, dynamic>),
      totals: json['totals'] as Map<String, dynamic>?,
    );
  }
}
