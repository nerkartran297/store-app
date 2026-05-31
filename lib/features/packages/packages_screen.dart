import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/utils/money.dart';
import '../../data/providers.dart';
import '../../domain/models/meal_package.dart';
import '../../shared/widgets/async_list.dart';

class PackagesScreen extends ConsumerWidget {
  const PackagesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final packages = ref.watch(packagesProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gói phần ăn'),
        actions: [
          TextButton.icon(
            onPressed: () => context.push('/packages/export'),
            icon: const Icon(Icons.outbox, color: Colors.white),
            label: const Text('Xuất theo gói',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Thêm gói'),
      ),
      body: AsyncListView<MealPackage>(
        value: packages,
        emptyMessage: 'Chưa có gói phần ăn',
        onRefresh: () async => ref.invalidate(packagesProvider),
        itemBuilder: (p) => Card(
          child: ListTile(
            leading: const Icon(Icons.card_membership, size: 36),
            title: Text(p.name,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(
                '${p.portionCount} phần × ${Money.format(p.portionPrice)}\n'
                'Gốc ${Money.format(p.originalPrice)} → Bán ${Money.format(p.salePrice)} '
                '(tiết kiệm ${Money.format(p.savings)})'),
            isThreeLine: true,
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _openForm(context, ref, pkg: p);
                if (v == 'delete') {
                  ref.read(packageRepoProvider).delete(p.id).then(
                      (_) => ref.invalidate(packagesProvider));
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Sửa')),
                PopupMenuItem(value: 'delete', child: Text('Xóa')),
              ],
            ),
            onTap: () => _openForm(context, ref, pkg: p),
          ),
        ),
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref, {MealPackage? pkg}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PackageForm(pkg: pkg, ref: ref),
    );
  }
}

class _PackageForm extends StatefulWidget {
  final MealPackage? pkg;
  final WidgetRef ref;
  const _PackageForm({this.pkg, required this.ref});

  @override
  State<_PackageForm> createState() => _PackageFormState();
}

class _PackageFormState extends State<_PackageForm> {
  late final _name = TextEditingController(text: widget.pkg?.name ?? '');
  late final _count = TextEditingController(
      text: widget.pkg?.portionCount.toString() ?? '30');
  late final _portionPrice = TextEditingController(
      text: widget.pkg?.portionPrice.toString() ?? '');
  late final _sale = TextEditingController(
      text: widget.pkg?.salePrice.toString() ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _count.dispose();
    _portionPrice.dispose();
    _sale.dispose();
    super.dispose();
  }

  int get _original =>
      (int.tryParse(_count.text) ?? 0) *
      (int.tryParse(_portionPrice.text) ?? 0);

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final repo = widget.ref.read(packageRepoProvider);
    final p = MealPackage(
      id: widget.pkg?.id ?? '',
      name: _name.text.trim(),
      portionCount: int.tryParse(_count.text) ?? 0,
      portionPrice: int.tryParse(_portionPrice.text) ?? 0,
      originalPrice: _original,
      salePrice: int.tryParse(_sale.text) ?? 0,
    );
    try {
      if (widget.pkg == null) {
        await repo.create(p);
      } else {
        await repo.update(p);
      }
      widget.ref.invalidate(packagesProvider);
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
          Text(widget.pkg == null ? 'Thêm gói' : 'Sửa gói',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            decoration:
                const InputDecoration(labelText: 'Tên gói (vd Gói 30 phần 35k)'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _count,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Số phần'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _portionPrice,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration:
                    const InputDecoration(labelText: 'Giá suất (nhóm giá)'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _sale,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Giá bán gói'),
          ),
          const SizedBox(height: 10),
          Text('Giá gốc (tự tính): ${Money.format(_original)}',
              style: Theme.of(context).textTheme.bodySmall),
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
