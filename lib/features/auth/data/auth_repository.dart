import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/user.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../core/services/convex_service.dart';

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
  final ConvexService _convex;

  AuthNotifier(this._cache, this._convex) : super(const AuthState()) {
    _restoreSession();
  }

  User? _userFromResponse(Map<String, dynamic> data) {
    final user = data['user'] as Map<String, dynamic>?;
    if (user == null) return null;
    return User(
      id: user['id'] as String,
      email: user['email'] as String,
      name: user['name'] as String?,
      subscriptionStatus: (user['subscriptionStatus'] as String?) == 'pro'
          ? SubscriptionStatus.pro
          : SubscriptionStatus.free,
      createdAt: user['createdAt'] != null
          ? DateTime.fromMillisecondsSinceEpoch(
              (user['createdAt'] as num).toInt(),
            )
          : DateTime.now(),
    );
  }

  Future<void> _restoreSession() async {
    final cookie = _cache.getSetting<String>('session_cookie');
    if (cookie == null) return;

    try {
      _convex.setSessionCookie(cookie);
      final result = await _convex.getSession();
      final user = _userFromResponse(result);

      if (user != null) {
        await _cache.saveSetting('current_user_id', user.id);
        await _cache.cacheUserData('currentUser', user.toJson());
        state = AuthState(user: user);
      } else {
        await _cache.saveSetting('session_cookie', null);
        await _cache.saveSetting('current_user_id', null);
        _convex.setSessionCookie(null);
      }
    } catch (_) {
      await _cache.saveSetting('session_cookie', null);
      await _cache.saveSetting('current_user_id', null);
      _convex.setSessionCookie(null);
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
      final result = await _convex.signUp(
        email: email,
        password: password,
        name: name,
      );

      final user = _userFromResponse(result);
      if (user != null) {
        final cookie = _convex.sessionCookie;
        if (cookie != null) {
          await _cache.saveSetting('session_cookie', cookie);
        }
        await _cache.saveSetting('current_user_id', user.id);
        await _cache.cacheUserData('currentUser', user.toJson());
        state = AuthState(user: user);
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Sign up failed: no user returned',
      );
      return false;
    } on ConvexApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
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
      final result = await _convex.signIn(email: email, password: password);

      final user = _userFromResponse(result);
      if (user != null) {
        final cookie = _convex.sessionCookie;
        if (cookie != null) {
          await _cache.saveSetting('session_cookie', cookie);
        }
        await _cache.saveSetting('current_user_id', user.id);
        await _cache.cacheUserData('currentUser', user.toJson());
        state = AuthState(user: user);
        return true;
      }

      state = state.copyWith(
        isLoading: false,
        error: 'Sign in failed: invalid credentials',
      );
      return false;
    } on ConvexApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
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
      await _convex.requestPasswordReset(email: email);
      state = state.copyWith(isLoading: false);
      return true;
    } on ConvexApiException catch (e) {
      state = state.copyWith(isLoading: false, error: e.message);
      return false;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Password reset failed: ${e.toString()}',
      );
      return false;
    }
  }

  Future<void> signOut() async {
    try {
      await _convex.signOut();
    } catch (_) {}

    await _cache.saveSetting('session_cookie', null);
    await _cache.saveSetting('current_user_id', null);
    _convex.setSessionCookie(null);
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
  final convex = ref.watch(convexServiceProvider);
  return AuthNotifier(cache, convex);
});

final isAuthenticatedProvider = Provider<bool>((ref) {
  return ref.watch(authProvider).isAuthenticated;
});

final currentUserProvider = Provider<User?>((ref) {
  return ref.watch(authProvider).user;
});
