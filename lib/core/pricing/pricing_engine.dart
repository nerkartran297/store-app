import '../utils/money.dart';

/// Một dòng món dùng cho tính toán (thuần, không phụ thuộc model/DB).
class PricingLine {
  final int unitPrice;
  final int qty;
  final bool fromPackage; // phần từ gói -> không tính tiền

  const PricingLine({
    required this.unitPrice,
    required this.qty,
    this.fromPackage = false,
  });

  int get lineTotal => fromPackage ? 0 : unitPrice * qty;
}

/// Kết quả tính hóa đơn — đủ chi tiết để UI hiển thị breakdown.
class InvoiceCalculation {
  final int subtotal; // tổng trước giảm (không gồm phần từ gói)
  final double discountPercent;
  final double memberBenefitPercent;
  final int manualDiscount;

  final int afterCode; // sau khi trừ mã giảm
  final int afterMember; // sau khi trừ lợi ích hội viên
  final int total; // sau giảm tay, không âm
  final double pointsEarned;

  const InvoiceCalculation({
    required this.subtotal,
    required this.discountPercent,
    required this.memberBenefitPercent,
    required this.manualDiscount,
    required this.afterCode,
    required this.afterMember,
    required this.total,
    required this.pointsEarned,
  });

  /// Tổng số tiền đã giảm.
  int get totalDiscount => subtotal - total;
}

/// Tách tiền thanh toán khi dùng số dư trả trước.
class PrepaidSplit {
  /// Phần trả từ số dư trả trước = min(balance, total).
  final int paidFromBalance;

  /// Phần còn lại trả tiền mặt = total - paidFromBalance.
  final int paidCash;

  const PrepaidSplit({required this.paidFromBalance, required this.paidCash});
}

/// Engine tính hóa đơn — chiết khấu chồng (tuần tự).
///
///   subtotal     = Σ(unitPrice × qty) [bỏ qua phần từ gói]
///   afterCode    = subtotal × (1 - discountPercent/100)
///   afterMember  = afterCode × (1 - memberBenefitPercent/100)
///   total        = max(0, afterMember - manualDiscount)
///   pointsEarned = round(total / 10000, 2)
class PricingEngine {
  /// 1 điểm cho mỗi 10.000đ chi tiêu.
  static const int pointsPerDong = 10000;

  static InvoiceCalculation calculate({
    required List<PricingLine> lines,
    double discountPercent = 0,
    double memberBenefitPercent = 0,
    int manualDiscount = 0,
  }) {
    final subtotal = lines.fold<int>(0, (sum, l) => sum + l.lineTotal);

    final afterCode = (subtotal * (1 - discountPercent / 100)).round();
    final afterMember =
        (afterCode * (1 - memberBenefitPercent / 100)).round();
    final total = (afterMember - manualDiscount).clamp(0, afterMember);

    final pointsEarned = Money.roundPoints(total / pointsPerDong);

    return InvoiceCalculation(
      subtotal: subtotal,
      discountPercent: discountPercent,
      memberBenefitPercent: memberBenefitPercent,
      manualDiscount: manualDiscount,
      afterCode: afterCode,
      afterMember: afterMember,
      total: total,
      pointsEarned: pointsEarned,
    );
  }

  /// Tách tiền: trừ tối đa số dư trả trước, phần còn lại trả tiền mặt.
  static PrepaidSplit splitPrepaid({required int total, required int balance}) {
    final fromBalance = balance < total ? balance : total;
    final safeFromBalance = fromBalance < 0 ? 0 : fromBalance;
    return PrepaidSplit(
      paidFromBalance: safeFromBalance,
      paidCash: total - safeFromBalance,
    );
  }
}
