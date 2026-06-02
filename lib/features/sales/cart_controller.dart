import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/pricing/pricing_engine.dart';
import '../../domain/models/customer.dart';
import '../../domain/models/discount.dart';
import '../../domain/models/product.dart';

/// Một dòng trong giỏ hàng.
class CartLine {
  final Product product;
  final int qty;
  const CartLine({required this.product, required this.qty});

  int get lineTotal => product.salePrice * qty;

  CartLine copyWith({int? qty}) =>
      CartLine(product: product, qty: qty ?? this.qty);
}

/// Trạng thái giỏ hàng cho 1 phiên bán.
class CartState {
  final List<CartLine> lines;
  final Customer? customer;
  final Discount? discount;
  final double memberBenefitPercent; // lợi ích nhóm/hội viên đã chọn
  final int manualDiscount;
  final bool usePrepaid; // dùng số dư trả trước (kèm ưu đãi x%)
  final double prepaidBenefitPercent; // x% áp khi dùng số dư

  const CartState({
    this.lines = const [],
    this.customer,
    this.discount,
    this.memberBenefitPercent = 0,
    this.manualDiscount = 0,
    this.usePrepaid = false,
    this.prepaidBenefitPercent = 0,
  });

  double get discountPercent => discount?.percent ?? 0;

  /// Tiền trừ từ số dư trả trước (0 nếu không dùng).
  int get prepaidApplied {
    if (!usePrepaid || customer == null) return 0;
    final balance = customer!.prepaidBalance;
    final total = calc.total;
    return balance < total ? balance : total;
  }

  /// Tiền mặt khách còn phải trả.
  int get cashDue => calc.total - prepaidApplied;

  InvoiceCalculation get calc => PricingEngine.calculate(
        lines: [
          for (final l in lines)
            PricingLine(unitPrice: l.product.salePrice, qty: l.qty),
        ],
        discountPercent: discountPercent,
        memberBenefitPercent: memberBenefitPercent,
        manualDiscount: manualDiscount,
      );

  bool get isEmpty => lines.isEmpty;

  CartState copyWith({
    List<CartLine>? lines,
    Object? customer = _sentinel,
    Object? discount = _sentinel,
    double? memberBenefitPercent,
    int? manualDiscount,
    bool? usePrepaid,
    double? prepaidBenefitPercent,
  }) =>
      CartState(
        lines: lines ?? this.lines,
        customer:
            customer == _sentinel ? this.customer : customer as Customer?,
        discount:
            discount == _sentinel ? this.discount : discount as Discount?,
        memberBenefitPercent: memberBenefitPercent ?? this.memberBenefitPercent,
        manualDiscount: manualDiscount ?? this.manualDiscount,
        usePrepaid: usePrepaid ?? this.usePrepaid,
        prepaidBenefitPercent:
            prepaidBenefitPercent ?? this.prepaidBenefitPercent,
      );

  static const _sentinel = Object();
}

class CartController extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

  /// Thêm 1 sản phẩm vào giỏ. Trả về false nếu đã chạm trần tồn kho.
  bool addProduct(Product p) {
    final idx = state.lines.indexWhere((l) => l.product.id == p.id);
    final currentQty = idx >= 0 ? state.lines[idx].qty : 0;
    if (currentQty + 1 > p.stockQty) return false; // vượt tồn kho

    final lines = [...state.lines];
    if (idx >= 0) {
      lines[idx] = lines[idx].copyWith(qty: currentQty + 1);
    } else {
      lines.add(CartLine(product: p, qty: 1));
    }
    state = state.copyWith(lines: lines);
    return true;
  }

  /// Đặt số lượng. Tự kẹp theo tồn kho. Trả về false nếu bị kẹp xuống.
  bool setQty(String productId, int qty) {
    final lines = [...state.lines];
    final idx = lines.indexWhere((l) => l.product.id == productId);
    if (idx < 0) return true;
    if (qty <= 0) {
      lines.removeAt(idx);
      state = state.copyWith(lines: lines);
      return true;
    }
    final stock = lines[idx].product.stockQty;
    final clamped = qty > stock ? stock : qty;
    lines[idx] = lines[idx].copyWith(qty: clamped);
    state = state.copyWith(lines: lines);
    return clamped == qty;
  }

  void setCustomer(
    Customer? c, {
    double memberBenefitPercent = 0,
    double prepaidBenefitPercent = 0,
  }) {
    state = state.copyWith(
      customer: c,
      memberBenefitPercent: memberBenefitPercent,
      prepaidBenefitPercent: prepaidBenefitPercent,
      usePrepaid: false, // reset khi đổi khách
    );
  }

  void setMemberBenefit(double percent) =>
      state = state.copyWith(memberBenefitPercent: percent);

  /// Bật/tắt dùng số dư trả trước. Khi bật, áp x% (prepaidBenefitPercent)
  /// vào memberBenefitPercent; khi tắt, gỡ x% đó ra.
  void setUsePrepaid(bool use) {
    state = state.copyWith(
      usePrepaid: use,
      memberBenefitPercent: use ? state.prepaidBenefitPercent : 0,
    );
  }

  void setDiscount(Discount? d) => state = state.copyWith(discount: d);

  void setManualDiscount(int amount) =>
      state = state.copyWith(manualDiscount: amount);

  void clear() => state = const CartState();
}

final cartProvider =
    NotifierProvider.autoDispose<CartController, CartState>(
        CartController.new);
