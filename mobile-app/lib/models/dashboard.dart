class DashboardCards {
  final int totalProducts;
  final int totalStockQuantity;
  final int totalPurchases;
  final int totalSales;
  final double todaysSales;
  final double todaysPurchases;
  final int totalCustomers;
  final int lowStockProducts;
  final int outOfStockProducts;
  final double totalSalesAmount;
  final double totalPurchaseCost;
  final double totalProfit;
  final double totalDue;

  DashboardCards({
    required this.totalProducts,
    required this.totalStockQuantity,
    required this.totalPurchases,
    required this.totalSales,
    required this.todaysSales,
    required this.todaysPurchases,
    required this.totalCustomers,
    required this.lowStockProducts,
    required this.outOfStockProducts,
    required this.totalSalesAmount,
    required this.totalPurchaseCost,
    required this.totalProfit,
    required this.totalDue,
  });

  factory DashboardCards.fromJson(Map<String, dynamic> json) => DashboardCards(
        totalProducts: (json['total_products'] as num).toInt(),
        totalStockQuantity: (json['total_stock_quantity'] as num).toInt(),
        totalPurchases: (json['total_purchases'] as num).toInt(),
        totalSales: (json['total_sales'] as num).toInt(),
        todaysSales: (json['todays_sales'] as num).toDouble(),
        todaysPurchases: (json['todays_purchases'] as num).toDouble(),
        totalCustomers: (json['total_customers'] as num).toInt(),
        lowStockProducts: (json['low_stock_products'] as num).toInt(),
        outOfStockProducts: (json['out_of_stock_products'] as num).toInt(),
        totalSalesAmount: (json['total_sales_amount'] as num?)?.toDouble() ?? 0,
        totalPurchaseCost: (json['total_purchase_cost'] as num?)?.toDouble() ?? 0,
        totalProfit: (json['total_profit'] as num?)?.toDouble() ?? 0,
        totalDue: (json['total_due'] as num?)?.toDouble() ?? 0,
      );
}

class StockMovementPoint {
  final String date;
  final int purchaseQty;
  final int saleQty;

  StockMovementPoint({required this.date, required this.purchaseQty, required this.saleQty});

  factory StockMovementPoint.fromJson(Map<String, dynamic> json) => StockMovementPoint(
        date: json['date'] as String,
        purchaseQty: (json['purchase_qty'] as num).toInt(),
        saleQty: (json['sale_qty'] as num).toInt(),
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
  final int currentStock;
  final int minimumStock;

  LowStockProduct({
    required this.id,
    required this.name,
    required this.currentStock,
    required this.minimumStock,
  });

  factory LowStockProduct.fromJson(Map<String, dynamic> json) => LowStockProduct(
        id: json['id'] as int,
        name: json['name'] as String,
        currentStock: (json['current_stock'] as num).toInt(),
        minimumStock: (json['minimum_stock'] as num).toInt(),
      );
}

class RecentPurchase {
  final int id;
  final String referenceNo;
  final String purchaseDate;
  final String? supplierName;
  final double grandTotal;
  final String? createdBy;

  RecentPurchase({
    required this.id,
    required this.referenceNo,
    required this.purchaseDate,
    this.supplierName,
    required this.grandTotal,
    this.createdBy,
  });

  factory RecentPurchase.fromJson(Map<String, dynamic> json) => RecentPurchase(
        id: json['id'] as int,
        referenceNo: json['reference_no'] as String,
        purchaseDate: json['purchase_date'] as String,
        supplierName: json['supplier_name'] as String?,
        grandTotal: (json['grand_total'] as num).toDouble(),
        createdBy: json['created_by'] as String?,
      );
}

class RecentSale {
  final int id;
  final String referenceNo;
  final String saleDate;
  final String? customerName;
  final double grandTotal;

  RecentSale({
    required this.id,
    required this.referenceNo,
    required this.saleDate,
    this.customerName,
    required this.grandTotal,
  });

  factory RecentSale.fromJson(Map<String, dynamic> json) => RecentSale(
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
  final List<RecentPurchase> recentPurchases;
  final List<RecentSale> recentSales;

  DashboardData({
    required this.cards,
    required this.stockMovement,
    required this.salesOverview,
    required this.topSellingProducts,
    required this.lowStockProducts,
    required this.recentPurchases,
    required this.recentSales,
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
        recentPurchases: (json['recent_purchases'] as List<dynamic>)
            .map((e) => RecentPurchase.fromJson(e as Map<String, dynamic>))
            .toList(),
        recentSales: (json['recent_sales'] as List<dynamic>)
            .map((e) => RecentSale.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
