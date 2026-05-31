import '../../domain/models/discount.dart';
import '../supabase_client.dart';

class DiscountRepository {
  Future<List<Discount>> fetchAll() async {
    final rows = await supabase.from('discounts').select().order('code');
    return (rows as List)
        .map((e) => Discount.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Tìm mã theo code (uppercase). Null nếu không có.
  Future<Discount?> findByCode(String code) async {
    final row = await supabase
        .from('discounts')
        .select()
        .eq('code', code.trim().toUpperCase())
        .maybeSingle();
    return row == null ? null : Discount.fromJson(row);
  }

  Future<Discount> create(Discount d) async {
    final row =
        await supabase.from('discounts').insert(d.toInsert()).select().single();
    return Discount.fromJson(row);
  }

  Future<Discount> update(Discount d) async {
    final row = await supabase
        .from('discounts')
        .update(d.toInsert())
        .eq('id', d.id)
        .select()
        .single();
    return Discount.fromJson(row);
  }

  Future<void> delete(String id) async {
    await supabase.from('discounts').delete().eq('id', id);
  }
}
