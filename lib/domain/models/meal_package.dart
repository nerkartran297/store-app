/// Định nghĩa gói phần ăn (30/60 phần ở mức giá cố định).
class MealPackage {
  final String id;
  final String name;
  final int portionCount; // số phần ăn (credits)
  final int portionPrice; // giá thành phần cố định = "nhóm giá"
  final int originalPrice; // = portionCount * portionPrice
  final int salePrice; // giá bán gói
  final bool isActive;

  const MealPackage({
    required this.id,
    required this.name,
    required this.portionCount,
    required this.portionPrice,
    required this.originalPrice,
    required this.salePrice,
    this.isActive = true,
  });

  /// Mức tiết kiệm so với mua lẻ.
  int get savings => originalPrice - salePrice;

  factory MealPackage.fromJson(Map<String, dynamic> j) => MealPackage(
        id: j['id'] as String,
        name: j['name'] as String,
        portionCount: (j['portion_count'] as num).toInt(),
        portionPrice: (j['portion_price'] as num).toInt(),
        originalPrice: (j['original_price'] as num).toInt(),
        salePrice: (j['sale_price'] as num).toInt(),
        isActive: j['is_active'] as bool? ?? true,
      );

  Map<String, dynamic> toInsert() => {
        'name': name,
        'portion_count': portionCount,
        'portion_price': portionPrice,
        'original_price': originalPrice,
        'sale_price': salePrice,
        'is_active': isActive,
      };
}

/// Gói mà một khách đã đăng ký (instance, theo dõi credit).
class CustomerPackage {
  final String id;
  final String customerId;
  final String packageId;
  final int creditsTotal;
  final int creditsRemaining;
  final DateTime registeredAt;
  final String? note;

  // Tùy chọn: thông tin gói kèm theo khi join.
  final MealPackage? package;

  const CustomerPackage({
    required this.id,
    required this.customerId,
    required this.packageId,
    required this.creditsTotal,
    required this.creditsRemaining,
    required this.registeredAt,
    this.note,
    this.package,
  });

  factory CustomerPackage.fromJson(Map<String, dynamic> j) => CustomerPackage(
        id: j['id'] as String,
        customerId: j['customer_id'] as String,
        packageId: j['package_id'] as String,
        creditsTotal: (j['credits_total'] as num).toInt(),
        creditsRemaining: (j['credits_remaining'] as num).toInt(),
        registeredAt: DateTime.parse(j['registered_at'] as String),
        note: j['note'] as String?,
        package: j['meal_packages'] == null
            ? null
            : MealPackage.fromJson(
                Map<String, dynamic>.from(j['meal_packages'] as Map)),
      );
}
