import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../domain/models/customer_group.dart';
import '../../shared/widgets/async_list.dart';

class CustomerGroupsScreen extends ConsumerWidget {
  const CustomerGroupsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = ref.watch(customerGroupsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Nhóm khách hàng')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Thêm'),
      ),
      body: AsyncListView<CustomerGroup>(
        value: groups,
        emptyMessage: 'Chưa có nhóm khách',
        onRefresh: () async => ref.invalidate(customerGroupsProvider),
        itemBuilder: (g) => Card(
          child: ListTile(
            leading: const Icon(Icons.groups),
            title: Text(g.name),
            subtitle: Text(g.benefitPercent > 0
                ? 'Ưu đãi ${g.benefitPercent.toInt()}% mỗi đơn'
                : 'Không ưu đãi cố định'),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _openForm(context, ref, group: g);
                if (v == 'delete') {
                  ref.read(customerGroupRepoProvider).delete(g.id).then(
                      (_) => ref.invalidate(customerGroupsProvider));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Sửa')),
                PopupMenuItem(value: 'delete', child: Text('Xóa')),
              ],
            ),
            onTap: () => _openForm(context, ref, group: g),
          ),
        ),
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref, {CustomerGroup? group}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GroupForm(group: group, ref: ref),
    );
  }
}

class _GroupForm extends StatefulWidget {
  final CustomerGroup? group;
  final WidgetRef ref;
  const _GroupForm({this.group, required this.ref});

  @override
  State<_GroupForm> createState() => _GroupFormState();
}

class _GroupFormState extends State<_GroupForm> {
  late final _name = TextEditingController(text: widget.group?.name ?? '');
  late final _benefit = TextEditingController(
      text: widget.group?.benefitPercent.toString() ?? '0');
  late final _note = TextEditingController(text: widget.group?.note ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _benefit.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final repo = widget.ref.read(customerGroupRepoProvider);
    final g = CustomerGroup(
      id: widget.group?.id ?? '',
      name: _name.text.trim(),
      benefitPercent: double.tryParse(_benefit.text) ?? 0,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    try {
      if (widget.group == null) {
        await repo.create(g);
      } else {
        await repo.update(g);
      }
      widget.ref.invalidate(customerGroupsProvider);
      if (mounted) Navigator.pop(context);
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
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.group == null ? 'Thêm nhóm' : 'Sửa nhóm',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên nhóm')),
          const SizedBox(height: 12),
          TextField(
            controller: _benefit,
            keyboardType: TextInputType.number,
            decoration:
                const InputDecoration(labelText: '% ưu đãi mỗi đơn'),
          ),
          const SizedBox(height: 12),
          TextField(
              controller: _note,
              decoration: const InputDecoration(labelText: 'Ghi chú')),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Đang lưu...' : 'Lưu'),
          ),
        ],
      ),
    );
  }
}
