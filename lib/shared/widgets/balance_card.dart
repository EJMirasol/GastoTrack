import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../features/expenses/data/expense_repository.dart';
import '../../core/constants/constants.dart';
import '../../core/services/currency_service.dart';

class BalanceCard extends ConsumerWidget {
  const BalanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalExpenses = ref.watch(totalExpensesForMonthProvider);
    final totalIncome = ref.watch(totalIncomeForMonthProvider);
    final currency = ref.watch(currencyProvider);
    final balance = totalIncome - totalExpenses;

    return Card(
      margin: const EdgeInsets.all(AppSizes.md),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.totalBalance,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSizes.xs),
            Text(
              formatCurrency(balance.abs(), currency),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: balance >= 0 ? AppColors.success : AppColors.error,
              ),
            ),
            const SizedBox(height: AppSizes.lg),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    label: AppStrings.income,
                    amount: totalIncome,
                    color: AppColors.income,
                    icon: Icons.arrow_downward,
                    currency: currency,
                  ),
                ),
                const SizedBox(width: AppSizes.md),
                Expanded(
                  child: _buildSummaryItem(
                    context,
                    label: AppStrings.expense,
                    amount: totalExpenses,
                    color: AppColors.expense,
                    icon: Icons.arrow_upward,
                    currency: currency,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    BuildContext context, {
    required String label,
    required double amount,
    required Color color,
    required IconData icon,
    required Currency currency,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppSizes.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppSizes.borderRadius),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSizes.sm),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: AppSizes.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  formatCurrency(amount, currency),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
