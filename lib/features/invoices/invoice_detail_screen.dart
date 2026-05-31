import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/money.dart';
import '../../data/providers.dart';
import '../../domain/models/invoice.dart';
import 'receipt_pdf.dart';

final invoiceDetailProvider =
    FutureProvider.autoDispose.family<Invoice, String>((ref, id) async {
  return ref.watch(invoiceRepoProvider).getById(id);
});

class InvoiceDetailScreen extends ConsumerWidget {
  final String invoiceId;
  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inv = ref.watch(invoiceDetailProvider(invoiceId));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Biên lai'),
        actions: [
          inv.maybeWhen(
            data: (i) => Row(children: [
              IconButton(
                tooltip: 'In',
                icon: const Icon(Icons.print),
                onPressed: () => _safe(context, () => ReceiptPdf.print(i)),
              ),
              IconButton(
                tooltip: 'Chia sẻ PDF',
                icon: const Icon(Icons.share),
                onPressed: () => _safe(context, () => ReceiptPdf.share(i)),
              ),
            ]),
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
      body: inv.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Lỗi: $e')),
        data: (i) => _Receipt(invoice: i),
      ),
    );
  }

  Future<void> _safe(BuildContext context, Future<void> Function() fn) async {
    try {
      await fn();
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Lỗi in: $e')));
      }
    }
  }
}

class _Receipt extends StatelessWidget {
  final Invoice invoice;
  const _Receipt({required this.invoice});

  @override
  Widget build(BuildContext context) {
    final i = invoice;
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Center(
                    child: Text('QUÁN CƠM',
                        style: TextStyle(
                            fontSize: 22, fontWeight: FontWeight.bold)),
                  ),
                  const Center(child: Text('HÓA ĐƠN BÁN HÀNG')),
                  const SizedBox(height: 8),
                  if (i.isPackageInvoice)
                    const Center(
                      child: Chip(
                        label: Text('Hóa đơn theo gói'),
                        backgroundColor: Color(0xFFFFE0B2),
                      ),
                    ),
                  const Divider(),
                  _kv('Mã HĐ', i.id.substring(0, 8)),
                  _kv('Thời gian',
                      DateFormat('dd/MM/yyyy HH:mm').format(i.createdAt)),
                  if (i.customerNameSnapshot != null)
                    _kv('Khách', i.customerNameSnapshot!),
                  if (i.companySnapshot != null)
                    _kv('Công ty', i.companySnapshot!),
                  if (i.batchId != null)
                    _kv('Lô xuất', i.batchId!.substring(0, 8)),
                  const Divider(),
                  for (final it in i.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${it.nameSnapshot} × ${it.qty}'
                              '${it.fromPackage ? ' (gói)' : ''}',
                            ),
                          ),
                          Text(it.fromPackage
                              ? '0 ₫'
                              : Money.format(it.lineTotal)),
                        ],
                      ),
                    ),
                  const Divider(),
                  _kv('Tạm tính', Money.format(i.subtotal)),
                  if (i.discountPercent > 0)
                    _kv('Mã ${i.discountCode ?? ''} (${i.discountPercent.toInt()}%)',
                        ''),
                  if (i.memberBenefitPercent > 0)
                    _kv('Ưu đãi', '${i.memberBenefitPercent.toInt()}%'),
                  if (i.manualDiscount > 0)
                    _kv('Giảm tay', '- ${Money.format(i.manualDiscount)}'),
                  const Divider(),
                  _kv('TỔNG', Money.format(i.total), bold: true),
                  if (i.prepaidUsed > 0) ...[
                    _kv('Trả từ số dư', '- ${Money.format(i.prepaidUsed)}'),
                    _kv('Tiền mặt', Money.format(i.total - i.prepaidUsed),
                        bold: true),
                  ],
                  _kv('Điểm tích', '+ ${i.pointsEarned.toStringAsFixed(2)}'),
                  _kv('Thanh toán',
                      i.paymentStatus == 'paid' ? 'Đã thanh toán' : 'Chưa'),
                  const SizedBox(height: 16),
                  const Center(child: Text('Cảm ơn quý khách!')),
                ],
              ),
            ),
          ),
        ),
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
