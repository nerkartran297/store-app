import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/money.dart';
import '../../data/providers.dart';
import '../../domain/models/discount.dart';
import '../../domain/models/product.dart';
import 'cart_controller.dart';
import 'checkout_screen.dart';
import 'customer_picker.dart';

class SalesScreen extends ConsumerWidget {
  const SalesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wide = MediaQuery.of(context).size.width > 720;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bán hàng'),
        actions: [
          TextButton.icon(
            onPressed: () => ref.read(cartProvider.notifier).clear(),
            icon: const Icon(Icons.delete_sweep, color: Colors.white),
            label: const Text('Xóa giỏ',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: wide
          ? Row(
              children: const [
                Expanded(flex: 3, child: _ProductGrid()),
                SizedBox(width: 380, child: _CartPanel()),
              ],
            )
          : const _ProductGrid(),
      bottomNavigationBar: wide ? null : const _CartBar(),
    );
  }
}

class _ProductGrid extends ConsumerWidget {
  const _ProductGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final products = ref.watch(activeProductsProvider);
    return products.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Lỗi: $e')),
      data: (list) => GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
          maxCrossAxisExtent: 180,
          childAspectRatio: 0.95,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: list.length,
        itemBuilder: (_, i) {
          final p = list[i];
          return _ProductTile(product: p);
        },
      ),
    );
  }
}

class _ProductTile extends ConsumerWidget {
  final Product product;
  const _ProductTile({required this.product});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final out = product.stockQty <= 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: out ? null : () => ref.read(cartProvider.notifier).addProduct(product),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.fastfood, size: 32),
              const SizedBox(height: 6),
              Flexible(
                child: Text(product.name,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 4),
              Text(Money.format(product.salePrice),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.bold)),
              Text(out ? 'Hết hàng' : 'Tồn ${product.stockQty}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 11,
                      color: out ? Colors.red : Colors.grey)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Thanh giỏ hàng cho màn hẹp (mobile dọc) -> mở panel toàn màn.
class _CartBar extends ConsumerWidget {
  const _CartBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final calc = cart.calc;
    return Material(
      elevation: 8,
      child: InkWell(
        onTap: cart.isEmpty
            ? null
            : () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => FractionallySizedBox(
                    heightFactor: 0.9,
                    child: const _CartPanel(),
                  ),
                ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Badge(
                label: Text('${cart.lines.length}'),
                child: const Icon(Icons.shopping_cart),
              ),
              const SizedBox(width: 16),
              Text(Money.format(calc.total),
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold)),
              const Spacer(),
              const Text('Xem giỏ'),
              const Icon(Icons.arrow_drop_up),
            ],
          ),
        ),
      ),
    );
  }
}

/// Panel giỏ hàng + tính tiền (dùng cho cả wide và bottom sheet).
class _CartPanel extends ConsumerWidget {
  const _CartPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final ctrl = ref.read(cartProvider.notifier);
    final calc = cart.calc;

    return Material(
      color: Colors.white,
      child: Column(
        children: [
          // Khách hàng
          ListTile(
            leading: const Icon(Icons.person),
            title: Text(cart.customer?.name ?? 'Khách lẻ'),
            subtitle: cart.memberBenefitPercent > 0
                ? Text('Ưu đãi ${cart.memberBenefitPercent.toInt()}%')
                : null,
            trailing: TextButton(
              onPressed: () async {
                final sel = await pickCustomer(context, ref);
                if (sel != null) {
                  ctrl.setCustomer(sel.customer,
                      memberBenefitPercent: sel.memberBenefitPercent,
                      prepaidBenefitPercent: sel.prepaidBenefitPercent);
                }
              },
              child: Text(cart.customer == null ? 'Chọn' : 'Đổi'),
            ),
          ),
          const Divider(height: 1),
          // Danh sách dòng
          Expanded(
            child: cart.isEmpty
                ? const Center(child: Text('Chưa có món nào'))
                : ListView(
                    children: [
                      for (final l in cart.lines)
                        ListTile(
                          dense: true,
                          contentPadding:
                              const EdgeInsets.only(left: 16, right: 4),
                          title: Text(l.product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          subtitle: Text(Money.format(l.product.salePrice)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: () => ctrl.setQty(
                                    l.product.id, l.qty - 1),
                              ),
                              SizedBox(
                                width: 24,
                                child: Text('${l.qty}',
                                    textAlign: TextAlign.center),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                constraints: const BoxConstraints(),
                                padding: const EdgeInsets.all(4),
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: () => ctrl.setQty(
                                    l.product.id, l.qty + 1),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
          ),
          const Divider(height: 1),
          // Ưu đãi
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.local_offer, size: 18),
                    label: Text(cart.discount?.code ?? 'Mã giảm'),
                    onPressed: () => _applyCode(context, ref),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit, size: 18),
                    label: Text(cart.manualDiscount > 0
                        ? Money.format(cart.manualDiscount)
                        : 'Giảm tay'),
                    onPressed: () => _manualDiscount(context, ref),
                  ),
                ),
              ],
            ),
          ),
          // Công tắc dùng số dư trả trước (chỉ hội viên còn số dư)
          if (cart.customer != null &&
              cart.customer!.isPrepaidMember &&
              cart.customer!.prepaidBalance > 0)
            SwitchListTile(
              dense: true,
              secondary: const Icon(Icons.account_balance_wallet),
              title: Text(
                  'Dùng số dư trả trước (−${cart.prepaidBenefitPercent.toInt()}%)'),
              subtitle:
                  Text('Số dư: ${Money.format(cart.customer!.prepaidBalance)}'),
              value: cart.usePrepaid,
              onChanged: (v) => ctrl.setUsePrepaid(v),
            ),
          // Breakdown
          _Breakdown(cart: cart),
          // Nút chốt
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: cart.isEmpty
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const CheckoutScreen()),
                        ),
                child: Text('Chốt hóa đơn · ${Money.format(calc.total)}'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _applyCode(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
        text: ref.read(cartProvider).discount?.code ?? '');
    final code = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Mã giảm giá'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(hintText: 'vd SALE304'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ref.read(cartProvider.notifier).setDiscount(null);
              Navigator.pop(context);
            },
            child: const Text('Bỏ mã'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text),
            child: const Text('Áp dụng'),
          ),
        ],
      ),
    );
    if (code == null || code.trim().isEmpty || !context.mounted) return;
    final Discount? d =
        await ref.read(discountRepoProvider).findByCode(code);
    if (!context.mounted) return;
    if (d == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Không tìm thấy mã')));
      return;
    }
    if (!d.isUsable(DateTime.now())) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mã đã hết hạn / hết lượt')));
      return;
    }
    ref.read(cartProvider.notifier).setDiscount(d);
  }

  Future<void> _manualDiscount(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(
        text: ref.read(cartProvider).manualDiscount.toString());
    final amount = await showDialog<int>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Giảm tay (VND)'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, 0),
              child: const Text('Xóa')),
          FilledButton(
            onPressed: () =>
                Navigator.pop(context, int.tryParse(controller.text) ?? 0),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    if (amount != null) {
      ref.read(cartProvider.notifier).setManualDiscount(amount);
    }
  }
}

class _Breakdown extends StatelessWidget {
  final CartState cart;
  const _Breakdown({required this.cart});

  @override
  Widget build(BuildContext context) {
    final c = cart.calc;
    Widget row(String label, String value, {bool bold = false}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(label,
                    style: TextStyle(
                        fontWeight:
                            bold ? FontWeight.bold : FontWeight.normal)),
              ),
              const SizedBox(width: 8),
              Text(value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                      fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                      fontSize: bold ? 18 : 14)),
            ],
          ),
        );

    return Container(
      color: const Color(0xFFFBF6F2),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          row('Tạm tính', Money.format(c.subtotal)),
          if (c.discountPercent > 0)
            row('Sau mã (${c.discountPercent.toInt()}%)',
                Money.format(c.afterCode)),
          if (c.memberBenefitPercent > 0)
            row('Sau ưu đãi (${c.memberBenefitPercent.toInt()}%)',
                Money.format(c.afterMember)),
          if (c.manualDiscount > 0)
            row('Giảm tay', '- ${Money.format(c.manualDiscount)}'),
          const Divider(),
          row('TỔNG', Money.format(c.total), bold: true),
          if (cart.usePrepaid && cart.prepaidApplied > 0) ...[
            row('Trả từ số dư', '- ${Money.format(cart.prepaidApplied)}'),
            row('Còn phải trả (tiền mặt)', Money.format(cart.cashDue),
                bold: true),
          ],
          row('Điểm tích', '+${c.pointsEarned.toStringAsFixed(2)}'),
        ],
      ),
    );
  }
}
