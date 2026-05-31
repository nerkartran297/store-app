import '../../domain/models/product.dart';
import '../supabase_client.dart';

class ProductRepository {
  Future<List<Product>> fetchAll({bool activeOnly = false}) async {
    var query = supabase.from('products').select();
    if (activeOnly) query = query.eq('is_active', true);
    final rows = await query.order('name');
    return (rows as List)
        .map((e) => Product.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Product> create(Product p) async {
    final row =
        await supabase.from('products').insert(p.toInsert()).select().single();
    return Product.fromJson(row);
  }

  Future<Product> update(Product p) async {
    final row = await supabase
        .from('products')
        .update(p.toInsert())
        .eq('id', p.id)
        .select()
        .single();
    return Product.fromJson(row);
  }

  Future<void> delete(String id) async {
    await supabase.from('products').delete().eq('id', id);
  }
}
