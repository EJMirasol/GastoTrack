import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/transaction.dart';
import '../domain/category.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../core/services/convex_service.dart';
import '../../auth/data/auth_repository.dart';

final _uuid = Uuid();

final defaultCategories = [
  const Category(
    id: '1',
    name: 'Food',
    icon: 'restaurant',
    color: '#FF6B6B',
    isDefault: true,
  ),
  const Category(
    id: '2',
    name: 'Transport',
    icon: 'directions_car',
    color: '#4ECDC4',
    isDefault: true,
  ),
  const Category(
    id: '3',
    name: 'Shopping',
    icon: 'shopping_bag',
    color: '#45B7D1',
    isDefault: true,
  ),
  const Category(
    id: '4',
    name: 'Entertainment',
    icon: 'movie',
    color: '#96CEB4',
    isDefault: true,
  ),
  const Category(
    id: '5',
    name: 'Bills',
    icon: 'receipt',
    color: '#FECEA8',
    isDefault: true,
  ),
  const Category(
    id: '6',
    name: 'Health',
    icon: 'local_hospital',
    color: '#FF6F91',
    isDefault: true,
  ),
  const Category(
    id: '7',
    name: 'Education',
    icon: 'school',
    color: '#845EC2',
    isDefault: true,
  ),
  const Category(
    id: '8',
    name: 'Rent',
    icon: 'home',
    color: '#D65DB1',
    isDefault: true,
  ),
  const Category(
    id: '9',
    name: 'Salary',
    icon: 'account_balance_wallet',
    color: '#4CAF50',
    isDefault: true,
  ),
  const Category(
    id: '10',
    name: 'Other',
    icon: 'more_horiz',
    color: '#FFC75F',
    isDefault: true,
  ),
];

final categoriesProvider = Provider<List<Category>>((ref) {
  return defaultCategories;
});

class TransactionNotifier extends StateNotifier<List<Transaction>> {
  final LocalCacheService _cache;
  final ConvexService _convex;

  TransactionNotifier(this._cache, this._convex) : super([]);

  Future<void> loadForUser(String userId) async {
    final cached = _cache.getAllTransactions(userId);
    if (cached.isNotEmpty) {
      state = cached.map((e) => Transaction.fromJson(e)).toList();
    }

    try {
      final result = await _convex.query('transactions:getByUser', {
        'userId': userId,
      });
      final remote = result['value'] as List<dynamic>? ?? [];

      final transactions = remote.map((e) {
        final map = e as Map<String, dynamic>;
        return Transaction(
          id: map['_id'] as String,
          amount: (map['amount'] as num).toDouble(),
          categoryId: map['categoryId'] as String,
          userId: map['userId'] as String,
          groupId: map['groupId'] as String?,
          description: map['description'] as String?,
          date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
          type: map['type'] == 'income'
              ? TransactionType.income
              : TransactionType.expense,
          isRecurring: map['isRecurring'] as bool? ?? false,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            map['createdAt'] as int,
          ),
        );
      }).toList();

      for (final t in transactions) {
        await _cache.saveTransaction(t.toJson());
      }
      state = transactions;
    } catch (_) {}
  }

  Future<bool> addTransaction({
    required double amount,
    required String categoryId,
    required String userId,
    String? groupId,
    String? description,
    required DateTime date,
    TransactionType type = TransactionType.expense,
  }) async {
    final localId = _uuid.v4();
    final transaction = Transaction(
      id: localId,
      amount: amount,
      categoryId: categoryId,
      userId: userId,
      groupId: groupId,
      description: description,
      date: date,
      type: type,
      createdAt: DateTime.now(),
    );
    await _cache.saveTransaction(transaction.toJson());
    state = [...state, transaction];

    try {
      final args = <String, dynamic>{
        'amount': amount,
        'categoryId': categoryId,
        'date': date.millisecondsSinceEpoch,
        'type': type.name,
      };
      if (groupId != null) args['groupId'] = groupId;
      if (description != null) args['description'] = description;
      final result = await _convex.mutation('transactions:create', args);
      final convexId = result['value'] as String?;
      if (convexId != null) {
        await _cache.deleteTransaction(localId);
        final synced = transaction.copyWith(id: convexId);
        await _cache.saveTransaction({
          ...synced.toJson(),
          'convexId': convexId,
          'syncStatus': 'synced',
        });
        state = state.map((e) => e.id == localId ? synced : e).toList();
      }
      return true;
    } catch (_) {
      await _cache.addToSyncQueue({
        'id': localId,
        'type': 'create',
        'collection': 'transactions',
        'recordId': localId,
        'payload': {
          'amount': amount,
          'categoryId': categoryId,
          'groupId': groupId,
          'description': description,
          'date': date.millisecondsSinceEpoch,
          'type': type.name,
        },
      });
      return false;
    }
  }

  Future<void> removeTransaction(String id) async {
    await _cache.deleteTransaction(id);
    state = state.where((e) => e.id != id).toList();

    try {
      await _convex.mutation('transactions:remove', {'id': id});
    } catch (_) {
      await _cache.addToSyncQueue({
        'id': '${id}_delete',
        'type': 'delete',
        'collection': 'transactions',
        'recordId': id,
        'payload': {},
      });
    }
  }

  Future<void> updateTransaction(Transaction updated) async {
    await _cache.saveTransaction(updated.toJson());
    state = state.map((e) => e.id == updated.id ? updated : e).toList();

    try {
      await _convex.mutation('transactions:update', {
        'id': updated.id,
        'amount': updated.amount,
        'description': updated.description,
        'date': updated.date.millisecondsSinceEpoch,
        'categoryId': updated.categoryId,
      });
    } catch (_) {
      await _cache.addToSyncQueue({
        'id': '${updated.id}_update',
        'type': 'update',
        'collection': 'transactions',
        'recordId': updated.id,
        'payload': updated.toJson(),
      });
    }
  }

  List<Transaction> getTransactionsForMonth(DateTime month) {
    return state.where((e) {
      return e.date.year == month.year && e.date.month == month.month;
    }).toList();
  }

  double getTotalExpensesForMonth(DateTime month) {
    return getTransactionsForMonth(month)
        .where((e) => e.type == TransactionType.expense)
        .fold(0, (sum, e) => sum + e.amount);
  }

  double getTotalIncomeForMonth(DateTime month) {
    return getTransactionsForMonth(month)
        .where((e) => e.type == TransactionType.income)
        .fold(0, (sum, e) => sum + e.amount);
  }
}

final transactionsProvider =
    StateNotifierProvider<TransactionNotifier, List<Transaction>>((ref) {
      final cache = ref.watch(localCacheServiceProvider);
      final convex = ref.watch(convexServiceProvider);
      return TransactionNotifier(cache, convex);
    });

final selectedMonthProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

final monthlyTransactionsProvider = Provider<List<Transaction>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final transactions = ref.watch(transactionsProvider);
  return transactions.where((e) {
    return e.date.year == month.year && e.date.month == month.month;
  }).toList();
});

final totalExpensesForMonthProvider = Provider<double>((ref) {
  final transactions = ref.watch(monthlyTransactionsProvider);
  return transactions
      .where((e) => e.type == TransactionType.expense)
      .fold(0.0, (sum, e) => sum + e.amount);
});

final totalIncomeForMonthProvider = Provider<double>((ref) {
  final transactions = ref.watch(monthlyTransactionsProvider);
  return transactions
      .where((e) => e.type == TransactionType.income)
      .fold(0.0, (sum, e) => sum + e.amount);
});

final transactionsByCategoryProvider = Provider<Map<String, double>>((ref) {
  final transactions = ref.watch(monthlyTransactionsProvider);
  final byCategory = <String, double>{};
  for (final e in transactions.where(
    (e) => e.type == TransactionType.expense,
  )) {
    byCategory[e.categoryId] = (byCategory[e.categoryId] ?? 0) + e.amount;
  }
  return byCategory;
});
