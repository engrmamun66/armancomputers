import '../core/api_config.dart';
import 'brand.dart';
import 'lookup.dart';

class ProductImageModel {
  final int id;
  final String url;
  final bool isDefault;

  ProductImageModel({required this.id, required this.url, required this.isDefault});

  factory ProductImageModel.fromJson(Map<String, dynamic> json) => ProductImageModel(
        id: json['id'] as int,
        url: ApiConfig.resolveUrl(json['url'] as String),
        isDefault: json['is_default'] as bool? ?? false,
      );
}

class ProductModel {
  final int id;
  final BrandModel? brand;
  final String name;
  final String? barcode;
  final String? description;
  final double purchasePrice;
  final double sellingPrice;
  final int currentStock;
  final int minimumStock;
  final String? stockState; // out-of-stock | low-stock | in-stock
  final StatusModel? status;
  final String? imageUrl;
  final List<ProductImageModel> images;
  final String? createdAt;

  ProductModel({
    required this.id,
    this.brand,
    required this.name,
    this.barcode,
    this.description,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.currentStock,
    required this.minimumStock,
    this.stockState,
    this.status,
    this.imageUrl,
    this.images = const [],
    this.createdAt,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) => ProductModel(
        id: json['id'] as int,
        brand: json['brand'] != null ? BrandModel.fromJson(json['brand'] as Map<String, dynamic>) : null,
        name: json['name'] as String,
        barcode: json['barcode'] as String?,
        description: json['description'] as String?,
        purchasePrice: (json['purchase_price'] as num).toDouble(),
        sellingPrice: (json['selling_price'] as num).toDouble(),
        currentStock: (json['current_stock'] as num).toInt(),
        minimumStock: (json['minimum_stock'] as num).toInt(),
        stockState: json['stock_state'] as String?,
        status: json['status'] != null ? StatusModel.fromJson(json['status'] as Map<String, dynamic>) : null,
        imageUrl: json['image_url'] != null ? ApiConfig.resolveUrl(json['image_url'] as String) : null,
        images: (json['images'] as List<dynamic>? ?? [])
            .map((e) => ProductImageModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt: json['created_at'] as String?,
      );
}

class StockHistoryEntry {
  final String type; // in | out
  final String date;
  final String reference;
  final int quantity;
  final int stockBefore;
  final int stockAfter;

  StockHistoryEntry({
    required this.type,
    required this.date,
    required this.reference,
    required this.quantity,
    required this.stockBefore,
    required this.stockAfter,
  });

  factory StockHistoryEntry.fromJson(Map<String, dynamic> json) => StockHistoryEntry(
        type: json['type'] as String,
        date: json['date'] as String,
        reference: json['reference'] as String,
        quantity: (json['quantity'] as num).toInt(),
        stockBefore: (json['stock_before'] as num).toInt(),
        stockAfter: (json['stock_after'] as num).toInt(),
      );
}
