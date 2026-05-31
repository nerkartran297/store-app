import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/money.dart';
import '../../data/providers.dart';
import '../../domain/models/customer.dart';
import '../../domain/models/meal_package.dart';
import 'customers_screen.dart';

final customerDetailProvider =
    FutureProvider.autoDispose.family<Customer, String>((ref, id) async {
  return ref.watch(customerRepoProvider).getById(id);
});

final customerPackagesProvider = FutureProvider.autoDispose
    .family<List<CustomerPackage>, String>((ref, id) async {
  return ref.watch(customerRepoProvider).fetchPackages(id);
});

class CustomerDetailScreen extends ConsumerWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customer = ref.watch(customerDetailProvider(customerId));
    final packages = ref.watch(customerPackagesProvider(customerId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết khách hàng'),
        actions: [
          customer.maybeWhen(
            data: (c) => IconButton(
              tooltip: 'Sửa thông tin',
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final saved =
                    await openCustomerForm(context, ref, customer: c);
                if (saved == true) {
                  ref.invalidate(customerDetailProvider(customerId));
                  ref.invalidate(customerPackagesProvider(customerId));
                }
              },
            ),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: customer.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (c) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(c.name, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            if (c.phone != null) Text('SĐT: ${c.phone}'),
            if (c.company != null) Text('Công ty: ${c.company}'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                Chip(
                  avatar: const Icon(Icons.star, size: 18),
                  label: Text('${c.points.toStringAsFixed(2)} điểm'),
                ),
                if (c.isPrepaidMember)
                  Chip(
                    avatar: const Icon(Icons.account_balance_wallet, size: 18),
                    label:
                        Text('Trả trước ${Money.format(c.prepaidBalance)}'),
                  ),
              ],
            ),
            const Divider(height: 32),
            Row(
              children: [
                Expanded(
                  child: Text('Gói đã đăng ký',
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                TextButton.icon(
                  onPressed: () => _registerPackage(context, ref, c),
                  icon: const Icon(Icons.add),
                  label: const Text('Đăng ký gói'),
                ),
              ],
            ),
            packages.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(16),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Text('Lỗi gói: $e'),
              data: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text('Chưa đăng ký gói nào'),
                    )
                  : Column(
                      children: [
                        for (final cp in list)
                          Card(
                            child: ListTile(
                              leading: const Icon(Icons.card_membership),
                              title: Text(cp.package?.name ?? 'Gói'),
                              subtitle: Text(
                                  'Còn ${cp.creditsRemaining}/${cp.creditsTotal} phần · '
                                  'ĐK ${DateFormat('dd/MM/yyyy').format(cp.registeredAt)}'),
                              trailing: Text(
                                '${cp.creditsRemaining}',
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: cp.creditsRemaining > 0
                                      ? Colors.green
                                      : Colors.grey,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _registerPackage(
      BuildContext context, WidgetRef ref, Customer c) async {
    final allPackages = await ref.read(packageRepoProvider).fetchAll();
    if (!context.mounted) return;
    final selected = await showModalBottomSheet<MealPackage>(
      context: context,
      builder: (_) => ListView(
        shrinkWrap: true,
        children: [
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('Chọn gói để đăng ký',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          for (final p in allPackages)
            ListTile(
              leading: const Icon(Icons.card_membership),
              title: Text(p.name),
              subtitle: Text(
                  '${p.portionCount} phần · ${Money.format(p.salePrice)}'),
              onTap: () => Navigator.pop(context, p),
            ),
        ],
      ),
    );
    if (selected == null) return;
    await ref.read(customerRepoProvider).registerPackage(
          customerId: c.id,
          packageId: selected.id,
          portionCount: selected.portionCount,
        );
    ref.invalidate(customerPackagesProvider(c.id));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Đã đăng ký ${selected.name}')));
    }
  }
}
