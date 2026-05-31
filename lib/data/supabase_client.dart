import 'package:supabase_flutter/supabase_flutter.dart';

/// Truy cập nhanh Supabase client đã khởi tạo trong main().
SupabaseClient get supabase => Supabase.instance.client;
