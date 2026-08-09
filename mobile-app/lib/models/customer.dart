import 'lookup.dart';

class CustomerModel {
  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final StatusModel? status;
  final int? totalPurchases;
  final double? totalPaid;
  final double? totalDue;
  final String? createdAt;

  CustomerModel({
    required this.id,
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.status,
    this.totalPurchases,
    this.totalPaid,
    this.totalDue,
    this.createdAt,
  });

  factory CustomerModel.fromJson(Map<String, dynamic> json) => CustomerModel(
        id: json['id'] as int,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
        status: json['status'] != null ? StatusModel.fromJson(json['status'] as Map<String, dynamic>) : null,
        totalPurchases: (json['total_purchases'] as num?)?.toInt(),
        totalPaid: (json['total_paid'] as num?)?.toDouble(),
        totalDue: (json['total_due'] as num?)?.toDouble(),
        createdAt: json['created_at'] as String?,
      );
}

/// The compact {id, name, phone} shape embedded in Sale/Invoice resources.
class CustomerRef {
  final int id;
  final String name;
  final String? phone;
  final String? email;
  final String? address;

  CustomerRef({required this.id, required this.name, this.phone, this.email, this.address});

  factory CustomerRef.fromJson(Map<String, dynamic> json) => CustomerRef(
        id: json['id'] as int,
        name: json['name'] as String,
        phone: json['phone'] as String?,
        email: json['email'] as String?,
        address: json['address'] as String?,
      );
}
