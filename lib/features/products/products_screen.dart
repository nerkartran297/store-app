import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money.dart';
import '../../data/providers.dart';
import '../../domain/models/product.dart';
import '../../shared/widgets/async_list.dart';

class ProductsScreen extends ConsumerWidget {
  const ProductsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(productsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Sản phẩm')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Thêm'),
      ),
      body: AsyncListView<Product>(
        value: products,
        emptyMessage: 'Chưa có sản phẩm',
        onRefresh: () async => ref.invalidate(productsProvider),
        itemBuilder: (p) => Card(
          child: ListTile(
            title: Text(p.name),
            subtitle: Text(
                'Nhập ${Money.format(p.costPrice)} · Bán ${Money.format(p.salePrice)} · Tồn ${p.stockQty}'),
            trailing: PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'edit') _openForm(context, ref, product: p);
                if (v == 'delete') _confirmDelete(context, ref, p);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Sửa')),
                PopupMenuItem(value: 'delete', child: Text('Xóa')),
              ],
            ),
            onTap: () => _openForm(context, ref, product: p),
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, WidgetRef ref, Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Xóa sản phẩm?'),
        content: Text('Xóa "${p.name}"?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Hủy')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Xóa')),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(productRepoProvider).delete(p.id);
      ref.invalidate(productsProvider);
    }
  }

  void _openForm(BuildContext context, WidgetRef ref, {Product? product}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProductForm(product: product, ref: ref),
    );
  }
}

class _ProductForm extends StatefulWidget {
  final Product? product;
  final WidgetRef ref;
  const _ProductForm({this.product, required this.ref});

  @override
  State<_ProductForm> createState() => _ProductFormState();
}

class _ProductFormState extends State<_ProductForm> {
  late final _name = TextEditingController(text: widget.product?.name ?? '');
  late final _cost = TextEditingController(
      text: widget.product?.costPrice.toString() ?? '');
  late final _sale = TextEditingController(
      text: widget.product?.salePrice.toString() ?? '');
  late final _stock = TextEditingController(
      text: widget.product?.stockQty.toString() ?? '0');
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _cost.dispose();
    _sale.dispose();
    _stock.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final repo = widget.ref.read(productRepoProvider);
    final p = Product(
      id: widget.product?.id ?? '',
      name: _name.text.trim(),
      costPrice: int.tryParse(_cost.text) ?? 0,
      salePrice: int.tryParse(_sale.text) ?? 0,
      stockQty: int.tryParse(_stock.text) ?? 0,
    );
    try {
      if (widget.product == null) {
        await repo.create(p);
      } else {
        await repo.update(p);
      }
      widget.ref.invalidate(productsProvider);
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
          Text(widget.product == null ? 'Thêm sản phẩm' : 'Sửa sản phẩm',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Tên món')),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _cost,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá nhập'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _sale,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Giá bán'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextField(
            controller: _stock,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Tồn kho'),
          ),
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
