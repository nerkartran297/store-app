import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/supabase_client.dart';

/// Stream trạng thái đăng nhập từ Supabase Auth.
final authStateProvider = StreamProvider<AuthState>((ref) {
  return supabase.auth.onAuthStateChange;
});

/// Có session hợp lệ không (đồng bộ, dùng cho router redirect).
final isLoggedInProvider = Provider<bool>((ref) {
  // Theo dõi authState để rebuild khi đổi.
  ref.watch(authStateProvider);
  return supabase.auth.currentSession != null;
});

class AuthController {
  Future<void> signIn(String email, String password) async {
    await supabase.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await supabase.auth.signOut();
  }
}

final authControllerProvider = Provider((_) => AuthController());
