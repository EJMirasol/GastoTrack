import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/expense.dart';
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

class ExpenseNotifier extends StateNotifier<List<Expense>> {
  final LocalCacheService _cache;
  final ConvexService _convex;

  ExpenseNotifier(this._cache, this._convex) : super([]);

  Future<void> loadForUser(String userId) async {
    final cachedExpenses = _cache.getAllExpenses(userId);
    if (cachedExpenses.isNotEmpty) {
      state = cachedExpenses.map((e) => Expense.fromJson(e)).toList();
    }

    try {
      final result = await _convex.query('expenses:getByUser', {
        'userId': userId,
      });
      final remoteExpenses = result['value'] as List<dynamic>? ?? [];

      final expenses = remoteExpenses.map((e) {
        final map = e as Map<String, dynamic>;
        return Expense(
          id: map['_id'] as String,
          amount: (map['amount'] as num).toDouble(),
          categoryId: map['categoryId'] as String,
          userId: map['userId'] as String,
          groupId: map['groupId'] as String?,
          description: map['description'] as String?,
          date: DateTime.fromMillisecondsSinceEpoch(map['date'] as int),
          type: map['type'] == 'income'
              ? ExpenseType.income
              : ExpenseType.expense,
          isRecurring: map['isRecurring'] as bool? ?? false,
          createdAt: DateTime.fromMillisecondsSinceEpoch(
            map['createdAt'] as int,
          ),
        );
      }).toList();

      for (final expense in expenses) {
        await _cache.saveExpense(expense.toJson());
      }
      state = expenses;
    } catch (_) {
      // Offline or error — keep cached data
    }
  }

  Future<void> addExpense({
    required double amount,
    required String categoryId,
    required String userId,
    String? groupId,
    String? description,
    required DateTime date,
    ExpenseType type = ExpenseType.expense,
  }) async {
    final localId = _uuid.v4();
    final expense = Expense(
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
    await _cache.saveExpense(expense.toJson());
    state = [...state, expense];

    try {
      final args = <String, dynamic>{
        'amount': amount,
        'categoryId': categoryId,
        'date': date.millisecondsSinceEpoch,
        'type': type.name,
      };
      if (groupId != null) args['groupId'] = groupId;
      if (description != null) args['description'] = description;
      final result = await _convex.mutation('expenses:create', args);
      final convexId = result['value'] as String?;
      if (convexId != null) {
        final syncedExpense = expense.copyWith(id: convexId);
        await _cache.saveExpense({
          ...syncedExpense.toJson(),
          'convexId': convexId,
          'syncStatus': 'synced',
        });
        state = state.map((e) => e.id == localId ? syncedExpense : e).toList();
      }
    } catch (_) {
      await _cache.addToSyncQueue({
        'id': localId,
        'type': 'create',
        'collection': 'expenses',
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
    }
  }

  Future<void> removeExpense(String id) async {
    await _cache.deleteExpense(id);
    state = state.where((e) => e.id != id).toList();

    try {
      await _convex.mutation('expenses:remove', {'id': id});
    } catch (_) {
      await _cache.addToSyncQueue({
        'id': '${id}_delete',
        'type': 'delete',
        'collection': 'expenses',
        'recordId': id,
        'payload': {},
      });
    }
  }

  Future<void> updateExpense(Expense updated) async {
    await _cache.saveExpense(updated.toJson());
    state = state.map((e) => e.id == updated.id ? updated : e).toList();

    try {
      await _convex.mutation('expenses:update', {
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
        'collection': 'expenses',
        'recordId': updated.id,
        'payload': updated.toJson(),
      });
    }
  }

  List<Expense> getExpensesForMonth(DateTime month) {
    return state.where((e) {
      return e.date.year == month.year && e.date.month == month.month;
    }).toList();
  }

  double getTotalExpensesForMonth(DateTime month) {
    return getExpensesForMonth(month)
        .where((e) => e.type == ExpenseType.expense)
        .fold(0, (sum, e) => sum + e.amount);
  }

  double getTotalIncomeForMonth(DateTime month) {
    return getExpensesForMonth(month)
        .where((e) => e.type == ExpenseType.income)
        .fold(0, (sum, e) => sum + e.amount);
  }
}

final expensesProvider = StateNotifierProvider<ExpenseNotifier, List<Expense>>((
  ref,
) {
  final cache = ref.watch(localCacheServiceProvider);
  final convex = ref.watch(convexServiceProvider);
  return ExpenseNotifier(cache, convex);
});

final selectedMonthProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

final monthlyExpensesProvider = Provider<List<Expense>>((ref) {
  final month = ref.watch(selectedMonthProvider);
  final expenses = ref.watch(expensesProvider);
  return expenses.where((e) {
    return e.date.year == month.year && e.date.month == month.month;
  }).toList();
});

final totalExpensesForMonthProvider = Provider<double>((ref) {
  final expenses = ref.watch(monthlyExpensesProvider);
  return expenses
      .where((e) => e.type == ExpenseType.expense)
      .fold(0.0, (sum, e) => sum + e.amount);
});

final totalIncomeForMonthProvider = Provider<double>((ref) {
  final expenses = ref.watch(monthlyExpensesProvider);
  return expenses
      .where((e) => e.type == ExpenseType.income)
      .fold(0.0, (sum, e) => sum + e.amount);
});

final expensesByCategoryProvider = Provider<Map<String, double>>((ref) {
  final expenses = ref.watch(monthlyExpensesProvider);
  final byCategory = <String, double>{};
  for (final e in expenses.where((e) => e.type == ExpenseType.expense)) {
    byCategory[e.categoryId] = (byCategory[e.categoryId] ?? 0) + e.amount;
  }
  return byCategory;
});
