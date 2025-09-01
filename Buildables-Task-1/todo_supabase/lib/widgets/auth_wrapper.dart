import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../screens/auth/sign_in_page.dart';
import '../screens/auth/email_confirmation_page.dart';
import '../widgets/bottom_navigation.dart';

class AuthWrapper extends ConsumerWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    // Show loading screen while checking auth state
    if (authState.status == AuthStatus.initial) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xff38b17d),
          ),
        ),
      );
    }

    // Show email confirmation screen if email is not confirmed
    if (authState.needsEmailConfirmation && authState.user != null) {
      return EmailConfirmationPage(email: authState.userEmail);
    }

    // Show main app if authenticated
    if (authState.isAuthenticated) {
      return const BottomNavigation();
    }

    // Show sign in screen if not authenticated
    return const SignInPage();
  }
}
