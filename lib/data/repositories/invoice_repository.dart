import '../../domain/models/invoice.dart';
import '../supabase_client.dart';

class InvoiceRepository {
  /// Tạo hóa đơn nguyên tử qua RPC create_invoice.
  /// Trả về invoice id.
  Future<String> createInvoice(Map<String, dynamic> payload) async {
    final id = await supabase.rpc('create_invoice', params: {
      'p_payload': payload,
    });
    return id as String;
  }

  Future<List<Invoice>> fetchAll({String? search}) async {
    var query = supabase
        .from('invoices')
        .select('*, invoice_items(*)');
    if (search != null && search.trim().isNotEmpty) {
      query = query.ilike('customer_name_snapshot', '%${search.trim()}%');
    }
    final rows = await query.order('created_at', ascending: false).limit(200);
    return (rows as List)
        .map((e) => Invoice.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Invoice> getById(String id) async {
    final row = await supabase
        .from('invoices')
        .select('*, invoice_items(*)')
        .eq('id', id)
        .single();
    return Invoice.fromJson(row);
  }
}
