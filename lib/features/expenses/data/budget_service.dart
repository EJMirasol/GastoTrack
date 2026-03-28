import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'expense_repository.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/local_cache_service.dart';
import '../../../core/services/convex_service.dart';
import '../../auth/data/auth_repository.dart';

class Budget {
  final String id;
  final String? categoryId;
  final double amount;
  final String period;
  final String? userId;
  final String? convexId;

  Budget({
    required this.id,
    this.categoryId,
    required this.amount,
    required this.period,
    this.userId,
    this.convexId,
  });

  Budget copyWith({
    String? id,
    String? categoryId,
    double? amount,
    String? period,
    String? userId,
    String? convexId,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      period: period ?? this.period,
      userId: userId ?? this.userId,
      convexId: convexId ?? this.convexId,
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
    if (convexId != null) map['convexId'] = convexId;
    return map;
  }

  factory Budget.fromJson(Map<String, dynamic> json) => Budget(
    id: json['id'] as String,
    categoryId: json['categoryId'] as String?,
    amount: (json['amount'] as num).toDouble(),
    period: json['period'] as String,
    userId: json['userId'] as String?,
    convexId: json['convexId'] as String?,
  );
}

class BudgetNotifier extends StateNotifier<List<Budget>> {
  final LocalCacheService _cache;
  final ConvexService _convex;

  BudgetNotifier(this._cache, this._convex) : super([]);

  Future<void> loadForUser(String userId) async {
    final cachedBudgets = _cache.getAllBudgets();
    state = cachedBudgets.map((b) => Budget.fromJson(b)).toList();

    try {
      final result = await _convex.query('budgets:getByUser', {
        'userId': userId,
      });
      final remoteBudgets = result['value'] as List<dynamic>? ?? [];

      final budgets = remoteBudgets.map((b) {
        final map = b as Map<String, dynamic>;
        return Budget(
          id: map['_id'] as String,
          categoryId: map['categoryId'] as String?,
          amount: (map['amount'] as num).toDouble(),
          period: map['period'] as String,
          userId: map['userId'] as String,
          convexId: map['_id'] as String,
        );
      }).toList();

      for (final budget in budgets) {
        await _cache.saveBudget({
          ...budget.toJson(),
          'convexId': budget.id,
          'syncStatus': 'synced',
        });
      }
      state = budgets;
    } catch (_) {}
  }

  Future<void> setBudget({
    required String categoryId,
    required double amount,
    required String userId,
    String period = 'monthly',
  }) async {
    final existingIndex = state.indexWhere((b) => b.categoryId == categoryId);
    Budget budget;

    if (existingIndex >= 0) {
      final existing = state[existingIndex];
      budget = existing.copyWith(amount: amount, period: period);

      state = [
        ...state.sublist(0, existingIndex),
        budget,
        ...state.sublist(existingIndex + 1),
      ];

      try {
        if (budget.convexId != null) {
          await _convex.mutation('budgets:update', {
            'id': budget.convexId,
            'amount': amount,
            'period': period,
          });
        }
      } catch (_) {
        await _cache.addToSyncQueue({
          'id': '${budget.id}_update',
          'type': 'update',
          'collection': 'budgets',
          'recordId': budget.id,
          'payload': {'amount': amount, 'period': period},
        });
      }
    } else {
      final localId = DateTime.now().millisecondsSinceEpoch.toString();
      budget = Budget(
        id: localId,
        categoryId: categoryId,
        amount: amount,
        period: period,
        userId: userId,
      );
      state = [...state, budget];

      try {
        final result = await _convex.mutation('budgets:create', {
          'categoryId': categoryId,
          'amount': amount,
          'period': period,
        });
        final convexId = result['value'] as String?;
        if (convexId != null) {
          final updatedBudget = budget.copyWith(
            id: convexId,
            convexId: convexId,
          );
          await _cache.saveBudget({
            ...updatedBudget.toJson(),
            'convexId': convexId,
            'syncStatus': 'synced',
          });
          state = state
              .map((b) => b.id == localId ? updatedBudget : b)
              .toList();
        }
      } catch (_) {
        await _cache.addToSyncQueue({
          'id': localId,
          'type': 'create',
          'collection': 'budgets',
          'recordId': localId,
          'payload': {
            'categoryId': categoryId,
            'amount': amount,
            'period': period,
          },
        });
      }
    }

    await _cache.saveBudget(budget.toJson());
  }

  Future<void> removeBudget(String categoryId) async {
    final budget = state.where((b) => b.categoryId == categoryId).firstOrNull;
    if (budget == null) return;

    await _cache.deleteBudget(budget.id);
    state = state.where((b) => b.categoryId != categoryId).toList();

    try {
      if (budget.convexId != null) {
        await _convex.mutation('budgets:remove', {'id': budget.convexId});
      }
    } catch (_) {
      await _cache.addToSyncQueue({
        'id': '${budget.id}_delete',
        'type': 'delete',
        'collection': 'budgets',
        'recordId': budget.id,
        'payload': {},
      });
    }
  }

  Budget? getBudgetForCategory(String categoryId) {
    return state.where((b) => b.categoryId == categoryId).firstOrNull;
  }
}

final budgetsProvider = StateNotifierProvider<BudgetNotifier, List<Budget>>((
  ref,
) {
  final cache = ref.watch(localCacheServiceProvider);
  final convex = ref.watch(convexServiceProvider);
  return BudgetNotifier(cache, convex);
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
