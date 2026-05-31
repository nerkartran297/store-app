import '../../domain/models/customer_group.dart';
import '../supabase_client.dart';

class CustomerGroupRepository {
  Future<List<CustomerGroup>> fetchAll() async {
    final rows = await supabase.from('customer_groups').select().order('name');
    return (rows as List)
        .map((e) => CustomerGroup.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<CustomerGroup> create(CustomerGroup g) async {
    final row = await supabase
        .from('customer_groups')
        .insert(g.toInsert())
        .select()
        .single();
    return CustomerGroup.fromJson(row);
  }

  Future<CustomerGroup> update(CustomerGroup g) async {
    final row = await supabase
        .from('customer_groups')
        .update(g.toInsert())
        .eq('id', g.id)
        .select()
        .single();
    return CustomerGroup.fromJson(row);
  }

  Future<void> delete(String id) async {
    await supabase.from('customer_groups').delete().eq('id', id);
  }
}
