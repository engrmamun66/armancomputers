import 'customer.dart';
import 'line_item.dart';
import 'lookup.dart';

class InvoiceModel {
  final int id;
  final String invoiceNumber;
  final int? saleId;
  final CustomerRef? customer;
  final String invoiceDate;
  final double subtotal;
  final double discount;
  final double additionalCost;
  final double grandTotal;
  final double paidAmount;
  final double dueAmount;
  final String? paymentStatus;
  final StatusModel? status;
  final String? createdBy;
  final List<LineItem> items;
  final String? createdAt;

  InvoiceModel({
    required this.id,
    required this.invoiceNumber,
    this.saleId,
    this.customer,
    required this.invoiceDate,
    required this.subtotal,
    required this.discount,
    required this.additionalCost,
    required this.grandTotal,
    required this.paidAmount,
    required this.dueAmount,
    this.paymentStatus,
    this.status,
    this.createdBy,
    this.items = const [],
    this.createdAt,
  });

  factory InvoiceModel.fromJson(Map<String, dynamic> json) => InvoiceModel(
        id: json['id'] as int,
        invoiceNumber: json['invoice_number'] as String,
        saleId: (json['sale_id'] as num?)?.toInt(),
        customer: json['customer'] != null ? CustomerRef.fromJson(json['customer'] as Map<String, dynamic>) : null,
        invoiceDate: json['invoice_date'] as String,
        subtotal: (json['subtotal'] as num).toDouble(),
        discount: (json['discount'] as num).toDouble(),
        additionalCost: (json['additional_cost'] as num).toDouble(),
        grandTotal: (json['grand_total'] as num).toDouble(),
        paidAmount: (json['paid_amount'] as num).toDouble(),
        dueAmount: (json['due_amount'] as num).toDouble(),
        paymentStatus: json['payment_status'] as String?,
        status: json['status'] != null ? StatusModel.fromJson(json['status'] as Map<String, dynamic>) : null,
        createdBy: json['created_by'] as String?,
        items: (json['items'] as List<dynamic>? ?? [])
            .map((e) => LineItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: json['created_at'] as String?,
      );
}
