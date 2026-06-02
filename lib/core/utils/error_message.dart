import 'package:supabase_flutter/supabase_flutter.dart';

/// Rút gọn lỗi kỹ thuật thành thông báo thân thiện cho người dùng cuối.
String friendlyError(Object e) {
  if (e is PostgrestException) {
    // RPC dùng `raise exception '...'` -> message tiếng Việt rõ ràng.
    return e.message;
  }
  if (e is AuthException) {
    return e.message;
  }
  final s = e.toString();
  // Cắt prefix loại "Exception: " nếu có.
  return s.replaceFirst(RegExp(r'^[A-Za-z]+(Exception)?:\s*'), '');
}
