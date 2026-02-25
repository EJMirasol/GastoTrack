import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/user.dart';
import '../../../core/services/local_cache_service.dart';

class AuthState {
  final User? user;
  final bool isLoading;
  final String? error;

  const AuthState({this.user, this.isLoading = false, this.error});

  AuthState copyWith({
    User? user,
    bool? isLoading,
    String? error,
    bool clearUser = false,
  }) {
    return AuthState(
      user: clearUser ? null : (user ?? this.user),
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  bool get isAuthenticated => user != null;
}

class AuthNotifier extends StateNotifier<AuthState> {
  final LocalCacheService _cache;

  AuthNotifier(this._cache) : super(const AuthState()) {
    _loadStoredUser();
  }

  Future<void> _loadStoredUser() async {
    final cachedUser = _cache.getCachedUserData('currentUser');

    if (cachedUser != null) {
      try {
        final user = User.fromJson(cachedUser);
        state = AuthState(user: user);
      } catch (e) {
        // Invalid cache, clear it
        await _cache.saveSetting('currentUser', null);
      }
    }
  }

  Future<bool> signUp({
    required String email,
    required String password,
    String? name,
  }) async {
    state = state.copyWith(isLoading: true, error: null);

    if (!_validatePassword(password)) {
      state = state.copyWith(
        isLoading: false,
        error:
            'Password must be at least 8 characters with 1 special character',
      );
      return false;
    }

    try {
      // Check if user already exists locally
      final existingEmail = _cache.getSetting<String>('user_email');
      if (existingEmail == email) {
        state = state.copyWith(
          isLoading: false,
          error: 'An account with this email already exists',
        );
        return false;
      }

      // Create user locally
      final userId = 'user_${DateTime.now().millisecondsSinceEpoch}';
      final user = User(
        id: userId,
        email: email,
        name: name,
        subscriptionStatus: SubscriptionStatus.free,
        createdAt: DateTime.now(),
      );

      // Store user data
      await _cache.cacheUserData('currentUser', user.toJson());
      await _cache.saveSetting('user_email', email);
      await _cache.saveSetting('user_password', password);

      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Sign up failed: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> signIn({required String email, required String password}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final storedEmail = _cache.getSetting<String>('user_email');
      final storedPassword = _cache.getSetting<String>('user_password');

      if (storedEmail != email || storedPassword != password) {
        state = state.copyWith(
          isLoading: false,
          error: 'Invalid email or password',
        );
        return false;
      }

      // Load cached user
      final cachedUser = _cache.getCachedUserData('currentUser');
      if (cachedUser != null) {
        final user = User.fromJson(cachedUser);
        state = AuthState(user: user);
        return true;
      }

      // Create user from stored data
      final user = User(
        id: 'user_${DateTime.now().millisecondsSinceEpoch}',
        email: email,
        subscriptionStatus: SubscriptionStatus.free,
        createdAt: DateTime.now(),
      );
      await _cache.cacheUserData('currentUser', user.toJson());
      state = AuthState(user: user);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Sign in failed: ${e.toString()}',
      );
      return false;
    }
  }

  Future<bool> resetPassword({required String email}) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final storedEmail = _cache.getSetting<String>('user_email');

      if (storedEmail != email) {
        state = state.copyWith(
          isLoading: false,
          error: 'No account found with this email',
        );
        return false;
      }

      // In a real app, this would send an email
      // For now, we'll just show a success message
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Password reset failed: ${e.toString()}',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    await _cache.saveSetting('currentUser', null);
    state = const AuthState();
  }

  bool _validatePassword(String password) {
    if (password.length < 8) return false;
    final hasSpecial = RegExp(r'[^a-zA-Z0-9]').hasMatch(password);
    return hasSpecial;
  }
}

final localCacheServiceProvider = Provider<LocalCacheService>((ref) {
  throw UnimplementedError('localCacheServiceProvider not overridden');
});

final authProvider = StateNotifierProvider<AuthNotifier, AuthState>((ref) {
  final cache = ref.watch(localCacheServiceProvider);
  return AuthNotifier(cache);
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});
