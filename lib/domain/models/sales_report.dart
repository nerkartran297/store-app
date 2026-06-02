/// Một món trong bảng xếp hạng bán chạy.
class TopProduct {
  final String name;
  final int qty;
  final int revenue;

  const TopProduct({
    required this.name,
    required this.qty,
    required this.revenue,
  });
}

/// Doanh thu của một ngày cụ thể.
class DailyRevenue {
  final DateTime day; // ngày (local, đã chuẩn hóa về 00:00)
  final int revenue;
  final int orderCount;

  const DailyRevenue({
    required this.day,
    required this.revenue,
    required this.orderCount,
  });
}

/// Kết quả báo cáo doanh thu/lãi cho một khoảng thời gian.
class SalesReport {
  final int revenue; // tổng total các hóa đơn (đã thanh toán)
  final int cost; // giá vốn = Σ(qty × cost_price)
  final int orderCount; // số hóa đơn
  final int packageInvoiceCount; // số HĐ theo gói
  final List<TopProduct> topProducts;
  final List<DailyRevenue> daily; // doanh thu theo từng ngày (mới nhất trước)

  const SalesReport({
    this.revenue = 0,
    this.cost = 0,
    this.orderCount = 0,
    this.packageInvoiceCount = 0,
    this.topProducts = const [],
    this.daily = const [],
  });

  /// Lãi gộp = doanh thu − giá vốn.
  int get grossProfit => revenue - cost;
}
