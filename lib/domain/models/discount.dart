/// Mã giảm giá.
class Discount {
  final String id;
  final String code;
  final double percent;
  final int maxUses; // 0 = vô hạn
  final int usedCount;
  final DateTime? expiresAt;
  final bool isActive;

  const Discount({
    required this.id,
    required this.code,
    this.percent = 0,
    this.maxUses = 0,
    this.usedCount = 0,
    this.expiresAt,
    this.isActive = true,
  });

  factory Discount.fromJson(Map<String, dynamic> j) => Discount(
        id: j['id'] as String,
        code: j['code'] as String,
        percent: (j['percent'] as num?)?.toDouble() ?? 0,
        maxUses: (j['max_uses'] as num?)?.toInt() ?? 0,
        usedCount: (j['used_count'] as num?)?.toInt() ?? 0,
        expiresAt: j['expires_at'] == null
            ? null
            : DateTime.parse(j['expires_at'] as String),
        isActive: j['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toInsert() => {
        'code': code,
        'percent': percent,
        'max_uses': maxUses,
        'expires_at': expiresAt?.toIso8601String().split('T').first,
        'is_active': isActive,
      };

  /// Mã còn dùng được tại thời điểm [now]?
  bool isUsable(DateTime now) {
    if (!isActive) return false;
    if (expiresAt != null && now.isAfter(expiresAt!.add(const Duration(days: 1)))) {
      return false;
    }
    if (maxUses > 0 && usedCount >= maxUses) return false;
    return true;
  }
}
