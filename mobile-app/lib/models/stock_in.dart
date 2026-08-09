import 'line_item.dart';
import 'lookup.dart';

class StockInModel {
  final int id;
  final String referenceNo;
  final String? supplierName;
  final String? supplierPhone;
  final String purchaseDate;
  final double subtotal;
  final double discount;
  final double additionalCost;
  final double grandTotal;
  final String? notes;
  final StatusModel? status;
  final String? createdBy;
  final int? itemsCount;
  final int? totalQty;
  final List<LineItem> items;
  final String? createdAt;

  StockInModel({
    required this.id,
    required this.referenceNo,
    this.supplierName,
    this.supplierPhone,
    required this.purchaseDate,
    required this.subtotal,
    required this.discount,
    required this.additionalCost,
    required this.grandTotal,
    this.notes,
    this.status,
    this.createdBy,
    this.itemsCount,
    this.totalQty,
    this.items = const [],
    this.createdAt,
  });

  factory StockInModel.fromJson(Map<String, dynamic> json) => StockInModel(
        id: json['id'] as int,
        referenceNo: json['reference_no'] as String,
        supplierName: json['supplier_name'] as String?,
        supplierPhone: json['supplier_phone'] as String?,
        purchaseDate: json['purchase_date'] as String,
        subtotal: (json['subtotal'] as num).toDouble(),
        discount: (json['discount'] as num).toDouble(),
        additionalCost: (json['additional_cost'] as num).toDouble(),
        grandTotal: (json['grand_total'] as num).toDouble(),
        notes: json['notes'] as String?,
        status: json['status'] != null ? StatusModel.fromJson(json['status'] as Map<String, dynamic>) : null,
        createdBy: json['created_by'] as String?,
        itemsCount: (json['items_count'] as num?)?.toInt(),
        totalQty: (json['total_qty'] as num?)?.toInt(),
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => LineItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: json['created_at'] as String?,
      );
}
