import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'repositories/customer_group_repository.dart';
import 'repositories/customer_repository.dart';
import 'repositories/discount_repository.dart';
import '../domain/models/sales_report.dart';
import 'repositories/invoice_repository.dart';
import 'repositories/package_repository.dart';
import 'repositories/product_repository.dart';
import 'repositories/report_repository.dart';

final productRepoProvider = Provider((_) => ProductRepository());
final discountRepoProvider = Provider((_) => DiscountRepository());
final customerGroupRepoProvider = Provider((_) => CustomerGroupRepository());
final customerRepoProvider = Provider((_) => CustomerRepository());
final packageRepoProvider = Provider((_) => PackageRepository());
final invoiceRepoProvider = Provider((_) => InvoiceRepository());
final reportRepoProvider = Provider((_) => ReportRepository());

// ----- Các nguồn dữ liệu dùng chung (auto refresh khi invalidate) -----

final productsProvider = FutureProvider.autoDispose((ref) =>
    ref.watch(productRepoProvider).fetchAll());

final activeProductsProvider = FutureProvider.autoDispose((ref) =>
    ref.watch(productRepoProvider).fetchAll(activeOnly: true));

final discountsProvider = FutureProvider.autoDispose((ref) =>
    ref.watch(discountRepoProvider).fetchAll());

final customerGroupsProvider = FutureProvider.autoDispose((ref) =>
    ref.watch(customerGroupRepoProvider).fetchAll());

final packagesProvider = FutureProvider.autoDispose((ref) =>
    ref.watch(packageRepoProvider).fetchAll());

final invoicesProvider = FutureProvider.autoDispose((ref) =>
    ref.watch(invoiceRepoProvider).fetchAll());

/// Khoảng ngày cho báo cáo.
typedef ReportRange = ({DateTime from, DateTime to});

final reportProvider = FutureProvider.autoDispose
    .family<SalesReport, ReportRange>((ref, range) =>
        ref.watch(reportRepoProvider).fetch(from: range.from, to: range.to));
