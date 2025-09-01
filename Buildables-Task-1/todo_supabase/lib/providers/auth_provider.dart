import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';

// Auth state enum
enum AuthStatus {
  initial,
  loading,
  authenticated,
  unauthenticated,
  emailNotConfirmed,
}

// Auth state model
class AppAuthState {
  final AuthStatus status;
  final User? user;
  final String? error;
  final bool isLoading;

  const AppAuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.error,
    this.isLoading = false,
  });

  AppAuthState copyWith({
    AuthStatus? status,
    User? user,
    String? error,
    bool? isLoading,
  }) {
    return AppAuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  // Convenience getters
  bool get isAuthenticated => status == AuthStatus.authenticated;
  bool get isUnauthenticated => status == AuthStatus.unauthenticated;
  bool get needsEmailConfirmation => status == AuthStatus.emailNotConfirmed;
  String get userId => user?.id ?? '';
  String get userEmail => user?.email ?? '';
  String? get userFullName => user?.userMetadata?['full_name'] as String?;
}

// Auth notifier
class AuthNotifier extends StateNotifier<AppAuthState> {
  final AuthService _authService;
  StreamSubscription<AuthState>? _authSubscription;

  AuthNotifier(this._authService) : super(const AppAuthState()) {
    _initialize();
  }

  void _initialize() {
    // Check initial auth state
    final currentUser = _authService.currentUser;
    if (currentUser != null) {
      if (_authService.isEmailConfirmed) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: currentUser,
        );
      } else {
        state = state.copyWith(
          status: AuthStatus.emailNotConfirmed,
          user: currentUser,
        );
      }
    } else {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }

    // Listen to auth state changes
    _authSubscription = _authService.authStateStream.listen(
      (authState) {
        if (kDebugMode) {
          print('Auth state changed: ${authState.event}');
        }

        switch (authState.event) {
          case AuthChangeEvent.signedIn:
            if (_authService.isEmailConfirmed) {
              state = state.copyWith(
                status: AuthStatus.authenticated,
                user: authState.session?.user,
                error: null,
                isLoading: false,
              );
            } else {
              state = state.copyWith(
                status: AuthStatus.emailNotConfirmed,
                user: authState.session?.user,
                error: null,
                isLoading: false,
              );
            }
            break;
            
          case AuthChangeEvent.signedOut:
            state = state.copyWith(
              status: AuthStatus.unauthenticated,
              user: null,
              error: null,
              isLoading: false,
            );
            break;
            
          case AuthChangeEvent.tokenRefreshed:
            if (_authService.isEmailConfirmed) {
              state = state.copyWith(
                status: AuthStatus.authenticated,
                user: authState.session?.user,
              );
            }
            break;
            
          default:
            break;
        }
      },
      onError: (error) {
        if (kDebugMode) {
          print('Auth stream error: $error');
        }
        state = state.copyWith(
          error: error.toString(),
          isLoading: false,
        );
      },
    );
  }

  // Sign up
  Future<String?> signUp({
    required String email,
    required String password,
    String? fullName,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final response = await _authService.signUp(
        email: email,
        password: password,
        fullName: fullName,
      );

      if (response.user != null && response.session == null) {
        // Email confirmation required
        state = state.copyWith(
          status: AuthStatus.emailNotConfirmed,
          user: response.user,
          isLoading: false,
        );
        return 'Please check your email and click the confirmation link to activate your account.';
      } else if (response.user != null && response.session != null) {
        // Signed in successfully (if email confirmation is disabled)
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: response.user,
          isLoading: false,
        );
        return 'Account created successfully!';
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          error: 'Failed to create account',
        );
        return 'Failed to create account. Please try again.';
      }
    } catch (e) {
      final errorMessage = _getErrorMessage(e);
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      return errorMessage;
    }
  }

  // Sign in
  Future<String?> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, error: null);
    
    try {
      final response = await _authService.signIn(
        email: email,
        password: password,
      );

      if (response.user != null) {
        if (_authService.isEmailConfirmed) {
          state = state.copyWith(
            status: AuthStatus.authenticated,
            user: response.user,
            isLoading: false,
          );
          return 'Welcome back!';
        } else {
          state = state.copyWith(
            status: AuthStatus.emailNotConfirmed,
            user: response.user,
            isLoading: false,
          );
          return 'Please confirm your email address to continue.';
        }
      } else {
        state = state.copyWith(
          status: AuthStatus.unauthenticated,
          isLoading: false,
          error: 'Failed to sign in',
        );
        return 'Failed to sign in. Please check your credentials.';
      }
    } catch (e) {
      final errorMessage = _getErrorMessage(e);
      state = state.copyWith(
        isLoading: false,
        error: errorMessage,
      );
      return errorMessage;
    }
  }

  // Sign out
  Future<void> signOut() async {
    state = state.copyWith(isLoading: true);
    
    try {
      await _authService.signOut();
      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        user: null,
        isLoading: false,
        error: null,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: _getErrorMessage(e),
      );
    }
  }

  // Reset password
  Future<String> resetPassword({required String email}) async {
    try {
      await _authService.resetPassword(email: email);
      return 'Password reset email sent! Check your inbox.';
    } catch (e) {
      return _getErrorMessage(e);
    }
  }

  // Resend confirmation email
  Future<String> resendConfirmation({required String email}) async {
    try {
      await _authService.resendConfirmation(email: email);
      return 'Confirmation email sent! Check your inbox.';
    } catch (e) {
      return _getErrorMessage(e);
    }
  }

  // Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  // Helper method to extract user-friendly error messages
  String _getErrorMessage(dynamic error) {
    if (error is AuthException) {
      switch (error.message.toLowerCase()) {
        case 'invalid login credentials':
          return 'Invalid email or password. Please try again.';
        case 'email not confirmed':
          return 'Please confirm your email address before signing in.';
        case 'user already registered':
          return 'An account with this email already exists.';
        case 'signup disabled':
          return 'New registrations are currently disabled.';
        default:
          return error.message;
      }
    } else if (error is PostgrestException) {
      return 'Database error: ${error.message}';
    } else {
      return error.toString();
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }
}

// Auth providers
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final authProvider = StateNotifierProvider<AuthNotifier, AppAuthState>((ref) {
  final authService = ref.read(authServiceProvider);
  return AuthNotifier(authService);
});

// Convenience providers
final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final authLoadingProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isLoading;
});
