import 'dart:math';
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
    _restoreSession();
  }

  String _generateUuid() {
    final random = Random.secure();
    final values = List<int>.generate(16, (_) => random.nextInt(256));
    values[6] = (values[6] & 0x0F) | 0x40;
    values[8] = (values[8] & 0x3F) | 0x80;
    return values.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  Future<void> _restoreSession() async {
    final hasVisited = _cache.getSetting<bool>('has_visited') ?? false;
    if (!hasVisited) return;

    final cached = _cache.getCachedUserData('currentUser');
    if (cached != null) {
      final user = User.fromJson(cached);
      state = AuthState(user: user);
    } else {
      final userId =
          _cache.getSetting<String>('current_user_id') ?? _generateUuid();
      final user = User(
        id: userId,
        email: '',
        name: 'User',
        createdAt: DateTime.now(),
      );
      await _cache.saveSetting('current_user_id', userId);
      await _cache.cacheUserData('currentUser', user.toJson());
      state = AuthState(user: user);
    }
  }

  Future<void> getStarted() async {
    final userId = _generateUuid();
    final user = User(
      id: userId,
      email: '',
      name: 'User',
      createdAt: DateTime.now(),
    );
    await _cache.saveSetting('has_visited', true);
    await _cache.saveSetting('current_user_id', userId);
    await _cache.cacheUserData('currentUser', user.toJson());
    state = AuthState(user: user);
  }

  Future<void> resetApp() async {
    await _cache.clearTransactions();
    await _cache.clearBudgets();
    await _cache.saveSetting('has_visited', false);
    await _cache.saveSetting('current_user_id', null);
    await _cache.userDataBox.delete('currentUser');
    state = const AuthState();
  }

  Future<bool> updateProfile({String? name, String? image}) async {
    if (state.user == null) return false;

    final updatedUser = state.user!.copyWith(
      name: name ?? state.user!.name,
      image: image ?? state.user!.image,
    );
    await _cache.cacheUserData('currentUser', updatedUser.toJson());
    state = AuthState(user: updatedUser);
    return true;
  }
}

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

final hasVisitedProvider = Provider<bool>((ref) {
  final cache = ref.watch(localCacheServiceProvider);
  return cache.getSetting<bool>('has_visited') ?? false;
});
