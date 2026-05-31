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

/// Kết quả báo cáo doanh thu/lãi cho một khoảng thời gian.
class SalesReport {
  final int revenue; // tổng total các hóa đơn (đã thanh toán)
  final int cost; // giá vốn = Σ(qty × cost_price)
  final int orderCount; // số hóa đơn
  final int packageInvoiceCount; // số HĐ theo gói
  final List<TopProduct> topProducts;

  const SalesReport({
    this.revenue = 0,
    this.cost = 0,
    this.orderCount = 0,
    this.packageInvoiceCount = 0,
    this.topProducts = const [],
  });

  /// Lãi gộp = doanh thu − giá vốn.
  int get grossProfit => revenue - cost;
}
