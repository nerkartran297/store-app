import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/money.dart';
import '../../data/providers.dart';
import '../../domain/models/sales_report.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  late DateTimeRange _range;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(
      start: now.subtract(const Duration(days: 6)),
      end: now,
    );
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      initialDateRange: _range,
    );
    if (picked != null) setState(() => _range = picked);
  }

  @override
  Widget build(BuildContext context) {
    final report = ref.watch(
      reportProvider((from: _range.start, to: _range.end)),
    );
    final fmt = DateFormat('dd/MM/yyyy');

    return Scaffold(
      appBar: AppBar(title: const Text('Báo cáo doanh thu')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: OutlinedButton.icon(
              icon: const Icon(Icons.date_range),
              label: Text(
                  '${fmt.format(_range.start)}  →  ${fmt.format(_range.end)}'),
              onPressed: _pickRange,
            ),
          ),
          Expanded(
            child: report.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Lỗi: $e', textAlign: TextAlign.center),
                ),
              ),
              data: (r) => RefreshIndicator(
                onRefresh: () async => ref.invalidate(reportProvider),
                child: ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      childAspectRatio: 1.6,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      children: [
                        _StatCard(
                          label: 'Doanh thu',
                          value: Money.format(r.revenue),
                          icon: Icons.payments,
                          color: const Color(0xFF2E7D32),
                        ),
                        _StatCard(
                          label: 'Giá vốn',
                          value: Money.format(r.cost),
                          icon: Icons.inventory_2,
                          color: const Color(0xFF8D6E63),
                        ),
                        _StatCard(
                          label: 'Lãi gộp',
                          value: Money.format(r.grossProfit),
                          icon: Icons.trending_up,
                          color: const Color(0xFFD84315),
                          highlight: true,
                        ),
                        _StatCard(
                          label: 'Số đơn',
                          value:
                              '${r.orderCount}  (gói ${r.packageInvoiceCount})',
                          icon: Icons.receipt_long,
                          color: const Color(0xFF1565C0),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text('Doanh thu theo ngày',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (r.daily.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Text('Chưa có doanh thu')),
                      ),
                    for (final DailyRevenue d in r.daily)
                      Card(
                        child: ListTile(
                          leading: const Icon(Icons.calendar_today),
                          title: Text(DateFormat('EEEE, dd/MM/yyyy', 'vi_VN')
                              .format(d.day)),
                          subtitle: Text('${d.orderCount} đơn'),
                          trailing: Text(Money.format(d.revenue),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 15)),
                        ),
                      ),
                    const SizedBox(height: 16),
                    Text('Top món bán chạy',
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (r.topProducts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Center(child: Text('Chưa có dữ liệu bán')),
                      ),
                    for (final TopProduct p in r.topProducts)
                      Card(
                        child: ListTile(
                          leading: CircleAvatar(child: Text('${p.qty}')),
                          title: Text(p.name),
                          subtitle: Text('Đã bán ${p.qty} phần'),
                          trailing: Text(Money.format(p.revenue),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool highlight;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: highlight ? color.withValues(alpha: 0.10) : null,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.labelLarge),
                ),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: TextStyle(
                  fontSize: highlight ? 20 : 17,
                  fontWeight: FontWeight.bold,
                  color: highlight ? color : null,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
