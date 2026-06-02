import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/utils/error_message.dart';
import '../../core/utils/money.dart';
import '../../data/providers.dart';
import '../../domain/models/customer.dart';
import '../../domain/models/meal_package.dart';
import '../../domain/models/product.dart';
import '../invoices/invoice_detail_screen.dart';

/// Màn xuất hóa đơn theo gói: 2 chế độ — Lẻ và Hàng loạt.
class PackageExportScreen extends ConsumerWidget {
  const PackageExportScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Xuất hóa đơn theo gói'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Lẻ (1 người)'),
              Tab(text: 'Hàng loạt (công ty)'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            _SingleExportTab(),
            _BatchExportTab(),
          ],
        ),
      ),
    );
  }
}

/// Lấy sản phẩm thuộc "nhóm giá" của gói (sale_price == portion_price).
Future<List<Product>> _productsForPrice(WidgetRef ref, int price) async {
  final all = await ref.read(productRepoProvider).fetchAll(activeOnly: true);
  return all.where((p) => p.salePrice == price).toList();
}

// ============================================================
// TAB 1: Xuất lẻ
// ============================================================
class _SingleExportTab extends ConsumerStatefulWidget {
  const _SingleExportTab();

  @override
  ConsumerState<_SingleExportTab> createState() => _SingleExportTabState();
}

class _SingleExportTabState extends ConsumerState<_SingleExportTab> {
  Customer? _customer;
  CustomerPackage? _pkg;
  Product? _product;
  List<CustomerPackage> _customerPackages = [];
  List<Product> _products = [];
  bool _saving = false;

  Future<void> _pickCustomer() async {
    final list = await ref.read(customerRepoProvider).fetchAll();
    if (!mounted) return;
    final c = await showModalBottomSheet<Customer>(
      context: context,
      builder: (_) => ListView(
        children: [
          for (final c in list)
            ListTile(
              title: Text(c.name),
              subtitle: Text(c.phone ?? ''),
              onTap: () => Navigator.pop(context, c),
            ),
        ],
      ),
    );
    if (c == null) return;
    final pkgs = await ref.read(customerRepoProvider).fetchPackages(c.id);
    setState(() {
      _customer = c;
      _customerPackages =
          pkgs.where((p) => p.creditsRemaining > 0).toList();
      _pkg = null;
      _product = null;
      _products = [];
    });
  }

  Future<void> _selectPackage(CustomerPackage cp) async {
    final price = cp.package?.portionPrice ?? 0;
    final prods = await _productsForPrice(ref, price);
    setState(() {
      _pkg = cp;
      _products = prods;
      _product = null;
    });
  }

  Future<void> _export() async {
    if (_customer == null || _pkg == null || _product == null) return;
    setState(() => _saving = true);
    final payload = <String, dynamic>{
      'customer_id': _customer!.id,
      'customer_name': _customer!.name,
      'company': _customer!.company,
      'subtotal': 0,
      'total': 0,
      'points_earned': 0,
      'is_package_invoice': true,
      'customer_package_id': _pkg!.id,
      'items': [
        {
          'product_id': _product!.id,
          'name': _product!.name,
          'unit_price': _product!.salePrice,
          'qty': 1,
          'line_total': 0,
          'from_package': true,
        }
      ],
    };
    try {
      final id = await ref.read(invoiceRepoProvider).createInvoice(payload);
      ref.invalidate(invoicesProvider);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => InvoiceDetailScreen(invoiceId: id)));
      // reset
      setState(() {
        _saving = false;
        _pkg = null;
        _product = null;
      });
      // refresh credits
      final pkgs =
          await ref.read(customerRepoProvider).fetchPackages(_customer!.id);
      if (mounted) {
        setState(() => _customerPackages =
            pkgs.where((p) => p.creditsRemaining > 0).toList());
      }
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        OutlinedButton.icon(
          icon: const Icon(Icons.person_search),
          label: Text(_customer?.name ?? 'Chọn khách hàng'),
          onPressed: _pickCustomer,
        ),
        if (_customer != null) ...[
          const SizedBox(height: 16),
          Text('Gói còn credit', style: Theme.of(context).textTheme.titleSmall),
          if (_customerPackages.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Khách chưa có gói nào còn credit'),
            ),
          for (final cp in _customerPackages)
            Card(
              color: _pkg?.id == cp.id
                  ? Theme.of(context).colorScheme.primaryContainer
                  : null,
              child: ListTile(
                title: Text(cp.package?.name ?? 'Gói'),
                subtitle: Text('Còn ${cp.creditsRemaining} phần'),
                onTap: () => _selectPackage(cp),
              ),
            ),
        ],
        if (_pkg != null) ...[
          const SizedBox(height: 16),
          Text(
              'Chọn món (giá ${Money.format(_pkg!.package?.portionPrice ?? 0)})',
              style: Theme.of(context).textTheme.titleSmall),
          if (_products.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Không có món nào đúng mức giá gói'),
            ),
          for (final p in _products)
            ListTile(
              title: Text(p.name),
              leading: Icon(_product?.id == p.id
                  ? Icons.radio_button_checked
                  : Icons.radio_button_unchecked),
              selected: _product?.id == p.id,
              onTap: () => setState(() => _product = p),
            ),
        ],
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: (_product != null && !_saving) ? _export : null,
          icon: const Icon(Icons.outbox),
          label: Text(_saving ? 'Đang xuất...' : 'Xuất & trừ 1 credit'),
        ),
      ],
    );
  }
}

// ============================================================
// TAB 2: Xuất hàng loạt theo công ty
// ============================================================
class _BatchMember {
  final Map<String, dynamic> raw; // customer_packages row joined
  bool absent = false; // hôm nay vắng -> giữ credit (bù sau)
  Product? product;
  _BatchMember(this.raw);

  String get cpId => raw['id'] as String;
  Map<String, dynamic> get customer =>
      Map<String, dynamic>.from(raw['customers'] as Map);
  Map<String, dynamic> get pkg =>
      Map<String, dynamic>.from(raw['meal_packages'] as Map);
  String get customerName => customer['name'] as String;
  int get portionPrice => (pkg['portion_price'] as num).toInt();
}

class _BatchExportTab extends ConsumerStatefulWidget {
  const _BatchExportTab();

  @override
  ConsumerState<_BatchExportTab> createState() => _BatchExportTabState();
}

class _BatchExportTabState extends ConsumerState<_BatchExportTab> {
  final _company = TextEditingController();
  List<_BatchMember> _members = [];
  Map<int, List<Product>> _productsByPrice = {};
  bool _loading = false;
  bool _saving = false;

  @override
  void dispose() {
    _company.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final company = _company.text.trim();
    if (company.isEmpty) return;
    setState(() => _loading = true);
    final rows =
        await ref.read(packageRepoProvider).fetchCompanyPackageMembers(company);
    final members = rows.map((r) => _BatchMember(r)).toList();
    // tải sản phẩm cho mỗi mức giá xuất hiện
    final prices = members.map((m) => m.portionPrice).toSet();
    final map = <int, List<Product>>{};
    for (final p in prices) {
      map[p] = await _productsForPrice(ref, p);
    }
    setState(() {
      _members = members;
      _productsByPrice = map;
      _loading = false;
    });
  }

  Future<void> _exportBatch() async {
    final present = _members.where((m) => !m.absent).toList();
    if (present.isEmpty) return;
    // mỗi người phải chọn món
    if (present.any((m) => m.product == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Chọn món cho tất cả người có mặt')));
      return;
    }
    setState(() => _saving = true);
    final batchId = const Uuid().v4();
    final repo = ref.read(invoiceRepoProvider);
    try {
      String? firstId;
      for (final m in present) {
        final payload = <String, dynamic>{
          'customer_id': m.customer['id'],
          'customer_name': m.customerName,
          'company': _company.text.trim(),
          'subtotal': 0,
          'total': 0,
          'points_earned': 0,
          'is_package_invoice': true,
          'customer_package_id': m.cpId,
          'batch_id': batchId,
          'items': [
            {
              'product_id': m.product!.id,
              'name': m.product!.name,
              'unit_price': m.product!.salePrice,
              'qty': 1,
              'line_total': 0,
              'from_package': true,
            }
          ],
        };
        final id = await repo.createInvoice(payload);
        firstId ??= id;
      }
      ref.invalidate(invoicesProvider);
      if (!mounted) return;
      final absentCount = _members.where((m) => m.absent).length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
            'Đã xuất ${present.length} hóa đơn (lô). '
            '$absentCount người vắng được giữ credit.'),
      ));
      if (firstId != null) {
        Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => InvoiceDetailScreen(invoiceId: firstId!)));
      }
      await _load();
      if (mounted) setState(() => _saving = false);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _company,
                  decoration: const InputDecoration(
                    labelText: 'Tên công ty',
                    hintText: 'vd Công ty FPT',
                  ),
                  onSubmitted: (_) => _load(),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _loading ? null : _load,
                child: const Text('Tải DS'),
              ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: _members.isEmpty
              ? const Center(child: Text('Nhập công ty và bấm "Tải DS"'))
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (final m in _members)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(m.customerName,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                  ),
                                  Text('Còn ${m.raw['credits_remaining']}'),
                                ],
                              ),
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: Text(m.absent
                                    ? 'Vắng — giữ credit (bù sau)'
                                    : 'Có mặt'),
                                value: m.absent,
                                onChanged: (v) =>
                                    setState(() => m.absent = v),
                              ),
                              if (!m.absent)
                                DropdownButton<Product>(
                                  isExpanded: true,
                                  value: m.product,
                                  hint: Text(
                                      'Chọn món (${Money.format(m.portionPrice)})'),
                                  items: [
                                    for (final p
                                        in _productsByPrice[m.portionPrice] ??
                                            [])
                                      DropdownMenuItem(
                                          value: p, child: Text(p.name)),
                                  ],
                                  onChanged: (p) =>
                                      setState(() => m.product = p),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
        ),
        if (_members.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving ? null : _exportBatch,
                icon: const Icon(Icons.outbox),
                label: Text(_saving
                    ? 'Đang xuất...'
                    : 'Xuất hàng loạt cho công ty'),
              ),
            ),
          ),
      ],
    );
  }
}
