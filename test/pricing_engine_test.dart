import 'package:flutter_test/flutter_test.dart';
import 'package:pos_app/core/pricing/pricing_engine.dart';

void main() {
  group('PricingEngine', () {
    test('subtotal cộng đúng các dòng món', () {
      final r = PricingEngine.calculate(lines: const [
        PricingLine(unitPrice: 35000, qty: 2),
        PricingLine(unitPrice: 15000, qty: 1),
      ]);
      expect(r.subtotal, 85000);
      expect(r.total, 85000);
    });

    test('phần từ gói không tính vào subtotal', () {
      final r = PricingEngine.calculate(lines: const [
        PricingLine(unitPrice: 35000, qty: 1, fromPackage: true),
        PricingLine(unitPrice: 12000, qty: 1),
      ]);
      expect(r.subtotal, 12000);
    });

    test('chỉ áp mã giảm 15%', () {
      final r = PricingEngine.calculate(
        lines: const [PricingLine(unitPrice: 100000, qty: 1)],
        discountPercent: 15,
      );
      expect(r.afterCode, 85000);
      expect(r.total, 85000);
    });

    test('chiết khấu chồng: mã 10% + hội viên 10% + giảm tay 1000', () {
      // 100000 -> 90000 -> 81000 -> 80000
      final r = PricingEngine.calculate(
        lines: const [PricingLine(unitPrice: 100000, qty: 1)],
        discountPercent: 10,
        memberBenefitPercent: 10,
        manualDiscount: 1000,
      );
      expect(r.afterCode, 90000);
      expect(r.afterMember, 81000);
      expect(r.total, 80000);
    });

    test('total không âm khi giảm tay lớn hơn', () {
      final r = PricingEngine.calculate(
        lines: const [PricingLine(unitPrice: 50000, qty: 1)],
        manualDiscount: 99999999,
      );
      expect(r.total, 0);
    });

    test('điểm tích = total / 10000, làm tròn 2 chữ số', () {
      final r = PricingEngine.calculate(
        lines: const [PricingLine(unitPrice: 85000, qty: 1)],
      );
      expect(r.pointsEarned, 8.5);
    });

    test('điểm làm tròn tới 2 chữ số thập phân', () {
      // 12345 / 10000 = 1.2345 -> 1.23
      final r = PricingEngine.calculate(
        lines: const [PricingLine(unitPrice: 12345, qty: 1)],
      );
      expect(r.pointsEarned, 1.23);
    });

    test('totalDiscount phản ánh đúng số tiền giảm', () {
      final r = PricingEngine.calculate(
        lines: const [PricingLine(unitPrice: 100000, qty: 1)],
        discountPercent: 10,
      );
      expect(r.totalDiscount, 10000);
    });
  });

  group('PricingEngine.splitPrepaid', () {
    test('số dư nhỏ hơn total: trừ tối đa, còn lại tiền mặt', () {
      final s = PricingEngine.splitPrepaid(total: 80000, balance: 50000);
      expect(s.paidFromBalance, 50000);
      expect(s.paidCash, 30000);
    });

    test('số dư đủ trả toàn bộ: tiền mặt = 0', () {
      final s = PricingEngine.splitPrepaid(total: 80000, balance: 200000);
      expect(s.paidFromBalance, 80000);
      expect(s.paidCash, 0);
    });

    test('số dư bằng đúng total', () {
      final s = PricingEngine.splitPrepaid(total: 80000, balance: 80000);
      expect(s.paidFromBalance, 80000);
      expect(s.paidCash, 0);
    });

    test('số dư 0: trả hết tiền mặt', () {
      final s = PricingEngine.splitPrepaid(total: 80000, balance: 0);
      expect(s.paidFromBalance, 0);
      expect(s.paidCash, 80000);
    });

    test('prepaid áp x% rồi split: 100k -10% =90k, số dư 50k', () {
      final r = PricingEngine.calculate(
        lines: const [PricingLine(unitPrice: 100000, qty: 1)],
        memberBenefitPercent: 10,
      );
      expect(r.total, 90000);
      final s = PricingEngine.splitPrepaid(total: r.total, balance: 50000);
      expect(s.paidFromBalance, 50000);
      expect(s.paidCash, 40000);
      // điểm vẫn tính trên total sau giảm
      expect(r.pointsEarned, 9.0);
    });
  });
}
