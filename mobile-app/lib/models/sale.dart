import 'customer.dart';
import 'line_item.dart';
import 'lookup.dart';

class SaleModel {
  final int id;
  final String referenceNo;
  final CustomerRef? customer;
  final String saleDate;
  final double subtotal;
  final double discount;
  final double additionalCost;
  final double grandTotal;
  final double paidAmount;
  final double dueAmount;
  final String paymentMethod;
  final String? paymentStatus; // paid | partial | due
  final String? notes;
  final StatusModel? status;
  final String? createdBy;
  final int? invoiceId;
  final int? itemsCount;
  final int? totalQty;
  final List<LineItem> items;
  final String? createdAt;

  SaleModel({
    required this.id,
    required this.referenceNo,
    this.customer,
    required this.saleDate,
    required this.subtotal,
    required this.discount,
    required this.additionalCost,
    required this.grandTotal,
    required this.paidAmount,
    required this.dueAmount,
    required this.paymentMethod,
    this.paymentStatus,
    this.notes,
    this.status,
    this.createdBy,
    this.invoiceId,
    this.itemsCount,
    this.totalQty,
    this.items = const [],
    this.createdAt,
  });

  factory SaleModel.fromJson(Map<String, dynamic> json) => SaleModel(
        id: json['id'] as int,
        referenceNo: json['reference_no'] as String,
        customer: json['customer'] != null ? CustomerRef.fromJson(json['customer'] as Map<String, dynamic>) : null,
        saleDate: json['sale_date'] as String,
        subtotal: (json['subtotal'] as num).toDouble(),
        discount: (json['discount'] as num).toDouble(),
        additionalCost: (json['additional_cost'] as num).toDouble(),
        grandTotal: (json['grand_total'] as num).toDouble(),
        paidAmount: (json['paid_amount'] as num).toDouble(),
        dueAmount: (json['due_amount'] as num).toDouble(),
        paymentMethod: json['payment_method'] as String? ?? 'cash',
        paymentStatus: json['payment_status'] as String?,
        notes: json['notes'] as String?,
        status: json['status'] != null ? StatusModel.fromJson(json['status'] as Map<String, dynamic>) : null,
        createdBy: json['created_by'] as String?,
        invoiceId: (json['invoice_id'] as num?)?.toInt(),
        itemsCount: (json['items_count'] as num?)?.toInt(),
        totalQty: (json['total_qty'] as num?)?.toInt(),
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => LineItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: json['created_at'] as String?,
      );
}

const kPaymentMethods = [
  {'value': 'cash', 'label': 'Cash'},
  {'value': 'bank', 'label': 'Bank'},
  {'value': 'card', 'label': 'Card'},
  {'value': 'mobile_banking', 'label': 'Mobile Banking'},
  {'value': 'other', 'label': 'Other'},
];
