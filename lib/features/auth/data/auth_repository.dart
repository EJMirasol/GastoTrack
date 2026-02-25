import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/domain/user.dart';

class AuthNotifier extends StateNotifier<User?> {
  AuthNotifier() : super(null);

  void signIn(String email, String name) {
    state = User(
      id: 'demo-user',
      email: email,
      name: name,
      subscriptionStatus: SubscriptionStatus.free,
      createdAt: DateTime.now(),
    );
  }

  void signOut() {
    state = null;
  }
}

final authProvider = StateNotifierProvider<AuthNotifier, User?>((ref) {
  return AuthNotifier();
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider) != null;
});
