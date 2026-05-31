import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../data/providers.dart';
import '../../domain/models/discount.dart';
import '../../shared/widgets/async_list.dart';

class DiscountsScreen extends ConsumerWidget {
  const DiscountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discounts = ref.watch(discountsProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Mã giảm giá')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(context, ref),
        icon: const Icon(Icons.add),
        label: const Text('Thêm'),
      ),
      body: AsyncListView<Discount>(
        value: discounts,
        emptyMessage: 'Chưa có mã giảm giá',
        onRefresh: () async => ref.invalidate(discountsProvider),
        itemBuilder: (d) {
          final usable = d.isUsable(DateTime.now());
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('${d.percent.toInt()}%')),
              title: Text(d.code,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text([
                d.maxUses == 0
                    ? 'Đã dùng ${d.usedCount} (vô hạn)'
                    : 'Đã dùng ${d.usedCount}/${d.maxUses}',
                if (d.expiresAt != null)
                  'HSD ${DateFormat('dd/MM/yyyy').format(d.expiresAt!)}',
                if (!usable) 'KHÔNG dùng được',
              ].join(' · ')),
              trailing: PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _openForm(context, ref, discount: d);
                  if (v == 'delete') {
                    ref.read(discountRepoProvider).delete(d.id).then(
                        (_) => ref.invalidate(discountsProvider));
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Sửa')),
                  PopupMenuItem(value: 'delete', child: Text('Xóa')),
                ],
              ),
              onTap: () => _openForm(context, ref, discount: d),
            ),
          );
        },
      ),
    );
  }

  void _openForm(BuildContext context, WidgetRef ref, {Discount? discount}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DiscountForm(discount: discount, ref: ref),
    );
  }
}

class _DiscountForm extends StatefulWidget {
  final Discount? discount;
  final WidgetRef ref;
  const _DiscountForm({this.discount, required this.ref});

  @override
  State<_DiscountForm> createState() => _DiscountFormState();
}

class _DiscountFormState extends State<_DiscountForm> {
  late final _code = TextEditingController(text: widget.discount?.code ?? '');
  late final _percent = TextEditingController(
      text: widget.discount?.percent.toString() ?? '');
  late final _maxUses = TextEditingController(
      text: widget.discount?.maxUses.toString() ?? '0');
  DateTime? _expires;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _expires = widget.discount?.expiresAt;
  }

  @override
  void dispose() {
    _code.dispose();
    _percent.dispose();
    _maxUses.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_code.text.trim().isEmpty) return;
    setState(() => _saving = true);
    final repo = widget.ref.read(discountRepoProvider);
    final d = Discount(
      id: widget.discount?.id ?? '',
      code: _code.text.trim().toUpperCase(),
      percent: double.tryParse(_percent.text) ?? 0,
      maxUses: int.tryParse(_maxUses.text) ?? 0,
      expiresAt: _expires,
    );
    try {
      if (widget.discount == null) {
        await repo.create(d);
      } else {
        await repo.update(d);
      }
      widget.ref.invalidate(discountsProvider);
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
          Text(widget.discount == null ? 'Thêm mã' : 'Sửa mã',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          TextField(
            controller: _code,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Mã (vd SALE304)'),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _percent,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '% giảm'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _maxUses,
                keyboardType: TextInputType.number,
                decoration:
                    const InputDecoration(labelText: 'Số lượt (0=∞)'),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            icon: const Icon(Icons.calendar_today),
            label: Text(_expires == null
                ? 'Chọn hạn dùng (tùy chọn)'
                : 'HSD: ${DateFormat('dd/MM/yyyy').format(_expires!)}'),
            onPressed: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _expires ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2035),
              );
              if (d != null) setState(() => _expires = d);
            },
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
