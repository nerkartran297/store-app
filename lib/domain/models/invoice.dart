/// Dòng món trong hóa đơn.
class InvoiceItem {
  final String? id;
  final String? productId;
  final String nameSnapshot;
  final int unitPrice;
  final int qty;
  final int lineTotal;
  final bool fromPackage;

  const InvoiceItem({
    this.id,
    this.productId,
    required this.nameSnapshot,
    required this.unitPrice,
    required this.qty,
    required this.lineTotal,
    this.fromPackage = false,
  });

  factory InvoiceItem.fromJson(Map<String, dynamic> j) => InvoiceItem(
        id: j['id'] as String?,
        productId: j['product_id'] as String?,
        nameSnapshot: j['name_snapshot'] as String,
        unitPrice: (j['unit_price'] as num).toInt(),
        qty: (j['qty'] as num).toInt(),
        lineTotal: (j['line_total'] as num).toInt(),
        fromPackage: j['from_package'] as bool? ?? false,
      );

  Map<String, dynamic> toPayload() => {
        'product_id': productId,
        'name': nameSnapshot,
        'unit_price': unitPrice,
        'qty': qty,
        'line_total': lineTotal,
        'from_package': fromPackage,
      };
}

/// Hóa đơn.
class Invoice {
  final String id;
  final String? customerId;
  final String? customerNameSnapshot;
  final String? companySnapshot;
  final int subtotal;
  final String? discountCode;
  final double discountPercent;
  final double memberBenefitPercent;
  final int manualDiscount;
  final int total;
  final int prepaidUsed;
  final double pointsEarned;
  final bool isPackageInvoice;
  final String? customerPackageId;
  final String? batchId;
  final String paymentStatus;
  final DateTime? paidAt;
  final DateTime createdAt;
  final List<InvoiceItem> items;

  const Invoice({
    required this.id,
    this.customerId,
    this.customerNameSnapshot,
    this.companySnapshot,
    required this.subtotal,
    this.discountCode,
    this.discountPercent = 0,
    this.memberBenefitPercent = 0,
    this.manualDiscount = 0,
    required this.total,
    this.prepaidUsed = 0,
    this.pointsEarned = 0,
    this.isPackageInvoice = false,
    this.customerPackageId,
    this.batchId,
    this.paymentStatus = 'pending',
    this.paidAt,
    required this.createdAt,
    this.items = const [],
  });

  factory Invoice.fromJson(Map<String, dynamic> j) {
    final items = <InvoiceItem>[];
    if (j['invoice_items'] is List) {
      for (final it in (j['invoice_items'] as List)) {
        items.add(InvoiceItem.fromJson(Map<String, dynamic>.from(it as Map)));
      }
    }
    return Invoice(
      id: j['id'] as String,
      customerId: j['customer_id'] as String?,
      customerNameSnapshot: j['customer_name_snapshot'] as String?,
      companySnapshot: j['company_snapshot'] as String?,
      subtotal: (j['subtotal'] as num).toInt(),
      discountCode: j['discount_code'] as String?,
      discountPercent: (j['discount_percent'] as num?)?.toDouble() ?? 0,
      memberBenefitPercent:
          (j['member_benefit_percent'] as num?)?.toDouble() ?? 0,
      manualDiscount: (j['manual_discount'] as num?)?.toInt() ?? 0,
      total: (j['total'] as num).toInt(),
      prepaidUsed: (j['prepaid_used'] as num?)?.toInt() ?? 0,
      pointsEarned: (j['points_earned'] as num?)?.toDouble() ?? 0,
      isPackageInvoice: j['is_package_invoice'] as bool? ?? false,
      customerPackageId: j['customer_package_id'] as String?,
      batchId: j['batch_id'] as String?,
      paymentStatus: j['payment_status'] as String? ?? 'pending',
      paidAt: j['paid_at'] == null
          ? null
          : DateTime.parse(j['paid_at'] as String),
      createdAt: DateTime.parse(j['created_at'] as String),
      items: items,
    );
  }
}
