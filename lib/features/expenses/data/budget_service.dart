import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'expense_repository.dart';
import '../../../core/services/notification_service.dart';

class Budget {
  final String id;
  final String? categoryId;
  final double amount;
  final String period;

  Budget({
    required this.id,
    this.categoryId,
    required this.amount,
    required this.period,
  });

  Budget copyWith({
    String? id,
    String? categoryId,
    double? amount,
    String? period,
  }) {
    return Budget(
      id: id ?? this.id,
      categoryId: categoryId ?? this.categoryId,
      amount: amount ?? this.amount,
      period: period ?? this.period,
    );
  }
}

class BudgetNotifier extends StateNotifier<List<Budget>> {
  BudgetNotifier() : super([]);

  void setBudget({
    required String categoryId,
    required double amount,
    String period = 'monthly',
  }) {
    final existingIndex = state.indexWhere((b) => b.categoryId == categoryId);

    if (existingIndex >= 0) {
      state = [
        ...state.sublist(0, existingIndex),
        Budget(
          id: state[existingIndex].id,
          categoryId: categoryId,
          amount: amount,
          period: period,
        ),
        ...state.sublist(existingIndex + 1),
      ];
    } else {
      state = [
        ...state,
        Budget(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          categoryId: categoryId,
          amount: amount,
          period: period,
        ),
      ];
    }
  }

  void removeBudget(String categoryId) {
    state = state.where((b) => b.categoryId != categoryId).toList();
  }

  Budget? getBudgetForCategory(String categoryId) {
    return state.where((b) => b.categoryId == categoryId).firstOrNull;
  }
}

final budgetsProvider = StateNotifierProvider<BudgetNotifier, List<Budget>>((
  ref,
) {
  return BudgetNotifier();
});

class BudgetAlertService {
  final Ref _ref;

  BudgetAlertService(this._ref);

  void checkBudgetAlerts(Map<String, double> expensesByCategory) {
    final budgets = _ref.read(budgetsProvider);
    final notificationService = _ref.read(notificationServiceProvider);

    for (final budget in budgets) {
      if (budget.categoryId == null) continue;

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
