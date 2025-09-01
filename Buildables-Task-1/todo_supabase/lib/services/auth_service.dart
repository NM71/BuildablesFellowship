import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart';

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  final SupabaseClient _supabase = Supabase.instance.client;

  // Get current user
  User? get currentUser => _supabase.auth.currentUser;

  // Check if user is authenticated
  bool get isAuthenticated => currentUser != null;

  // Auth state stream
  Stream<AuthState> get authStateStream => _supabase.auth.onAuthStateChange;

  // Sign up with email and password
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    try {
      final response = await _supabase.auth.signUp(
        email: email,
        password: password,
        data: fullName != null ? {'full_name': fullName} : null,
      );

      if (kDebugMode) {
        print('Sign up successful: ${response.user?.email}');
      }

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Sign up error: $e');
      }
      rethrow;
    }
  }

  // Sign in with email and password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );

      if (kDebugMode) {
        print('Sign in successful: ${response.user?.email}');
      }

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Sign in error: $e');
      }
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    try {
      await _supabase.auth.signOut();
      if (kDebugMode) {
        print('Sign out successful');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Sign out error: $e');
      }
      rethrow;
    }
  }

  // Reset password
  Future<void> resetPassword({required String email}) async {
    try {
      await _supabase.auth.resetPasswordForEmail(email);
      if (kDebugMode) {
        print('Password reset email sent to: $email');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Password reset error: $e');
      }
      rethrow;
    }
  }

  // Resend email confirmation
  Future<void> resendConfirmation({required String email}) async {
    try {
      await _supabase.auth.resend(type: OtpType.signup, email: email);
      if (kDebugMode) {
        print('Confirmation email resent to: $email');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Resend confirmation error: $e');
      }
      rethrow;
    }
  }

  // Update user profile
  Future<UserResponse> updateProfile({String? fullName, String? email}) async {
    try {
      final updates = <String, dynamic>{};
      if (fullName != null) updates['full_name'] = fullName;
      if (email != null) updates['email'] = email;

      final response = await _supabase.auth.updateUser(
        UserAttributes(
          email: email,
          data: fullName != null ? {'full_name': fullName} : null,
        ),
      );

      if (kDebugMode) {
        print('Profile updated successfully');
      }

      return response;
    } catch (e) {
      if (kDebugMode) {
        print('Profile update error: $e');
      }
      rethrow;
    }
  }

  // Get user profile data
  Map<String, dynamic>? get userMetadata => currentUser?.userMetadata;

  String? get userEmail => currentUser?.email;

  String? get userFullName => userMetadata?['full_name'] as String?;

  String get userId => currentUser?.id ?? '';

  // Check if email is confirmed
  bool get isEmailConfirmed => currentUser?.emailConfirmedAt != null;

  // Dispose resources
  void dispose() {
    // Clean up if needed
  }
}
