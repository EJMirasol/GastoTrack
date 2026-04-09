import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';

class LocalCacheService {
  static const String transactionsBoxName = 'transactions';
  static const String userDataBoxName = 'user_data';
  static const String settingsBoxName = 'settings';
  static const String budgetsBoxName = 'budgets';
  static const String categoriesBoxName = 'categories';

  late final Box<Map> _transactionsBox;
  late final Box<String> _userDataBox;
  late final Box<dynamic> _settingsBox;
  late final Box<Map> _budgetsBox;
  late final Box<Map> _categoriesBox;

  Future<void> initialize() async {
    await Hive.initFlutter();

    _transactionsBox = await Hive.openBox<Map>(transactionsBoxName);
    _userDataBox = await Hive.openBox<String>(userDataBoxName);
    _settingsBox = await Hive.openBox(settingsBoxName);
    _budgetsBox = await Hive.openBox<Map>(budgetsBoxName);
    _categoriesBox = await Hive.openBox<Map>(categoriesBoxName);
  }

  Future<void> saveTransaction(Map<String, dynamic> transaction) async {
    final id = transaction['id'] as String;
    await _transactionsBox.put(id, {
      ...transaction,
      'cachedAt': DateTime.now().toIso8601String(),
    });
  }

  Map<String, dynamic>? getTransaction(String id) {
    final data = _transactionsBox.get(id);
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  List<Map<String, dynamic>> getAllTransactions(String userId) {
    return _transactionsBox.values
        .where((e) => e['userId'] == userId)
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> deleteTransaction(String id) async {
    await _transactionsBox.delete(id);
  }

  Future<void> clearTransactions() async {
    await _transactionsBox.clear();
  }

  Box<Map> get transactionsBox => _transactionsBox;

  Box<String> get userDataBox => _userDataBox;

  Future<void> cacheUserData(String key, Map<String, dynamic> data) async {
    await _userDataBox.put(
      key,
      jsonEncode({'data': data, 'cachedAt': DateTime.now().toIso8601String()}),
    );
  }

  Map<String, dynamic>? getCachedUserData(String key) {
    final value = _userDataBox.get(key);
    if (value == null) return null;

    try {
      final wrapper = jsonDecode(value) as Map<String, dynamic>;
      return wrapper['data'] as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  Future<void> saveSetting(String key, dynamic value) async {
    await _settingsBox.put(key, value);
  }

  T? getSetting<T>(String key) {
    return _settingsBox.get(key) as T?;
  }

  Box<dynamic> get settingsBox => _settingsBox;

  Future<void> saveBudget(Map<String, dynamic> budget) async {
    final id = budget['id'] as String;
    await _budgetsBox.put(id, {
      ...budget,
      'cachedAt': DateTime.now().toIso8601String(),
    });
  }

  Map<String, dynamic>? getBudget(String id) {
    final data = _budgetsBox.get(id);
    if (data == null) return null;
    return Map<String, dynamic>.from(data);
  }

  List<Map<String, dynamic>> getAllBudgets() {
    return _budgetsBox.values.map((b) => Map<String, dynamic>.from(b)).toList();
  }

  Future<void> deleteBudget(String id) async {
    await _budgetsBox.delete(id);
  }

  Future<void> clearBudgets() async {
    await _budgetsBox.clear();
  }

  Box<Map> get budgetsBox => _budgetsBox;

  Future<void> saveCategory(Map<String, dynamic> category) async {
    final id = category['id'] as String;
    await _categoriesBox.put(id, category);
  }

  void deleteCategory(String id) {
    _categoriesBox.delete(id);
  }

  List<Map<String, dynamic>> getAllCategories() {
    return _categoriesBox.values
        .map((c) => Map<String, dynamic>.from(c))
        .toList();
  }

  Future<void> clearCategories() async {
    await _categoriesBox.clear();
  }

  Box<Map> get categoriesBox => _categoriesBox;

  Future<void> savePendingTransferIds(List<String> ids) async {
    await _settingsBox.put('pending_transfer_ids', ids);
  }

  List<String> getPendingTransferIds() {
    final raw = _settingsBox.get('pending_transfer_ids');
    if (raw == null) return [];
    return (raw as List).cast<String>();
  }

  Future<void> clearPendingTransferIds() async {
    await _settingsBox.delete('pending_transfer_ids');
  }
}

final localCacheServiceProvider = Provider<LocalCacheService>((ref) {
  throw UnimplementedError('localCacheServiceProvider must be overridden');
});
