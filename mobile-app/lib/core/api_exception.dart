class ApiException implements Exception {
  final String message;
  final Map<String, List<String>>? errors;
  final int? statusCode;

  ApiException(this.message, {this.errors, this.statusCode});

  String? firstErrorFor(String field) => errors?[field]?.first;

  @override
  String toString() => message;
}
