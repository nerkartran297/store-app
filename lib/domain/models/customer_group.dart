/// Nhóm khách hàng (sinh viên, VIP, văn phòng, hội viên trả trước...).
class CustomerGroup {
  final String id;
  final String name;
  final double benefitPercent; // % giảm mỗi đơn cho nhóm này
  final String? note;

  const CustomerGroup({
    required this.id,
    required this.name,
    this.benefitPercent = 0,
    this.note,
  });

  factory CustomerGroup.fromJson(Map<String, dynamic> j) => CustomerGroup(
        id: j['id'] as String,
        name: j['name'] as String,
        benefitPercent: (j['benefit_percent'] as num?)?.toDouble() ?? 0,
        note: j['note'] as String?,
      );

  Map<String, dynamic> toInsert() => {
        'name': name,
        'benefit_percent': benefitPercent,
        'note': note,
      };

  CustomerGroup copyWith({String? name, double? benefitPercent, String? note}) =>
      CustomerGroup(
        id: id,
        name: name ?? this.name,
        benefitPercent: benefitPercent ?? this.benefitPercent,
        note: note ?? this.note,
      );
}
