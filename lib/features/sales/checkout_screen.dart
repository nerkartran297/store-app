import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/error_message.dart';
import '../../core/utils/money.dart';
import '../../data/providers.dart';
import '../invoices/invoice_detail_screen.dart';
import 'cart_controller.dart';

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen> {
  bool _saving = false;

  Future<void> _confirmPayment() async {
    final cart = ref.read(cartProvider);
    final calc = cart.calc;
    setState(() => _saving = true);

    final payload = <String, dynamic>{
      'customer_id': cart.customer?.id,
      'customer_name': cart.customer?.name,
      'company': cart.customer?.company,
      'discount_code': cart.discount?.code,
      'discount_percent': calc.discountPercent,
      'member_benefit_percent': calc.memberBenefitPercent,
      'manual_discount': calc.manualDiscount,
      'subtotal': calc.subtotal,
      'total': calc.total,
      'points_earned': calc.pointsEarned,
      'prepaid_used': cart.prepaidApplied,
      'is_package_invoice': false,
      'items': [
        for (final l in cart.lines)
          {
            'product_id': l.product.id,
            'name': l.product.name,
            'unit_price': l.product.salePrice,
            'qty': l.qty,
            'line_total': l.lineTotal,
            'from_package': false,
          }
      ],
    };

    try {
      final id =
          await ref.read(invoiceRepoProvider).createInvoice(payload);
      // Refresh dữ liệu liên quan
      ref.invalidate(productsProvider);
      ref.invalidate(activeProductsProvider);
      ref.invalidate(invoicesProvider);
      ref.read(cartProvider.notifier).clear();
      if (!mounted) return;
      // Về POS rồi mở biên lai
      Navigator.of(context).pop();
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => InvoiceDetailScreen(invoiceId: id),
      ));
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = ref.watch(cartProvider);
    final c = cart.calc;
    return Scaffold(
      appBar: AppBar(title: const Text('Xác nhận hóa đơn')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Khách: ${cart.customer?.name ?? 'Khách lẻ'}',
                      style: Theme.of(context).textTheme.titleMedium),
                  if (cart.customer?.company != null)
                    Text('Công ty: ${cart.customer!.company}'),
                  const Divider(),
                  for (final l in cart.lines)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: Text('${l.product.name} × ${l.qty}')),
                          Text(Money.format(l.lineTotal)),
                        ],
                      ),
                    ),
                  const Divider(),
                  _kv('Tạm tính', Money.format(c.subtotal)),
                  if (c.discountPercent > 0)
                    _kv('Mã ${cart.discount?.code} (${c.discountPercent.toInt()}%)',
                        '- ${Money.format(c.subtotal - c.afterCode)}'),
                  if (c.memberBenefitPercent > 0)
                    _kv('Ưu đãi ${c.memberBenefitPercent.toInt()}%',
                        '- ${Money.format(c.afterCode - c.afterMember)}'),
                  if (c.manualDiscount > 0)
                    _kv('Giảm tay', '- ${Money.format(c.manualDiscount)}'),
                  const Divider(),
                  _kv('TỔNG THANH TOÁN', Money.format(c.total), bold: true),
                  if (cart.usePrepaid && cart.prepaidApplied > 0) ...[
                    _kv('Trả từ số dư trả trước',
                        '- ${Money.format(cart.prepaidApplied)}'),
                    _kv('Còn phải trả (tiền mặt)', Money.format(cart.cashDue),
                        bold: true),
                  ],
                  _kv('Điểm tích lũy',
                      '+ ${c.pointsEarned.toStringAsFixed(2)} điểm'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _saving ? null : _confirmPayment,
            icon: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check_circle),
            label: Text(_saving
                ? 'Đang lưu...'
                : 'Xác nhận đã thanh toán · ${Money.format(cart.usePrepaid ? cart.cashDue : c.total)}'),
          ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(k,
                  style: TextStyle(
                      fontWeight:
                          bold ? FontWeight.bold : FontWeight.normal)),
            ),
            const SizedBox(width: 8),
            Text(v,
                textAlign: TextAlign.right,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal,
                    fontSize: bold ? 18 : 14)),
          ],
        ),
      );
}
