import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/money.dart';
import '../../data/providers.dart';
import '../../domain/models/customer.dart';
import '../../domain/models/customer_group.dart';
import '../../shared/widgets/async_list.dart';

class CustomerSearch extends Notifier<String> {
  @override
  String build() => '';
  void set(String value) => state = value;
}

final customerSearchProvider =
    NotifierProvider.autoDispose<CustomerSearch, String>(CustomerSearch.new);

final customersListProvider =
    FutureProvider.autoDispose<List<Customer>>((ref) async {
  final search = ref.watch(customerSearchProvider);
  return ref.watch(customerRepoProvider).fetchAll(search: search);
});

class CustomersScreen extends ConsumerWidget {
  const CustomersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersListProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Khách hàng')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.person_add),
        label: const Text('Thêm'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Tìm theo tên hoặc SĐT',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) =>
                  ref.read(customerSearchProvider.notifier).set(v),
            ),
          ),
          Expanded(
            child: AsyncListView<Customer>(
              value: customers,
              emptyMessage: 'Không có khách hàng',
              onRefresh: () async => ref.invalidate(customersListProvider),
              itemBuilder: (c) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                      child: Text(c.name.isNotEmpty ? c.name[0] : '?')),
                  title: Text(c.name),
                  subtitle: Text([
                    if (c.phone != null) c.phone!,
                    if (c.company != null) c.company!,
                    '${c.points.toStringAsFixed(2)} điểm',
                    if (c.isPrepaidMember) 'Hội viên',
                  ].join(' · ')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/customers/${c.id}'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref, {Customer? customer}) =>
      openCustomerForm(context, ref, customer: customer);
}

/// Mở form thêm/sửa khách (bottom sheet). Trả về Customer đã lưu, null nếu hủy.
Future<Customer?> openCustomerForm(
  BuildContext context,
  WidgetRef ref, {
  Customer? customer,
}) {
  return showModalBottomSheet<Customer>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CustomerForm(customer: customer, ref: ref),
  );
}

class _CustomerForm extends ConsumerStatefulWidget {
  final Customer? customer;
  final WidgetRef ref;
  const _CustomerForm({this.customer, required this.ref});

  @override
  ConsumerState<_CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends ConsumerState<_CustomerForm> {
  late final _name = TextEditingController(text: widget.customer?.name ?? '');
  late final _phone = TextEditingController(text: widget.customer?.phone ?? '');
  late final _company =
      TextEditingController(text: widget.customer?.company ?? '');
  late final Set<String> _selectedGroups = {...?widget.customer?.groupIds};
  late bool _prepaid = widget.customer?.isPrepaidMember ?? false;
  late final _prepaidBalance = TextEditingController(
      text: widget.customer?.prepaidBalance.toString() ?? '0');
  final _prepaidFocus = FocusNode();
  bool _saving = false;

  /// Nhóm có tên chứa "trả trước" được coi là nhóm hội viên trả trước.
  bool _isPrepaidGroup(CustomerGroup g) =>
      g.name.toLowerCase().contains('trả trước');

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _company.dispose();
    _prepaidBalance.dispose();
    _prepaidFocus.dispose();
    super.dispose();
  }

  /// Bật/tắt trả trước, đồng bộ chip nhóm trả trước (nếu có trong [groups]).
  void _setPrepaid(bool on, List<CustomerGroup> groups) {
    setState(() {
      _prepaid = on;
      for (final g in groups) {
        if (_isPrepaidGroup(g)) {
          if (on) {
            _selectedGroups.add(g.id);
          } else {
            _selectedGroups.remove(g.id);
          }
        }
      }
    });
    if (on) {
      // Mở bàn phím nhập tiền ngay.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _prepaidFocus.requestFocus();
      });
    }
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Nhập tên khách')));
      return;
    }
    final isNew = widget.customer == null;
    final inputBalance = int.tryParse(_prepaidBalance.text) ?? 0;
    // Tạo mới + bật trả trước -> bắt buộc nhập số tiền ban đầu > 0.
    if (isNew && _prepaid && inputBalance <= 0) {
      _prepaidFocus.requestFocus();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nhập số tiền trả trước (> 0)')));
      return;
    }
    // Số dư cuối: tạo mới dùng số nhập; sửa thì GIỮ số dư cũ (đổi qua nút Nạp
    // tiền). Tắt trả trước -> 0.
    final int finalBalance;
    if (!_prepaid) {
      finalBalance = 0;
    } else if (isNew) {
      finalBalance = inputBalance;
    } else {
      finalBalance = widget.customer!.prepaidBalance;
    }
    setState(() => _saving = true);
    final repo = widget.ref.read(customerRepoProvider);
    final c = Customer(
      id: widget.customer?.id ?? '',
      name: _name.text.trim(),
      phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      company: _company.text.trim().isEmpty ? null : _company.text.trim(),
      isPrepaidMember: _prepaid,
      prepaidBalance: finalBalance,
      points: widget.customer?.points ?? 0,
    );
    try {
      final Customer saved;
      if (widget.customer == null) {
        saved = await repo.create(c, groupIds: _selectedGroups.toList());
      } else {
        saved = await repo.update(c, groupIds: _selectedGroups.toList());
      }
      widget.ref.invalidate(customersListProvider);
      if (mounted) Navigator.pop(context, saved);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final groups = ref.watch(customerGroupsProvider);
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.customer == null ? 'Thêm khách' : 'Sửa khách',
                style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Tên')),
            const SizedBox(height: 12),
            TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Số điện thoại')),
            const SizedBox(height: 12),
            TextField(
                controller: _company,
                decoration:
                    const InputDecoration(labelText: 'Công ty (nếu có)')),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Nhóm khách',
                  style: Theme.of(context).textTheme.labelLarge),
            ),
            const SizedBox(height: 8),
            groups.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Lỗi nhóm: $e'),
              data: (list) => Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final CustomerGroup g in list)
                    FilterChip(
                      label: Text(g.name),
                      selected: _selectedGroups.contains(g.id),
                      onSelected: (s) {
                        // Chip nhóm trả trước điều khiển luôn công tắc.
                        if (_isPrepaidGroup(g)) {
                          _setPrepaid(s, list);
                          return;
                        }
                        setState(() {
                          if (s) {
                            _selectedGroups.add(g.id);
                          } else {
                            _selectedGroups.remove(g.id);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            groups.maybeWhen(
              data: (list) => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hội viên trả trước'),
                subtitle: const Text('Trả trước để nhận ưu đãi mỗi đơn'),
                value: _prepaid,
                onChanged: (v) => _setPrepaid(v, list),
              ),
              orElse: () => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Hội viên trả trước'),
                value: _prepaid,
                onChanged: (v) => setState(() => _prepaid = v),
              ),
            ),
            // Khi TẠO MỚI: nhập số tiền trả trước ban đầu.
            // Khi SỬA: số dư chỉ đổi qua nút "Nạp tiền" (có ghi sổ) — không cho
            // sửa tay ở đây để tránh ghi đè nhầm.
            if (_prepaid && widget.customer == null)
              TextField(
                controller: _prepaidBalance,
                focusNode: _prepaidFocus,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Số tiền trả trước ban đầu (VND)',
                  hintText: 'Nhập số tiền khách trả trước',
                ),
              ),
            if (_prepaid && widget.customer != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Số dư hiện tại: ${Money.format(widget.customer!.prepaidBalance)} '
                  '· dùng nút "Nạp tiền" ở màn chi tiết để nạp thêm.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Đang lưu...' : 'Lưu'),
            ),
          ],
        ),
      ),
    );
  }
}
