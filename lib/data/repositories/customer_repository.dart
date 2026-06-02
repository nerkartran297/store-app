import '../../domain/models/customer.dart';
import '../../domain/models/meal_package.dart';
import '../supabase_client.dart';

class CustomerRepository {
  static const _selectWithGroups =
      '*, customer_group_members(group_id)';

  Future<List<Customer>> fetchAll({String? search}) async {
    var query = supabase.from('customers').select(_selectWithGroups);
    if (search != null && search.trim().isNotEmpty) {
      final s = search.trim();
      query = query.or('name.ilike.%$s%,phone.ilike.%$s%');
    }
    final rows = await query.order('name');
    return (rows as List)
        .map((e) => Customer.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Customer> getById(String id) async {
    final row = await supabase
        .from('customers')
        .select(_selectWithGroups)
        .eq('id', id)
        .single();
    return Customer.fromJson(row);
  }

  Future<Customer> create(Customer c, {List<String> groupIds = const []}) async {
    final row =
        await supabase.from('customers').insert(c.toInsert()).select().single();
    final created = Customer.fromJson(row);
    await _setGroups(created.id, groupIds);
    return getById(created.id);
  }

  Future<Customer> update(Customer c, {List<String>? groupIds}) async {
    await supabase.from('customers').update(c.toInsert()).eq('id', c.id);
    if (groupIds != null) await _setGroups(c.id, groupIds);
    return getById(c.id);
  }

  Future<void> delete(String id) async {
    await supabase.from('customers').delete().eq('id', id);
  }

  Future<void> _setGroups(String customerId, List<String> groupIds) async {
    await supabase
        .from('customer_group_members')
        .delete()
        .eq('customer_id', customerId);
    if (groupIds.isEmpty) return;
    await supabase.from('customer_group_members').insert([
      for (final g in groupIds) {'customer_id': customerId, 'group_id': g}
    ]);
  }

  /// Gói còn credit của một khách (join meal_packages).
  Future<List<CustomerPackage>> fetchPackages(String customerId) async {
    final rows = await supabase
        .from('customer_packages')
        .select('*, meal_packages(*)')
        .eq('customer_id', customerId)
        .order('registered_at', ascending: false);
    return (rows as List)
        .map((e) =>
            CustomerPackage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Đăng ký gói mới cho khách (tạo instance credit).
  Future<void> registerPackage({
    required String customerId,
    required String packageId,
    required int portionCount,
  }) async {
    await supabase.from('customer_packages').insert({
      'customer_id': customerId,
      'package_id': packageId,
      'credits_total': portionCount,
      'credits_remaining': portionCount,
    });
  }

  /// Nạp thêm tiền trả trước (cộng dồn). Trả về số dư mới.
  Future<int> topUp({required String customerId, required int amount}) async {
    final newBalance = await supabase.rpc('topup_balance', params: {
      'p_customer_id': customerId,
      'p_amount': amount,
    });
    return (newBalance as num).toInt();
  }
}
