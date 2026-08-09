class DashboardCards {
  final int totalProducts;
  final int totalStockQuantity;
  final int totalStockIn;
  final int totalStockOut;
  final double todaysSales;
  final double todaysStockIn;
  final int totalCustomers;
  final int lowStockProducts;
  final int outOfStockProducts;

  DashboardCards({
    required this.totalProducts,
    required this.totalStockQuantity,
    required this.totalStockIn,
    required this.totalStockOut,
    required this.todaysSales,
    required this.todaysStockIn,
    required this.totalCustomers,
    required this.lowStockProducts,
    required this.outOfStockProducts,
  });

  factory DashboardCards.fromJson(Map<String, dynamic> json) => DashboardCards(
        totalProducts: (json['total_products'] as num).toInt(),
        totalStockQuantity: (json['total_stock_quantity'] as num).toInt(),
        totalStockIn: (json['total_stock_in'] as num).toInt(),
        totalStockOut: (json['total_stock_out'] as num).toInt(),
        todaysSales: (json['todays_sales'] as num).toDouble(),
        todaysStockIn: (json['todays_stock_in'] as num).toDouble(),
        totalCustomers: (json['total_customers'] as num).toInt(),
        lowStockProducts: (json['low_stock_products'] as num).toInt(),
        outOfStockProducts: (json['out_of_stock_products'] as num).toInt(),
      );
}

class StockMovementPoint {
  final String date;
  final int stockInQty;
  final int stockOutQty;

  StockMovementPoint({required this.date, required this.stockInQty, required this.stockOutQty});

  factory StockMovementPoint.fromJson(Map<String, dynamic> json) => StockMovementPoint(
        date: json['date'] as String,
        stockInQty: (json['stock_in_qty'] as num).toInt(),
        stockOutQty: (json['stock_out_qty'] as num).toInt(),
      );
}

class SalesPoint {
  final String date;
  final double total;

  SalesPoint({required this.date, required this.total});

  factory SalesPoint.fromJson(Map<String, dynamic> json) =>
      SalesPoint(date: json['date'] as String, total: (json['total'] as num).toDouble());
}

class TopProduct {
  final String name;
  final int qtySold;

  TopProduct({required this.name, required this.qtySold});

  factory TopProduct.fromJson(Map<String, dynamic> json) =>
      TopProduct(name: json['name'] as String, qtySold: (json['qty_sold'] as num).toInt());
}

class LowStockProduct {
  final int id;
  final String name;
  final String sku;
  final int currentStock;
  final int minimumStock;

  LowStockProduct({
    required this.id,
    required this.name,
    required this.sku,
    required this.currentStock,
    required this.minimumStock,
  });

  factory LowStockProduct.fromJson(Map<String, dynamic> json) => LowStockProduct(
        id: json['id'] as int,
        name: json['name'] as String,
        sku: json['sku'] as String,
        currentStock: (json['current_stock'] as num).toInt(),
        minimumStock: (json['minimum_stock'] as num).toInt(),
      );
}

class RecentStockIn {
  final int id;
  final String referenceNo;
  final String purchaseDate;
  final String? supplierName;
  final double grandTotal;
  final String? createdBy;

  RecentStockIn({
    required this.id,
    required this.referenceNo,
    required this.purchaseDate,
    this.supplierName,
    required this.grandTotal,
    this.createdBy,
  });

  factory RecentStockIn.fromJson(Map<String, dynamic> json) => RecentStockIn(
        id: json['id'] as int,
        referenceNo: json['reference_no'] as String,
        purchaseDate: json['purchase_date'] as String,
        supplierName: json['supplier_name'] as String?,
        grandTotal: (json['grand_total'] as num).toDouble(),
        createdBy: json['created_by'] as String?,
      );
}

class RecentStockOut {
  final int id;
  final String referenceNo;
  final String saleDate;
  final String? customerName;
  final double grandTotal;

  RecentStockOut({
    required this.id,
    required this.referenceNo,
    required this.saleDate,
    this.customerName,
    required this.grandTotal,
  });

  factory RecentStockOut.fromJson(Map<String, dynamic> json) => RecentStockOut(
        id: json['id'] as int,
        referenceNo: json['reference_no'] as String,
        saleDate: json['sale_date'] as String,
        customerName: json['customer_name'] as String?,
        grandTotal: (json['grand_total'] as num).toDouble(),
      );
}

class DashboardData {
  final DashboardCards cards;
  final List<StockMovementPoint> stockMovement;
  final List<SalesPoint> salesOverview;
  final List<TopProduct> topSellingProducts;
  final List<LowStockProduct> lowStockProducts;
  final List<RecentStockIn> recentStockIns;
  final List<RecentStockOut> recentStockOuts;

  DashboardData({
    required this.cards,
    required this.stockMovement,
    required this.salesOverview,
    required this.topSellingProducts,
    required this.lowStockProducts,
    required this.recentStockIns,
    required this.recentStockOuts,
  });

  factory DashboardData.fromJson(Map<String, dynamic> json) => DashboardData(
        cards: DashboardCards.fromJson(json['cards'] as Map<String, dynamic>),
        stockMovement: (json['stock_movement'] as List<dynamic>)
            .map((e) => StockMovementPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        salesOverview: (json['sales_overview'] as List<dynamic>)
            .map((e) => SalesPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        topSellingProducts: (json['top_selling_products'] as List<dynamic>)
            .map((e) => TopProduct.fromJson(e as Map<String, dynamic>))
            .toList(),
        lowStockProducts: (json['low_stock_products'] as List<dynamic>)
            .map((e) => LowStockProduct.fromJson(e as Map<String, dynamic>))
            .toList(),
        recentStockIns: (json['recent_stock_ins'] as List<dynamic>)
            .map((e) => RecentStockIn.fromJson(e as Map<String, dynamic>))
            .toList(),
        recentStockOuts: (json['recent_stock_outs'] as List<dynamic>)
            .map((e) => RecentStockOut.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
