import '../../domain/models/meal_package.dart';
import '../supabase_client.dart';

class PackageRepository {
  Future<List<MealPackage>> fetchAll({bool activeOnly = false}) async {
    var query = supabase.from('meal_packages').select();
    if (activeOnly) query = query.eq('is_active', true);
    final rows = await query.order('portion_count');
    return (rows as List)
        .map((e) => MealPackage.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<MealPackage> create(MealPackage p) async {
    final row = await supabase
        .from('meal_packages')
        .insert(p.toInsert())
        .select()
        .single();
    return MealPackage.fromJson(row);
  }

  Future<MealPackage> update(MealPackage p) async {
    final row = await supabase
        .from('meal_packages')
        .update(p.toInsert())
        .eq('id', p.id)
        .select()
        .single();
    return MealPackage.fromJson(row);
  }

  Future<void> delete(String id) async {
    await supabase.from('meal_packages').delete().eq('id', id);
  }

  /// Lấy tất cả customer_packages còn credit của một công ty (join customer + package).
  /// Dùng cho xuất hàng loạt theo công ty.
  Future<List<Map<String, dynamic>>> fetchCompanyPackageMembers(
      String company) async {
    final rows = await supabase
        .from('customer_packages')
        .select('*, customers!inner(id,name,company), meal_packages(*)')
        .eq('customers.company', company)
        .gt('credits_remaining', 0);
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
