import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/customer.dart';
import '../customers/customers_screen.dart';

/// Kết quả chọn khách cho hóa đơn.
class CustomerSelection {
  final Customer customer;
  final double memberBenefitPercent; // lợi ích thường đã đồng ý áp dụng
  final double prepaidBenefitPercent; // x% khả dụng nếu trả bằng số dư

  const CustomerSelection({
    required this.customer,
    this.memberBenefitPercent = 0,
    this.prepaidBenefitPercent = 0,
  });
}

/// Mở dialog tìm + chọn khách. Khi khách có nhóm ưu đãi/hội viên/công ty,
/// hỏi tiếp có muốn áp dụng lợi ích không (đúng yêu cầu nghiệp vụ).
Future<CustomerSelection?> pickCustomer(
    BuildContext context, WidgetRef ref) async {
  final selected = await showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _CustomerSearchSheet(),
  );
  if (selected == null || !context.mounted) return null;

  // Tính lợi ích cao nhất từ các nhóm khách thuộc về.
  final groups = await ref.read(customerGroupRepoProvider).fetchAll();
  final myGroups =
      groups.where((g) => selected.groupIds.contains(g.id)).toList();
  double bestBenefit = 0;
  for (final g in myGroups) {
    if (g.benefitPercent > bestBenefit) bestBenefit = g.benefitPercent;
  }

  if (!context.mounted) {
    return CustomerSelection(customer: selected);
  }

  // Hội viên trả trước: ưu đãi x% CHỈ áp khi bật công tắc "Dùng số dư" ở màn
  // bán hàng, nên ở đây không hỏi áp ngay — chỉ truyền x% khả dụng.
  if (selected.isPrepaidMember) {
    return CustomerSelection(
      customer: selected,
      prepaidBenefitPercent: bestBenefit,
    );
  }

  // Khách thường không có lợi ích -> chọn thẳng.
  if (bestBenefit <= 0) {
    return CustomerSelection(customer: selected);
  }

  // Khách có ưu đãi nhóm (không trả trước) -> hỏi áp dụng ngay.
  final apply = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: Text(selected.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (selected.company != null) Text('Công ty: ${selected.company}'),
          if (myGroups.isNotEmpty)
            Text('Nhóm: ${myGroups.map((g) => g.name).join(', ')}'),
          const SizedBox(height: 12),
          Text(
            'Áp dụng ưu đãi ${bestBenefit.toInt()}% cho hóa đơn này?',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Không áp dụng')),
        FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Áp dụng ${bestBenefit.toInt()}%')),
      ],
    ),
  );

  return CustomerSelection(
    customer: selected,
    memberBenefitPercent: apply == true ? bestBenefit : 0,
  );
}

class _CustomerSearchSheet extends ConsumerStatefulWidget {
  const _CustomerSearchSheet();

  @override
  ConsumerState<_CustomerSearchSheet> createState() =>
      _CustomerSearchSheetState();
}

class _CustomerSearchSheetState extends ConsumerState<_CustomerSearchSheet> {
  String _query = '';

  /// Mở form tạo khách mới; nếu tạo xong thì đóng sheet và trả khách đó về
  /// cho luồng chọn khách (pickCustomer) xử lý ưu đãi như bình thường.
  Future<void> _createNew() async {
    final created = await openCustomerForm(context, ref);
    if (created != null && mounted) {
      Navigator.pop(context, created);
    }
  }

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(_searchProvider(_query));
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                autofocus: true,
                decoration: const InputDecoration(
                  hintText: 'Tìm khách theo tên / SĐT',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.person_add),
                  label: const Text('Tạo khách hàng mới'),
                  onPressed: _createNew,
                ),
              ),
            ),
            Expanded(
              child: result.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Lỗi: $e')),
                data: (list) => ListView(
                  children: [
                    for (final c in list)
                      ListTile(
                        leading: CircleAvatar(
                            child: Text(c.name.isNotEmpty ? c.name[0] : '?')),
                        title: Text(c.name),
                        subtitle: Text([
                          if (c.phone != null) c.phone!,
                          if (c.company != null) c.company!,
                        ].join(' · ')),
                        onTap: () => Navigator.pop(context, c),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

final _searchProvider =
    FutureProvider.autoDispose.family<List<Customer>, String>((ref, q) async {
  return ref.watch(customerRepoProvider).fetchAll(search: q);
});
