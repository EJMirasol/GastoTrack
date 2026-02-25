import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

class LocalCacheService {
  static const String expensesBoxName = 'expenses';
  static const String pendingBoxName = 'pending_mutations';
  static const String userDataBoxName = 'user_data';
  static const String settingsBoxName = 'settings';

  late final Box<Map> _expensesBox;
  late final Box<Map> _pendingBox;
  late final Box<String> _userDataBox;
  late final Box<dynamic> _settingsBox;

  Future<void> initialize() async {
    await Hive.initFlutter();

    _expensesBox = await Hive.openBox<Map>(expensesBoxName);
    _pendingBox = await Hive.openBox<Map>(pendingBoxName);
    _userDataBox = await Hive.openBox<String>(userDataBoxName);
    _settingsBox = await Hive.openBox(settingsBoxName);
  }

  // === Expense Operations ===

  Future<void> saveExpense(Map<String, dynamic> expense) async {
    final id = expense['id'] as String;
    await _expensesBox.put(id, {
      ...expense,
      'cachedAt': DateTime.now().toIso8601String(),
    });
  }

  Map<String, dynamic>? getExpense(String id) {
    final data = _expensesBox.get(id);
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  List<Map<String, dynamic>> getAllExpenses(String userId) {
    return _expensesBox.values
        .where((e) => e['userId'] == userId)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> deleteExpense(String id) async {
    await _expensesBox.delete(id);
  }

  // === Pending Mutation Queue ===

  Future<void> addToSyncQueue(Map<String, dynamic> mutation) async {
    final id = mutation['id'] as String;
    await _pendingBox.put(id, {
      ...mutation,
      'createdAt': DateTime.now().toIso8601String(),
      'retryCount': 0,
    });
  }

  List<Map<String, dynamic>> getPendingMutations() {
    return _pendingBox.values.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<void> removePendingMutation(String id) async {
    await _pendingBox.delete(id);
  }

  Future<void> updateMutationRetry(
    String id,
    int retryCount,
    String? error,
  ) async {
    final mutation = _pendingBox.get(id);
    if (mutation != null) {
      await _pendingBox.put(id, {
        ...Map<String, dynamic>.from(mutation),
        'retryCount': retryCount,
        'lastError': error,
      });
    }
  }

  // === User Data Cache ===

  Future<void> cacheUserData(String key, Map<String, dynamic> data) async {
    await _userDataBox.put(
      key,
      jsonEncode({
        'data': data,
        'cachedAt': DateTime.now().toIso8601String(),
        'expiresAt': DateTime.now()
            .add(const Duration(days: 30))
            .toIso8601String(),
      }),
    );
  }

  Map<String, dynamic>? getCachedUserData(String key) {
    final value = _userDataBox.get(key);
    if (value == null) return null;

    try {
      final wrapper = jsonDecode(value) as Map<String, dynamic>;
      final expiresAt = DateTime.parse(wrapper['expiresAt'] as String);

      if (DateTime.now().isAfter(expiresAt)) {
        _userDataBox.delete(key);
        return null;
      }

      return wrapper['data'] as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // === Settings ===

  Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  T? getSetting<T>(String key) {
    return _settingsBox.get(key) as T?;
  }

  // === Data Expiration ===

  Future<void> cleanupExpiredData() async {
    final now = DateTime.now();
    final expirationDays = 30;

    final keysToDelete = <dynamic>[];

    for (final key in _expensesBox.keys) {
      final expense = _expensesBox.get(key);
      if (expense != null) {
        final cachedAtStr = expense['cachedAt'] as String?;
        if (cachedAtStr != null) {
          final cachedAt = DateTime.tryParse(cachedAtStr);
          if (cachedAt != null) {
            final expiresAt = cachedAt.add(Duration(days: expirationDays));
            if (now.isAfter(expiresAt)) {
              keysToDelete.add(key);
            }
          }
        }
      }
    }

    for (final key in keysToDelete) {
      await _expensesBox.delete(key);
    }
  }
}
