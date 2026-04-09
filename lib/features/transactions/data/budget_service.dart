import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'transaction_repository.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/local_cache_service.dart';

class Budget {
  final String id;
  final String? categoryId;
  final double amount;
  final String period;
  final String? userId;

  Budget({
    required this.id,
    this.categoryId,
    required this.amount,
    required this.period,
    this.userId,
  });

  Budget copyWith({
    String? id,
    String? categoryId,
    double? amount,
    String? period,
    String? userId,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      userId: userId ?? this.userId,
    );
  }

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{
      'id': id,
      'categoryId': categoryId,
      'amount': amount,
      'period': period,
    };
    if (userId != null) map['userId'] = userId;
    return map;
  }

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
    id: json['id'] as String,
    categoryId: json['categoryId'] as String?,
    amount: (json['amount'] as num).toDouble(),
    period: json['period'] as String,
    userId: json['userId'] as String?,
  );
}

class BudgetNotifier extends StateNotifier<List<Budget>> {
  final LocalCacheService _cache;

  BudgetNotifier(this._cache) : super([]);

  Future<void> loadForUser(String userId) async {
    final cachedBudgets = _cache.getAllBudgets();
    state = cachedBudgets.map((b) => Budget.fromJson(b)).toList();
  }

  Future<void> setBudget({
    required String categoryId,
    required double amount,
    required String userId,
    String period = 'monthly',
  }) async {
    final existingIndex = state.indexWhere((b) => b.categoryId == categoryId);

    if (existingIndex >= 0) {
      final existing = state[existingIndex];
      final budget = existing.copyWith(amount: amount, period: period);
      state = [
        ...state.sublist(0, existingIndex),
        budget,
        ...state.sublist(existingIndex + 1),
      ];
      await _cache.saveBudget(budget.toJson());
    } else {
      final localId = DateTime.now().millisecondsSinceEpoch.toString();
      final budget = Budget(
        id: localId,
        categoryId: categoryId,
        amount: amount,
        period: period,
        userId: userId,
      );
      state = [...state, budget];
      await _cache.saveBudget(budget.toJson());
    }
  }

  Future<void> removeBudget(String categoryId) async {
    final budget = state.where((b) => b.categoryId == categoryId).firstOrNull;
    if (budget == null) return;

    await _cache.deleteBudget(budget.id);
    state = state.where((b) => b.categoryId != categoryId).toList();
  }

  Budget? getBudgetForCategory(String categoryId) {
    return state.where((b) => b.categoryId == categoryId).firstOrNull;
  }
}

final budgetsProvider = StateNotifierProvider<BudgetNotifier, List<Budget>>((
  ref,
) {
  final cache = ref.watch(localCacheServiceProvider);
  return BudgetNotifier(cache);
});

class BudgetAlertService {
  final Ref _ref;

  BudgetAlertService(this._ref);

  void checkBudgetAlerts(Map<String, double> expensesByCategory) {
    final budgets = _ref.read(budgetsProvider);
    final notificationService = _ref.read(notificationServiceProvider);

    for (final budget in budgets) {
      if (budget.categoryId == null) continue;
      if (budget.amount <= 0) continue;

      final spent = expensesByCategory[budget.categoryId!] ?? 0;
      final percentage = spent / budget.amount;

      if (percentage >= 0.8 && percentage < 1.0) {
        notificationService.showBudgetAlert(
          title: 'Budget Alert',
          body:
              'You\'ve reached 80% of your ${_getCategoryName(budget.categoryId!)} budget',
        );
      } else if (percentage >= 1.0) {
        notificationService.showBudgetAlert(
          title: 'Budget Exceeded',
          body:
              'You\'ve exceeded your ${_getCategoryName(budget.categoryId!)} budget!',
        );
      }
    }
  }

  String _getCategoryName(String categoryId) {
    final categories = _ref.read(categoriesProvider);
    final category = categories.where((c) => c.id == categoryId).firstOrNull;
    return category?.name ?? 'category';
  }
}

final budgetAlertServiceProvider = Provider<BudgetAlertService>((ref) {
  return BudgetAlertService(ref);
});
