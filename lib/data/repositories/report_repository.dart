import '../../domain/models/sales_report.dart';
import '../supabase_client.dart';

class ReportRepository {
  /// Báo cáo trong khoảng [from, to] (theo created_at, đã thanh toán).
  /// Giá vốn lấy theo cost_price hiện tại của sản phẩm (join products).
  Future<SalesReport> fetch({
    required DateTime from,
    required DateTime to,
  }) async {
    // to + 1 ngày để bao trọn ngày kết thúc.
    final toExclusive = DateTime(to.year, to.month, to.day)
        .add(const Duration(days: 1));
    final fromDay = DateTime(from.year, from.month, from.day);

    final rows = await supabase
        .from('invoices')
        .select(
            'id,total,is_package_invoice,invoice_items(name_snapshot,qty,line_total,from_package,products(cost_price))')
        .eq('payment_status', 'paid')
        .gte('created_at', fromDay.toIso8601String())
        .lt('created_at', toExclusive.toIso8601String());

    var revenue = 0;
    var cost = 0;
    var orderCount = 0;
    var packageCount = 0;
    final byProduct = <String, TopProduct>{};

    for (final r in (rows as List)) {
      final inv = Map<String, dynamic>.from(r as Map);
      orderCount++;
      revenue += (inv['total'] as num?)?.toInt() ?? 0;
      if (inv['is_package_invoice'] as bool? ?? false) packageCount++;

      final items = (inv['invoice_items'] as List?) ?? const [];
      for (final it in items) {
        final item = Map<String, dynamic>.from(it as Map);
        final name = item['name_snapshot'] as String? ?? '—';
        final qty = (item['qty'] as num?)?.toInt() ?? 0;
        final lineTotal = (item['line_total'] as num?)?.toInt() ?? 0;
        final costPrice = item['products'] == null
            ? 0
            : ((item['products'] as Map)['cost_price'] as num?)?.toInt() ?? 0;

        cost += qty * costPrice;

        final prev = byProduct[name];
        byProduct[name] = TopProduct(
          name: name,
          qty: (prev?.qty ?? 0) + qty,
          revenue: (prev?.revenue ?? 0) + lineTotal,
        );
      }
    }

    final top = byProduct.values.toList()
      ..sort((a, b) => b.qty.compareTo(a.qty));

    return SalesReport(
      revenue: revenue,
      cost: cost,
      orderCount: orderCount,
      packageInvoiceCount: packageCount,
      topProducts: top.take(10).toList(),
    );
  }
}
