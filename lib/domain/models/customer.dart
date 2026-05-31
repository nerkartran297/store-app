/// Khách hàng.
class Customer {
  final String id;
  final String name;
  final DateTime? dob;
  final String? phone;
  final String? company;
  final double points;
  final bool isPrepaidMember;
  final int prepaidBalance;

  // Tùy chọn: id nhóm kèm theo khi join.
  final List<String> groupIds;

  const Customer({
    required this.id,
    required this.name,
    this.dob,
    this.phone,
    this.company,
    this.points = 0,
    this.isPrepaidMember = false,
    this.prepaidBalance = 0,
    this.groupIds = const [],
  });

  factory Customer.fromJson(Map<String, dynamic> j) {
    final groups = <String>[];
    if (j['customer_group_members'] is List) {
      for (final m in (j['customer_group_members'] as List)) {
        final gid = (m as Map)['group_id'];
        if (gid != null) groups.add(gid as String);
      }
    }
    return Customer(
      id: j['id'] as String,
      name: j['name'] as String,
      dob: j['dob'] == null ? null : DateTime.parse(j['dob'] as String),
      phone: j['phone'] as String?,
      company: j['company'] as String?,
      points: (j['points'] as num?)?.toDouble() ?? 0,
      isPrepaidMember: j['is_prepaid_member'] as bool? ?? false,
      prepaidBalance: (j['prepaid_balance'] as num?)?.toInt() ?? 0,
      groupIds: groups,
    );
  }

  Map<String, dynamic> toInsert() => {
        'name': name,
        'dob': dob?.toIso8601String().split('T').first,
        'phone': phone,
        'company': company,
        'is_prepaid_member': isPrepaidMember,
        'prepaid_balance': prepaidBalance,
      };

  Customer copyWith({
    String? name,
    DateTime? dob,
    String? phone,
    String? company,
    double? points,
    bool? isPrepaidMember,
    int? prepaidBalance,
    List<String>? groupIds,
  }) =>
      Customer(
        id: id,
        name: name ?? this.name,
        dob: dob ?? this.dob,
        phone: phone ?? this.phone,
        company: company ?? this.company,
        points: points ?? this.points,
        isPrepaidMember: isPrepaidMember ?? this.isPrepaidMember,
        prepaidBalance: prepaidBalance ?? this.prepaidBalance,
        groupIds: groupIds ?? this.groupIds,
      );
}
