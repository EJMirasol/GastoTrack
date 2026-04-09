import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../domain/transaction.dart';
import '../domain/category.dart';
import '../../../core/services/local_cache_service.dart';

final _uuid = Uuid();

enum SortOption { newestFirst, oldestFirst, amountHighLow, amountLowHigh }

class TransactionFilter {
  final TransactionType? type;
  final Set<String> categoryIds;
  final PaymentMethod? paymentMethod;
  final SortOption sort;

  const TransactionFilter({
    this.type,
    this.categoryIds = const {},
    this.paymentMethod,
    this.sort = SortOption.newestFirst,
  });

  TransactionFilter copyWith({
    TransactionType? type,
    bool clearType = false,
    Set<String>? categoryIds,
    PaymentMethod? paymentMethod,
    bool clearPaymentMethod = false,
    SortOption? sort,
  }) {
    return TransactionFilter(
      type: clearType ? null : (type ?? this.type),
      categoryIds: categoryIds ?? this.categoryIds,
      paymentMethod: clearPaymentMethod
          ? null
          : (paymentMethod ?? this.paymentMethod),
      sort: sort ?? this.sort,
    );
  }

  bool get hasActiveFilters =>
      type != null ||
      categoryIds.isNotEmpty ||
      paymentMethod != null ||
      sort != SortOption.newestFirst;
}

final defaultCategories = [
  const Category(
    id: '1',
    name: 'Food',
    icon: 'restaurant',
    color: '#FF6B6B',
    isDefault: true,
    order: 0,
    categoryType: 'expense',
  ),
  const Category(
    id: '2',
    name: 'Transport',
    icon: 'directions_car',
    color: '#4ECDC4',
    isDefault: true,
    order: 1,
    categoryType: 'expense',
  ),
  const Category(
    id: '3',
    name: 'Shopping',
    icon: 'shopping_bag',
    color: '#45B7D1',
    isDefault: true,
    order: 2,
    categoryType: 'expense',
  ),
  const Category(
    id: '4',
    name: 'Entertainment',
    icon: 'movie',
    color: '#96CEB4',
    isDefault: true,
    order: 3,
    categoryType: 'expense',
  ),
  const Category(
    id: '5',
    name: 'Bills',
    icon: 'receipt',
    color: '#FECEA8',
    isDefault: true,
    order: 4,
    categoryType: 'expense',
  ),
  const Category(
    id: '6',
    name: 'Health',
    icon: 'local_hospital',
    color: '#FF6F91',
    isDefault: true,
    order: 5,
    categoryType: 'expense',
  ),
  const Category(
    id: '7',
    name: 'Education',
    icon: 'school',
    color: '#845EC2',
    isDefault: true,
    order: 6,
    categoryType: 'expense',
  ),
  const Category(
    id: '8',
    name: 'Rent',
    icon: 'home',
    color: '#D65DB1',
    isDefault: true,
    order: 7,
    categoryType: 'expense',
  ),
  const Category(
    id: '9',
    name: 'Salary',
    icon: 'account_balance_wallet',
    color: '#4CAF50',
    isDefault: true,
    order: 8,
    categoryType: 'income',
  ),
  const Category(
    id: '10',
    name: 'Other',
    icon: 'more_horiz',
    color: '#FFC75F',
    isDefault: true,
    order: 9,
    categoryType: 'both',
  ),
  const Category(
    id: '11',
    name: 'Transfer Fee',
    icon: 'swap_horiz',
    color: '#FF8A65',
    isDefault: true,
    order: 10,
    categoryType: 'both',
  ),
];

class CategoryNotifier extends StateNotifier<List<Category>> {
  final LocalCacheService _cache;

  CategoryNotifier(this._cache) : super([]) {
    _load();
  }

  void _load() {
    final cached = _cache.getAllCategories();
    if (cached.isEmpty) {
      for (final c in defaultCategories) {
        _cache.saveCategory(c.toJson());
      }
      state = List.from(defaultCategories);
    } else {
      state = cached.map((c) => Category.fromJson(c)).toList()
        ..sort((a, b) => a.order.compareTo(b.order));
    }
  }

  Future<void> addCategory(Category category) async {
    await _cache.saveCategory(category.toJson());
    state = [...state, category]..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> updateCategory(Category category) async {
    await _cache.saveCategory(category.toJson());
    state = state.map((c) => c.id == category.id ? category : c).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
  }

  Future<void> deleteCategory(String id) async {
    _cache.deleteCategory(id);
    state = state.where((c) => c.id != id).toList();
  }

  Future<void> reorderCategories(int oldIndex, int newIndex) async {
    if (oldIndex < newIndex) newIndex -= 1;
    final items = List<Category>.from(state);
    final item = items.removeAt(oldIndex);
    items.insert(newIndex, item);
    final reordered = items.asMap().entries.map((e) {
      return e.value.copyWith(order: e.key);
    }).toList();
    state = reordered;
    for (final c in reordered) {
      await _cache.saveCategory(c.toJson());
    }
  }

  Future<void> restoreDefaults() async {
    await _cache.clearCategories();
    for (final c in defaultCategories) {
      await _cache.saveCategory(c.toJson());
    }
    state = List.from(defaultCategories);
  }
}

final categoriesProvider =
    StateNotifierProvider<CategoryNotifier, List<Category>>((ref) {
      final cache = ref.watch(localCacheServiceProvider);
      return CategoryNotifier(cache);
    });

class TransactionNotifier extends StateNotifier<List<Transaction>> {
  final LocalCacheService _cache;

  TransactionNotifier(this._cache) : super([]);

  Future<void> loadForUser(String userId) async {
    await _cleanupPendingTransfers();
    final cached = _cache.getAllTransactions(userId);
    state = cached.map((e) => Transaction.fromJson(e)).toList();
  }

  Future<void> _cleanupPendingTransfers() async {
    final pendingIds = _cache.getPendingTransferIds();
    if (pendingIds.isEmpty) return;
    for (final id in pendingIds) {
      try {
        await _cache.deleteTransaction(id);
      } catch (_) {}
    }
    await _cache.clearPendingTransferIds();
  }

  Future<void> savePendingTransferIds(List<String> ids) async {
    await _cache.savePendingTransferIds(ids);
  }

  Future<void> clearPendingTransferIds() async {
    await _cache.clearPendingTransferIds();
  }

  Future<String> addTransaction({
    required double amount,
    required String categoryId,
    required String userId,
    String? groupId,
    String? description,
    required DateTime date,
    TransactionType type = TransactionType.expense,
    PaymentMethod paymentMethod = PaymentMethod.cash,
    bool isTransfer = false,
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
      paymentMethod: paymentMethod,
      isTransfer: isTransfer,
      createdAt: DateTime.now(),
    );
    await _cache.saveTransaction(transaction.toJson());
    state = [...state, transaction];
    return localId;
  }

  Future<void> removeTransaction(String id) async {
    await _cache.deleteTransaction(id);
    state = state.where((e) => e.id != id).toList();
  }

  Future<void> updateTransaction(Transaction updated) async {
    await _cache.saveTransaction(updated.toJson());
    state = state.map((e) => e.id == updated.id ? updated : e).toList();
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
      return TransactionNotifier(cache);
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

final transactionFilterProvider = StateProvider<TransactionFilter>((ref) {
  return const TransactionFilter();
});

final filteredTransactionsProvider = Provider<List<Transaction>>((ref) {
  final transactions = ref.watch(monthlyTransactionsProvider);
  final filter = ref.watch(transactionFilterProvider);

  var filtered = transactions.where((e) => !e.isTransfer);

  if (filter.type != null) {
    filtered = filtered.where((e) => e.type == filter.type);
  }
  if (filter.categoryIds.isNotEmpty) {
    filtered = filtered.where((e) => filter.categoryIds.contains(e.categoryId));
  }
  if (filter.paymentMethod != null) {
    filtered = filtered.where((e) => e.paymentMethod == filter.paymentMethod);
  }

  final result = filtered.toList();

  switch (filter.sort) {
    case SortOption.newestFirst:
      result.sort((a, b) => b.date.compareTo(a.date));
    case SortOption.oldestFirst:
      result.sort((a, b) => a.date.compareTo(b.date));
    case SortOption.amountHighLow:
      result.sort((a, b) => b.amount.compareTo(a.amount));
    case SortOption.amountLowHigh:
      result.sort((a, b) => a.amount.compareTo(b.amount));
  }

  return result;
});

final totalExpensesForMonthProvider = Provider<double>((ref) {
  final transactions = ref.watch(monthlyTransactionsProvider);
  return transactions
      .where((e) => e.type == TransactionType.expense && !e.isTransfer)
      .fold(0.0, (sum, e) => sum + e.amount);
});

final totalIncomeForMonthProvider = Provider<double>((ref) {
  final transactions = ref.watch(monthlyTransactionsProvider);
  return transactions
      .where((e) => e.type == TransactionType.income && !e.isTransfer)
      .fold(0.0, (sum, e) => sum + e.amount);
});

final transactionsByCategoryProvider = Provider<Map<String, double>>((ref) {
  final transactions = ref.watch(monthlyTransactionsProvider);
  final byCategory = <String, double>{};
  for (final e in transactions.where(
    (e) => e.type == TransactionType.expense && !e.isTransfer,
  )) {
    byCategory[e.categoryId] = (byCategory[e.categoryId] ?? 0) + e.amount;
  }
  return byCategory;
});

final cashBalanceProvider = Provider<double>((ref) {
  final transactions = ref.watch(monthlyTransactionsProvider);
  return transactions.where((e) => e.paymentMethod == PaymentMethod.cash).fold(
    0.0,
    (sum, e) {
      return e.type == TransactionType.income ? sum + e.amount : sum - e.amount;
    },
  );
});

final ewalletBalanceProvider = Provider<double>((ref) {
  final transactions = ref.watch(monthlyTransactionsProvider);
  return transactions
      .where((e) => e.paymentMethod == PaymentMethod.ewallet)
      .fold(0.0, (sum, e) {
        return e.type == TransactionType.income
            ? sum + e.amount
            : sum - e.amount;
      });
});

final bankBalanceProvider = Provider<double>((ref) {
  final transactions = ref.watch(monthlyTransactionsProvider);
  return transactions.where((e) => e.paymentMethod == PaymentMethod.bank).fold(
    0.0,
    (sum, e) {
      return e.type == TransactionType.income ? sum + e.amount : sum - e.amount;
    },
  );
});

final allTimeCashBalanceProvider = Provider<double>((ref) {
  final transactions = ref.watch(transactionsProvider);
  return transactions.where((e) => e.paymentMethod == PaymentMethod.cash).fold(
    0.0,
    (sum, e) {
      return e.type == TransactionType.income ? sum + e.amount : sum - e.amount;
    },
  );
});

final allTimeEwalletBalanceProvider = Provider<double>((ref) {
  final transactions = ref.watch(transactionsProvider);
  return transactions
      .where((e) => e.paymentMethod == PaymentMethod.ewallet)
      .fold(0.0, (sum, e) {
        return e.type == TransactionType.income
            ? sum + e.amount
            : sum - e.amount;
      });
});

final allTimeBankBalanceProvider = Provider<double>((ref) {
  final transactions = ref.watch(transactionsProvider);
  return transactions.where((e) => e.paymentMethod == PaymentMethod.bank).fold(
    0.0,
    (sum, e) {
      return e.type == TransactionType.income ? sum + e.amount : sum - e.amount;
    },
  );
});
