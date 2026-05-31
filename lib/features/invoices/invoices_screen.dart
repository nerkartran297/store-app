import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/utils/money.dart';
import '../../data/providers.dart';
import '../../domain/models/invoice.dart';
import '../../shared/widgets/async_list.dart';
import 'invoice_detail_screen.dart';

class InvoicesScreen extends ConsumerWidget {
  const InvoicesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Lịch sử hóa đơn')),
      body: AsyncListView<Invoice>(
        value: invoices,
        emptyMessage: 'Chưa có hóa đơn',
        onRefresh: () async => ref.invalidate(invoicesProvider),
        itemBuilder: (i) => Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  i.isPackageInvoice ? Colors.orange : Colors.green,
              child: Icon(
                  i.isPackageInvoice ? Icons.card_membership : Icons.receipt,
                  color: Colors.white,
                  size: 20),
            ),
            title: Text(i.customerNameSnapshot ?? 'Khách lẻ'),
            subtitle: Text(
                '${DateFormat('dd/MM HH:mm').format(i.createdAt)} · '
                '${i.items.length} món'
                '${i.companySnapshot != null ? ' · ${i.companySnapshot}' : ''}'),
            trailing: Text(
              i.isPackageInvoice ? 'Gói' : Money.format(i.total),
              style: const TextStyle(
                  fontWeight: FontWeight.bold, fontSize: 15),
            ),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => InvoiceDetailScreen(invoiceId: i.id),
            )),
          ),
        ),
      ),
    );
  }
}
