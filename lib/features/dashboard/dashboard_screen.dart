import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../auth/auth_controller.dart';

class _NavItem {
  final String label;
  final IconData icon;
  final String route;
  final Color color;
  const _NavItem(this.label, this.icon, this.route, this.color);
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const _items = [
    _NavItem('Bán hàng', Icons.point_of_sale, '/sales', Color(0xFFD84315)),
    _NavItem('Sản phẩm', Icons.fastfood, '/products', Color(0xFF00897B)),
    _NavItem('Mã giảm giá', Icons.local_offer, '/discounts', Color(0xFF7B1FA2)),
    _NavItem('Nhóm khách', Icons.groups, '/groups', Color(0xFF1565C0)),
    _NavItem('Khách hàng', Icons.people, '/customers', Color(0xFF2E7D32)),
    // Gói phần ăn tạm ẩn khỏi menu (route /packages vẫn còn nếu cần bật lại).
    // _NavItem('Gói phần ăn', Icons.card_membership, '/packages',
    //     Color(0xFFEF6C00)),
    _NavItem('Lịch sử HĐ', Icons.receipt_long, '/invoices', Color(0xFF455A64)),
    _NavItem('Báo cáo', Icons.bar_chart, '/reports', Color(0xFF00695C)),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('POS Quán Cơm'),
        actions: [
          IconButton(
            tooltip: 'Đăng xuất',
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(authControllerProvider).signOut(),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final cross = constraints.maxWidth > 900
              ? 4
              : constraints.maxWidth > 600
                  ? 3
                  : 2;
          return GridView.count(
            crossAxisCount: cross,
            padding: const EdgeInsets.all(16),
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            children: [
              for (final item in _items)
                _DashCard(item: item, onTap: () => context.push(item.route)),
            ],
          );
        },
      ),
    );
  }
}

class _DashCard extends StatelessWidget {
  final _NavItem item;
  final VoidCallback onTap;
  const _DashCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: 48, color: item.color),
            const SizedBox(height: 12),
            Text(item.label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
