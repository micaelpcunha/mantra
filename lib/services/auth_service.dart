import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/auth_redirects.dart';

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  SupabaseClient get _client => Supabase.instance.client;

  Session? get currentSession => _client.auth.currentSession;
  User? get currentUser => _client.auth.currentUser;

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(email: email, password: password);
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
    required String companyName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      emailRedirectTo: publicAuthCallbackUrl,
      data: {
        'full_name': fullName.trim(),
        'pending_company_name': companyName.trim(),
        'role': 'technician',
      },
    );
  }

  Future<void> sendPasswordRecoveryEmail({required String email}) {
    return _client.auth.resetPasswordForEmail(
      email,
      redirectTo: publicAuthCallbackUrl,
    );
  }

  Future<UserResponse> updateEmail({required String email}) {
    return _client.auth.updateUser(
      UserAttributes(email: email.trim()),
      emailRedirectTo: publicAuthCallbackUrl,
    );
  }

  Future<void> sendPasswordReauthenticationCode() {
    return _client.auth.reauthenticate();
  }

  Future<UserResponse> updatePassword({
    required String password,
    String? nonce,
  }) {
    return _client.auth.updateUser(
      UserAttributes(password: password, nonce: nonce?.trim()),
    );
  }

  Future<void> signOut() {
    return _client.auth.signOut();
  }

  Future<bool> refreshSessionIfPossible() async {
    final session = currentSession;
    if (session == null) return false;

    await _client.auth.refreshSession();
    return true;
  }
}
