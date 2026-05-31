import 'package:intl/intl.dart';

/// Tiện ích định dạng tiền tệ (VND) và làm tròn điểm.
class Money {
  static final NumberFormat _vnd =
      NumberFormat.currency(locale: 'vi_VN', symbol: '₫', decimalDigits: 0);

  /// Format số nguyên VND -> "35.000 ₫"
  static String format(num value) => _vnd.format(value);

  /// Format gọn không ký hiệu -> "35.000"
  static String plain(num value) =>
      NumberFormat.decimalPattern('vi_VN').format(value);

  /// Làm tròn điểm tới 2 chữ số thập phân.
  static double roundPoints(double points) =>
      (points * 100).round() / 100;
}
