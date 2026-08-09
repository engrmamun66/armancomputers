/// Shared shape for StockInItem / StockOutItem / InvoiceItem — all three
/// resources on the backend serialize identically.
class LineItem {
  final int? id;
  final int productId;
  final String? productName;
  final String? sku;
  final int quantity;
  final double unitPrice;
  final double? totalPrice;

  LineItem({
    this.id,
    required this.productId,
    this.productName,
    this.sku,
    required this.quantity,
    required this.unitPrice,
    this.totalPrice,
  });

  factory LineItem.fromJson(Map<String, dynamic> json) => LineItem(
        id: json['id'] as int?,
        productId: json['product_id'] as int,
        productName: json['product_name'] as String?,
        sku: json['sku'] as String?,
        quantity: (json['quantity'] as num).toInt(),
        unitPrice: (json['unit_price'] as num).toDouble(),
        totalPrice: (json['total_price'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'product_id': productId,
        'quantity': quantity,
        'unit_price': unitPrice,
      };

  double get lineTotal => totalPrice ?? (quantity * unitPrice);
}
